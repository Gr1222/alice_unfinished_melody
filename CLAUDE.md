# CLAUDE.md — 《爱丽丝·律境回响》

## 项目
- 引擎：Godot 4.7.2（macOS 路径：`/Applications/Godot.app/Contents/MacOS/Godot`），GDScript，渲染器 gl_compatibility
- 对话/UI 为 2D（CanvasLayer），场景与角色为 3D
- 比赛：thatgamejam #2；最终提交文本需为英文，当前以中文测试
- 策划文档：`docs/副本爱丽丝人物设定及剧情大纲.docx`（完整剧情）、`docs/序章详细玩法优化版.docx`（序章玩法，以此为准）

## 新会话先读
1. 本文件
2. `docs/开发进度与交接.md`：做到哪一步、占位清单、解谜如何换成正式版、下一步计划（**每完成一步都要更新**）
3. `docs/调参指南.md`：所有可调设置

## 可调设置文档
- `docs/调参指南.md` 列出所有可调设置（Inspector 导出变量、数据文件、代码常量）的位置、默认值和作用
- **每次新增或修改可调设置（`@export`、可调 `const`、data/ 中的字段），必须同步更新该文档**

## 交流与语言
- 与开发者对话使用英语
- 代码注释、Markdown 文档一律使用中文
- 所有玩家可见文本（对话、任务、道具、按钮）**禁止写死在代码里**：
  - 字符串放 `data/i18n/strings.csv`（列：`keys,zh,en`），代码中用 `tr("KEY")`
  - 剧情流程放 `data/dialogue/*.json`，只引用字符串 key
  - 当前语言由 `GameState.DEFAULT_LOCALE` 决定（测试期为 `zh`）

## 文件夹结构
- `scripts/autoload/`        全局单例（EventBus、GameState，后续加入 Fader、Music、DialogueManager）
- `scripts/components/`      可复用组件（ForestLevel、Interactable 等）
- `scripts/data/`            只读数据读取（ItemDatabase ← `data/items.json`）
- `scenes/props/`            场景中的可交互物体（PocketWatch 等）
- `assets/models/`           角色/道具的正式 3D 模型（.glb），在 `data/models.json` 中引用；外观槽组件 `scripts/components/ActorModel.gd`
- `scripts/audio/`           音频工具（ToneGenerator：没有真实音频时生成占位音）
- `data/puzzles/`            调律解谜数据（音频路径、切点、奖励道具）
- `scenes/ui/`               对话框、任务栏、弹窗、背包、交互提示
- `scenes/player/`           爱丽丝 3D 角色
- `scenes/chapters/<章节>/`  每章的主场景与导演脚本（序章：`scenes/chapters/prologue/`）
- `scenes/puzzles/`          解谜场景
- `data/`                    dialogue / i18n / items / puzzles 数据
- `assets/`                  美术与音频（由美术/建模负责）
- `assets/audio/music/`      背景音乐（`forest_theme.wav`：森林 BGM，导入设置为循环）
- `assets/audio/puzzle/`     解谜音轨；`assets/audio/sfx/` 音效
- `assets/audio/source/`     美术给的原始文件（如 .m4a），游戏不直接使用

## 字体
- 项目默认字体：`assets/fonts/ui_font.tres`（SystemFont，macOS 用 Hiragino Sans GB，Windows 用 Microsoft YaHei）
- 不要把 “PingFang SC” 放在第一位：Godot 会打开同一字体文件里的 PingFang HK（繁体），缺少“迟”等简体字
- `tests/dialogue_manager.gd` 会检查 strings.csv 中所有中文字符都能被字体显示
- 正式提交前建议换成打包进项目的字体文件（美术选定后放入 `assets/fonts/`）

