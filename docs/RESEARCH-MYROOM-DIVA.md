# 调研：Project DIVA F / F 2nd — DIVA Room（My Room）与 AR

> 日期：2026-09-10  
> 目的：为 9-Dot **MyRoom 独立模块**对齐歌姬计划 F / F 2nd 玩法骨架；并厘清官方 **AR Mode** 与 Room 的关系。  
> 范围：玩法/信息架构/互动规则；**不**实现、不搬运版权资产。  
> 主要来源：Project DIVA Wiki（[ƒ Room](https://www.projectdiva.wiki/wiki/DIVA_Room_(%C6%92)) / [F 2nd Room](https://www.projectdiva.wiki/wiki/DIVA_Room_(F_2nd))）、SEGA 官方 F / F 2nd AR 页、hXcHector 攻略。

---

## 1. 一句话

**DIVA Room（日：DIVAルーム）** = 角色个人房间：布置 + **触摸沟通（タッチコミュ）** + 好感度 + 礼物/事件 + 迷你游戏。  
**AR Mode**（Vita 系）= 摄像头把角色叠到现实空间（AR Live 演出 / AR Portrait 合影）；与 Room **并列入口**，不是 Room 内子菜单。

9-Dot 用户期望：**独立模块** → 进入后选 **MyRoom 模式** 或 **AR 模式**；加载 **MMD** 与 Miku 互动。玩法对齐 F / F 2nd Room；AR 对齐 Vita 系 AR（无实体卡优先）。

---

## 2. F（ƒ）DIVA Room 核心

| 块 | 内容 |
|----|------|
| 入口 | 主菜单 → DIVA Room；开局仅 **Miku** 房，其它角色靠通关特定曲 NORMAL 解锁 |
| 触摸沟通 | 点角色进沟通模式；摸头发/脸、空处转眼、背面触控等 → 开心/困扰/生气/睡觉 |
| 好感节奏（F） | **轻抚到恰当时机**（睁一眼→再闭眼开心时停手）加分；过度/粗暴/戳脸降分 |
| 会话上限 | 每次可提升好感有限；冷却后气泡提示可再摸 |
| 生气 | 重复负面互动 → 强制结束沟通；需暂时离开房间冷静 |
| 好感等级 | Lv1–6/MAX（MAX 显示王冠）；每级内 gauge 约 0–10 |
| 迷你游戏 | **あっちむいてホイ**（猜拳 + 看方向）；约 3 次成功沟通后高概率邀请；先到 3 分 |
| 礼物 | 菜单送礼；反应好坏都加好感，高兴加更多 |
| 事件 | 摆放道具触发 Item Event；送礼触发 Present Event；已看过可跳过 |
| 布置 | 主题 / 家具 / 床头道具 / Gadget |

---

## 3. F 2nd DIVA Room 相对 F 的变化（建议对齐基准）

官方与 Wiki 强调 F 2nd **沟通更“手感化”**，更适合作为现代复刻主参考：

| 块 | F 2nd |
|----|--------|
| 房间解锁 | **开局全部房间可用**（相对 F 更宽松） |
| 触摸沟通 | **无轻/重抚区分**；抚触时右上角出现 **Heart Gauge** |
| Heart Gauge | 越满越好感越多；**涨满爆炸则本段不加好感**；反复爆炸 → 生气背对玩家 |
| Fever | 连续多次拉满好感后进 **Fever**：可狂戳加好感且心不易爆 |
| 和好 | 生气后需送礼和/或再填满心条 |
| 会话上限 UI | 右下角绿手势；达上限变淡+红圈，冷却后恢复 |
| 迷你游戏 | **あっちむいてホイ**（先到 2 分）+ **アルプス一万尺**（点圆/滑箭头，三回合加速） |
| お願い | 气泡请求：换模组 / 主题家具 / BGM / 相框；**角色自选结果**，玩家答应即可 |
| 事件 | 数量大增（Wiki ~143）；含料理、编织等「一起过日子」演出 |

**对 9-Dot 的建议对齐**：互动规则以 **F 2nd Heart Gauge + Fever + 生气/和好** 为主；迷你游戏先做 **あっちむいてホイ**，アルプス为后期；お願い / 布置 / 礼物做可削减 MVP。

---

## 4. AR Mode（F / F 2nd Vita）

| 模式 | 说明 |
|------|------|
| AR Live | 摄像头场景中放置角色（F 曾用 AR 卡；F 2nd **可不需实体卡**），播放已解锁 PV；可缩放；**不可当音游打谱** |
| AR Portrait | 现实背景合影；F 2nd 可双人、新姿势、保存布置 |
| PS3 对应 | Studio（Live Studio / Photo Studio），非摄像头 AR |

与 Room 关系：**同级功能**（官方页面常写作 DIVA ROOM / AR）。9-Dot Hub → MyRoom 模块 → **二选一：Room | AR** 符合原作心智。

---

## 5. 映射到 9-Dot（技术约束）

| 原作 | 9-Dot 方向 |
|------|------------|
| 自制引擎角色 | **MMD（.pmx 等）** 加载；表情/骨骼驱动沟通反馈 |
| Vita 前触 + 背触 | 手机：**前屏触摸分区**（头/脸/身）；背触用 **双指点空白/按钮模拟「背后」** 或省略背触支线 |
| 房间布置 | 简易场景（HDRI/低模房间）+ 后期道具；MVP 可固定一间「Miku Room」 |
| 好感存档 | `user://`（与曲库/设置并列） |
| AR | Godot 摄像头 + 平面放置（Web 弱；**APK 优先**）；AR Live = 播内置/用户曲 PV 或 Idle 动作 |
| 模块边界 | `scripts/myroom/`（或 `modules/myroom/`）独立于节奏玩法；Hub 只进入口 |

---

## 6. 明确非目标（调研边界）

- 不复制官方模组/房间美术/事件脚本原文  
- 不做完整商店经济 / 全事件图鉴（可分期）  
- Web 完整 AR 不作为 MVP 门禁  
- 不在 Room 内嵌九宫格音游判定  

---

## 7. 参考链接

- https://www.projectdiva.wiki/wiki/DIVA_Room_(%C6%92)  
- https://www.projectdiva.wiki/wiki/DIVA_Room_(F_2nd)  
- https://miku.sega.jp/f/en/ar.html  
- https://miku.sega.jp/f2/vita/en/divaroom_ar.html  
- https://miku.sega.jp/f2/ps3/divaroom.html  
- https://www.hxchector.com/hatsune-miku-project-diva-f-2nd-guide/  

---

## 8. 待 grill 的决策（预告）

1. 互动规则基准：F 时机抚触 vs **F 2nd Heart Gauge**（推荐后者）  
2. MVP 角色范围：仅 Miku vs 多角色  
3. AR MVP：Portrait / Live / 两者；平台（仅 APK vs 含桌面摄像头）  
4. 迷你游戏：先 Acchi Muite Hoi vs 全砍到后期  
5. 布置/礼物/お願い：MVP 含哪些  
6. MMD 资源来源与目录约定（`user://` vs 打包）  
