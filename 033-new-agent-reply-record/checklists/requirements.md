# 规格质量检查清单：新 Agent 上线验证结果落库

**用途**：验证需求完整性、参数完整性和实施就绪度
**创建日期**：`2026-05-26`
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目、模块、入口和核心实现位置。
- [x] 明确用户目标、成功标准和非目标。
- [x] 明确新增、修改和禁止改变的行为。
- [x] 明确日志、时间、幂等、fallback、兼容性和异常处理要求。
- [x] 明确实现必须增加测试或静态验证记录。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 或未替换占位内容残留。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖正常路径、边界路径和不回归路径。
- [x] 边界情况已识别，并明确跳过、兜底、抛错或记录日志的策略。

## 参数完整性门禁

- [x] 已列出关键参数来源和赋值时机。
- [x] 已列出下游读取字段清单。
- [x] 没有未解释的 `new XxxDto()`、空 JSON、空 Map 或占位参数。
- [x] 下游读取字段在调用前已赋值，或在当前层现算现用。
- [x] 不存在未处理的调用后赋值风险。
- [x] 外部 Coze 调用、OTS 查询、Redis conversation key 和 MySQL 写入的关键参数已有下游参数断言方案。
- [x] 已完成会改变外部请求和数据库写入的业务语义确认：新 Agent 为影子调用，不发送给学员，不阻断原链路。

## 实施就绪度

- [x] 实现范围已限定，不扩散到无关模块。
- [x] 已明确新增数据库表、Nacos 配置和 Coze SDK 依赖；DDL 当前不执行。
- [x] 已确认旧逻辑中必须保持不变的过滤、异常、日志、延迟和 fallback。
- [x] 每个关键需求至少有一条测试、编译或静态验证任务。
- [x] 单元测试计划避免真实访问 Redis、OTS、Center、RocketMQ、FC 或外部 Coze HTTP，除非规格明确要求联调。
- [x] 补充需求或纠正需求时，需同步更新 `spec.md`、`tasks.md` 和 `AGENTS.md`。

## 配置与数据检查

- [x] Nacos 配置项已明确：`new-agent.verify.enabled`、`new-agent.verify.sales-user-ids`、`new-agent.verify.agent-id`。
- [x] 默认 agentId 已明确：`7638948127407636514`。
- [x] 销售白名单口径已明确：销售企业微信 `user_id`，多个用英文逗号分隔；默认值为 `ZhangFuYi02,liuyongqi02,DengPiaoPiao_1,ShuDie2,LiXin9_1`。
- [x] 表名已明确：`drh_new_agent_reply_record`。
- [x] 幂等口径已明确：`message_id + agent_id` 唯一或等价幂等保护。

## 实现验证

- [x] 已新增配置解析、验证 service 和异常不阻断相关单元测试。
- [x] 已运行目标测试类并通过。
- [x] 已运行 `juzi-service` 编译验证并通过。
- [x] 已静态搜索新包内发送能力调用；新包只通过 `FcInvokeUtils` 获取 Coze JWT，不调用发送学员消息逻辑。
- [x] DDL 提案未执行，生产执行前仍需 DBA 审核。

## 备注

- 强制门禁已完成并进入实现记录阶段。
- 若后续继续调整代码，必须先复核 `fc/delay-mq` 当前 Coze SDK 版本和 `juzi-service` 依赖兼容性。
