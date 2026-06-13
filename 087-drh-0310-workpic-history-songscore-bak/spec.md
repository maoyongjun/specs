# 功能规格：0310 营期作业状态回退、历史点评与五维分数 union_id 备份

**功能目录**：`087-drh-0310-workpic-history-songscore-bak`  
**创建日期**：`2026-06-13`  
**状态**：Done  
**输入**：用户要求按照 `084` 的方式，处理 `进阶班0310期-小靳老师班`、`进阶班0310期-董董老师班`、`进阶班0310期-玉米老师` 这三个营期的点评作业；另外需要通过作业点评 `pic_id` 匹配 `drh_song_score`，将匹配到的五维作业点评分数记录 `union_id` 更新为 `{union_id}_bak`。

## 背景

- 当前问题：3 个 0310 营期的 `胡琴说（下）` 作业需要重新进入未点评状态，同时历史人工点评和五维分数记录需要从原 `union_id` 下移开，避免后续业务继续按原 `union_id` 命中。
- 当前行为：正式库中目标作业分布在 3 个 `live_id` 下，存在 1130 条非 `status=0` 作业、114 条原始历史点评记录、579 条原始五维分数记录。
- 目标行为：将目标 `drh_works_pic.status` 全部置为 `0`，将目标 `drh_history_pic.union_id` 和 `drh_song_score.union_id` 改为 `_bak`，并保留执行前 CSV 快照用于回滚。
- 非目标：不修改应用代码，不新增表结构，不修改 `drh_live`、`drh_live_camp` 或其他业务字段，不处理 `胡琴说（下）` 以外课程。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 查询并归档目标记录（优先级：P1）

运维执行前需要拿到 3 个营期在 `胡琴说（下）` 下的完整作业清单、历史点评清单和五维分数清单。

**独立测试**：执行三份 preview SQL，确认导出 `1623`、`114`、`579` 行快照。

**验收场景**：

1. **Given** 正式库中存在 3 个目标营期，**When** 执行 workPicId 预览 SQL，**Then** 输出 3 个 `live_id` 和 `1623` 条 `work_pic_id`。
2. **Given** 预览 CSV 已生成，**When** 审阅历史点评和五维分数快照，**Then** 每行都包含主键、原始 `union_id` 和目标 `_bak` 值。

### 用户故事 2 - 回退作业状态（优先级：P1）

目标作业需要统一变为未点评状态。

**独立测试**：提交后执行 `verify-drh-0310-workpic-history-songscore-bak.sql`，确认 `not_status0_count=0`。

**验收场景**：

1. **Given** 目标 workPicId 已固化到临时表，**When** 执行状态更新，**Then** 仅这些 `drh_works_pic.id` 的 `status` 被设置为 `0`。
2. **Given** 某些目标记录已经是 `status=0`，**When** 重复执行同一更新，**Then** 状态保持为 `0`，不会修改其他字段。

### 用户故事 3 - 备份历史点评和五维分数 union_id（优先级：P1）

目标作业对应的原始历史点评和五维分数记录需要保留记录内容，但不再以原 `union_id` 被命中。

**独立测试**：提交后执行验证 SQL，确认历史点评和五维分数的原始 `union_id` 命中均为 `0`，`_bak` 命中分别为 `114` 和 `579`。

**验收场景**：

1. **Given** `wp.status=0` 且 `wp.is_del=0`，**When** 历史点评记录满足 `hp.pic_id=wp.id` 和 `hp.union_id=wp.union_id`，**Then** `hp.union_id` 被改为 `{union_id}_bak`。
2. **Given** 五维分数记录满足 `ss.pic_id=wp.id`、`ss.union_id=wp.union_id`、`ss.class_id=wp.live_id`，**When** 执行更新，**Then** `ss.union_id` 被改为 `{union_id}_bak`。
3. **Given** 记录已经是 `_bak`，**When** 更新 SQL 再次执行，**Then** 因 `union_id NOT LIKE '%\_bak'` 不会重复追加。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `camp name`：来源于用户输入，固定为 `进阶班0310期-小靳老师班`、`进阶班0310期-董董老师班`、`进阶班0310期-玉米老师`。
  - `live_name`：来源于“按照之前方式”，固定为 `胡琴说（下）`。
  - `work_pic_id`：来源于正式库只读查询结果，执行脚本中通过临时表固化。
  - `history_id`：来源于 `drh_history_pic` 预览快照，执行脚本中通过临时表固化。
  - `song_score_id`：来源于 `drh_song_score` 预览快照，执行脚本中通过临时表固化。
  - `target_union_id`：脚本内通过 `CONCAT(union_id, '_bak')` 现算现用。
- 下游读取字段清单：
  - 无应用代码下游调用变更；业务侧后续仍按原 `pic_id + union_id` 查询历史点评或五维分数。
  - 本次将目标记录 `union_id` 改为 `_bak` 后，原 `union_id` 查询不再命中这些记录。
- 空对象 / 占位对象风险：
  - 不涉及 DTO、JSON、Map；SQL 不允许空集合或占位条件。
- 调用顺序风险：
  - 遵循 `084` 修正后的安全顺序：所有临时表 DDL 在 `START TRANSACTION` 前完成，事务内只保留 DML 和复核，避免 MySQL DDL 隐式提交影响回滚语义。
