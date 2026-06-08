# 功能规格：企微打标签限流与 OTS 一致性

**功能目录**：`059-qw-tag-fc-rate-limit-ots-consistency`  
**创建日期**：`2026-06-08`  
**状态**：Implemented
**输入**：用户要求实现企微打标签限流与 OTS 一致性方案，并同步更新 Spec Kit 文档、任务状态和建表 SQL。

## 背景

- 当前问题：多处调用打标签函数计算，容易触发函数计算限流；同时 `mark_tag` 成功和我方 `drh_external_user_info` 标签写入之间存在一致性风险。
- 当前行为：`fc/qw-tag/AppTask` 默认执行企微 `externalcontact/mark_tag` 并在函数内更新 OTS；`CompleteTagUtil.doResponseTag(...)` 通过 `qw-api-proxy` 访问企微接口。
- 目标行为：`kkhc-idc/ai` 新接口收请求后只落任务并发 MQ，MQ 消费者限速直接调用企微代理函数 `qw-api-proxy/qw-api-proxy-test` 执行 `mark_tag`；打标签成功后，`kkhc-idc/ai` 再直接通过同一个企微代理函数执行 `externalcontact/get`，三次确认成功后由调用侧写 `drh_external_user_info`。
- 非目标：本次不直接执行数据库建表 SQL，不调整线上 MQ 权限，不部署函数计算。

## 最终方案

| 事项 | 决策 |
|---|---|
| 统一入口 | 新增接口放在 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai`，Controller 为 `com.kkhc.idc.ai.controller.QwTagController`，接口 `POST /qwTag/markAsync`。 |
| 新链路代理调用 | `kkhc-idc/ai` 消费者直接调用 `qw-api-proxy/qw-api-proxy-test`，不再通过 `fc/qw-tag/AppTask` 中转。 |
| 旧调用兼容 | 已实现的 `AppTask` 双模式代码保留，供旧链路兼容使用；新链路不依赖 `fc_action/ots_write_mode`。 |
| 新链路写入 | 新链路 `mark_tag` 成功后由 `kkhc-idc/ai` 三次 get 确认，确认成功后写 `drh_external_user_info`。 |
| get 调用方式 | 三次 get 逻辑写在 `kkhc-idc/ai`，每次都直接调用企微代理函数，不能直接 HTTP 调企微 get。 |
| 限流位置 | `QW_EXTERNAL_TAG_MARK` 消费者内先进入 `rateLimiter`，再调用企微代理函数。 |
| 失败拉取 | `mark_tag` 返回 `errcode != 0` 时直接失败并打印日志，不触发 get。 |

## 用户场景与测试

### 用户故事 1 - 接口收敛并削峰调用 FC（优先级：P1）

业务方调用统一接口提交打标签请求，接口不直接调用函数计算，而是落任务并发送 MQ，由消费者限速调用企微代理函数。

**独立测试**：构造合法请求，验证接口写入任务、发送 `QW_EXTERNAL_TAG_MARK` MQ，并立即返回 `taskId` 和 `QUEUED`，不直接调用 FC。

**验收场景**：

1. **Given** 合法打标签请求，**When** 调用 `POST /qwTag/markAsync`，**Then** 返回 `QUEUED` 且生成 `taskId`。
2. **Given** MQ 消费者处理任务，**When** 调用企微代理函数打标签，**Then** 调用必须包在 `rateLimiter` 内。
3. **Given** 重复请求命中同一个幂等 key，**When** 再次提交，**Then** 不重复创建有效任务。

### 用户故事 2 - 新链路绕过 AppTask 且旧链路保持兼容（优先级：P1）

旧调用不传新增参数时，`AppTask` 仍按原逻辑打标签并写 OTS；新链路不再通过 `AppTask`，MARK 和 GET 都直接调用企微代理函数。

**独立测试**：验证新链路调用 `qw-api-proxy/qw-api-proxy-test` 的代理入参，且旧 `AppTask` 调用行为不被回滚。

**验收场景**：

1. **Given** 未传 `fc_action` 和 `ots_write_mode`，**When** 调用 `AppTask`，**Then** 执行打标签并保持旧的 FC 内部 OTS 写入。
2. **Given** 新链路 MARK 消费，**When** 调用企微代理函数，**Then** 代理入参为 `source/reqType=2/actionType=1/url/body`，body 使用企微原始 `userid/external_userid/add_tag/remove_tag`。
3. **Given** 新链路 GET 确认，**When** 调用企微代理函数，**Then** 代理入参为 `source/reqType=1/actionType=1/url`，不经过 `AppTask`。

### 用户故事 3 - 三次 get 确认后写 OTS（优先级：P1）

`mark_tag` 成功后，系统必须在 30 秒内最多三次通过企微代理函数 get 确认企微标签已生效，确认后再更新 `drh_external_user_info`。

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

## AppTask 旧链路兼容说明

- 以下改造已保留用于旧链路兼容；`kkhc-idc/ai` 新链路不再通过 `AppTask` 中转。
- `fc/common` 入参 DTO `com.drh.common.dto.EmpExternalTag` 已新增：
  - `fc_action`：函数动作。缺省或 `MARK_TAG` 表示打标签；`GET_EXTERNAL_CONTACT` 表示读取企微外部联系人详情。
  - `ots_write_mode`：OTS 写入模式。缺省表示 FC 内部写；`CALLER_VERIFY_WRITE` 表示调用方确认后写。
- `AppTask.handleRequest(...)` 已先判断 `fc_action`，再执行旧的 `add_tag_list/remove_tag_list` 非空校验。
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
- `fc_action` 为其他未知非空值时，返回参数错误 JSON，不写 OTS。

## 新链路企微代理调用明细

- `kkhc-idc/ai` 新链路直接构造企微代理函数入参并调用 `FcInvokeUtils.doSyncTaskReturnJSONObj(...)`。
- 测试环境：`mq.delay.topic=test_delay` 时，`serviceName=service_sys`，`functionName=qw-api-proxy-test`。
- 其他环境：`serviceName=ai-service`，`functionName=qw-api-proxy`。
- MARK URL：`https://qyapi.weixin.qq.com/cgi-bin/externalcontact/mark_tag`。
- MARK body 使用企微原始格式：
  - `userid`
  - `external_userid`
  - `add_tag`：待新增标签 ID 数组，非空时传。
  - `remove_tag`：待移除标签 ID 数组，非空时传。
