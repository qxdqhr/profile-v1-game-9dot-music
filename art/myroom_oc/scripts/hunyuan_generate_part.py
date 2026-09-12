#!/usr/bin/env python3
"""Generate OC parts with Hunyuan3D-2mv from front/left/back images.

Uses the local Hunyuan venv + weights (not BlenderMCP). Mini single-view is
the reason previous parts collapsed into plaques; 2mv consumes the turnaround.
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

ART = Path(__file__).resolve().parent.parent
HY3D = Path.home() / "src" / "Hunyuan3D-2"
VIEWS = ("front", "left", "back")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "parts",
        nargs="+",
        help="part folder names under art/myroom_oc/parts/ (pipeline loaded once)",
    )
    parser.add_argument("--octree", type=int, default=128)
    parser.add_argument("--steps", type=int, default=5)
    parser.add_argument("--seed", type=int, default=1234)
    args = parser.parse_args()

    os.environ.setdefault("PYTORCH_ENABLE_MPS_FALLBACK", "1")
    os.environ.setdefault("HF_ENDPOINT", "https://hf-mirror.com")
    os.environ.setdefault("HY3DGEN_MODELS", str(Path.home() / ".cache" / "hy3dgen"))
    os.environ.setdefault("PYTORCH_MPS_HIGH_WATERMARK_RATIO", "0.0")
    sys.path.insert(0, str(HY3D))

    import torch
    from PIL import Image
    from hy3dgen.shapegen import Hunyuan3DDiTFlowMatchingPipeline

    device = "mps" if torch.backends.mps.is_available() else "cpu"
    print(f"loading Hunyuan3D-2mv-turbo on {device}", flush=True)
    pipe = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained(
        "tencent/Hunyuan3D-2mv",
        subfolder="hunyuan3d-dit-v2-mv-turbo",
        use_safetensors=True,
        device=device,
    )
    try:
        pipe.enable_flashvdm(mc_algo="mc")
    except Exception as exc:
        print("flashvdm skipped", exc, flush=True)

    gen_device = "cpu" if device == "mps" else device

    def cond_image(path: Path):
        im = Image.open(path).convert("RGBA")
        px = im.load()
        w, h = im.size
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if abs(r - g) < 22 and abs(g - b) < 22 and 150 < r < 240:
                    px[x, y] = (0, 0, 0, 0)
        return im

    for part in args.parts:
        part_dir = ART / "parts" / part
        cond = {}
        for view in VIEWS:
            path = part_dir / f"{view}.png"
            if not path.exists():
                raise SystemExit(f"missing {path}; run crop_threeview_parts.py first")
            cond[view] = cond_image(path)
        print(f"generating {part}...", flush=True)
        t0 = time.time()
        mesh = pipe(
            image=cond,
            num_inference_steps=args.steps,
            octree_resolution=args.octree,
            guidance_scale=5.0,
            generator=torch.Generator(gen_device).manual_seed(args.seed),
            mc_algo="mc",
            num_chunks=8000,
            output_type="trimesh",
        )[0]
        out = part_dir / f"{part}.glb"
        mesh.export(str(out))
        print(f"WROTE {out} in {time.time() - t0:.1f}s verts={len(mesh.vertices)}", flush=True)
        if device == "mps":
            torch.mps.empty_cache()


if __name__ == "__main__":
    main()
