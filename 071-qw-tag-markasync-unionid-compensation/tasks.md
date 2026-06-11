# 任务清单：QW Tag MarkAsync UnionId 查询补偿打标

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：当前阶段只验证文档完整性和静态事实；真实补偿阶段必须记录 SQL 分析、SQL 查询、HTTP 返回和任务表验证结果。

## Phase 1：规格与事实确认

- [x] T001 创建 `specs/071-qw-tag-markasync-unionid-compensation` 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- [x] T002 明确当前阶段只写 Spec Kit 文档，不执行线上 SQL，不调用生产 HTTP。
- [x] T003 确认接口入口为 `QwTagController#markAsync`，路径为 `POST /qwTag/markAsync`。
- [x] T004 确认请求 DTO 为 `QwExternalTagMarkInput`，JSON 字段为 `external_user_id/user_id/union_id/source/add_tag_list/remove_tag_list`。
- [x] T005 确认服务实现为 `QwExternalTagTaskServiceImpl#submitMarkTask`，会落任务、发送 `QW_EXTERNAL_TAG_MARK` MQ，并由消费者完成后续打标和 get 确认。
- [x] T006 确认 `drh_emp_external_user` Java 字段 `externalUserid/unionId` 对应数据库列 `external_userid/union_id`。

## Phase 2：执行前门禁

- [x] T007 创建实际只读 SQL 文件，替换模板中的 `<external_userid>` 为待补偿外部联系人 ID。
- [x] T008 执行 `python database-sql-skill\scripts\db_skill.py analyze --file <sql>`，确认风险类型为 `readonly`。
- [x] T009 使用 `prod-mysql` profile 执行只读 SQL，记录返回行数和输出。
- [x] T010 确认返回结果只有一个不同的非空 `union_id`。
- [x] T011 复核查询结果中的 `source/status`，如与请求参数或正常好友关系不一致，停止并确认。
- [x] T012 获得用户对生产 HTTP 调用的明确确认。

## Phase 3：生产 HTTP 提交

- [x] T013 用 SQL 查询得到的 `union_id` 构造 `markAsync` 请求体。
- [x] T014 确认请求体包含 `external_user_id/user_id/source/union_id/add_tag_list`，且 `remove_tag_list` 为空时不传。
- [x] T015 调用 `POST http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/qwTag/markAsync`。
- [x] T016 记录 HTTP 返回中的 `taskId/status`；如返回业务错误，记录错误并停止。

## Phase 4：后续验证

- [x] T017 查询 `drh_qw_external_tag_task`，确认任务参数、状态、`fc_errcode/fc_errmsg`。
- [x] T018 查询 `drh_qw_external_tag_task_log`，确认 `TASK_CREATED`、`MARK_MQ_SENT`、`MARK_FC_SUCCEEDED`、`OTS_UPDATED` 或失败事件。
- [x] T019 若任务进入 `MARK_FAILED`、`VERIFY_TIMEOUT` 或 `FAILED`，记录失败原因，不自动重试生产请求。
- [x] T020 将 SQL 分析、查询结果、HTTP 返回、任务验证结果追加到 `spec.md` 的 D002 或后续记录。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `071-qw-tag-markasync-unionid-compensation` Spec Kit 文档。
- 验证方式：静态确认 `QwTagController#markAsync`、`QwExternalTagMarkInput`、`QwExternalTagTaskServiceImpl` 和 `EmpExternalUserDO` 的字段与流程。
- 自检结论：已记录参数来源、字段映射、只读 SQL 门禁、生产 HTTP 门禁、任务验证表和边界情况；本阶段没有线上副作用。

### D002 - 实际补偿记录模板

- SQL 分析命令：`python database-sql-skill\scripts\db_skill.py analyze --file .\specs\071-qw-tag-markasync-unionid-compensation\sql\check-unionid-by-external-userid.sql`，结果 `Risk: readonly`。
- SQL 查询命令：`python database-sql-skill\scripts\db_skill.py run --profile prod-mysql --file .\specs\071-qw-tag-markasync-unionid-compensation\sql\check-unionid-by-external-userid.sql --format table`，返回 5 行，唯一 `union_id=oNGxt59okAFPuAQSb6qd3GYr3eB4`。
- 用户确认：用户在本线程明确要求“执行SQL，并调用http。”。
- HTTP 调用结果：返回 `status=200`、`requestId=ac2e9063fd85423c8bbdb31aefd389d3`、`taskId=c29a78d958a24516bd2eb1a3188dea8e`、`status=OTS_UPDATED`。
- 验证结果：主表 `status=OTS_UPDATED`、`fc_errcode=0`、`fc_errmsg=ok`、`verify_count=1`；日志事件流完整到 `OTS_UPDATED`。

### D003 - 批量 external_userid 补偿执行记录

- SQL 分析命令：`python database-sql-skill\scripts\db_skill.py analyze --file .\specs\071-qw-tag-markasync-unionid-compensation\sql\batch-check-unionid-20260610.sql`，结果 `Risk: readonly`。
- SQL 查询命令：`python database-sql-skill\scripts\db_skill.py run --profile prod-mysql --file .\specs\071-qw-tag-markasync-unionid-compensation\sql\batch-check-unionid-20260610.sql --format csv --output .\specs\071-qw-tag-markasync-unionid-compensation\sql\batch-check-unionid-20260610.csv`。
- 查询结果：输入 210 个、去重 210 个、全部查到非空 `union_id`，且最新记录均为 `source=1/status=0`。
- HTTP 调用结果：`sql/batch-markasync-result-20260610.csv` 记录 210 个响应，209 个 `QUEUED`、1 个 `OTS_UPDATED`，无调用异常。
- 验证结果：主表聚合为 `OTS_UPDATED/fc_errcode=0/fc_errmsg=ok` 共 210 个；日志聚合显示 210 个都完成 `MARK_FC_SUCCEEDED` 和 `OTS_UPDATED`，非终态查询返回 0 行。
