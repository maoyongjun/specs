# 功能规格：新 Agent 上线验证结果落库

**功能目录**：`033-new-agent-reply-record`
**创建日期**：`2026-05-26`
**状态**：Implemented
**输入**：新的 agent 上线验证，agentId 是 `7638948127407636514`。需要将指定销售企业微信 `user_id` 配置到走新 Agent，默认销售 `user_id` 为 `ZhangFuYi02`、`liuyongqi02`、`DengPiaoPiao_1`、`ShuDie2`、`LiXin9_1`；接收到结果后不用发送，而是记录到数据库。只有私聊消息回复，群消息不用处理。数据库表字段：`externalUserId`、`unionId`、用户昵称、学员消息 `message_id`、学员发送的消息、AI 回复的消息、生成时间、`dayN`、销售企业微信 id。从 `juzi-service` 调用单独 service 方法，Coze agent 调用逻辑仿照原 `delay-mq`，包括获取历史消息。当前已按文档完成 `juzi-service` 实现，并支持无 AI 权限但可通过 `IdSetDto.empId`、企微营期标签和营期 `dayNum` 补齐验证上下文的私聊影子流量；DDL 仍只作为提案未执行。

## 背景

- 当前问题：新 Agent 需要上线前验证回复质量，但不能影响学员实际收到的原 AI 回复。
- 当前行为：`juzi-service` 接收消息并写入 OTS 后，按权限、路由和延迟逻辑调用原延迟 MQ / FC 链路，由 `fc/delay-mq` 调用 Coze 并发送回复。
- 目标行为：`juzi-service` 对命中 Nacos 销售 `user_id` 白名单的私聊学员消息额外执行新 Agent 影子调用；即使原 AI 权限为 `false`，只要能补齐验证上下文，也调用新 Agent 并将结果写入 MySQL 表 `drh_new_agent_reply_record`，不发送给学员，且不阻断原回复链路。
- 非目标：不执行 DDL，不连接生产数据库，不替代原延迟 MQ / AI 回复链路，不处理群聊新 Agent 验证。

## 用户场景与测试

### 用户故事 1 - 命中销售私聊消息影子调用新 Agent（优先级：P1）

运营配置某些销售企业微信 `user_id` 后，这些销售名下的私聊学员消息应额外调用新 Agent，用于上线验证。

**独立测试**：构造私聊消息，`JuziMessageDto.botWeixin` 命中 `new-agent.verify.sales-user-ids`，验证实现调用新 Agent `7638948127407636514` 并写入 `drh_new_agent_reply_record`。

**验收场景**：

1. **Given** `new-agent.verify.enabled=true` 且销售 `user_id` 命中白名单，**When** 学员发送私聊消息，**Then** 系统额外调用新 Agent 并写入验证记录。
2. **Given** 新 Agent 返回可用回复，**When** 回复生成完成，**Then** 系统记录 `external_user_id`、`union_id`、`nick_name`、`message_id`、`student_message`、`ai_reply`、`generated_time`、`day_n`、`sales_qw_user_id` 和 `agent_id`。
3. **Given** 原路由仍应执行，**When** 新 Agent 影子调用成功或失败，**Then** 原 `sendDelayMessage` / 原 AI 回复链路不被取消、不被替代。
4. **Given** 权限接口返回 `permission=false` 且 `UserInfoDto` 缺少 `empId/campDateId/day`，**When** `IdSetDto` 可补齐 `empId`、企微“营期”标签名可映射到 `campDateId` 且营期接口可返回 `dayNum`，**Then** 仍执行新 Agent 影子调用，但原 AI 回复链路继续按无权限返回。

### 用户故事 2 - 群聊消息不做新 Agent 验证（优先级：P1）

群聊消息不进入新 Agent 验证，避免扩大验证范围或误记群消息。

**独立测试**：构造 `roomWecomChatId` 或 `roomTopic` 有值的消息，即使销售 `user_id` 命中白名单，也不得调用新 Agent，不得写入新表。

**验收场景**：

1. **Given** 销售 `user_id` 命中白名单，**When** 收到群聊文本消息，**Then** 不调用新 Agent。
2. **Given** 群聊语音、图片或视频消息，**When** `roomWecomChatId` 非空，**Then** 不写入 `drh_new_agent_reply_record`。

### 用户故事 3 - 未命中配置不产生验证记录（优先级：P1）

未配置或未命中的销售消息保持现有行为，不产生新 Agent 调用成本。

**独立测试**：关闭 `new-agent.verify.enabled` 或让销售 `user_id` 不在白名单内，验证不调用新 Agent、不写库。

