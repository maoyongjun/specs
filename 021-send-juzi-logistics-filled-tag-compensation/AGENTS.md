# 规格执行说明

本目录记录 `021-send-juzi-logistics-filled-tag-compensation`，作用范围包含：

- 规格文档：`C:\workspace\ju-chat\specs\021-send-juzi-logistics-filled-tag-compensation`
- 目标代码：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\controller\AiController.java`
- 目标代码：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\impl\AiServiceImpl.java`
- 参考代码：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\ai\service\QwAutoTagService.java`
- 参考代码：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\ai\service\impl\QwAutoTagServiceImpl.java`

## 当前目标

- 在 `AiServiceImpl.sendJuzi` 的物流消息分支中补偿增加 `MqQwTagEnum.Write_Over` 对应的“已填写”标签。
- `QwAutoTag` 的 `tagId` 必须通过 `source + type` 动态查询，不硬编码。
- `invokeFc` 调用参数必须固定为 `externalUserId`、`userId`、`unionId`、`companyId`，其中 `userId = empDto.getQyvxUserId()`，`companyId = empDto.getCompany()`。
- 增加中文日志，便于线上判断补偿是否生效。
- 实现已完成，后续仅需维护文档或回归验证说明。

## 实现约束

- 不新增 endpoint、DTO、配置项或数据库表。
- 不改变 `sendJuziMsg` 对外入参或返回结构。
- 补偿必须是 best-effort，不能阻断物流消息发送主流程。
- `QwAutoTag` 未命中、`tagId` 为空或 `invokeFc` 失败时，只记录日志，不抛出新的业务异常。
- 不把 `Write_Over` 的 `tagId` 写死在代码里。
- `invokeFc` 的测试/正式函数名由 `mq.delay.topic` 决定，`test_delay` 使用测试函数，`delay` 使用正式函数。

## 文档维护

- `spec.md` 描述用户场景、功能需求、边界情况、成功标准和假设。
- `tasks.md` 记录后续实现任务和验证任务。
- `checklists/requirements.md` 用于验证规格质量和实施完整性。
