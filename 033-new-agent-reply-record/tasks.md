# 任务清单：新 Agent 上线验证结果落库

**输入**：来自 `spec.md` 的功能规格
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前目标项目为 `C:\workspace\ju-chat\data-RC\juzi-service`。
- [x] T002 用代码搜索确认真实入口为 `MessageServiceImpl#doSendMessage`，原延迟消息构造在 `DelayMessageServiceImpl#createJSONObject`，参考 Coze 调用在 `fc/delay-mq`。
- [x] T003 确认关键参数来源：销售 `user_id` 来源 `JuziMessageDto.botWeixin`，`external_user_id` 来源 OTS DTO / IM 转换，`day_n` 来源 `UserInfoDto.day`，`message_id` 来源 `JuziMessageDto.messageId`。
- [x] T004 确认配置来源为 Nacos，数据库落库使用 MyBatis-Plus，OTS 历史消息能力目前在 `OtsUtil` / `fc/delay-mq` 中存在参考实现。
- [x] T005 确认旧逻辑必须保持：原延迟 MQ / AI 回复链路、群聊处理、路由 agent 配置、SOP 门禁和消息发送逻辑不变。

**检查点**：实现不得在未复核 T001-T005 的情况下直接编码。

## Phase 2：风险门禁

- [x] T006 检查空对象风险：新 Agent 请求不得用空历史消息列表、空 `external_user_id`、空 `message_id` 或空 `sales_qw_user_id` 继续调用。
- [x] T007 检查调用后赋值风险：验证 service 必须在 `external_user_id`、`user_id` 和 `UserInfoDto` 已确定后调用。
- [x] T008 检查下游读取字段：Coze 调用读取历史消息、agentId、conversationId；落库读取所有记录字段。
- [x] T009 检查影响范围：本需求会新增外部 Coze 请求、MySQL 写入、Nacos 配置和依赖，但不改变原 MQ body 或原发送链路。
- [x] T010 用户已确认业务语义：按销售 `user_id` 配置；Nacos 配置；默认销售 `user_id` 为 `ZhangFuYi02,liuyongqi02,DengPiaoPiao_1,ShuDie2,LiXin9_1`；表名 `drh_new_agent_reply_record`；影子调用不替代原链路。
- [x] T011 建立测试映射：覆盖白名单命中、未命中、群聊跳过、影子调用不阻断原链路、落库字段完整和 Coze 请求参数。

**检查点**：实现前必须保持上述结论，如实现发现代码事实冲突，先更新 `spec.md` 再编码。

## Phase 3：实现

- [x] T012 新增 `NewAgentVerifyProperties`，配置前缀 `new-agent.verify`，默认 `enabled=false`、`agentId=7638948127407636514`、`salesUserIds=ZhangFuYi02,liuyongqi02,DengPiaoPiao_1,ShuDie2,LiXin9_1`。
- [x] T013 新增验证记录 Entity/Mapper/Service，表名 `drh_new_agent_reply_record`，并将 Mapper 包加入 `RouteMybatisPlusConfig`。
- [x] T014 新增历史消息模型和 OTS 查询方法，私聊按 `external_user_id + user_id` 获取历史消息，口径仿照 `fc/delay-mq`。
- [x] T015 新增 Coze 调用组件，复用 token 获取、conversationId 创建、stream answer 解析能力，但禁止发送消息。
- [x] T016 在 `MessageServiceImpl#doSendMessage` 已获取权限且判断为学员私聊后调用验证 service，并确保异常不影响原链路。
- [x] T017 增加 `create-new-agent-reply-record.sql` 对应的生产执行说明，执行前需 DBA 审核和元数据检查。
- [x] T018 同步更新因实现产生变化的 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist。

## Phase 4：测试与验证

- [x] T019 新增配置解析单元测试：`sales-user-ids` 支持逗号、空格、空项，默认 agentId 正确。
- [x] T020 新增 service 单元测试：未开启、白名单未命中、群聊、缺关键参数均跳过且不调用 Coze/Mapper。
- [x] T021 新增私聊命中测试：调用 Coze、写入 `drh_new_agent_reply_record`，并断言字段完整。
- [x] T022 新增影子链路测试：新 Agent service 抛异常时 `MessageServiceImpl` 原链路不被异常阻断。
- [x] T023 新增幂等测试：重复 `message_id + agent_id` 不重复插入、不重复调用或按实现选择安全跳过。
- [x] T024 新增 Coze 请求参数测试：断言 agentId、conversationId key、历史消息和当前消息内容。
- [x] T025 运行 `mvn -pl juzi-service test` 或目标测试类，并记录结果。
- [x] T026 搜索确认没有新增任何发送学员消息的调用点，例如 `sendJuzi`、`sendDelayMessage`、`sendWarningMessage` 或原 MQ body 变更；新包内 `FcInvokeUtils` 仅用于 `ai-service/jwt` 获取 Coze token。

