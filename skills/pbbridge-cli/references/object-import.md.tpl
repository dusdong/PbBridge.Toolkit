# V8 对象交付参考

日常对象写回只使用 V8 delivery，并显式解析 repo/workspace：

```powershell
pbbridge delivery close-loop --repo-root . --workspace canyin --object "app.pbl:window:w_example=src/app.pbl.src/w_example.srw" --result .pbbridge/workspaces/canyin/results/delivery-v8/preflight.json
pbbridge delivery continue --from .pbbridge/workspaces/canyin/results/delivery-v8/preflight.json --apply --result .pbbridge/workspaces/canyin/results/delivery-v8/apply.json
```

预检读取 workspace、三层 readiness、target snapshot、零冲突守卫、计划差异与 `nextAction`。Apply 后读取 canonical summary、`verificationCoverage`、对象级 residual/review、恢复状态与 session evidence。

旧 import/writeback 仅用于隔离专家排障，结果不能作为 V8 preflight 或 facts source。最终仍需 PowerBuilder IDE Regenerate、Full Build 与业务运行验收。
