"""Compares two PNG images without third-party dependencies.

Used to review golden changes before they are committed: it reports the
percentage of differing pixels and the bounding box of the change so an
unexpected drift is visible without opening an image editor.

Usage::

    python tool/compare_goldens.py OLD.png NEW.png [OLD.png NEW.png ...]
"""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path

import numpy as np

_CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


def _chunks(data: bytes):
    offset = 8
    while offset < len(data):
        (length,) = struct.unpack(">I", data[offset : offset + 4])
        kind = data[offset + 4 : offset + 8]
        payload = data[offset + 8 : offset + 8 + length]
        yield kind, payload
        offset += 12 + length


def read_png(path: Path) -> np.ndarray:
    """Returns an (height, width, channels) uint8 array for an 8-bit PNG."""
    data = path.read_bytes()
    header = b""
    compressed = bytearray()
    palette = b""
    for kind, payload in _chunks(data):
        if kind == b"IHDR":
            header = payload
        elif kind == b"PLTE":
            palette = payload
        elif kind == b"IDAT":
            compressed += payload
        elif kind == b"IEND":
            break

    width, height, depth, color_type, compression, _, interlace = struct.unpack(
        ">IIBBBBB", header
    )
    if depth != 8:
        raise ValueError(f"{path}: only 8-bit PNGs are supported (got {depth})")
    if interlace != 0:
        raise ValueError(f"{path}: interlaced PNGs are not supported")
    if compression != 0:
        raise ValueError(f"{path}: unsupported compression {compression}")

    channels = _CHANNELS[color_type]
    raw = zlib.decompress(bytes(compressed))
    stride = width * channels
    out = np.zeros((height, stride), dtype=np.uint8)

    previous = np.zeros(stride, dtype=np.uint8)
    position = 0
    for row in range(height):
        filter_type = raw[position]
        position += 1
        line = np.frombuffer(raw[position : position + stride], dtype=np.uint8).copy()
        position += stride

        if filter_type == 0:
            pass
        elif filter_type == 1:
            for index in range(channels, stride):
                line[index] = (int(line[index]) + int(line[index - channels])) & 0xFF
        elif filter_type == 2:
            line = (line.astype(np.uint16) + previous.astype(np.uint16)).astype(np.uint8)
        elif filter_type == 3:
            for index in range(stride):
                left = int(line[index - channels]) if index >= channels else 0
                line[index] = (int(line[index]) + ((left + int(previous[index])) >> 1)) & 0xFF
        elif filter_type == 4:
            for index in range(stride):
                left = int(line[index - channels]) if index >= channels else 0
                up = int(previous[index])
                up_left = int(previous[index - channels]) if index >= channels else 0
                estimate = left + up - up_left
                distance_left = abs(estimate - left)
                distance_up = abs(estimate - up)
                distance_up_left = abs(estimate - up_left)
                if distance_left <= distance_up and distance_left <= distance_up_left:
                    predictor = left
                elif distance_up <= distance_up_left:
                    predictor = up
                else:
                    predictor = up_left
                line[index] = (int(line[index]) + predictor) & 0xFF
        else:
            raise ValueError(f"{path}: unsupported filter {filter_type}")

        out[row] = line
        previous = line

    image = out.reshape(height, width, channels)
    if color_type == 3:
        palette_array = np.frombuffer(palette, dtype=np.uint8).reshape(-1, 3)
        image = palette_array[image[:, :, 0]]
    if color_type == 0:
        image = np.repeat(image, 3, axis=2)
    if color_type == 4:
        image = np.repeat(image[:, :, :1], 3, axis=2)
    return image[:, :, :3]


def compare(old_path: Path, new_path: Path) -> bool:
    old = read_png(old_path)
    new = read_png(new_path)
    if old.shape != new.shape:
        print(f"{old_path.name}: size changed {old.shape} -> {new.shape}")
        return True

    delta = np.abs(old.astype(np.int16) - new.astype(np.int16)).max(axis=2)
    changed = delta > 8
    total = changed.size
    count = int(changed.sum())
    print(f"{old_path.name}: {count}/{total} pixels differ ({100 * count / total:.3f}%)")
    if count == 0:
        return False

    rows = np.flatnonzero(changed.any(axis=1))
    columns = np.flatnonzero(changed.any(axis=0))
    print(
        f"  bounding box: x {columns[0]}..{columns[-1]}, y {rows[0]}..{rows[-1]}"
    )
    bands: list[tuple[int, int]] = []
    start = previous = int(rows[0])
    for row in rows[1:]:
        row = int(row)
        if row != previous + 1:
            bands.append((start, previous))
            start = row
        previous = row
    bands.append((start, previous))
    print("  changed row bands: " + ", ".join(f"{a}-{b}" for a, b in bands[:12]))
    return True


def main(argv: list[str]) -> int:
    """Compares pairs of images: OLD NEW [OLD NEW ...]."""
    if len(argv) < 3 or (len(argv) - 1) % 2 != 0:
        print(__doc__)
        print("Expected pairs of OLD NEW paths.")
        return 2
    changed = False
    for index in range(1, len(argv), 2):
        old_path = Path(argv[index])
        new_path = Path(argv[index + 1])
        changed = compare(old_path, new_path) or changed
    return 1 if changed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