## Phase 5：无 AI 权限影子验证补充

- [x] T027 将新 Agent 触发点前移到 `selectUserPermission` 返回后、原 AI 权限 `return` 前。
- [x] T028 扩展 `NewAgentVerifyService#verify` 入参，传入 `IdSetDto` 作为无权限场景的验证上下文来源。
- [x] T029 新增验证上下文解析：优先 `UserInfoDto.empId/campDateId/day`，缺失时使用 `IdSetDto.empId`、企微营期标签映射出的 `campDateId` 和 `AiFeign#getCampInfoByCampDateId(campDateId).data.dayNum`。
- [x] T030 保持原 AI 权限语义：`permission=false` 仍不进入 `sendDelayMessage`，新 Agent 回复仍只落库不发送。
- [x] T031 新增无权限场景测试：上下文可补齐时调用 Coze 并落库，上下文不完整时跳过，`UserInfoDto.day` 优先于营期接口。
- [x] T032 新增入口测试：权限失败仍触发新 Agent 验证并返回，权限通过只触发一次并继续原链路。
- [x] T033 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 和 checklist。

## Phase 6：营期标签解析补充

- [x] T034 新增 `NewAgentCampDateResolver`，按企微标签 `group_name` 包含“营期”的第一个 `tag_name` 获取营期名称。
- [x] T035 新增 `NewAgentLiveCampDateEntity` 与 `NewAgentLiveCampDateMapper`，查询 `drh_live_camp_date` 的 `id/name` 映射。
- [x] T036 为营期 name/id 映射增加本地缓存、Redis 缓存和短锁，Redis key 使用 `ai:juzi:new-agent:camp-date-id-map:v1`，lock key 使用 `ai:juzi:new-agent:camp-date-id-map:lock:v1`。
- [x] T037 调整上下文解析：`IdSetDto` 只补 `empId`；`campDateId` 使用 `UserInfoDto.campDateId || 企微营期标签映射`。
- [x] T038 新增 `NewAgentCampDateResolverTest`，覆盖标签提取、Redis 命中、DB 加载缓存和异常安全返回。
- [x] T039 更新 `NewAgentVerifyServiceTest`，覆盖无权限通过营期标签解析、resolver miss 跳过、权限字段优先和幂等前置跳过。
- [x] T040 运行目标测试、编译和 diff 检查，并同步更新文档状态。

## Phase 7：Coze 前缀与异步 MDC 修正

- [x] T041 修正新 Agent Coze 消息构造：历史消息不追加销售前缀，仅最后一条学员消息追加 `"&&" + request.getUserId() + "&&  "`；最后一条为销售自己发送时跳过 Coze 请求。
- [x] T042 在触发新 Agent 异步验证前补齐 `JuziMessageDto.requestId`，并在 `NewAgentVerifyService#verify` 异步入口绑定和清理 MDC `requestId`。
- [x] T043 新增 `DefaultNewAgentCozeClientTest` 并更新现有测试，覆盖最新消息前缀、重复前缀保护、销售最后消息跳过、异步 MDC 绑定和触发前 MDC 补齐。
- [x] T044 运行目标测试、编译和 diff 检查，并同步更新文档状态。

## Phase 8：当前消息类型门禁补充

- [x] T045 在 `NewAgentVerifyService#shouldProcess` 增加消息类型门禁，仅允许 `MessageType.TEXT(7)` 与 `MessageType.VOICE(2)` 进入新 Agent 验证。
- [x] T046 确认图片、视频、表情、文件、图文等其他类型在入口跳过，避免当前图片消息无文本时拿历史老师消息误触发 Coze。
- [x] T047 更新 `NewAgentVerifyServiceTest`，覆盖文字/语音允许，图片/视频/表情跳过，以及 `type=null/messageType=5` 不查询历史、不调用 Coze、不落库。
- [x] T048 运行目标测试、编译和 diff 检查，并同步更新文档状态。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `033-new-agent-reply-record` Spec Kit 文档、checklist 和未执行 DDL 提案。
- 验证方式：文档静态检查、占位符搜索、路径和编号确认。
- 自检结论：已明确参数来源、调用顺序、旧逻辑保持、Nacos 配置、数据库表、边界情况和测试映射。

### D002 - 实现记录

