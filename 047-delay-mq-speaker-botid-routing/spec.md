# 功能规格：delay-mq 按 speakerId 路由 Coze botId

**功能目录**：`047-delay-mq-speaker-botid-routing`  
**创建日期**：`2026-06-03`  
**状态**：Done  
**输入**：`在 C:\workspace\ju-chat\specs 新建 spec-kit 文档，完成如下需求，先修改文档，不编码：修改 C:\workspace\ju-chat\fc\delay-mq，botId 通过 speakerId 来区分。如果 speakerId=106，也就是赵曼，走固定的 botId=7638948127407636514。speakerId=39，张曼，走原来默认的。其他的走固定的 botId=7638948127407636514。获取 speakerId，参考 C:\workspace\ju-chat\fc\audio-tts\src\main\java\com\drh\audio\service\AppTask.java 中 CenterUtil.getCampInfoByCampDateId(campDateId) 相关代码。`

## 背景

- 当前问题：`delay-mq` 发送 Coze 通用聊天时，`CreateChatReq.botID` 当前直接取 `DayEnum.getBotId()`，没有按营期对应的 `speakerId` 做区分。
- 当前行为：`AppTask`、`AppTaskV2` 将 `EmpExternalDto.day` 传入 `CozeUtil` / `CozeUtilV2`；`CozeUtil.sendMessage()`、`CozeUtilV2.sendMessage()`、`CozeUtilV2.sendMessageV2()` 在构建 `CreateChatReq` 时使用 `dayEnum.getBotId()`。
- 目标行为：在 `delay-mq` 通用聊天调用 Coze 前，通过 `campDateId` 查询营期信息，取出 `speakerId` 并按规则解析本次 Coze 请求使用的 `botId`。
- 非目标：不修改 `audio-tts`；不修改 MQ body、Redis key、OTS 查询、conversation key、企微发送链路或数据库结构。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 赵曼营期使用固定 botId（优先级：P1）

当消息所属营期的 `speakerId=106`（赵曼）时，`delay-mq` 发送 Coze 聊天请求必须使用固定 `botId=7638948127407636514`。

**独立测试**：用单元测试或可替换的 Center 查询桩返回 `speakerId=106`，触发 V1 和 V2 通用聊天路径，断言 `CreateChatReq.botID` 为 `7638948127407636514`。

**验收场景**：

1. **Given** `EmpExternalDto.camp_date_id` 对应的 `CampInfo.speakerId=106`，**When** `AppTask` 进入 `CozeUtil` 或 `CozeUtilV2` 通用聊天发送，**Then** Coze 请求的 `botID` 为 `7638948127407636514`。
2. **Given** `EmpExternalDto.camp_date_id` 对应的 `CampInfo.speakerId=106`，**When** `AppTaskV2` 调用 `CozeUtilV2.sendMessageV2()`，**Then** Coze 请求的 `botID` 为 `7638948127407636514`。

### 用户故事 2 - 张曼营期保持原默认 botId（优先级：P1）

当消息所属营期的 `speakerId=39`（张曼）时，系统必须继续走原来的默认 botId 逻辑，避免改变张曼既有通用聊天 Agent。

**独立测试**：构造 `speakerId=39`，断言解析出的 `botId` 等于当前 `dayEnum.getBotId()`，而不是绕过默认逻辑。

**验收场景**：

1. **Given** `speakerId=39` 且 `dayEnum=day3`，**When** 构建 Coze 请求，**Then** `botID` 等于 `DayEnum.day3.getBotId()`。
2. **Given** `speakerId=39` 且原有流程因 `dayEnum` 为空会提前返回，**When** 进入发送方法，**Then** 保持原提前返回行为，不因 botId 兜底而新增发送。

### 用户故事 3 - 未知或其他 speakerId 使用固定 botId（优先级：P2）

