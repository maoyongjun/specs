# 规格质量检查清单：sendJuziAllMq 保留完整 extras

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-06-16`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目（`data-RC/juzi`）、模块（sendResult callback）、入口（`CallbackController.msgCallbackMessageResult`）和核心实现位置。
- [x] 明确用户目标（all MQ 保留完整 `extras`）、成功标准（SC-001~004）和非目标（不改 MQ 配置、过滤、接口响应）。
- [x] 明确修改行为（all MQ body 截断前生成）和禁止改变行为（原 MQ 继续截断、OSS 上传、日志、开关过滤）。
- [x] 明确异常处理、异步行为、日志、兼容性和旧逻辑保持要求。
- [x] 明确后续实现必须增加 controller 单元测试或静态验证记录。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 或未替换占位内容残留（执行记录 D002/D003 为待回填模板，属约定保留项）。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖正常路径（all MQ 完整 extras）、边界路径（无 payload/短 extras）、不回归路径（原 MQ 截断和过滤保持）。
- [x] 边界情况已识别，并明确跳过、保持或记录策略。

## 参数完整性门禁

- [x] 已列出关键参数来源和赋值时机（`msg`、`requestId`、`payload.extras`、all MQ 开关）。
- [x] 已列出下游读取字段清单（`sendMq`、`sendJuziAllMq`、`shouldSendJuziAllMq`）。
- [x] 没有未解释的 `new XxxDto()`、空 JSON、空 Map 或占位参数。
- [x] 下游读取字段在调用前已赋值，或在当前层现算现用。
- [x] 不存在未处理的调用后赋值风险；已明确 all MQ body 需在截断前生成。
- [x] MQ body 的关键参数已有下游参数断言方案（fake `JuziMessageService` 捕获两个 body）。
- [x] 修复会改变 all MQ body 内容：已记录，且由用户原始需求授权。

## 实施就绪度

- [x] 实现范围已限定，不扩散到无关模块。
- [x] 不新增数据库表、不新增对外 API、不修改 MQ topic/tag/group、Redis 或配置契约。
- [x] 已确认旧逻辑中必须保持不变的过滤、异常、日志、异步处理、OSS 上传和原 MQ 发送。
- [x] 每个关键需求至少有一条测试、编译或静态验证任务。
- [x] 单元测试计划避免真实访问 Redis、OTS、RocketMQ、FC 或外部 HTTP。
- [x] 补充需求或纠正需求时，会同步更新 `spec.md`、`tasks.md` 和 `AGENTS.md`。

## 备注

- 强制门禁已完成，功能已实现。
- 本次重点风险是可变 `JSONObject` 的截断副作用；已通过 `CallbackControllerTest.sendResultAllMqKeepsOriginalExtrasWhenNormalMqTruncates` 断言两个 MQ body 的 `payload.extras`。
