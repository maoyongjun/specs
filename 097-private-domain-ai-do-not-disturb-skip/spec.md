# 功能规格：私域 AI Agent「请勿打扰」标签跳过回复

**功能目录**：`097-private-domain-ai-do-not-disturb-skip`  
**创建日期**：`2026-06-17`  
**状态**：Draft  
**输入**：修改 `C:\workspace\ju-chat\data-RC\juzi-service` 在私域 agent 的回复（agentId：`7644079727246065664`），如果用户有「请勿打扰」的标签，不进行回复，并打印日志。标签数据源：通过 OTS `drh_external_user_info` 表查询，参考 `com.drh.delay.consumer.service.AppTask#notNeedReplay`。拦截生效范围：整个私域 AI 回复分支。

## 背景

- 当前问题：私域 AI Agent（agentId 默认 `7644079727246065664`）命中私域白名单后会无条件下发 AI 回复，未考虑客户已被打「请勿打扰」标签的诉求。
- 当前行为：`MessageServiceImpl#handlePrivateDomainAiIfMatched` 在「白名单命中 → 非自消息 → 回复时间窗内」后，直接 `getAgentId` 并调用 `delayMessageService.sendPrivateDomainAiMessage` 下发回复。
- 目标行为：在下发回复前增加一次客户标签判断，若该客户在 OTS `drh_external_user_info` 中含「请勿打扰」标签，则不下发回复、打印可定位日志并结束私域分支。
- 非目标：不改动非私域链路（钢琴、声乐、SOP、路由、人工回复静默、旁路新 Agent 验证）；不新增 OTS 表、不新增对外接口、不改 MQ/Redis/FC 契约；不修改私域白名单、回复时间窗、自消息缓存清理逻辑。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 私域客户被标「请勿打扰」时不回复（优先级：P1）

私域客户被运营/销售打上「请勿打扰」标签后，再向其发送的消息不应触发私域 AI 自动回复，且系统需留下可排查的日志。

**独立测试**：构造命中私域白名单、非自消息、回复时间窗内的消息，令标签查询返回含「请勿打扰」的标签列表，断言不调用 `sendPrivateDomainAiMessage`，且私域分支返回已处理。

**验收场景**：

1. **Given** 消息命中私域白名单、非自消息、处于回复时间窗内，且客户在 `drh_external_user_info` 含「请勿打扰」标签，**When** 进入 `handlePrivateDomainAiIfMatched`，**Then** 不调用 `getAgentId`、不调用 `sendPrivateDomainAiMessage`，打印 `private_domain_ai_do_not_disturb_skip` 日志，方法返回 `true`。
2. **Given** 同上条件但客户标签列表不含「请勿打扰」，**When** 进入 `handlePrivateDomainAiIfMatched`，**Then** 仍按原逻辑获取 agentId 并调用 `sendPrivateDomainAiMessage`，方法返回 `true`。
3. **Given** 标签查询 OTS 抛出异常，**When** 进入 `handlePrivateDomainAiIfMatched`，**Then** 降级为「不拦截」，按原逻辑下发私域回复，并打印 warn 日志。

### 用户故事 2 - 非私域与边界链路不回归（优先级：P2）

私域白名单未命中、自消息、回复时间窗外等既有分支行为完全保持不变，「请勿打扰」判断不得提前触发或影响这些路径。

**独立测试**：分别构造白名单未命中、自消息（source=0）、时间窗外三种场景，断言不发生新增的标签查询副作用，且原有返回与调用保持不变。

**验收场景**：

1. **Given** 私域白名单未命中，**When** 进入 `handlePrivateDomainAiIfMatched`，**Then** 返回 `false`，不查询标签，不发送私域回复。
2. **Given** 自消息且 source=0，**When** 进入 `handlePrivateDomainAiIfMatched`，**Then** 仅清理缓存并返回 `true`，不查询标签。
3. **Given** 回复时间窗外，**When** 进入 `handlePrivateDomainAiIfMatched`，**Then** 返回 `true`，不查询标签，不发送私域回复。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `externalUserId`：来源 `MessageServiceImpl#doSendMessage` 的 `external_user_id`（取自 `otsDto`/`messageDto`），在调用 `handlePrivateDomainAiIfMatched` 前已赋值；下游读取位置 `OtsUtil#selectExternalUserTags`（作为 `drh_external_user_info` 主键）。
  - `userId`：来源 `doSendMessage` 的 `otsDto.getString("user_id")`（企微 user_id / bot userid），调用前已赋值；下游读取位置 `OtsUtil#selectExternalUserTags`（匹配 `follow_user.userid`）。
  - 标签列表：来源 OTS `drh_external_user_info` 表 `follow_user` 列，由 `selectExternalUserTags` 现查现用，不缓存、不跨层暂存。
- 下游读取字段清单：
  - `selectExternalUserTags` 读取 `drh_external_user_info` 主键 `external_user_id`、列 `follow_user`，并从匹配 `userid` 的 `FollowUser` 取 `tags`。
  - 标签匹配只读取 `FollowUser.Tag.tag_name`，与 `PrivateDomainAiConstants.DO_NOT_DISTURB_TAG_NAME`（`请勿打扰`）精确比较。
- 空对象 / 占位对象风险：
  - 否。不构造任何占位 DTO；`selectExternalUserTags` 返回空或 null 列表时按「未命中」处理，不下传空对象。
