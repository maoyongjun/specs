# 需求检查清单：企微打标签限流与 OTS 一致性

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-06-08`  
**功能**：[spec.md](../spec.md)

## 文档完整性

- [x] 已创建规格目录 `059-qw-tag-fc-rate-limit-ots-consistency`。
- [x] 已包含 `spec.md`。
- [x] 已包含 `tasks.md`。
- [x] 已包含 `AGENTS.md`。
- [x] 已包含 `checklists/requirements.md`。
- [x] 已明确本阶段只编写文档，不修改业务代码。

## 内容质量

- [x] 明确目标项目、模块、入口和核心实现位置。
- [x] 明确用户目标、成功标准和非目标。
- [x] 明确新增、修改和禁止改变的行为。
- [x] 明确日志、时间、延迟、幂等、fallback、兼容性和异常处理要求。
- [x] 明确后续实现必须增加测试或静态验证记录。

## FC 双模式

- [x] 明确 `EmpExternalTag` 需要新增 `fc_action`。
- [x] 明确 `EmpExternalTag` 需要新增 `ots_write_mode`。
- [x] 明确 `fc_action` 缺省或 `MARK_TAG` 表示打标签。
- [x] 明确 `fc_action=GET_EXTERNAL_CONTACT` 表示读取企微外部联系人详情。
- [x] 明确 `ots_write_mode=CALLER_VERIFY_WRITE` 时 FC 不写 OTS。
- [x] 明确旧调用不传新增参数时，FC 保持内部写 OTS。
- [x] 明确 `AppTask` 必须先判断 `fc_action`，再执行旧标签列表校验。

## get 调用方式

- [x] 明确三次 get 逻辑写在 `kkhc-idc/ai`。
- [x] 明确每次 get 都通过同一个 `fc/qw-tag/AppTask` 调用。
- [x] 明确 get 模式入参为 `fc_action=GET_EXTERNAL_CONTACT`。
- [x] 明确 `kkhc-idc/ai` 不能直接 HTTP 调企微 get。
- [x] 明确 `CompleteTagUtil.doGetExternalContact(...)` 通过 `invokeQwProxyFc(...)` 调用企微代理函数。
- [x] 明确 get URL 为 `https://qyapi.weixin.qq.com/cgi-bin/externalcontact/get?external_userid={externalUserId}`。
- [x] 明确 get 使用 `QwFcProxyInput.reqType=1`、`actionType=1`。

## MQ 与限流

- [x] 明确接口只落任务和发 MQ，不直接调用 FC。
- [x] 明确 topic 使用现有 `mq.delay.topic`。
- [x] 明确测试 topic 为 `test_delay`，生产 topic 为 `delay`。
- [x] 明确打标签 tag 为 `QW_EXTERNAL_TAG_MARK`。
- [x] 明确确认 tag 为 `QW_EXTERNAL_TAG_VERIFY`。
- [x] 明确新增 `MessageType.QW_EXTERNAL_TAG_MARK`，建议 code 为 `136`。
- [x] 明确打标签 FC 限速 key 为 `ai:qwExternalTagFcRateLimiter`。
- [x] 明确 get FC 限速 key 为 `ai:qwExternalTagGetFcRateLimiter`。

## 一致性与失败处理

- [x] 明确 `mark_tag errcode=0` 后才触发 get。
- [x] 明确 `mark_tag errcode != 0` 不触发 get，不写 OTS。
- [x] 明确第 1 次 get 在 `MARK` 消费者内立即执行。
- [x] 明确第 2 次 get 通过延迟 MQ 约 `10s` 后执行。
- [x] 明确第 3 次 get 通过延迟 MQ 约 `20s` 后执行。
- [x] 明确三次未确认置为 `VERIFY_TIMEOUT`，只打印日志。
- [x] 明确 get 成功判定使用 `tag_id`，不使用 `tag_name`。
- [x] 明确确认成功后才更新 `drh_external_user_info`。

## 新表与状态

- [x] 明确任务主表 `drh_qw_external_tag_task`。
- [x] 明确任务日志表 `drh_qw_external_tag_task_log`。
- [x] 明确主表核心字段。
- [x] 明确任务状态枚举。
- [x] 明确过程日志记录 FC、get、OTS 和错误详情。

## 后续测试门禁

- [ ] 后续实现需测试 `AppTask` 默认打标签路径保持兼容。
- [ ] 后续实现需测试 `CALLER_VERIFY_WRITE` 路径不写 OTS。
- [ ] 后续实现需测试 `GET_EXTERNAL_CONTACT` 路径不校验标签列表。
- [ ] 后续实现需测试 `idc-ai` 打标签消费者 FC 入参。
- [ ] 后续实现需测试 `idc-ai` 三次确认 FC 入参。
- [ ] 后续实现需测试 `60111` 不触发 get。
- [ ] 后续实现需测试三次未确认置为 `VERIFY_TIMEOUT`。
- [ ] 后续实现需测试确认成功后只更新目标 `external_user_id + userid` 的标签。

## 备注

- 强制门禁未完成前，不进入实现。
- 本清单当前只确认文档阶段完成；后续代码实现后需要更新未完成测试项。
