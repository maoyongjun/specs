# 任务清单：drh_history_pic union_id 备份 SQL

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：以文档审阅、SQL 静态复核、事务内复核和提交后只读查询为主。

## Phase 1：事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前任务是 `drh_history_pic.union_id` 备份 SQL。
- [x] T002 确认目标表为 `drh_history_pic`，目标字段为 `union_id`。
- [x] T003 确认目标值为 `{原 union_id}_bak`。
- [x] T004 确认筛选课程为 `drh_live.name = '胡琴说（上）'`。
- [x] T005 确认目标 `union_id` 一共 5 个，包含示例 1 个和补充 4 个。
- [x] T006 确认本次不涉及应用代码、不涉及接口、不涉及 MQ / Redis / 配置。

## Phase 2：风险门禁

- [x] T007 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或占位传参风险。
- [x] T008 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段的问题。
- [x] T009 检查每个下游读取字段是否都能在 SQL 中直接看到来源。
- [x] T010 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库结构或异步行为。
- [x] T011 记录需要用户确认的业务语义变化；当前仅等待审核后决定是否把 `ROLLBACK` 改为 `COMMIT`。
- [x] T012 为每个关键行为建立审阅映射：目标行临时表、更新前计数、更新后复核、默认回滚。

## Phase 3：脚本整理

- [x] T013 创建 Spec Kit 目录和文档。
- [x] T014 编写 `drh-history-pic-unionid-bak.sql`。
- [x] T015 确认 SQL 只修改 `drh_history_pic.union_id`，不触碰其他字段。
- [x] T016 确认 SQL 默认 `ROLLBACK`，不直接提交。
- [x] T017 通过 Linux 服务器只读查询 RDS，确认实际命中的运维 `class_id`。
- [x] T018 生成 `ops-interface-params.json`，供 SQL 更新后调用 `/works/songScore`。
- [x] T019 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 和 checklist。

## Phase 4：审阅与执行

- [x] T020 审核 SQL 的目标行查询、分组计数和更新条件。
- [x] T021 执行前保持事务内复核 `target_count`、`updated_count`、`not_updated_count` 和接口参数输出。
- [x] T022 用户确认后，执行时将事务末尾改为 `COMMIT` 正式提交。
- [x] T023 执行后补充执行记录，写明每个 `union_id` 的命中和更新数量。

## 执行记录

### D001 - 文档和 SQL 记录

- 执行内容：已创建 Spec Kit 文档，并已输出 `drh-history-pic-unionid-bak.sql`。
- 验证方式：人工复核目录结构、文档内容和 SQL 结构。
- 自检结论：满足“先审核、默认回滚、后确认提交”的要求；只做只读查询核验，未发生数据库变更。

### D002 - Linux 只读查询和运维参数记录

- 执行内容：通过 `182.92.157.63` 只读查询 RDS，核对 5 个 `union_id` 在 `胡琴说（上）` 下的历史点评和作业命中情况。
- 测试命令：远程执行 MySQL `SELECT`，未执行 `UPDATE`、`COMMIT` 或其他写操作。
- 测试结果：
  - 原始 `drh_history_pic` 命中 3 条，均为 `class_id=1124820`。
  - `oNGxt5zmBZ2howLnojgjhd3e9ntI` 当前已存在 `_bak` 历史点评记录 `id=3986709`，同属 `class_id=1124820`。
  - `oNGxt5_XcRNYDz971WrqFeJOCYyk` 在 `class_id=1124818` 有作品，但没有同 `union_id` 或 `_bak` 的历史点评记录，因此不属于本次 SQL 更新目标。
  - 运维接口参数已输出到 `ops-interface-params.json`：`class_id=1124820`、`max_score=83`、`min_score=77`、`song_name=胡琴说`。
- 自检结论：接口参数按实际 SQL 更新目标的 `live_id` 生成，D002 阶段未执行数据库更新。

### D003 - SQL 提交执行记录

- 执行内容：通过 `182.92.157.63` 远程连接 RDS，在事务内按 `drh-history-pic-unionid-bak.sql` 的筛选条件执行更新，并将末尾改为 `COMMIT` 提交。
- 测试命令：远程执行 MySQL 事务脚本；执行前输出目标行，执行后在事务内输出复核结果，提交后再用 `SELECT` 独立复核。
- 测试结果：
  - 执行前目标行 3 条：`3994156`、`3993249`、`3991837`。
  - `updated_rows=3`。
  - 事务内复核：3 条目标记录均 `updated_count=1`、`not_updated_count=0`。
  - 提交后复核：4 个有历史点评的目标用户原始历史点评记录均为 `0`，对应 `_bak` 记录均为 `1`；无历史点评的 `oNGxt5_XcRNYDz971WrqFeJOCYyk` 仍为 `0/0`。
  - 5 个目标 `union_id` 在 `drh_song_score` 的 `class_id=1124820` 下均为 `0` 条。
  - 运维接口参数仍为 `{"class_id":1124820,"max_score":83,"min_score":77,"song_name":"胡琴说"}`。
- 自检结论：本次只修改 `drh_history_pic.union_id`，已提交；未修改应用代码、作业表、课程表或评分表。

### D004 - 纠正记录模板

- 触发原因：用户确认 `1124818` 这组补偿没有执行，之前只补了 `{"class_id":1124820,"max_score":83,"min_score":77,"song_name":"胡琴说"}`。
- 修正内容：文档中明确漏项来源于补偿参数缺失，不是 SQL 目标筛选错误，也不是 `drh_history_pic` / `drh_song_score` 数据脏了；后续补偿需要按实际命中的 `class_id` 分组补齐。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 验证结果：只读查询确认 `oNGxt5_XcRNYDz971WrqFeJOCYyk` 在 `class_id=1124820` 下无 `drh_song_score`，而问题根因是 `1124818` 参数没进补偿。
