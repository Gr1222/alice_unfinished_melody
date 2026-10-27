# 最新森林：已接手完成的可运行实验

直接打开 `scenes/art/LatestForest.tscn`，按 F6；或解压最新交付包后双击 `START.cmd`。无需手工切轮廓、配置材质或运行 Blender 脚本。

WASD / 方向键移动，空格自动从入口走到树洞，H 对比遮挡开关，R 返回入口，Esc 退出。本场景使用项目已有的爱丽丝正面、侧面、背面静态姿态，不声称已经有行走帧动画。

## 已完成

- 原生 8192×4608 源文件无损保留。
- imagegen 生成四类轮廓的 ID 蒙版指引；生成结果仅参与透明度选择，不参与原画 RGB。
- Blender 5.2.3 实际生成蒙版控制的图片卡片、四个透明物体层、四张灰度遮挡蒙版，以及内嵌原图与蒙版的 `forest-ready.blend`。
- Godot 固定机位使用原图颜色与同坐标蒙版：中央树根和石碑按 Y 排序，左右前景覆盖角色。
- 已制作独立道路范围和自动走完路径，不修改原有序章、怀表、对白或音乐拼合逻辑。

## 质量与验证

隐藏角色与界面后，1024×576 实际 Godot 截图与原图最近邻采样对比，RGB 最大差异为 0；完整原件在 `assets/latest_forest/original-8k.png`。

已检查树根前后实际截图，自动走路完整运行至树洞。结构和路径测试见 `tests/latest_forest.gd`，序章回归见 `tests/prologue_flow.gd`。

四张蒙版已经从粗区域改为轮廓选择，但属于自动分割，复杂细枝并非逐像素手绘验收。没有把生成图中的颜色替换进原画。镜头保持固定，没有补画被遮挡的地面，没有重新建模为可自由旋转的完整三维森林。当前交付是原图保留的 2.5D 预渲染实验。

## Blender 文件

本机输出为 `output/finished-latest-forest/forest-ready.blend`，直接打开即可查看；原图与分割指引已内嵌。`layers/` 是实际 Blender 透明出图，`masks/` 为实际 Blender 灰度蒙版，`previews/` 包含 Blender 与 Godot 预览。运行时为保持颜色完全一致，使用原图加灰度蒙版着色器，而不是把 Blender 色彩转换后的 RGB 覆盖到原图。

来源与复现脚本：`tools/forest_sample/finish_latest_forest.py`。生成蒙版指引保存在输出目录 `segmentation-guide.png`。保留这些文件即可重复 Blender 出图，不需要重新调用图像生成。
