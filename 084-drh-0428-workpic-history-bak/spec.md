# 功能规格：0428 营期作业状态回退与历史点评 union_id 备份

**功能目录**：`084-drh-0428-workpic-history-bak`  
**创建日期**：`2026-06-12`  
**状态**：Done  
**输入**：用户要求使用 `C:\workspace\ju-chat\database-sql-skill` 查询正式库，找出 4 个 0428 进阶班营期在课程 `胡琴说（下）` 下对应作业的 `drh_works_pic.id`，将这些作业的 `status` 更新为 `0`；随后按示例 SQL 将对应 `drh_history_pic.union_id` 更新为 `{union_id}_bak`，并限制 `wp.status=0`、`wp.is_del=0`、`hp.union_id NOT LIKE '%\_bak'`。

## 背景

- 当前问题：4 个 0428 营期的 `胡琴说（下）` 作业需要重新进入未点评状态，同时历史人工点评记录需要从原 `union_id` 下移开，避免后续业务继续按原 `union_id` 命中。
- 当前行为：正式库中目标作业分布在 4 个 `live_id` 下，部分 `drh_works_pic.status` 不是 `0`，并存在 855 条可备份的原始 `drh_history_pic.union_id`。
- 目标行为：将目标 `drh_works_pic.status` 全部置为 `0`，将 855 条 `drh_history_pic.union_id` 改为 `_bak`，并保留执行前 CSV 快照用于回滚。
- 非目标：不修改应用代码，不新增表结构，不修改 `drh_live`、`drh_live_camp` 或其他业务字段，不使用仅 `live_id IN (...)` 的宽泛写入条件。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 查询并归档 workPicId（优先级：P1）

运维执行前需要拿到 4 个营期在 `胡琴说（下）` 下的完整作业清单。

**独立测试**：执行 `preview-drh-0428-workpic-targets.sql`，确认导出 `1972` 条 workPicId。

**验收场景**：

1. **Given** 正式库中存在 4 个目标营期，**When** 执行只读预览 SQL，**Then** 输出 4 个 `live_id` 和 `1972` 条 `work_pic_id`。
2. **Given** 预览 CSV 已生成，**When** 审阅 CSV，**Then** 每行包含 `camp_id`、`camp_name`、`live_id`、`work_pic_id`、`current_status`、`is_del`、`union_id`。

### 用户故事 2 - 回退作业状态（优先级：P1）

目标作业需要统一变为未点评状态。

**独立测试**：提交后执行 `verify-drh-0428-workpic-history-bak.sql`，确认 `not_status0_count=0`。

**验收场景**：

1. **Given** 目标 workPicId 已固化到临时表，**When** 执行状态更新，**Then** 仅这些 `drh_works_pic.id` 的 `status` 被设置为 `0`。
2. **Given** 某些目标记录已经是 `status=0`，**When** 重复执行同一更新，**Then** 状态保持为 `0`，不会修改其他字段。

### 用户故事 3 - 备份历史点评 union_id（优先级：P1）

目标作业对应的原始历史点评记录需要保留记录内容，但不再以原 `union_id` 被命中。

**独立测试**：提交后执行验证 SQL，确认 `history_original_rows=0` 且 `history_bak_rows=855`。

**验收场景**：

1. **Given** `wp.status=0` 且 `wp.is_del=0`，**When** 历史点评记录满足 `hp.pic_id=wp.id` 和 `hp.union_id=wp.union_id`，**Then** `hp.union_id` 被改为 `{union_id}_bak`。
2. **Given** 记录已经是 `_bak`，**When** 更新 SQL 再次执行，**Then** 因 `hp.union_id NOT LIKE '%\_bak'` 不会重复追加。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `camp name`：来源于用户输入，固定为 `进阶班0428期-晨宇老师`、`进阶班0428期-彦铭老师班`、`进阶班0428期-康康老师班`、`进阶班0428期-小向老师班`。
  - `live_name`：来源于用户 SQL 示例，固定为 `胡琴说（下）`。
  - `work_pic_id`：来源于正式库只读查询结果，执行脚本中通过临时表固化。
  - `status`：来源于用户需求，目标值固定为 `0`。
  - `target_union_id`：脚本内通过 `CONCAT(hp.union_id, '_bak')` 现算现用。
- 下游读取字段清单：
  - 无应用代码下游调用变更；业务侧后续仍按原 `pic_id + union_id` 查询历史点评。
  - 本次将目标历史点评 `union_id` 改为 `_bak` 后，原 `union_id` 查询不再命中这些记录。
- 空对象 / 占位对象风险：
  - 不涉及 DTO、JSON、Map；SQL 不允许空集合或占位条件。
- 调用顺序风险：
  - 初版演练脚本在事务中包含临时表 DDL，触发 MySQL DDL 隐式提交风险；已修正为所有临时表 DDL 在 `START TRANSACTION` 前完成，事务内只保留 DML 和复核。
- 旧逻辑保持：
  - 仅修改 `drh_works_pic.status` 与 `drh_history_pic.union_id`。
  - 历史点评更新必须限制在已固化 workPicId 范围内，并保留 `wp.status=0`、`wp.is_del=0`、未 `_bak` 条件。
