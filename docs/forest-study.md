# 森林三渲二制作小样 01

## 已确认的制作方向（优先于下文早期小样说明）

使用“预渲染场景＋2D 像素角色”：Blender 用于制作、渲染背景，游戏运行时使用二维图片、角色和碰撞。固定相机，光照预先烘焙。已有出图由 Godot 三维小样离线生成，用于验证图片接入管线；这不代表 Blender 出图已验证。2026-10-27 已检测到本机 Steam 版 Blender 5.2.3 LTS，并补装三渲二技能，详见 `blender-npr-skills.md`；Blender 脚本仍待实际运行。

当前可运行实验是 `scenes/art/ForestPrerender2D.tscn`，打开后 F6。WASD/方向键移动，R 回入口，Esc 退出。逻辑画布 480×270，窗口 960×540，最近邻放大。人物是代码绘制的像素形状占位，尚无正式立绘或行走动画。

交付 `assets/forest_prerender/background.png` 与 15 张裁切后的透明树木/树桩图；`manifest.json` 记录每张图的脚底锚点、裁切偏移、碰撞与投影坐标。所有图使用同一机位输出，离线烘焙树木和树桩阴影。运行时按脚底 Y 排序，无三维节点或实时三维光照。地面装饰仍合并在背景中；后续若需要遮挡或交互，应单独出图。

桥上可以通行，桥外河面禁止通行，树干和树桩使用简化圆形碰撞。碰撞是本小样的测试范围，不代表最终地图校准。该场景不修改序章玩法，也不消耗或修改音乐进度。

重新出图（会更新 `assets/forest_prerender/` 下的实验素材，手绘修图请先另存其他文件）：

```powershell
./tools/forest_sample/bake_2d.ps1
```

更新模型布局时先运行 `tools/forest_sample/build_layout.py`，再执行出图脚本。后续 Blender 使用相同布局与正交相机，仍需校准输出坐标、阴影和透明材质后才能替换本批图片。

验证命令：

```powershell
& 'C:/Users/sophi/Desktop/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/forest_prerender.gd
& 'C:/Users/sophi/Desktop/Godot_v4.7.2-stable_win64_console.exe' --path . res://scenes/art/ForestPrerender2D.tscn -- --capture-prerender
```

第二条命令保存 overview、behind、front 三张截图到 `output/forest-study/`，其中后两张用于对比人物在树前、树后的遮挡。

本轮实际验证：预渲染实验 37 项通过、0 失败（含透明图层、纯二维结构、桥面通行、河流阻挡和树干碰撞）；图形运行已保存三张截图并检查前后遮挡。树冠与树干按整棵树共同排序，适合当前固定机位小样，复杂拱形树冠仍需按遮挡关系进一步拆层。

依据用户提供的森林地图范本，制作入口木桥、石板路、树桩、枯树与发光蘑菇的小样。范围是制作管线与构图验证，不是整图还原，也不是完成的像素背景。

## 当前交付

- `scenes/art/ForestStudy.tscn`：独立 Godot 三维预览，不接入序章。
- `data/art/forest_study.json`：两个工具共用的物体位置、尺度、配色、相机和分组数据。
- `tools/forest_sample/build_layout.py`：固定种子 271027，生成 543 个物体的布局。
- `tools/forest_sample/build_blender.py`：创建 Blender 新场景，配置正交相机与 Eevee 三档明暗材质，保存新的 `.blend` 副本，可选择渲染。
- `output/forest-study/godot-preview.png`：Godot 实际渲染结果。
- `output/forest-study/godot-pixel-native.png`：低分辨率原始渲染，用于检查轮廓与比例，不是手工像素画。

模型由基础几何体构成，树叶、树干、桥和地形尚未完成手绘修形。蘑菇采用明亮颜色表达发光，没有完成范本中的局部光晕、雾和粒子。人形是尺寸参照，不是爱丽丝正式素材。没有地图碰撞、角色操作或剧情。

## 在 Godot 里查看

