# 规格执行说明

本目录记录 rocket-mq-consumer 隔天消息按 skuId=4 分流到 ai-reply 的需求、实现任务和验证结果。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\040-app-task-sku4-ai-reply-route`
- 目标项目：`C:\workspace\ju-chat\fc\rocket-mq-consumer`
- 相关模块：`rocket-mq-consumer`、`ai-reply`

## 当前目标

- `AppTask` 接收隔天 MQ 消息后，对 `sku_id` / `skuId` 为 `4` 的消息分流到 `ai-service/ai-reply`。
- 非 `4` 消息保持原有环境变量 `function_name` 路由，继续落到现有 `prod-msg-consumer`。
- 确认样例消息体与 `ai-reply` 的 `EmpExternalDto` 字段兼容，并用单测断言下游 FC 参数。

## 执行原则

- 只修改 `rocket-mq-consumer` 的消息转发路由，不调整上游延迟消息生成、不改 `ai-reply` 业务逻辑。
- 保持 MQ body 原始字段下传；仅在 `skuId` 兼容输入进入 ai-reply 分支时补齐 `sku_id`。
- 外部调用必须通过测试 seam 捕获 `FcInvokeInput`，单测不得真实调用 FC。
- 非 `sku_id=4` 的旧路由、服务名、异步调用方式、日志语义保持不变。

## 强制门禁

- 关键参数：`body` 来自 RocketMQ 事件元素；`sku_id` / `skuId` 来自 `body`；`functionName` 在调用 FC 前解析完成。
- 下游读取：`ai-reply` 入口 `EmpExternalDto` 读取 `redisKey`、`timestamp`、`time_gap`、`day`、`sku_id`、`agent_id`、`external_user_id`、`user_id` 等字段。
- 占位对象：不新增空 DTO、空 JSON 或空 Map 作为有效输入；缺失 `body` 不构造空任务下传。
- 影响范围：只影响 FC functionName 选择和 `skuId` 兼容补齐，不改 MQ topic/tag、Redis、OTS、数据库、FC serviceName。
- 测试映射：新增 `AppTaskTest` 捕获 `FcInvokeInput`，断言函数名和 taskObj 字段。

## 重点代码位置

- `C:\workspace\ju-chat\fc\rocket-mq-consumer\src\main\java\com\drh\mq\service\AppTask.java`
- `C:\workspace\ju-chat\fc\rocket-mq-consumer\src\test\java\com\drh\mq\service\AppTaskTest.java`
- `C:\workspace\ju-chat\fc\ai-reply\src\main\java\com\drh\delay\consumer\dto\EmpExternalDto.java`

## 文档维护

- `spec.md` 描述场景、需求、边界、成功标准和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行结果。
- `checklists/requirements.md` 用于确认规格质量、参数完整性和实施就绪度。