**验收场景**：

1. **Given** `new-agent.verify.enabled=false`，**When** 学员发送私聊消息，**Then** 不调用新 Agent。
2. **Given** 销售 `user_id` 不在 `new-agent.verify.sales-user-ids` 中，**When** 学员发送私聊消息，**Then** 不写验证记录。

## 数据模型与配置

### Nacos 配置

- `new-agent.verify.enabled`：是否开启验证链路，默认 `false`。
- `new-agent.verify.sales-user-ids`：销售企业微信 `user_id` 白名单，多个值使用英文逗号分隔；代码默认值 MUST 为 `ZhangFuYi02,liuyongqi02,DengPiaoPiao_1,ShuDie2,LiXin9_1`，配置为空时使用默认值。
- `new-agent.verify.agent-id`：新 Agent ID，代码默认值 MUST 为 `7638948127407636514`，配置为空时使用默认值。

### MySQL 表

完整 DDL 提案见 [create-new-agent-reply-record.sql](create-new-agent-reply-record.sql)。当前只提供脚本，不执行。

推荐表名：`drh_new_agent_reply_record`。

字段口径：

- `external_user_id`：学员 `externalUserId`。
- `union_id`：从 OTS 外部联系人信息或现有查询能力获取的 `unionId`。
- `nick_name`：用户昵称，优先使用当前消息 `contactName`，为空时可用 OTS 姓名兜底。
- `message_id`：学员消息的 `message_id`。
- `student_message`：本次学员发送的消息文本；多消息合并时记录传给新 Agent 的最终用户消息内容。
- `ai_reply`：新 Agent 返回的 AI 回复文本。
- `generated_time`：新 Agent 回复生成完成时间。
- `day_n`：优先使用 `UserInfoDto.day` 的数字值；为空时使用 `AiFeign#getCampInfoByCampDateId(campDateId).data.dayNum` 兜底。
- `sales_qw_user_id`：销售企业微信 `user_id`，来源为 `JuziMessageDto.botWeixin`。
- `agent_id`：实际调用的新 Agent ID，默认 `7638948127407636514`。

## 目标实现路径

- 在 `juzi-service` 中新增单独 service，例如 `NewAgentVerifyService`，由 `MessageServiceImpl#doSendMessage` 在 `selectUserPermission` 返回后、原 AI 权限 `return` 前调用。
- 新 service 内部完成配置判断、历史消息查询、新 Agent 调用和结果落库；调用失败只记录日志，不向外抛出影响主链路的异常。
- 新 service 通过 `UserInfoDto`、`IdSetDto.empId`、企微“营期”标签名到 `drh_live_camp_date.name -> id` 的缓存映射，以及营期接口补齐验证上下文；原 AI 权限为 `false` 时仍允许影子验证，但不得恢复或绕过原 AI 回复权限。
- `campDateId` 解析优先级：优先使用 `UserInfoDto.campDateId`；为空时使用当前销售跟进标签中 `group_name` 包含“营期”的第一个标签 `tag_name`，再通过独立缓存 key `ai:juzi:new-agent:camp-date-id-map:v1` 映射到 `drh_live_camp_date.id`；`IdSetDto.campDateId` 不再作为新 Agent 验证的兜底来源。
- Coze agent 调用逻辑仿照 `fc/delay-mq`：
  - 使用 OTS 查询历史消息，私聊按 `external_user_id + user_id` 查询。
  - 复用类似 `ai:coze:conversation:key:v3:{day}:{externalUserId}:{empId}:{campDateId}:{userId}` 的会话缓存思路，但建议为验证链路增加独立前缀，避免污染原会话。
  - 构造包含历史消息的 Coze 请求，bot/agent 使用 `new-agent.verify.agent-id`。
  - 接收到答案事件后只返回文本给落库流程，MUST NOT 调用 `sendJuzi`、FC 发送消息或任何对学员发消息能力。
