# 任务清单：私域 AI Agent「请勿打扰」标签跳过回复

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查需求与 `AGENTS.md`：目标项目 `data-RC/juzi-service`，业务链路为私域 AI Agent 回复分支。
- [x] T002 确认真实入口：`MessageServiceImpl#handlePrivateDomainAiIfMatched`（401-428 行），下发回复经 `delayMessageService.sendPrivateDomainAiMessage`；测试落点参考 `MessageServiceImplManualReplySilenceTest`。
- [x] T003 确认关键参数：`externalUserId`、`userId` 为私域分支入参且调用前已赋值；标签来源 OTS `drh_external_user_info`，复用 `OtsUtil.selectExternalUserTags`，读取 `FollowUser.Tag.tag_name`。
- [x] T004 确认配置/契约影响：仅新增一次 OTS 读取（复用既有静态方法），不涉及新 Redis key、MQ topic/tag、Feign/FC 新接口或数据库写入。私域默认 agentId `7644079727246065664` 来自 `PrivateDomainAiConstants.DEFAULT_AGENT_ID`。
- [x] T005 确认旧逻辑保持：私域白名单、自消息缓存清理、回复时间窗、非私域链路（钢琴/声乐/SOP/路由/人工回复静默/新 Agent 验证）均不变。

**检查点**：T001-T005 已完成，进入实现。

## Phase 2：风险门禁

- [x] T006 占位参数检查：无 `new XxxDto()`、空 JSON、空 Map 占位传参；空/`null` 标签列表按未命中处理。
- [x] T007 调用后赋值检查：新增判断为同步现查现用，无调用后赋值、无异步补齐字段。
- [x] T008 下游字段来源检查：`external_user_id`、`user_id`、`tag_name` 均在使用前有确定来源。
- [x] T009 影响范围检查：仅在私域分支「时间窗校验通过」后、「getAgentId/发送」前新增判断与提前返回，不改调用顺序契约、外部请求体、MQ body、Redis TTL、数据库写入。
- [x] T010 业务语义确认：标签数据源（OTS `drh_external_user_info`）与拦截范围（整个私域分支）已由用户确认，记录于 `spec.md` D001。
- [x] T011 测试映射：标签匹配纯函数（命中/不命中/空/null/其它标签）、命中拦截、未命中放行、异常降级、不回归各建立测试。

**检查点**：T006-T011 结论明确，无未确认的高风险项。

## Phase 3：实现

- [x] T012 `PrivateDomainAiConstants` 新增 `DO_NOT_DISTURB_TAG_NAME = "请勿打扰"` 常量。
- [x] T013 `MessageServiceImpl` 新增包级方法 `containsDoNotDisturbTag(List<FollowUser.Tag>)`（纯匹配）与 `hasDoNotDisturbTag(externalUserId, userId)`（调用 `selectExternalUserTags` + 异常降级）。
- [x] T014 在 `handlePrivateDomainAiIfMatched` 时间窗校验后、`getAgentId` 前插入「请勿打扰」拦截，命中则打印日志并返回 `true`。
- [x] T015 保持未声明的旧行为不变，同步更新文档执行记录。

## Phase 4：测试与验证

- [x] T016 新增 `MessageServiceImplPrivateDomainDoNotDisturbTest`，覆盖命中拦截、未命中放行、标签匹配纯函数。
- [x] T017 断言下游：命中时 `never sendPrivateDomainAiMessage` 且 `never getAgentId`；未命中时 `verify sendPrivateDomainAiMessage(...)`。
- [x] T018 不回归：复用既有 `MessageServiceImplManualReplySilenceTest`（白名单未命中、自消息、时间窗外），并将「正常发送」用例改为 spy 跳过真实 OTS。
- [x] T019 运行 `mvn -pl juzi-service test -Dtest=... -DskipTests=false` 并记录结果（见 D002）。
- [x] T020 搜索确认无残留旧调用、旧字段、旧口径。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 097 规格文档，完成 Phase 1/2 门禁结论。
- 验证方式：代码搜索 + 阅读 `MessageServiceImpl`、`OtsUtil`、`AppTask`、既有私域测试确认事实。
- 自检结论：满足强制门禁，数据源与范围已确认。

### D002 - 实现记录

- 实现内容：见 Phase 3；新增「请勿打扰」标签拦截，复用 `OtsUtil.selectExternalUserTags`，异常降级放行。
- 测试命令：`mvn -f data-RC/pom.xml -pl juzi-service test -Dtest=MessageServiceImplPrivateDomainDoNotDisturbTest,MessageServiceImplManualReplySilenceTest -DskipTests=false -o`。
- 测试结果：`MessageServiceImplPrivateDomainDoNotDisturbTest` 6/6 通过；`MessageServiceImplManualReplySilenceTest` 12/12 通过；合计 `Tests run: 18, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：参数来源齐备、调用顺序未变、旧逻辑保持；测试以 spy 隔离静态 OTS 调用，未真实访问 OTS；剩余风险仅为标签名别名假设。

### D003 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