- 需要用户确认的设计选择：
  - 用户已在 2026-06-12 明确要求 `PLEASE IMPLEMENT THIS PLAN`，本次据此执行正式库写入。

## 边界情况

- 某个营期命中 0 行时，`@expected_work_pic_count=1972` 保护会阻止 DML 生效。
- 历史点评目标不是 855 条时，`@expected_history_count=855` 保护会阻止 `drh_history_pic` 更新。
- 已经是 `status=0` 的作业不会产生 changed rows，但提交后必须满足所有目标作业 `status=0`。
- 已经是 `_bak` 的历史点评记录不会被重复更新。
- 回滚依赖执行前 CSV 快照：`preview-drh-0428-workpic-targets.csv` 和 `preview-drh-0428-history-unionid-snapshot.csv`。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 创建本次 Spec Kit 文档、预览 SQL、执行 SQL、验证 SQL 和回滚说明。
- **FR-002**：系统 MUST 用只读 SQL 查询并归档 4 个营期在 `胡琴说（下）` 下的 `work_pic_id`。
- **FR-003**：系统 MUST 只按固化的 `work_pic_id` 将 `drh_works_pic.status` 设置为 `0`。
- **FR-004**：系统 MUST 只按固化的目标历史点评 `history_id` 将 `drh_history_pic.union_id` 设置为 `{union_id}_bak`。
- **FR-005**：系统 MUST 使用 `database-sql-skill analyze` 分析 SQL，并使用 `prod-mysql` profile 的写入门禁执行。
- **FR-006**：系统 MUST 在提交后用新连接只读复核最终状态。

## 成功标准 *(必填)*

- **SC-001**：预览 CSV 存在，`work_pic_id` 数据行数为 `1972`，历史点评回滚快照数据行数为 `855`。
- **SC-002**：提交后 4 个营期目标作业 `status0_count=work_pic_count`，`not_status0_count=0`。
- **SC-003**：提交后目标历史点评 `history_original_rows=0`，`history_bak_rows=855`。
- **SC-004**：仓库内执行 SQL 默认保留 `ROLLBACK`，正式提交使用临时 `COMMIT` 副本，不保存数据库密钥。

## 假设

- `status=0` 表示作业未点评。
- 4 个营期名称和课程名需要精确匹配，不做模糊匹配。
- `drh_history_pic` 更新范围遵循用户示例，额外保留 `wp.is_del=0` 和未 `_bak` 条件。
- 提交后如需回滚，由人工基于 CSV 快照构造临时表并执行回滚 SQL。

## 执行记录

### D001 - 文档和只读预览

- 已创建本 Spec Kit 文档和 SQL 文件。
- 已执行 `preview-drh-0428-workpic-targets.sql`，导出 `1972` 条 workPicId。
- 已执行 `preview-drh-0428-history-unionid-snapshot.sql`，导出 `855` 条历史点评回滚快照。
- 只读阶段未执行数据库写入。

### D002 - 写 SQL 演练修正

- 首次默认 `ROLLBACK` 演练在最终复核查询处触发 `Can't reopen table: 't'`，原因是 MySQL 临时表在同一 SELECT 内被重复引用。
- 异常后只读复核发现 `drh_works_pic.status` 已全部为 `0`，说明初版脚本中事务内 DDL 存在隐式提交风险，第一段状态更新已生效。
- 已修正执行 SQL：所有临时表 DDL 移到 `START TRANSACTION` 之前，事务内只保留两段 DML 和复核。
- 修正后默认 `ROLLBACK` 演练通过：`target_work_pic_count=1972`、`work_pic_status0_count=1972`、`target_history_count=855`、`history_updated_count=855`、`history_not_updated_count=0`。
- 演练后只读复核确认历史点评未提交：`history_original_rows=855`、`history_bak_rows=0`。

### D003 - 正式提交和提交后复核

- 正式执行方式：从仓库内默认 `ROLLBACK` 脚本生成临时 `COMMIT` 副本，使用 `database-sql-skill` 的 `prod-mysql` profile 执行，并带 `--allow-write --confirm`。
- 提交结果：
  - `target_work_pic_count=1972`。
  - `work_pic_changed_rows=0`，因为目标作业状态已在 D002 后全部为 `0`。
  - `work_pic_status0_count=1972`、`work_pic_not_status0_count=0`。
  - `target_history_count=855`、`history_changed_rows=855`。
  - `history_updated_count=855`、`history_not_updated_count=0`。
- 提交后只读复核：
  - 晨宇 `1135090`：`543/543` 作业为 `status=0`，历史 `_bak=161`。
  - 彦铭 `1135089`：`428/428` 作业为 `status=0`，历史 `_bak=228`。
  - 康康 `1136563`：`470/470` 作业为 `status=0`，历史 `_bak=242`。
  - 小向 `1136562`：`531/531` 作业为 `status=0`，历史 `_bak=224`。
  - 4 个营期 `history_original_rows` 均为 `0`。

### D004 - 纠正记录模板

- 触发原因：`<用户补充 / 审核意见 / 执行反馈>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态验证结果>`。
