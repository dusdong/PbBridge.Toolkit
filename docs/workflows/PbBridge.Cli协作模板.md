> 本文档由 `PbBridge.Toolkit` 从父仓库手册同步生成。
> 当前 toolkit 固定提供 `CLI win-x86 + IDE win-x64` 的 Windows 运行时组合；正式写回支持矩阵仍以父仓库事实源为准。
# PbBridge.Cli 协作模板

不确定入口时先运行 `pbbridge toolkit entrypoints explain --intent <intent>`。当前 `.sr*` 交付只使用 V8 preflight、continue 和 session evidence。

## 给 AI 的任务上下文

```text
项目根目录：<repo-root>
workspace id：<id>
目标对象：<workspace-relative-pbl-path>:<object-type>:<object-name>
源码路径：<source.sr*>
目标：<业务变更>
约束：先执行 V8 preflight；未经授权不 Apply；写回、IDE、包装、部署、运行和业务验收分别报告。
```

## 执行模板

```powershell
pbbridge delivery close-loop --repo-root <repo-root> --workspace <id> --object "<object-key>=<source-path>" --progress text --result .pbbridge/workspaces/<id>/results/delivery-v8/preflight.json
pbbridge delivery continue --from .pbbridge/workspaces/<id>/results/delivery-v8/preflight.json --apply --result .pbbridge/workspaces/<id>/results/delivery-v8/apply.json
pbbridge delivery ingest-ide-log --session <session-id> --log <pb-build-or-runtime.log>
pbbridge delivery attest --session <session-id> --stage build --status passed --actor <actor-id> --note "<人工验收说明>" --evidence <evidence-path>
pbbridge delivery handoff-summary --session <session-id> --format markdown
```

包装与部署证据必须绑定同一 session：

```powershell
pbbridge target packaging inspect --target <project.pbt> --artifact-root <artifact-root> --session <session-id> --result <packaging.json>
pbbridge target deployment verify --packaging-result <packaging.json> --dependency-manifest <runtime-dependencies.json> --artifact-root <artifact-root> --session <session-id> --result <deployment.json>
```

汇报必须分开说明全局健康、对象交付、IDE/发布验收，并包含 `writebackReadiness`、`ideReadiness`、`releaseReadiness`、十项 `verificationCoverage`、冲突、恢复、session 与下一动作。`verified` 和 `attested` 不得混用；PB 编译、运行、部署或业务验收未提供证据时必须保持 `not-checked`。