- GET URL：`https://qyapi.weixin.qq.com/cgi-bin/externalcontact/get?external_userid={urlEncodedExternalUserId}`。
- 企微代理函数入参：
  - `source=source`
  - `actionType=1`
  - `reqType=2` 用于 MARK，`reqType=1` 用于 GET。
  - `url`
  - `body`：仅 MARK 传。

## idc-ai 调用方式

- 新接口：
  - 模块：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`
  - Controller：`com.kkhc.idc.ai.controller.QwTagController`
  - 接口：`POST /qwTag/markAsync`
  - 行为：校验参数、落任务、发送 MQ，立即返回 `taskId` 和 `QUEUED`。
- 打标签企微代理入参：
  - `source`
  - `reqType=2`
  - `actionType=1`
  - `url=https://qyapi.weixin.qq.com/cgi-bin/externalcontact/mark_tag`
  - `body.userid`
  - `body.external_userid`
  - `body.add_tag`
  - `body.remove_tag`
- get 企微代理入参：
  - `source`
  - `reqType=1`
  - `actionType=1`
  - `url=https://qyapi.weixin.qq.com/cgi-bin/externalcontact/get?external_userid={urlEncodedExternalUserId}`
- 企微代理 FC 路由：
  - `mq.delay.topic=test_delay` 时 `serviceName=service_sys`、`functionName=qw-api-proxy-test`
  - 其他情况 `serviceName=ai-service`、`functionName=qw-api-proxy`

## 数据与 MQ

### 新建表

- `drh_qw_external_tag_task`：任务主表。
- `drh_qw_external_tag_task_log`：任务过程日志表。

### 建表 SQL

