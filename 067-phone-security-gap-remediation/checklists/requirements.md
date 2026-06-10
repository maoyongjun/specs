# 规格质量检查清单：手机号安全漏改整改执行

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-06-09`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目、模块、入口和核心实现位置。
- [x] 明确用户目标、成功标准和非目标。
- [x] 明确本规格进入代码修复阶段，会修改实体、Service、Controller、Mapper。
- [x] 明确实现必须补充测试或静态验证记录。
- [x] 明确不合并工具、不做历史回填、不删除明文字段。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 或未替换占位内容残留。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量（`rg` 静态、SQL 条件、响应抽查、编译/单测）。
- [x] 验收范围覆盖精确查询、掩码返回、保存生成安全字段、模糊改精确、逻辑 bug、实体补齐六类。
- [x] 边界情况已识别（手机号为空/非法/已是 MD5/模糊降级/安全字段为空）。

## 参数完整性门禁

- [x] 已列出关键手机号参数来源和赋值时机。
- [x] 已列出下游读取字段清单（`getPhoneMd5`、`*_md5`、`*_mask`、前端字段）。
- [x] 已解释 `setEntity(appletUserDo)` 带明文 `phone` 的占位查询风险及整改。
- [x] 已明确下游读取字段必须在调用前赋值或当前层现算现用。
- [x] 已识别调用后赋值、保存后异步补齐安全字段的风险。
- [x] 已为查询、返回、保存链路给出静态搜索与编译/单测验证方案。
- [x] 模糊搜索降级为精确搜索的业务语义变更已由用户确认并记录。

## 实施就绪度

- [x] 实现范围限定为 `066` 已确认漏改 + 用户六项决策，不扩散到 `048b/051` 的 P2/P3 扩展表。
- [x] 不新增对外 API，不改 MQ/Redis/配置契约（外呼缓存 key 内部归一化已单独记录）。
- [x] 已确认必须保持不变的接口路径、分页、权限、导出和外部明文请求口径。
- [x] 每个关键需求至少有一条测试、编译或静态验证任务。
- [x] 单元测试计划避免真实访问 Redis、OTS、Center、RocketMQ、FC 或外部 HTTP。
- [x] 补充需求或纠正时，已要求同步更新 `spec.md`、`tasks.md` 和 `AGENTS.md`。

## 静态证据清单

- [x] kkhc K1–K9 每项均有 `file:line` 证据（`OrderPageProcessorDataFacade:309`、`OrderGoodReissueDetailServiceImpl:169`、`AppletUserController:73`、`WxComplaintOrderServiceImpl:52`、`LeadsNoqwSendMsgTaskDetailServiceImpl:121`、`UserServiceRecordServiceImpl:99`、`InfluencerServiceImpl:90/163`、`AppletUserDo:40-43`、`OrderBookReissueServiceImpl:145`）。
- [x] drh D1–D10 每项均有 `file:line` 证据（`FrontWorkServiceImpl:106`、`FrontMyClassBaseServiceImpl:171`、`ImportAddressRecordDetailServiceImpl:32`、`MallOrderMapper.xml:41/68`、`MessageTriggerLogServiceImpl:402/412`、`VoiceRobotTaskUserServiceImpl:80`、`VoiceRobotCallbackDetailsServiceImpl` 多处、`VoiceRobotServiceImpl:551/554/583/590`、`UserTriggerSetServiceImpl` 多处、`OutboundTriggerTaskHandle`/`SmsTriggerBaiWuUserCallBackHandler`）。
- [x] `ai` 模块漏改（K2、K5、K9）已单独标记，纠正"ai 为干净基线"的审计盲区。
- [x] 缺失安全字段的三个实体（`lms-common AppletUserDo`、`drh MallOrder`、`drh-kk-cms ImportAddressRecordDetail`）已记录。

## 备注

- 本规格是 `066` 审计的执行落地，修复完成后需回写 `066/tasks.md` Phase 4 对应项的状态。
- 上线节奏必须与 `juzi-service` 历史回填对齐：先回填 `*_md5` 再切精确查询，否则旧数据将查不到。
- 三套加解密工具保留现状属已知技术债，后续如需统一需另立规格。
