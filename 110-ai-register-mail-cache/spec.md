# 功能规格：AI 登记邮寄缓存联动

**功能目录**：`110-ai-register-mail-cache`  
**创建日期**：`2026-06-24`  
**状态**：Implementing  
**输入**：`修改 C:\workspace\ju-chat\fc\delay-mq 和 C:\workspace\ju-chat\fc\ai-reply；遇到 AI 生成的消息包含“已经给您登记邮寄”，记录缓存 5 分钟，key 中包含 external_user_id。external-info-select 返回时检查缓存，缓存存在则 if_register 强制设置为 是，代表已登记物流信息。`

## 背景

- 当前问题：AI 已回复用户“已经给您登记邮寄”后，`external-info-select` 仍可能因为标签或物流数据未同步而返回 `if_register=否` 或缺失。
- 当前行为：`if_register` 主要由企微标签“已填写”和部分物流状态补偿写入；AI 回复路径不会给外部信息插件留下短期状态。
- 目标行为：AI answer 生成内容命中固定文案后，按 `external_user_id` 写入 5 分钟 Redis 缓存；`AppTask` 返回前发现缓存存在时强制返回 `if_register="是"`。
- 非目标：不修改 `ProfileTask/ProfileTaskV2`，不新增数据库字段，不改变 Coze 参数、FC/MQ body、标签解析和原有物流查询逻辑。

## 用户场景与测试

### 用户故事 1 - AI 回复后短期返回已登记（优先级：P1）

当 AI 生成“已经给您登记邮寄”相关话术时，后续 Coze 外部信息查询应立即视为已登记物流信息。

**独立测试**：断言缓存 key、TTL、触发文案识别，以及 `AppTask` 纯逻辑缓存覆盖。

**验收场景**：

1. **Given** AI answer 生成内容包含 `已经给您登记邮寄`，**When** 系统打印 AI 生成消息日志，**Then** 写入 `ai:reply:register-mail:if_register:{external_user_id}`，值为 `是`，TTL 为 300 秒。
2. **Given** `AppTask` 普通返回路径生成 `chat_name`，且对应缓存存在，**When** 返回前检查缓存，**Then** `if_register` 被强制设置为 `是`。
3. **Given** `AppTask` 私域返回路径生成结果，且对应缓存存在，**When** 返回前检查缓存，**Then** `if_register` 被强制设置为 `是`。

### 用户故事 2 - 未命中或异常不影响旧逻辑（优先级：P2）

未命中文案、缓存不存在或 Redis 异常时，旧回复发送和外部信息返回不能被阻断。

**独立测试**：断言未命中文案返回 false；缓存值为空时不覆盖 `if_register`。

**验收场景**：

1. **Given** AI 内容不包含固定文案，**When** 进入发送逻辑，**Then** 不写登记邮寄缓存。
2. **Given** Redis 读写抛异常，**When** AI 发送或 `AppTask` 返回，**Then** 只记录 warn 日志并继续原流程。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `external_user_id`：AI 回复路径来自 `EmpExternalDto.getExternal_user_id()`；在 `sendJuzi` 调用前已由任务输入解析完成；下游用于 Redis key 拼接。
  - `content`：来自 Coze `MessageType.ANSWER` 内容，经 `sanitizeAiGeneratedContent` 清洗；在 answer 生成事件中当前层现算现用。
  - `chat_name/result`：`AppTask.handleRequest` 根据 `DayEnum.createCozeJson` 或私域聚合生成；返回前当前层读取缓存并覆盖。
- 下游读取字段清单：
  - AI 回复路径读取 `content`、`external_user_id`。
  - `AppTask` 普通路径读取 `external_user_id`、`chat_name.if_register`。
  - `AppTask` 私域路径读取 `PrivateDomainExternalKey.externalUserId`、`result.if_register`。
- 空对象 / 占位对象风险：
  - `AppTask` 早退会返回静态空 JSON；早退场景不做缓存检查，避免给无效 external key 写入业务字段。
  - AI 回复 `empExternalDto` 或 `external_user_id` 为空时跳过写缓存。
- 调用顺序风险：
  - 写缓存放在 `CONVERSATION_MESSAGE_COMPLETED + ANSWER` 内容清洗和日志打印后，避免撤回、人工回复时间戳、空内容或“无法回答”等 early return 导致 AI 已生成但未记录缓存。
  - 读缓存放在 `AppTask` 返回日志前，确保日志和返回体一致。
- 旧逻辑保持：
  - 保持敏感词重试、撤回检查、人工回复跳过、`无法回答` 跳过、`lastPrefix` MD5 缓存、`CenterUtil.saveUserKeyInfo`、标签解析和物流查询逻辑不变。
- 需要用户确认的设计选择：
  - 已确认只按 `external_user_id` 维度生效，且只覆盖 `AppTask` 主入口。

## 边界情况

- `content` 为空或不含触发文案：不写缓存。
- `external_user_id` 为空：不写缓存、不读缓存。
- Redis 读写异常：记录 warn，继续发送或返回。
- 缓存值不为空即可视为命中；约定写入值为 `是`。
- 5 分钟后 Redis 自然过期，`AppTask` 恢复原标签/物流逻辑结果。

## 需求

### 功能需求

- **FR-001**：系统 MUST 在 `ai-reply` answer 生成内容命中文案时写入登记邮寄缓存。
- **FR-002**：系统 MUST 在 `delay-mq` 新旧 Coze 回复路径 answer 生成内容命中文案时写入登记邮寄缓存。
- **FR-003**：系统 MUST 在 `external-info-select` 的 `AppTask` 普通和私域返回前读取缓存，命中后强制 `if_register="是"`。
- **FR-004**：系统 MUST NOT 因 Redis 读写失败阻断 AI 回复发送或外部信息返回。
- **FR-005**：单元测试 MUST 覆盖 key、TTL、触发文案识别和缓存覆盖纯逻辑。

## 成功标准

- **SC-001**：三个目标模块均使用同一 key 前缀、值和 TTL。
- **SC-002**：目标 Maven 测试命令通过，或失败原因明确且与本次改动无关。
- **SC-003**：搜索确认未改动 `ProfileTask/ProfileTaskV2` 的缓存覆盖逻辑，且未触碰当前工作区已有无关改动。

## 假设

- 固定触发文案精确为 `已经给您登记邮寄`，包含即可命中。
- `external-info-select` 与两个 FC 模块使用同一 Redis 环境和 DB 配置。
- AI answer 命中文案即写缓存，即使后续因撤回、人工回复、空内容或“无法回答”逻辑未实际发送。
- 用户已在实施请求中确认进入实现，无需在文档创建后再次停顿确认。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成历史问题防漏分析和强制门禁检查。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 已新增统一 Redis key/TTL/触发文案常量，补充三个模块测试。
- 已在 `ai-reply`、`delay-mq` 的 Coze answer 生成事件中写登记邮寄缓存。
- 已在 `external-info-select` 的 `AppTask` 普通和私域返回前读取缓存并覆盖 `if_register`。
- 测试结果：三条目标 Maven 测试均 BUILD SUCCESS。

### D003 - 纠正记录：缓存写入时机前移

- 触发原因：运行日志已打印 `AI生成的消息: 同学，已经给您登记邮寄了...`，但未看到缓存写入日志；说明缓存写在 `sendJuzi` 内会被中间 early return 漏掉。
- 修正内容：旧口径为发送前校验通过后写缓存；新口径为 Coze answer 内容生成并打印日志后立即写缓存。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md`。
- 验证结果：`ai-reply` 4 tests、`delay-mq` 3 tests、`external-info-select` 10 tests 全部通过。
