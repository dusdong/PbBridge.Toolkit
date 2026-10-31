# PbBridge.Toolkit 文档

资产生成版本为 `7.6.1`。V8 delivery 是当前 `.sr*` 交付主路径；当前执行拒绝非当前输入。7.6.1 开发候选的完整发行资格和发布事实须另查独立回执。

历史查询：`pbbridge delivery history --session-file <path> [--result <new-independent-json>]` 仅读取已知 7.5.2/7.5.3/7.6.0 V8 session。独立历史报告的当前状态未评估，附件未复查，不能继续执行或进入当前 evidence；不改变 workspace 和原文件。

## 当前阅读路径

1. [快速开始](getting-started/快速开始.md)
2. [V8 交付证据闭环使用手册](getting-started/V8交付证据闭环使用手册.md)
3. [V8 迁移说明](getting-started/V8迁移说明.md)
4. [V8 交付 JSON 契约参考](reference/V8交付JSON契约参考.md)
5. [V8 IDE 与发布证据指南](workflows/V8-IDE与发布证据指南.md)
6. [本包冻结说明与外部回执位置](7.6.1发布说明.md)
7. [编译诊断到原始源码定位](reference/编译诊断到原始源码定位.md)
8. [源码规范化预览与独立采用](reference/源码规范化预览与独立采用.md)
9. [DataWindow 分类与 PB9 验收](reference/DataWindow分类与PB9验收.md)

## 产品边界

PbBridge 负责高保真文本投影、对象级审查、受控 PBL 写回，以及构建和运行证据编排。PB9 GUI 编译、运行场景和业务正确性仍由 PB IDE 与验收人员负责。

历史报告默认输出 stdout。显式 `--result` 位于 Git 仓库内时，必须指向最近所属仓库（含 `.git` 文件边界）的既存 `.pbbridge/local/<task>/new.json`，外层仓库不改变归属；仓库外的独立任务目录继续按既有本地路径规则判断。两种情况均须使用本地固定盘上既存的父目录，拒绝链接、受保护路径及记录的 workspace 受管位置，所有祖先的身份与安全检查仍生效。目标只能是新建 JSON，重复路径拒绝且原报告不变。历史读取不会访问记录的 workspace 或附件；当前交付必须重新生成同构建 preflight/session。


### 规范化预览的观察范围

`pbbridge object normalize-preview --repo-root <root> --workspace default --object <key> --source <source> --output-dir <new-task-dir>` 只在新任务目录的副本上编译、反导；原源码、PBL、共享库、基线和 session 不写入。完整 PB9 win-x86 bundle 的正常 CLI 会在首次适配器探测前准备同 bundle 模块，无须手设 PBSPY_HOME、PB_HOME 或额外 PATH；缺件或已加载冲突须更换完整 bundle/使用干净 CLI 进程，不能通过取消模块核验继续。

preview schemaVersion 仍为 1。`protection.scope=related-inputs`，`observedPaths[].path/role` 列出源码及格式、全部实际编译库、project/workspace 配置、PBW 及其 PBT、manifest、对象关联既存基线、CLI 与七个实际运行模块；`notCovered` 说明未引用文件、工具目录、无关历史状态及未引用 sidecar 不在比较范围。`before/after/unchanged` 仅对应此集合，不代表全仓字节守恒。未引用的 node_modules 链接不阻断；同名路径成为实际输入或输出时仍检查链接与身份。相关文件缺失、漂移或观察失败会撤销建议；输出禁区和链接保护独立保留。

仅 preview-ready 提供建议与 patch；审阅变换、原始/建议 Hash 及差异后，采用仍是独立授权的源码修改，并须重新预检。预览不执行 Apply/promotion/recovery、不刷新基线，也不证明 PB IDE Full Build 或业务验收。开发验证工具 `scripts/pb9-source-normalization/validate_preview_only.py` 仅接受 owned 合成 seed，验证函数、菜单、no-changes 和原件保全，不执行采用。

独立预览任务可以位于本项目既存 `.pbbridge/local` 下；根目录放置 PBL 不会将整个项目变成输出禁区。源码根、库文件、专用依赖目录、受管状态/缓存/锁/恢复、canonical baseline 和运行时目录仍禁止输出重叠，所有输入/输出链接检查保持。
