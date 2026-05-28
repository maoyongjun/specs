# 规格质量检查清单：手机号安全字段保存与查询改造

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-05-28`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标工程（`C:\workspace\drh` 和 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai`）、模块（drh-common / drh-pay / drh-endpoint / drh-kk-cms / drh-callback / drh-media-process + ai-common / ai）、入口和核心实现位置。
- [x] 明确用户目标（保存同步写入安全字段、查询使用 MD5、展示使用掩码、前端兼容）、成功标准（8 条 SC）和非目标（不做回填、不改 applet_user / live_user / external_book_question_record）。
- [x] 明确新增（实体持久化字段、createAesInfo 方法含前端兼容、MD5 查询、掩码展示）、修改（Service 保存方法、Mapper 查询条件、VO 返回字段）和禁止改变的行为（原 phone 字段保留、事务不变）。
- [x] 明确空值保护、解密失败处理、FC 调用失败降级、前端明文 / 密文兼容、历史数据 fallback 等异常处理要求。
- [x] 明确必须编写单元测试，覆盖明文输入、密文输入、空值、非法密文四种场景。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 或未替换占位内容残留。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量（8 条 SC）。
- [x] 验收场景覆盖保存（正常 + 明文兼容 + 空值）、查询（正常 + 空值 + 不匹配）、展示（正常 + 历史 NULL）、前端兼容（明文 + 密文）和单元测试五个路径。
- [x] 边界情况已识别，并明确空值跳过、解密失败回退、FC 超时降级、明文兼容 try-catch、历史 NULL 做 fallback、Redis 锁 key 不变的策略。

## 参数完整性门禁

- [x] 已列出关键参数来源和赋值时机：`phone` 来自前端请求（密文或明文），`phoneMask/phoneMd5/phoneAes` 来自 `DataSecurityInvoke.doDsTask()`（远程 FC）。
- [x] 已列出下游读取字段清单：列表读 `phoneMask`，查询读 `phoneMd5`，详情读 `phoneAes`。
- [x] 没有未解释的空 `DataSecurityInput` 或占位参数。
- [x] 下游读取字段在 `createAesInfo()` 调用后赋值，在 `save()` 前已就绪。
- [x] 不存在调用后赋值风险（`createAesInfo()` 同步执行，在 `save()` 前完成）。
- [x] `DataSecurity*` 类已确认存在于 drh-common；ju-chat ai 模块的依赖可用性标记为待确认项。
- [x] `DataSecurityInvoke.doDsTask()` 为远程 FC 调用，已标记超时和失败降级风险。

## 实施就绪度

- [x] 实现范围限定为 2 张表（`H5Order` / `H5OrderDO`、`BookQuestionRecord` / `BookQuestionRecordDO`）在两个工程中的保存、查询、展示链路。
- [x] 不新增数据库表、不新增对外 API、不修改 MQ/Redis/配置契约。
- [x] 已确认旧逻辑中原 `phone` 字段保留、旧查询可并存（渐进式改造）。
- [x] 每个关键需求（FR-001 到 FR-012）都有对应的实现任务和测试任务。
- [x] 单元测试计划覆盖明文输入、密文输入、空值、非法密文四种场景。
- [x] 批量 `in` 查询已标记为暂不改造（TODO）。
- [x] 补充需求或纠正需求时，需同步更新 `spec.md`、`tasks.md` 和 `AGENTS.md`。

## 待确认项

以下项目需在 Phase 1（代码事实确认）阶段解决，未确认前不进入实现：

- [ ] ju-chat 工程 ai 模块是否能访问 drh-common 的 `DataSecurity*` 类（Maven 依赖链确认）。
- [ ] `DataSecurityUtil.aesDecrypt()` 对明文输入的具体行为（抛异常 / 返回 null / 返回乱码）。
- [ ] `DataSecurityInvoke.doDsTask()` 远程 FC 调用的超时时间和失败降级策略。
- [ ] MD5 大小写口径确认。
- [ ] 批量 `in` 查询（`getPhoneResult()`、`getPhoneChannelSet()`）本次是否改造。

## 备注

- 强制门禁未完成前，不进入实现。
- 发现模型未识别的历史代码风险时，先补文档和测试映射，再改代码。
- `drh_applet_user` 已完成整改，`drh_live_user` 和 `drh_external_book_question_record` 由其他同事后续处理，本次不涉及。
