# 功能规格：企微打标签限流与 OTS 一致性

**功能目录**：`059-qw-tag-fc-rate-limit-ots-consistency`  
**创建日期**：`2026-06-08`  
**状态**：Draft  
**输入**：用户要求在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档，记录企微打标签限流、函数计算兼容改造、三次 get 确认、OTS 一致性、MQ tag/queue、任务表和补偿方案；本阶段只编写文档，不编码。

## 背景

- 当前问题：多处调用打标签函数计算，容易触发函数计算限流；同时 `mark_tag` 成功和我方 `drh_external_user_info` 标签写入之间存在一致性风险。
- 当前行为：`fc/qw-tag/AppTask` 默认执行企微 `externalcontact/mark_tag` 并在函数内更新 OTS；`CompleteTagUtil.doResponseTag(...)` 通过 `qw-api-proxy` 访问企微接口。
- 目标行为：`kkhc-idc/ai` 新接口收请求后只落任务并发 MQ，MQ 消费者限速调用同一个 `AppTask` 打标签；打标签成功后，`kkhc-idc/ai` 再通过同一个 `AppTask` 的 get 模式读取企微标签，三次确认成功后由调用侧写 `drh_external_user_info`。
- 非目标：本阶段不修改代码，不创建数据库表，不调整线上 MQ 配置，不部署函数计算。

## 最终方案