除 `speakerId=39` 以外的其他 speakerId，包含空值、未知值和 Center 查询失败，都应使用固定 `botId=7638948127407636514` 作为兜底。

**独立测试**：分别模拟 `speakerId=107`、`speakerId=null`、`CampInfo=null`、Center 调用异常，断言解析结果均为固定 botId，并且原消息过滤、Redis、OTS、conversation 行为不变。

**验收场景**：

1. **Given** `speakerId=107`，**When** 构建 Coze 请求，**Then** `botID` 为 `7638948127407636514`。
2. **Given** `campDateId` 为空或 Center 查询失败，**When** 已通过原有发送前置校验并构建 Coze 请求，**Then** `botID` 为 `7638948127407636514`，并记录包含 `campDateId`、`speakerId`、`botId` 的日志。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `campDateId`：来源 `EmpExternalDto.getCamp_date_id()`；赋值时机为 MQ/FC 入参反序列化完成后；下游读取位置为 `AppTask`、`AppTaskV2`、待新增 botId 解析逻辑。
  - `campInfo`：来源待在 `delay-mq` 的 `CenterUtil.getCampInfoByCampDateId(campDateId)` 中通过 Center 接口查询；参考 `audio-tts` 的 `CenterUtil.getCampInfoByCampDateId()`。
  - `skuId`：来源 `campInfo == null ? null : campInfo.getCategory()`；本需求只要求参考获取方式，可用于日志，不参与 botId 路由。
  - `speakerId`：来源 `campInfo == null ? null : campInfo.getSpeakerId()`；必须在构建 `CreateChatReq` 之前解析完成。
  - `dayEnum`：来源 `EmpExternalDto.getDay()`；当前默认 botId 来源为 `dayEnum.getBotId()`；`speakerId=39` 必须继续走该默认来源。
  - `resolvedBotId`：来源当前层按 `speakerId` 和 `dayEnum` 解析；下游读取位置为 `CreateChatReq.builder().botID(...)`。
  - `user_bot_id`：来源 `EmpExternalDto.getUser_bot_id()`；下游用于 `LocalCacheUtil.getCorpId(user_id, empExternalDto.getUser_bot_id())`，不是本需求要修改的 Coze `botID`。
- 下游读取字段清单：
  - `CozeUtil.sendMessage()` 和 `CozeUtil.generateAndSendRetry()` 读取 `dayEnum.getBotId()` 构建 Coze 请求，后续实现需替换为解析后的 `resolvedBotId` 或等价封装。
  - `CozeUtilV2.sendMessage()` 读取 `dayEnum.getBotId()` 构建 Coze 请求，后续实现需替换为解析后的 `resolvedBotId` 或等价封装。
  - `CozeUtilV2.sendMessageV2()` 读取 `dayEnum.getBotId()` 构建 Coze 请求，后续实现需替换为解析后的 `resolvedBotId` 或等价封装。
  - `CozeUtil` / `CozeUtilV2` 发送企微消息时仍读取 `empExternalDto.user_bot_id` 查询 corpId，该字段必须保持原义。
- 空对象 / 占位对象风险：
  - `CenterUtil.getCampInfoByCampDateId(campDateId)` 可能返回 null；必须允许 `skuId`、`speakerId` 为 null，并按“其他的走固定 botId”兜底。
  - Center 响应的 `data` 可能是 JSON 对象或字符串；参考 `audio-tts` 解析策略处理，不能把空 JSON 或只 set 部分字段的对象当作 speakerId=39。
  - 不新增空 DTO、空 Map 或空 JSON 作为 Coze 参数占位；Coze `parameters` 原有图片、视频参数逻辑保持不变。
- 调用顺序风险：
  - `resolvedBotId` 必须在 `CreateChatReq.builder().botID(...)` 调用前确定，不能在 Coze 请求发出后再补写。
  - 不依赖后续发送企微阶段的 `user_bot_id` 来反推出 Coze botId。
  - `speakerId=39` 使用原默认逻辑时，不得绕过当前 `dayEnum` 为空的早退校验。
