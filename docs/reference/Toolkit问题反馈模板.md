# Toolkit 问题反馈模板

当前 Toolkit 公共版本为 `7.5.3`。请复制本模板并填写；提交前应脱敏，不要附业务源码、数据库口令、许可证、客户数据或完整敏感 PBL。

## 1. 构建身份

```json
{
  "productVersion": "7.5.3",
  "cliSha256": "",
  "toolkitCommit": "",
  "actualToolkitHead": "",
  "parentGitlinkCommit": "",
  "toolkitWorktreeStatus": "",
  "runtimeContractSha256": "",
  "manifestSha256": ""
}
```

同时附 `PbBridge.Cli.exe`、`manifest.json`、`checks/toolkit-runtime-contract.json` 的本地 SHA-256 计算结果，以及 `checks/SHA256SUMS.txt` 核验结果。不要只填写版本号。

## 2. 最小复现

- 操作系统、PowerShell、PowerBuilder/PBSDK/PBSpy 版本：
- 完整命令（敏感路径可做一致替换）：
- workspace、target PBL 与期望行为：
- CLI 是否报告实际文件锁、访问拒绝、目标漂移或并发写入（附具体路径、reason code 与诊断；无需预先检查或关闭 PB IDE）：
- 是否在至少一个全新隔离副本中复现：

## 3. 结构化证据

- `producerBuildIdentity` 与 canonical `factsHash`
- closure hash、staging map、失败 stage/reason code
- 失败条目、源/目标路径、底层异常类型、HResult、重试次数、已复制条目数
- target 与依赖 PBL 的写入前后 SHA-256
- importer 调用次数、transaction/session 标识和结果 JSON 路径
- `writebackReadiness`、可原样执行的 `nextAction.command` 与 handoff 中的全局 reason code
- 五次独立复现的结果摘要（若问题稳定复现）

## 4. 安全声明

- 原始工作区是否发生写入：
- staging/candidate 是否位于 `.pbbridge/local` 或其他 local-only 路径：
- 是否确认 PBL 前后哈希不变：
- 已移除的敏感数据：

如构建身份缺失或与当前发布不一致，请先完整重新同步 Toolkit、清理旧 CLI 缓存并重新运行 V8 preflight，再提交新证据。
