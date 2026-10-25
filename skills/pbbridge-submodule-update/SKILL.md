---
name: pbbridge-submodule-update
description: 当用户需要更新 PbBridge.Toolkit、pb-libs、pb-langchao 或其他 PowerBuilder 共享库 submodule，拉取子模块更新，刷新父仓库 submodule 指针，重新运行 pbbridge-readonly-sync、verify、report 或更新 baseline 时使用。
---

# PbBridge Submodule Update

使用本 skill 处理 toolkit 或 PowerBuilder 共享库 submodule 更新后的完整协作流程。目标是把“子模块 commit 变了”安全地落到消费项目当前 `.pbw/.pbt/LibList`、`.sr*` 事实源和 `.pbbridge/workspaces/default` baseline 上。

## 先判断 Git 边界

1. 在父仓库运行 `git status --short --branch` 和 `git submodule status --recursive`，确认目标 submodule 路径与当前指针。
2. 进入目标 submodule 后运行 `git status --short --branch`，若子模块内部有未提交修改，先停止更新并让用户决定是否提交、暂存或放弃。
3. 只更新用户指定的 submodule；用户只说“toolkit 更新”时，默认目标是 `.pbbridge/PbBridge.Toolkit` 或本仓库的 `Toolkit/PbBridge.Toolkit`。
4. 用户只说“pb-libs 更新”或“共享库更新”时，把 `pb-libs`、`pb-langchao` 等作为外部 PB 项目的典型 submodule 名称处理，先用 `.gitmodules` 或目录事实确认真实路径。
5. 子模块内部如果有未提交 `.sr*`、`.pbl` 或脚本修改，必须先完成子模块内提交或暂停，不要在父仓只提交指针。

## 更新流程

1. 在目标 submodule 中执行 fetch 或 pull 前，先报告当前分支、HEAD、远端和工作区状态。
2. 拉取后记录旧 commit 与新 commit；不要把“已拉取子模块”说成“父仓库已提交更新”。
3. 回到父仓库检查 `git status --short`，确认父仓库是否出现 submodule 指针变更。
4. 如果更新的是 `PbBridge.Toolkit`，优先阅读新的 `CODEX-START.md`、`manifest.json` 和相关 `skills/*/SKILL.md`，确认流程或模板是否变化。
5. 如果更新的是 `pb-libs` 等共享库，必须把消费项目 baseline 理解为“当前 `.pbw/.pbt` + 当前 submodule commit”的集成快照。

## Toolkit 最新快照检查

`PbBridge.Toolkit` 子仓按最新版二进制快照维护，远端历史和 tag 不作为外部项目的更新信号。判断 Toolkit 是否有更新时，只比较本地 submodule `HEAD` 与远端 `origin/master`：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-toolkit-update.ps1
```

默认检查只写出 `.pbbridge/toolkit-update-check.json` 并提示 `current/outdated/blocked`，不会更新工作树、不会 stage、不会提交。需要更新到远端最新快照时显式运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-toolkit-update.ps1 -Apply
```

`-Apply` 只在 Toolkit submodule 工作区干净时 checkout `refs/remotes/origin/master`；完成后必须回父项目提交 `.pbbridge/PbBridge.Toolkit` submodule 指针。不要通过 Gitee 提交列表、旧 tag 或历史提交数量判断 Toolkit 是否最新。

## 共享库回灌流程

当父项目审查发现共享库对象需要修复时，先分类为“回灌共享库”“项目私有保留”或“废弃旧副本”。如果判定为回灌共享库，必须切换到共享库 submodule 工作区执行：

1. 在 submodule 内修改 `src/<normalized-pbl-name>/**/*.sr*` 和必要伴随文件。
2. 使用 `pbbridge-cli` 工作流完成 `verify / diff / shared-library gate / v4 import-object 或 import-objects DryRun / Apply --writeback --post-apply-review`；对象级写回使用 manifest 输出的路径化 `ObjectKey`，交接说明也写路径化 key。
3. 确认 submodule 内 `src`、对应 `.pbl`、post-apply review 或反导出证据一致。
4. 在 submodule 内提交并推送共享库修复，提交说明写明 PBL、对象、影响范围和验证证据。
5. 回父仓库只更新 submodule 指针和必要的 `.pbt/.pbw` 引用，再刷新消费项目 baseline。

禁止在父项目本地同名 PBL 副本中长期保存共享库修复，也不要只提交父仓指针而遗漏 submodule 内的共享库提交。

