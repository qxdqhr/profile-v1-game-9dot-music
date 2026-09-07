# 9-Dot Game（Godot）

竖屏九宫格音游：**Tap** 点节点，**Slide** 沿邻接边（含对角）滑动。  
需求文档：[docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)（PRD v1.0）

旁路入口：`/games/9dot-music/`

```bash
# 编辑器运行
godot --path app_games/9dot-music

# 在 profile-v1 根目录导出 H5
bash scripts/export-godot-game.sh 9dot-music
```

## 当前进度

- **M0** PRD 收敛
- **M1** 标题 / 选歌 / 设置 / 关于 + Tap/Slide + Metronome Lab
- **M2** 内置 `audio.ogg` + `video.ogv`；音频主时钟；视频跟随纠偏
- **M3** 主界面品牌首屏 / 曲目目录 / 难度灰显 / 设置面板 / 独立结算页
- **M4+** 补难度、百万计分、Agent 生谱