```sql
CREATE TABLE `drh_qw_external_tag_task` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `task_id` varchar(64) NOT NULL COMMENT '任务ID',
  `idempotent_key` varchar(191) NOT NULL COMMENT '幂等键',
  `external_user_id` varchar(128) NOT NULL COMMENT '企微外部联系人ID',
  `user_id` varchar(128) NOT NULL COMMENT '企微成员userid',
  `union_id` varchar(128) NOT NULL DEFAULT '' COMMENT '用户unionId',
  `source` int NOT NULL COMMENT '企业/来源标识',
  `add_tag_list` text COMMENT '待新增标签ID列表，逗号分隔',
  `remove_tag_list` text COMMENT '待移除标签ID列表，逗号分隔',
  `fc_action` varchar(32) NOT NULL DEFAULT 'MARK_TAG' COMMENT 'FC动作',
  `ots_write_mode` varchar(32) NOT NULL DEFAULT 'CALLER_VERIFY_WRITE' COMMENT 'OTS写入模式',
  `status` varchar(32) NOT NULL DEFAULT 'INIT' COMMENT '任务状态',
  `fc_errcode` int DEFAULT NULL COMMENT '打标签FC返回errcode',
  `fc_errmsg` varchar(512) NOT NULL DEFAULT '' COMMENT '打标签FC返回errmsg',
  `fc_response` mediumtext COMMENT '打标签FC完整响应',
  `verify_count` tinyint NOT NULL DEFAULT '0' COMMENT 'get确认次数',
  `next_verify_time` datetime(3) DEFAULT NULL COMMENT '下次确认时间',
  `last_get_response` mediumtext COMMENT '最近一次get完整响应',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_id` (`task_id`),
  UNIQUE KEY `uk_idempotent_key` (`idempotent_key`),
  KEY `idx_status_next_verify_time` (`status`, `next_verify_time`),
  KEY `idx_external_user_user` (`external_user_id`, `user_id`),
  KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='企微外部联系人打标签任务表';

CREATE TABLE `drh_qw_external_tag_task_log` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `task_id` varchar(64) NOT NULL COMMENT '任务ID',
  `event_type` varchar(64) NOT NULL COMMENT '事件类型',
  `status_before` varchar(32) NOT NULL DEFAULT '' COMMENT '变更前状态',
  `status_after` varchar(32) NOT NULL DEFAULT '' COMMENT '变更后状态',
  `verify_count` tinyint NOT NULL DEFAULT '0' COMMENT '当前get确认次数',
  `fc_action` varchar(32) NOT NULL DEFAULT '' COMMENT 'FC动作',
  `errcode` int DEFAULT NULL COMMENT '错误码',
  `errmsg` varchar(512) NOT NULL DEFAULT '' COMMENT '错误信息',
  `request_payload` mediumtext COMMENT '请求内容',
  `response_payload` mediumtext COMMENT '响应内容',
  `remark` varchar(512) NOT NULL DEFAULT '' COMMENT '备注',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_task_id` (`task_id`),
  KEY `idx_task_event` (`task_id`, `event_type`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='企微外部联系人打标签任务日志表';
```

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
- MQ 发送使用 `delayProducerBean.sendTagMessage(...)`。
- `QW_EXTERNAL_TAG_MARK` 初始投递时间为 `System.currentTimeMillis() + 10L`。
- `QW_EXTERNAL_TAG_VERIFY` 投递时间分别为 `System.currentTimeMillis() + 10_000L`、`System.currentTimeMillis() + 20_000L`。
- 消费端使用独立 consumer group，默认 `GID_delay_qw_external_tag`。
- tag：`QW_EXTERNAL_TAG_MARK`，用于打标签任务。
- tag：`QW_EXTERNAL_TAG_VERIFY`，用于第 2、第 3 次 get 确认。
- `MessageType`：新增 `QW_EXTERNAL_TAG_MARK`，建议 code 使用 `136`。
- `MessageType`：新增 `QW_EXTERNAL_TAG_VERIFY`，code 使用 `137`。

### 限速

- 打标签企微代理函数限速 key：`ai:qwExternalTagFcRateLimiter`。
- get 企微代理函数限速 key：`ai:qwExternalTagGetFcRateLimiter`。
- 限速放在 MQ 消费者内，接口层不直接调用 FC。

## 三次 get 确认

