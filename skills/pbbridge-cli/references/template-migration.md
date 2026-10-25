# 模板迁移任务卡

外部项目的 `AGENTS.md`、`pbbridge-readonly-sync.ps1`、`pbbridge-import-sr.ps1`、`move-pb-build-output.ps1` 可能已有项目定制，不能直接覆盖。

## 合并规则

1. 从 V7.2.2 过渡到 V7.2.3 时，先运行 canonical Toolkit 中的 `templates/external-project/pbbridge-template-migrate.ps1`，原子安装项目 `scripts/` 下的迁移入口与模块；安装成功后，日常统一运行项目入口。
2. 带 `PbBridge-TemplateVersion` 标记且未本地修改的模板脚本，可按报告覆盖。
3. 无版本标记或包含本地参数的脚本必须人工 merge。
4. 保留 `PBW` 路径、`ScanScope`、`ExcludeLibrary`、共享库配置、OpenSpec/项目规则和构建产物排除项。
5. 覆盖或合并前保留 backup。
6. 修改 PowerShell 模板后运行 parser check，避免大小写变量冲突。
7. `scripts/pbbridge-template-migrate.ps1` 与 `scripts/PbBridge.TemplateMigration.psm1` 属于 `migration-bootstrap` 原子资产组；未知自定义必须人工处理，不允许只升级其中一个成员。
8. ToolkitRoot 依次使用显式参数、项目 `.pbbridge/PbBridge.Toolkit`、合法 canonical 模板目录；都不可用时应保留 `template-migration-toolkit-root-not-found` 诊断。
