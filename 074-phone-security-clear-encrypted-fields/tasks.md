# 任务清单：生产手机号安全字段清空

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充静态验证、SQL 风险分析、dry-run 和 verify 记录。

## Phase 1：事实确认

- [x] T001 确认目标清单来源为 `069-phone-security-backfill-governance/sql/final-phone-security-ddl-and-indexes.sql`。
- [x] T002 确认清空范围包含标准 `phone_*`、`app_phone_*`、`receiver_phone_*`、`reciver_phone_*`，但候选判断只按同组 `*_md5` 非空。
- [x] T003 确认生产 profile 为 `prod-mysql`，本地策略 `allow_write=true`。
- [x] T004 生产只读元数据确认 44 张目标表均存在目标列，且主键均为 `id`。
- [x] T005 生产只读元数据确认目标 `*_md5` 和 `*_aes` 字段均已有索引。

**检查点**：不得在未完成 T001-T005 前执行生产写入。

## Phase 2：执行器与门禁

- [x] T006 新增 074 Spec Kit 目录结构。
- [x] T007 新增目标 manifest 生成与校验能力。
- [x] T008 新增 DML 分析模板生成能力。
- [x] T009 新增 dry-run、verify、execute 执行器。
- [x] T010 execute 默认拒绝执行，必须提供包含日期、profile、备份确认、写入暂停和批大小的 `--confirm`。
- [x] T011 execute 使用 `id` 主键小批量更新，每批最多 500 行并立即提交。
- [x] T012 execute 设置 `innodb_lock_wait_timeout=5`，锁等待/死锁最多重试 3 次。
- [x] T012a 候选条件改为 `*_md5 IS NOT NULL AND *_md5 <> ''`，不再按 `mask/aes` 任意非空核对。

## Phase 3：验证

- [x] T013 运行 `--write-artifacts` 生成并校验 manifest 与 DML 模板。
- [x] T014 运行 manifest 静态校验，确认 44/45/135 数量。
- [x] T015 运行 `database-sql-skill analyze`，确认 DML 模板风险为 `dml`。
- [x] T016 运行 execute 无确认文本的安全检查，确认脚本拒绝写入。
- [x] T017 运行生产 dry-run，记录候选量和报告路径。
- [x] T018 执行生产写入前，人工确认 RDS 备份/PITR 与写入任务暂停。
- [x] T019 执行生产清空并记录报告路径、更新量和失败情况。
- [x] T020 执行生产 verify，确认全部目标字段组候选量为 0。

## 执行记录

### D001 - 文档与执行器创建

- 执行内容：新增 074 规格目录、文档、执行器、目标 manifest 和 DML 模板生成机制。
- 验证方式：待执行 T013-T017。
- 自检结论：生产写入仍受 `--execute` 与 `--confirm` 门禁约束。

### D002 - 静态验证与生产 dry-run

- 执行内容：生成 `sql/phone-security-clear-targets.json` 和 `sql/phone-security-clear-dml-template.sql`；校验 manifest 与 069 DDL 一致；执行 DML 模板风险分析；验证无确认文本时 execute 被拒绝；执行生产 dry-run。
- 验证命令：
  - `python specs/074-phone-security-clear-encrypted-fields/scripts/phone_security_clear_runner.py --write-artifacts`
  - `python specs/074-phone-security-clear-encrypted-fields/scripts/phone_security_clear_runner.py --validate-artifacts`
  - `python database-sql-skill/scripts/db_skill.py analyze --file specs/074-phone-security-clear-encrypted-fields/sql/phone-security-clear-dml-template.sql`
  - `python specs/074-phone-security-clear-encrypted-fields/scripts/phone_security_clear_runner.py --execute`
  - `python specs/074-phone-security-clear-encrypted-fields/scripts/phone_security_clear_runner.py --dry-run --batch-size 500 --sleep-ms 200`
- 验证结果：
  - manifest 校验通过：44 张表、45 组字段、135 个目标列。
  - DML 模板分析结果：45 条语句，风险级别 `dml`。
  - 无 `--confirm` 的 execute 被拒绝，失败报告：`out/phone-security-clear-execute-20260611-105851.json`。
  - 生产 dry-run 报告：`out/phone-security-clear-dry-run-20260611-105937.json`，字段组候选量合计 `133500`。
  - 非零候选字段组：`drh_applet_user.phone=64800`、`drh_live_user.app_phone=35100`、`drh_real_address_record.phone=13500`、`drh_h5_order.phone=8400`、`drh_live_user.phone=8100`、`drh_external_book_question_record.phone=2100`、`drh_book_edit_address_compensation.phone=1200`、`drh_book_question_record.phone=300`。
