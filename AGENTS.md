# 项目开发约定

本项目是 Godot 4.7.2 的像素俯视探索与视觉小说游戏《爱丽丝与未完成的旋律》。开始实现前阅读 README.md、相关场景与测试，保留已验证的序章流程；需求以用户指令和项目设计文档为准。

## 已接入的开发技能

技能安装在 `C:/Users/sophi/.codex/skills/<name>/SKILL.md`。按任务读取相关技能及必要的 references，不要每次加载全部技能。

| 工作 | 技能 |
| --- | --- |
| GDScript、场景拆分、事件与数据 | godot-gdscript、godot-nodes-scenes、godot-signals-groups、godot-resources |
| 俯视移动、地图与碰撞 | godot-2d-movement、godot-tilemap、godot-physics |
| 交互、短按长按、模式切换 | input-systems |
| 镜头、探索引导与关卡节奏 | camera-systems、level-design |
| 对话、分支、立绘、回看与快进 | dialogue-systems、visual-novel |
| 对话框、选项、背包、暂停菜单 | godot-ui-control、game-ui-ux |
| 动画、转场与音频 | godot-animation、godot-audio |
| 存档、剧情标记与恢复 | save-systems、godot-resources |
| 像素素材规范、切图和素材检查 | create-game-assets；实际图像生成使用已提供的 imagegen |
| 回归测试与导出 | godot-gdscript-headless-testing、godot-export |

这些技能是参考工作流。示例不能直接替代项目需求；视觉小说技能仅用于本作的叙事演出部分，不能据此改成纯视觉小说。谜题以项目中的怀表与章节设计方案为准。

## 最新设定（优先于旧设计文档）

- 怀表只在序章用于观察白兔残影与旧脚印，后续章节停用，不把怀表做成全游戏核心能力。
- 全游戏围绕同一首大旋律：每章收集音乐碎片，在章末拼出本章乐句，累计到结局才完整奏响；不是每章独立一首歌。
- 序章对白后出现碎片，树根后的小径始终存在，音乐拼合是章末任务，不恢复石门或限时开路。
- 最新叙事顺序：白兔听见爱丽丝接出后续旋律而惊退 → 白兔离开后发现同纹碎片 → 怀表负责找路 → 小径旁停顿时拼合 → 洞口回应带来继续探索的动机。音乐拼合不作为进入黑洞的前置条件，不能重新加上音乐门锁。
- 拼合支持原生拖放、槽位换位/移除、键盘操作和退出保留草稿；首次完成返回探索后触发一次洞口光纹与独白回应。无音频时只呈现视觉反馈，不声称实际播放了音乐。
- 音频等待用户上传。当前使用视觉连接线索；保持无音频可玩，不擅自生成替代音乐。
- 乐句数据使用 MelodyPhrase 资源，拼合使用独立 MelodyPuzzle 场景，MelodyProgress 为跨场景内存进度；退出持久化存档尚未实现。

## 项目验证

- 行为变更后运行相关测试；现有序章回归命令：
  `& 'C:/Users/sophi/Desktop/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/prologue_flow.gd`
- 冷启动或增加导入资源后先运行 Godot 无窗口导入。
- 序章已改为白兔残影与旧脚印指引树根后原有小径，不再使用石门解锁。重点检查对白期间输入消费、E 短按与长按区分、失焦与暂停恢复、怀表状态、观察/直接探索两条路线及主动进入第一章。
- 素材需在原生显示尺度确认可读性、像素网格、透明度、帧尺寸和锚点；生成图片只作为待验证素材。
- 新增存档时覆盖探索/对白位置、剧情与谜题标记、已读记录，并避免恢复后重复发放道具或触发剧情。

安装来源、版本和完整清单见 `docs/game-development-skills.md`。

森林美术补充技能：`blender-modeler`、`environment-artist`、`hand-painted-style`，用于三维布局和材质参考。来源、固定版本、验证边界见 `docs/forest-study.md` 与 `docs/forest-skills.lock.json`。独立预览为 `scenes/art/ForestStudy.tscn`，不替代序章；已检测 Steam 版 Blender 5.2.3 LTS，位置为 `C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe`，生成脚本仍未经 Blender 实际执行。

三渲二补充技能：`anime-style`、`materials`、`lighting`、`rendering`、`compositing`、`pixel-art-style`、`camera-cinematography`。用途、版本适配与来源见 `docs/blender-npr-skills.md`；技能包含旧版示例，执行前核对 Blender 5.2 API，不让通用 PBR、自由运镜或实时三维示例覆盖用户已确认的制作方向。

用户已确认“预渲染场景＋2D 像素角色”为制作方向。三维只用于离线出图；图片运行实验为 `scenes/art/ForestPrerender2D.tscn`，资源在 `assets/forest_prerender/`。当前离线出图由 Godot 代理验证，后续换 Blender，勿据此将游戏改成实时三维场景。

最新原图保留实验见 `docs/latest-forest-blender.md`：用户附件原生 8192×4608，原件不重绘；已实际使用 Blender 5.2.3 生成固定机位图片卡片工程与五个透明分区，输出在 `output/latest-forest-20261027/`。这是 2.5D 分区工作底稿，不是完整三维重建或已逐物体精细抠图。旧低模小样不是最新原图的美术还原。旧 `build_blender.py` 的验证状态仍独立于新 `build_latest_plate.py`。

用户随后要求代理接手。最新可运行成果改为 `scenes/art/LatestForest.tscn`、`assets/latest_forest/`，说明见 `docs/latest-forest-ready.md`。四类自动分割指引只控制 alpha，原图 RGB 保留；Blender 生成轮廓层和灰度蒙版，固定相机运行截图已验证原画颜色不变。该成果仍为 2.5D 固定机位，不将其描述为完整三维重建。不要再把细抠操作作为用户必须完成的步骤。

后续用户明确拒绝仅贴片的效果，提供了空间光照视频，并要求接近原参考图的精细度。当前独立空间/美术样段为 `scenes/art/ForestArtStudy.tscn` 和 `SpatialForest.gd`，模型来自 Blender 真正的体积网格，仍不替换序章主场景。用户最新明确：横木要低，按 W 跳过，不能做成从下方钻过的拱根；样段方向键移动，W 只跳跃。地面不能使用整片画好的草地贴图，光源必须有来源，禁止角色无来源的跟随补光。详见 `docs/forest-jump-study.md`，不可把当前局部样段当作整张地图的最终美术验收。
