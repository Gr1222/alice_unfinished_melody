# 游戏开发技能接入记录

接入日期：2026-10-27。适用项目：Godot 4.7.2 像素俯视探索＋视觉小说。

## 来源与选择

- 已通过 Codex 内置 skill-installer 查询 OpenAI 官方精选目录；查询时没有直接匹配的 Godot/视觉小说开发技能。现有 imagegen、skill-creator 等能力继续可用。
- GitHub 搜索比较了 `gamedev-skills/awesome-gamedev-agent-skills`、`vl4dt/godot-skills` 等来源。
- 选择 https://github.com/gamedev-skills/awesome-gamedev-agent-skills ，因为同一套技能覆盖 Godot 4.7、对话、视觉小说、存档及游戏素材流程。
- 固定提交：`184b72be02884f782a0058f2eeae2ce4277453e4`，许可证 Apache-2.0。
- 安装位置：`C:/Users/sophi/.codex/skills/`，用户级安装，可在其他项目中复用。
- 安装工具：Codex 内置 `skill-installer/scripts/install-skill-from-github.py`。未运行第三方仓库的安装程序。

## 安装清单

| 类别 | 技能 |
| --- | --- |
| Godot（12） | godot-gdscript、godot-nodes-scenes、godot-signals-groups、godot-2d-movement、godot-tilemap、godot-ui-control、godot-animation、godot-audio、godot-physics、godot-resources、godot-export、godot-gdscript-headless-testing |
| 通用制作（7） | dialogue-systems、save-systems、create-game-assets、input-systems、level-design、camera-systems、game-ui-ux |
| 叙事类型（1） | visual-novel |

按任务自动匹配，也可在消息中明确指定，例如：

- `使用 $godot-tilemap 和 $godot-2d-movement 实现俯视地图与移动。`
- `使用 $dialogue-systems 和 $visual-novel 增加对白、立绘差分和历史回看。`
- `使用 $create-game-assets 为森林、爱丽丝和怀表制定统一像素素材规范。`
- `使用 $save-systems 实现剧情和谜题状态存读档。`

技能将在安装后的下一轮对话提供给 Codex。当前项目的 AGENTS.md 也记录了任务与技能的对应关系。

## 审查与边界

- 检查了所选目录的文件类型、技能说明和可疑指令模式；检查了素材检查脚本及场景检查脚本的相关操作。
- 所选内容主要是 Markdown 参考资料；附带脚本用于场景引用检查、图片尺寸/透明度/颜色数检查及预览拼图。未发现需要上传项目、读取密钥或驻留后台的安装步骤。这不是完整安全审计或全部 API 示例的正确性认证。
- 素材脚本需要 Pillow，优先使用 Codex 自带 Python 与现有依赖；没有新增付费服务或 API 密钥依赖。
- 未安装全引擎路由器：它覆盖大量未安装引擎，本项目由 AGENTS.md 提供更具体的路由。
- 未安装通用 puzzle 技能：其内容主要是消除、推箱与网格谜题，与本作怀表调查谜题不直接匹配。
- 未启用 Godot MCP 服务，也未修改游戏运行逻辑。

## 接入验证

- 20 个技能均安装成功，逐文件 SHA-256 与固定提交下载内容一致。
- 每个技能目录保留上游 LICENSE 与 NOTICE。
- 使用已安装的 `godot-nodes-scenes/scripts/check_godot_project.py` 检查当前项目：扫描 5 个文件，0 错误、0 警告。
- 已验证素材检查工具能够启动，Pillow 依赖可用；未对尚不存在的正式素材做验收。

## 更新与移除说明

来源与文件校验值记录在 `game-development-skills.lock.json`；许可证和 NOTICE 随技能保存。更新前检查上游变更，再使用内置安装工具安装审核过的新提交，不自动追踪 main。

移除时仅删除清单中对应的用户技能目录，并同步调整项目 AGENTS.md。不要删除 `.system` 或其他已有技能。