打开工程，打开 `scenes/art/ForestStudy.tscn`，按 F6 运行当前场景。F5 仍启动原有序章。

- P：原生 / 降低分辨率预览。
- C：显示 / 隐藏树冠，检查地面布局。
- Esc：退出独立预览。

PowerShell 截图命令（在项目根目录执行）：

```powershell
& 'C:/Users/sophi/Desktop/Godot_v4.7.2-stable_win64_console.exe' --path . res://scenes/art/ForestStudy.tscn -- --capture-forest
```

截图命令会更新上面两张预览图。

## 安装 Blender 后

脚本目标为 Blender 4.2 及以上版本。本机现已检测到 Blender 5.2.3 LTS，但脚本仍仅完成 Python 语法检查，不能据此保证 Blender API 兼容或出图成功。两个渲染器的光照和材质实现不同，不承诺 Blender 和 Godot 出图完全一致。

将下面的 Blender 路径替换为实际安装位置：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 4.5/blender.exe' --background --python tools/forest_sample/build_blender.py -- --render
```

输出保存在 `output/forest-study/<时间戳>/`，包含 `forest-bridge.blend` 和 `blender-preview.png`。不加 `-- --render` 则只保存工程。脚本创建新场景，保留已有场景，采用另存副本，避免覆盖原工程；不安装插件、不联网。

也可在 Blender 的 Scripting 界面打开脚本并运行。脚本依赖自身路径定位项目，不应复制后脱离本项目目录运行。

在 Blender 中按 Ground、Path、Rocks、Bridge、Trees、Canopy、Props、Mushrooms、Shrubs、Water、ScaleReference 分组，可在 Outliner 逐组隐藏进行后续分层渲染。当前自动命令只输出合成预览；尚未自动导出每组透明图。

## 下一步制作

1. 先看小样，调整相机、人物尺寸参照和通路宽度。
2. 把树干改成范本中的弯曲轮廓，树冠整理成叶簇；当前轮廓较规则。
3. 确定游戏的原生像素尺度，再制作树木、蘑菇和石板的小资产集。
4. 分别渲染地面、可遮挡物与前景，清理边缘、像素簇和阴影。只缩小渲染不能代替这一步。
5. 在独立的二维美术测试场景中验证人物前后遮挡与碰撞，再考虑接入序章。

小样中的桥和河只是范本制作练习，未经关卡设计确认，不应替换序章已有路线。怀表、碎片、乐句拼合与主动进入第一章的规则不变。

## 技能来源与验证边界

复用 Codex 已有的 create-game-assets 和 Godot 技能；imagegen 也已可用，本次没有调用图像生成服务，图片为实际三维场景渲染。官方精选技能目录中没有发现需要额外安装的 Blender 专项技能，没有重复安装已有技能。

新增用户级技能来自 <https://github.com/arjun988/blender-skills> ，固定提交 `8f778d2405a214b508d4c7d80742be8e43acdd52`：

| 技能                 | 用途             |
| ------------------ | -------------- |
| blender-modeler    | 建模、命名和场景组织     |
| environment-artist | 模块化场景、植被、构图与比例 |
| hand-painted-style | 手绘材质方向         |

安装位置 `C:/Users/sophi/.codex/skills/`。新技能会在下一轮对话提供给 Codex，本轮已手动阅读使用。通过内置 skill-installer 安装，没有运行第三方安装程序。保留上游 MIT LICENSE；文件哈希见 `forest-skills.lock.json`。

所选目录包含 Markdown 指导与参考资料，未安装 Blender 软件、MCP 服务或扩展。上游部分跨技能公共参考位于选择目录之外，没有一并安装；本轮使用的构图和场景组织参考已随技能安装。后续需要其他参考时按需检查获取。

验证：Godot 4.7.2 无窗口导入、独立场景图形运行和两种分辨率截图成功；场景资源引用检查通过；序章回归 65 项通过、0 失败。Blender 脚本仅做语法检查，未执行建模与出图，不将其标为已验证。