- 旧逻辑保持：
  - `AppTask` 中 `newAi` 分流、`homeworkOnlyMode`、消息类型过滤、撤回检查、时间间隔检查、`notNeedReplay`、OTS 查询和作业点评分支保持不变。
  - `AppTaskV2` 中时间戳校验、消息类型过滤、撤回检查、重复回复 key、消息合并和图片视频参数保持不变。
  - Coze conversation key 仍为 `ai:coze:conversation:key:v3:{day}:{otsInfoKey}`，本需求不按 botId 拆分会话。
  - Redis key、TTL、MQ 入参字段、外部接口契约和数据库写入不变。
  - `EmpExternalDto.user_bot_id` 继续只服务企微 corpId 查询，不作为 Coze `botID` 的最终来源。
- 需要用户确认的设计选择：
  - 无。用户已明确要求通过 `speakerId` 区分 botId，并指定 `speakerId=106`、`speakerId=39`、其他值的路由口径。
  - 本规格将“张曼走原来默认的”解释为继续使用当前 `dayEnum.getBotId()` 默认逻辑；如后续确认默认来源不是 `DayEnum`，实现前必须追加纠正记录。

## 边界情况

- `campDateId` 为 null：不调用或无法有效调用 Center，`speakerId` 视为 null；已通过原发送前置校验时使用固定 `botId=7638948127407636514`。
- Center 接口失败、`sys_domain` 缺失、响应体为空、响应无法解析：记录 warn 或 info 日志，`speakerId` 视为 null，使用固定 botId。
- `speakerId=106`：强制使用固定 `botId=7638948127407636514`，不依赖 `dayEnum.getBotId()` 的当前值。
- `speakerId=39`：继续使用原默认 `dayEnum.getBotId()`；若原流程会因 `dayEnum` 为空直接返回，保持直接返回。
- `speakerId` 为其他值或 null：使用固定 `botId=7638948127407636514`。
- `skuId` 与 `speakerId` 不匹配或为空：本需求不按 `skuId` 分支，只记录日志辅助排查。

## 需求 *(必填)*

### 功能需求

- **FR-001**：`delay-mq` MUST 新增或复用 `CenterUtil.getCampInfoByCampDateId(campDateId)` 能力，按 `campDateId` 获取 `CampInfo.category` 和 `CampInfo.speakerId`，获取方式参考 `audio-tts` 的 `AppTask.resolveSpeaker()` 和 `CenterUtil`。
- **FR-002**：系统 MUST 在 Coze 请求发出前解析 `resolvedBotId`：`speakerId == 106` 时为 `7638948127407636514`。
- **FR-003**：系统 MUST 在 `speakerId == 39` 时继续使用原默认 botId 逻辑，即当前 `dayEnum.getBotId()`。
- **FR-004**：系统 MUST 在 `speakerId` 为其他值、null、或 Center 查询失败时使用固定 `botId=7638948127407636514`。
- **FR-005**：系统 MUST 将 `resolvedBotId` 应用于 `CozeUtil.sendMessage()`、`CozeUtilV2.sendMessage()`、`CozeUtilV2.sendMessageV2()` 中所有 `CreateChatReq.builder().botID(...)` 调用。
- **FR-006**：系统 MUST 在日志中记录 `campDateId`、`skuId`、`speakerId`、`resolvedBotId` 和路由原因，避免记录 token 等敏感字段。
- **FR-007**：系统 MUST NOT 修改 `EmpExternalDto.user_bot_id` 的语义或赋值，不得影响 `LocalCacheUtil.getCorpId(...)` 逻辑。
- **FR-008**：系统 MUST NOT 修改 MQ body、Redis key/TTL、OTS 查询、conversation key、消息过滤、作业点评分支、敏感词重试和企微发送行为。
- **FR-009**：实现阶段 MUST 增加单元测试或可执行静态验证，覆盖 `speakerId=106`、`speakerId=39`、其他 speakerId、空值/查询失败，以及 V1/V2 Coze 请求参数断言。

