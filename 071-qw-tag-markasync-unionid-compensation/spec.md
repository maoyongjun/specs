# 功能规格：QW Tag MarkAsync UnionId 查询补偿打标

**功能目录**：`071-qw-tag-markasync-unionid-compensation`  
**创建日期**：`2026-06-10`  
**状态**：Executed  
**输入**：用户要求在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档；通过 `C:\workspace\ju-chat\database-sql-skill` 查询线上 `drh_emp_external_user`，按 `external_userid` 获取 `union_id`；随后调用 `POST http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/qwTag/markAsync` 发送补偿打标请求。用户提供示例参数：`add_tag_list=etW_OgDwAAiEGPQFoaojLpFw9I1sLwHg`、`external_user_id=wmW_OgDwAA5AMTr7TUm-2lSzna9CdDlA`、`source=1`、`union_id=oNGxt59okAFPuAQSb6qd3GYr3eB4`、`user_id=LiXinYao`。

## 背景

- 当前问题：需要对指定企微外部联系人补偿打标签，但执行前必须先通过线上 `external_userid` 查询可信 `union_id`。
- 当前行为：`QwTagController#markAsync` 校验请求参数后调用 `QwExternalTagTaskServiceImpl#submitMarkTask`，落 `drh_qw_external_tag_task` 任务并投递 `QW_EXTERNAL_TAG_MARK` 延迟 MQ；消费者限流调用企微代理打标签，并最多三次 get 确认后更新 OTS。
- 目标行为：形成可复用的人工补偿执行说明，锁定只读 SQL、参数映射、HTTP 请求模板、执行前门禁和后续验证表。
- 非目标：本阶段不执行线上 SQL、不调用生产 HTTP、不修改 Java 代码、不新增接口、不新增数据库表、不绕过现有 MQ/限流/三次确认链路。

## 执行流程

1. 准备用户提供参数：`external_user_id`、`add_tag_list`、`source`、`user_id`。
2. 将 `external_user_id` 映射为数据库查询字段 `external_userid`。
3. 使用 `database-sql-skill` 对只读 SQL 执行 `analyze`，确认风险类型为 `readonly`。
4. 使用 `prod-mysql` profile 执行只读 SQL，查询 `drh.drh_emp_external_user.union_id`。
5. 确认查询结果只有一个有效非空 `union_id`；如存在多个不同 `union_id`、无记录或 `union_id` 为空，停止执行。
6. 用户明确确认后，按查询得到的 `union_id` 构造 `markAsync` 请求。
7. 记录接口返回的 `taskId/status`，并通过任务表和任务日志表验证后续执行状态。

## 只读 SQL 模板

执行前必须先分析 SQL：

```powershell
python database-sql-skill\scripts\db_skill.py analyze --file .\specs\071-qw-tag-markasync-unionid-compensation\sql\check-unionid-by-external-userid.sql
```

只读查询模板：

```sql
SELECT id, emp_id, external_userid, union_id, user_id, source, status, create_time
FROM drh.drh_emp_external_user
WHERE external_userid = '<external_userid>'
  AND union_id IS NOT NULL
  AND union_id <> ''
ORDER BY id DESC
LIMIT 10;
```

执行模板：

```powershell
python database-sql-skill\scripts\db_skill.py run --profile prod-mysql --file .\specs\071-qw-tag-markasync-unionid-compensation\sql\check-unionid-by-external-userid.sql --format table
```

> 本阶段只写文档，未创建并执行上述 SQL 文件；如后续执行，应先把实际 `external_userid` 写入 SQL 文件，再走 analyze 和 run。

## HTTP 请求模板

接口：

```http
POST http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/qwTag/markAsync
Content-Type: application/json
```

请求体模板：

```json
{
  "add_tag_list": "etW_OgDwAAiEGPQFoaojLpFw9I1sLwHg",
  "external_user_id": "wmW_OgDwAA5AMTr7TUm-2lSzna9CdDlA",
  "source": 1,
  "union_id": "<SQL查询得到的union_id>",
  "user_id": "LiXinYao"
}
```

若 SQL 查询结果确认 `union_id=oNGxt59okAFPuAQSb6qd3GYr3eB4`，则请求体示例为：

```json
{
  "add_tag_list": "etW_OgDwAAiEGPQFoaojLpFw9I1sLwHg",
  "external_user_id": "wmW_OgDwAA5AMTr7TUm-2lSzna9CdDlA",
  "source": 1,
  "union_id": "oNGxt59okAFPuAQSb6qd3GYr3eB4",
  "user_id": "LiXinYao"
}
```

