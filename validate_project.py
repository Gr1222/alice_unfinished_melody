#!/usr/bin/env python3
# validate_project.py — 离线工程结构校验（零依赖）
# 作用：在不启动 Godot 的前提下，检查工程配置、Autoload 路径、场景外部资源引用、
#       脚本缩进（必须为 Tab）、括号配平、extends 存在性、输入动作是否注册、
#       @onready 节点路径是否真实存在、sub_resource 顺序、load_steps 一致性。
# 注意：本脚本不编译 GDScript，真正的语法校验请在 Godot 编辑器内运行（见 docs/VERIFICATION.md）。
#
# 用法：
#   python tools/validate_project.py [工程根目录]
# 若不传参，则自动向上查找包含 project.godot 的目录。

import os
import re
import sys

EXT_RE = re.compile(r'\[ext_resource\s+type="([^"]+)"\s+path="([^"]+)"\s+id="([^"]+)"\]')
SCRIPT_RE = re.compile(r'script\s*=\s*ExtResource\("([^"]+)"\)')
AUTOLOAD_RE = re.compile(r'^(\w+)\s*=\s*"\*?(res://[^"]+)"', re.MULTILINE)
MAIN_SCENE_RE = re.compile(r'run/main_scene="(res://[^"]+)"')
NODE_RE = re.compile(r'\[node\s+name="([^"]+)"(?:\s+type="[^"]*")?(?:\s+parent="([^"]*)")?')
ONREADY_RE = re.compile(r'@onready\s+var\s+\w+\s*:?[^=]*=\s*\$([A-Za-z0-9_/]+)')
ACTION_RE = re.compile(r'is_action_(?:pressed|released|just_pressed|just_released)\("([^"]+)"\)|get_vector\("([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"([^"]+)"\)')

# Godot 内置默认输入动作（无需在 project.godot 注册）
BUILTIN_ACTIONS = {
    "ui_accept", "ui_select", "ui_cancel", "ui_focus_next", "ui_focus_prev",
    "ui_left", "ui_right", "ui_up", "ui_down", "ui_home", "ui_end",
    "ui_page_up", "ui_page_down", "ui_cut", "ui_copy", "ui_paste",
}


def find_project_root(start: str) -> str:
    cur = os.path.abspath(start)
    while True:
        if os.path.isfile(os.path.join(cur, "project.godot")):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            return start
        cur = parent


def res_to_path(root: str, res: str) -> str:
    if res.startswith("res://"):
        return os.path.join(root, res[len("res://"):])
    return os.path.join(root, res)


def check_gd(path: str, errors: list, warns: list):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    lines = text.splitlines()
    for i, line in enumerate(lines, 1):
        stripped = line.lstrip(" \t")
        leading = line[:len(line) - len(stripped)]
        if stripped and leading and not leading.startswith("\t"):
            errors.append(f"{path}:{i} 缩进使用了空格，Godot 要求 Tab")
    if "extends" not in text and "class_name" not in text:
        if text.strip():
            warns.append(f"{path} 未找到 extends（请确认是否为合法脚本）")
    for ch_open, ch_close in [("(", ")"), ("{", "}"), ("[", "]")]:
        if text.count(ch_open) != text.count(ch_close):
            warns.append(f"{path} 括号 {ch_open}{ch_close} 数量不配平（可能为字符串内符号，请人工确认）")


def parse_tscn_nodes(text: str) -> dict:
    """返回 节点完整路径 -> True 的字典，供 @onready 路径检查使用。"""
    nodes = {}      # name -> parent
    raw = {}        # name -> parent (用于构建路径)
    for line in text.splitlines():
        m = NODE_RE.match(line.strip())
        if not m:
            continue
        name = m.group(1)
        parent = m.group(2)
        raw[name] = parent if parent not in (None, ".", "") else None
    # 构建完整路径
    paths = {}
    for name, parent in raw.items():
        cur = name
        p = parent
        while p is not None:
            cur = p + "/" + cur
            p = raw.get(p)
        paths[cur] = True
    return paths


def check_tscn(path: str, root: str, errors: list, warns: list):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    exts = {}
    for m in EXT_RE.finditer(text):
        exts[m.group(3)] = (m.group(1), m.group(2))
    for eid, (etype, epath) in exts.items():
        full = res_to_path(root, epath)
        if not os.path.isfile(full):
            errors.append(f"{path} 引用的外部资源缺失: [{etype}] {epath} (id={eid})")
    for m in SCRIPT_RE.finditer(text):
        eid = m.group(1)
        if eid not in exts:
            errors.append(f"{path} 引用了未定义的 ExtResource id={eid}")
        else:
            etype, epath = exts[eid]
            if etype != "Script":
                errors.append(f"{path} 节点 script 指向了非 Script 资源: {epath}")
            if not os.path.isfile(res_to_path(root, epath)):
                errors.append(f"{path} 脚本文件缺失: {epath}")
    # sub_resource 必须先声明后使用
    sub_decl = {}
    for m in re.finditer(r'\[sub_resource type="[^"]+"\s+id="([^"]+)"\]', text):
        sub_decl[m.group(1)] = m.start()
    for m in re.finditer(r'SubResource\("([^"]+)"\)', text):
        sid = m.group(1)
        if sid not in sub_decl:
            errors.append(f"{path} 引用了未定义的 SubResource id={sid}")
        elif m.start() < sub_decl[sid]:
            errors.append(f"{path} SubResource \"{sid}\" 在声明之前被引用（tscn 顺序解析会加载失败），需把 [sub_resource] 块移到 [node] 之前")
    # load_steps = ext + sub + 1
    n_ext = len(re.findall(r'\[ext_resource ', text))
    n_sub = len(re.findall(r'\[sub_resource ', text))
    lm = re.search(r'load_steps=(\d+)', text)
    if lm and int(lm.group(1)) != n_ext + n_sub + 1:
        warns.append(f"{path} load_steps={lm.group(1)} 与实际资源数不符（应为 {n_ext + n_sub + 1}），建议修正")
    return parse_tscn_nodes(text)


