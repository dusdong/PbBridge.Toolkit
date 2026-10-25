# 共享库回灌任务卡

共享库对象的事实源在共享库 submodule，不在消费项目导出的集成快照。

## 固定顺序

1. 在父仓识别对象是否属于 `pb-libs`、`pb-langchao` 等 submodule。
2. 切到 submodule 工作区修改 `src/<normalized-pbl-name>/**/*.sr*`。
3. 在 submodule 内执行 verify、diff、对象级 DryRun、Apply、post-apply review。
4. 在 submodule 内提交并推送源码与 PBL 修复。
5. 回父仓更新 submodule 指针。
6. 父仓重新运行 readonly sync、verify、report。

## 禁止事项

1. 不把 `pb-libs/src` 复制到父项目 `src`。
2. 不把消费项目 `.pbbridge/workspaces/default` 当作共享库事实源。
3. 不长期保存父项目本地同名 PBL 修复。
4. 不只提交父仓指针而遗漏 submodule 内提交。