- 三次 get 编排写在 `kkhc-idc/ai` 的 `QwExternalTagTaskService`。
- 每次 get 都由 `kkhc-idc/ai` 直接调用企微代理函数 `qw-api-proxy/qw-api-proxy-test`，不能直接 HTTP 调企微，也不再通过 `fc/qw-tag/AppTask` 中转。
- 第 1 次：`QW_EXTERNAL_TAG_MARK` 消费者收到 `mark_tag` 代理函数 `errcode=0` 后立即调用企微代理 get。
- 第 2 次：第 1 次未确认时，发送 `QW_EXTERNAL_TAG_VERIFY` 延迟 MQ，约 `10s` 后消费并调用企微代理 get。
- 第 3 次：第 2 次未确认时，再发送 `QW_EXTERNAL_TAG_VERIFY`，约 `20s` 后消费并调用企微代理 get。
- 第 3 次仍未确认：状态置为 `VERIFY_TIMEOUT`，只打印日志，不继续自动拉取。

## get 成功判定

- 企微代理 get 返回 `errcode=0`。
- 返回体中存在目标 `follow_user`。
- 目标 `follow_user.userid == 请求 user_id`。
- `add_tag_list` 中所有 `tag_id` 都存在于目标 `follow_user.tags`。
- `remove_tag_list` 中所有 `tag_id` 都不存在于目标 `follow_user.tags`。
- 满足以上条件后，`kkhc-idc/ai` 合并更新 `drh_external_user_info.follow_user` 中对应 `userid` 的 `tags`。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `external_user_id`：来自 `POST /qwTag/markAsync` 请求；接口落任务前校验；MARK body 和 GET URL 构造前写入代理函数入参。
  - `user_id`：来自请求；用于 `mark_tag` body 和 get 后定位 `follow_user`。
  - `source`：来自请求；用于企微代理函数选择企业身份。
  - `reqType`：MARK 固定 `2`，GET 固定 `1`。
  - `actionType`：MARK 和 GET 都固定 `1`。
  - `body`：仅 MARK 传，使用企微原始 `userid/external_userid/add_tag/remove_tag`。
  - `fc_action/ots_write_mode`：仅保留在任务表和旧 AppTask 兼容链路中，新链路不传给 AppTask。
  - `verify_count`：来自 `drh_qw_external_tag_task`；每次 get 前后更新。
- 下游读取字段清单：
  - `qw-api-proxy/qw-api-proxy-test` 读取 `source`、`reqType`、`url`、`body`、`actionType`。
  - `AppTask.handleRequest(...)`、`CompleteTagUtil.doResponseTag(...)`、`CompleteTagUtil.doGetExternalContact(...)` 只属于旧链路兼容路径，新链路不依赖。
  - `QwExternalTagTaskService.verifyAndUpdateOts(...)` 读取任务表的目标标签、get 返回的 `follow_user.tags` 和 OTS 当前 `follow_user`。
- 空对象 / 占位对象风险：
  - 新链路 MARK body 不能传空标签变更，`add_tag_list` 和 `remove_tag_list` 不能同时为空。
  - GET URL 必须对 `external_user_id` 做 URL encode。
  - 任务表中 `add_tag_list` 和 `remove_tag_list` 不能同时为空。
- 调用顺序风险：
  - 必须先 `mark_tag` 成功，再 get 确认，再写 OTS。
  - `mark_tag` 失败不能触发 get。
  - 第 2、第 3 次 get 只能由延迟 MQ 触发，不能在同一线程 sleep 等待。
- 旧逻辑保持：
  - 旧调用不传 `fc_action` 和 `ots_write_mode` 时，`AppTask` 行为保持兼容。
  - 旧 AppTask 函数名 `cpv-qw-tag-util-test`、`sync-external-tag` 保持，但 `kkhc-idc/ai` 新链路不再调用。
  - `CompleteTagUtil.invokeQwProxyFc(...)` 继续作为旧 AppTask 访问企微接口的代理入口。
- 需要用户确认的设计选择：
  - 已确认：新链路 MARK 和 GET 直接调用企微代理函数，不通过 `fc/qw-tag/AppTask`。
  - 已确认：已实现的 AppTask 双模式兼容代码不主动回滚，避免影响旧调用。

## 边界情况

