# 功能规格：Dong 专属 Coze 直连回复

**功能目录**：`099-juzi-dong-direct-coze-reply`  
**创建日期**：`2026-06-17`  
**状态**：Implemented  
**输入**：在 `C:\workspace\ju-chat\data-RC\juzi-service` 新增 Dong 专属链路。销售企微 `user_id=Dong` 的学员私聊文字/语音消息，直调 Coze Bot `7652273657926434831`，Coze `userID=demo:{botId}:{externalUserId}:{userId}:{env}`，请求消息使用 Coze SDK `object_string` 文本对象数组传入；收到返回文本后通过 Juzi 发送给学员。参考 `AiServiceImpl#rewriteBookLogisticsNotice` 的同步获取返回结果口径，以及私域链路的 Juzi 发送思路。需要单元测试验证可通过 Coze client 获取返回消息并触发 Juzi 发送，并提供显式开启的真实 agent 验证用例。

## 背景

- 当前问题：现有私域链路会把消息交给 `ai-reply FC`，Coze 调用和 Juzi 发送都在 FC 内完成；本需求要求 `juzi-service` 在 Dong 场景中直接拿到 Coze 返回文本后发送。
- 当前行为：`MessageServiceImpl#doSendMessage` 在自消息处理后先尝试私域白名单，再执行旧权限、SOP、路由和延迟回复链路。
- 目标行为：`user_id=Dong` 的学员私聊文字/语音消息在私域判断前被 Dong 专属链路消费，直调 Coze Bot 并通过 Juzi 文本发送回复。
- 非目标：不使用 `works_flow`，不需要 `worksFlowId`；不新增数据库表；不改 `fc/ai-reply`、`sop-reply`、私域配置页或旧路由规则。

## 用户场景与测试

### 用户故事 1 - Dong 私聊文字消息直连 Coze 并回复（优先级：P1）

当 Dong 名下学员发送私聊文字消息时，系统应直接调用指定 Coze Bot 获取回复，并将回复通过 Juzi 文本消息发给学员。

**独立测试**：mock Coze token/client 返回 `conversationId` 和回复文本，断言 Coze 请求 botId、userID、contentType 和 content JSON 结构正确，并断言 Juzi 发送 gateway 被调用。

**验收场景**：

1. **Given** `user_id=Dong`、私聊、非自消息、文字 `夸我`，**When** 进入消息处理，**Then** Coze 请求 `botID=7652273657926434831` 且 `userID=demo:7652273657926434831:{externalUserId}:Dong:{env}`。
2. **Given** Coze 返回非空文本，**When** Dong 分支处理完成，**Then** 系统通过 `juzi-api` 发送 `messageType=7` 的文本消息给该学员。
3. **Given** Dong 分支已消费消息，**When** 返回到 `MessageServiceImpl`，**Then** 不继续调用私域、权限、SOP、路由或 `ai-reply FC`。

### 用户故事 2 - Dong 语音文本可回复，空文本跳过（优先级：P1）

当 Dong 名下学员发送语音消息且回调中已有可用转写文本时，系统应按同一结构调用 Coze；若语音没有文本，系统跳过并不进入旧链路。

**独立测试**：构造 `type=VOICE` 且 `payload.text/content` 有值，验证 Coze 与 Juzi 调用；构造语音无文本，验证不调用 Coze/Juzi 且 Dong 分支返回已处理。

**验收场景**：

1. **Given** Dong 私聊语音且 `payload.text=夸我`，**When** 处理消息，**Then** Coze content JSON 中 `content.text=夸我`。
2. **Given** Dong 私聊语音但文本为空，**When** 处理消息，**Then** 不调用 Coze、不发送 Juzi、记录跳过日志并结束 Dong 分支。

### 用户故事 3 - 非 Dong 或不支持消息不影响旧链路（优先级：P1）

非 Dong 销售继续走旧逻辑；Dong 的群聊、图片、视频、表情等首期不支持消息不会调用 Coze，也不会 fallback 到旧链路。

**独立测试**：构造非 Dong、Dong 群聊、Dong 图片、Dong Coze 空回复、Dong Coze 异常，断言返回与下游调用符合预期。

**验收场景**：

1. **Given** `user_id` 不是 Dong，**When** 进入 Dong 分支，**Then** 返回 `false`，旧链路继续。
2. **Given** `user_id=Dong` 且为群聊或非文字/语音，**When** 进入 Dong 分支，**Then** 返回 `true`，不调用 Coze/Juzi，不进入旧链路。
3. **Given** Coze 返回空或抛异常，**When** 处理 Dong 消息，**Then** 记录日志并结束，不 fallback 到旧链路。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `userId`：来源 `MessageServiceImpl#doSendMessage` 中 `otsDto.getString("user_id")`，即销售企微 id；在 Dong 分支调用前已判空。
  - `externalUserId`：来源 `otsDto.getString("external_user_id")` 或 `imContactId` 兜底转换；在 Dong 分支调用前已判空并写回 `messageDto`。
  - `messageId`：来源 `JuziMessageDto.messageId`；参与 Dong 分支必要参数和 Juzi `externalRequestId`。
  - `botWxid`：来源 `messageDto.getBotWxid()` / `createOtsDto` 兼容 `imBotId` 后的值；当前 Juzi 发送 DTO 无 `corpId` 字段，发送链路不依赖该值。
  - `botId`：来源 `dong-direct-coze.bot-id`，默认 `7652273657926434831`。
  - `env`：来源 `System.getenv("fc_env")`，为空使用 `default`。
