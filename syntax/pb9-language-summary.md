# PB9 语言摘要

本文件面向 Codex / Copilot 提供 PowerBuilder 9 文本层协作的最小背景。

## 1. 基本事实

1. PowerBuilder 项目入口通常是 `.pbw`
2. 库资产通常位于 `.pbl`
3. AI 协作时不应直接把 `.pbl` 当成稳定源码输入
4. 推荐先导出为 `.sr*` 与 `manifest.json`

## 2. 协作输入面

优先使用：

1. `.sr*`
2. `manifest.json`
3. `verify` 结果
4. `report.md`
5. `diff` 结果

## 3. 边界

1. 文本层理解、整理、批量修改：适合 AI
2. `.pbl` 直接写回：必须受支持矩阵、准入和审查链路约束
3. PBSpyORCA candidate 当前不等同于正式 supported PBL 直写能力
