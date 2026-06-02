# 功能规格：drh_history_pic union_id 备份 SQL

**功能目录**：`044-drh-history-pic-unionid-bak`  
**创建日期**：`2026-06-01`  
**状态**：Done  
**输入**：用户要求在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档，并先编写 SQL。示例为按 `union_id='oNGxt5zmBZ2howLnojgjhd3e9ntI'` 和课程 `胡琴说（上）` 查询 `drh_history_pic`，再将命中记录的 `union_id` 改为 `oNGxt5zmBZ2howLnojgjhd3e9ntI_bak`。补充需要同样处理 `oNGxt54fYKaIKHAGsqEFhYLtXXbY`、`oNGxt5y-muyKxySOWAw4u-gmzvNo`、`oNGxt5z_XoNyC5kG_Q7f-WJRNlmA`、`oNGxt5_XcRNYDz971WrqFeJOCYyk`。后续补充要求：SQL 更新后需要给出 `/works/songScore` 运维接口参数，示例为 `{"class_id":1124820,"max_score":83,"min_score":77,"song_name":"胡琴说"}`，其中 `class_id` 即 `live_id`；只读查询需通过 Linux 服务器访问 RDS。2026-06-02 追加第二批 92 个 `union_id`，用户明确之前批次已处理，本次只处理新增批次。

## 背景

- 当前问题：指定用户在 `胡琴说（上）` 课程下存在 `drh_history_pic` 人工点评记录，业务查询按原 `union_id` 命中后会继续识别为人工点评。
- 当前行为：`drh_history_pic` 中 `pic_id` 与 `drh_works_pic.id` 对应，且同一 `union_id` 的历史点评记录会被应用侧按 `pic_id + union_id` 读取。
- 目标行为：先生成可审核 SQL，把指定批次 `union_id` 的目标历史点评记录改为 `{union_id}_bak`，使其不再以原 `union_id` 命中；更新后输出可用于运维调用 `/works/songScore` 的接口参数。
- 非目标：不修改应用代码，不删除历史点评记录，不修改 `drh_works_pic`、`drh_live`、`drh_song_score` 或 `drh_history_pic` 其他字段。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 生成可审核 SQL（优先级：P1）

运维同学需要先看到完整 SQL，确认命中范围和更新策略后再决定是否提交。

**独立测试**：打开 `drh-history-pic-unionid-bak.sql`，确认包含临时表圈定、目标行审阅、分组计数、更新、更新后复核和默认 `ROLLBACK`。

**验收场景**：

1. **Given** 用户提供了 5 个 `union_id` 和课程名，**When** 查看 SQL，**Then** 5 个 `union_id` 均在 `IN` 条件中。
2. **Given** 审核者担心误更新，**When** 查看 SQL，**Then** 更新只通过临时表中的 `drh_history_pic.id` 执行。

### 用户故事 2 - 备份人工点评记录 union_id（优先级：P1）

命中的人工点评记录需要保留原记录内容，但不再以原 `union_id` 参与后续业务匹配。

**独立测试**：静态检查 `UPDATE` 语句只修改 `drh_history_pic.union_id`，且目标值为 `CONCAT(source_union_id, '_bak')`。

**验收场景**：

1. **Given** SQL 在事务中执行，**When** 目标记录命中，**Then** `drh_history_pic.union_id` 更新为 `{原 union_id}_bak`。
2. **Given** 某个 `union_id` 在该课程下没有命中记录，**When** SQL 执行，**Then** 该用户对应更新数量为 0，不影响其他数据。

### 用户故事 3 - 审核后再提交（优先级：P1）

执行者需要先在事务内复核结果，确认无误后再人工改为提交。

**独立测试**：检查 SQL 末尾是 `ROLLBACK`，不是 `COMMIT`。

**验收场景**：

1. **Given** SQL 默认执行，**When** 未修改末尾语句，**Then** 更新不会提交。
2. **Given** 审核通过，**When** 人工把末尾 `ROLLBACK` 改为 `COMMIT` 后执行，**Then** 更新才会正式落库。

### 用户故事 4 - 输出运维接口参数（优先级：P1）

