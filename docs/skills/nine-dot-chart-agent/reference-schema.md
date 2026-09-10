# 9-Dot chart schema reference

Extracted from game runtime (`NineDotChart` / builtin charts) and former `NineDotAgent`.

## Node grid

```
1 2 3
4 5 6
7 8 9
```

Legal slide edges = king-move adjacency (orthogonal + diagonal). No long jumps (e.g. 1–8).

## meta.json

| Field | Type | Notes |
|-------|------|--------|
| schemaVersion | int | `1` |
| id | string | directory slug |
| title | string | |
| artist | string | |
| bpm | number | |
| offsetMs | int | chart timing offset |
| durationMs | int | |
| sourceUrl | string | optional |
| bvid | string | optional |
| audio.path | string | 仓库可用 `res://charts/<id>/audio.ogg`；seed 后相对如 `audio.ogg` |
| video.source | string | e.g. `builtin` |
| video.path | string | 同上；相对或含 `://` 的绝对路径 |
| video.cacheKey | string | |
| difficulties.\* | null \| `{ "file": "…" }` | missing file → UI grey-out |

Runtime library fields: `_category` / `_key`=`category/id` / `_root` / `_metaPath` / `_dir`. Seed copies into `user://songs/official/`.

## notes file

```json
{
  "difficulty": "normal",
  "notes": [ /* sorted by tMs ascending preferred */ ]
}
```

### tap

```json
{ "tMs": 2000, "type": "tap", "node": 1 }
```

`node` ∈ 1..9

### slide

```json
{ "tMs": 3000, "type": "slide", "edge": [1, 5], "dir": "a_to_b" }
```

- `edge`: two distinct legal neighbors (order in array is canonical endpoints; `dir` chooses travel)
- `dir`: `a_to_b` | `b_to_a` relative to `edge[0]`→`edge[1]`

Illegal edges are skipped at load time.

## Heuristic stub (legacy Godot behavior)

- Interval = `60000 / bpm` ms
- Start at `2 * interval`, stop before `durationMs - interval`
- Every 5th note: slide on `legal_edges[i % len]`, alternating dir
- Else: tap on node `(i % 9) + 1`
