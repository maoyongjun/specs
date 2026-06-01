# -*- coding: utf-8 -*-
"""Convert first-review source m4a files to upload-friendly mp3 copies."""

import subprocess
from pathlib import Path

import imageio_ffmpeg


HOMEWORK_DIR = Path(r"C:\workspace\homework_file")
OUTPUT_DIR = HOMEWORK_DIR / "kelong" / "first-mp3"


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    for day in range(1, 7):
        matches = sorted(HOMEWORK_DIR.glob(f"{day}-*.m4a"))
        if not matches:
            raise FileNotFoundError(f"missing first-review m4a for day {day}")
        source = matches[0]
        target = OUTPUT_DIR / f"day{day}-first.mp3"
        cmd = [
            ffmpeg,
            "-y",
            "-i",
            str(source),
            "-vn",
            "-codec:a",
            "libmp3lame",
            "-ar",
            "24000",
            "-ac",
            "1",
            "-b:a",
            "64k",
            str(target),
        ]
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        print(f"{target.name}\t{target.stat().st_size}")


if __name__ == "__main__":
    main()
