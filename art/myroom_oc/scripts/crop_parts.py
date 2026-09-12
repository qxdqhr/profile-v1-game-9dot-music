"""Crop concept art into Hunyuan part images. Geometry only — no sticker UVs."""
from __future__ import annotations

import subprocess
from pathlib import Path

ART = Path(__file__).resolve().parent.parent
SRC = ART / "concept" / "oc_q_concept_front.png"
PARTS = ART / "concept" / "parts"

# ffmpeg crop=w:h:x:y  on 864x1152 concept
CROPS = {
    "part_hair.png": "760:500:52:40",
    "part_hoodie.png": "560:340:152:430",
    "part_skirt.png": "300:95:282:808",
    "part_shoes.png": "360:240:252:860",
}

# Hair/face split is done in Blender (punch face hole → part_hair_only.png;
# smooth Q-head oval → part_face_only.png). Do not send the combined head crop
# to Hunyuan — it sculpts eye sockets into the hair.

PAD = 512
BG = "0xB8B8B8"


def run(cmd: list[str]) -> None:
    subprocess.check_call(cmd)


def main() -> None:
    PARTS.mkdir(parents=True, exist_ok=True)
    for name, crop in CROPS.items():
        out = PARTS / name
        run(
            [
                "ffmpeg",
                "-y",
                "-i",
                str(SRC),
                "-filter:v",
                f"crop={crop}",
                str(out),
            ]
        )
        sq = PARTS / name.replace(".png", "_sq.png")
        run(
            [
                "ffmpeg",
                "-y",
                "-i",
                str(out),
                "-vf",
                f"pad={PAD}:{PAD}:(ow-iw)/2:(oh-ih)/2:color={BG}",
                str(sq),
            ]
        )
        print("wrote", out.name, sq.name)


if __name__ == "__main__":
    main()