## 音频格式
- Godot 不支持 .m4a，只用 .ogg / .mp3 / .wav
- WAV 必须是普通 PCM 头；macOS `afconvert` 导出的是 EXTENSIBLE 头，Godot 会报 “not PCM”，需要重写文件头
- 背景音乐在 `.import` 中设置 `edit/loop_mode=2`（Forward 循环）
- `tests/`                   无头测试（`extends SceneTree`）
- 旧 demo：`scenes/prologue/`、`scenes/forest/`、`scenes/art/`、`scenes/music/` 仅作参考，不在其上开发新功能

## 命名规则
- 场景与脚本文件：PascalCase（`DialogueBox.tscn` / `DialogueBox.gd`）
- 数据文件与文件夹：snake_case（`prologue.json`）
- 变量/函数：snake_case；常量：UPPER_SNAKE_CASE；信号：过去式（`dialogue_finished`）
- 字符串 key：`<类别>_<章节>_<名称>_<序号>`，如 `DLG_PRO_SISTER_01`、`ITEM_WATCH_NAME`、`QUEST_PRO_FOLLOW`
- 输入动作统一在 `project.godot` 的 Input Map 中定义，禁止直接判断 keycode：
  `move_left/right/up/down`（WASD + 方向键）、`jump`（空格）、`interact`（E）、`talk`（F）、
  `inventory`（B）、`dialogue_next`（Enter / 鼠标左键 / E）、`pause`（Esc）

## 协作规则
- **不要修改别人的场景/资源**：`assets/` 下的模型与美术、`scenes/art/`、`scenes/forest/`、`scenes/prologue/` 等。需要时“实例化/继承”或新建副本，并在 PR 中说明
- 修改 `project.godot`（主场景、autoload、输入映射）前先在群里同步
- 二进制资源走 Git LFS，提交前确认已 `git lfs install`
- 不提交 `.godot/`、`output/`、`*.translation`（翻译文件由 CSV 导入自动生成）

## 场景入口
- 主场景（⌘B / F5）：`scenes/chapters/prologue/Prologue3D.tscn`（新序章）
- 旧 demo 仍可单独打开：`scenes/forest/ForestPrologue.tscn`

## 运行与验证
- 导入资源（新增 CSV/图片后）：`Godot --headless --path . --import`
- 无头检查：`Godot --headless --path . --quit-after 60`
- 测试：`Godot --headless --path . -s tests/<name>.gd`
- 遇到报错：先运行 Godot 读取输出，再修复
- 测试脚本里不要把“引用了 autoload 的 class_name”（Alice3D、QuestTracker 等）当类型用，会编译失败；用 `Node` 并显式写变量类型
- 连接 autoload（EventBus 等）的信号时用**方法**，不要用 lambda：节点释放后方法连接自动断开，lambda 不会，之后会调用已释放的对象
- 移动**冻结的物理刚体**（RigidBody2D）时不要用 Tween：在 `_physics_process` 中设置位置，并用 `PhysicsServer2D.body_set_state` 同步（见 `PuzzleSegment.sync_to_physics()`），否则物理引擎会把它拉回旧位置
- 导演/剧情脚本里“每帧等待”的循环用 `next_frame()`（见 `PrologueDirector.gd`），返回 false 时立刻 `return`：换场景时节点已离开场景树，否则后续剧情会在被销毁的场景里继续执行
- `GameState` 跨场景保存（操作锁、背包、解谜结果）：换场景前释放自己加的锁，不要随意 `reset()`
- 角色/兔子洞的外观不要在场景里直接放贴图或模型：一律通过 `ActorModel` + `data/models.json`，导演只调用 `face_toward` / `set_motion` / `play_state`
- 修 bug 时先写能复现的测试，并临时关掉修复确认测试会失败，再打开修复
- 测试只验证逻辑，看不到画面：改动镜头/UI 后要截图检查（非 headless 运行，用 `get_viewport().get_texture().get_image().save_png()`）
- 已知无害输出：用 `--headless` 或 `-s 测试脚本` 运行且播放过音乐后退出，会报
  “ObjectDB instances were leaked / resources still in use (forest_theme.wav)”。
  正常运行游戏（编辑器 ⌘B / ⌘R）退出时不会出现，无需修复