- 下游读取字段清单：
  - Coze 请求读取 `botID`、`userID`、`conversationID`、`messages.contentType`、`messages.content`。
  - Juzi 发送读取 `MessageDto.wecomUserId`、`externalUserId`、`messageType`、`payload.text`、`functionCode`、`type`。
- 空对象 / 占位对象风险：
  - 不允许 Coze content 为空；真实验证确认 SDK 原生 `MessageObjectString.buildText` 生成的 `[{\"type\":\"text\",\"text\":\"...\"}]` 可被 chat API 接收。
  - 不允许空 `text`、空 `conversationId` 或空 Coze 回复继续发送 Juzi。
- 调用顺序风险：
  - Dong 分支必须在私域判断之前；否则 `Dong` 若被配置进私域可能被旧私域链路抢先消费。
  - Dong 命中后，异常和空回复都必须返回 `true`，避免 fallback 到旧链路造成重复或非预期回复。
- 旧逻辑保持：
  - OTS 入库、撤回、群聊基础过滤、招呼语、空用户跳过、自消息清理和非 Dong 全部旧链路保持不变。
  - 私域“请勿打扰”、回复时间窗、SOP 门禁、新 Agent 影子验证不因本需求改变。
- 需要用户确认的设计选择：
  - 已确认：直调 Coze Bot，不走 `works_flow`。
  - 已确认：Coze `userID` 使用 `demo:{botId}:{externalUserId}:{userId}:{env}`。
  - 已确认：Coze 调试页的用户输入显示为 `content_type=text` 的对象数组结构。
  - 真实验证修正：chat API 直接传 `content_type/content` 会返回 `Request parameter error`；实现层使用 SDK 原生 `Message.buildUserQuestionObjects(MessageObjectString.buildText(text))`，平台可正常返回回复。

## 边界情况

- 配置关闭：非 Dong 分支逻辑继续；Dong 不拦截。
- `sales-user-id` 配置为空：使用默认 `Dong`。
- `bot-id` 配置为空：使用默认 `7652273657926434831`。
- `conversation-ttl-hours` 小于等于 0：使用默认 24 小时。
- Dong 群聊：不调用 Coze/Juzi，返回已处理。
- Dong 图片、视频、表情、文件、图文：首期不处理，返回已处理。
- Coze token 获取失败、conversation 创建失败、stream 失败、返回空：记录日志，返回已处理，不发送 Juzi。
- Juzi 发送失败：记录日志，返回已处理，不重试、不 fallback。

## 需求

### 功能需求

- **FR-001**：系统 MUST 新增 Dong 专属 Coze 直连回复链路。
- **FR-002**：系统 MUST 默认只匹配销售企微 `user_id=Dong`。
- **FR-003**：系统 MUST 默认使用 Coze Bot ID `7652273657926434831`。
- **FR-004**：Coze `userID` MUST 为 `demo:{botId}:{externalUserId}:{userId}:{env}`。
- **FR-005**：Coze 请求消息 MUST 使用 `contentType=OBJECT_STRING`，实现层 MUST 使用 SDK 原生文本对象数组，实际 `content` 为 `[{\"type\":\"text\",\"text\":\"学员消息文本\"}]`。
- **FR-006**：系统 MUST 通过独立 Redis key 缓存 Dong Coze conversationId，默认 TTL 24 小时。
- **FR-007**：Coze 返回非空文本后，系统 MUST 通过 `juzi-api` 发送文本消息给学员。
- **FR-008**：Dong 命中后系统 MUST NOT 继续进入私域、权限、SOP、路由或 `ai-reply FC` 链路。
- **FR-009**：非 Dong 消息 MUST 保持旧流程不变。
- **FR-010**：单元测试 MUST 覆盖 Coze 请求结构、Juzi 发送参数、Dong 命中旧链路旁路和边界跳过。

## 成功标准

- **SC-001**：Dong 私聊文字消息可构造出 `userID=demo:7652273657926434831:{externalUserId}:Dong:{env}` 的 Coze 请求。
- **SC-002**：Coze 请求 content 使用真实 agent 验证通过的 SDK object JSON 数组，并包含学员文本。
- **SC-003**：Coze 返回文本后，Juzi 文本发送 payload 字段完整。
- **SC-004**：Dong 命中后旧链路不会继续执行。
- **SC-005**：非 Dong、群聊、非文字/语音、空回复、异常路径均有单元测试。

## 假设

- `JuziMessageDto.botWeixin` / `otsDto.user_id` 就是本需求中的企业微信 id。
- 语音消息若已有 `payload.text` 或 `payload.content`，即可作为文本传入 Coze；本次不做语音转写。
- 首期只发送文本回复，不解析图片、文件、视频号或语音标记。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已记录 Dong 直连 Coze、`demo` userID、OBJECT_STRING 入参、Juzi 文本发送和旧链路旁路要求。
- 已记录真实 agent 验证结论：调试页 `content_type/content` 结构不是 chat API 直接可接受结构，SDK object JSON 可正常返回。

### D002 - 实现记录

- 已在 `juzi-service` 新增 Dong 专属配置、Coze client、Coze reply service 和 Juzi 文本发送 gateway。
- 已在 `MessageServiceImpl#doSendMessage` 自消息处理后、私域判断前接入 Dong 分支。
- 已新增单元测试覆盖 Coze 请求、Juzi 发送和旧链路旁路。
