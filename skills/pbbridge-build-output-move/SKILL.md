---
name: pbbridge-build-output-move
description: 当用户在 PowerBuilder IDE 编译完成后，需要整理、预览或移动 .pbd 与 .exe 构建产物到 bin，运行 move-pb-build-output.ps1，或询问编译产物整理规则时使用。
---

# PbBridge Build Output Move

使用本 skill 在 PowerBuilder IDE 编译、调试或运行验收之后整理构建产物。此流程只移动 `*.pbd` 与应用 `*.exe`，不参与 `.pbl -> .sr* -> .pbl` 文本协作，也不代表 Codex 完成了 PowerBuilder 编译。

## 脚本选择

1. 在外部业务项目中，优先使用项目根目录的 `scripts/move-pb-build-output.ps1`。
2. 如果项目还没有该脚本，提示用户从 `templates/external-project/move-pb-build-output.ps1` 复制并按项目命名规则调整。
3. 不临时手写移动逻辑；脚本不存在时只给出接入建议，不直接批量移动文件。

## 默认安全流程

先预览，不移动文件：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\move-pb-build-output.ps1 -WhatIf
```

用户确认预览结果后，再正式移动：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\move-pb-build-output.ps1
```

需要审计结果时，使用：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\move-pb-build-output.ps1 -PassThru
```

## 移动边界

允许处理：

1. 仓库根目录直接子文件中的 `*.pbd`
2. 仓库根目录直接子文件中的应用 `*.exe`
3. 根目录下 `pb-*` 依赖 PB 子模块直接子文件中的 `*.pbd` 和 `*.exe`

禁止处理：

1. `.pbl`、`.pbw`、`.pbt`
2. `.sr*`
3. `.pbbridge/workspaces/`
4. toolkit runtime、历史发布目录、第三方工具目录中的可执行文件

默认脚本固定排除 `pbregexp_pb9.pbd`。如业务项目不使用 `pb-*` 命名依赖模块，应先调整脚本顶部的固定目录发现规则。

## Git 与交接

1. `bin/` 是否提交由业务项目发布策略决定；普通开发默认把它视为可再生构建产物。
2. 如果项目要求提交 `*.pbd` 或 `*.exe`，必须确认 `.gitattributes` 已通过 Git LFS 管理二进制。
3. 结束时说明：是否只执行了 `-WhatIf`、实际移动了哪些文件、是否覆盖 `bin/` 同名文件、PowerBuilder IDE 编译和业务验收是否由用户完成。

## 权威资料

- `docs/workflows/PowerBuilder构建产物整理脚本指南.md`：脚本用途、安全边界和 Git 管理建议。
- `templates/external-project/move-pb-build-output.ps1`：外部项目可复制的固定脚本。
- `CODEX-START.md`：导入 PBL 后的编译产物整理交接规则。
