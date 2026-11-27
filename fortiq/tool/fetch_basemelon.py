#!/usr/bin/env python3
"""Collect the BaseMelon base records Fortiq needs but cannot get elsewhere.

The MIT-licensed ``clash-bases`` export stops at Town Hall 18 and carries no
Builder Base layouts: its ``WB`` payloads are war bases (home-village war
layouts), not Builder Base layouts. Town Hall 19 shipped on 2026-11-16 and
Builder Base links use the ``BB2`` payload marker.

This tool reads the public BaseMelon sitemap, visits only the level pages
Fortiq needs (Town Hall 19 and Builder Halls 3-10), and extracts for each base:

* the official ``link.clashofclans.com`` OpenLayout URL,
* the preview image URL plus its lighter thumbnail variant,
* the page title/description and the level/category/tags implied by the URL.

It is deliberately polite: one request per second, sequential, with the result
cached to disk so the catalogue can be rebuilt without touching the network.

Usage::

    python tool/fetch_basemelon.py --out tool/data/basemelon_bases.json
"""

from __future__ import annotations

import argparse
import gzip
import html
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

SITEMAP_URL = "https://basemelon.com/sitemaps/bases_all.xml.gz"
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)
REQUEST_DELAY_SECONDS = 1.0
SOURCE_ID = "basemelon"
DEFAULT_LEVELS = ["th19", "bh3", "bh4", "bh5", "bh6", "bh7", "bh8", "bh9", "bh10"]

LINK_RE = re.compile(
    r'href="(https://link\.clashofclans\.com[^"]*action=OpenLayout[^"]*)"'
)
IMAGE_RE = re.compile(r"(https://img\.basemelon\.com/bases/[^\"'\s]+/md\.jpg)")
H1_RE = re.compile(r"(?s)<h1[^>]*>(.*?)</h1>")
DESCRIPTION_RE = re.compile(
    r'<meta name="description" content="([^"]*)"', re.IGNORECASE
)
ID_RE = re.compile(r"id(\d+)$")

TYPE_TOKENS = {
    "war": "War",
    "farm": "Farm",
    "farming": "Farm",
    "trophy": "Trophy",
    "defense": "Trophy",
    "hybrid": "Hybrid",
    "fun": "Fun",
    "progress": "Progress",
}
TAG_PATTERNS = (
    ("anti-2-star", ("anti-2-star", "anti 2 star")),
    ("anti-3-star", ("anti-3-star", "anti 3 star")),
    ("anti-4-star", ("anti-4-star", "anti 4 star")),
    ("anti-everything", ("anti-everything", "anti everything")),
    ("anti-air", ("anti-air", "anti air")),
    ("anti-ground", ("anti-ground", "anti ground")),
    ("legend league", ("legend league", "legend-league")),
    ("clan war league", ("cwl", "clan war league")),
    ("ranked", ("ranked",)),
    ("offensive", ("offensive",)),
    ("defensive", ("defensive",)),
)


