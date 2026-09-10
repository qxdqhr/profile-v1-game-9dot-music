# 调研：osu! Songs 曲包加载 → 9-Dot 外置 `songs/` 设计参考

> 日期：2026-09-10  
> 目的：对照 osu! 官方「Songs 目录 + 可导入曲包」模型，评估把 9-Dot 现行 `res://charts/<id>/` 外置为用户可编辑曲包目录的路径。  
> 范围：加载/目录约定/可写路径；**不**实现、不改玩法 schema。

---

## 1. 现状（9-Dot）

| 项 | 现状 |
|----|------|
| 发现 | `SongLibrary` 扫 `user://songs/<cat>/<id>/meta.json`（首次从 `res://charts` seed） |
| 单曲目录 | `meta.json` + `easy|normal|hard|extreme.json` + `audio.ogg` + `video.ogv` |
| 路径 | 媒体相对 set 根；兼容绝对 `://` |
| 可写性 | 运行时曲库在 `user://songs`；仓库 `charts/` 仍为发版源 |

Schema 摘要见 `docs/skills/nine-dot-chart-agent/reference-schema.md`。

---

## 2. osu! 官方：Songs 如何组织与加载

### 2.1 Songs 目录（稳定版程序文件）

来源：[osu! wiki · Program files](https://raw.githubusercontent.com/ppy/osu-wiki/master/wiki/Client/Program_files/en.md) / [osu.ppy.sh Program files](https://osu.ppy.sh/wiki/en/Client/Program_files)

要点摘录：

- **Songs** 存放玩家谱面；通常含 `.osu`（各难度）、`.mp3`/`.ogg`（音频）、背景图、`.osb` storyboard、`.mp4`/`.flv` 视频等。  
- **文件夹命名**：`{Beatmap number} {Artist} - {Song Title}`（例：`57950 SOUND HOLIC - Drive My Life`）；极老/未提交谱可不遵循。  
- 另有 **Downloads**（osu!direct 下载中）完成后转入 Songs；**Exports** 导出 `.osz`。  
- 本地有 **`osu!.db`** 等数据库缓存已扫描谱面列表（改 Songs 后可能需重建索引）。

### 2.2 曲包导入：`.osz`

来源：[osu! File formats](https://osu.ppy.sh/wiki/en/Client/File_formats)、[Beatmap packs](https://osu.ppy.sh/wiki/en/Beatmap/Packs)

- `.osz` = ZIP 改后缀的谱面包；放入 Songs 或拖入客户端后 **自动解压进 Songs**，并常删除原 `.osz`。  
- 官方曲包流程：解压得到多个 `.osz` → 丢进 Songs / 拖进窗口 → 必要时选歌界面 **F5** 重新处理。  
- 结论：**用户侧工作流 = 可写 Songs 目录 + 压缩包导入 + 可选强制重扫**。

### 2.3 Beatmap set vs difficulty

- **一个 Songs 子文件夹 = 一首歌的一组难度（beatmap set）**：共享音频/视频/背景。  
- **多个 `.osu` = 多难度**，不是「一难度一文件夹」。  
- 与 9-Dot 对比：9-Dot 已是「一目录一曲 + difficulties 表」——更接近 set，难度用 JSON 文件而非 `.osu`。

### 2.4 Lazer 对照（次要）

osu!lazer **没有**明文 Songs；文件按 SHA-256 存，映射在 `client.realm`，官方宣称不再需要选歌 F5。见 [Lazer File storage](https://osu.ppy.sh/wiki/en/Client/Release_stream/Lazer/File_storage)。早期 9-Dot **不必**上 content-addressed 存储；明文 `songs/<id>/` 更利于用户改包。

### 2.5 对 9-Dot 可挪用的模式（非照搬格式）

| osu! 模式 | 9-Dot 可借鉴 |
|-----------|----------------|
| 用户可写 `Songs/` | `user://songs/`（及桌面旁路目录） |
| set 一级目录 | 保持 `songs/<id>/meta.json + notes + media` |
| 媒体相对 set 根 | meta 内用相对路径，迁目录不碎 |
| `.osz` 导入 | 可选 `*.zip` / `*.9dotz` 解压为 set 目录 |
| F5 重扫 | 选歌「刷新」或启动扫描 + 可选轻量索引 |
| db 缓存 | MVP 可纯目录扫描；曲多再加缓存 |
| Pack ≠ 展开谱 | 分发层（zip）与安装层（已解压目录）分开 |

**不必**兼容 `.osu` / osu 判定体系；只借「外置可编辑曲库」产品形态。

**一句话**：stable 证明「可写 Songs + 包导入 + 缓存扫描」对 UGC 友好；Godot 硬约束是用户包必须落在 **`user://`（非 `res://`）**。

---

## 3. Godot：外置内容必须落在可写路径

来源：[Data paths](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)、[Runtime loading](https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html)

- 导出后项目包多半 **只读** → 持久/用户内容用 **`user://`**（保证可写）。  
- 桌面可额外支持「游戏旁 `songs/`」或文件选择器；**Android/iOS 沙盒**下用户不能直接改 Application Support，需应用内导入或 SAF。  
- Web：无真实本地 Songs 文件夹；可 `user://`（IndexedDB 等）或仅内置 `res://`。  
- 运行时加载：普通文件用 `FileAccess`/`AudioStreamOggVorbis.load_from_file` 等；PCK/ZIP 可用 `ProjectSettings.load_resource_pack`（偏 DLC），或 `ZIPReader` 解用户 zip。  
- **注意**：未走编辑器导入的 `.ogv`/部分格式在导出端可能受限；用户曲包媒体格式需收敛（如强制 ogg + 有限视频格式）。

---

## 4. 推荐目录形态（调研结论草案，待 grill）

```
user://songs/                          # 用户曲库（可写）
  <id>/
    meta.json                         # 路径改为相对或 user://songs/<id>/...
    easy.json | normal.json | ...
    audio.ogg
    video.ogv                         # 可选
  _incoming/                          # 可选：待解压 zip
res://charts/                         # 只读内置（仍可保留）
```

Catalog 合并：`builtin (res://charts)` ∪ `user (user://songs)`，同 `id` 时需策略（用户覆盖 / 双条目）。

可选分发：`*.9dotz` = zip(set 目录)，启动或「导入」时解到 `user://songs/<id>/`。

---

## 5. 平台差异（会影响 grill 决策）

| 平台 | 用户如何改曲包 |
|------|----------------|
| 桌面 Godot / 导出 | 打开 `user://` 真实路径或旁路 `songs/`；拖 zip |
| Android APK | 应用内「导入」文件 → 写入 `user://songs`；难直接文件管理器改 |
| Web `/games/9dot-music/` | 基本只能内置或未来云端；本地文件夹弱 |

---

## 6. 参考链接

- https://osu.ppy.sh/wiki/en/Client/Program_files  
- https://github.com/ppy/osu-wiki/blob/master/wiki/Client/Program_files/en.md  
- https://osu.ppy.sh/wiki/en/Client/File_formats  
- https://osu.ppy.sh/wiki/en/Beatmap/Packs  
- https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html  
- https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html  
- 本仓：`scripts/songs/`（`SongLibrary`）、`docs/skills/nine-dot-chart-agent/reference-schema.md`

---

## 7. 已锁定决策（2026-09-10 grill）

| 项 | 决策 |
|----|------|
| 曲库根 | 仅 `user://songs/<category>/<id>/` |
| 内置 | 首次从 `res://charts` seed → `official/`；之后只读 user |
| 分类 | 至少 `official/` + `users/`；目录名即分类 |
| 导入 | MVP 扫盘 + seed；zip/`.9dotz` 预留；`SongImport.import_set_folder` |
| 选歌 UI | 分组可折叠默认开；状态栏刷新 |
| 平台 | APK/桌面可导入 `users/`；Web 暂官方 seed |
| meta 路径 | 相对 set 根优先；含 `://` 当绝对 |
| 同 id | 可并存；内部键 `category/id` |
| 开发源 | git `charts/`；agent 默认写此；可选打本机 users |

实现模块：`scripts/songs/`（paths / entry / seed / scanner / resolve / media_io / import + Autoload `SongLibrary`）。
