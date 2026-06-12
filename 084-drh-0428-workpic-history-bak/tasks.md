# 任务清单：0428 营期作业状态回退与历史点评 union_id 备份

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：以 SQL 风险分析、只读预览、事务演练、正式提交和提交后只读复核为主。

## Phase 1：事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前任务是生产库运维 SQL。
- [x] T002 确认目标表为 `drh_works_pic` 和 `drh_history_pic`。
- [x] T003 确认目标营期为 4 个 0428 进阶班，课程名为 `胡琴说（下）`。
- [x] T004 确认正式库 profile 为 `prod-mysql`，环境为 `prod`，写入需要 `--allow-write --confirm`。
- [x] T005 确认本次不涉及应用代码、接口、MQ、Redis 或配置变更。

## Phase 2：风险门禁

- [x] T006 检查是否存在 DTO、空 JSON、空 Map 或占位传参风险；本次无应用对象传参。
- [x] T007 检查是否存在调用后赋值、异步后赋值或依赖后续流程补齐字段；本次无应用调用链。
- [x] T008 确认关键字段来源：营期名、课程名、workPicId、historyId、原始 status、原始 union_id。
- [x] T009 确认写入范围只来自临时表固化的 workPicId / historyId。
- [x] T010 确认写 SQL 默认 `ROLLBACK`，正式提交使用临时 `COMMIT` 副本。
- [x] T011 建立测试映射：预览 CSV、写 SQL analyze、ROLLBACK 演练、COMMIT 提交、提交后只读验证。

## Phase 3：脚本整理

- [x] T012 创建 `084-drh-0428-workpic-history-bak` 目录。
- [x] T013 编写 `preview-drh-0428-workpic-targets.sql`。
- [x] T014 编写 `preview-drh-0428-history-unionid-snapshot.sql`。
- [x] T015 编写 `execute-drh-0428-workpic-history-bak.sql`，仓库版本默认 `ROLLBACK`。
- [x] T016 编写 `verify-drh-0428-workpic-history-bak.sql`。
- [x] T017 编写 `rollback-drh-0428-workpic-history-bak.md`，说明基于 CSV 快照回滚。

## Phase 4：执行与验证

- [x] T018 分析两个预览 SQL，风险均为 `readonly`。
- [x] T019 执行预览 SQL 并导出 CSV：workPicId `1972` 行，历史快照 `855` 行。
- [x] T020 分析写 SQL，风险为 `ddl`，包含 `UPDATE drh_works_pic` 和 `UPDATE drh_history_pic`。
- [x] T021 首次演练发现临时表重复引用和 DDL 隐式提交风险，已修正脚本结构。
- [x] T022 修正后执行默认 `ROLLBACK` 演练，确认事务内 `history_updated_count=855` 且演练后未提交历史更新。
- [x] T023 生成临时 `COMMIT` 副本并执行正式提交。
- [x] T024 提交后用新连接只读复核最终状态。
- [x] T025 将执行结果同步到 `spec.md`、`tasks.md`、`AGENTS.md` 和 checklist。

## 执行记录

### D001 - 文档和 SQL 记录

- 执行内容：已创建 Spec Kit 目录，生成预览、执行、验证和回滚说明文件。
- 验证方式：`database-sql-skill analyze` 静态分析 SQL 风险。
- 自检结论：SQL 文件不包含数据库账号、密码或连接串；写 SQL 仓库版本默认 `ROLLBACK`。

### D002 - 只读预览记录

- 执行内容：通过 `prod-mysql` profile 执行只读预览 SQL。
- 测试结果：
  - `preview-drh-0428-workpic-targets.csv`：`1972` 行。
  - `preview-drh-0428-history-unionid-snapshot.csv`：`855` 行。
  - 目标 live_id：`1135090`、`1135089`、`1136563`、`1136562`。
- 自检结论：预览结果与计划一致，未发生数据库写入。

### D003 - 演练修正记录

- 执行内容：默认 `ROLLBACK` 演练写 SQL。
- 测试结果：
  - 首次演练报错 `Can't reopen table: 't'`，随后只读复核发现 `drh_works_pic.status` 已全部为 `0`。
  - 修正脚本后演练通过：`target_work_pic_count=1972`、`target_history_count=855`、`history_updated_count=855`、`history_not_updated_count=0`。
  - 演练后只读复核：`history_original_rows=855`、`history_bak_rows=0`，确认历史点评未被演练提交。
- 自检结论：脚本已重排为 DDL 在事务前、DML 在事务内，避免回滚语义被 DDL 影响。

### D004 - 正式提交记录

- 执行内容：生成临时 `COMMIT` 副本并通过 `database-sql-skill` 写入门禁执行正式提交。
- 测试结果：
  - `work_pic_status0_count=1972`、`work_pic_not_status0_count=0`。
  - `history_changed_rows=855`、`history_updated_count=855`、`history_not_updated_count=0`。
  - 提交后验证 CSV 已输出到 `verify-drh-0428-workpic-history-bak-after.csv`。
- 自检结论：最终生产数据满足验收标准；仓库内执行脚本仍默认 `ROLLBACK`。

### D005 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
