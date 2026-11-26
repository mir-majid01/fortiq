#!/usr/bin/env python3
import hashlib
import sys
import zipfile
from pathlib import Path

REQUIRED_ENTRIES = {
    "AndroidManifest.xml",
    "classes.dex",
    "resources.arsc",
    "lib/arm64-v8a/libflutter.so",
    "assets/flutter_assets/assets/data/catalogue_rights.json",
    "assets/flutter_assets/assets/data/cleared_catalogue.json",
}
FORBIDDEN_SUFFIX = "clash_bases_catalog.json"


def fail(message: str) -> None:
    print(f"APK verification failed: {message}", file=sys.stderr)
    raise SystemExit(1)


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
    except zipfile.BadZipFile as error:
        fail(str(error))

    missing = sorted(REQUIRED_ENTRIES - names)
    if missing:
        fail(f"missing required entries: {', '.join(missing)}")
    forbidden = sorted(name for name in names if name.endswith(FORBIDDEN_SUFFIX))
    if forbidden:
        fail(f"rights-uncleared catalogue packaged: {', '.join(forbidden)}")

    print(f"APK verification passed: {apk}")
    print(f"size={apk.stat().st_size}")
    print(f"sha256={digest.hexdigest()}")
    print("rights_uncleared_catalogue=absent")


if __name__ == "__main__":
    main()
