# 调研：音游手感 / 判定实现方案（对照 9-Dot Game）

> 状态：调研中（2026-09-07）  
> 动机：APK 真机上 **Slide 几乎划不到**、**Tap 总感觉要提前点**。先梳理业界常见方案与规范，再对照本项目现状，为后续优化排优先级。  
> 范围：公开资料 + 本仓现有实现；**不包含**本次代码改动。

---

## 1. 玩家症状 → 技术分层

音游「手感差」通常不是单一 bug，而是多层延迟与判定模型叠在一起。常见拆法（Exceed7 / Rhythm Quest / LastExceed 等一致）：

| 层 | 含义 | 玩家体感 |
|----|------|----------|
| **Audio latency** | 混音缓冲 → 扬声器真正发声 | Note 看起来「到了」，耳朵还没听到拍点 → 会主动提前点 |
| **Input latency** | 触屏采样 → 引擎收到事件 | 点得「刚好」却判 Late / Miss |
| **Visual / display latency** | 提交帧 → 面板显示 | 跟画面点会偏 Early/Late |
| **Logic / clock error** | 用错时间源、块状步进、未补偿 mix | 桌面 OK、安卓炸；长曲逐渐漂 |
| **Judge model** | 窗宽、对称性、Slide 完成条件过严 | 「明明划过了却 Miss」 |

**经验规则（玩家社区 + 开发日志共识）**：

- 单点校准永远测到的是 **端到端组合**（听音点拍 ≈ audio + input；看画面点 ≈ visual + input），很难单独拆开。
- 先 **降低** 可降延迟（音频缓冲、有线耳机、高帧率），再靠 **Offset 校准** 吃掉剩余。
- 蓝牙耳机常带来 **100ms+** 额外延迟，校准值应按设备/输出路径分别存，不宜全局一套。

---

## 2. 时间轴：业界「正确做法」摘要

### 2.1 原则

1. **音频是 master**，禁止用 UI 帧累加当曲时间（本项目 PRD 已写死）。
2. 判定只比：`inputSongMs - note.tMs`（或等价），**不要**用「画面像素碰到判定线」当唯一真理。
3. 渲染用 `note.tMs - songMs` 映射位置；逻辑与渲染可共用同一 `songMs`，但输入时刻应尽量贴近事件发生时的 song 时间。

### 2.2 Unity / 通用（大量音游文章同源）