`remove_tag_list` 为空时不传。接口成功提交后返回体中的业务数据应包含 `taskId` 和 `status`，初始状态通常为 `QUEUED`；重复请求可能命中幂等，返回既有任务状态。

## 用户场景与测试

### 用户故事 1 - 通过 external_userid 查询 union_id（优先级：P1）

执行人需要用用户提供的 `external_user_id` 在生产库中查到可信的 `union_id`，避免把标签任务提交给错误用户。

**独立测试**：对查询 SQL 执行 `db_skill.py analyze`，确认 readonly；再使用 `prod-mysql` 查询，检查结果中只有一个不同的非空 `union_id`。

**验收场景**：

1. **Given** `external_userid` 有唯一有效 `union_id`，**When** 执行只读查询，**Then** 得到一个可用于 HTTP 请求的 `union_id`。
2. **Given** `external_userid` 无记录或 `union_id` 为空，**When** 执行只读查询，**Then** 停止补偿，不构造 HTTP 请求。
3. **Given** 查询结果出现多个不同 `union_id`，**When** 执行人复核结果，**Then** 停止补偿并要求确认真实用户。

### 用户故事 2 - 调用 markAsync 补偿打标签（优先级：P1）

执行人确认 `union_id` 后，通过统一异步打标接口提交任务，让现有 MQ、限流、企微代理和三次 get 确认链路完成补偿。

**独立测试**：在用户明确确认生产调用后，构造请求体并调用 `markAsync`，验证返回 `taskId/status`，再查询任务表和任务日志表确认任务进入后续链路。

**验收场景**：

1. **Given** 请求体包含 `external_user_id/user_id/source/union_id/add_tag_list`，**When** 调用 `markAsync`，**Then** 接口应返回 `taskId` 和 `status`。
2. **Given** `add_tag_list` 和 `remove_tag_list` 同时为空，**When** 调用 `markAsync`，**Then** 接口返回业务错误，不创建有效任务。
3. **Given** 重复提交完全相同参数，**When** 调用 `markAsync`，**Then** 服务按幂等 key 返回既有任务，不重复创建有效任务。

### 用户故事 3 - 生产副作用受控（优先级：P1）

文档阶段不能误触线上数据库写入或生产打标；实际执行必须有明确记录和可回溯任务。

**独立测试**：检查文档和任务清单，确认当前阶段未执行 SQL、未调用 HTTP；后续执行记录必须包含 SQL 分析结果、查询结果摘要、HTTP 返回和任务表验证结果。

**验收场景**：

1. **Given** 当前只创建 Spec Kit 文档，**When** 完成 D001，**Then** 不应产生任何线上副作用。
2. **Given** 后续需要真实补偿，**When** 用户明确确认执行，**Then** 先记录 SQL 分析和查询结果，再执行 HTTP 调用。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `external_user_id`：来源用户输入；HTTP 请求前已确定；下游 `QwTagController` 读取 `input.getExternalUserId()`。
  - `external_userid`：数据库列名，由 `external_user_id` 去掉第二个下划线映射而来；SQL 查询前确定。
  - `union_id`：来源 `drh.drh_emp_external_user.union_id` 线上只读查询；HTTP 请求前必须确定；下游用于任务幂等 key 和任务表记录。
  - `add_tag_list`：来源用户输入；HTTP 请求前确定；下游解析为 `add_tag` 数组。
  - `remove_tag_list`：本次为空；为空时不传；下游允许新增和移除标签不同时为空。
  - `source`：来源用户输入，示例为 `1`；下游用于企微代理企业身份。
  - `user_id`：来源用户输入，示例为 `LiXinYao`；下游作为企微成员 `userid`。
- 下游读取字段清单：
  - `QwTagController#markAsync` 读取 `external_user_id`、`user_id`、`source`、`add_tag_list`、`remove_tag_list`。
  - `QwExternalTagTaskServiceImpl#submitMarkTask` 读取 `union_id`，为空时会降级为 `unKnown`；本补偿流程必须避免使用该降级值。
  - `QwExternalTagTaskServiceImpl#invokeMarkFcWithRateLimit` 读取任务中的 `userId/externalUserId/source/addTagList/removeTagList`，构造企微代理 MARK 请求。
  - `QwExternalTagTaskServiceImpl#verifyAndUpdateOts` 读取任务和企微 get 返回，确认标签后写 `drh_external_user_info`。
