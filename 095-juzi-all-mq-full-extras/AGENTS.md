# 规格执行说明

本目录记录 `095-juzi-all-mq-full-extras` 功能规格，作用范围仅限当前规格目录及 `C:\workspace\ju-chat\data-RC\juzi` 模块。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\095-juzi-all-mq-full-extras`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi`
- 相关模块：句子 sendResult 回调、原 MQ 发送、juzi_all MQ 发送

## 当前目标

- 修改 `CallbackController.msgCallbackMessageResult`，当需要调用 `sendJuziAllMq` 时，all MQ 的消息体保留原始完整 `payload.extras`。
- 原 `sendMq`、`sendResult` 日志和长 `payload.extras` 截断逻辑保持不变，继续执行 `payloadObj.put("extras", extrasValue.substring(0, 50)+"...")`。
- 不改变 `sendJuziAllMq` 的发送开关、过滤条件、MQ topic/tag/group 或原 `sendMq` 的 self 分流。

## 执行原则

- 原有 `msgCallbackMessageResult` 异步处理、`juzi.flag` 判断、MDC 恢复、异常捕获和立即返回必须保持。
- `payload.extras` 超过 200 字符时，原 MQ body 仍必须被截断到前 50 字符加省略号。
- `sendJuziAllMq` 使用的 body 必须在截断前生成，避免被原 MQ 的截断副作用污染。
- `Dong` 账号原始消息上传 OSS 的逻辑保持不变，仍在截断前执行。
- 不新增接口入参，不修改消费端契约，不修改 `JuziMessageServiceImpl.sendJuziAllMq`。

## 强制门禁

- 参数来源：`msg` 来自回调请求体；`requestId` 来自 MDC；`payload.extras` 来自请求体 `payload.extras`；发送开关来自 `JuziConfig.sendResultAllMqEnabled`。
- 赋值时机：`requestId` 在异步线程内写入；all MQ body 必须在 `payload.extras` 截断前生成；原 MQ body 在截断后生成。
- 占位对象：本次不创建空 DTO、空 JSON 或空 Map 继续下传。
- 下游读取：`sendMq` 接收截断后的 JSON 字符串；`sendJuziAllMq` 接收截断前的 JSON 字符串；`shouldSendJuziAllMq` 读取 `roomTopic`、`room_topic`、`externalUserId`、`external_user_id`。
- 旧逻辑保持：不改变原 MQ 发送、all MQ 开关和过滤、OSS 上传、日志、异常捕获和接口响应。
- 影响范围：只调整 `CallbackController` 中 sendResult 回调生成两个 MQ body 的时机。
- 测试映射：补充 controller 单元测试，断言原 MQ body 截断、all MQ body 保留完整 `extras`。

## 重点代码位置

- `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\controller\CallbackController.java`
- `C:\workspace\ju-chat\data-RC\juzi\src\test\java\com\drh\data\juzi\controller\CallbackControllerTest.java`

## 文档维护

- `spec.md` 描述业务目标、参数来源、边界和验收标准。
- `tasks.md` 记录事实确认、风险门禁、实现任务和验证结果。
- `checklists/requirements.md` 用于确认规格质量和实施就绪度。
- 用户后续调整 `extras` 截断长度、过滤条件或发送顺序时，必须追加 Dxxx 记录并同步更新文档。