FastReport 类案例：父项目可以发现 `Lib_FastReport.pbl:userobject:nvo_fastreport` 或 `str_fr` 与 `pb-libs` 不一致，但实际修复必须进入 `pb-libs` submodule，按新版 DLL/demo 更新 `pb-libs/src/lib_fastreport/...`，写回 `pb-libs/Lib_FastReport.pbl` 并提交后，父项目再更新 `pb-libs` 指针。

## 刷新 PbBridge 状态

更新共享库 submodule 指针后，在消费项目根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-readonly-sync.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-check-shared-library-writeback.ps1 -SharedLibraryPath .\pb-libs -AllowPointerUpdate
```

若项目需要排除已有自己源码事实源的共享库，沿用项目既有参数，例如：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-readonly-sync.ps1 -ScanScope all-targets -ExcludeLibrary 'pb-libs/*','pb-langchao/*'
```

如果项目维护了 `.pbbridge/shared-libraries.json`，共享库检查脚本可以不传 `-SharedLibraryPath`，直接读取配置并输出聚合 JSON。配置必须显式列出共享库路径，不能让脚本隐式扫描全部 submodule：

```json
{
  "schemaName": "pbbridge-shared-library-config",
  "sharedLibraries": [
    {
      "name": "pb-libs",
      "path": "pb-libs",
      "parentOutputPath": ".pbbridge/workspaces/default/artifacts/pbbridge",
      "sharedOutputPath": "pb-libs/.pbbridge/workspaces/default/artifacts/pbbridge",
      "resultJsonPath": ".pbbridge/shared-library-writeback-check.pb-libs.json"
    }
  ]
}
```

缺少共享库配置时，2.8.0 起先运行初始化草案：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-init-shared-libraries.ps1
```

草案会扫描 `.gitmodules`、共享库 `.pbw/.pbt` 和父项目 manifest：有独立 PBW/PBT 的共享库建议 `evidenceMode=self`，只有父项目 manifest 覆盖的共享库建议 `evidenceMode=consumer`。传 `-Apply` 写入 `.pbbridge/shared-libraries.json` 前必须人工复核；目标已存在时除非传 `-Force`，否则应保持失败。

检查脚本只生成证据，不提交、不推送、不更新 submodule 指针。配置在 `.pbbridge/shared-libraries.json` 中的共享库，专家链路 gate 通过后默认允许继续 Apply/WriteBack，不需要额外共享库写回授权；gate 失败、证据缺失或配置缺失仍必须阻断。`-AllowDirtySubmodule` 和 `-AllowPointerUpdate` 只把对应阻断降级为告警，仍保留 `submoduleCommit`、`parentRecordedCommit`、`issues[]` 和 `evidence[]`。

刷新后检查：

1. `.pbbridge/workspaces/default/artifacts/pbbridge/verify.json`
2. `.pbbridge/workspaces/default/artifacts/pbbridge/report.md`
3. `report` 的 Source Layout 与受管控 PBL 清单
4. 是否出现新的 `.sr*` 事实源变化或 baseline 变化
5. `.pbbridge/shared-library-writeback-check.json` 或每个共享库配置的 `resultJsonPath`
6. `.pbbridge/project-health.json`，缺失时建议运行 `scripts/pbbridge-project-health.ps1` 做更新后的统一总览

## 提交交接

1. 子模块内部如果产生了源码修改，使用 `pbbridge-git-publish` 在子模块内单独提交并推送。
2. 父仓库只提交 submodule 指针、必要的脚本或配置更新；不要提交 `.pbbridge/workspaces/`，也不要提交共享库本地同名 PBL 副本作为替代修复。
3. 若同步后 `.sr*` 有变化，先判断是共享库真实源码变化、消费项目导出布局变化，还是编译/导出噪声。
4. 回灌完成顺序必须是：子仓提交并推送 -> 父仓更新 submodule 指针 -> 父仓 readonly sync -> 父仓 verify/report。
5. 结束时说明：目标 submodule 的旧新 commit、父仓库指针是否变化、是否已运行 readonly sync、verify/report 是否通过、共享库 gate JSON 路径、仍需用户在 PowerBuilder IDE 中编译和运行验收。
6. 复杂任务按 `skills/_shared/handoff-template.md` 补齐 Git 状态和未完成风险。
7. 如果已运行 project-health，补充总体状态和仍需处理的 check issue code。

## 权威资料

- `CODEX-START.md`：启动、自检、submodule 与 baseline 规则。
- `skills/pbbridge-cli/SKILL.md`：export、verify、report、diff、import 的命令选择。
- `docs/getting-started/安装与升级说明.md`：toolkit 安装与升级说明。
