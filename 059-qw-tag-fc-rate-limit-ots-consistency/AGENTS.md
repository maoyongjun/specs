# 规格执行说明

本目录是企微打标签限流与 OTS 一致性的 Spec Kit 文档。当前阶段已按方案实现代码，并记录数据库建表 SQL；建表 SQL 只写入文档，未直接执行。

## 作用范围

- 规格目录：`C:\workspace\ju-chat\specs\059-qw-tag-fc-rate-limit-ots-consistency`
- 目标接口项目：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`
- 目标函数计算项目：`C:\workspace\ju-chat\fc\qw-tag`
- 目标公共 DTO 项目：`C:\workspace\ju-chat\fc\common`
- 目标企微代理函数：`qw-api-proxy` / `qw-api-proxy-test`
- 目标 OTS 表：`drh_external_user_info`

## 当前目标

- 记录统一接口接收请求、发送 MQ、消费者限速调用企微代理函数的方案。
- 记录 `AppTask` 双模式只作为旧链路兼容保留，新链路不再依赖 `AppTask`。
- 记录新链路三次 get 确认后由 `kkhc-idc/ai` 写 OTS 的一致性方案。
- 保证旧调用不传新增参数时继续由 FC 内部写 OTS。

## 固定实现口径

- 新接口落点：`com.kkhc.idc.ai.controller.QwTagController`。
- 新接口：`POST /qwTag/markAsync`。
- 接口只负责参数校验、落任务、发送 MQ，不直接调用企微代理函数。
- 新链路 MARK 和 GET 直接调用企微代理函数：
  - `mq.delay.topic=test_delay`：`serviceName=service_sys`，`functionName=qw-api-proxy-test`。
  - 其他 topic：`serviceName=ai-service`，`functionName=qw-api-proxy`。
- 企微代理函数入参：
  - `source`
  - `reqType`：MARK 为 `2`，GET 为 `1`。
  - `actionType=1`
  - `url`
  - `body`：仅 MARK 传，使用企微原始 body。
- MARK URL：`https://qyapi.weixin.qq.com/cgi-bin/externalcontact/mark_tag`。
- MARK body：`userid`、`external_userid`、非空 `add_tag`、非空 `remove_tag`。
- GET URL：`https://qyapi.weixin.qq.com/cgi-bin/externalcontact/get?external_userid={urlEncodedExternalUserId}`。
- `EmpExternalTag` 已新增字段，当前只用于旧 AppTask 兼容链路：
  - `fc_action`
  - `ots_write_mode`
- `fc_action` 规则：
  - 缺省或 `MARK_TAG`：打标签。
  - `GET_EXTERNAL_CONTACT`：读取企微外部联系人详情。
- `ots_write_mode` 规则：
  - 缺省：保持旧行为，FC 内部写 OTS。
  - `CALLER_VERIFY_WRITE`：FC 不写 OTS，由调用侧确认后写。
- `AppTask.handleRequest(...)` 必须先判断 `fc_action`，再执行旧标签列表校验。
- `GET_EXTERNAL_CONTACT` 必须通过 `CompleteTagUtil.doGetExternalContact(...)` 和企微代理函数访问企微，不能直接 HTTP 调企微。
- `mark_tag errcode != 0` 时，不触发 get，不写 OTS。
- 三次 get 都写在 `kkhc-idc/ai`，每次直接调用企微代理函数，不通过 `AppTask` 中转。

## MQ 与限速

- Topic 使用现有 `mq.delay.topic`。
- 测试 topic：`test_delay`。
- 生产 topic：`delay`。
- 打标签 MQ tag：`QW_EXTERNAL_TAG_MARK`。
- 确认 MQ tag：`QW_EXTERNAL_TAG_VERIFY`。
- MQ 发送使用 `delayProducerBean.sendTagMessage(...)`。
- `QW_EXTERNAL_TAG_MARK` 初始投递延迟 `10ms`。
- `QW_EXTERNAL_TAG_VERIFY` 第 2/3 次确认延迟 `10s/20s`。
- 消费端使用独立 consumer group，默认 `GID_delay_qw_external_tag`。
- 新增 `MessageType.QW_EXTERNAL_TAG_MARK`，code 为 `136`。
- 新增 `MessageType.QW_EXTERNAL_TAG_VERIFY`，code 为 `137`。
- 打标签企微代理函数限速 key：`ai:qwExternalTagFcRateLimiter`。
- get 企微代理函数限速 key：`ai:qwExternalTagGetFcRateLimiter`。

## 三次 get 门禁

- 第 1 次：`MARK` 消费者收到 `mark_tag errcode=0` 后立即调用企微代理 get。
- 第 2 次：第 1 次未确认时，发送 `QW_EXTERNAL_TAG_VERIFY`，约 `10s` 后消费。
- 第 3 次：第 2 次未确认时，再发送 `QW_EXTERNAL_TAG_VERIFY`，约 `20s` 后消费。
- 三次仍未确认：任务置为 `VERIFY_TIMEOUT`，只打印日志，不继续自动拉取。
- 成功判定必须基于 `tag_id`，不使用 `tag_name`。

## 强制门禁

- 不允许 `GET_EXTERNAL_CONTACT` 被旧的 `add_tag_list/remove_tag_list` 非空校验拦截。
- 不允许 `kkhc-idc/ai` 直接 HTTP 调企微 `externalcontact/get`。
- 不允许 `kkhc-idc/ai` 新链路通过 `async-util/sync-external-tag`、`async-util/cpv-qw-tag-util-test` 或 `fc/qw-tag/AppTask` 中转。
- 不允许 `mark_tag errcode != 0` 后继续 get。
- 不允许 `CALLER_VERIFY_WRITE` 模式下由 FC 写 OTS。
- 不允许旧调用行为被破坏。
- 不允许重复 MQ 导致重复写 OTS 或旧任务覆盖新任务。

## 重点代码位置

- `C:\workspace\ju-chat\fc\common\src\main\java\com\drh\common\dto\EmpExternalTag.java`
- `C:\workspace\ju-chat\fc\qw-tag\src\main\java\com\drh\compute\AppTask.java`
- `C:\workspace\ju-chat\fc\qw-tag\src\main\java\com\drh\util\CompleteTagUtil.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\ai\controller\QwTagController.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\ai\service\impl\QwExternalTagTaskServiceImpl.java`

## 文档维护

- `spec.md` 描述业务场景、需求、边界、成功标准和假设。
- `tasks.md` 记录事实确认、风险门禁、实现任务和测试任务。
- `checklists/requirements.md` 用于验证规格质量和实施就绪度。
- 用户继续补充或纠正方案时，必须同步更新三个文档并追加执行记录。
