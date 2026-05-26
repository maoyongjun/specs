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

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `033-new-agent-reply-record` Spec Kit 文档、checklist 和未执行 DDL 提案。
- 验证方式：文档静态检查、占位符搜索、路径和编号确认。
- 自检结论：已明确参数来源、调用顺序、旧逻辑保持、Nacos 配置、数据库表、边界情况和测试映射。

### D002 - 实现记录

- 实现内容：新增 `NewAgentVerifyProperties`、`NewAgentVerifyService`、历史消息查询、Coze token / stream 调用、外部联系人资料读取、验证记录 Entity/Mapper，并在 `MessageServiceImpl` 中触发影子验证。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=NewAgentVerifyPropertiesTest,NewAgentVerifyServiceTest,MessageServiceImplManualReplySilenceTest" test`。
- 编译命令：`mvn -pl juzi-service -DskipTests compile`。
- 测试结果：目标测试通过，`Tests run: 10, Failures: 0, Errors: 0, Skipped: 0`；`juzi-service` 编译通过。
- 自检结论：默认白名单、私聊命中、群聊跳过、幂等、落库字段、Coze 参数和异常不阻断已覆盖；DDL 未执行。

### D003 - 纠正记录

- 当前无已确认的口径纠正项。
- 后续如有用户补充、代码审查发现或实现测试失败，追加新的 Dxxx 记录并同步规格、任务与 checklist。

### D004 - 默认销售 user_id 补充

- 执行内容：补充默认销售 `user_id` 白名单为 `ZhangFuYi02,liuyongqi02,DengPiaoPiao_1,ShuDie2,LiXin9_1`。
- 验证方式：同步检查 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 自检结论：默认白名单已写入配置、需求和实施任务口径。
