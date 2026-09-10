# 9-Dot Game — 现有功能梳理

> 日期：2026-09-10  
> 版本：约 v0.6.6（`project.godot`）  
> 工程：`app_games/9dot-music/` · 旁路 `/games/9dot-music/`  
> 需求原文：[REQUIREMENTS.md](REQUIREMENTS.md)（PRD）；本文件为**已实现能力**快照，便于对照 PRD / 调研。

---

## 1. 流程与场景

| 场景 | 说明 |
|------|------|
| 闪屏 `title` | 品牌首屏；点任意处 → Hub |
| Hub `hub` | 节奏游戏 / MyRoom（占位）/ 设置 / 关于 |
| 选歌 `song_select` | 翻盖手机通讯录风；分组曲库；难度本；设置入口 |
| 游玩 `play` | Tap / Slide；AV 同步；HUD；暂停；结算跳转 |
| 结算 `result` | 分数 / 准度 / Max Combo / 分档计数；回选歌 / Hub |
| 设置 `settings` | 顶部 Tab：游戏 / 视频 / 音量 |
| 关于 `about` | 版本与离线生谱指引 |
| MyRoom `my_room` | Stub，后期个人空间 |

**已移除**：游戏内「Agent 生谱」UI（`agent` 场景 / `nine_dot_agent`）；生谱仅离线 skill。

---

## 2. 玩法（已实现）

- **Tap**：九宫格 1–9 点击；接近窗内判定 Perfect / Great / Good / Miss  
- **Slide**：邻接边（含对角）；按压 Arm → 滑动完成；更宽判定窗  
- **时钟**：音频主时钟 + 设置偏移；视频跟随纠偏（`NineDotMedia.sync_video_to_audio`）  
- **计分**：百万制权重；Combo / Acc；结算页展示  
- **反馈**：判定文案 + SFX + 可选振动；空点 Too Early / Empty（不覆盖 hold 中的 Perfect 等）  
- **输入**：`emulate_touch_from_mouse` 时只走触摸事件，避免 Perfect 被 Empty 盖掉  

难度：Easy / Normal / Hard / Extreme；缺档灰显。

---

## 3. 曲库模块（`scripts/songs/`）

| 能力 | 说明 |
|------|------|
| 根路径 | 仅 `user://songs/<category>/<id>/` |
| 分类 | `official/`、`users/`（目录名即分类；可并存同 id，键为 `category/id`） |
| 首次 seed | `res://charts/*` → `user://songs/official/`；写 `.seeded`；meta 媒体改相对路径 |
| Autoload | `SongLibrary`：ensure_seed / refresh / list / list_grouped / resolve |
| 媒体 | `SongMediaIo`：`res://` 用 ResourceLoader；`user://` 运行时解码 ogg/ogv |
| 导入 API | `SongImport.import_set_folder` → `users/`（Web 暂不支持）；zip/`.9dotz` 预留 |
| 发版源 | 仓库仍写 `charts/`；chart-agent 默认写此 |

选歌：官方 / 我的分组（可折叠，默认开）+ 状态栏「刷新」。

调研与决策：[RESEARCH-EXTERNAL-SONGS.md](RESEARCH-EXTERNAL-SONGS.md)。

---

## 4. 游玩 HUD

| 元素 | 说明 |
|------|------|
| 标题框 | 曲名（`TitleFrame`） |
| 判定柱 | Judge → Combo → Score → Acc |
| 底进度条 | 歌姬式纯色条（曲进度） |
| 排布预设 | `stack_center`（默认）/ `stack_left` / `stack_right` / `split_maimai` |

设置项：`AppSettings.hud_layout`。详见 [RESEARCH-PLAY-HUD.md](RESEARCH-PLAY-HUD.md)。

---

## 5. 设置（Tab）

顶部横滑 Tab：

1. **游戏**：判定偏移、振动、击打音、HUD 排布、恢复默认偏移  
2. **视频**：适配 Fit 层 / 完整 / 铺满（横屏 PV × 竖屏）  
3. **音量**：主音量  

持久化：`user://nine_dot_settings.cfg`。视频调研：[RESEARCH-PORTRAIT-LANDSCAPE-VIDEO.md](RESEARCH-PORTRAIT-LANDSCAPE-VIDEO.md)。

---

## 6. UI / Theme

- 共享 `NineDotTheme` + `NineDotUiJuice`（进场 / 按钮 / 判定弹出）  
- 选歌：翻盖手机 LCD + softkey  
- 设置 Tab：`SettingsTab` / `SettingsTabActive`  
- Skill 索引：[RESEARCH-GODOT-UI-SKILLS.md](RESEARCH-GODOT-UI-SKILLS.md)

---

## 7. 曲目内容（仓库 `charts/`）

| id | 标题 | 备注 |
|----|------|------|
| `song-metronome-001` | Metronome Lab | 开发向 |
| `bv19k-aimuji` | 愛夢跡 | 含 aspect 等 meta |
| `bv1yt-hajimete` | ハジメテノオト | BV1yt411f7pj p2；四难度 |

运行时列表以 seed 后的 `user://songs` 为准。改 charts 后需清 `.seeded`（或对应 official 目录）才会重新拷贝。

---

## 8. 离线生谱

- Skill：`docs/skills/nine-dot-chart-agent/`  
- 启发式脚本：`scripts/heuristic_chart.py` → `charts/<id>/`  
- Schema：`reference-schema.md`（相对路径 / `res://` 均可；seed 后相对）

---

## 9. 关键脚本 / Autoload

| 名 | 职责 |
|----|------|
| `AppSettings` | 音量 / 偏移 / 振动 / SFX / 视频适配 / HUD |
| `PlaySession` | 选曲 `library_key`、难度、结算载荷、设置返回场景 |
| `SongLibrary` | 曲库门面 |
| `Sa2kitCjk` | CJK 字体 boot |

玩法核心：`nine_dot_judge` / `clock` / `geometry` / `feedback` / `media` / `catalog`（兼容转发）。

---

## 10. 已知边界 / 未做

- APK「导入曲包」UI 未挂（仅 `SongImport` API）  
- Web 用户曲导入弱；暂以官方 seed 为主  
- `.9dotz` / zip 解压未实现  
- MyRoom 仅占位  
- 联机 / 云存 / 谱面编辑器 / 评级字母：非本阶段  

手感与节奏调研：`RESEARCH-CASUAL-HIT-FEEL.md`、`RESEARCH-RHYTHM-FEEL.md`。