- 新链路代理函数选择：`mq.delay.topic=test_delay` 走 `service_sys/qw-api-proxy-test`，其他走 `ai-service/qw-api-proxy`。
- 新链路 MARK body 中 `add_tag/remove_tag` 仅非空时传。
- 新链路 GET URL 的 `external_userid` 必须 URL encode。
- 旧 AppTask 兼容：`fc_action` 缺省或空按 `MARK_TAG` 处理。
- 旧 AppTask 兼容：`fc_action=GET_EXTERNAL_CONTACT` 且缺少 `external_user_id` 或 `source` 时返回参数错误，不写 OTS。
- 旧 AppTask 兼容：`fc_action=MARK_TAG` 且 `add_tag_list/remove_tag_list` 同时为空时保持旧校验，不处理。
- `mark_tag` 返回 `errcode != 0`：任务置为 `MARK_FAILED`，不触发 get。
- `get` 返回 `errcode != 0`：本次确认失败，若 `verify_count < 3` 则继续延迟确认。
- get 返回缺少目标 `userid`：本次确认失败。
- 三次 get 未确认：任务置为 `VERIFY_TIMEOUT`，只打印日志。
- OTS 当前不存在目标 `external_user_id` 或目标 `follow_user`：记录失败或按后续实现约定补空对象，但不得覆盖其他 `follow_user`。
- 重复 MQ：消费者按 `task_id` 和状态幂等处理。

## 需求

### 功能需求

- **FR-001**：系统 MUST 保留 Spec Kit 文档记录本方案，并包含建表 SQL、MQ、限流、三次 get 和代理函数调用口径。
- **FR-002**：旧链路兼容代码 MUST 保持 `fc/common` 的 `EmpExternalTag.fc_action/ots_write_mode`。
- **FR-003**：旧链路兼容代码 MUST 让 `AppTask` 在旧标签参数校验前先按 `fc_action` 分流。
- **FR-004**：旧链路兼容代码 MUST 让 `AppTask` 支持 `GET_EXTERNAL_CONTACT`，并通过 `CompleteTagUtil.doGetExternalContact(...)` 调用企微代理函数。
- **FR-005**：旧链路兼容代码 MUST 让 `AppTask` 在 `CALLER_VERIFY_WRITE` 模式下跳过 FC 内部写 OTS。
- **FR-006**：旧链路兼容代码 MUST 保持旧调用默认打标签并由 FC 内部写 OTS。
- **FR-007**：实现 MUST 在 `kkhc-idc/ai` 新增 `POST /qwTag/markAsync`，接口只落任务和发 MQ。
- **FR-008**：实现 MUST 在 MQ 消费者内通过 `rateLimiter` 限速调用企微代理函数。
- **FR-009**：实现 MUST 让 MARK 和三次 GET 都直接调用 `qw-api-proxy/qw-api-proxy-test`，不得通过 `fc/qw-tag/AppTask` 中转。
- **FR-010**：实现 MUST 在 get 确认成功后才更新 `drh_external_user_info`。
- **FR-011**：实现 MUST 在 `mark_tag` 返回 `errcode != 0` 时不触发 get。
- **FR-012**：实现 MUST 将三次 get 控制在 30 秒窗口内。

## 成功标准

- **SC-001**：本目录包含 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- **SC-002**：文档明确 `AppTask` 的 `MARK_TAG` 和 `GET_EXTERNAL_CONTACT` 双模式仅作为旧链路兼容保留。
- **SC-003**：文档明确新链路绕过 `AppTask`，不再依赖 `ots_write_mode=CALLER_VERIFY_WRITE`。
- **SC-004**：文档明确 MARK 和三次 get 都写在 `kkhc-idc/ai`，并直接调用企微代理函数。
- **SC-005**：文档明确旧调用兼容、限流、MQ tag、任务表、失败不拉取和 30 秒内三次确认。

## 假设

