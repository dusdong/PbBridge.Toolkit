# AGENTS.md 示例

本项目通过 submodule 引入 `PbBridge.Toolkit`，项目私有规则写在本文件，通用协作资产统一引用 toolkit。

## 推荐约定

1. toolkit 挂载路径：`.pbbridge/PbBridge.Toolkit`
2. CLI 入口：`.pbbridge/PbBridge.Toolkit/runtime/cli/win-x86/PbBridge.Cli.exe`
3. IDE 入口：`.pbbridge/PbBridge.Toolkit/runtime/ide/win-x64/SharpIDE.exe`
4. 导出产物目录：`.pbbridge/workspaces/default/artifacts/pbbridge`
5. 协作文档：`.pbbridge/PbBridge.Toolkit/docs/`
6. skill 资产：`.pbbridge/PbBridge.Toolkit/skills/`

## 项目私有规则建议

1. 写明 `.pbw` 与导出目录约定
2. 写明 allowlist、对象范围和审查要求
3. 写明是否允许进入自动写回链路
4. 明确项目自己的事实源文档和脚本入口
