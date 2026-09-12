# MyRoom Q-OC（Mint Ribbon）

原创 Q 版占位角色。概念图已有 **正 / 侧 / 背** 三视图，生成必须吃三视图，不能只对正面。

概念图：

- `concept/oc_q_concept_front.png`
- `concept/oc_q_concept_side.png`（角色左侧）
- `concept/oc_q_concept_back.png`

## 分件（各自独立 GLB）

| 分件 | GLB | 体积（非扁片） | 三视图吻合 |
|------|-----|----------------|------------|
| 头发 | `parts/hair/hair.glb` | 有（双团子+腔） | 正/背结构对齐，侧视较乱 |
| 头部 | `parts/head/head.glb` | 有（Q 球+耳） | 正/侧/背均为球体 |
| 五官 | `parts/face/face.glb` | 有（眼窝在球上） | 正面眼位对，侧视鼻不清晰 |
| 衣服 | `parts/clothes/clothes.glb` | 有（卫衣+帽+袖） | 正/侧/背都是衣服体积 |
| 手 | `parts/hands/hands.glb` | 差（两枚圆片） | 未形成 Q 手掌 |
| 裙子 | `parts/skirt/skirt.glb` | 偏薄，带裁图毛刺 | 正/背扇形，厚度不够 |
| 腿 | `parts/legs/legs.glb` | 有（两截圆柱+袜） | 正双腿、侧一条 |
| 鞋 | `parts/shoes/shoes.glb` | 最好 | 正双靴、侧轮廓、背鞋跟 |

```bash
# 1. 从三视图裁件
~/src/hunyuan3d-venv/bin/python art/myroom_oc/scripts/crop_threeview_parts.py

# 2. 停掉正在占 MPS 的 Hunyuan-mini API（2mv 与 mini 不能同时驻留）
# 3. 一次加载 2mv，逐件生成（不是 BlenderMCP）
export PYTHONUNBUFFERED=1 HF_ENDPOINT=https://hf-mirror.com
export PYTORCH_ENABLE_MPS_FALLBACK=1 HY3DGEN_MODELS=$HOME/.cache/hy3dgen
export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
~/src/hunyuan3d-venv/bin/python art/myroom_oc/scripts/hunyuan_generate_part.py \
  hair clothes skirt shoes legs head face hands
```

权重：`Hunyuan3D-2mv` turbo DiT + `Hunyuan3D-2` turbo VAE，走本机 `hy3dgen` 缓存。

整模装配（八件 + 色盘 + 简单骨骼 idle）：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python \
  art/myroom_oc/scripts/assemble_oc_q.py
```

写出 `art/myroom_oc/oc_q.glb` 与 `myroom/placeholder/oc_q.glb`。朝向 **-Y**，脚在 z=0，身高约 1.10m。

单视角 mini 会把裙/脸收成扁片。已弃用：整模正面投影、`assemble_hunyuan_parts.py`。