- 用 **DSP / 采样时钟**（如 `AudioSettings.dspTime`、`timeSamples`），避免 `Time.time`。
- `Play()` 启动抖动大 → 常用 **`PlayScheduled(futureDsp)`** 把开场钉在可预期未来时刻。
- 缓冲抖动：多帧采样取中位数 / 拒绝回退（monotonic clamp）。
- 参考：[Coding to the Beat (Gamasutra/GD)](https://www.gamedeveloper.com/audio/coding-to-the-beat---under-the-hood-of-a-rhythm-game-in-unity)、[Rhythm Quest Devlog 4](https://rhythmquestgame.com/devlog/04.html)、[Exceed7 Rhythm Game Crash Course](https://exceed7.com/native-audio/rhythm-game-crash-course/index.html)。

### 2.3 Godot 官方推荐（与本引擎直接相关）

文档 [Syncing games to audio](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html)：

```text
time = get_playback_position()
      + AudioServer.get_time_since_last_mix()
      - AudioServer.get_output_latency()
```

要点：

- 裸 `get_playback_position()` **按 mix 块跳变**，同帧多次调用可能相同。
- 结果可能抖动 → **丢弃小于上一帧的值**。
- **Android 上 `get_output_latency()` 常返回 0**（Godot Forum 2026 多例：桌面正常、手机固定约百毫秒级「画面早于声音」）。社区共识：**必须做玩家 Offset 校准**，不能指望系统 API 自动吃完。

本项目现状（`nine_dot_clock.gd`）：

```text
raw_ms = int(player.get_playback_position() * 1000)
now_ms = raw_ms + chart_offset_ms + player_offset_ms
```

**缺口**：未加 `get_time_since_last_mix()`，也未减 `get_output_latency()`；安卓上后一项即使为 0，前一项仍能改善「块状时间」带来的判定抖。

### 2.4 Offset 语义约定（务必写进产品规范）

综合 [offsets-in-rythmgames](https://github.com/LastExceed/offsets-in-rythmgames)、喵斯快跑社区通用帖、Phaser 判定文：

| 名称 | 作用 | 典型符号约定 |
|------|------|----------------|
| **Global / Audio offset** | 补偿设备听感延迟 | 常为负：音乐相对逻辑「提前播」或逻辑时间「滞后听感」 |
| **Visual / Video offset** | 补偿显示延迟（下落物与听感对齐） | 常为负 |
| **Local / Chart offset** | 单曲制谱不准 | 改 note 时间，勿当设备延迟 |
| **Input / Calibration offset** | 校准页统计出的平均偏差 | 符号必须在 UI 与代码一致 |

本项目设置文案：「正值更晚判定」= 增大 `AppSettings.offset_ms` 会让 `now_ms` 变大 → 同一物理点击相对 `tMs` 更偏 Late。若玩家「总要提前点」，在 **听感正确、画面偏早** 的典型安卓模型下，往往需要 **正的听感补偿或负的视觉补偿**——应用校准页实测，而不是猜符号。

---

## 3. 校准流程（产品规范级）

业界可落地的最小规范：

1. **听拍校准**：稳定节拍（无复杂谱），连续点 20–40 次；去极值后取平均偏差 → `calibrationOffsetMs`。
2. **可选：看画面校准**：得到 visual+input；与听拍差可近似 audio−visual。
3. **UI**：实时 Early/Late 直方图；标准差过大则拒绝保存并提示重测。
4. **存储键**：至少 `deviceId / 输出设备类型（有线|外放|蓝牙）`；换耳机重校。
5. **稳定性验收**：同一校准值，**重开一局 / Retry 后偏差应可复现**（Exceed7：校准飘 = 程序启动抖动，比窗口宽更伤手感）。

Rhythm Quest Devlog 10：校准重点放在 **audio vs video**，并承认「跟画」里的 visual+input 玩家会自然适应一部分。

---

## 4. 判定窗口：行业参照

Exceed7 整理的部分游戏 **最高档窗口**（约）：

| 游戏 | Perfect 量级 |
|------|----------------|
| DDR | ~15ms |
| 太鼓等 | ~20–33ms |
| Arcaea / Pop'n 等 | ~25ms |
| VOEZ | ~30ms |
| Deemo | ~50ms |
| Dynamix | ~59ms |
| Cytus | ~70ms |

Phaser 文示例配置（教学向）：Perfect ≤32 / Great ≤70 / Good ≤110 / Miss >140，并强调 **Early/Late 分向反馈**。

**本项目 PRD / 实现**：±50 / ±100 / ±150 ms（偏宽松，接近 Deemo 档）。  
→ 「总要提前点」**更像时钟/延迟未对齐**，而不是窗口太窄。窗口再放宽只能「糊过」，不能根治「系统性 Early 需求」。

规范建议：

- 窗口做成 **数据表**，可按难度覆盖。
- 结算与判定反馈拆开：**档位** + **Early/Late**（练习价值远高于只显示 Great）。
- 对称窗可先保留；若真机校准后残差仍偏一侧，再考虑 **非对称窗**（少见，优先修 offset）。

---

## 5. Slide / 滑动类：业界模型 vs 本项目

### 5.1 常见模型

| 方案 | 代表 | 核心 |
|------|------|------|
| **路径跟踪 + 跟随圈** | osu! slider | 沿曲线进度；手指需落在 follow 半径内；时长与路径绑定 |
| **区间/传感器序列** | maimai DX | 粗粒度触区序列；终点区停留时间给 **额外时间宽容** |
| **轨迹贴合 + 完成时刻** | Cytus/Deemo 类黄键等 | 需蹭过轨迹；玩家常抱怨「必须大幅度蹭」才算 |
| **短向量 flick** | 多数手机音游 | 按下后短时位移+方向；完成时刻用抬起或达阈值位移 |

maimai 要点（[How MaiMai DX Judges Slides](https://listed.to/@donmai/44545/how-maimai-dx-judges-slides)）：

- Slide **不是**「在某一个瞬时点刚好划完」的窄窗；Critical Perfect 可达 **±233ms** 量级，并按路径终点区占比再放宽。
- 判定与 **slide 主动时长 `ta`**、终点区距离占比相关。

osu SliderInputManager 思路：用当前 song 时间算路径期望点，再测触点是否在 follow 半径内（跟踪态机）。

### 5.2 本项目当前逻辑（易导致「划不到」）

实现：`play_scene.gd` + `NineDotConfig`

| 规则 | 现状 | 风险 |
|------|------|------|
| 接住时刻 | `finger_down` 时 `\|now - tMs\| ≤ 150ms` 且靠近 **起点** | 玩家常在接近圈出现后就按下并开始滑；若按下偏早则 **根本进不了 slide 手势**，后续 drag 被当成 idle |
| 中途 | 离边距 > `2 * band` 记 `off_band` | 真机胖手指 / 斜滑易出带；抬起直接 Miss |
| 完成 | 进度 ≥ **70%** 才结算 | 短边 + 抬手早 → Miss |
| 结算时刻 | 达 70% 或抬起时的 `now` 对 `tMs` | Slide 若被理解为「整段动作」，却用 **单点瞬时窗** 量完成时刻 → 慢滑必 Late/Miss |
| 输入源 | `Control.gui_input` 的 ScreenTouch/Drag | 需确认是否漏事件、是否与滚动手势冲突；安卓偶发丢 touch |

**与「划不到」高度吻合的假设（待真机验证）**：

1. **接住窗口过窄 / 接住时机错误**：应允许在 `tMs - approach` 内按下并 lock 边，在滑动过程中持续有效，在 `[tMs - W, tMs + W]` 或「到达终点附近的时间」结算。  
2. **完成条件用瞬时窗套长动作**：应改为「路径完成度 +（可选）到达终点时间相对 `tMs` 的宽容」，或给 Slide 单独更宽的时间窗（参考 maimai）。  
3. **起点吸附过严**（`near_start` 或 progress≤0.25）：斜滑、从边中段切入会被拒。  
4. **未区分「方向速度」**：当前不要求最小位移速度；反而可能在误触时锁错边——但「划不到」主因更可能是 1–3。

### 5.3 可借鉴的 Slide 产品规范（建议草案）

1. **生命周期**：`Arm（可接）→ Tracking（跟踪）→ Judge（结算）→ Consume`。  
2. **Arm**：`tMs - ArmEarly`～`tMs + ArmLate`（ArmEarly 可接近 approach，如 300–500ms）。  
3. **Tracking**：触点到线段距离 ≤ band；允许短暂离带（grace N ms）再回，避免一次毛刺直接 Miss。  
4. **完成**：progress ≥ P（可先 0.55–0.70）且方向正确；**结算时间**用「首次达到 P 的时刻」或「抬起时刻」二者取更优策略需 A/B。  
5. **时间窗**：Slide 专用，至少不低于 Tap 的 1.5–2×，或随边长/期望滑时缩放。  
6. **反馈**：跟踪中显示进度条/光点跟随；Miss 原因拆分（早接失败 / 离带 / 进度不足 / 时机）。

---

## 6. 移动端 / APK 特有坑

| 来源 | 现象 | 对策方向 |
|------|------|----------|
| Godot Android `output_latency≈0` | 系统补偿失效，常见画面早于声音约百毫秒 | 强制校准；文档化默认建议值区间 |
| 音频缓冲过大 | 整体延迟↑ | 导出/引擎侧低延迟路径（OpenSL ES fast track 等，社区改 driver 讨论）；优先 WAV/预解码 |
| 触控采样 | 丢点、合并、边缘手势 | 用裸 touch 索引；关闭父级滚动；调试绘制触点轨迹 |
| 击打音效延迟 | 「听着不对」 | 短 hit 用最低延迟通路；或弱化依赖击打音（Exceed7：response sound 无法用 offset 前移） |
| 断触 / 吃音设备 | 手感玄学 | 设置页提示；无法软件完全修复 |
| 帧率不稳 | 输入贴帧检查时窗口等效变歪 | 输入时刻用事件时间 + audio clock，避免「只在 _process 里采样键位」 |

Godot Forum 案例：手机端约 **165ms** 画面早于拍点，靠万能 Offset 解决——与本项目「要点提前」高度同型。

---

## 7. 本项目对照清单（Gap）

| 项 | 业界常见 | 9-Dot 现状 | 优先级（手感） |
|----|----------|------------|----------------|
| 音频 master | 是 | 是 | — |
| mix 补偿公式 | Godot 官方三项式 | 仅 `get_playback_position` | **P0** |
| 输出延迟 API | 减 latency | 无；且安卓常为 0 | P0（+ 校准） |
| 玩家校准页 | 节拍点 + 统计 | 仅手动滑条 Offset | **P0** |
| Audio / Visual 双偏移 | 常见 | 仅单一 `offset_ms` | P1 |
| Early/Late 反馈 | 强烈建议 | 仅档位名 | P1 |
| Tap 窗 | 数据化 | 50/100/150 常量 | P2 |
| Slide 生命周期 | Arm/Track/Judge | down 瞬间接住 + 70% + 瞬时窗 | **P0** |
| Slide 时间宽容 | 明显宽于 Tap | 与 Tap 同窗 | **P0** |
| 离带 grace | 常见 | 一次出带抬起即 Miss | P1 |
| 调试：触点/判定带可视化 | 开发标配 | 无 | P1（排障） |
| 按设备存校准 | 推荐 | 全局 ConfigFile | P2 |
| 原生低延迟音频 | 高端方案 | 未做 | P3 |

---

## 8. 与当前症状的假说排序

### A. 「Tap 总要提前点」

1. **安卓音频输出延迟未进入 clock**（最常见）：逻辑/画面按「已 mix 的位置」走，耳朵听到的更晚 → 玩家跟耳朵会感觉「要点更早」。  
2. Offset 默认 0，且无校准引导。  
3. 次要：`get_playback_position` 块状误差造成判定边界抖。

**验证**：设置里把 Offset 调到 +80～+180ms 试听是否「突然对齐」；若对齐，即可确认是延迟模型而非谱面。

### B. 「Slide 从来划不到」

1. **必须在 ±150ms 内于起点按下**才能进入 slide 状态——跟听感不准叠加后，按下时刻经常落在窗外 → 整段滑动无效。  
2. 完成仍用 ±150ms 量「划完瞬间」。  
3. 70% + 双倍 band 在真机手指下过严。  
4. 较少见：gui_input 丢 drag（可用轨迹 debug 排除）。

**验证**：临时把 `JUDGE_GOOD_MS` 对 slide 接住放宽到 400–500ms、完成度降到 0.5，看 Miss 率是否断崖下降——若是，则属模型问题而非「玩家不会滑」。

---

## 9. 建议的后续工作包（仅规划，本调研不实施）

1. **Clock v2**：官方三项式 + monotonic；日志打印 `playback` / `since_mix` / `latency`。  
2. **校准场景**：听拍 24 击 → 写入 offset；文案与符号单测。  
3. **Slide v2**：Arm/Track/Judge；Slide 独立窗；离带 grace；Miss 原因枚举。  
4. **手感调试叠加层**（开发开关）：note 判定带、触点、Early/Late ms、当前 songMs。  
5. **真机矩阵**：至少 2 台安卓 ×（外放 / 有线）；记录默认建议 offset。

---

## 10. 主要资料索引

| 资料 | 用途 |
|------|------|
| [Godot: Syncing games to audio](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html) | 引擎时钟公式 |
| [Godot Forum: 165ms mobile delay](https://forum.godotengine.org/t/rhythm-game-has-a-165-ms-delay-running-on-mobile/133858) | 安卓 latency API 失效 |
| [Exceed7 Native Audio – Rhythm Game Crash Course](https://exceed7.com/native-audio/rhythm-game-crash-course/index.html) | 延迟分类、校准、击打音 |
| [Rhythm Quest Devlog 4 / 10](https://rhythmquestgame.com/devlog/04.html) | DSP 时间、校准产品设计 |
| [LastExceed/offsets-in-rythmgames](https://github.com/LastExceed/offsets-in-rythmgames) | Audio/Visual offset 语义 |
| [Coding to the Beat](https://www.gamedeveloper.com/audio/coding-to-the-beat---under-the-hood-of-a-rhythm-game-in-unity) | Unity 音频时钟经典文 |
| [Medium: latency-free sync Android](https://medium.com/@thibautdumont/rhythm-game-with-unity3d-achieve-latency-free-sync-android-and-other-platforms-c05fa8e2718b) | 安卓原生时间戳思路 |
| [Phaser 音游判定系统（PlumePHP）](https://plumephp.com/phaser-rhythm-game-timing-window-2026/) | 中文：窗、校准、Early/Late |
| [喵斯快跑 Offset 通用帖（TapTap）](https://www.taptap.cn/moment/15208093797321190) | 玩家侧校准与设备坑 |
| [How MaiMai DX Judges Slides](https://listed.to/@donmai/44545/how-maimai-dx-judges-slides) | Slide 宽窗与终点区宽容 |
| osu! `SliderInputManager` | 路径跟随判定参考实现 |
| 本仓 `docs/REQUIREMENTS.md`、`nine_dot_clock.gd`、`play_scene.gd` | 现状 SSOT |

---

## 11. 结论（一句话）

真机「提前点」优先怀疑 **安卓音频延迟 + Clock 未按 Godot 公式补偿 + 缺少校准**；「Slide 划不到」优先怀疑 **用 Tap 瞬时窗去接住/结算一段滑动动作**，而不是单纯把判定数字再放大糊弄过去。
