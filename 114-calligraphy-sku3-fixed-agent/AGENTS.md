# 规格执行说明

本目录记录 `juzi-service` 书法 `skuId=3` 固定 agent 路由到函数计算 `ai-reply` 的需求和执行过程。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\114-calligraphy-sku3-fixed-agent`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 相关模块：消息入口、route 特殊路由 helper、延迟消息 FC payload 构造、route 单元测试。

## 当前目标

- 对书法 `skuId=3` 复用钢琴雅琪固定 agent 模式。
- 在 `GENERAL_CHAT` 策略命中时固定 `agent_id=7638948127407636514`。
- 继续通过现有 `DelayMessageServiceImpl` 和 `fc.common_function_name` 调用函数计算 `ai-reply`。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、配置来源和测试落点。
- 不允许把空对象、占位 DTO 或未赋值字段当成有效输入继续传递。
- 对跨层可变 DTO、调用后赋值、字段来源不明、旧逻辑副作用，必须先标记风险。
- 发现关键参数依赖后续步骤补齐时，优先在当前层现算现用，或改为显式请求对象；如果会改变业务语义，先确认。
- 任何会改变调用顺序、接口契约、远程调用、MQ 字段、Redis key、数据库结构或外部行为的方案，实施前必须确认业务意图。
- 单元测试不能只验证最终结果；涉及 FC 参数时，必须断言 `agent_id`、`sku_id`、`ai_strategy` 和函数名。

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：`skuId` 来自 `UserInfoDto.getSkuId()`，`msgType` 来自 `JuziMessageDto.getType()`，route 策略来自 snapshot。
- 赋值时机：固定 agent plan 必须在调用 `DelayMessageServiceImpl#sendDelayMessage` 之前完整赋值。
- 占位对象：未命中时返回空，不传递缺少 `aiDecision` 或 `agentDecision` 的 plan。
- 下游读取：`DelayMessageServiceImpl` 实际读取 `RouteExecutionPlanDto.skuId`、`aiDecision.strategy`、`agentDecision.agentId`。
- 旧逻辑保持：私域、Dong 直连、声乐默认、SOP/NOOP、route fallback、人工回复静默、延迟 MQ 保持不变。
- 影响范围：不改 DB、FC 入参契约、MQ 基础字段、Redis key/TTL 或通用 AgentRouter。
- 测试映射：书法命中、跳过、通配规则、非书法不命中、钢琴雅琪回归和 FC payload 均需测试或静态验证。

## 重点代码位置

- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\MessageServiceImpl.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\route\service\YaqiAgentRouteService.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\DelayMessageServiceImpl.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\test\java\com\drh\data\juzi\route\service\YaqiAgentRouteServiceTest.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\test\java\com\drh\data\juzi\service\impl\DelayMessageServiceImplTest.java`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
