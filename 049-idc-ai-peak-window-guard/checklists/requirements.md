# 规格质量检查清单：自发消息跳过 AiFeign 与高峰期轻量化处理

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-06-04`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目、模块、入口和核心实现位置。
- [x] 明确用户目标、成功标准和非目标。
- [x] 明确新增、修改和禁止改变的行为。
- [x] 明确日志、时间、延迟、幂等、fallback、兼容性或异常处理要求。
- [x] 明确后续实现必须增加测试或静态验证记录。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 或未替换占位内容残留。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖自发消息、高峰期学生消息、非高峰不回归和权限 fallback。
- [x] 边界情况已识别，并明确跳过、兜底、抛错或记录日志的策略。

## 参数完整性门禁

- [x] 已列出关键参数来源和赋值时机。
- [x] 已列出下游读取字段清单。
- [x] 已解释自发消息使用空 `IdSetDto` 的原因和限制。
- [x] 下游读取字段在调用前已赋值，或在当前层现算现用。
- [x] 不存在未处理的调用后赋值风险。
- [x] 外部接口、Feign、OTS、Redis 的关键行为已有下游参数断言方案。
- [x] 修复涉及调用顺序变化，已记录并按用户最新口径实现。

## 实施就绪度

- [x] 实现范围已限定，不扩散到无关模块。
- [x] 不新增数据库表、不新增对外 API、不修改 MQ/Redis/配置契约，除非规格明确要求。
- [x] 已确认旧逻辑中必须保持不变的过滤、异常、日志、延迟和 fallback。
- [x] 每个关键需求至少有一条测试、编译或静态验证任务。
- [x] 单元测试避免真实访问 Redis、OTS、Center、RocketMQ、FC 或外部 HTTP。
- [x] 补充需求或纠正需求时，已同步更新 `spec.md`、`tasks.md` 和 `AGENTS.md`。

## 已验证行为

- [x] 自发消息不调用 `crmService.selectManagerIdAndSaleIdAndCampDateId(...)`。
- [x] 自发消息不调用 `userCheckService.selectUserPermission(...)`。
- [x] 自发消息不调用 `delayMessageService.sendExtendBaseInfoGenerate(...)`。
- [x] 自发消息不调用 `syncTagService.syncTag(...)`。
- [x] 自发手动消息 `source=0` 仍调用 `delayMessageService.removeCache(...)`。
- [x] 高峰期学生消息不调用 `sendExtendBaseInfoGenerate(...)`。
- [x] 高峰期学生消息不调用两处 `syncTagService.syncTag(...)`。
- [x] 非高峰期学生消息保持原有调用。
- [x] `aiFeign.getPermission(...)` 成功时不调用 Center fallback。
- [x] `aiFeign.getPermission(...)` 异常时才调用 Center fallback。
- [x] `07:30` 命中高峰期。

## 备注

- 模块全量回归已通过：`mvn -pl juzi-service -DskipTests=false test`，`Tests run: 98, Failures: 0, Errors: 0, Skipped: 1`，`BUILD SUCCESS`。
- 如后续要把高峰窗口改为运行时配置，需要另开或扩展规格，不能只改硬编码窗口。