- 调用顺序风险：
  - 否。新增判断为同步现查现用，无调用后赋值、无异步补齐；位置固定在「时间窗校验通过」之后、「getAgentId/发送」之前。
- 旧逻辑保持：
  - 私域白名单判断 `isWhiteListed`、自消息缓存清理 `removeCache`、回复时间窗 `isReplyTimeAllowed`、`getAgentId` 默认值与日志、`sendPrivateDomainAiMessage` 入参、非私域全部链路、`newAgentVerify` 旁路均保持不变。
- 需要用户确认的设计选择：
  - 已确认：标签数据源为 OTS `drh_external_user_info`（参考 `AppTask#notNeedReplay`）；拦截范围为整个私域 AI 回复分支（不限定 agentId 取值）。

## 边界情况

- 客户在 `drh_external_user_info` 无记录或 `follow_user` 中无匹配 `userid`：`selectExternalUserTags` 返回空列表，按「未命中」放行。
- 标签列表为空或元素 `tag_name` 为空：不视为命中，放行。
- 标签 `tag_name` 与「请勿打扰」大小写/前后空格不一致：按精确相等判断（沿用参考方法 `equals` 口径，不做模糊匹配）。
- OTS 查询异常：捕获异常、打印 warn 日志、降级放行（与 `notNeedReplay` 一致）。
- 时间窗外、自消息、白名单未命中：在「请勿打扰」判断之前已返回，不触发标签查询。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在私域 AI 回复分支下发回复前，使用 `OtsUtil.selectExternalUserTags(externalUserId, userId)` 查询客户标签。
- **FR-002**：当标签列表存在 `tag_name` 等于「请勿打扰」时，系统 MUST 跳过私域 AI 回复（不调用 `getAgentId` 与 `sendPrivateDomainAiMessage`），打印可定位日志，并使 `handlePrivateDomainAiIfMatched` 返回 `true`。
- **FR-003**：当标签列表不含「请勿打扰」时，系统 MUST 保持原有私域 AI 回复行为不变。
- **FR-004**：标签查询发生异常时，系统 MUST 降级为不拦截（按原逻辑回复）并打印 warn 日志，MUST NOT 因标签查询失败而漏回复或抛出异常中断私域分支。
- **FR-005**：系统 MUST NOT 改变私域白名单、自消息缓存清理、回复时间窗判断、非私域链路、MQ/Redis/FC/接口契约。
- **FR-006**：「请勿打扰」拦截 MUST 作用于整个私域 AI 回复分支（命中私域白名单即生效），MUST NOT 限定具体 agentId 取值。
- **FR-007**：单元测试 MUST 断言「命中『请勿打扰』时不调用 `sendPrivateDomainAiMessage`」与「未命中时仍调用 `sendPrivateDomainAiMessage`」，且 MUST NOT 真实访问 OTS。

## 成功标准 *(必填)*

- **SC-001**：命中「请勿打扰」标签的私域消息 100% 不下发私域 AI 回复，并产生可定位日志。
- **SC-002**：未命中「请勿打扰」标签的私域消息回复行为与改动前一致。
- **SC-003**：白名单未命中、自消息、时间窗外、非私域链路全部不回归。
- **SC-004**：`juzi-service` 目标测试编译并通过，测试不真实访问 OTS。

## 假设

- `selectExternalUserTags` 的入参 `userId` 与私域分支 `handlePrivateDomainAiIfMatched` 的 `userId`（企微 user_id）语义一致，可用于匹配 `follow_user.userid`（沿用 `ChatFrequencyLevelClassifierServiceImpl` 既有用法）。
- 「请勿打扰」标签名为简体中文精确字符串 `请勿打扰`，不含别名；若实际存在别名或大小写差异，需追加 Dxxx 纠正记录并调整匹配口径。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档（AGENTS.md / spec.md / tasks.md / checklists/requirements.md）。
- 已完成历史问题防漏分析和强制门禁检查。
- 数据源与拦截范围已由用户确认。

### D002 - 实现记录

- 实现内容：
  - `PrivateDomainAiConstants` 新增 `DO_NOT_DISTURB_TAG_NAME = "请勿打扰"`。
  - `MessageServiceImpl` 新增 `containsDoNotDisturbTag(List<FollowUser.Tag>)`（按 `tag_name` 精确匹配）与 `hasDoNotDisturbTag(externalUserId, userId)`（复用 `OtsUtil.selectExternalUserTags`，异常降级返回 `false`）。
  - `handlePrivateDomainAiIfMatched` 在回复时间窗校验通过后、`getAgentId` 之前插入「请勿打扰」拦截，命中则打印 `private_domain_ai_do_not_disturb_skip` 日志并返回 `true`。
- 影响范围：仅私域分支新增一次 OTS 读取与一处提前返回；未改接口契约、MQ、Redis、数据库写入、FC payload 与非私域链路。
- 测试命令：`mvn -f data-RC/pom.xml -pl juzi-service test -Dtest=MessageServiceImplPrivateDomainDoNotDisturbTest,MessageServiceImplManualReplySilenceTest -DskipTests=false -o`。
- 测试结果：`Tests run: 18, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`（新增 6 条 + 既有 12 条）。
- 自检结论：命中标签不下发、未命中照常下发、异常降级、不回归均经测试覆盖；测试用 spy 隔离静态 OTS，未真实访问 OTS。

### D003 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