def fail(message: str) -> None:
    print(f"basemelon fetch failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def fetch(url: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def level_urls(levels: list[str]) -> list[str]:
    raw = gzip.decompress(fetch(SITEMAP_URL)).decode("utf-8")
    urls = re.findall(r"<loc>([^<]+)</loc>", raw)
    wanted = set(levels)
    selected = [
        url
        for url in urls
        if any(f"/coc-bases-{level}/" in url for level in wanted)
    ]
    return sorted(set(selected))


def clean_text(value: str) -> str:
    value = re.sub(r"<[^>]+>", " ", value)
    value = html.unescape(value)
    return re.sub(r"\s+", " ", value).strip()


def parse_slug(url: str) -> tuple[str, str, list[str]]:
    path = url.split("basemelon.com", 1)[-1]
    parts = [part for part in path.split("/") if part]
    level = ""
    slug = ""
    for part in parts:
        if part.startswith("coc-bases-"):
            level = part.replace("coc-bases-", "")
        elif slug == "" and part not in {"coc-bases", ""}:
            slug = part
    tokens = [token for token in slug.split("-") if token]
    return level, slug, tokens


def derive_type(tokens: list[str], description: str) -> str:
    for token in tokens:
        if token in TYPE_TOKENS:
            return TYPE_TOKENS[token]
    lowered = description.lower()
    for token, value in TYPE_TOKENS.items():
        if f"{token} base" in lowered:
            return value
    return "Progress"


def derive_tags(tokens: list[str], description: str) -> list[str]:
    haystack = " ".join(tokens).lower()
    haystack += " " + re.sub(r"[^a-z0-9]+", " ", description.lower())
    haystack = " " + re.sub(r"\s+", " ", haystack) + " "
    tags: list[str] = []
    for tag, phrases in TAG_PATTERNS:
        for phrase in phrases:
            normalized = re.sub(r"[^a-z0-9]+", " ", phrase.lower()).strip()
            needles = {f" {normalized} ", f" {normalized}s "}
            if any(needle in haystack for needle in needles) and tag not in tags:
                tags.append(tag)
                break
    return tags


def derive_name(level: str, base_type: str, base_id: str, title: str) -> str:
    hall = "Builder Hall" if level.startswith("bh") else "Town Hall"
    number = level[2:]
    label = base_type if base_type != "Progress" else "Layout"
    return f"{hall} {number} {label} #{base_id}"


def parse_record(url: str, html: str) -> dict | None:
    link_match = LINK_RE.search(html)
    image_match = IMAGE_RE.search(html)
    if not link_match or not image_match:
        return None

    link = link_match.group(1)
    level, slug, tokens = parse_slug(url)
    id_match = ID_RE.search(slug)
    base_id = id_match.group(1) if id_match else slug
    title = clean_text(H1_RE.search(html).group(1)) if H1_RE.search(html) else ""
    description_match = DESCRIPTION_RE.search(html)
    description = clean_text(description_match.group(1)) if description_match else ""
    base_type = derive_type(tokens, f"{title} {description}")
    tags = derive_tags(tokens, f"{title} {description}")

    image = image_match.group(1)
    thumbnail = image.replace("/md.jpg", "/sm_crop.jpg")
    return {
        "id": f"bm-{level}-{base_id}",
        "name": derive_name(level, base_type, base_id, title),
        "town_hall": int(level[2:]),
        "type": base_type,
        "link": link,
        "description": description[:280] or None,
        "builder": None,
        "tags": tags,
        "added": None,
        "image": image,
        "thumbnail": thumbnail,
        "source_id": SOURCE_ID,
        "source_url": url,
        "title": title,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--levels", nargs="*", default=DEFAULT_LEVELS)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument(
        "--update",
        action="store_true",
        help="keep already collected records and only fetch missing pages",
    )
    args = parser.parse_args()

    urls = level_urls(args.levels)
    if args.limit:
        urls = urls[: args.limit]

    existing: list[dict] = []
    collected_urls: set[str] = set()
    if args.update and args.out.is_file():
        existing = json.loads(args.out.read_text(encoding="utf-8"))
        collected_urls = {record["source_url"] for record in existing}
        urls = [url for url in urls if url not in collected_urls]
    print(f"fetching {len(urls)} base pages")

    records: list[dict] = []
    skipped = 0
    for index, url in enumerate(urls, start=1):
        try:
            html = fetch(url).decode("utf-8", errors="replace")
        except (urllib.error.URLError, TimeoutError) as error:
            print(f"  [{index}/{len(urls)}] ERROR {url}: {error}", file=sys.stderr)
            skipped += 1
            continue
        record = parse_record(url, html)
        if record is None:
            skipped += 1
        else:
            records.append(record)
        if index % 20 == 0:
            print(f"  [{index}/{len(urls)}] collected {len(records)}")
        time.sleep(REQUEST_DELAY_SECONDS)

    merged = existing + records
    if not merged:
        fail("no records collected")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"wrote {len(merged)} records to {args.out} (skipped {skipped})")


if __name__ == "__main__":
    main()