SQL 更新后，运维同学需要拿到 `/works/songScore` 的请求体参数，以便触发课程 AI 点评任务。

**独立测试**：检查 SQL 和 `ops-interface-params.json`，确认包含 `class_id`、`max_score`、`min_score`、`song_name`，且 `class_id` 来自命中记录的 `drh_works_pic.live_id`。

**验收场景**：

1. **Given** 临时表已圈定目标历史点评记录，**When** 查看接口参数输出，**Then** 能得到去重后的 `class_id` 请求体。
2. **Given** 当前只读查询结果，**When** 打开 `ops-interface-params.json`，**Then** 能看到 `{"class_id":1124820,"max_score":83,"min_score":77,"song_name":"胡琴说"}`。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `source_union_id` 列表：来源于用户示例和补充输入，SQL 执行前固定为 5 个值。
  - `target_union_id`：来源于当前需求，脚本内通过 `CONCAT(hp.union_id, '_bak')` 现算现用。
  - `live_name`：来源于用户示例 SQL，固定为 `胡琴说（上）`。
  - `class_id`：来源于命中目标记录的 `drh_works_pic.live_id`，用于 `/works/songScore` 运维接口。
  - `max_score/min_score/song_name`：来源于用户补充的接口参数口径，固定为 `83/77/胡琴说`。
  - `pic_id`：来源于 `drh_history_pic.pic_id`，与 `drh_works_pic.id` 关联。
  - `target id`：来源于临时表 `tmp_drh_history_pic_unionid_bak_target.id`，更新阶段只按该 `id` 命中。
- 下游读取字段清单：
  - 应用侧 `HistoryPicService.mapByCondition` 会按 `pic_id` 列表和 `union_id` 查询 `drh_history_pic`。
  - AI 点评过滤会读取 `historyPicDO.picId` 和 `historyPicDO.unionId` 判断是否人工点评过。
  - 本次将目标行 `union_id` 改为 `_bak` 后，原 `union_id` 查询不再命中这些历史点评记录。
- 空对象 / 占位对象风险：
  - 不涉及 DTO、JSON、Map 传参；SQL 不允许空 `IN` 或占位条件。
- 调用顺序风险：
  - 不涉及应用调用顺序；SQL 使用临时表先固化目标行，再执行更新和复核。
- 旧逻辑保持：
  - 保持示例 SQL 的核心筛选口径：同 `union_id`、同 `pic_id`、课程名 `胡琴说（上）`。
  - 只修改 `drh_history_pic.union_id`，不修改历史点评内容和作业表状态。
- 需要用户确认的设计选择：
  - 是否把 SQL 末尾从 `ROLLBACK` 改为 `COMMIT` 并真实执行：已由用户确认并已执行。

## 边界情况

- 某个 `union_id` 命中 0 行时，临时表没有对应记录，更新无影响。
- 已经被改成 `_bak` 的记录不会再次命中，因为筛选条件只包含原始 `union_id`。
- 同一 `union_id` 在 `胡琴说（上）` 下有多条人工点评记录时，会按每条 `drh_history_pic.id` 更新。
- 如果存在同名课程，当前按用户示例仅使用 `drh_live.name = '胡琴说（上）'` 筛选，不额外增加营期条件。
- 如果 `drh_history_pic.union_id` 与 `drh_works_pic.union_id` 不一致，该行不会被纳入本次目标范围。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 创建本次运维 Spec Kit 文档和 SQL 文件。
- **FR-002**：SQL MUST 纳入用户指定的 5 个原始 `union_id`。
- **FR-003**：SQL MUST 通过 `drh_history_pic`、`drh_works_pic`、`drh_live` 的关联条件圈定课程 `胡琴说（上）` 下的目标历史点评记录。
- **FR-004**：SQL MUST 仅修改 `drh_history_pic.union_id`，目标值为 `{原 union_id}_bak`。
- **FR-005**：SQL MUST 默认以 `ROLLBACK` 收尾，审核前不得提交。
- **FR-006**：SQL MUST 在更新后输出 `/works/songScore` 运维接口参数，`class_id` 取命中记录的 `live_id`。
- **FR-007**：执行数据库更新时 MUST 先在事务内复核目标行和更新结果，再提交。