- `fc_action=GET_EXTERNAL_CONTACT` 是旧 AppTask 兼容链路读取企微外部联系人详情的指定参数值。
- `ots_write_mode=CALLER_VERIFY_WRITE` 是旧 AppTask 兼容链路跳过 FC 内部写 OTS 的指定参数值。
- 新链路直接使用 `qw-api-proxy` 入参结构：`source`、`reqType`、`url`、`body`、`actionType`。
- get 确认使用 `tag_id` 判断，不使用 `tag_name`。
- 本次不主动回滚已完成的 AppTask 兼容代码。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成代码事实确认：`AppTask` 当前默认打标签并写 OTS；`CompleteTagUtil` 已通过 `qw-api-proxy` 访问企微接口；`EmpExternalTag` 来自 `fc/common`。
- 已记录 FC 双模式、旧链路兼容、新链路调用侧确认写 OTS、三次 get 调用方式、MQ tag、任务表和限速方案。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 已实现 `EmpExternalTag.fc_action/ots_write_mode`、`AppTask` 双模式、`CompleteTagUtil.doGetExternalContact(...)`。
- 已实现 `kkhc-idc/ai` 的 `POST /qwTag/markAsync`、任务/日志 DO 与 Mapper、任务服务、独立 delay consumer group、`QW_EXTERNAL_TAG_MARK` 和 `QW_EXTERNAL_TAG_VERIFY` 消费链路。
- 已实现 MARK MQ 10ms 投递、MARK/GET 企微代理函数限速调用、三次 get 确认、`mark_tag errcode != 0` 不拉取、确认成功后更新 `drh_external_user_info.follow_user`。
- 编译验证：
  - `C:\workspace\ju-chat\fc`：`mvn -pl common,qw-tag -am -DskipTests compile`，结果 `BUILD SUCCESS`。
  - `C:\workspace\ju-chat\kkhc\kkhc-idc`：`mvn -pl ai -am -DskipTests compile`，结果 `BUILD SUCCESS`。
- 未新增自动化单测；发布前仍建议补齐 FC 双模式、MQ 消费、三次 get 和 OTS 更新的单元/集成测试。

### D003 - MQ 口径纠正记录

- 触发原因：用户补充 MQ 必须使用 `delayProducerBean.sendTagMessage`，初始延迟 `10ms`。
- 修正内容：`QW_EXTERNAL_TAG_MARK` 使用 `System.currentTimeMillis() + 10L` 投递；`QW_EXTERNAL_TAG_VERIFY` 仍保持 10s/20s；消费者使用独立 group `GID_delay_qw_external_tag`。
- 文档同步：已同步 `spec.md`、`tasks.md`、`checklists/requirements.md`。
- 验证结果：目标模块编译通过。

### D004 - 建表 SQL 记录

- 已在 `spec.md` 写入 `drh_qw_external_tag_task` 和 `drh_qw_external_tag_task_log` 的完整建表 SQL。
- 本次只写入文档和代码模型，未执行数据库建表。

### D005 - 新链路直连企微代理函数纠正记录

- 触发原因：用户明确要求新链路 MARK 和 GET 不再通过 `fc/qw-tag/AppTask` 中转，改为直接调用 `invokeQwProxyFc` 对应的企微代理函数。
- 修正内容：`kkhc-idc/ai` 的 MARK 消费和三次 GET 确认改为直接构造 `qw-api-proxy/qw-api-proxy-test` 入参；测试 topic `test_delay` 走 `service_sys/qw-api-proxy-test`，其他 topic 走 `ai-service/qw-api-proxy`。
- 废止点：新链路不再调用 `async-util/sync-external-tag`、`async-util/cpv-qw-tag-util-test`，不再向 `AppTask` 传 `fc_action/ots_write_mode/add_tag_list/remove_tag_list`。
- 保留点：已实现的 `AppTask` 双模式兼容代码不主动回滚，避免影响旧调用。
- 验证结果：
  - `C:\workspace\ju-chat\kkhc\kkhc-idc`：`mvn -pl ai -am -DskipTests compile`，结果 `BUILD SUCCESS`。
  - 静态验证：`QwExternalTagTaskServiceImpl` 不再出现 `async-util`、`sync-external-tag`、`cpv-qw-tag-util-test` 或 `AppTask` 引用。
  - 静态验证：MARK/GET 代理入参构造包含 `source`、`reqType`、`actionType`、URL 和 MARK body。
- 修正内容：写清楚旧口径和新口径。
- 文档同步：记录 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 是否已同步。
- 验证结果：记录测试或静态检查结果。
