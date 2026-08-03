#!/usr/bin/env python3
"""Align every animated pet frame to one transparent-canvas baseline."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


TARGET_BASELINE = 470
EXPECTED_SIZE = (512, 512)
EXPECTED_FRAME_COUNT = 24


def frame_paths(directory: Path) -> list[Path]:
    return sorted(directory.glob("pet_*_frame_*.png"))


def validate_image(path: Path, image: Image.Image) -> tuple[int, int, int, int]:
    if image.size != EXPECTED_SIZE:
        raise ValueError(f"{path}: expected {EXPECTED_SIZE}, got {image.size}")
    if image.mode != "RGBA":
        raise ValueError(f"{path}: expected RGBA, got {image.mode}")
    box = image.getchannel("A").getbbox()
    if box is None:
        raise ValueError(f"{path}: alpha channel contains no visible subject")
    return box


def check_transparent_corners(path: Path, image: Image.Image) -> None:
    alpha = image.getchannel("A")
    width, height = image.size
    corners = (
        alpha.getpixel((0, 0)),
        alpha.getpixel((width - 1, 0)),
        alpha.getpixel((0, height - 1)),
        alpha.getpixel((width - 1, height - 1)),
    )
    if corners != (0, 0, 0, 0):
        raise ValueError(f"{path}: corners are not transparent: {corners}")


def normalize(path: Path) -> None:
    with Image.open(path) as source:
        image = source.convert("RGBA")
    box = validate_image(path, image)
    offset_y = TARGET_BASELINE - box[3]
    shifted_top = box[1] + offset_y
    shifted_bottom = box[3] + offset_y
    if shifted_top < 0 or shifted_bottom > image.height:
        raise ValueError(f"{path}: translation {offset_y} would clip the subject")

    if offset_y != 0:
        translated = Image.new("RGBA", image.size, (0, 0, 0, 0))
        translated.alpha_composite(image, (0, offset_y))
        translated.save(path)

    with Image.open(path) as result_source:
        result = result_source.convert("RGBA")
    result_box = validate_image(path, result)
    check_transparent_corners(path, result)
    if result_box[3] != TARGET_BASELINE:
        raise ValueError(f"{path}: expected baseline {TARGET_BASELINE}, got {result_box[3]}")
    print(f"{path.name}: offset={offset_y:+d}, baseline={result_box[3]}")


def check(path: Path) -> None:
    with Image.open(path) as source:
        image = source.convert("RGBA")
    box = validate_image(path, image)
    check_transparent_corners(path, image)
    if box[3] != TARGET_BASELINE:
        raise ValueError(f"{path}: expected baseline {TARGET_BASELINE}, got {box[3]}")
    print(f"{path.name}: baseline={box[3]}, corners=transparent")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    paths = frame_paths(args.directory)
    if len(paths) != EXPECTED_FRAME_COUNT:
        raise ValueError(f"expected {EXPECTED_FRAME_COUNT} frames, found {len(paths)}")
    for path in paths:
        check(path) if args.check else normalize(path)


if __name__ == "__main__":
    main()