## 成功标准 *(必填)*

- **SC-001**：`speakerId=106` 的 V1、V2 通用聊天 Coze 请求均使用 `botID=7638948127407636514`。
- **SC-002**：`speakerId=39` 的 Coze 请求使用当前 `dayEnum.getBotId()`，保持原默认 Agent 行为。
- **SC-003**：其他 `speakerId`、null 或 Center 异常均使用固定 `botID=7638948127407636514`，且不会导致消息发送流程异常中断。
- **SC-004**：后续实现完成后，静态搜索确认 Coze `CreateChatReq.botID(...)` 不再无条件直接读取 `dayEnum.getBotId()`。
- **SC-005**：后续实现完成后，`fc/delay-mq` 编译或目标测试通过，且不出现 MQ、Redis、OTS、conversation key 的非需求变更。

## 假设

- `EmpExternalDto.camp_date_id` 对应用户需求中的 `campDateId`。
- `speakerId=106` 表示赵曼，`speakerId=39` 表示张曼。
- 固定 `botId=7638948127407636514` 已在 Coze 可用。
- “原来默认的”当前解释为 `DayEnum.getBotId()`；当前 `DayEnum` 中各 day 的 botId 也是该默认来源。
- Center 接口 `/sae-gateway/kkhc-idc-ai/ai/getCampInfoByCampDateId?campDateId=` 可在 `delay-mq` 运行环境通过 `sys_domain` 访问。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成 `delay-mq` 与 `audio-tts` 参考代码的只读核查。
- 已记录 V1、V2 Coze 调用点、参数来源、边界、旧逻辑保持项和测试映射。
- 本阶段未修改业务代码。

### D002 - 实现记录

- **实现内容**：在 `delay-mq` 的 `CenterUtil` 中新增 `getCampInfoByCampDateId()`、`CampInfo` 和响应解析逻辑；新增 `BotIdResolver`，按 `speakerId=106` 固定 botId、`speakerId=39` 走 `DayEnum.getBotId()`、其他或空值固定 botId；将 `CozeUtil`、`CozeUtilV2` 的 Coze `CreateChatReq.botID(...)` 切换为解析后的 `resolvedBotId`，V1 敏感词重试复用同一个 `resolvedBotId`。
- **影响范围**：`fc/delay-mq/src/main/java/com/drh/delay/consumer/util/CenterUtil.java`、`BotIdResolver.java`、`CozeUtil.java`、`CozeUtilV2.java`，以及新增 `BotIdResolverTest.java`。
- **测试命令**：`mvn -pl delay-mq -am test`。
- **测试结果**：通过，`BUILD SUCCESS`；`common` 22 个测试通过，`delay-mq` 16 个测试通过，其中新增 `BotIdResolverTest` 8 个测试通过。Maven 输出存在既有 `coze-api` 使用 `LATEST` 的 warning，不影响本次构建结果。
- **静态验证**：`rg "botID\\(dayEnum\\.getBotId\\(\\)" fc/delay-mq/src/main/java/com/drh/delay/consumer/util` 无匹配；`user_bot_id` 仍只在原 DTO 和 `LocalCacheUtil.getCorpId(...)` 相关路径中使用。
- **自检结论**：实现覆盖 V1、V2 和 V2 合并消息路径；未修改 MQ body、Redis key/TTL、OTS 查询、conversation key、作业点评分支、敏感词过滤策略和企微发送链路。

### D003 - 纠正记录模板

- 触发原因：`用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题`。
- 修正内容：`写清楚旧口径和新口径`。
- 文档同步：`spec/tasks/AGENTS/checklist 是否已同步`。
- 验证结果：`测试或静态检查结果`。
