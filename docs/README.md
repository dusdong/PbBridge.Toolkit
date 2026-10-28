# PbBridge.Toolkit 文档

资产生成版本为 `7.6.0`。V8 delivery 是当前 `.sr*` 交付主路径；当前执行拒绝非当前输入。7.6.0 开发候选的完整发行资格和发布事实须另查独立回执。

历史查询：`pbbridge delivery history --session-file <path> [--result <new-independent-json>]` 仅读取已知 7.5.2/7.5.3 V8 session。独立历史报告的当前状态未评估，附件未复查，不能继续执行或进入当前 evidence；不改变 workspace 和原文件。

## 当前阅读路径

1. [快速开始](getting-started/快速开始.md)
2. [V8 交付证据闭环使用手册](getting-started/V8交付证据闭环使用手册.md)
3. [V8 迁移说明](getting-started/V8迁移说明.md)
4. [V8 交付 JSON 契约参考](reference/V8交付JSON契约参考.md)
5. [V8 IDE 与发布证据指南](workflows/V8-IDE与发布证据指南.md)
6. [本包冻结说明与外部回执位置](7.6.0发布说明.md)
7. [编译诊断到原始源码定位](reference/编译诊断到原始源码定位.md)
8. [源码规范化预览与独立采用](reference/源码规范化预览与独立采用.md)
9. [DataWindow 分类与 PB9 验收](reference/DataWindow分类与PB9验收.md)

## 产品边界

PbBridge 负责高保真文本投影、对象级审查、受控 PBL 写回，以及构建和运行证据编排。PB9 GUI 编译、运行场景和业务正确性仍由 PB IDE 与验收人员负责。