- 旧逻辑保持：
  - 仅修改 `drh_works_pic.status`、`drh_history_pic.union_id`、`drh_song_score.union_id`。
  - `drh_song_score` 更新以 `pic_id` 命中为核心，并同时校验 `union_id` 与 `class_id`；只读结果显示该校验不会减少目标范围。
- 需要用户确认的设计选择：
  - 用户已在 2026-06-13 明确要求 `PLEASE IMPLEMENT THIS PLAN`，本次据此执行正式库写入。

## 边界情况

- 某个营期命中 0 行或目标数不等于预期时，预期数量保护会阻止 DML 生效。
- 已经是 `status=0` 的作业不会产生 changed rows，但提交后必须满足所有目标作业 `status=0`。
- 已经是 `_bak` 的历史点评或五维分数记录不会被重复更新。
- 小靳班存在 1 个 `pic_id` 对应 2 条 `drh_song_score` 记录，本次按 `song_score_id` 逐行更新。
- 回滚依赖三份执行前 CSV 快照。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 创建本次 Spec Kit 文档、预览 SQL、执行 SQL、验证 SQL 和回滚说明。
- **FR-002**：系统 MUST 用只读 SQL 查询并归档 3 个营期在 `胡琴说（下）` 下的目标记录。
- **FR-003**：系统 MUST 只按固化的 `work_pic_id` 将 `drh_works_pic.status` 设置为 `0`。
- **FR-004**：系统 MUST 只按固化的 `history_id` 将 `drh_history_pic.union_id` 设置为 `{union_id}_bak`。
- **FR-005**：系统 MUST 只按固化的 `song_score_id` 将 `drh_song_score.union_id` 设置为 `{union_id}_bak`。
- **FR-006**：系统 MUST 使用 `database-sql-skill analyze` 分析 SQL，并使用 `prod-mysql` profile 的写入门禁执行。
- **FR-007**：系统 MUST 在提交后用新连接只读复核最终状态。

## 成功标准 *(必填)*

- **SC-001**：预览 CSV 存在，数据行数分别为 `1623`、`114`、`579`。
- **SC-002**：提交后 3 个营期目标作业 `status0_count=work_pic_count`，`not_status0_count=0`。
- **SC-003**：提交后目标历史点评 `history_original_rows=0`，`history_bak_rows=114`。
- **SC-004**：提交后目标五维分数 `song_score_original_rows=0`，`song_score_bak_rows=579`。
- **SC-005**：仓库内执行 SQL 默认保留 `ROLLBACK`，正式提交使用临时 `COMMIT` 副本，不保存数据库密钥。

## 假设

- `status=0` 表示作业未点评。
- “按照之前方式”表示只处理 `胡琴说（下）`，不处理复训课或其他课程。
- 3 个营期名称和课程名需要精确匹配，不做模糊匹配。
- 提交后如需回滚，由人工基于 CSV 快照构造临时表并执行回滚 SQL。

## 执行记录

### D001 - 文档和只读预览

- 已创建本 Spec Kit 目录和 SQL 文件。
- 已执行三份 preview SQL：
  - `preview-drh-0310-workpic-targets.csv`：`1623` 行。
  - `preview-drh-0310-history-unionid-snapshot.csv`：`114` 行。
  - `preview-drh-0310-song-score-unionid-snapshot.csv`：`579` 行。
- 只读阶段未执行数据库写入。

### D002 - 默认 ROLLBACK 演练

- 写 SQL 分析结果：`Risk: ddl`，包含 3 段 DML。
- 默认 `ROLLBACK` 演练结果：
  - `target_work_pic_count=1623`、`work_pic_changed_rows=1130`、`work_pic_status0_count=1623`、`work_pic_not_status0_count=0`。
  - `target_history_count=114`、`history_changed_rows=114`、`history_updated_count=114`、`history_not_updated_count=0`。
  - `target_song_score_count=579`、`song_score_changed_rows=579`、`song_score_updated_count=579`、`song_score_not_updated_count=0`。
- 演练后只读复核确认未提交：历史点评和五维分数 `_bak` 均仍为 `0`。

### D003 - 正式提交和提交后复核

- 正式执行方式：从仓库内默认 `ROLLBACK` 脚本生成临时 `COMMIT` 副本，使用 `database-sql-skill` 的 `prod-mysql` profile 执行，并带 `--allow-write --confirm`。
- 提交结果与演练一致：
  - 作业状态 changed `1130` 条，最终 `1623` 条全部 `status=0`。
  - 历史点评 changed `114` 条。
  - 五维分数 changed `579` 条。
- 提交后只读复核：
  - 小靳 `1107245`：`519/519` 作业为 `status=0`，历史 `_bak=30`，五维分数 `_bak=200`。
  - 董董 `1107244`：`615/615` 作业为 `status=0`，历史 `_bak=33`，五维分数 `_bak=217`。
  - 玉米 `1107705`：`489/489` 作业为 `status=0`，历史 `_bak=51`，五维分数 `_bak=162`。
  - 3 个营期的 `history_original_rows` 和 `song_score_original_rows` 均为 `0`。

### D004 - 后续纠正记录

- 当前暂无纠正事项。
- 如后续需要回滚或补充处理范围，必须追加新的 Dxxx 记录，并同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 和 checklist。
