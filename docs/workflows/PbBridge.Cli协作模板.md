> 本文档由 `PbBridge.Toolkit` 从父仓库手册同步生成。
> 当前 toolkit 固定提供 `CLI win-x86 + IDE win-x64` 的 Windows 运行时组合；正式写回支持矩阵仍以父仓库事实源为准。
# PbBridge.Cli 协作模板

按[第一次完成一次业务变更](../getting-started/第一次完成一次业务变更.md)推进，每次只复制当前阶段。以下在业务项目根目录执行；`pbbridge` 表示当前完整 Toolkit 的 CLI（也可用快速开始中的 `$pbbridge` 路径及 `&` 调用）。把尖括号占位符换成实际值。命令参数以当前 CLI `delivery --help` 为准。

## 给 AI 的任务上下文

```text
项目根目录：<repo-root>
workspace id：<id>
目标对象：<workspace-relative-pbl-path>:<object-type>:<object-name>
源码路径：<source.sr*>
目标：<业务变更>
当前授权范围：<实际已授权的源码修改/写回范围；没有写回授权则明确写明>
约束：先预检并审阅真实结果；仅执行当前授权允许的写回；写回、IDE、包装、部署、运行和业务验收分别报告。
```

## 1. 预检与审阅

不确定当前意图对应哪个入口时，先运行 `pbbridge toolkit entrypoints explain --intent <intent>` 查看入口选择说明。

```powershell
pbbridge doctor
pbbridge delivery close-loop --repo-root <repo-root> --workspace <id> --object "<object-key>=<source-path>" --progress text --result .pbbridge/workspaces/<id>/results/delivery-v8/preflight.json
```

停止复制，读取 stdout 指向的完整预检结果：核对真实 workspace、PBL/对象、源码映射、session、阻塞原因及下一动作；确认可执行性。源码/依赖修正后必须重新预检并采用新结果。未通过时保留真实失败，不能修改结果 JSON 继续；处理方式见[项目接入](../getting-started/外部PowerBuilder项目接入Codex.md)。需要人工时可直接用该 session 生成下文 handoff，尚未发生的写回不能描述为完成。

## 2. 确认授权后写回

只有上述审阅允许继续，且当前任务确已授权这些 workspace/对象的写回时，才复制这一段；`--from` 必须是刚才审阅的实际预检结果。授权不足时停在这里。

```powershell
pbbridge delivery continue --from .pbbridge/workspaces/<id>/results/delivery-v8/preflight.json --apply --result .pbbridge/workspaces/<id>/results/delivery-v8/apply.json
```

检查实际成功对象、post-apply review、promotion intent 与 recovery；失败或阻塞按具体 reason code 和下一动作处理，不原样循环重试。写回不证明 IDE 编译、运行或业务正确。记录这次实际 session id，后续证据与交接都使用同一 session；若修复后产生新预检，则改用新结果对应的 session，并保留原尝试事实。

## 3. 先交接再登记实际证据

需要 PB IDE 动作而尚无结果时先生成交接，无需先填写验收通过：

```powershell
pbbridge delivery handoff-summary --session <session-id> --format markdown
```

交接中列出 workspace/PBW、PBL/对象、session、Regenerate/Full Build/运行或业务场景的适用步骤及所需日志。用户在 IDE 完成这些动作后，再核对返回证据的对象、范围和 session。没有实际证据保持 `not-checked`，已有失败保留。Codex 不自动操控 PB IDE，具体边界见[项目接入](../getting-started/外部PowerBuilder项目接入Codex.md)。

收到实际 IDE 日志，且适合日志解析入口时，单独执行：

```powershell
pbbridge delivery ingest-ide-log --session <session-id> --log <actual-pb-build-or-runtime.log>
```

需要登记实际人工验收时，单独选择适用的 stage（`build`、`runtime` 或 `business`），status 只能依据实际结果填 `passed` 或 `failed`。下面没有默认通过；缺少结果时不要执行 attest。填写真实执行者、范围/步骤/结果说明和证据文件，而不是把人工操作说明当成命令。

```powershell
pbbridge delivery attest --session <session-id> --stage <actual-stage> --status <actual-status> --actor <actual-actor-id> --note "<实际验收范围、步骤与结果>" --evidence <actual-evidence-path>
```

人工通过只记为 `attested`，不能冒充 `verified`；图片证据为 `pending-review`，需要继续审阅。日志解析与人工声明按适用情况选择，不为凑齐状态重复登记同一事实。证据登记后检查返回状态，再刷新同一 session 的交接：

```powershell
pbbridge delivery handoff-summary --session <session-id> --format markdown
```

## 4. 任务确需包装与部署时

写回后，只在任务适用且已授权时收集以下证据，也必须绑定上述同一 session：

```powershell
pbbridge target packaging inspect --target <project.pbt> --artifact-root <artifact-root> --session <session-id> --result <packaging.json>
pbbridge target deployment verify --packaging-result <packaging.json> --dependency-manifest <runtime-dependencies.json> --artifact-root <artifact-root> --session <session-id> --result <deployment.json>
```

汇报分别说明全局健康、对象交付、IDE/发布验收，包含 `writebackReadiness`、`ideReadiness`、`releaseReadiness`、十项 `verificationCoverage`、冲突、恢复、session 与下一动作。多对象或后续修复结果用[业务变更交付视图](../reference/业务变更交付视图.md)查阅；诊断见[源码定位](../reference/编译诊断到原始源码定位.md)，反馈见[实际模板](../reference/Toolkit问题反馈模板.md)。
