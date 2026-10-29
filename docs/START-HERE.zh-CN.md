# 当前统一试玩工程

唯一日常编辑入口：`C:/Users/sophi/Documents/alice-melody/project.godot`。

- 双击项目根目录 `打开最新工程.cmd`：打开这个工程和森林场景。
- 双击 `试玩森林.cmd`：直接运行工程默认场景。窗口正常显示，不使用隐藏窗口参数。
- Godot 按 F5：默认进入森林整图。
- 森林窗口右上角按钮或 F2：打开原序章灰盒，保留对白、怀表和音乐拼合流程。
- 编辑森林：`scenes/forest/VolumeForest.tscn`。场景中的 `ForestModel` 是实际模型实例，在编辑器里可查看；角色、运行灯光及碰撞仍由脚本创建，运行后可在“远程”节点树查看。

WASD / 方向键移动，空格跳跃，P 自动巡游，Tab 整图/跟随镜头，E 调查，Esc 暂停。对白下一句只使用 E / Enter，空格不推进对白。

资源已经放在本工程的 `assets/volume_forest/` 与 `assets/user_art/`，不需要复制解压目录里的资源。`forest-volume-whole-map/` 是保留的便携备份，已用 `.gdignore` 排除主工程扫描，以免重复导入。

统一的是项目资源、默认启动入口与两个试玩模式的入口；森林还没有替换原序章的整套剧情地图。F2 明确进入原序章，不把两个控制器同时放在同一地图运行。

修改前配置备份在 `output/integration-backup/project-before.godot`。原序章源文件没有改动。

整合后验证：默认项目启动日志确认 `FOREST_READY`；入口切换测试 8 项、整图测试 23 项、原序章回归 65 项通过，共 96 项；引用检查 142 个文件，0 错误、0 警告。已实际以正常窗口模式启动，并将窗口放到屏幕内；桌面窗口截图为 `output/integration-backup/visible-game.png`。
