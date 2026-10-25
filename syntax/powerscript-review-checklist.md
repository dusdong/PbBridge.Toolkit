# PowerScript 审查清单

本清单用于 Codex 审查真实 `.sru/.srw/.srm/.srd` 修改，重点关注行为回归、事务安全和可导入性。

## 1. 修改前

1. 先阅读 `.pbbridge/workspaces/default/artifacts/pbbridge/manifest.json`、`verify.json`、`report.md`。
2. 确认修改对象来自 manifest 中 `libraries[].sourceRoot` 指向的 `.sr*`；默认 `beside-pbl-src` 布局下通常是 `<PBL所在目录>/src/<normalized-pbl-name>/**/*.sr*`。
3. 当前生产布局只使用 `beside-pbl-src`；如布局事实不一致，先重新运行 export 或 readonly-sync 生成当前 facts。
4. 确认对象键时以 manifest 为准：`ObjectKey` 是 `<workspace-relative-pbl-path>:<object-type>:<object-name>`，路径统一使用 `/`。
5. 确认文件编码，避免无意把旧源码整体改成另一种编码。
6. 用文本检索找到同名函数、事件、全局函数和共享对象调用点。

## 2. 源码审查

1. 检查事件入口是否正确，尤其是窗口 open/close、按钮 clicked、DataWindow itemchanged。
2. 检查变量作用域，不把局部变量、实例变量、共享变量和全局变量混用。
3. 检查 `return`、`halt`、`goto`、异常路径是否绕过资源释放或事务处理。
4. 检查字符串拼接 SQL、动态 DataWindow、反射式调用和外部 DLL 调用。
5. 检查注释和显示文本，避免破坏业务中文、提示消息和既有术语。

## 3. 事务审查

1. 每个数据库操作后应关注 `SQLCA.SQLCode` 或项目封装函数结果。
2. `commit` 前确认所有必要操作都成功。
3. 失败路径应有 `rollback` 或明确交给上层事务处理。
4. 错误消息应保留足够业务上下文，不能吞掉 SQL 错误。
5. 提前返回路径不能绕过游标关闭、连接释放或状态恢复。

## 4. 修改后

1. 运行 toolkit 的 `verify / diff / report`，用证据说明结果。
2. 如需导回 `.pbl`，先 DryRun，再由用户确认 Apply。
3. Apply 后仍需 PowerBuilder IDE 编译、调试和运行验收。
4. Codex 最终说明应列出修改对象、验证命令、导入状态和待人工验收事项。
