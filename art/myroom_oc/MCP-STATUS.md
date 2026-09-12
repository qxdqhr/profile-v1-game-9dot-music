# BlenderMCP status

- Addon / Blender 4.4.3 仍可用，但 **分件生成不走 MCP**，只用本机 Hunyuan3D-2mv。
- 坏掉的整模已删：`oc_q.glb` / `oc_q.blend` / 场景网格。
- 概念图三视图：`concept/oc_q_concept_{front,side,back}.png`
- 分件目录：`art/myroom_oc/parts/{hair,head,face,clothes,hands,skirt,legs,shoes}/`
- 生成器：`scripts/hunyuan_generate_part.py` → **Hunyuan3D-2mv-turbo**（正/左/背）
- 2026-09-12：八件 GLB 已用 2mv 重出。`assemble_oc_q.py` 按概念图比例拼成 `oc_q.glb`（脚 z=0，朝向 -Y）。
- 生成分件前需停掉 `:8081` mini，给 2mv 腾 MPS。