- 实现内容：新增 `NewAgentVerifyProperties`、`NewAgentVerifyService`、历史消息查询、Coze token / stream 调用、外部联系人资料读取、验证记录 Entity/Mapper，并在 `MessageServiceImpl` 中触发影子验证。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=NewAgentVerifyPropertiesTest,NewAgentVerifyServiceTest,MessageServiceImplManualReplySilenceTest" test`。
- 编译命令：`mvn -pl juzi-service -DskipTests compile`。
- 测试结果：基础实现目标测试通过，`Tests run: 10, Failures: 0, Errors: 0, Skipped: 0`；无权限补充后目标测试通过，`Tests run: 14, Failures: 0, Errors: 0, Skipped: 0`；营期标签解析补充后目标测试通过，`Tests run: 20, Failures: 0, Errors: 0, Skipped: 0`；`juzi-service` 编译通过。
- 自检结论：默认白名单、私聊命中、无权限上下文兜底、企微营期标签映射、群聊跳过、幂等、落库字段、Coze 参数和异常不阻断已覆盖；DDL 未执行。

### D003 - 纠正记录

- D003 创建时无已确认的口径纠正项。
- 后续用户补充已分别记录到 D004、D005、D007、D008，并同步规格、任务与 checklist。

### D004 - 默认销售 user_id 补充

- 执行内容：补充默认销售 `user_id` 白名单为 `ZhangFuYi02,liuyongqi02,DengPiaoPiao_1,ShuDie2,LiXin9_1`。
- 验证方式：同步检查 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 自检结论：默认白名单已写入配置、需求和实施任务口径。

### D005 - 无 AI 权限影子验证补充

- 执行内容：将新 Agent 验证触发点前移到原 AI 权限返回前；新增无权限上下文兜底；保持原 `permission=false` 不走原 AI 回复。D007 已将 `campDateId` 兜底细化为企微营期标签映射。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=NewAgentVerifyPropertiesTest,NewAgentVerifyServiceTest,MessageServiceImplManualReplySilenceTest" test`。
- 测试结果：目标测试通过，`Tests run: 14, Failures: 0, Errors: 0, Skipped: 0`。
- 自检结论：无权限但上下文可补齐时可影子调用并落库；上下文不可补齐时安全跳过；权限通过路径只触发一次新 Agent。

### D007 - 营期标签解析补充

- 执行内容：新增营期标签解析和 `drh_live_camp_date.name -> id` 缓存映射；`IdSetDto` 只补 `empId`，`campDateId` 改由 `UserInfoDto.campDateId || 企微营期标签映射` 获取。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=NewAgentVerifyPropertiesTest,NewAgentCampDateResolverTest,NewAgentVerifyServiceTest,MessageServiceImplManualReplySilenceTest" test`。
- 编译命令：`mvn -pl juzi-service -DskipTests compile`。
- 测试结果：目标测试通过，`Tests run: 20, Failures: 0, Errors: 0, Skipped: 0`；`juzi-service` 编译通过。
- 自检结论：营期标签提取、缓存 key 隔离、Redis 命中、DB 加载缓存、resolver miss 跳过、无权限影子调用和幂等前置跳过均已覆盖；DDL 未执行。

### D008 - Coze 前缀与异步 MDC 修正

- 执行内容：修正新 Agent Coze 请求消息构造，保持历史消息不加前缀，只给最后一条学员消息加 `"&&" + request.getUserId() + "&&  "`；最后一条为销售自己消息时跳过 Coze；异步验证入口补齐并绑定 MDC `requestId`。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=DefaultNewAgentCozeClientTest,NewAgentVerifyPropertiesTest,NewAgentCampDateResolverTest,NewAgentVerifyServiceTest,MessageServiceImplManualReplySilenceTest" test`。
- 编译命令：`mvn -pl juzi-service -DskipTests compile`。
- 测试结果：目标测试通过，`Tests run: 25, Failures: 0, Errors: 0, Skipped: 0`；`juzi-service` 编译通过。
- 自检结论：前缀逻辑与原代码保持一致，历史消息未被加前缀，异步日志跟踪 ID 已补齐；DDL 未执行。

### D009 - 当前消息类型门禁补充

- 执行内容：新 Agent 入口仅允许当前学员文字和语音消息，图片、视频、表情等其他消息类型直接跳过，防止图片消息无文本时只用历史老师消息请求 Coze。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=NewAgentVerifyServiceTest" test`。
- 测试结果：目标测试通过，`Tests run: 8, Failures: 0, Errors: 0, Skipped: 0`。
- 自检结论：文字/语音门禁、图片/视频/表情跳过、企业级 `messageType=5` 图片不查历史不调 Coze 不落库均已覆盖；DDL 未执行。
