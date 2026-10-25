# PbBridge 失败码处置表

| 现象 | 常见原因 | 能否自动继续 | 下一步 |
| --- | --- | --- | --- |
| `CompileEntryImport -11` | PBSpy/PBSDK 编译导入失败，application 对象尤其常见 | 否 | 保留 diagnostics，按对象类型判断是否人工 ORCA/IDE 兜底 |
| manifest/sourceRoot 不一致 | 复制 state、迁移布局或旧 manifest 指向旧路径 | 否 | 先 `validate-manifest`，必要时重新 readonly sync/export |
| checksum drift | `.sr*` 或 `.pbl` 与 baseline 不一致 | 视范围 | 先 diff/report，确认是真实修改还是过期 baseline |
| post-apply review failed | Apply 后反导出不匹配或写回不完整 | 否 | 读取 diagnostics bundle，暂停提交 `.pbl` |
| partial writeback | 部分对象写回成功、部分失败 | 否 | 不宣称写回完成，按失败对象重新计划 |
| PBSpy DLL 加载失败 | x86 运行时、PBSDK、路径或权限问题 | 否 | 运行 doctor，确认 toolkit runtime/pbspy/win-x86 |
| `sourceRoot` 缺失 | manifest 损坏或导出不完整 | 否 | 重新运行 readonly sync，检查 Source Layout |
| PowerShell 参数变量大小写冲突 | PowerShell 变量大小写不敏感 | 否 | 修复脚本变量名，运行 parser check |
