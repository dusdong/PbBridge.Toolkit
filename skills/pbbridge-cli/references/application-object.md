# Application 对象任务卡

Application 对象可以参与 DryRun，但 Apply 写回在 PB9 + PBSpy/PBSDK 路径上可能遇到 `CompileEntryImport -11`。该错误不只属于 application，对 function、userobject、window 等对象也可能表示写回编译上下文或导入链路受限。

## 处理规则

1. 先保留 DryRun、Apply、diagnostics bundle 和失败阶段证据。
2. 先按对象类型、final library list、current application、源码编码和 compileMessages 分层解释，不把错误简单归因到 application。
3. 满足 `doctor --adapter orca` 准入证据时，可显式尝试 PBSpyORCA candidate 链路；它不是默认写回器，也不是正式 supported。
4. candidate 仍失败时再转 PowerBuilder IDE 兜底；兜底后必须 re-export / verify / diff 或反向导出确认。
5. 最终仍需 PowerBuilder IDE Regenerate / Full Build 和业务运行验收。
