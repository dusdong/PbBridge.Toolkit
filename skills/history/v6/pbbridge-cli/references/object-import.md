# V6 对象交付参考

日常对象写回只使用 V6 delivery：

```powershell
pbbridge delivery close-loop --object "app.pbl:window:w_example=src/app.pbl.src/w_example.srw" --result .pbbridge/local/results/delivery-v6/dryrun.json
pbbridge delivery close-loop --object "app.pbl:window:w_example=src/app.pbl.src/w_example.srw" --apply --preflight-result .pbbridge/local/results/delivery-v6/dryrun.json --result .pbbridge/local/results/delivery-v6/apply.json
```

DryRun 读取 `apply.readiness`、`diff.planned`、对象级 preflight/checks 与 `nextCommand`。Apply 后读取 canonical `summary`、`writeback`、`review`、`diff.residual`、`conflicts`、`recovery` 与 evidence。

V4 import/writeback 仅用于隔离专家排障，其结果不能作为 V6 preflight 或事实源。最终仍需 PowerBuilder IDE Regenerate、Full Build 与业务运行验收。
