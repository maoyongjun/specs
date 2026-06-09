# 规格质量检查清单：手机号安全接口补遗与漏改审计

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-06-09`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目、模块、入口和核心实现位置。
- [x] 明确用户目标、成功标准和非目标。
- [x] 明确新增文档行为、后续修复建议和禁止改变的行为。
- [x] 明确后续实现必须增加测试或静态验证记录。
- [x] 明确本规格不新增 DDL、不改业务代码、不覆盖历史规格。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 或未替换占位内容残留。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量。
- [x] 验收范围覆盖已覆盖接口引用、补充接口、确认漏改接口和非 HTTP 风险。
- [x] 边界情况已识别，并明确跳过、兜底、抛错或记录日志的策略。

## 参数完整性门禁

- [x] 已列出关键手机号参数来源和赋值时机。
- [x] 已列出下游读取字段清单。
- [x] 已解释 `setEntity(appletUserDo)` 带明文 `phone` 的占位查询风险。
- [x] 已明确后续修复中下游读取字段必须在调用前赋值，或在当前层现算现用。
- [x] 已识别调用后赋值和保存后异步补齐安全字段的风险。
- [x] 已为外部接口、Feign、回调和数据库查询给出静态验证方案。
- [x] 已记录会改变业务语义的模糊手机号搜索项，需要产品确认。

## 实施就绪度

- [x] 实现范围已限定，不扩散到无关模块。
- [x] 不新增数据库表、不新增对外 API、不修改 MQ/Redis/配置契约，除非后续规格另行确认。
- [x] 已确认旧逻辑中必须保持不变的接口路径、分页、权限、导出和外部明文请求口径。
- [x] 每个关键需求至少有一条测试、编译或静态验证任务。
- [x] 单元测试计划避免真实访问 Redis、OTS、Center、RocketMQ、FC 或外部 HTTP。
- [x] 补充需求或纠正需求时，已要求同步更新 `spec.md`、`tasks.md` 和 `AGENTS.md`。

## 静态证据清单

- [x] `OrderPageProcessorDataFacade` app/lms 明文返回证据已记录。
- [x] `OrderGoodReissueDetailServiceImpl` 明文查询证据已记录。
- [x] `AppletUserController.listByEntity|getOneByCondition` 和 `LeadsController.select` Feign 链路证据已记录。
- [x] `WxComplaintOrderServiceImpl` 明文保存/查询证据已记录。
- [x] `LeadsNoqwSendMsgTaskDetailServiceImpl` 明文查询证据已记录。
- [x] `UserServiceRecordServiceImpl` 明文查询证据已记录。
- [x] `FrontWorkServiceImpl`、`FrontMyClassBaseServiceImpl`、`MallOrderMapper.xml`、`MessageTriggerLogServiceImpl` 风险证据已记录。

## 备注

- 本规格完成的是文档审计和后续修复计划，不代表漏改项已经修复。
- 进入代码修复前，应先处理模糊手机号搜索的业务确认。
