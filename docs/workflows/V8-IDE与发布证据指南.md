# V8 IDE 与发布证据指南

```powershell
pbbridge delivery ingest-ide-log --session <id> --log build.log
pbbridge target packaging inspect --target cy.pbt --artifact-root bin --session <id> --result packaging.json
pbbridge target deployment verify --packaging-result packaging.json --dependency-manifest .pbbridge/runtime-dependencies.json --artifact-root bin --session <id> --result deployment.json
pbbridge delivery attest --session <id> --stage runtime --status passed --actor <id> --note "运行场景通过"
pbbridge delivery attest --session <id> --stage business --status passed --actor <id> --note "业务验收通过"
pbbridge delivery handoff-summary --session <id> --format markdown
```

PB9 R0006 等运行错误会尽量映射到对象、成员、本地行号和 `.sr*` 一基行号；无法映射的原文保留为 `unmapped`。

人工声明只产生 `attested`。只有工具证据全为 `verified` 或 `not-applicable` 时，release readiness 才能为 `ready`。
