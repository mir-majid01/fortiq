#!/usr/bin/env python3
"""Build the catalogue asset that Fortiq packages in the app.

Two upstream feeds are merged into one versioned, lossless asset:

* ``clash-bases`` — the MIT-licensed community catalogue (Town Hall 4-18).
* BaseMelon — the Town Hall 19 and Builder Hall 3-10 layouts that the first
  feed does not carry (see ``tool/fetch_basemelon.py``).

Every record is validated before it is written: unique IDs/links/images,
official ``link.clashofclans.com`` OpenLayout URLs whose payload level matches
the record, and HTTPS preview URLs. A malformed record fails the build instead
of silently disappearing at runtime.

Each record also gets a lightweight ``thumbnail`` rendition so grid cards
download a fraction of the bytes of the full preview. The rendition comes from
the source host itself whenever it publishes one (``-400w.webp``,
``sm_crop.jpg``, ``?width=400``, ``m.jpg``, ``-300x300.webp``). Hosts that
publish a single multi-megabyte original and no rendition — the
``raw.githubusercontent.com`` PNGs and the oneclash ``/layout/`` previews — are
requested through the public weserv.nl resizer, which returns a 400px WebP
copy of the same public file. No preview image is ever copied into the app
bundle.

Usage (from the ``fortiq`` app directory)::

    python tool/build_catalogue.py \\
        --source ../clash-bases/bases.json \\
        --extra tool/data/basemelon_bases.json \\
        --out assets/data/cleared_catalogue.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.parse
from collections import Counter
from pathlib import Path
from typing import NoReturn

SCHEMA_VERSION = 1
CLASH_BASES_SOURCE_ID = "clash-bases"
BASEMELON_SOURCE_ID = "basemelon"
# Public image resizer used only for hosts that publish no smaller rendition.
RESIZE_PROXY = "https://wsrv.nl/"
THUMBNAIL_WIDTH = 400
THUMBNAIL_QUALITY = 70
FIELDS = (
    "id",
    "name",
    "town_hall",
    "type",
    "link",
    "description",
    "builder",
    "tags",
    "added",
    "image",
)
HOST_RE = re.compile(r"^https://link\.clashofclans\.com/")
PAYLOAD_RE = re.compile(r"^TH(\d+):(HV|WB|BB2|BB):[A-Za-z0-9_-]{32}$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def fail(message: str) -> NoReturn:
    print(f"catalogue build failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def payload(link: str) -> tuple[int, str] | None:
    query = urllib.parse.urlparse(link).query
    value = urllib.parse.parse_qs(query).get("id", [None])[0]
    match = PAYLOAD_RE.match(value or "")
    if not match:
        return None
    return int(match.group(1)), match.group(2)


def resize_proxy(image: str) -> str:
    """Routes an image through the public weserv.nl resizer.

    A few hosts publish a single multi-megabyte original and expose no
    rendition API at all. The proxy fetches that same public file and returns
    a 400px WebP copy, so the app never downloads the full-size asset for a
    grid card. No image content is copied into the app bundle.
    """
    parsed = urllib.parse.urlparse(image)
    target = urllib.parse.quote(parsed.netloc + parsed.path, safe="/")
    if parsed.query:
        # Keep "=" readable so the source query survives the proxy's own
        # parameter parsing; "&" is escaped so it cannot split the URL.
        target += "?" + urllib.parse.quote(parsed.query, safe="=")
    return (
        f"{RESIZE_PROXY}?url={target}"
        f"&w={THUMBNAIL_WIDTH}&output=webp&q={THUMBNAIL_QUALITY}"
    )


def thumbnail_for(image: str) -> str:
    """Returns a smaller rendition of the same preview when the host offers one."""
    parsed = urllib.parse.urlparse(image)
    host = parsed.netloc
    path = parsed.path
    query = parsed.query

    # media.oneclash.com publishes a 1600px WebP sibling for each preview.
    if host == "media.oneclash.com":
        if path.endswith("-1600w.webp"):
            return urllib.parse.urlunparse(
                parsed._replace(path=path[: -len("-1600w.webp")] + "-400w.webp")
            )
        # The /layout/ previews have no sibling rendition at all.
        if path.startswith("/layout/"):
            return resize_proxy(image)
    # BaseMelon ships a 300px square crop next to every 1000px preview.
    if host == "img.basemelon.com" and path.endswith("/md.jpg"):
        return urllib.parse.urlunparse(
            parsed._replace(path=path[: -len("/md.jpg")] + "/sm_crop.jpg")
        )
    # blueprintcoc.com runs a Shopify-style CDN that honours ?width=.
    if host == "blueprintcoc.com":
        params = urllib.parse.parse_qsl(query, keep_blank_values=True)
        if not any(key == "width" for key, _ in params):
            params.append(("width", str(THUMBNAIL_WIDTH)))
            return urllib.parse.urlunparse(parsed._replace(query=urllib.parse.urlencode(params)))
    # imgur exposes size suffixes: t (160px), m (640px), b (1024px).
    if host == "i.imgur.com":
        stem = path[: path.rfind(".")] if "." in path else path
        return urllib.parse.urlunparse(parsed._replace(path=f"{stem}m.jpg", query=""))
    # WordPress generates a -300x300 sibling for every uploaded preview.
    if host == "bases-coc.com" and path.endswith(".webp"):
        return urllib.parse.urlunparse(
            parsed._replace(path=path[: -len(".webp")] + "-300x300.webp")
        )
    # raw.githubusercontent.com serves one 3-4 MB PNG per base and nothing else.
    if host == "raw.githubusercontent.com":
        return resize_proxy(image)
    # cdn.shopify.com only transforms some archived files ("_400x400" answers
    # 502 and the resizer 404s), so those six previews keep their original URL
    # as the thumbnail and are decoded at the painted size instead.
    return image


def load_clash_bases(path: Path) -> list[dict]:
    try:
        parsed = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot read {path}: {error}")
    records = parsed.get("bases") if isinstance(parsed, dict) else None
    if not isinstance(records, list):
        fail(f"{path} must be an object with a top-level 'bases' list")
    return records


def load_basemelon(path: Path) -> list[dict]:
    try:
        records = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot read {path}: {error}")
    if not isinstance(records, list):
        fail(f"{path} must contain a list of base records")
    return records


def validate(records: list[dict], source_id: str) -> list[dict]:
    ids: set[str] = set()
    links: set[str] = set()
    images: set[str] = set()
    cleaned: list[dict] = []

    for index, record in enumerate(records):
        if not isinstance(record, dict):
            fail(f"{source_id} record {index} is not an object")
        for field in FIELDS:
            if field not in record:
                fail(f"{source_id} record {index} is missing '{field}'")

        record_id = record["id"]
        name = record["name"]
        town_hall = record["town_hall"]
        base_type = record["type"]
        link = record["link"]
        image = record["image"]

        if not isinstance(record_id, str) or not record_id:
            fail(f"{source_id} record {index} has an invalid id")
        if not isinstance(name, str) or not name:
            fail(f"{source_id} record {index} has an invalid name")
        if not isinstance(town_hall, int):
            fail(f"{source_id} record {index} has an invalid town_hall")
        if not isinstance(base_type, str) or not base_type:
            fail(f"{source_id} record {index} has an invalid type")
        if not isinstance(link, str) or not HOST_RE.match(link):
            fail(f"{source_id} record {index} link is not an official Clash share URL")
        if not isinstance(image, str) or not image.startswith("https://"):
            fail(f"{source_id} record {index} image is not an HTTPS URL")

        parsed_payload = payload(link)
        if parsed_payload is None:
            fail(f"{source_id} record {index} has a malformed OpenLayout payload")
        embedded_hall, marker = parsed_payload
        if embedded_hall != town_hall:
            fail(
                f"{source_id} record {index} town_hall={town_hall} does not match "
                f"the link payload TH{embedded_hall}"
            )

        tags = record["tags"]
        if not isinstance(tags, list) or not all(
            isinstance(tag, str) for tag in tags
        ):
            fail(f"{source_id} record {index} has invalid tags")
        added = record["added"]
        if added is not None and (not isinstance(added, str) or not DATE_RE.match(added)):
            fail(f"{source_id} record {index} has an invalid added date")

        if record_id in ids:
            fail(f"duplicate id in {source_id}: {record_id}")
        if link in links:
            fail(f"duplicate link in {source_id}: {link}")
        if image in images:
            fail(f"duplicate image in {source_id}: {image}")
        ids.add(record_id)
        links.add(link)
        images.add(image)

        thumbnail = record.get("thumbnail")
        if thumbnail is not None and (
            not isinstance(thumbnail, str) or not thumbnail.startswith("https://")
        ):
            fail(f"{source_id} record {index} has an invalid thumbnail")

        cleaned.append(
            {
                "id": record_id,
                "name": name,
                "town_hall": town_hall,
                "type": base_type,
                "link": link,
                "description": record["description"],
                "builder": record["builder"],
                "tags": tags,
                "added": added,
                "image": image,
                "thumbnail": thumbnail or thumbnail_for(image),
                "source_id": source_id,
            }
        )
    return cleaned


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--extra", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    records = validate(load_clash_bases(args.source), CLASH_BASES_SOURCE_ID)
    if args.extra:
        records += validate(load_basemelon(args.extra), BASEMELON_SOURCE_ID)
    if not records:
        fail("source contains no catalogue records")

    seen_ids = {record["id"] for record in records}
    seen_links = {record["link"] for record in records}
    seen_images = {record["image"] for record in records}
    if len(seen_ids) != len(records):
        fail("duplicate ids across sources")
    if len(seen_links) != len(records):
        fail("duplicate links across sources")
    if len(seen_images) != len(records):
        fail("duplicate images across sources")

    payload_text = json.dumps(
        {"schemaVersion": SCHEMA_VERSION, "bases": records},
        ensure_ascii=False,
        separators=(",", ":"),
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(payload_text + "\n", encoding="utf-8")

    types = Counter(record["type"] for record in records)
    sources = Counter(record["source_id"] for record in records)
    villages = Counter(record["town_hall"] for record in records)
    print(f"wrote {len(records)} records to {args.out}")
    print(f"bytes: {args.out.stat().st_size}")
    print("sources: " + ", ".join(f"{k}={v}" for k, v in sorted(sources.items())))
    print("types: " + ", ".join(f"{k}={v}" for k, v in sorted(types.items())))
    print("levels: " + ", ".join(f"TH{k}={v}" for k, v in sorted(villages.items())))


if __name__ == "__main__":
    main()
