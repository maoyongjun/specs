# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\071-qw-tag-markasync-unionid-compensation`
- 目标项目：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`
- 数据库工具：`C:\workspace\ju-chat\database-sql-skill`
- 相关模块：
  - `com.kkhc.idc.ai.controller.QwTagController`
  - `com.kkhc.idc.ai.service.impl.QwExternalTagTaskServiceImpl`
  - `com.kkhc.idc.lms.common.module.input.ai.QwExternalTagMarkInput`
  - `drh.drh_emp_external_user`

## 当前目标

- 记录一次通过 `external_userid` 查询线上 `drh_emp_external_user.union_id` 的只读 SQL 流程。
- 记录一次调用 `POST /qwTag/markAsync` 补偿企微标签的参数映射和执行门禁。
- 明确当前阶段只创建 Spec Kit 文档，不执行线上 SQL，不调用生产 HTTP 接口。

## 执行原则

- 线上 SQL 必须通过 `database-sql-skill` 的 `prod-mysql` profile 执行，不允许在聊天中暴露数据库凭据。
- 任何 SQL 执行前必须先运行 `db_skill.py analyze --file <sql>`，并确认结果为 `readonly`。
- 本需求只允许 `SELECT` 查询，不允许 `INSERT`、`UPDATE`、`DELETE`、DDL 或存储过程。
- 只有查询结果存在唯一有效的非空 `union_id` 后，才允许构造 `markAsync` 请求。
- 生产 HTTP 调用属于外部副作用，必须在用户明确确认后才执行。
- 数据库字段和 HTTP 字段必须区分：数据库列是 `external_userid`，请求字段是 `external_user_id`。
- `remove_tag_list` 为空时不传；不得传空 JSON、空 Map 或缺少关键字段的占位请求。

## 强制门禁

- 参数来源：`external_user_id`、`add_tag_list`、`source`、`user_id` 来自用户输入；`union_id` 来自线上只读 SQL 查询。
- 查询门禁：`external_userid` 无记录、存在多个不同 `union_id`、`union_id` 为空、`source` 明显不一致、`status` 非正常时，停止执行并记录原因。
- 接口门禁：请求体必须包含 `external_user_id`、`user_id`、`source`、`union_id`、`add_tag_list`。
- 响应门禁：接口返回后必须记录 `taskId/status`；预期初始状态为 `QUEUED` 或命中幂等后的既有状态。
- 验证门禁：后续通过 `drh_qw_external_tag_task` 和 `drh_qw_external_tag_task_log` 查询任务状态和失败原因。

## 重点代码位置

- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\ai\controller\QwTagController.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\input\ai\QwExternalTagMarkInput.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\ai\service\impl\QwExternalTagTaskServiceImpl.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\emp\EmpExternalUserDO.java`

## 文档维护

- `spec.md` 描述用户场景、参数来源、SQL 模板、HTTP 模板、边界和成功标准。
- `tasks.md` 记录文档创建、执行前门禁、实际查询、接口调用和验证任务。
- `checklists/requirements.md` 验证规格质量、参数完整性和生产执行门禁。
- 每次用户补充实际执行结果、修正参数或要求发起生产调用，都必须追加 Dxxx 记录，并同步更新相关文档。
