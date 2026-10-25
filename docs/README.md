# PbBridge.Toolkit 文档

当前分发版本为 `7.5.3`。V8 delivery 是当前 `.sr*` 交付主路径；非当前输入不提供兼容 reader，历史行为只通过正式 Git commit/tag 追溯。

## 当前阅读路径

1. [快速开始](getting-started/快速开始.md)
2. [V8 交付证据闭环使用手册](getting-started/V8交付证据闭环使用手册.md)
3. [V8 迁移说明](getting-started/V8迁移说明.md)
4. [V8 交付 JSON 契约参考](reference/V8交付JSON契约参考.md)
5. [V8 IDE 与发布证据指南](workflows/V8-IDE与发布证据指南.md)

## 产品边界

PbBridge 负责高保真文本投影、对象级审查、受控 PBL 写回，以及构建和运行证据编排。PB9 GUI 编译、运行场景和业务正确性仍由 PB IDE 与验收人员负责。
