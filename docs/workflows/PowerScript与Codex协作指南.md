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
2. `docs/workflows/AI协作完整性审查模板.md`

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
pwsh -NoProfile -File .\scripts\pbbridge-delivery-close-loop.ps1 `
  -RepoRoot . -Workspace default `
  -Object "app.pbl:window:w_example=src/app/window/w_example.srw" `
  -ResultJsonPath .pbbridge/workspaces/default/results/preflight.json
```

预检不写入 PBL。核对当前输入、对象范围和写回授权后，使用新的当前预检继续：

```powershell
pbbridge delivery continue --from .pbbridge/workspaces/default/results/preflight.json `
  --apply --result .pbbridge/workspaces/default/results/apply.json
```

Apply 后仍由 PowerBuilder IDE 负责编译、调试和运行验收。

原生错误先核对保留的输入和 `mappingStatus`，未映射坐标不猜原行。需要规范化时，使用 `pbbridge object normalize-preview`，审阅后独立采用，再重新生成当前预检；预览不自动采用、不刷新基线。历史 `delivery history` 报告只读，不能继续执行。DataWindow 的源定义、内存填充用法及数据库适用性分别核验。

## 5. 审查重点

1. 事务路径是否完整：成功、失败、提前返回和异常分支都要检查。
2. DataWindow 行为是否被误解：行状态、缓冲区、过滤、删除和更新路径要分开说明。
3. 事件入口是否正确：不要把 UI 事件当成普通无副作用函数。
4. 编码是否稳定：不要无意整体转码。
5. 版本边界是否清楚：PB12.5 或 PB2019/PB2021 资料只能作为参考，PB9 不确定点要标为需验证。
6. 证据是否完整：最终说明必须包含 verify、diff、report 或无法运行的原因。

## 6. 分发边界

Toolkit 内置的是 Codex 可用的 PowerScript 轻量资料包。PowerScript 全文手册、PDF 抽取 Spike 和生成校验工具链由 `Powerbuilder.IDE` 父仓库维护，不要求外部项目安装或运行。

历史查询使用 `pbbridge delivery history --session-file <known-session.json>`，只读范围为已知 7.5.2/7.5.3/7.6.0 V8 session。输出位于 Git 仓库内时，先准备最近所属仓库的 `.pbbridge/local/<task>`，再传 `--result <该目录/new.json>`；仓库外的独立任务目录按既有本地路径规则判断。两种情况均须使用本地固定盘上既存的父目录，拒绝链接、受保护路径及记录的 workspace 受管位置，保留全部祖先的身份与安全检查；只新建 JSON，禁止覆盖。报告保留原状态和身份缺失，当前未评估、附件未复查，不能继续执行。


### 规范化预览的观察范围

`pbbridge object normalize-preview --repo-root <root> --workspace default --object <key> --source <source> --output-dir <new-task-dir>` 只在新任务目录的副本上编译、反导；原源码、PBL、共享库、基线和 session 不写入。完整 PB9 win-x86 bundle 的正常 CLI 会在首次适配器探测前准备同 bundle 模块，无须手设 PBSPY_HOME、PB_HOME 或额外 PATH；缺件或已加载冲突须更换完整 bundle/使用干净 CLI 进程，不能通过取消模块核验继续。

preview schemaVersion 仍为 1。`protection.scope=related-inputs`，`observedPaths[].path/role` 列出源码及格式、全部实际编译库、project/workspace 配置、PBW 及其 PBT、manifest、对象关联既存基线、CLI 与七个实际运行模块；`notCovered` 说明未引用文件、工具目录、无关历史状态及未引用 sidecar 不在比较范围。`before/after/unchanged` 仅对应此集合，不代表全仓字节守恒。未引用的 node_modules 链接不阻断；同名路径成为实际输入或输出时仍检查链接与身份。相关文件缺失、漂移或观察失败会撤销建议；输出禁区和链接保护独立保留。

仅 preview-ready 提供建议与 patch；审阅变换、原始/建议 Hash 及差异后，采用仍是独立授权的源码修改，并须重新预检。预览不执行 Apply/promotion/recovery、不刷新基线，也不证明 PB IDE Full Build 或业务验收。开发验证工具 `scripts/pb9-source-normalization/validate_preview_only.py` 仅接受 owned 合成 seed，验证函数、菜单、no-changes 和原件保全，不执行采用。

独立预览任务可以位于本项目既存 `.pbbridge/local` 下；根目录放置 PBL 不会将整个项目变成输出禁区。源码根、库文件、专用依赖目录、受管状态/缓存/锁/恢复、canonical baseline 和运行时目录仍禁止输出重叠，所有输入/输出链接检查保持。
