# 规格执行说明

本目录用于这次作业点评状态修复 SQL 的 Spec Kit 文档。当前需求只做文档和 SQL 脚本整理，不直接执行数据库更新，待你审核后再上服务器。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\030-drh-works-pic-status-reset-unreviewed`
- 目标项目：`C:\workspace\ju-chat`
- 相关模块：数据库运维 / `drh_works_pic` 作业状态修复

## 当前目标

- 归档原始查询 SQL 文档，保留审计依据。
- 将 4 段查询整理为可执行的更新脚本，把命中的作业状态改为未点评。
- 保持原有筛选条件不变，等待人工审核后再执行。

## 执行原则

- 先留档，再改写脚本，不直接在服务器上执行。
- 更新脚本必须沿用原始条件：班级、课程名、`union_id` 列表都不能变。
- 不允许使用占位 `IN (...)` 代替真实条件；脚本必须可审阅、可执行。
- 仅修改 `drh_works_pic.status`，不碰其他字段。
- 如果脚本写法可能触发 MySQL 同表子查询限制，优先使用等价的 `JOIN` 更新写法。

## 强制门禁

- 关键参数必须可追溯到原始 `作业点评数据SQL.txt`。
- 更新目标必须明确为 `drh_works_pic`，状态值必须明确为 `0`。
- 不允许出现未解释的空条件、空集合或临时占位对象。
- 任何会扩大影响范围的改动，都必须先停下来确认。

## 重点文件

- `作业点评数据SQL.txt`
- `update-drh-works-pic-status-unreviewed.sql`
- `spec.md`
- `tasks.md`
- `checklists\requirements.md`

## 文档维护

- `spec.md` 记录需求背景、边界、成功标准和假设。
- `tasks.md` 记录文档准备、脚本整理和后续执行状态。
- `checklists\requirements.md` 用于确认脚本是否满足审阅和执行前置条件。
- 如果你后续要求调整条件或范围，我会追加纠正记录并同步更新这几份文档。
