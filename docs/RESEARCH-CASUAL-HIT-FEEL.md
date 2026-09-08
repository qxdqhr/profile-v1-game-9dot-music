# 调研 + 排查：Hard/Extreme「按下无反馈 → Miss」

> 日期：2026-09-08  
> 方法：按 `research` skill — 一手/可追溯资料 + 对照本仓实现与谱面统计  
> 症状：Hard / Extreme 上感觉 note **已经按上了**，但**当时完全没有命中反馈**，随后变成 Miss  
> 相关：`docs/RESEARCH-RHYTHM-FEEL.md`（延迟/时钟）、`docs/REQUIREMENTS.md` v1.2

---

## 1. 结论摘要（先看这个）

| 问题 | 判断 |
|------|------|
| 判定窗是不是「休闲音游过严」？ | **基本不是主因**。Tap Good ±150ms 已接近/宽于 Muse Dash Great（±130）与 Arcaea Far（±100） |
| 更像 bug / 交互缺陷？ | **是**。窗外点击与点空 = **静默忽略**；Miss **无击打音/无振动**；与「按下无反馈」高度吻合 |
| 还可能是什么？ | 安卓 **音频延迟 + Clock 未按 Godot 公式补偿** → 系统性偏晚 → 落入窗外静默 → 再被 sweep Miss；Slide **抢先于 Tap**；触区偏紧 |

**一句话**：Hard/Extreme 物量上去后，把「静默拒收 + 延迟未校准 + Slide 抢输入」放大了；不是单纯把 Perfect 放宽就能修好。

---

## 2. 流行/休闲向音游：实现惯例（有出处）

### 2.1 判定窗宽度（对照）

