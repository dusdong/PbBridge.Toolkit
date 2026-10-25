# Readonly Sync 安全任务卡

`pbbridge-readonly-sync.ps1` 会刷新本机导出、verify、report 和 baseline。它适合在源码事实源稳定后运行，不适合用来覆盖未写回的工作面。

命名工作区必须使用 `-WorkspaceName <id>`；PBW/PBT 路径继续独立使用 `-WorkspacePath <path>`。不要缩写成 `-Workspace`，因为它会同时匹配这两个参数并产生歧义。

```powershell
./scripts/pbbridge-readonly-sync.ps1 -RepoRoot . -WorkspaceName canyin -WorkspacePath 'CanYin.pbw'
```

## 运行前暂停条件

1. 存在未写回 `.sr*` 修改，且没有 DryRun/Apply 或备份证据。
2. 存在未解释 `.pbl` 漂移，无法判断是真实写回还是 IDE 全量编译噪声。
3. 共享库 submodule 有未提交修复，父仓库指针尚未更新。
4. 项目脚本带本地定制参数，例如 `PBW`、`ScanScope`、`ExcludeLibrary`，但当前命令没有沿用。

## 运行后检查

1. `verify.json` 是否有 blocking issue。
2. `report.md` 的 Source Layout 是否列出预期受管控 PBL。
3. baseline 是否绑定当前 PBW/PBT、LibList 和 submodule commit。
4. `.pbbridge/workspaces/` 是否仍未被 Git 跟踪。
