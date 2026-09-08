# 调研：Godot UI / HUD 相关 Agent Skills

> 日期：2026-09-08  
> 目的：优化竖屏音游（9-Dot）菜单、HUD、主题、Control 布局与 juice/反馈时，可选用的 Agent Skills 清单。  
> 主源：[thedivergentai/gd-agentic-skills](https://github.com/thedivergentai/gd-agentic-skills)（Godot 4.7+，约 97 Domain Skills；索引见 `skills_index.json`）

---

## 安装提示

本 monorepo **已嵌套 submodule**（与 mattpocock 同级）：

`packages/sa2kit-skill/third-party/gd-agentic-skills`  
（`@` / 相对 symlink 即可；克隆须 `--recursive`）

亦可经 skills.sh（勿 `--all`）：

```bash
npx skills add thedivergentai/gd-agentic-skills
# 按需单 skill，例如：
npx skills add thedivergentai/gd-agentic-skills/skills/godot-ui-containers
```

---

## 1. UI & UX（官方分组，5 个）

来源：仓库 README「🎨 UI & UX」+ `skills_index.json` / `SKILL.md` 描述。

| Skill | 一句话用途 |
|-------|------------|
| **godot-input-handling** | `InputMap` / `InputEvent`、手柄、重绑、死区、输入缓冲；含手柄与无障碍向输入能力。 |
| **godot-ui-containers** | 响应式布局：`Container` 族、锚点、size flags、`stretch_shrink`、虚拟列表与动态菜单/HUD 排布。 |
| **godot-ui-rich-text** | `RichTextLabel` + BBCode、自定义 `RichTextEffect`、可点链接与动态格式化文案。 |
| **godot-theme-easter** | 季节主题运行时注入（StyleBox 复制）、弹性 juice（wobble/bounce）、彩纸/闪光，且不污染共享 `.tres`。 |
| **godot-ui-theming** | `.theme` / StyleBox / **自定义字体** / 继承与覆盖、动态换肤与 DPI/分辨率缩放相关管理脚本。 |

说明：库内**没有**单独的 `godot-accessibility` / `godot-fonts` / `godot-resolution` skill；字体落在 **theming**，无障碍侧重 **input-handling**，stretch/分辨率分散在 **ui-containers** + **platform-*** / **adapt-***。

---

## 2. 相邻 Skills（Tween / 动画 / 平台 / 音游 / Juice）

与菜单、HUD、反馈、竖屏/Web 强相关，但不在「UI & UX」五件套内。

### 2.1 Juice / 动效 / 视觉反馈

| Skill | 一句话用途 |
|-------|------------|
| **godot-tweening** | `Tween` 程序化动画：UI 过渡、缓动、并行/链式、生命周期；juice / game feel 核心。 |
| **godot-animation-player** | 时间轴动画（Value/Method/Audio/Bezier）、回调与 RESET；适合菜单开场/结算演出轨。 |
| **godot-2d-animation** | `AnimatedSprite2D` / 剪纸骨骼；含 squash/stretch 等表现向动画（偏角色/图标，非 Control 布局）。 |
| **godot-particles** | `GPUParticles2D/3D` 爆炸、拖尾、命中 VFX；判定反馈粒子。 |
| **godot-shaders-basics** | CanvasItem 闪白、溶解、后处理等；命中/Miss 闪光与屏幕特效。 |
| **godot-camera-systems** | 跟随、trauma 震屏、死区；可做判定重击时的镜头反馈（注意竖屏 Web 慎用过猛）。 |

### 2.2 输入 / 无障碍 / 触控（补充）

| Skill | 一句话用途 |
|-------|------------|
| **godot-input-handling** | （已列 UI）重绑、缓冲、手柄；无障碍入口关键词在此。 |
| **godot-platform-mobile** | 触控、虚拟摇杆、响应式 UI、刘海 safe area、竖屏 orientation。 |
| **godot-adapt-desktop-to-mobile** | 桌面→手机：触控方案、**小屏 UI 缩放**、移动 GPU/电量。 |
| **godot-adapt-mobile-to-desktop** | 手机→桌面：键鼠、**resolution scaling**、展开布局与设置页。 |
| **godot-platform-desktop** | 窗口/全屏/分辨率、设置菜单、键位重映射。 |
| **godot-platform-web** | HTML5/WebGL 导出、桥接与加载壳；竖屏 Web 音游部署相关。 |

### 2.3 字体 / 主题 / Control 架构

| Skill | 一句话用途 |
|-------|------------|
| **godot-ui-theming** | （已列）字体与 Theme 统一皮肤；含 ui_scale / theme swap 类脚本。 |
| **godot-composition-apps** | Control 重 UI / 设置面板的组合架构（Orchestrator + 组件）；偏工具型界面，非玩法实体。 |
| **godot-dialogue-system** | 打字机、立绘、分支对话 UI（结算叙事/教程可选）。 |
| **godot-inventory-system** | 槽位与拖放 UI 模式（本项目九宫格非背包，仅作 Control 交互参考）。 |
| **godot-agent-vision** | Agent 截图 + 视觉 QA（层级/对比度/排版受体）；审 HUD 构图时用，非运行时系统。 |

### 2.4 音游 / 音频 / 转场（竖屏节奏 HUD 强相关）

| Skill | 一句话用途 |
|-------|------------|
| **godot-genre-rhythm** | BPM 指挥、延迟补偿、判定窗、连击分、谱面加载；驱动判定条/判定字 HUD 逻辑。 |
| **godot-audio-systems** | AudioBus、交叉淡入、池化；与判定音效、BGM 同步相关。 |
| **godot-scene-management** | 异步加载、淡入淡出、加载屏；选歌→游玩→结算转场。 |
| **godot-signal-architecture** | 判定/连击 → HUD 更新的信号上行解耦。 |

---

## 3. 其他流行源（简要）

| 来源 | 相关 Skill | 备注 |
|------|------------|------|
| [skills.sh · gamedev-skills/awesome-gamedev-agent-skills](https://www.skills.sh/gamedev-skills/awesome-gamedev-agent-skills) | **godot-ui-control**、**godot-animation**；另有跨引擎 **game-ui-ux** / **game-feel** / **input-systems** | `godot-ui-control`：Control 锚点 + Container + Theme + 键鼠/手柄焦点导航；动画走 `godot-animation`（含 Tween）。安装量大，偏「单 skill 打包」。 |
| [skills.sh · zate/cc-godot](https://skills.sh/zate/cc-godot) | **godot-ui**（另有 development/optimization/debugging） | 一体式 UI 专家：Control、Theme、菜单/HUD/背包/对话模式；体量小、安装命令 `npx skills add zate/cc-godot --skill godot-ui`。 |
| Divergent AI 同库 | **godot-master** | 总编排，非专精 UI；大上下文，HUD 迭代不优先。 |

结论：UI 深度与模块化仍以 **gd-agentic-skills** 的 Domain Skills 最全；若只要「一个 UI skill」，可备选 `zate/cc-godot` 的 `godot-ui` 或 awesome 的 `godot-ui-control`。

---

## 4. 竖屏音游 HUD：优先装哪些

针对 **9-Dot（竖屏 Web / 触控 / 判定反馈 / 菜单主题）**，建议顺序：

| 优先级 | Skill | 为何先装 |
|--------|-------|----------|
| P0 | **godot-ui-containers** | 九宫格 HUD、锚点、竖屏 stretch、安全区外的布局基础。 |
| P0 | **godot-ui-theming** | 统一 Theme/字体/判定字样式；避免到处 `add_theme_override` 散落。 |
| P0 | **godot-tweening** | Perfect/Miss 字弹跳、连击弹、按钮按压缩放等 juice。 |
| P1 | **godot-input-handling** | 触控/重绑/缓冲；与无障碍、输入延迟调试相关。 |
| P1 | **godot-genre-rhythm** | 判定窗与 HUD 文案/连击数据模型对齐（非纯皮肤）。 |
| P1 | **godot-platform-mobile**（或 **adapt-desktop-to-mobile**） | 刘海、orientation、触控命中区。 |
| P2 | **godot-particles** / **godot-shaders-basics** | 命中粒子与闪白。 |
| P2 | **godot-scene-management** | 菜单↔游玩↔结算转场。 |
| P2 | **godot-platform-web** | 若继续打磨 HTML5 导出与加载体验。 |
| 可选 | **godot-theme-easter** | 只借「运行时 StyleBox + 弹性 juice」手法，不必真做复活节皮。 |
| 可选 | **godot-agent-vision** | 需要 Agent 对照截图审 HUD 时再装。 |

### 建议安装命令（竖屏节奏 HUD 第一批）

```bash
npx skills add thedivergentai/gd-agentic-skills/skills/godot-ui-containers
npx skills add thedivergentai/gd-agentic-skills/skills/godot-ui-theming
npx skills add thedivergentai/gd-agentic-skills/skills/godot-tweening
npx skills add thedivergentai/gd-agentic-skills/skills/godot-input-handling
npx skills add thedivergentai/gd-agentic-skills/skills/godot-genre-rhythm
```

---

## 5. 与本仓文档关系

- 节奏手感：`docs/RESEARCH-RHYTHM-FEEL.md`  
- 打击感：`docs/RESEARCH-CASUAL-HIT-FEEL.md`  
- 本文专注 **Agent Skills 选型**，不重复玩法公式；实现时 DIA：查 `skills_index.json` → 读对应 `SKILL.md` → 再写代码。

---

## 参考链接

- https://github.com/thedivergentai/gd-agentic-skills  
- https://raw.githubusercontent.com/thedivergentai/gd-agentic-skills/main/skills_index.json  
- https://www.skills.sh/thedivergentai/gd-agentic-skills  
- https://www.skills.sh/gamedev-skills/awesome-gamedev-agent-skills/godot-ui-control  
- https://skills.sh/zate/cc-godot/godot-ui  