def main():
    if len(sys.argv) > 1:
        root = os.path.abspath(sys.argv[1])
    else:
        root = find_project_root(os.getcwd())
    print(f"工程根目录: {root}")
    errors, warns = [], []

    proj = os.path.join(root, "project.godot")
    if not os.path.isfile(proj):
        print("ERROR: 未找到 project.godot")
        sys.exit(1)

    with open(proj, "r", encoding="utf-8") as f:
        proj_text = f.read()

    # Autoload 路径
    registered_autoloads = {}
    for m in AUTOLOAD_RE.finditer(proj_text):
        name, res = m.group(1), m.group(2)
        registered_autoloads[name] = res
        full = res_to_path(root, res)
        status = "OK" if os.path.isfile(full) else "MISSING"
        if status == "MISSING":
            errors.append(f"Autoload {name} 路径缺失: {res}")
        print(f"  Autoload {name:18s} -> {res} [{status}]")

    # 主场景
    mm = MAIN_SCENE_RE.search(proj_text)
    if mm:
        res = mm.group(1)
        full = res_to_path(root, res)
        status = "OK" if os.path.isfile(full) else "MISSING"
        if status == "MISSING":
            errors.append(f"主场景缺失: {res}")
        print(f"  主场景 -> {res} [{status}]")

    # 从 InputBootstrap.gd 收集运行时注册的动作
    runtime_actions = set()
    ib = os.path.join(root, "core", "autoload", "InputBootstrap.gd")
    if os.path.isfile(ib):
        with open(ib, "r", encoding="utf-8") as f:
            ib_text = f.read()
        for m in re.finditer(r'"([a-z_]+)"\s*:\s*\[', ib_text):
            runtime_actions.add(m.group(1))
    else:
        warns.append("未找到 core/autoload/InputBootstrap.gd，无法核对运行时注册的输入动作")

    # 扫描脚本中的输入动作引用
    action_uses = {}
    onready_map = {}   # tscn 路径 -> 节点路径集合
    for dirpath, _, files in os.walk(root):
        for fn in files:
            full = os.path.join(dirpath, fn)
            rel = "res://" + os.path.relpath(full, root).replace(os.sep, "/")
            if fn.endswith(".tscn"):
                nodes = check_tscn(full, root, errors, warns)
                onready_map[rel] = nodes
            elif fn.endswith(".gd"):
                check_gd(full, errors, warns)
                with open(full, "r", encoding="utf-8") as f:
                    gtext = f.read()
                # 输入动作
                for am in ACTION_RE.finditer(gtext):
                    names = [x for x in am.groups() if x]
                    for nm in names:
                        action_uses.setdefault(nm, set()).add(rel)
                # get_vector 4 个方向动作
                for mv in re.finditer(r'get_vector\("([^"]+)",\s*"([^"]+)",\s*"([^"]+)",\s*"([^"]+)"\)', gtext):
                    for nm in mv.groups():
                        action_uses.setdefault(nm, set()).add(rel)

    # 校验输入动作是否注册（运行时 / 内置）
    print("\n--- 输入动作核对 ---")
    for act, srcs in sorted(action_uses.items()):
        ok = act in runtime_actions or act in BUILTIN_ACTIONS
        status = "OK" if ok else "未注册!"
        if not ok:
            errors.append(f"输入动作 \"{act}\" 未在 InputBootstrap 注册，也不是内置动作；使用处: {', '.join(sorted(srcs))}")
        print(f"  {act:14s} [{status}]  {', '.join(sorted(srcs))}")

    # 校验 @onready 节点路径存在
    print("\n--- @onready 节点路径核对 ---")
    for dirpath, _, files in os.walk(root):
        for fn in files:
            if not fn.endswith(".gd"):
                continue
            full = os.path.join(dirpath, fn)
            with open(full, "r", encoding="utf-8") as f:
                gtext = f.read()
            for om in ONREADY_RE.finditer(gtext):
                node_path = om.group(1)
                # 找同目录同名 tscn
                tscn = os.path.join(dirpath, os.path.splitext(fn)[0] + ".tscn")
                tscn_rel = "res://" + os.path.relpath(tscn, root).replace(os.sep, "/")
                if tscn_rel in onready_map:
                    nodes = onready_map[tscn_rel]
                    if node_path not in nodes:
                        errors.append(f"{full} 的 @onready 路径 \"{node_path}\" 在 {tscn_rel} 中不存在")
                        print(f"  {fn} -> {node_path} [缺失!]")
                    else:
                        print(f"  {fn} -> {node_path} [OK]")
                else:
                    warns.append(f"{fn} 找不到同名场景 {tscn_rel}，跳过 @onready 路径检查")

    print("\n--- 汇总 ---")
    if warns:
        print(f"警告 {len(warns)} 条:")
        for w in warns:
            print("  WARN  " + w)
    if errors:
        print(f"错误 {len(errors)} 条:")
        for e in errors:
            print("  ERROR " + e)
        print("\n校验未通过。")
        sys.exit(1)
    print("校验通过：工程配置、Autoload、资源引用、输入动作注册、@onready 路径、脚本缩进与括号配平均无明显问题。")
    print("（GDScript 完整编译仍请在 Godot 编辑器内运行一次以确认。）")


if __name__ == "__main__":
    main()
