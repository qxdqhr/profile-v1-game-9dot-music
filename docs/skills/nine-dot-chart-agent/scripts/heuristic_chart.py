#!/usr/bin/env python3
"""Offline heuristic chart writer for 9-Dot (migrated from NineDotAgent.gd).

Writes charts/<id>/meta.json + normal.json under the game root.
Does NOT fetch Bilibili media — points audio/video at metronome placeholders by default.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def legal_edges() -> list[tuple[int, int]]:
    edges: list[tuple[int, int]] = []
    for a in range(1, 10):
        for b in range(a + 1, 10):
            ra, ca = divmod(a - 1, 3)
            rb, cb = divmod(b - 1, 3)
            if abs(ra - rb) <= 1 and abs(ca - cb) <= 1:
                edges.append((a, b))
    return edges


def cache_key_from_url(url: str) -> str:
    m = re.search(r"(?i)(BV[0-9A-Za-z]+)", url.strip())
    if m:
        return m.group(1)
    return str(abs(hash(url.strip())) % (10**10))


def build_heuristic_notes(bpm: float, duration_ms: int) -> list[dict]:
    interval = int(60000.0 / max(bpm, 1.0))
    edges = legal_edges()
    notes: list[dict] = []
    t = interval * 2
    i = 0
    while t < duration_ms - interval:
        if i % 5 == 4 and edges:
            a, b = edges[i % len(edges)]
            notes.append(
                {
                    "tMs": t,
                    "type": "slide",
                    "edge": [a, b],
                    "dir": "a_to_b" if i % 2 == 0 else "b_to_a",
                }
            )
        else:
            notes.append({"tMs": t, "type": "tap", "node": (i % 9) + 1})
        t += interval
        i += 1
    return notes


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


def main() -> int:
    p = argparse.ArgumentParser(description="Write heuristic 9-Dot chart under charts/<id>/")
    p.add_argument("--game-root", type=Path, default=None, help="app_games/9dot-music (auto-detect)")
    p.add_argument("--id", required=True, help="chart folder slug")
    p.add_argument("--title", default=None)
    p.add_argument("--artist", default="Auto Chart")
    p.add_argument("--bpm", type=float, default=120.0)
    p.add_argument("--duration-ms", type=int, default=16000)
    p.add_argument("--offset-ms", type=int, default=0)
    p.add_argument("--url", default="", help="optional source URL / BV")
    p.add_argument(
        "--placeholder-media",
        action="store_true",
        default=True,
        help="point audio/video at song-metronome-001 (default)",
    )
    args = p.parse_args()

    script_dir = Path(__file__).resolve().parent
    game_root = args.game_root
    if game_root is None:
        # …/docs/skills/nine-dot-chart-agent/scripts → game root
        game_root = script_dir.parents[3]
    charts = game_root / "charts"
    if not charts.is_dir():
        print(f"charts/ not found under {game_root}", file=sys.stderr)
        return 1

    chart_id = args.id.strip()
    out_dir = charts / chart_id
    key = cache_key_from_url(args.url) if args.url.strip() else chart_id
    title = args.title or f"Agent · {key}"

    notes = build_heuristic_notes(args.bpm, args.duration_ms)
    write_json(out_dir / "normal.json", {"difficulty": "normal", "notes": notes})

    media_id = "song-metronome-001"
    meta = {
        "schemaVersion": 1,
        "id": chart_id,
        "title": title,
        "artist": args.artist,
        "bpm": args.bpm,
        "offsetMs": args.offset_ms,
        "durationMs": args.duration_ms,
        "audio": {"path": f"res://charts/{media_id}/audio.ogg"},
        "video": {
            "source": "builtin",
            "path": f"res://charts/{media_id}/video.ogv",
            "cacheKey": key,
        },
        "difficulties": {
            "easy": None,
            "normal": {"file": "normal.json"},
            "hard": None,
            "extreme": None,
        },
    }
    if args.url.strip():
        meta["sourceUrl"] = args.url.strip()
        if key.upper().startswith("BV"):
            meta["bvid"] = key

    write_json(out_dir / "meta.json", meta)
    print(f"Wrote {out_dir}/meta.json and normal.json ({len(notes)} notes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
