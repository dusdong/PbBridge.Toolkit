# PowerBuilder 构建产物整理脚本指南

本指南用于外部 PowerBuilder 项目在 IDE 编译、调试和运行验收之后，把编译生成的 `*.pbd` 与应用 `*.exe` 移动到仓库根目录 `bin/`。

该脚本只整理编译产物，不参与 `.pbl -> .sr* -> .pbl` 的文本协作流程，也不替代 PowerBuilder IDE 编译。

## 1. 适用场景

典型场景：

1. PowerBuilder IDE Full Build 后，项目根目录出现多个 `*.pbd` 或应用 `*.exe`。
2. 依赖的 PB 子模块，例如 `pb-langchao`、`pb-jiudian` 或其他项目实际使用的 `pb-*` 模块，也在模块目录下生成 `*.pbd` 或 `*.exe`。
3. 团队希望把运行产物集中到根目录 `bin/`，保持项目根目录和依赖 PB 子模块目录只保留 PB 库、项目文件、源码事实源和协作脚本。

推荐把 `templates/external-project/move-pb-build-output.ps1` 复制到外部项目仓库的 `scripts/` 目录后使用。

该模板是固定脚本，不要求日常传入路径参数。默认会按项目实际目录发现仓库根目录下现有的 `pb-*` 依赖 PB 子模块；如果项目依赖模块不使用 `pb-*` 命名，应在脚本顶部把固定目录发现规则调整为该项目自己的模块清单。

## 2. 安全边界

脚本只处理：

1. `*.pbd`
2. `*.exe`

脚本不处理：

1. `*.pbl`，库文件本身不能被当作编译产物移动。
2. `.sr*`，这是 Codex / Copilot 的文本源码事实源。
3. `.pbw`、`.pbt`，这是 PowerBuilder 工作区和 target 定义。
4. `.pbbridge/workspaces/`，这是每台机器自己的可再生导出、baseline、diff、plan 和诊断目录。

默认只扫描仓库根目录和根目录下现有 `pb-*` 依赖 PB 子模块的直接子文件，不递归扫描子目录，避免误移动 `.pbbridge`、toolkit runtime、历史发布目录或第三方工具中的 `*.exe`。

脚本固定排除 `pbregexp_pb9.pbd`，避免误移动项目保留的老依赖。

## 3. 推荐用法

先预览，不移动文件：

```powershell
pwsh -NoProfile -File .\scripts\move-pb-build-output.ps1 -WhatIf
```

确认预览结果后再正式移动：

```powershell
pwsh -NoProfile -File .\scripts\move-pb-build-output.ps1
```

默认会覆盖 `bin/` 中已有的同名编译产物。需要审计结果时，可输出结构化结果：

```powershell
pwsh -NoProfile -File .\scripts\move-pb-build-output.ps1 -PassThru
```

## 4. Git 管理建议

`bin/` 是否提交由业务项目自己的发布策略决定。普通开发默认把 `bin/` 视为可再生构建产物目录；如果项目确实要求把运行包随仓库版本化保存，应在 `.gitattributes` 中为 `*.pbd`、`*.exe` 等二进制启用 Git LFS。

无论是否提交 `bin/`，都不要通过移动脚本改变 `.pbl` 的位置。`.pbl` 是 PowerBuilder 库文件或项目基线资产，应该继续按项目既有 PB 二进制管理策略处理。