- 自检结论：dry-run 候选量高于“约 1 万条”的预期，未执行生产写入；需先确认清空范围或线上数据预期，再进入 T018-T020。

### D003 - 候选核对口径调整

- 触发原因：用户确认“更新的是 `phone_md5/phone_aes/phone_mask` 这些字段，不要动 Phone 字段；按照 `phone_md5` 不为空来核对”。
- 修正内容：执行器候选条件从 `mask/md5/aes` 任意非空调整为同一字段组的 `*_md5 IS NOT NULL AND *_md5 <> ''`；更新动作仍仅将同一字段组的 `*_mask/*_md5/*_aes` 置空，不修改源手机号列。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md` 和 checklist。
- 验证结果：已重新生成 DML 模板并通过 manifest 校验、DML 风险分析和生产 dry-run。

### D004 - 按 `*_md5` 非空口径重新 dry-run

- 执行内容：按 `*_md5 IS NOT NULL AND *_md5 <> ''` 重新生成 DML 模板并执行生产 dry-run。
- 验证命令：
  - `python specs/074-phone-security-clear-encrypted-fields/scripts/phone_security_clear_runner.py --write-artifacts`
  - `python specs/074-phone-security-clear-encrypted-fields/scripts/phone_security_clear_runner.py --validate-artifacts`
  - `python database-sql-skill/scripts/db_skill.py analyze --file specs/074-phone-security-clear-encrypted-fields/sql/phone-security-clear-dml-template.sql`
  - `python specs/074-phone-security-clear-encrypted-fields/scripts/phone_security_clear_runner.py --dry-run --batch-size 500 --sleep-ms 200`
- 验证结果：
  - manifest 校验通过：44 张表、45 组字段、135 个目标列。
  - DML 模板分析结果：45 条语句，风险级别 `dml`。
  - 生产 dry-run 报告：`out/phone-security-clear-dry-run-20260611-110856.json`，按 `*_md5` 非空统计候选量合计 `133500`。
  - 非零候选字段组：`drh_applet_user.phone=64800`、`drh_live_user.app_phone=35100`、`drh_real_address_record.phone=13500`、`drh_h5_order.phone=8400`、`drh_live_user.phone=8100`、`drh_external_book_question_record.phone=2100`、`drh_book_edit_address_compensation.phone=1200`、`drh_book_question_record.phone=300`。
- 自检结论：候选量仍为 `133500`，说明高候选量来自 `*_md5` 本身非空；未执行生产写入。

### D005 - 生产清空执行与 verify

- 执行前确认：用户确认 `2026-06-11 prod-mysql` 备份/PITR 可用，相关写入任务已暂停，按 `batch_size=500` 执行清空。
- 执行命令：
  - `python specs/074-phone-security-clear-encrypted-fields/scripts/phone_security_clear_runner.py --execute --batch-size 500 --sleep-ms 200 --confirm "已确认 2026-06-11 prod-mysql 备份/PITR 可用，相关写入任务已暂停，按 batch_size=500 执行清空。"`
  - `python specs/074-phone-security-clear-encrypted-fields/scripts/phone_security_clear_runner.py --verify --batch-size 500 --sleep-ms 200`
- 执行报告：`out/phone-security-clear-execute-20260611-111625.json`。
- Verify 报告：`out/phone-security-clear-verify-20260611-112059.json`。
- 执行结果：清空前候选量 `133500`，实际更新 `133500`，清空后候选量 `0`。
- 非零更新字段组：`drh_applet_user.phone=64800`、`drh_live_user.app_phone=35100`、`drh_real_address_record.phone=13500`、`drh_h5_order.phone=8400`、`drh_live_user.phone=8100`、`drh_external_book_question_record.phone=2100`、`drh_book_edit_address_compensation.phone=1200`、`drh_book_question_record.phone=300`。
- 自检结论：按 `*_md5` 非空口径验证，45 组目标字段候选量已归零；执行过程只置空同组 `*_mask/*_md5/*_aes`，未修改源手机号字段。
