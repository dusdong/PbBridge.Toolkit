# PowerScript 与 Codex 协作指南

本文说明外部 PowerBuilder 项目接入 `PbBridge.Toolkit` 后，Codex 如何使用 toolkit 内置的 PowerScript 资料完成阅读、审查、修改和迁移辅助。

## 1. 定位

`PbBridge.Toolkit` 负责把 PowerBuilder 项目的二进制资产转换成 Codex 可读的文本工作面，并提供 PowerScript 语言背景。

PowerScript 资料的最终使用目标是：

1. 帮 Codex 正确理解 `.sru/.srw/.srm/.srd` 等导出源码。
2. 帮 Codex 审查事务、DataWindow、事件和对象生命周期风险。
3. 帮 Codex 生成迁移说明和 C# / Avalonia 目标设计。
4. 减少把现代语言习惯误套到 PowerScript 上的错误。

## 2. 推荐读取顺序

当任务涉及 `.sr*` 或 PowerScript 时，Codex 应按下面顺序读取：

1. `CODEX-START.md`
2. `skills/pbbridge-cli/SKILL.md`
3. `skills/powerbuilder-powerscript/SKILL.md`
4. `syntax/powerscript-language-summary.md`
5. `syntax/powerscript-pb9-compatibility.md`
6. 按任务读取 `skills/powerbuilder-powerscript/references/` 下的速查和示例

如果任务是代码审查，再读取：

1. `syntax/powerscript-review-checklist.md`
2. `docs/AI协作完整性审查模板.md`

如果任务是迁移，再读取：

1. `syntax/powerscript-migration-guide.md`
2. `skills/powerbuilder-powerscript/references/powerscript-示例.md`

## 3. 阅读真实 `.sr*`

阅读真实源码时，不要只看单个文件。至少结合：

1. 默认布局下的 `<PBL所在目录>/src/<normalized-pbl-name>/**/*.sr*`
2. `.pbbridge/workspaces/default/artifacts/pbbridge/manifest.json`
3. `.pbbridge/workspaces/default/artifacts/pbbridge/verify.json`
4. `.pbbridge/workspaces/default/artifacts/pbbridge/report.md`

当前外部项目统一使用 `beside-pbl-src`，源码位置以 manifest 中的 `sourceRoot` 为准；升级后若发现旧状态文件，应重新运行 `pbbridge source export` 或 `pbbridge workspace readonly-sync` 生成当前 facts。

对象定位以 manifest 为准：`ObjectKey` 主键为 `<workspace-relative-pbl-path>:<object-type>:<object-name>`，路径统一使用 `/`，例如 `pb-libs/Lib_Query.pbl:userobject:nvo_query`。

如果要判断影响范围，继续读取基线目录和 diff 结果。

## 4. 修改真实 `.sr*`

Codex 只应修改导出的 `.sr*` 文本，不直接修改 `.pbl`。修改完成后应运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-import-sr.ps1
```

该命令默认执行 DryRun。用户确认后才允许：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-import-sr.ps1 -Apply
```

Apply 后仍由 PowerBuilder IDE 负责编译、调试和运行验收。

## 5. 审查重点

1. 事务路径是否完整：成功、失败、提前返回和异常分支都要检查。
2. DataWindow 行为是否被误解：行状态、缓冲区、过滤、删除和更新路径要分开说明。
3. 事件入口是否正确：不要把 UI 事件当成普通无副作用函数。
4. 编码是否稳定：不要无意整体转码。
5. 版本边界是否清楚：PB12.5 或 PB2019/PB2021 资料只能作为参考，PB9 不确定点要标为需验证。
6. 证据是否完整：最终说明必须包含 verify、diff、report 或无法运行的原因。

## 6. 分发边界

Toolkit 内置的是 Codex 可用的 PowerScript 轻量资料包。PowerScript 全文手册、PDF 抽取 Spike 和生成校验工具链由 `Powerbuilder.IDE` 父仓库维护，不要求外部项目安装或运行。