- 空对象 / 占位对象风险：
  - 不允许在 `union_id` 未查到时构造请求，避免任务表写入 `unKnown`。
  - 不允许 `add_tag_list` 和 `remove_tag_list` 同时为空。
  - 不允许把空 JSON 或只含部分字段的请求发给生产接口。
- 调用顺序风险：
  - 必须先完成 SQL readonly 分析，再查库，再人工确认，再调用 HTTP。
  - `markAsync` 只是提交异步任务；接口返回成功不等于企微标签已经最终落地。
  - 后续落地状态必须看 `drh_qw_external_tag_task` 和 `drh_qw_external_tag_task_log`。
- 旧逻辑保持：
  - 保持 `markAsync` 现有参数校验。
  - 保持任务表幂等 key 规则。
  - 保持 `QW_EXTERNAL_TAG_MARK` 和 `QW_EXTERNAL_TAG_VERIFY` 的 MQ 异步链路。
  - 保持消费者限流、企微代理调用和三次 get 确认。
- 需要用户确认的设计选择：
  - 生产 HTTP 调用必须另行确认，本阶段不执行。
  - 若查询到的 `source` 与用户提供 `source=1` 冲突，需确认最终请求使用哪个 `source`。
  - 若查询记录 `status` 非正常，需确认是否仍可对该外部联系人补偿打标。

## 边界情况

- `external_userid` 无记录：停止补偿，记录未命中。
- `union_id` 为 `NULL` 或空字符串：停止补偿，不能使用 `unKnown`。
- 查询到多个不同 `union_id`：停止补偿，避免误打标签。
- 查询到多行但只有同一个非空 `union_id`：允许继续，但需记录选用的 `union_id` 和最新行 `id`。
- `source` 与查询记录不一致：停止并确认。
- `status` 显示外部联系关系非正常：停止并确认。
- `markAsync` 返回业务错误：记录错误响应，不重试生产请求，除非用户重新确认。
- `markAsync` 返回 `QUEUED` 后任务消费失败：通过任务日志定位 `MARK_MQ_SEND_FAILED`、`MARK_FAILED`、`VERIFY_TIMEOUT` 或 `FAILED`。
- 幂等命中：记录既有 `taskId/status`，不应简单认为没有执行。

## 需求

### 功能需求

- **FR-001**：本目录 MUST 包含 `spec.md`、`tasks.md`、`AGENTS.md` 和 `checklists/requirements.md`。
- **FR-002**：文档 MUST 明确当前阶段只写 Spec Kit，不执行线上 SQL，不调用生产 HTTP。
- **FR-003**：文档 MUST 固定 `external_user_id` 到数据库 `external_userid` 的字段映射。
- **FR-004**：执行 SQL 前 MUST 使用 `database-sql-skill` 分析 SQL，并确认结果为 `readonly`。
- **FR-005**：线上查询 MUST 使用 `prod-mysql` profile，且只查询 `drh.drh_emp_external_user`。
- **FR-006**：HTTP 请求 MUST 使用 `POST http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/qwTag/markAsync`。
- **FR-007**：HTTP 请求体 MUST 包含 `external_user_id`、`user_id`、`source`、`union_id` 和 `add_tag_list`。
- **FR-008**：`remove_tag_list` 为空时 MUST 不传；`add_tag_list` 和 `remove_tag_list` MUST NOT 同时为空。
- **FR-009**：未查到唯一有效 `union_id` 时 MUST NOT 构造或发送生产 HTTP 请求。
- **FR-010**：生产 HTTP 调用后 MUST 记录 `taskId/status`，并通过任务表和任务日志表做后续验证。

## 成功标准

- **SC-001**：规格目录完整，且无模板占位内容残留。
- **SC-002**：规格中能直接区分数据库 `external_userid` 与 HTTP `external_user_id`。
- **SC-003**：规格中包含只读 SQL 模板、`db_skill.py analyze/run` 命令模板和 `markAsync` 请求体模板。
- **SC-004**：执行门禁明确阻止无 `union_id`、多 `union_id`、空标签和未确认生产调用。
- **SC-005**：后续执行人能按文档记录 SQL 分析、查询结果、HTTP 返回、任务表状态和任务日志。

