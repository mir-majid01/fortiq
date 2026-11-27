#!/usr/bin/env python3
"""Build the catalogue asset that Fortiq packages in the app.

The upstream ``clash-bases`` project publishes its catalogue as an
MIT-licensed public repository. This tool converts its ``bases.json`` export
into the versioned, lossless schema that ``ClashBasesCatalogRepository``
expects, while validating every record so a malformed entry fails the build
instead of silently disappearing at runtime.

Usage (from the ``fortiq`` app directory)::

    python tool/build_catalogue.py \
        --source ../clash-bases/bases.json \
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
SOURCE_ID = "clash-bases"
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
PAYLOAD_RE = re.compile(r"^TH(\d+):(HV|WB):[A-Za-z0-9_-]{32}$")
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


def load(source: Path) -> list[dict]:
    try:
        parsed = json.loads(source.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot read {source}: {error}")

    records = parsed.get("bases") if isinstance(parsed, dict) else None
    if not isinstance(records, list):
        fail("source must be an object with a top-level 'bases' list")
    return records


def validate(records: list[dict]) -> list[dict]:
    ids: set[str] = set()
    links: set[str] = set()
    images: set[str] = set()
    cleaned: list[dict] = []

    for index, record in enumerate(records):
        if not isinstance(record, dict):
            fail(f"record {index} is not an object")
        for field in FIELDS:
            if field not in record:
                fail(f"record {index} is missing '{field}'")

        record_id = record["id"]
        name = record["name"]
        town_hall = record["town_hall"]
        base_type = record["type"]
        link = record["link"]
        image = record["image"]

        if not isinstance(record_id, str) or not record_id:
            fail(f"record {index} has an invalid id")
        if not isinstance(name, str) or not name:
            fail(f"record {index} has an invalid name")
        if not isinstance(town_hall, int):
            fail(f"record {index} has an invalid town_hall")
        if not isinstance(base_type, str) or not base_type:
            fail(f"record {index} has an invalid type")
        if not isinstance(link, str) or not HOST_RE.match(link):
            fail(f"record {index} link is not an official Clash share URL")
        if not isinstance(image, str) or not image.startswith("https://"):
            fail(f"record {index} image is not an HTTPS URL")

        parsed_payload = payload(link)
        if parsed_payload is None:
            fail(f"record {index} has a malformed OpenLayout payload")
        embedded_hall, _village = parsed_payload
        if embedded_hall != town_hall:
            fail(
                f"record {index} town_hall={town_hall} does not match "
                f"the link payload TH{embedded_hall}"
            )

        tags = record["tags"]
        if not isinstance(tags, list) or not all(
            isinstance(tag, str) for tag in tags
        ):
            fail(f"record {index} has invalid tags")
        added = record["added"]
        if not isinstance(added, str) or not DATE_RE.match(added):
            fail(f"record {index} has an invalid added date")

        if record_id in ids:
            fail(f"duplicate id: {record_id}")
        if link in links:
            fail(f"duplicate link: {link}")
        if image in images:
            fail(f"duplicate image: {image}")
        ids.add(record_id)
        links.add(link)
        images.add(image)

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
                "source_id": SOURCE_ID,
            }
        )
    return cleaned


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    records = validate(load(args.source))
    if not records:
        fail("source contains no catalogue records")

    payload_text = json.dumps(
        {"schemaVersion": SCHEMA_VERSION, "bases": records},
        ensure_ascii=False,
        separators=(",", ":"),
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(payload_text + "\n", encoding="utf-8")

    types = Counter(record["type"] for record in records)
    print(f"wrote {len(records)} records to {args.out}")
    print(f"bytes: {args.out.stat().st_size}")
    print("types: " + ", ".join(f"{k}={v}" for k, v in sorted(types.items())))


if __name__ == "__main__":
    main()
