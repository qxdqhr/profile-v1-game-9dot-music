# MyRoom 实现计划（共享理解已确认）

> 依据：[REQUIREMENTS-MYROOM.md](REQUIREMENTS-MYROOM.md)  
> 平台门控：仅 APK；Web/桌面 Hub 隐藏或灰显入口。

---

## 模块边界

```
scripts/myroom/          # 逻辑（加载、沟通、好感、迷你游戏、礼物、布置、AR）
scenes/myroom/           # 入口分流、房间、AR、子 UI
res://myroom/placeholder/  # 可分发占位模型（UCL/自有 OC）
user://myroom/           # models/ · save（好感等）
```

Hub 只负责：`OS`/`Feature` 检测 → 进 `myroom_gate` 或提示「仅移动版」。

与节奏玩法隔离；共享：`SongLibrary` 通关计数（解锁）、`NineDotTheme` 可选。

---

## 里程碑

| 阶段 | 内容 | 完成标准 |
|------|------|----------|
| **M0 骨架** | 目录 + APK 门控 + 入口二分 UI（Room / AR 灰显）+ 占位模型加载探针 | ✅ 2026-09-11 |
| **M1 沟通** | 房间场景、触摸分区、Heart Gauge、Fever、生气/和好、好感存档 | ✅ 2026-09-11 |
| **M2 迷你游戏** | あっちむいてホイ + アルプス一万尺 | ✅ 2026-09-11 |
| **M3 礼物** | 礼物目录、偏好简表、送礼演出钩子 | ✅ 2026-09-11 |
| **M4 布置+お願い** | 主题/家具切换、お願い气泡 | ✅ 2026-09-11 |
| **M5 多角色解锁** | 槽位；官方曲 NORMAL 通关计数配置表 | ✅ 2026-09-11 |
| **M6 AR** | Portrait → Live（摄像头平面放置） | ✅ 2026-09-11：Portrait 合影 + Live 放置/待机；无摄像头时模拟背景 |

---

## M0–M5 落地摘要

| 路径 | 作用 |
|------|------|
| `myroom_platform.gd` | APK / editor / `myroom_debug` 门控 |
| `myroom_paths.gd` | `user://myroom/` |
| `myroom_cast.gd` | 6 槽 + `unlock_at` 阈值 |
| `myroom_progress.gd` | 好感/生气/冷却/Fever/布置/お願い/通关计数 |
| `myroom_comm.gd` | Heart Gauge + Fever + 爆心生气 + 和好 |
| `myroom_gifts.gd` | 礼物目录 + 偏好加分 |
| `myroom_decor.gd` | 4 主题 + 3 家具 |
| `myroom_onegai.gd` | 随机お願い |
| `myroom_acchi.gd` / `myroom_alps.gd` | 两款迷你游戏 overlay |
| `myroom_model_loader.gd` | glTF / 程序性 tint OC |
| `scenes/myroom/room.tscn` | 房间主 UI |
| `play_scene._notify_myroom_clear` | 官方 NORMAL+ 通关 +1 |

| `myroom_camera.gd` | CameraServer 前摄 / 模拟背景回退 |
| `myroom_ar_scene.gd` + `scenes/myroom/ar.tscn` | Portrait 合影 · Live 平面放置 · PNG 存 `user://myroom/photos/` |
| Android `permissions/camera` | export_presets 已开 |

### AR 游玩提示

- Gate → **AR 模式**（与 Room 并列）。  
- **Portrait**：角色叠在摄像头（或模拟）背景上，缩放后「合影」。  
- **Live**：点半透明地面放置，拖动移动，待机晃动，「截图」保存。  
- 真机需授权摄像头；编辑器无摄像头时自动用动态模拟背景。

---

## 暂不做

Web MyRoom、内置未授权 Miku、140+ 事件全文复刻、真实世界平面检测（ARCore）——当前为摄像头背景 + 虚拟地面投影。
