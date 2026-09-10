# 调研：免费 / 低门槛获取 MMD 资源用于 MyRoom（许可现实）

> 日期：2026-09-10  
> 目的：回答「如何免费获得**无需再许可**即可打进 APK 的 MMD」；给 9-Dot MyRoom 资源策略。  
> 结论先行：**几乎不存在「既是初音形象、又是标准 MMD/PMX、又可无个别作者许可地打进游戏包」的资源。** 可行路径是分层：占位用可商用/可分发许可素材 + 用户自备模型走 `user://`。

---

## 1. 为什么「免费下载的 Miku MMD」≠ 可打包进游戏

三层权利叠在一起：

| 层 | 谁 | 典型限制 |
|----|-----|----------|
| 角色 | Crypton（初音等） | [Piapro キャラクター利用ガイドライン](https://piapro.jp/license/character_guideline) / PCL / 海外 [CC BY-NC（原画）](https://piapro.net/intl/en_for_creators.html)。**非商用二次创作**空间大；**应用内同捆分发、商店上架**常超出自动许可，需个案判断或官方许可。 |
| 模型网格 | MMD 作者（Tda 等） | Readme 几乎一律：**禁止未改二次配布原模**、常禁商用、常禁 Unity/游戏引擎/公开 Avatar 分发。 |
| 发布站 | Bowlroll / DeviantArt 等 | 作者规约优先；Bowlroll 侧也提醒游戏引擎用途要在 Readme 写清。 |

社区共识（含 MMD4Mecanim 文档）：多数模型按**动画/静画**前提制作；要进自研游戏，须 **Readme 明示允许** 或 **作者书面同意**，否则不能当「无需许可」。

AI 站（如 Meshy）上的「CC0 Miku」多为 **非 PMX/MMD 骨骼** 的通用 3D，且角色权仍受 Crypton 约束——**不能**当成「免许可官方 Miku MMD」。

---

## 2. 「免费且相对无需再找作者」的现实选项

### 2.1 不做初音外观：开源 / 游戏友好许可角色（推荐作工程占位）

| 资源 | 许可要点 | 用途 |
|------|----------|------|
| [Unity-chan](http://unity-chan.com/)（UCL） | 明确面向游戏；遵守 UCL 可同捆 | Godot 需自转格式；作 **Room/AR 管线占位** 极合适 |
| 自研简易人形 / VRM 转 PMX（自有版权） | 你拥有全部权利 | 长期可控 |
| CC0 / MIT 的通用 anime-rig 模型（非 Crypton 角色） | 读清是否允许 binary 分发 | 占位或原创 OC |

这些**不是**歌姬官方模组，但能让 MyRoom 先跑通加载 / 抚触 / AR，不踩二次配布雷区。

### 2.2 初音形象：不能「无许可打包」，只能「用户自备」或「申请」

| 策略 | 说明 |
|------|------|
| **A. 用户导入（推荐与 Q6=B 一致）** | APK 不内置 Crypton 角色 PMX；引导用户把**其已合法持有且 Readme 允许私用**的模型拷入 `user://myroom/models/`。游戏只提供加载器。 |
| **B. 作者逐一授权** | 选定 1–2 个允许「非商用应用同捆」的改模，邮件/表单取得书面同意并附 Readme。 |
| **C. Crypton / 商用许可** | 上架或商用向产品走官方渠道；成本与周期不适合「免费无许可」假设。 |
| **D. 仅个人本机调试** | 开发者自己用私有模型测，**不提交 git、不分发**。 |

「从网上免费下一只 Tda Miku 打进 APK」在合规上 **基本不可行**。

### 2.3 动作 / 表情数据

- VMD 同样几乎都有作者规约；默认按**用户自备**或自做 idle/touch 动画。  
- 可用程序化：骨骼程序摆 pose + 表情 morph 插值，减少对第三方 VMD 的依赖。

---

## 3. 建议落地策略（写入需求）

1. **仓库 / 包内**：仅含 **自有或 UCL/明确可分发** 的占位模型（非 Crypton 商标外观，或极度简化的原创「青绿双马尾 OC」）。  
2. **运行时**：`user://myroom/models/<id>/` 扫描 PMX；首次可 seed **占位**，不 seed 他人 Miku。  
3. **关于页 / 导入页**：说明「请只导入你有权使用的模型；Crypton 角色请遵守 Piapro；作者 Readme 禁止游戏同捆的勿请求我们内置。」  
4. **多角色解锁（Q8=B）**：解锁的是**槽位/房间逻辑**；每个槽绑定的模型路径仍由用户或后续授权包提供。  

---

## 4. 参考

- https://piapro.jp/license/character_guideline  
- https://piapro.net/intl/en_for_creators.html  
- https://stereoarts.jp/（MMD4Mecanim：游戏利用须确认作者）  
- http://unity-chan.com/download/license.html（UCL）  
- Bowlroll 管理ブログ：游戏引擎用途与 Readme  

---

## 5. 一句话给产品

**免费、免再许可、可进 APK 的「真·初音 MMD」基本买不到；MyRoom 应做成「引擎 + 占位 + 用户合法导入」，而不是「内置网上下的 Miku」。**
