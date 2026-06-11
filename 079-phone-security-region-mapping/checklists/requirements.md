# 规格质量检查清单：手机号安全字段与地区映射

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-06-11`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目、模块、入口和核心实现位置。
- [x] 明确用户目标、成功标准和非目标。
- [x] 明确新增表、字段、索引和禁止保存 `segment` 的行为。
- [x] 明确兼容性、日志、幂等、fallback 和异常处理要求。
- [x] 明确后续实现必须增加测试或静态验证记录。

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
- [x] 数据库写入关键参数已有下游参数断言方案。
- [x] 本次会新增数据库表，已记录字段和索引；不会新增对外接口、MQ、Redis key 或 Feign 契约。
- [x] 已记录并完成用户确认：`drh_phone_security_region` 不保存 `segment`。

## 实施就绪度

- [x] 实现范围已限定，不扩散到无关模块。
- [x] 不新增对外 API、不修改 MQ/Redis/配置契约。
- [x] 已确认旧逻辑中必须保持不变的空值返回、号段查询、`city/province` 赋值、异常和日志行为。
- [x] 每个关键需求至少有一条测试、编译或静态验证任务。
- [x] 单元测试计划避免真实访问 Redis、OTS、Center、RocketMQ、FC 或外部 HTTP，除非规格明确要求联调。
- [x] 补充需求或纠正需求时，已同步更新 `spec.md`、`tasks.md` 和 `AGENTS.md`。

## DDL 检查

- [x] `drh_phone_security_region` DDL 包含 `phone_mask`、`phone_md5`、`phone_aes`、`province`、`city`。
- [x] `drh_phone_security_region` DDL 不包含 `segment`。
- [x] `drh_phone_security_region` DDL 不包含明文 `phone`。
- [x] DDL 包含 `uk_phone_md5` 唯一索引。
- [x] DDL 包含 `idx_province_city` 普通索引。

## 备注

- 强制门禁未完成前，不进入业务代码实现。
- 实现阶段若选择 Redis 缓存、保存 `segment` 或新增对外接口，必须先更新规格并追加纠正记录。