- `juzi-service` 已补齐 Coze SDK 依赖、验证记录 Entity/Mapper，并将新 Mapper 包加入现有 `RouteMybatisPlusConfig` 扫描范围。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `sales_qw_user_id`：来源 `JuziMessageDto.botWeixin`；在 `MessageServiceImpl` 进入验证 service 前已存在；下游用于白名单判断和落库。
  - `external_user_id`：来源 `messageDto.createOtsDto()` 或 `imContactId` 转换结果；在权限判断前后已补齐；下游用于历史消息查询和落库。
  - `empId/campDateId/dayN`：优先来源 `userCheckService.selectUserPermission` 返回的 `UserInfoDto`；若无权限返回导致字段为空，则用权限接口前已获得的 `IdSetDto.empId` 补齐 `empId`，用企微“营期”标签名映射补齐 `campDateId`，并通过 `AiFeign#getCampInfoByCampDateId(campDateId).data.dayNum` 补齐 `dayN`；下游落库为 `day_n`，并参与 conversation key。
  - `message_id`：来源 `JuziMessageDto.messageId`；消息入 OTS 前已存在；下游用于幂等和落库。
  - `student_message`：来源 `Payload.text` 或历史消息合并结果；下游用于 Coze 请求和落库。
  - `union_id` / `nick_name`：来源 OTS 外部联系人查询或当前消息；下游只用于记录，不作为是否调用新 Agent 的前置门禁。
  - `agent_id`：来源 `new-agent.verify.agent-id`，为空时使用代码默认 `7638948127407636514`；下游用于 Coze 请求和幂等。
- 下游读取字段清单：
  - 验证配置判断读取 `enabled`、`sales-user-ids`、`sales_qw_user_id`、`groupMessage`。
  - Coze 调用读取 `agent_id`、`conversationId`、`sales_qw_user_id`、历史消息列表、当前学员消息。
  - 落库读取 `external_user_id`、`union_id`、`nick_name`、`message_id`、`student_message`、`ai_reply`、`generated_time`、`day_n`、`sales_qw_user_id`、`agent_id`。
- 空对象 / 占位对象风险：
  - 不允许用空历史消息 DTO 或空 Coze 请求继续调用；至少当前 `message_id` 对应的学员消息必须存在。
  - `union_id`、`nick_name` 为空时允许落库为空，但不得阻断验证。
- 调用顺序风险：
  - 验证 service 必须在已获得 `external_user_id`、`user_id`，且 `selectUserPermission` 已返回后调用；触发点必须位于原 AI 权限 `return` 之前。
  - 新 Agent 调用必须包裹异常，不得阻断后续 `sendDelayMessage`。
  - 结果落库必须发生在 Coze 回复生成完成后，`generated_time` 使用当前完成时间。
- 旧逻辑保持：
  - 原消息 OTS 写入、撤回判断、AI 权限判断、手动回复静默、标签同步、作业点评、路由、延迟 MQ、原 Coze 发送链路保持不变。
  - 群聊现有处理逻辑保持不变；本验证链路直接跳过群聊。
  - 原 `agent_id` 路由字段和 `drh_ai_config_agent_route_rule` 不因本需求修改契约。
- 需要用户确认的设计选择：
  - 已确认按销售 `user_id` 白名单匹配。
  - 已确认白名单放 Nacos，多个 `user_id` 用英文逗号分隔；默认值为 `ZhangFuYi02`、`liuyongqi02`、`DengPiaoPiao_1`、`ShuDie2`、`LiXin9_1`。
  - 已确认表名为 `drh_new_agent_reply_record`。
  - 已确认新 Agent 为影子调用，不替代原回复链路。

## 边界情况

- `enabled=false`、配置缺失或销售白名单为空：跳过验证链路。
- `sales-user-ids` 存在空格或多余逗号：实现应 trim 后忽略空值。
- 销售 `user_id` 为空：跳过验证链路并记录可检索日志。
- `external_user_id`、`message_id` 为空：跳过验证链路，不能构造空请求。
- `empId/campDateId/dayN` 经 `UserInfoDto`、`IdSetDto.empId`、企微营期标签映射和营期接口兜底后仍为空：跳过验证链路并记录 `new_agent_verify_context_incomplete_skip`。
- 群聊字段 `roomWecomChatId` 或 `roomTopic` 任一非空：跳过验证链路。
- OTS 历史消息查询为空：不得调用新 Agent；记录日志。
- Coze 调用异常、超时、返回空或错误事件：不发送给学员，不影响原链路；当前实现为空回复不落库，异常只记录日志并保持不阻断主流程。若 Coze 返回非空文本，包括无法回答类文本，按验证样本落库。
- 重复 `message_id + agent_id`：使用唯一索引或插入前查询保证幂等，避免重复验证记录。
- 新 Agent 验证链路和原 Coze conversation key 必须隔离，避免串用会话上下文。

## 需求

