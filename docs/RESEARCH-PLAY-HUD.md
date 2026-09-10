# Play HUD：歌姬底条 + maimai 排布预设

> 日期：2026-09-10  
> 状态：已实现（默认 `stack_center`）

## 构图

| 区域 | 内容 |
|------|------|
| 顶栏 | 曲名 **标题框**（`TitleFrame`）+ 暂停 |
| 判定柱 | Judge → Combo → Score → Acc |
| 底栏 | 纯色曲进度条（`SongProgress`，高度 6px） |

## 预设（设置 → 游戏 → HUD 排布）

| ID | 名称 |
|----|------|
| `stack_center` | 居中柱（默认） |
| `stack_left` | 左侧柱 |
| `stack_right` | 右侧柱 |
| `split_maimai` | 分离：Judge+Combo 居中，Score/Acc 顶部分列 |

实现：`scripts/play_hud_layout.gd`、`AppSettings.hud_layout`、`scenes/play.tscn`。

相关 skill：`godot-ui-containers` / `godot-ui-theming` / `godot-tweening`（见 `RESEARCH-GODOT-UI-SKILLS.md`）。