| 事项 | 决策 |
|---|---|
| 统一入口 | 新增接口放在 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai`，Controller 为 `com.kkhc.idc.ai.controller.QwTagController`，接口 `POST /qwTag/markAsync`。 |
| 函数双模式 | 改造 `C:\workspace\ju-chat\fc\qw-tag\src\main\java\com\drh\compute\AppTask.java`，通过 `fc_action` 区分打标签和读取外部联系人。 |
| 旧调用兼容 | `fc_action` 缺省或 `MARK_TAG` 时走打标签；`ots_write_mode` 缺省时保持 FC 内部写 OTS。 |
| 新链路写入 | 新链路调用打标签 FC 时传 `ots_write_mode=CALLER_VERIFY_WRITE`，FC 不写 OTS，由 `kkhc-idc/ai` 三次 get 确认后写。 |
| get 调用方式 | 三次 get 逻辑写在 `kkhc-idc/ai`，但每次都调用同一个 `AppTask` 的 `fc_action=GET_EXTERNAL_CONTACT`，不能直接 HTTP 调企微 get。 |
| 限流位置 | `QW_EXTERNAL_TAG_MARK` 消费者内先进入 `rateLimiter`，再调用打标签 FC。 |
| 失败拉取 | `mark_tag` 返回 `errcode != 0` 时直接失败并打印日志，不触发 get。 |

## 用户场景与测试

### 用户故事 1 - 接口收敛并削峰调用 FC（优先级：P1）

业务方调用统一接口提交打标签请求，接口不直接调用函数计算，而是落任务并发送 MQ，由消费者限速调用 FC。

**独立测试**：构造合法请求，验证接口写入任务、发送 `QW_EXTERNAL_TAG_MARK` MQ，并立即返回 `taskId` 和 `QUEUED`，不直接调用 FC。

**验收场景**：

1. **Given** 合法打标签请求，**When** 调用 `POST /qwTag/markAsync`，**Then** 返回 `QUEUED` 且生成 `taskId`。
2. **Given** MQ 消费者处理任务，**When** 调用打标签 FC，**Then** FC 调用必须包在 `rateLimiter` 内。
3. **Given** 重复请求命中同一个幂等 key，**When** 再次提交，**Then** 不重复创建有效任务。

### 用户故事 2 - FC 兼容旧调用并支持 get 模式（优先级：P1）

旧调用不传新增参数时，`AppTask` 仍按原逻辑打标签并写 OTS；新调用可指定跳过 FC 内部写 OTS；get 模式可读取企微外部联系人详情。

**独立测试**：分别构造无新增参数、`CALLER_VERIFY_WRITE`、`GET_EXTERNAL_CONTACT` 三类入参，验证 OTS 写入行为和返回结果。

**验收场景**：

1. **Given** 未传 `fc_action` 和 `ots_write_mode`，**When** 调用 `AppTask`，**Then** 执行打标签并保持旧的 FC 内部 OTS 写入。
2. **Given** `fc_action=MARK_TAG` 且 `ots_write_mode=CALLER_VERIFY_WRITE`，**When** `mark_tag` 返回 `errcode=0`，**Then** FC 返回成功 JSON 且不写 OTS。
3. **Given** `fc_action=GET_EXTERNAL_CONTACT`，**When** 调用 `AppTask`，**Then** 不校验 `add_tag_list/remove_tag_list`，通过企微代理函数返回 `externalcontact/get` 结果。

### 用户故事 3 - 三次 get 确认后写 OTS（优先级：P1）

`mark_tag` 成功后，系统必须在 30 秒内最多三次通过 `AppTask` get 模式确认企微标签已生效，确认后再更新 `drh_external_user_info`。

**独立测试**：模拟三次 get 返回，覆盖第一次成功、第二次成功、第三次仍未成功、`mark_tag` 失败不拉取。

**验收场景**：

1. **Given** `mark_tag` 返回 `errcode=0`，**When** 第一次 get 已看到目标标签，**Then** 立即写 OTS 并置为 `OTS_UPDATED`。
2. **Given** 第一次 get 未确认，**When** 约 `10s` 后消费 `QW_EXTERNAL_TAG_VERIFY`，**Then** 执行第二次 get。
3. **Given** 第二次 get 未确认，**When** 约 `20s` 后再次消费 `QW_EXTERNAL_TAG_VERIFY`，**Then** 执行第三次 get。
4. **Given** 三次 get 都未确认，**When** 第三次结束，**Then** 任务置为 `VERIFY_TIMEOUT`，只打印日志，不继续自动拉取。

### 用户故事 4 - 业务失败不触发 get（优先级：P1）

当企微打标签返回业务错误时，不应继续 get，也不应写 OTS。

**独立测试**：模拟 FC 返回 `{"errcode":60111,"errmsg":"userid not found"}`，验证任务失败、无 get 调用、无 OTS 写入。

**验收场景**：

1. **Given** `mark_tag` 返回 `errcode=60111`，**When** 消费者处理结果，**Then** 状态置为 `MARK_FAILED` 并记录错误日志。
2. **Given** `MARK_FAILED` 任务，**When** 补偿扫描执行，**Then** 不重新触发 get 确认。

## FC 改造明细

- `fc/common` 入参 DTO `com.drh.common.dto.EmpExternalTag` 后续实现 MUST 新增：
  - `fc_action`：函数动作。缺省或 `MARK_TAG` 表示打标签；`GET_EXTERNAL_CONTACT` 表示读取企微外部联系人详情。
  - `ots_write_mode`：OTS 写入模式。缺省表示 FC 内部写；`CALLER_VERIFY_WRITE` 表示调用方确认后写。
- `AppTask.handleRequest(...)` 后续实现 MUST 先判断 `fc_action`，再执行旧的 `add_tag_list/remove_tag_list` 非空校验。
- `fc_action=GET_EXTERNAL_CONTACT` 时：
  - 只校验 `external_user_id` 和 `source`。
  - 调用 `CompleteTagUtil.doGetExternalContact(source, externalUserId)`。
  - 直接返回 get JSON，不写 OTS。
- `fc_action` 缺省或 `MARK_TAG` 时：
  - 走原打标签逻辑。
  - `CompleteTagUtil.doResponseTag(...)` 的返回值必须保存并返回。
  - `errcode != 0` 时不写 OTS。
  - `errcode=0` 且 `ots_write_mode=CALLER_VERIFY_WRITE` 时不写 OTS。
  - `errcode=0` 且未传 `CALLER_VERIFY_WRITE` 时保持旧行为写 OTS。
- `fc_action` 为其他未知非空值时，后续实现 SHOULD 返回参数错误 JSON，不写 OTS。

## CompleteTagUtil 改造明细

- 保留 `doResponseTag(Integer source, CompleteTagDto completeTagDto)`，继续调用 `externalcontact/mark_tag`。
- 新增 `doGetExternalContact(Integer source, String externalUserId)`。
- `doGetExternalContact(...)` MUST 通过现有 `invokeQwProxyFc(...)` 调用企微代理函数，不能直接 HTTP 调企微。
- get URL 固定为：`https://qyapi.weixin.qq.com/cgi-bin/externalcontact/get?external_userid={externalUserId}`。
- `QwFcProxyInput` 参数：
  - `source=source`
  - `reqType=1`
  - `actionType=1`
  - `url=get URL`

