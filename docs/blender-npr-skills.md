# Blender 三渲二补充技能

2026-10-27 检查 Codex 官方精选技能目录：未发现 Blender 三渲二专项技能。本次通过 Codex 内置 skill-installer 从 GitHub 安装以下七项，保留原有三项。

来源：https://github.com/arjun988/blender-skills

固定提交：`8f778d2405a214b508d4c7d80742be8e43acdd52`，MIT License。用户级目录：`C:/Users/sophi/.codex/skills/`。新增技能会在下一轮对话提供给 Codex。

| 新增技能 | 本项目用途 |
| --- | --- |
| anime-style | 赛璐璐明暗分档、卡通材质和轮廓处理 |
| materials | 可复用的材质与节点组织 |
| lighting | 森林光照、视觉重点和明暗可读性 |
| rendering | Eevee 出图、色彩管理、渲染通道和非写实渲染参考 |
| compositing | 后期调色、发光与分层输出指导 |
| pixel-art-style | 像素尺度、有限配色和低分辨率可读性 |
| camera-cinematography | 固定机位、画幅、透视和构图 |

原有 `blender-modeler`、`environment-artist`、`hand-painted-style` 保留。上游公共参考资料九份已放到用户技能目录的 `references/`，用于修复技能中的 `../references/...` 相对引用。许可证与每个文件的 SHA-256 见 `forest-skills.lock.json`；各技能内容还与该提交 Git blob 校验值逐项核对。所选技能目录由 Markdown 指导与参考组成，没有运行第三方安装程序，也没有安装 Blender 扩展或 MCP 服务。

这些技能提供参考工作流，不是 Blender 插件或自动保证画质的材质包。部分技能包含旧版 Eevee/Bloom 等示例；实现时必须按实际 Blender 版本检查 API 和渲染器支持，不直接照抄。材质技能中的通用 PBR 建议、渲染技能中的 AgX 默认建议也不能覆盖本项目已确定的像素风和色彩管理。

实际执行 `blender.exe --version` 检测到 Blender **5.2.3 LTS**，路径为：

```text
C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe
```

本次只完成技能安装、来源与文件核验、Blender 可执行文件版本检查；尚未实际运行 `build_blender.py`，不声称模型、材质、渲染或透明分层已在 Blender 验证。

制作方向仍为“离线预渲染背景＋2D 像素角色”。优先使用已有森林小样验证：固定正交相机 → 材质明暗分档 → 背景与透明物体出图 → Godot 二维锚点与前后遮挡。技能示例中的自由运镜、实时三维、复杂动画和角色比例不构成本项目新需求。

此前已发送的迁移 ZIP 是历史快照，不会随本机技能安装自动更新。