## 假设

- 新目录编号使用当前最新 `070` 的下一号 `071`。
- 用户示例参数作为本规格默认示例值；若实际补偿对象不同，后续只替换 `external_user_id/add_tag_list/source/user_id`。
- 网关调用不在文档创建阶段执行；如后续执行，需由用户明确确认生产 HTTP 调用。
- 网关鉴权未在代码中发现额外约束，文档默认只记录 `Content-Type: application/json`，实际调用时沿用业务方现有网络和鉴权环境。
- `drh_emp_external_user.status=0` 表示正常好友关系；若实际业务含义变化，以当前线上表定义和业务确认结果为准。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档目录。
- 已记录 `prod-mysql` 只读查询流程、SQL 模板、HTTP 请求模板和执行门禁。
- 已完成代码事实确认：`QwTagController#markAsync` 校验必填字段，`QwExternalTagTaskServiceImpl#submitMarkTask` 落任务并发送 `QW_EXTERNAL_TAG_MARK` MQ，消费端通过企微代理打标签并三次 get 确认。
- 已明确本阶段未执行线上 SQL，未调用生产 HTTP，未修改业务代码。

### D002 - 后续执行记录模板

- SQL 分析：`check-unionid-by-external-userid.sql` 分析结果为 `Risk: readonly`。
- SQL 查询：使用 `prod-mysql` 查询 `external_userid=wmW_OgDwAA5AMTr7TUm-2lSzna9CdDlA`，返回 5 行，`union_id` 唯一为 `oNGxt59okAFPuAQSb6qd3GYr3eB4`；最新记录 `id=13086123`、`source=1`、`status=0`、`create_time=2026-03-10 15:01:25`。
- 执行确认：用户在本线程明确要求“执行SQL，并调用http。”。
- HTTP 返回：`POST http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/qwTag/markAsync` 返回 `status=200`、`message=OK`、`requestId=ac2e9063fd85423c8bbdb31aefd389d3`、`taskId=c29a78d958a24516bd2eb1a3188dea8e`、`status=OTS_UPDATED`。
- 任务验证：`drh_qw_external_tag_task` 主表状态为 `OTS_UPDATED`，`fc_errcode=0`、`fc_errmsg=ok`、`verify_count=1`；日志表事件流为 `TASK_CREATED -> MARK_MQ_SENT -> MARK_CONSUME -> MARK_FC_SUCCEEDED -> VERIFY_GET_START -> OTS_UPDATED`。

### D003 - 批量 external_userid 补偿执行记录

- 输入来源：`C:\Users\EDY\.codex\attachments\caa0bfb3-36e3-4312-94a8-5d61b27fbb7a\pasted-text.txt`。
- 输入统计：共 210 个 `external_userid`，去重后 210 个，无重复。
- SQL 文件：`sql/batch-check-unionid-20260610.sql`；分析结果 `Risk: readonly`。
- SQL 查询结果：`prod-mysql` 查询输出到 `sql/batch-check-unionid-20260610.csv`；210 个均查到非空 `union_id`，且最新记录均满足 `source=1`、`status=0`。
- HTTP 调用：对 210 个 external_userid 逐条调用 `POST http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/qwTag/markAsync`；请求参数固定 `add_tag_list=etW_OgDwAAiEGPQFoaojLpFw9I1sLwHg`、`source=1`、`user_id=LiXinYao`，`union_id` 使用 SQL 查询结果。
- HTTP 返回：结果输出到 `sql/batch-markasync-result-20260610.csv`；210 个请求均无异常，209 个返回 `QUEUED`，1 个返回 `OTS_UPDATED`，共 210 个唯一 `taskId`。
- 任务验证：验证 SQL 均为 `readonly`；`drh_qw_external_tag_task` 聚合结果为 `OTS_UPDATED/fc_errcode=0/fc_errmsg=ok` 共 210 个。
- 日志验证：`drh_qw_external_tag_task_log` 聚合显示 `TASK_CREATED`、`MARK_MQ_SENT`、`MARK_CONSUME`、`MARK_FC_SUCCEEDED`、`OTS_UPDATED` 均为 210；`VERIFY_GET_START` 为 217、`VERIFY_MQ_SENT` 为 7，说明 7 个任务经历了延迟二次确认，但最终全部 `OTS_UPDATED`。
- 非终态检查：`status <> 'OTS_UPDATED'` 查询返回 0 行。