## idc-ai 调用方式

- 新接口：
  - 模块：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`
  - Controller：`com.kkhc.idc.ai.controller.QwTagController`
  - 接口：`POST /qwTag/markAsync`
  - 行为：校验参数、落任务、发送 MQ，立即返回 `taskId` 和 `QUEUED`。
- 打标签 FC 入参：
  - `fc_action=MARK_TAG`
  - `ots_write_mode=CALLER_VERIFY_WRITE`
  - `external_user_id`
  - `user_id`
  - `union_id`
  - `source`
  - `add_tag_list`
  - `remove_tag_list`
- get FC 入参：
  - `fc_action=GET_EXTERNAL_CONTACT`
  - `external_user_id`
  - `user_id`
  - `source`
  - `request_id/task_id`
- FC 路由：
  - `serviceName=async-util`
  - `mq.delay.topic=test_delay` 时 `functionName=cpv-qw-tag-util-test`
  - 其他情况 `functionName=sync-external-tag`

## 数据与 MQ

### 新建表

- `drh_qw_external_tag_task`：任务主表。
- `drh_qw_external_tag_task_log`：任务过程日志表。

### 主表字段

- `task_id`
- `idempotent_key`
- `external_user_id`
- `user_id`
- `union_id`
- `source`
- `add_tag_list`
- `remove_tag_list`
- `fc_action`
- `ots_write_mode`
- `status`
- `fc_errcode`
- `fc_errmsg`
- `fc_response`
- `verify_count`
- `next_verify_time`
- `last_get_response`
- `created_at`
- `updated_at`

### 状态枚举

- `INIT`
- `MQ_SENT`
- `FC_CALLING`
- `MARK_SUCCEEDED`
- `MARK_FAILED`
- `VERIFYING`
- `OTS_UPDATED`
- `VERIFY_TIMEOUT`
- `FAILED`

### MQ

- Topic 使用现有 `mq.delay.topic`。
- 测试 topic：`test_delay`。
- 生产 topic：`delay`。
- tag：`QW_EXTERNAL_TAG_MARK`，用于打标签任务。
- tag：`QW_EXTERNAL_TAG_VERIFY`，用于第 2、第 3 次 get 确认。
- `MessageType`：新增 `QW_EXTERNAL_TAG_MARK`，建议 code 使用 `136`。

### 限速

- 打标签 FC 限速 key：`ai:qwExternalTagFcRateLimiter`。
- get FC 限速 key：`ai:qwExternalTagGetFcRateLimiter`。
- 限速放在 MQ 消费者内，接口层不直接调用 FC。

## 三次 get 确认

- 三次 get 编排写在 `kkhc-idc/ai` 的 `QwExternalTagTaskService`。
- 每次 get 都通过同一个 `fc/qw-tag/AppTask` 的 `fc_action=GET_EXTERNAL_CONTACT` 调用，不能直接 HTTP 调企微。
- 第 1 次：`QW_EXTERNAL_TAG_MARK` 消费者收到打标签 FC `errcode=0` 后立即调用 get 模式。
- 第 2 次：第 1 次未确认时，发送 `QW_EXTERNAL_TAG_VERIFY` 延迟 MQ，约 `10s` 后消费并调用 get 模式。
- 第 3 次：第 2 次未确认时，再发送 `QW_EXTERNAL_TAG_VERIFY`，约 `20s` 后消费并调用 get 模式。
- 第 3 次仍未确认：状态置为 `VERIFY_TIMEOUT`，只打印日志，不继续自动拉取。

## get 成功判定

- get FC 返回 `errcode=0`。
- 返回体中存在目标 `follow_user`。
- 目标 `follow_user.userid == 请求 user_id`。
- `add_tag_list` 中所有 `tag_id` 都存在于目标 `follow_user.tags`。
- `remove_tag_list` 中所有 `tag_id` 都不存在于目标 `follow_user.tags`。
- 满足以上条件后，`kkhc-idc/ai` 合并更新 `drh_external_user_info.follow_user` 中对应 `userid` 的 `tags`。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `external_user_id`：来自 `POST /qwTag/markAsync` 请求；接口落任务前校验；FC 调用前写入 taskObj。
  - `user_id`：来自请求；用于 `mark_tag` 和 get 后定位 `follow_user`。
  - `source`：来自请求；用于企微代理函数选择企业身份。
  - `fc_action`：`kkhc-idc/ai` 消费者现算现传；打标签传 `MARK_TAG`，get 传 `GET_EXTERNAL_CONTACT`。
  - `ots_write_mode`：`kkhc-idc/ai` 打标签消费者固定传 `CALLER_VERIFY_WRITE`。
  - `verify_count`：来自 `drh_qw_external_tag_task`；每次 get 前后更新。
- 下游读取字段清单：
  - `AppTask.handleRequest(...)` 读取 `fc_action`、`ots_write_mode`、`external_user_id`、`user_id`、`source`、`add_tag_list`、`remove_tag_list`。
  - `CompleteTagUtil.doResponseTag(...)` 读取 `source` 和 `CompleteTagDto`。
  - `CompleteTagUtil.doGetExternalContact(...)` 读取 `source` 和 `external_user_id`。
  - `QwExternalTagTaskService.verifyAndUpdateOts(...)` 读取任务表的目标标签、get 返回的 `follow_user.tags` 和 OTS 当前 `follow_user`。
- 空对象 / 占位对象风险：
  - `GET_EXTERNAL_CONTACT` 不能被旧的空标签列表校验拦截。
  - get 模式不能构造空 `CompleteTagDto` 作为下游参数。
  - 任务表中 `add_tag_list` 和 `remove_tag_list` 不能同时为空。
- 调用顺序风险：
  - 必须先 `mark_tag` 成功，再 get 确认，再写 OTS。
  - `mark_tag` 失败不能触发 get。
  - 第 2、第 3 次 get 只能由延迟 MQ 触发，不能在同一线程 sleep 等待。
- 旧逻辑保持：
  - 旧调用不传 `fc_action` 和 `ots_write_mode` 时，`AppTask` 行为保持兼容。
  - 旧函数名 `cpv-qw-tag-util-test`、`sync-external-tag` 保持。
  - `CompleteTagUtil.invokeQwProxyFc(...)` 继续作为访问企微接口的代理入口。
- 需要用户确认的设计选择：
  - 已确认：同一个 `AppTask` 同时支持打标签和 get。
  - 已确认：新链路传参数让 FC 跳过内部写 OTS，由 `kkhc-idc/ai` 确认后写。

## 边界情况

- `fc_action` 缺省或空：按 `MARK_TAG` 处理。
- `fc_action=GET_EXTERNAL_CONTACT` 且缺少 `external_user_id` 或 `source`：返回参数错误，不写 OTS。
- `fc_action=MARK_TAG` 且 `add_tag_list/remove_tag_list` 同时为空：保持旧校验，不处理。
- `mark_tag` 返回 `errcode != 0`：任务置为 `MARK_FAILED`，不触发 get。
- `get` 返回 `errcode != 0`：本次确认失败，若 `verify_count < 3` 则继续延迟确认。
- get 返回缺少目标 `userid`：本次确认失败。
- 三次 get 未确认：任务置为 `VERIFY_TIMEOUT`，只打印日志。
- OTS 当前不存在目标 `external_user_id` 或目标 `follow_user`：记录失败或按后续实现约定补空对象，但不得覆盖其他 `follow_user`。
- 重复 MQ：消费者按 `task_id` 和状态幂等处理。

## 需求

### 功能需求

- **FR-001**：系统 MUST 新增 Spec Kit 文档记录本方案，本阶段不得修改业务代码。
- **FR-002**：后续实现 MUST 在 `fc/common` 的 `EmpExternalTag` 增加 `fc_action` 和 `ots_write_mode`。
- **FR-003**：后续实现 MUST 让 `AppTask` 在旧标签参数校验前先按 `fc_action` 分流。
- **FR-004**：后续实现 MUST 让 `AppTask` 支持 `GET_EXTERNAL_CONTACT`，并通过 `CompleteTagUtil.doGetExternalContact(...)` 调用企微代理函数。
- **FR-005**：后续实现 MUST 让 `AppTask` 在 `CALLER_VERIFY_WRITE` 模式下跳过 FC 内部写 OTS。
- **FR-006**：后续实现 MUST 保持旧调用默认打标签并由 FC 内部写 OTS。
- **FR-007**：后续实现 MUST 在 `kkhc-idc/ai` 新增 `POST /qwTag/markAsync`，接口只落任务和发 MQ。
- **FR-008**：后续实现 MUST 在 MQ 消费者内通过 `rateLimiter` 限速调用打标签 FC。
- **FR-009**：后续实现 MUST 让三次 get 都通过同一个 `AppTask` 的 `GET_EXTERNAL_CONTACT` 模式调用。
- **FR-010**：后续实现 MUST 在 get 确认成功后才更新 `drh_external_user_info`。
- **FR-011**：后续实现 MUST 在 `mark_tag` 返回 `errcode != 0` 时不触发 get。
- **FR-012**：后续实现 MUST 将三次 get 控制在 30 秒窗口内。

## 成功标准

- **SC-001**：本目录包含 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- **SC-002**：文档明确 `AppTask` 的 `MARK_TAG` 和 `GET_EXTERNAL_CONTACT` 双模式。
- **SC-003**：文档明确 `ots_write_mode=CALLER_VERIFY_WRITE` 只由调用侧确认写 OTS。
- **SC-004**：文档明确三次 get 都写在 `kkhc-idc/ai`，但通过 `AppTask` 调用企微代理函数。
- **SC-005**：文档明确旧调用兼容、限流、MQ tag、任务表、失败不拉取和 30 秒内三次确认。

## 假设

- `fc_action=GET_EXTERNAL_CONTACT` 是读取企微外部联系人详情的指定参数值。
- `ots_write_mode=CALLER_VERIFY_WRITE` 是新链路跳过 FC 内部写 OTS 的指定参数值。
- get 确认使用 `tag_id` 判断，不使用 `tag_name`。
- 后续实现可在 `kkhc-idc/ai` 内新增任务表对应 mapper/service/controller/consumer。
- 本阶段只编写文档，不修改代码。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成代码事实确认：`AppTask` 当前默认打标签并写 OTS；`CompleteTagUtil` 已通过 `qw-api-proxy` 访问企微接口；`EmpExternalTag` 来自 `fc/common`。
- 已记录 FC 双模式、旧链路兼容、新链路调用侧确认写 OTS、三次 get 调用方式、MQ tag、任务表和限速方案。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 待后续实现完成后补充实现内容、影响范围、测试命令、测试结果和自检结论。

### D003 - 纠正记录模板

- 触发原因：记录用户补充、测试失败、代码审查发现、参数遗漏或调用顺序问题。
- 修正内容：写清楚旧口径和新口径。
- 文档同步：记录 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 是否已同步。
- 验证结果：记录测试或静态检查结果。
