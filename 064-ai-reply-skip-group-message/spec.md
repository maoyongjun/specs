# 功能规格：ai-reply 群消息跳过

**功能目录**：`064-ai-reply-skip-group-message`  
**创建日期**：`2026-06-09`  
**状态**：Implemented  
**输入**：`fc\ai-reply` 如果是群消息不用回复；上游 `juzi-service` 会对需要作业点评的群消息单独处理，所以这里不用回复群消息。

## 背景

- 当前问题：`ai-reply` 仍会处理 `isGroup=true` 的群消息，可能进入群 OTS 查询、Coze 会话创建和发送流程。
- 当前行为：`AppTask.handleRequest` 在普通 AI 和私域 AI 路径中都存在群消息分支。
- 目标行为：`isGroup=true` 的消息在 `ai-reply` 入口直接返回，不访问 Redis、OTS、Coze，也不执行转账/红包识别和提醒。
- 非目标：不修改上游路由、MQ body、Redis key、数据库、配置项或群作业点评链路。

## 用户场景与测试

### 用户故事 1 - 群消息不由 ai-reply 回复（优先级：P1）

作为群消息处理链路，进入 `fc/ai-reply` 的群消息应完全跳过，避免与上游独立群作业点评处理重复。

**独立测试**：构造 `isGroup=true` 的完整 `ai-reply` 入参调用 `AppTask.handleRequest`，应直接返回且不触发 Redis/OTS/Coze 依赖。

**验收场景**：

1. **Given** 入参 `isGroup=true`，**When** 调用 `AppTask.handleRequest`，**Then** 记录 `ai_reply_group_message_skip` 日志并返回 `null`。
2. **Given** 入参 `isGroup=false` 或缺失，**When** 调用内部判定方法，**Then** 不命中群消息跳过规则。

### 用户故事 2 - 非群消息不回归（优先级：P1）

非群消息仍按旧链路执行普通 AI 或私域 AI 回复前置逻辑。

**独立测试**：保留现有 `PrivateDomainAppTaskTest` 中私域 AI 判定、缺失 agent/sku 判定测试。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `isGroup`：来源为上游 `juzi-service` 创建 FC 入参时写入；在 `AppTask.handleRequest` 解析 JSON 后已可读取。
  - `roomWecomChatId`：仅用于日志和上游契约说明；本次不作为新增兜底判定。
  - `redisKey`、`timestamp`、`agent_id`、`sku_id`：群消息命中门禁时不再读取校验，不触发后续外部依赖。
- 下游读取字段清单：
  - 原普通 AI 路径会读取 Redis、OTS、Coze 会话相关字段；群消息跳过后不再进入。
  - 原私域 AI 路径会读取 `agent_id`、Redis、OTS、Coze 会话相关字段；群消息跳过后不再进入。
- 空对象 / 占位对象风险：
  - 无新增 DTO、空 JSON、空 Map 或占位参数。
- 调用顺序风险：
  - 门禁位于 `redisKey/timestamp` 校验、`handlePrivateDomainAi`、`new RedisClient()` 之前。
- 旧逻辑保持：
  - 非群消息的图片/视频/file 跳过、延迟合并、撤回、人工回复静默、标签过滤、普通 AI、私域 AI 逻辑不变。
- 需要用户确认的设计选择：
  - 已确认采用“完全跳过”，不保留 `ai-reply` 内红包/转账识别和提醒副作用。

## 边界情况

- `EmpExternalDto` 为 `null`：内部 helper 返回 `false`。
- `isGroup=null` 或 `false`：不跳过，保持旧逻辑。
- `isGroup=true` 且缺少 `redisKey`、`timestamp`、`agent_id` 或 `sku_id`：仍直接跳过。
- `roomWecomChatId` 非空但 `isGroup` 未置 `true`：不新增兜底跳过，避免改变现有入参契约。

## 需求

### 功能需求

- **FR-001**：系统 MUST 在 `AppTask.handleRequest` 入口识别 `isGroup=true` 的消息并直接返回。
- **FR-002**：系统 MUST 在群消息跳过时不创建 `RedisClient`，不查询 OTS，不创建 Coze 会话，不发送 Coze 消息。
- **FR-003**：系统 MUST NOT 修改 FC 入参结构、上游路由、MQ body、Redis key、数据库或配置契约。
- **FR-004**：单元测试 MUST 覆盖 `isGroup=true`、`false`、`null` 和完整群消息早返回。

## 成功标准

- **SC-001**：`isGroup=true` 的群消息调用 `handleRequest` 直接返回 `null`。
- **SC-002**：目标测试 `PrivateDomainAppTaskTest` 全部通过。
- **SC-003**：静态确认群消息门禁位于 `handlePrivateDomainAi` 和 `new RedisClient()` 之前。

## 假设

- `isGroup=true` 表示进入 `fc/ai-reply` 的群消息。
- 群作业点评和需要处理的群消息由上游 `juzi-service` 独立链路负责。
- 群消息在 `ai-reply` 内不需要转账/红包提醒等副作用。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成入口、字段来源、调用链和风险门禁确认。

### D002 - 实现记录

- 实现内容：在 `AppTask.handleRequest` 入口新增 `shouldSkipGroupMessage` 门禁和 `ai_reply_group_message_skip` 日志；更新 `PrivateDomainAppTaskTest`。
- 测试命令：`mvn -pl ai-reply -am -Dtest=PrivateDomainAppTaskTest -DfailIfNoTests=false '-Dsurefire.failIfNoSpecifiedTests=false' test`
- 测试结果：`Tests run: 6, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 静态验证：`shouldSkipGroupMessage` 在 `AppTask.java` 第 71 行，早于 `handlePrivateDomainAi` 第 91 行和 `new RedisClient()` 第 98 行。
- 备注：首次按原计划命令运行时，reactor 中 `common` 模块因无匹配测试失败；加入 `-Dsurefire.failIfNoSpecifiedTests=false` 后通过。
