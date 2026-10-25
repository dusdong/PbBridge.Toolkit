## PbBridge V6 delivery

- 唯一当前 full schema：`pbbridge-v6-delivery` / 6。
- 唯一当前 compact schema：`pbbridge-v6-compact-summary` / 6。
- 日常流程：DryRun → Apply/ApplyIfEligible → post-apply review → IDE checklist/handoff → PowerBuilder Full Build。
- 旧 delivery JSON 必须重新运行 V6 DryRun，不做兼容读取或字段映射。
