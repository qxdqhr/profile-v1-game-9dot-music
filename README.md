# 9-Dot Game（Godot）

竖屏九宫格音游：**Tap** 点节点，**Slide** 沿邻接边（含对角）滑动。  
需求文档：[docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)（PRD）  
**已实现功能快照**：[docs/FEATURES.md](docs/FEATURES.md)

旁路入口：`/games/9dot-music/`

```bash
# 编辑器运行
godot --path app_games/9dot-music

# 在 profile-v1 根目录导出 H5
bash scripts/export-godot-game.sh 9dot-music
```

## 当前进度（摘要）

- 流程：闪屏 → Hub（节奏游戏 / MyRoom stub / 设置 / 关于）
- 玩法：Tap / Slide · 音频主时钟 · 视频跟随 · 四难度 · 百万计分
- 曲库：`user://songs` + 首次 seed；模块 `scripts/songs/`（`SongLibrary`）
- HUD：曲名标题框 · 判定柱 · 底进度条 · maimai 风格排布预设
- 设置：顶部 Tab（游戏 / 视频 / 音量）
- 曲目：Metronome Lab · 愛夢跡 · ハジメテノオト
- 生谱：已迁出至离线 skill（见下）

## 文档索引

| 文档 | 内容 |
|------|------|
| [docs/FEATURES.md](docs/FEATURES.md) | **现有功能梳理**（实现快照） |
| [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) | PRD |
| [docs/RESEARCH-EXTERNAL-SONGS.md](docs/RESEARCH-EXTERNAL-SONGS.md) | 外置曲库 |
| [docs/RESEARCH-PLAY-HUD.md](docs/RESEARCH-PLAY-HUD.md) | Play HUD / 预设 |
| [docs/RESEARCH-PORTRAIT-LANDSCAPE-VIDEO.md](docs/RESEARCH-PORTRAIT-LANDSCAPE-VIDEO.md) | 竖屏×横屏 PV |
| [docs/RESEARCH-GODOT-UI-SKILLS.md](docs/RESEARCH-GODOT-UI-SKILLS.md) | Godot UI skills |
| [docs/skills/nine-dot-chart-agent/](docs/skills/nine-dot-chart-agent/) | 离线生谱 |

## 离线生谱（非运行时）

游戏内已无「Agent 生谱」菜单。批量做谱请用本机 skill：

[`docs/skills/nine-dot-chart-agent/SKILL.md`](docs/skills/nine-dot-chart-agent/SKILL.md)

```bash
python3 docs/skills/nine-dot-chart-agent/scripts/heuristic_chart.py \
  --id my-song --title "Demo" --bpm 120 --duration-ms 16000
```

产物写入仓库 `charts/<id>/`（发版源）。运行时首次 seed 到 `user://songs/official/<id>/`；选歌扫 `user://songs`（官方 / 我的）。曲库模块：`scripts/songs/`（Autoload `SongLibrary`）。
