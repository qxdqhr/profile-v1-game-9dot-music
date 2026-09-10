---
name: nine-dot-chart-agent
description: >-
  Offline 9-Dot Game chart pipeline: Bilibili/URL → meta.json + difficulty notes
  under app_games/9dot-music/charts/<id>/. Use when batch-generating song charts,
  converting onset/BPM data into tap/slide JSON, or the user mentions 9dot 生谱,
  Agent 生谱, chart agent, or filling charts/ for 9-Dot Music. Not a runtime
  in-game feature — invoke only when producing content.
disable-model-invocation: true
---

# 9-Dot Chart Agent（离线生谱）

游戏内 **已移除** Agent 生谱 UI。本 skill 供本机 Cursor / CLI **批量做谱** 时调用；产物写入仓库 `charts/<id>/`（发版源）。运行时首次会 seed 到 `user://songs/official/<id>/`，由 `SongLibrary` 发现。改完 charts 后需清 `user://songs/.seeded`（或删对应 official 目录）再启动才会重新拷贝。

## When to use

- 用户要为很多曲目生成 / 补全 9-Dot 谱面
- 从 B 站链接、BV、onset 表、BPM+时长生成可玩 JSON
- 校验或修补 `meta.json` / `easy|normal|hard|extreme.json`

## When NOT to use

- 改玩法判定、UI、时钟（用游戏代码 + PRD）
- 在 Web/APK 运行时动态生谱（刻意不做）

## Output layout（必须）

```
app_games/9dot-music/charts/<id>/
  meta.json
  easy.json      # 可选；缺则 meta 里对应档为 null，选歌灰显
  normal.json
  hard.json
  extreme.json
  audio.ogg      # 可选；路径写在 meta.audio.path
  video.ogv      # 可选；路径写在 meta.video.path
```

`id`：小写 slug（如 `bv19k-aimuji`）。资源路径一律 `res://charts/<id>/...`。

## Schema（摘要）

详见同目录 [reference-schema.md](reference-schema.md)。

**meta.json** 关键字段：`schemaVersion`(1)、`id`、`title`、`artist`、`bpm`、`offsetMs`、`durationMs`、`audio.path`、`video.{source,path,cacheKey}`、`difficulties.{easy,normal,hard,extreme}` = `null` 或 `{ "file": "<name>.json" }`。

**notes JSON**：

```json
{
  "difficulty": "normal",
  "notes": [
    { "tMs": 2000, "type": "tap", "node": 5 },
    { "tMs": 3000, "type": "slide", "edge": [1, 5], "dir": "a_to_b" }
  ]
}
```

- 节点 `1..9`（行列国王布局）
- `slide.edge` 仅 **邻接含对角**；`dir` = `a_to_b` | `b_to_a`
- 时间单位毫秒整数 `tMs`

## Workflow（Agent 执行步骤）

1. 确认工作目录为游戏根：`app_games/9dot-music/`（或 monorepo 内等价路径）。
2. 收集：`title` / `artist` / `bpm` / `durationMs` / `offsetMs` / 可选 `sourceUrl`·`bvid`。
3. 若仅有 URL：解析 BV（`BV[0-9A-Za-z]+`）；尚无真下载管线时，**先**用启发式占位谱 + 指向已有 metronome 媒体，并在 meta 注明 `sourceUrl`，待后期替换真实音视频与 onset。
4. 生成 notes：优先真实 onset/手动编排；否则运行本 skill 的启发式脚本（见下）。
5. 写入 `charts/<id>/`，`difficulties` 只挂存在的档。
6. 用 Godot 头less 或编辑器打开选歌，确认条目出现且可玩。

## 本机 CLI（启发式 stub）

从旧版 `NineDotAgent` 迁出的占位算法（按 BPM 等间隔；每 5 拍一个 slide）：

```bash
# 在 app_games/9dot-music 下
python3 docs/skills/nine-dot-chart-agent/scripts/heuristic_chart.py \
  --id agent-demo \
  --title "Demo" \
  --bpm 120 \
  --duration-ms 16000 \
  --url "https://www.bilibili.com/video/BVxxxxxxxx"
```

默认把 `audio`/`video` 指到 `song-metronome-001` 占位媒体，便于先打通选歌；正式曲请换成该曲自己的 ogg/ogv。

## 后期真管线（待开发，本 skill 预留）

按优先级实现，**不要**重新塞回 Godot 运行时菜单：

1. 本机拉取 / 缓存 B 站音视频（或用户提供本地文件）
2. onset / beat 检测 → 映射到九宫格 tap/slide
3. 四难度密度曲线
4. 批量：`清单.csv` → 多目录 `charts/*`
5. 校验脚本：非法边、空档、tMs 单调、时长覆盖

## 调用方式

在 Cursor 对话中明确引用：

```text
@app_games/9dot-music/docs/skills/nine-dot-chart-agent/SKILL.md
按 skill 为 <曲目> 生成 charts/<id>/
```

或用户说「用 9dot 生谱 skill / chart agent 批量做谱」时再读本文件。
