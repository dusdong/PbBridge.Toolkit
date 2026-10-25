# PbBridge 交接模板

结束 PbBridge 任务时，按实际执行情况填写这些字段；没有执行的项要写明原因。

1. 修改范围：对象主键、`.sr*` 文件、脚本、配置或 submodule 指针。
2. 已运行命令：列出关键命令和通过/失败结果。
3. verify：新增、已知、waived、expired waiver、blocking 结论。
4. diff/report：本轮语义差异和 Source Layout 结论。
5. DryRun/Apply：计划文件、DryRun 结果、Apply 写回数、失败数、post-apply review。
6. diagnostics bundle：路径和关键风险。
7. IDE 待验收：Regenerate、Full Build、运行验收和用户确认状态。
8. Git 状态：仓库边界、submodule 指针、暂存/未提交/已推送状态。
9. 未完成风险：阻断项、下一条建议命令和需要人工决策的事项。
