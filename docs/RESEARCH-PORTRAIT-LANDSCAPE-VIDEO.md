# 调研：竖屏音游中横版 PV / MV 的适配（不变形）

> 日期：2026-09-10  
> 问题：9-Dot 为竖屏（约 9:16），内置素材多为横版（约 16:9）。当前 `VideoStreamPlayer.expand = true` + 全屏锚点会把画面**非等比拉伸**进竖屏，观感差。  
> 方法：对照 Godot 官方文档 / `AspectRatioContainer` API、FFmpeg 等比缩放惯例，以及竖屏音游常见产品形态；结论落成可实施选项。

---

## 1. 根因（设计缺陷确认）

当前游玩场景（`scenes/play.tscn`）：

- `Video` 为全屏 `Control` 锚点（`PRESET_FULL_RECT`）
- `expand = true` → 视频纹理被拉满控件矩形

Godot 文档对 `expand` 的定义是：视频缩放到 **控件尺寸**；**并不**自动保持片源宽高比。  
在竖屏控件上播放横版片源，等于把 16:9「压扁」成 9:16。

官方说明（[Playing videos](https://docs.godotengine.org/en/stable/tutorials/animation/playing_videos.html)）：

> By default, the VideoStreamPlayer will automatically be resized to match the video's resolution. You can make it follow usual Control sizing by enabling **Expand**…
>
> …playing fullscreen videos **without distorting** the video (but with empty space on the edges instead). For more control, you can use an **AspectRatioContainer**…

`VideoStreamPlayer.expand` 类文档（[VideoStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_videostreamplayer.html)）：

> If `true`, the video scales to the control size.

**硬规则：禁止用「全屏 expand + 与片源不同的控件比例」当唯一布局；那必然变形。**

---

## 2. Godot 运行时：官方推荐模式

### 2.1 `AspectRatioContainer` + `VideoStreamPlayer.expand`

官方教程步骤摘要：

1. 添加 **非嵌套在其他 Container 下** 的 `AspectRatioContainer`，Layout = Full Rect  
2. `ratio` = 片源宽/高（如 `16.0/9.0`）  
3. 把 `VideoStreamPlayer` 设为子节点，并开启 `expand`  
4. 即可在父区域内缩放且 **不变形**

`AspectRatioContainer.stretch_mode`（[class docs](https://docs.godotengine.org/en/stable/classes/class_aspectratiocontainer.html)）：

| 模式 | 行为 | 竖屏里放 16:9 的结果 |
|------|------|----------------------|
| **STRETCH_FIT**（默认） | 完整装进容器，保比例 | **上下黑边（letterbox）**，或在更矮容器里缩成一条带 |
| **STRETCH_COVER** | 铺满容器，保比例，溢出裁切 | **左右裁切（center crop）**；需父节点 `clip_contents` |

对齐：`alignment_horizontal/vertical` 默认居中，适合 MV 主体居中。

### 2.2 布局变体（与九宫格共存）

| 方案 | 结构 | 观感 | 与九宫格关系 |
|------|------|------|----------------|
| **A. 顶栏 16:9 带** | 上方固定高度 ≈ `width * 9/16` 的 ARC(FIT)；下方留给格 | PV 完整、不变形；上半屏像「小电视」 | **最贴 9-Dot**：格在 `GRID_TOP≈210` 一带，视频可占顶部安全带 |
| **B. 全屏 COVER 裁切** | 全屏 ARC `ratio=16/9` + `STRETCH_COVER` + clip | 全屏氛围强；左右被裁 | 格叠在 MV 上；脸/字幕靠两侧会丢 |
| **C. 全屏 FIT letterbox** | 全屏 ARC FIT | 不变形；大块黑边 | 格可能压在黑边或画面上，层次需调 |
| **D. 模糊垫底 + 清晰 FIT** | 底层 COVER 模糊（或静态模糊帧）+ 上层 FIT 清晰条 | 常见短视频「竖屏包装」 | 实现成本高于 A/B；Web 上双重解码要谨慎 |

Godot 教程另述可用 `SubViewport` + 3D 平面贴视频纹理；对本案过重，不优先。

---

## 3. 内容管线（离线，FFmpeg）

运行时保比例之外，也可在生谱 skill 导出时预处理。FFmpeg 惯例（`force_original_aspect_ratio` + `pad` / `crop`）：

**Letterbox / pad 进 9:16（不裁内容）**

```bash
ffmpeg -i in.mp4 -vf \
  "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black,setsar=1" \
  out_pad.mp4
```

**Center crop 进 9:16（铺满竖屏）**

```bash
ffmpeg -i in.mp4 -vf \
  "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920" \
  out_crop.mp4
```

**模糊背景 + 前景 FIT**（包装感强，文件更大）— 短视频业界常用 filter_complex；适合「导出竖版成片」而非双重运行时解码。

参考：[FFmpeg scaling handbook 片段](https://github.com/endcycles/ffmpeg-engineering-handbook/blob/main/docs/operations/scaling.md)、社区竖屏转换惯例（pad vs crop）。

对 9-Dot：`meta.video` 可增加 `aspect` / `fitMode`（`fit`|`cover`|`band`），生谱 skill 默认写真实 SAR，游玩层读取。

---

## 4. 产品侧对标（次级证据）

竖屏音游 + 横版 PV 的常见处理（玩家/资料描述，非引擎规范）：

- **Miku Flick**：Arcade PV 作背景，小屏上需 **大量裁切** 才能塞进 iPhone（Reddit / [Wikipedia: Miku Flick](https://en.wikipedia.org/wiki/Miku_Flick) — 预渲染 PV + 玩法叠层）。说明「竖屏玩横 PV」行业默认是 **裁或框**，不是拉伸。  
- **Project SEKAI 等**：Live/MV 多为专为竖屏或 3D 舞台构图；横版成片进竖屏 UI 时仍多见 **带状或裁切**，而非变形。

结论：变形（squash）几乎从不作为产品选择；二选一是 **保比例留边** 或 **保比例裁切**。

---

## 5. 针对 9-Dot 的推荐排序

### P0 — 运行时立刻修

两条都合法，按产品取向二选一（或设置切换）：

| 默认取向 | 方案 | 做法 |
|----------|------|------|
| **看清完整 PV / 与九宫格分区** | **顶栏 16:9 带（FIT）** | 容器高 ≈ `width×9/16`，顶对齐；下方格区不变 |
| **大气背景（更贴「视频在格下」）** | **全屏 COVER + clip** | ARC `ratio=16/9`、`STRETCH_COVER`、`clip_contents`；保留 `VideoDim` |

两者都必须：`AspectRatioContainer` + 子级 `expand`，**禁止**裸全屏非等比 expand。

可参考竖屏节奏里用 **lane/遮罩不透明度** 压过 MV（如 SEKAI 设置中的 lane opacity，次级来源），你们已有 `VideoDim`。

### P1 — 生谱 / 导出管线

在 `docs/skills/nine-dot-chart-agent` 增加：

- 探测片源 DAR  
- 可选 ffmpeg：`force_original_aspect_ratio=decrease`+`pad`（letterbox）或 `increase`+`crop`（cover）  
- `meta.video.fit = "band"|"cover"|"fit"`，`aspect` 浮点  

移动端编码：Godot 教程建议 PV **≤720p、≤30fps**。

### P2 — 模糊垫底

观感最「现代」，双路解码或运行时模糊在 Web/移动上成本高；优先**离线**合成。

### 不推荐

| 做法 | 原因 |
|------|------|
| 维持现状全屏非等比 expand | 必然压扁 |
| 整页改横屏 | 与「竖屏九宫格」产品定位冲突（PRD） |
| 每曲手搓竖版 MV | 成本高；可作精品曲特例，不作默认 |

---

## 6. 建议决策（可进 grill）

| # | 建议 |
|---|------|
| 1 | 立刻去掉裸 expand；上 ARC |
| 2 | 默认二选一：**顶栏 FIT 带**（完整 PV）或 **全屏 COVER**（氛围）；设置可切换 |
| 3 | `meta.video` 增加 `aspect` 与可选 `fit` |
| 4 | chart-agent 下载后写 DAR；可选 ffmpeg 预处理 |

---

## 7. 参考链接

- https://docs.godotengine.org/en/stable/tutorials/animation/playing_videos.html  
- https://docs.godotengine.org/en/stable/classes/class_videostreamplayer.html  
- https://docs.godotengine.org/en/4.6/classes/class_aspectratiocontainer.html  
- https://ffmpeg.org/ffmpeg-filters.html#scale-1  
- https://github.com/endcycles/ffmpeg-engineering-handbook/blob/main/docs/operations/scaling.md  
- https://en.wikipedia.org/wiki/Miku_Flick  
- https://www.sekaipedia.org/wiki/Settings （lane opacity，次级）  

---

## 8. 与本仓关系

- 现状：`scenes/play.tscn` `Video.expand = true` 全屏  
- 格位：`NineDotConfig.GRID_TOP` / `GRID_SIZE`  
- 生谱：`docs/skills/nine-dot-chart-agent/`  
- 本文只调研方案；落地前可 grill 默认「顶栏 FIT」vs「全屏 COVER」。
