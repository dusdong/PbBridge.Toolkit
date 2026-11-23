# PBSpy/PBSDK 运行时摘要

## 当前运行时

1. 平台：`win-x86`
2. 主 DLL：`runtime/pbspy/win-x86/PBSpy.dll`
3. PB9 运行时：`runtime/pbspy/win-x86/PBSDK/PB090/`
4. 来源：分发运行时清单或父仓库 `reference-pbl/PBSpyORCA/PBSpyORCA/`

## 说明

1. 该运行时用于 PB9 PBL 写回路径：`Windows x86 + PBSpy + PBSDK`
2. CLI 会按 toolkit 相对路径自动探测 `runtime/pbspy/win-x86/`
3. 如果外部项目替换或删除该目录，才需要额外配置 `PBSPY_HOME` 或 `PB_HOME`
4. 该运行时不替代 PowerBuilder IDE 编译、调试和运行验收
5. 对象返回 `CompileEntryImport -11` 时保留 DryRun / Apply 诊断；核对 PB9、PBSpy.dll、PBSDK、进程架构、编码和库列表准入证据后，可显式尝试 `--adapter orca` 的 PBSpyORCA candidate。该路径不作为默认写回器，也不提升为 supported。
6. candidate 仍失败时交由 PowerBuilder IDE 处理；兜底后 re-export / verify / diff，并完成 IDE Regenerate / Full Build 和实际运行验收。