## 成功标准 *(必填)*

- **SC-001**：`044-drh-history-pic-unionid-bak` 目录下存在完整 Spec Kit 文档和 SQL 文件。
- **SC-002**：SQL 可清晰审阅目标行、按用户统计命中数量、执行更新并复核结果。
- **SC-003**：SQL 静态检查可确认只更新 `drh_history_pic.union_id`，且默认不会提交。
- **SC-004**：运维接口参数文件存在，并与只读查询确认的 `class_id` 一致。

## 假设

- 初始处理范围为示例 `union_id` 加补充 4 个，共 5 个；2026-06-02 第二批处理范围为用户新补充的 92 个 `union_id`，不重复处理初始批次。
- 课程筛选固定为 `drh_live.name = '胡琴说（上）'`。
- 目标行为是让这些人工点评记录不再以原 `union_id` 命中业务查询，因此改成 `{union_id}_bak`。
- 运维接口参数固定使用 `max_score=83`、`min_score=77`、`song_name=胡琴说`。
- 本次正式执行时使用同一筛选条件，将事务末尾改为 `COMMIT` 提交；仓库中的 SQL 仍保留默认 `ROLLBACK`，便于复核。

## 执行记录

### D001 - 文档和 SQL 记录

- 已创建本 Spec Kit 文档。
- 已生成 `drh-history-pic-unionid-bak.sql`。
- 已生成 `ops-interface-params.json`。
- 已完成历史问题防漏分析和强制门禁检查。
- D001 阶段仅做只读查询核验，未执行数据库更新。

### D002 - Linux 只读查询和运维参数记录

- 查询方式：通过 `182.92.157.63` 远程执行 MySQL `SELECT` 访问 RDS，只读核对目标数据；未执行 `UPDATE`、`COMMIT` 或其他写操作。
- 查询结论：
  - 当前按“原始 `union_id` + `胡琴说（上）` + `drh_history_pic.pic_id = drh_works_pic.id` + 同 `union_id`”命中 3 条历史点评记录，均为 `class_id=1124820`。
  - `oNGxt5zmBZ2howLnojgjhd3e9ntI` 已存在 `_bak` 历史点评记录 `id=3986709`，对应 `class_id=1124820`。
  - `oNGxt5_XcRNYDz971WrqFeJOCYyk` 在 `class_id=1124818` 下有作品，但没有同 `union_id` 或 `_bak` 的历史点评记录，因此不属于本次 SQL 更新目标。
- 运维接口参数：

```json
{"class_id":1124820,"max_score":83,"min_score":77,"song_name":"胡琴说"}
```

- 文档同步：`drh-history-pic-unionid-bak.sql` 已加入更新后接口参数输出，`ops-interface-params.json` 已记录可直接使用的请求体。

### D003 - SQL 提交执行记录

- 执行内容：用户确认后，通过 `182.92.157.63` 远程连接 RDS，在事务内按 `drh-history-pic-unionid-bak.sql` 的筛选条件执行更新，并将末尾改为 `COMMIT` 提交。
- 执行前目标行：
  - `oNGxt54fYKaIKHAGsqEFhYLtXXbY`：`history_id=3994156`、`pic_id=8742569`、`class_id=1124820`。
  - `oNGxt5y-muyKxySOWAw4u-gmzvNo`：`history_id=3993249`、`pic_id=8729843`、`class_id=1124820`。
  - `oNGxt5z_XoNyC5kG_Q7f-WJRNlmA`：`history_id=3991837`、`pic_id=8724245`、`class_id=1124820`。
- 执行结果：`updated_rows=3`。
- 事务内复核：
  - 3 个目标 `union_id` 的 `target_count=1`、`updated_count=1`、`not_updated_count=0`。
  - 输出接口参数为 `{"class_id":1124820,"max_score":83,"min_score":77,"song_name":"胡琴说"}`。