| 游戏 | 窗（约） | 来源 |
|------|----------|------|
| **Muse Dash**（休闲向） | Perfect ±50ms；Great ±130ms | [NamuWiki Muse Dash/System](https://en.namu.wiki/w/Muse%20Dash/%EC%8B%9C%EC%8A%A4%ED%85%9C)；中文整理亦见 [233乐园转载](https://www.233leyuan.com/post-detail/2065444363633623040) |
| **Arcaea**（偏竞技触控） | Pure ≤50（亮 Pure ≤25）；Far ≤100；Lost >100；100–120 仍可「消掉」但算 Lost | [Arcaea Wiki Scoring](https://arcaea.fandom.com/wiki/Scoring)；[Fan Wiki timing](https://arcaea.miraheze.org/wiki/Gameplay_and_scoring) |
| **osu!**（OD 相关） | OD10 约 Great±19.5 / Ok±59.5 / Meh±99.5（ms） | [ppy/osu#34244](https://github.com/ppy/osu/issues/34244) |
| **9-Dot Tap（现状）** | P±50 / G±100 / Good±150 | `nine_dot_config.gd` |
| **9-Dot Slide** | P±80 / G±140 / Good±220 | 同上 |

解读：休闲向也常把 **「还能算打中」** 放到 **±100～130ms**；9-Dot 的 Good **并不更严**。玩家体感「严」往往来自 **延迟未对齐**（有效窗相对听感变窄）或 **按了却不算输入**。

### 2.2 命中 / Miss 反馈惯例

行业常见产品规则（来自玩法文档与开源行为，非「感觉」）：

1. **落在判定窗内** → 立即档位字 + 通常有击打音/粒子（Arcaea Far 仍有明确黄字反馈）。
2. **过晚自动 Miss / Lost** → 仍有 **Miss 字 + 视觉消失**，多数还有 miss 音或 combo break 提示。
3. **Arcaea 特例**：在约 100–120ms 点到会让 note **消失**，但仍记 Lost —— 「有消散反馈，但记 miss」（Wiki 明确写出）。
4. **osu notelock / empty hit**：窗内无物或锁键时，点击可无判定；但正式局对 **已过窗的 note** 仍会结算 Miss，而不是让玩家以为「系统没收到手」。

休闲手感核心不是「窗更宽」，而是：**每次有效意图都要有闭环反馈**（打中 / 打空 / Miss）。

### 2.3 校准与时钟（引擎级一手）

Godot 官方音游同步文档要求：

```text
time = get_playback_position()
     + AudioServer.get_time_since_last_mix()
     - AudioServer.get_output_latency()
```

来源：[Sync the gameplay with audio and music](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html)

Deemo 等休闲作把 **Audio–Video 校准** 做成正式设置（步进约 10ms / 5ms），承认设备延迟是默认前提：[DEEMO Wiki Settings](https://deemo.fandom.com/wiki/Settings)。

Muse Dash 明确：Early 多就减 offset，Late 多就加 offset（NamuWiki 同上）。

### 2.4 输入与触区

- 触控休闲作通常 **判定半径 ≥ 视觉**，密集谱仍靠「同轨优先最近 note」而非静默吞输入。
- 多 note 同轨：优先 **时间最近且未判定** 的那一个（osu / 多数下落音游）。
- Slide / Hold 有独立状态机；不应在「玩家以为在点 Tap」时静默绑到 Slide（需清晰视觉 + 接住反馈）。

---

## 3. 本项目对照：代码级排查

### 3.1 【高】窗外点击 / 点空 = 静默（与症状最吻合）

`play_scene.gd` `_finger_down`：

1. 先找 Slide Arm 候选；成功则只 `vibrate_arm()`，无判定字。
2. 再 `hit_node`；找不到节点 → `idle`，**无反馈**。
3. 找到节点但 `_find_tap_candidate` 失败（`|now−tMs| > 150` 或已 judged）→ 同样 `idle`，**无反馈**。
4. 稍后 `_sweep_misses` 在 `tMs + 150` 后 `_resolve(..., MISS, ..., play_hit=false)`。

玩家体感链：

> 看见圆快满 → 跟耳朵/习惯按下 →（实际已出窗或点偏）→ **无字无音** → 下一帧/稍后 HUD 闪 Miss 或结算里一堆 Miss。

这在 **Extreme（物量高、容错时间心理更紧）** 上会被放大。

### 3.2 【高】Miss 无击打音、无振动

`_resolve`：仅 `play_hit and grade != MISS` 才播 SFX；Miss 路径一律 `play_hit=false`。  
自动 sweep Miss 也无独立 miss 音。  
→ 即便 Miss 字写了，也容易被下一 note 的反馈盖掉，形成「完全没返回」。

### 3.3 【高】Clock 仍未按 Godot 公式补偿

`nine_dot_clock.gd` 仍只用：

```text
raw = get_playback_position() * 1000
now = raw + chart_offset + player_offset
```

缺 `get_time_since_last_mix()` / `get_output_latency()`；安卓上 latency API 又常不可靠（见前篇调研与 Forum）。  
典型结果：**画面/逻辑偏早，听感偏晚** → 玩家跟耳朵会 **系统性 Late** → 更容易掉出 ±150 → 触发 3.1 静默。

### 3.4 【中】Slide 优先于 Tap

`_finger_down` **永远先** `_find_slide_candidate`。  
Extreme `bv19k-aimuji`：**145 slide / 264 tap**。  
若触点落在某条边的 Arm 带内（`tMs−700 … tMs+150`），本来想点的格上 Tap 会被抢走 → 短振一下（若有）然后划失败 Miss，或玩家以为「点了没反应」。

### 3.5 【中】触区与视觉

- 命中半径 = `0.38 * cell`；视觉填满圆约 `1.08 * node_r`。  
- 紧张连点时易「点在亮圆上但中心判定没吃到」→ 再次静默。  
休闲作通常触区 ≥ 视觉。

### 3.6 【低】判定窗本身

相对 Muse Dash / Arcaea，**不是「休闲标准下过严」**。  
若校准正确且输入有反馈，±150 Good 对竖屏九宫格足够休闲。

### 3.7 谱面密度（数据）

| 谱 | notes | tap/slide | 同节点 tap 最小间隔 |
|----|--------|-----------|---------------------|
| aimuji easy | 75 | 63/12 | ~16.8s |
| aimuji hard | 226 | 170/56 | ~2.2s |
| aimuji extreme | 409 | 264/145 | **219ms**（且 16 对同节点落在 700ms approach 内） |
| metronome extreme | 66 | 50/16 | 1.8s |

Extreme 的问题主要是 **物量 + Slide 占比 + 偶发同节点接近**，不是同帧多押（maxStack=1）。

---

## 4. 因果图（Hard/Extreme）

```text
音频延迟未进 Clock / 无校准
        ↓
  跟耳朵点 → 逻辑偏 Late
        ↓
  |Δt| > Good(150) 或 点偏 / 被 Slide 抢走
        ↓
  _finger_down 静默 idle     ←── 「按了没反馈」
        ↓
  sweep 记 Miss（无 SFX）
        ↓
  结算大量 Miss，体感「手感崩了 / 判定太严」
```

---

## 5. 假设优先级清单（建议验证顺序）

1. **静默拒收**：开发叠加层记录每次 `finger_down` 的 `now`、最近 note `tMs`、是否命中候选；复现「无反馈」时应看到大量 `reject: out_of_window | no_node | slide_steal`。
2. **延迟**：设置 Offset 扫 +80～+180ms；若 Late Miss 明显下降 → Clock/校准优先于改窗。
3. **Miss 反馈**：临时给 Miss 加音效+字停留 300ms；若「无反馈」感消失，则是反馈缺陷而非没判到。
4. **Slide 抢 Tap**：统计 steal 次数；极端可试「同点优先距离更近的 Tap」。
5. **触区**：临时 `NODE_HIT_RADIUS_FRAC *= 1.25` 做 A/B。
6. **最后才改窗**：例如 Good → ±180/200（休闲向），且仅在 1–3 验证后。

---

## 6. 建议修复方向（调研结论 → 产品，尚未开工）

| 优先级 | 改动 | 对齐的业界惯例 |
|--------|------|----------------|
| P0 | 窗外/点空也给反馈：`Empty` / `Miss Early` / `Too Late` + 轻 miss 音 | 每次触控有闭环 → **✅ 2026-09-08 已落地** |
| P0 | Clock 三项式 + 单调；引导校准 | Godot 文档 / Deemo → **Clock ✅；校准页仍待** |
| P0 | Miss 与成功命中同等可见（字+FX；可选弱振） | Arcaea Lost 仍有字 → **✅** |
| P1 | Tap vs Slide 仲裁：更近节点优先 Tap；或 Arm 需更明确起点 | 避免抢输入 → **✅ 节点优先** |
| P1 | 触区 ≥ 视觉填满圆 | 休闲触控 → **✅ 0.50 cell** |
| P2 | 可选放宽 Good（±180）作「休闲档」 | Muse Dash 量级 |

---

## 7. 资料索引

| 资料 | 用途 |
|------|------|
| [Godot Sync with audio](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html) | 时钟公式 |
| [Muse Dash System (Namu)](https://en.namu.wiki/w/Muse%20Dash/%EC%8B%9C%EC%8A%A4%ED%85%9C) | 休闲窗 ±50/±130 |
| [Arcaea Scoring Wiki](https://arcaea.fandom.com/wiki/Scoring) | Pure/Far/Lost；Lost 仍可消 note |
| [DEEMO Settings](https://deemo.fandom.com/wiki/Settings) | 双校准 |
| [ppy/osu#34244](https://github.com/ppy/osu/issues/34244) | osu 窗数量级 |
| 本仓 `scripts/play_scene.gd` / `nine_dot_clock.gd` / `nine_dot_config.gd` | 现状 |
| `charts/bv19k-aimuji/*.json` | Extreme 密度 |

---

## 8. 与前篇关系

- `RESEARCH-RHYTHM-FEEL.md`：延迟分层、Slide Arm、Offset 语义。  
- **本文**：聚焦「按下无反馈」产品缺陷 + Hard/Extreme 放大机制 + 休闲作窗宽对照。  
两者一起支撑下一轮修复优先级（建议先 P0，再考虑放宽窗）。
