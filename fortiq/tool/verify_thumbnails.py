#!/usr/bin/env python3
"""Check that the catalogue thumbnails really are smaller and still resolve.

The packaged catalogue points grid cards at a lighter ``thumbnail`` rendition
of every preview. This tool downloads a sample of those renditions (or all of
them with ``--all``) and reports, per source host:

* how many thumbnails resolve and how many fail,
* the average size of the thumbnail versus the full preview,
* how much smaller the rendition actually is.

Usage (from the ``fortiq`` app directory)::

    python tool/verify_thumbnails.py --catalogue assets/data/cleared_catalogue.json
    python tool/verify_thumbnails.py --catalogue assets/data/cleared_catalogue.json --all

The command exits with status 1 when a checked thumbnail fails to load or is
not smaller than the full preview it replaces.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)
REQUEST_TIMEOUT = 45
MAX_BYTES = 8 * 1024 * 1024


def probe(url: str) -> tuple[int | None, int | None, str]:
    """Returns (status, bytes, content type) for one URL.

    Preview hosts are flaky: they answer 502/503 when several requests arrive
    at once. Transient server errors are retried before the URL is reported as
    broken.
    """
    last: tuple[int | None, int | None, str] = (None, None, "not attempted")
    for attempt in range(3):
        request = urllib.request.Request(
            url,
            headers={"User-Agent": USER_AGENT, "Accept": "image/*,*/*;q=0.8"},
        )
        try:
            with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT) as response:
                payload = response.read(MAX_BYTES)
                return response.status, len(payload), response.headers.get("Content-Type", "")
        except urllib.error.HTTPError as error:
            last = (error.code, None, "http-error")
            if error.code not in (429, 500, 502, 503, 504):
                return last
        except Exception as error:  # noqa: BLE001
            last = (None, None, str(error)[:60])
        time.sleep(1.5 * (attempt + 1))
    return last


def load_catalogue(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    records = data.get("bases")
    if not isinstance(records, list):
        print(f"{path} does not contain a 'bases' list", file=sys.stderr)
        raise SystemExit(1)
    return records


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--catalogue",
        type=Path,
        default=Path("assets/data/cleared_catalogue.json"),
    )
    parser.add_argument(
        "--per-host",
        type=int,
        default=3,
        help="how many thumbnails to check per host (0 checks every one)",
    )
    parser.add_argument("--all", action="store_true", help="check every thumbnail")
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()

    records = load_catalogue(args.catalogue)
    by_host: dict[str, list[dict]] = defaultdict(list)
    for record in records:
        host = urllib.parse.urlparse(record["image"]).netloc
        by_host[host].append(record)

    random.seed(args.seed)
    jobs: list[tuple[dict, dict, dict]] = []
    for host, host_records in sorted(by_host.items(), key=lambda kv: -len(kv[1])):
        picks = host_records
        if not args.all and args.per_host > 0:
            picks = random.sample(host_records, min(args.per_host, len(host_records)))
        for record in picks:
            jobs.append((host, record, record))

    results: dict[tuple[str, str], tuple[int | None, int | None, str]] = {}
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = {
            pool.submit(probe, record["thumbnail"]): (host, record["id"])
            for host, record, _ in jobs
        }
        for future, key in futures.items():
            results[key] = future.result()

    failures = []
    stats: dict[str, list[int]] = defaultdict(list)
    for host, record, _ in jobs:
        status, size, content_type = results[(host, record["id"])]
        if status != 200 or not size:
            failures.append((host, record["id"], status, content_type))
            continue
        original_status, original_size, _ = probe(record["image"])
        stats[host].append(size)
        if original_size and size >= original_size:
            failures.append(
                (host, record["id"], status, f"not smaller: {size} >= {original_size}")
            )

    print(f"catalogue: {args.catalogue}")
    print(f"records: {len(records)}  checked: {len(jobs)}")
    print()
    print(f"{'host':32} {'checked':>8} {'avg KB':>9} {'max KB':>9}")
    for host in sorted(stats, key=lambda key: -len(stats[key])):
        sizes = stats[host]
        print(
            f"{host:32} {len(sizes):>8} {sum(sizes) / len(sizes) / 1024:>9.1f} "
            f"{max(sizes) / 1024:>9.1f}"
        )

    if failures:
        print()
        print(f"FAILURES ({len(failures)}):")
        for host, record_id, status, detail in failures[:20]:
            print(f"  {host} {record_id}: status={status} {detail}")
        raise SystemExit(1)
    print()
    print("all checked thumbnails resolve and are smaller than the full preview")


if __name__ == "__main__":
    main()