- 提交后复核：
  - `oNGxt54fYKaIKHAGsqEFhYLtXXbY`、`oNGxt5y-muyKxySOWAw4u-gmzvNo`、`oNGxt5z_XoNyC5kG_Q7f-WJRNlmA` 的原始历史点评记录均为 `0`，对应 `_bak` 记录均为 `1`。
  - `oNGxt5zmBZ2howLnojgjhd3e9ntI` 原始历史点评记录为 `0`，既有 `_bak` 记录 `id=3986709` 保持为 `1`。
  - `oNGxt5_XcRNYDz971WrqFeJOCYyk` 在 `class_id=1124818` 有作品，但原始和 `_bak` 历史点评记录均为 `0`，无可更新目标。
  - 5 个目标 `union_id` 在 `drh_song_score` 的 `class_id=1124820` 下均为 `0` 条。
- 自检结论：本次只修改 `drh_history_pic.union_id`，未修改作业表、课程表或评分表；目标记录已提交为 `_bak`。

### D004 - 纠正记录模板

- 触发原因：用户确认 `class_id=1124818` 对应的补偿没有执行，之前只给了 `{"class_id":1124820,"max_score":83,"min_score":77,"song_name":"胡琴说"}` 这一个参数，导致 `1124818` 没有被纳入补偿范围。
- 修正内容：在文档里补充说明本次漏项来源于补偿参数缺失，`1124818` 未执行补偿不是 `drh_history_pic` 或 `drh_song_score` 数据脏了，而是运维参数列表不完整；后续同类补偿需要按实际命中的 `class_id` 分别补齐。
- 文档同步：已同步更新 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`，并保留现有 SQL 与 `ops-interface-params.json`。
- 验证结果：已用只读查询复核 `drh_song_score`，`oNGxt5_XcRNYDz971WrqFeJOCYyk` 在 `class_id=1124820` 下无评分记录，`1124818` 维度未见补偿参数对应的执行痕迹。

### D005 - 第二批 92 个 union_id 只读核对

- 触发原因：用户追加 92 个 `union_id`，并明确之前批次已处理，本次只处理新加的这批。
- 查询方式：通过 Linux 服务器远程执行 MySQL `SELECT` 访问 RDS，只读核对目标数据；未在 D005 阶段执行写操作。
- 查询结论：
  - 输入 `union_id` 数量为 92，目标课程 `胡琴说（上）`、`class_id=1124820` 下均有对应作品和原始 `drh_history_pic` 记录。
  - 执行前目标历史点评记录为 92 条，目标 `_bak` 历史点评记录为 0 条。
  - `drh_song_score(class_id=1124820)` 中已有 1 条记录：`oNGxt53APz8O4kdRucqp0fGszOs0`，评分记录 `id=38505`；该记录不影响本次 `drh_history_pic` 备份更新，后续补偿接口会按现有评分过滤逻辑处理。
- 运维接口参数保持为：

```json
{"class_id":1124820,"max_score":83,"min_score":77,"song_name":"胡琴说"}
```

### D006 - 第二批 92 个 union_id SQL 提交执行记录

- 执行内容：用户确认后，通过 Linux 服务器远程连接 RDS，在事务内按第二批 SQL 的筛选条件执行更新，并将执行脚本末尾改为 `COMMIT` 提交。
- 执行保护：第二批 SQL 使用临时表固化目标 `drh_history_pic.id`，并用 `@target_count = 92` 作为更新保护条件。
- 执行过程：
  - 首次执行脚本因 MySQL 临时表重复引用限制报错 `Can't reopen table`，未进入更新提交；随后只读复核确认原始记录仍为 92 条、`_bak` 仍为 0 条。
  - 修正为先把目标数写入 `@target_count` 后重新执行。
- 执行结果：
  - 执行前目标行：`target_rows=92`、`target_union_cnt=92`、`class_id=1124820`。
  - 更新结果：`updated_rows=92`。
  - 事务内复核：`target_count=92`、`updated_count=92`、`not_updated_count=0`。
  - 提交后独立复核：原始历史点评记录 `rows_cnt=0`、`union_cnt=0`；`_bak` 历史点评记录 `rows_cnt=92`、`union_cnt=92`。
  - `drh_song_score(class_id=1124820)` 仍为 1 条、1 个用户；本次 SQL 未修改评分表。
- 文档同步：新增 `drh-history-pic-unionid-bak-20260602-batch2.sql`，并同步更新执行记录；未写入 SSH、数据库账号或密码。