### 功能需求

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下维护本 Spec Kit 目录，记录新 Agent 上线验证需求。
- **FR-002**：实现 MUST 在 `juzi-service` 内新增单独 service 方法处理新 Agent 验证，不直接改写原 `delay-mq` 发送逻辑。
- **FR-003**：实现 MUST 通过 Nacos 配置 `new-agent.verify.enabled` 控制验证链路是否开启。
- **FR-004**：实现 MUST 通过 Nacos 配置 `new-agent.verify.sales-user-ids` 配置销售企业微信 `user_id` 白名单，多个值用英文逗号分隔；配置为空时 MUST 使用默认白名单 `ZhangFuYi02,liuyongqi02,DengPiaoPiao_1,ShuDie2,LiXin9_1`。
- **FR-005**：实现 MUST 使用 `7638948127407636514` 作为新 Agent 默认 ID；当 `new-agent.verify.agent-id` 为空时使用该默认值。
- **FR-006**：实现 MUST 仅对私聊、非销售自己发送、销售 `user_id` 命中白名单的学员消息执行新 Agent 影子调用。
- **FR-007**：实现 MUST NOT 对群聊消息执行新 Agent 验证或写入验证记录。
- **FR-008**：实现 MUST 获取历史消息并仿照 `fc/delay-mq` 构造 Coze 请求上下文。
- **FR-009**：实现 MUST NOT 将新 Agent 返回结果发送给学员。
- **FR-010**：实现 MUST 将新 Agent 结果写入 MySQL 表 `drh_new_agent_reply_record`。
- **FR-011**：实现 MUST 保持原延迟 MQ / AI 回复链路不变，新 Agent 成功或失败都不得阻断原链路。
- **FR-012**：实现 MUST 对 `message_id + agent_id` 做幂等保护。
- **FR-013**：实现 MUST 增加单元测试，覆盖白名单命中、未命中、群聊跳过、影子调用不阻断原链路、落库字段完整和 Coze 参数构造。
- **FR-014**：实现阶段 MUST NOT 执行 DDL、连接生产数据库或发起真实外部 Coze 联调；数据库变更仍按 DBA 审核流程执行。
- **FR-015**：实现 MUST 在原 AI 权限 `return` 前触发新 Agent 验证；当 `permission=false` 但验证上下文可通过 `IdSetDto.empId`、企微“营期”标签映射和营期接口补齐时，仍执行影子验证。
- **FR-016**：实现 MUST 保持 `permission=false` 不走原 `sendDelayMessage`，不得因为新 Agent 验证恢复或绕过原 AI 回复权限。

## 成功标准

- **SC-001**：`specs/033-new-agent-reply-record` 中存在完整 `spec.md`、`tasks.md`、`AGENTS.md` 和 `checklists/requirements.md`。
- **SC-002**：规格明确新 Agent ID 默认值为 `7638948127407636514`，且配置来源为 Nacos。
- **SC-003**：规格明确只处理命中销售 `user_id` 白名单的私聊消息，群聊不处理，默认白名单为 `ZhangFuYi02`、`liuyongqi02`、`DengPiaoPiao_1`、`ShuDie2`、`LiXin9_1`。
- **SC-004**：规格明确新 Agent 回复只落库，不发送给学员，且原回复链路保持不变。
- **SC-005**：规格包含 `drh_new_agent_reply_record` DDL 提案，当前实现未执行该 DDL。
- **SC-006**：实现已按文档补齐 service、Coze 调用、历史消息查询、落库和测试，核心业务口径无需重新确认。

## 假设

- `JuziMessageDto.botWeixin` 与延迟任务中的 `user_id` 是本需求所说的销售企业微信 `user_id`。
- `UserInfoDto.day` 数字值可直接作为 `day_n`；为空时使用营期接口返回的 `dayNum`。
- `UserInfoDto.campDateId` 若权限接口已返回则优先可信；为空时按当前销售 `user_id` 下第一个 `group_name` 包含“营期”的企微标签 `tag_name` 转换为 `campDateId`。
- `juzi-service` 当前 MySQL datasource 可读取 `drh_live_camp_date` 的 `id/name` 映射。
- `union_id` 可从 `OtsUtil.selectExternalUser` 或同等 OTS 查询能力获取；为空时允许记录空值。
- 新 Agent 验证表使用 MySQL，后续由 MyBatis-Plus Entity/Mapper 写入。
- Coze SDK 已加入 `juzi-service`，版本与 `fc/delay-mq` 的 `com.coze:coze-api` 保持兼容。

## 执行记录

### D001 - 文档记录

- 已新增本 Spec Kit 文档，记录新 Agent 上线验证结果落库需求。
- 已明确销售 `user_id` 白名单、Nacos 配置、默认 agentId、影子调用、私聊限定和群聊跳过口径。
- 本轮仅修改 `specs` 文档，未修改 `juzi-service` 业务代码，未连接数据库，未执行 DDL。

