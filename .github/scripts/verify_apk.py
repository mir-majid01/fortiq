#!/usr/bin/env python3
import hashlib
import json
import sys
import zipfile
from pathlib import Path

RIGHTS_ENTRY = "assets/flutter_assets/assets/data/catalogue_rights.json"
CATALOGUE_ENTRY = "assets/flutter_assets/assets/data/cleared_catalogue.json"
REQUIRED_ENTRIES = {
    "AndroidManifest.xml",
    "classes.dex",
    "resources.arsc",
    "lib/arm64-v8a/libflutter.so",
    RIGHTS_ENTRY,
    CATALOGUE_ENTRY,
}
FORBIDDEN_SUFFIX = "clash_bases_catalog.json"
# Hosts that publish one multi-megabyte original and no smaller rendition.
# Their previews must be requested through the resize proxy, otherwise a grid
# card downloads the full-size asset.
HEAVY_IMAGE_HOSTS = ("raw.githubusercontent.com/", "media.oneclash.com/layout/")
RESIZE_PROXY_HOST = "wsrv.nl"


def fail(message: str) -> None:
    print(f"APK verification failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(archive: zipfile.ZipFile, name: str) -> dict:
    try:
        return json.loads(archive.read(name))
    except KeyError:
        fail(f"missing packaged asset: {name}")
    except json.JSONDecodeError as error:
        fail(f"invalid JSON in {name}: {error}")


def verify_catalogue(rights: dict, catalogue: dict) -> tuple[int, int]:
    if rights.get("schemaVersion") != 1:
        fail("rights manifest has an unsupported schema version")
    cleared = {
        source.get("id")
        for source in rights.get("sources", [])
        if source.get("contentRedistribution") == "cleared"
        and source.get("previewRedistribution") == "cleared"
    }
    cleared.discard(None)
    if not cleared:
        fail("rights manifest clears zero sources")

    if catalogue.get("schemaVersion") != 1:
        fail("catalogue has an unsupported schema version")
    bases = catalogue.get("bases")
    if not isinstance(bases, list) or not bases:
        fail("packaged catalogue contains zero bases")

    ids: set[str] = set()
    for index, base in enumerate(bases):
        if not isinstance(base, dict):
            fail(f"catalogue record {index} is not an object")
        if base.get("source_id") not in cleared:
            fail(f"catalogue record {index} belongs to an uncleared source")
        for field in ("id", "link", "image", "name", "thumbnail"):
            if not isinstance(base.get(field), str) or not base[field]:
                fail(f"catalogue record {index} has an invalid {field}")
        if not base["thumbnail"].startswith("https://"):
            fail(f"catalogue record {index} thumbnail is not an HTTPS URL")
        if base["id"] in ids:
            fail(f"duplicate catalogue id: {base['id']}")
        ids.add(base["id"])
        if any(host in base["image"] for host in HEAVY_IMAGE_HOSTS):
            if RESIZE_PROXY_HOST not in base["thumbnail"]:
                fail(
                    f"catalogue record {index} uses a multi-megabyte preview "
                    "without a lightweight rendition"
                )

    return len(bases), len(cleared)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: verify_apk.py <apk-path>")
    apk = Path(sys.argv[1])
    if not apk.is_file():
        fail(f"missing APK: {apk}")

    digest = hashlib.sha256()
    with apk.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)

    try:
        with zipfile.ZipFile(apk) as archive:
            bad_entry = archive.testzip()
            if bad_entry is not None:
                fail(f"CRC error in {bad_entry}")
            names = set(archive.namelist())
            missing = sorted(REQUIRED_ENTRIES - names)
            if missing:
                fail(f"missing required entries: {', '.join(missing)}")
            rights = load_json(archive, RIGHTS_ENTRY)
            catalogue = load_json(archive, CATALOGUE_ENTRY)
    except zipfile.BadZipFile as error:
        fail(str(error))

    forbidden = sorted(name for name in names if name.endswith(FORBIDDEN_SUFFIX))
    if forbidden:
        fail(f"rights-uncleared catalogue packaged: {', '.join(forbidden)}")

    base_count, cleared_count = verify_catalogue(rights, catalogue)
    if base_count < 1000:
        fail(f"packaged catalogue looks incomplete ({base_count} bases)")

    print(f"APK verification passed: {apk}")
    print(f"size={apk.stat().st_size}")
    print(f"sha256={digest.hexdigest()}")
    print(f"catalogue_bases={base_count}")
    print(f"cleared_sources={cleared_count}")
    print("catalogue_thumbnails=verified")
    print("rights_uncleared_catalogue=absent")


if __name__ == "__main__":
    main()