### D002 - DDL 提案记录

- 已新增 `create-new-agent-reply-record.sql` 作为未执行 DDL 提案。
- 脚本包含 `drh_new_agent_reply_record`、幂等唯一键 `uk_message_agent(message_id, agent_id)` 和常用查询索引。

### D003 - 纠正记录

- 当前无已确认的口径纠正项。
- 后续如发生用户补充、代码审查发现或实现测试失败，需追加新的 Dxxx 记录并同步 `spec.md`、`tasks.md`、`AGENTS.md` 与 checklist。

### D004 - 默认销售 user_id 补充

- 用户补充默认销售 `user_id`：`ZhangFuYi02`、`liuyongqi02`、`DengPiaoPiao_1`、`ShuDie2`、`LiXin9_1`。
- 已同步 Nacos 配置口径、功能需求和成功标准。

### D005 - 代码实现记录

- 已在 `juzi-service` 新增 `com.drh.data.juzi.newagentverify` 包，包含 Nacos 配置、历史消息查询、Coze token 与 stream 调用、外部联系人资料读取、结果 Entity/Mapper 和影子验证 service。
- 已在 `MessageServiceImpl#doSendMessage` 获得 `external_user_id`、销售 `user_id` 和 `UserInfoDto` 后触发 `NewAgentVerifyService#verify`，并用异常保护保证原链路继续执行。
- 已将 `drh_new_agent_reply_record` Mapper 加入 `RouteMybatisPlusConfig` 扫描范围，并在 `pom.xml` 加入 `com.coze:coze-api` 依赖。
- 当前实现对 `message_id + agent_id` 插入前查重，插入时捕获 `DuplicateKeyException`；Coze 返回空时只记录日志不落库。
- 已新增单元测试覆盖默认配置解析、销售白名单解析、群聊/自己发送/未命中跳过、命中私聊调用 Coze 并落库、重复消息幂等跳过、新 Agent 触发异常不阻断。
- 已执行目标测试与编译验证；DDL 提案未执行，未连接生产数据库。

### D006 - 无 AI 权限影子验证补充

- 用户补充：`triggerNewAgentVerifySafely` 原来在 AI 权限判断后，无权限用户无法进入；现在要求 `permission=false` 时依然可执行新 Agent 影子验证，并想办法获取验证依赖字段。
- 已将 `MessageServiceImpl` 触发点调整到 `selectUserPermission` 返回后、原 AI 权限 `return` 前；原 `permission=false` 仍不走 `sendDelayMessage`。
- 已将 `NewAgentVerifyService` 上下文补齐改为优先使用 `UserInfoDto`；后续 D007 已将缺失时的 `campDateId` 兜底从 `IdSetDto.campDateId` 调整为企微“营期”标签映射。
- 若 `empId/campDateId/dayN` 兜底后仍不完整，记录 `new_agent_verify_context_incomplete_skip` 并跳过，不构造空 Coze 请求。
- 已新增测试覆盖 `permission=false` 的上下文兜底、上下文不完整跳过、`UserInfoDto.day` 优先、权限失败仍触发验证、权限通过只触发一次。

### D007 - 营期标签解析补充

- 用户补充：`campDateId` 获取需仿照 `kkhc-idc-ai` 的 `AiServiceImpl#getCampDateName` 和 `getCampDateIds`，通过企微“营期”标签名映射到 `campDateId`，缓存 key 不得与其他项目重复。
- 已新增 `NewAgentCampDateResolver`，从当前销售跟进标签中提取 `group_name` 包含“营期”的第一个 `tag_name`，再通过 `drh_live_camp_date.name -> id` 映射补齐 `campDateId`。
- 已使用独立 Redis key `ai:juzi:new-agent:camp-date-id-map:v1` 和 lock key `ai:juzi:new-agent:camp-date-id-map:lock:v1`，本地缓存与 Redis TTL 为 35 分钟。
- 已调整上下文优先级：`empId` 仍可由 `IdSetDto.empId` 兜底；`campDateId` 不再使用 `IdSetDto.campDateId`，改为 `UserInfoDto.campDateId || 企微营期标签映射`。
- 已新增 `NewAgentCampDateResolverTest` 并更新 `NewAgentVerifyServiceTest`，目标测试通过 `Tests run: 20, Failures: 0, Errors: 0, Skipped: 0`；`juzi-service` 编译通过。
