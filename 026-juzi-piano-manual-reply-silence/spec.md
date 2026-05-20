# 功能规格：钢琴用户级人工回复静默（AI/SOP）

**功能目录**：`026-juzi-piano-manual-reply-silence`  
**创建日期**：`2026-05-20`  
**状态**：Draft  
**输入**：用户要求针对钢琴 `skuId=4`，当人工回复发生后 5 分钟内不发送 AI，也不发送 SOP。静默规则升级为用户级，Redis key 按 `externalUserId + userId + skuId` 维度保存。`sop-reply` 读取同一把已经按 `skuId` 维度写入的 Redis key，不再额外写 `skuId == 4` 分支。只改 `juzi-service`、`fc/ai-reply`、`fc/sop-reply`，不改 `delay-mq`。

## 背景

- 当前问题：人工回复后，AI 和 SOP 的发送链路仍可能继续执行，尤其是已经生成完毕但还没真正发送的结果，缺少用户级静默拦截。
- 当前行为：`juzi-service` 只有消息级的 `removeCache` 清理，`ai-reply` 主要是消息级 `redisKey` 前后检查，`sop-reply` 只有自己的 `recentProcess` 去重锁，不是用户级静默锁。
- 目标行为：钢琴用户一旦发生人工回复，就写入 5 分钟用户静默锁，AI 和 SOP 在这 5 分钟内都不发，包含“已经生成好但还没发送”的场景。
- 非目标：不改 `delay-mq`，不改非钢琴 SKU 的发送行为，不改现有消息级 `removeCache`、`recentProcess`、路由开关和既有异常兜底语义。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 钢琴人工回复后 AI 静默 5 分钟（优先级：P1）

当钢琴用户发生人工回复后，系统应在 5 分钟内禁止 `fc/ai-reply` 发送任何 AI 回复，即使 AI 已经生成了内容，只要最终发送阶段检测到静默标识，也必须丢弃。

**独立测试**：构造钢琴人工回复场景，验证 `juzi-service` 写入用户静默锁；随后触发 `fc/ai-reply`，验证入口和最终发送阶段都能命中静默锁，AI 不会发出。

**验收场景**：

1. **Given** 钢琴用户已发生人工回复且静默锁存在，**When** `fc/ai-reply` 收到后续消息，**Then** 不进入 Coze 或最终发送流程。
2. **Given** AI 已经生成完内容但静默锁在发送前出现，**When** `fc/ai-reply` 到达最终发送阶段，**Then** 已生成内容不发送。
3. **Given** 钢琴用户再次发生人工回复，**When** 重新写入静默锁，**Then** TTL 刷新为 300 秒。

### 用户故事 2 - 钢琴人工回复后 SOP 静默 5 分钟（优先级：P1）

当钢琴用户发生人工回复后，系统应在 5 分钟内禁止 `fc/sop-reply` 发送任何 SOP，即使作业识别已经完成，路由已经命中，或者 Action 已经准备好，只要最终发送阶段检测到静默标识，也必须不发。

**独立测试**：构造钢琴人工回复场景，验证 `fc/sop-reply` 在入口和最终 Action 发送点都能读取同一把静默锁，命中后不发送 SOP。

**验收场景**：

1. **Given** 钢琴用户已发生人工回复且静默锁存在，**When** `SopReply` 开始处理请求，**Then** 不继续进入 SOP 派发。
2. **Given** 作业识别已经完成、Action 已经构建，但静默锁在最终发送前存在，**When** `SopConfigSender` 到达 `sendSingleAction(...)`，**Then** 不调用 `juziUtil.sendJuzi(...)`。
3. **Given** 静默锁在识别完成后、延迟发送前才写入，**When** 最终 Action 发送执行，**Then** 仍然不发送 SOP。

### 用户故事 3 - 非钢琴和 `delay-mq` 保持现状（优先级：P2）

本次规则只针对钢琴用户级静默，不改变 `delay-mq`，也不改变非钢琴 SKU 的既有 AI / SOP 行为。

**独立测试**：构造非钢琴 SKU 和 `delay-mq` 的现有流程，验证本次新增静默锁不会被写入，也不会影响原有发送结果。

**验收场景**：

1. **Given** 非钢琴 SKU 发生人工回复，**When** 走现有 AI / SOP 流程，**Then** 行为保持不变。
2. **Given** `delay-mq` 继续处理其既有链路，**When** 本次静默规则生效，**Then** `delay-mq` 不受影响。
3. **Given** 钢琴用户静默锁过期，**When** 新消息到达，**Then** AI / SOP 恢复正常发送。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `skuId`：来源 `juzi-service` 的 `UserInfoDto.skuId`，赋值时机在 `selectUserPermission(...)` 之后；当前 `MessageServiceImpl` 的自发消息早退点在这之前，新写锁不能被早退吞掉。
  - `externalUserId` / `userId`：来源于消息上下文，在 `juzi-service`、`ai-reply`、`sop-reply` 都能拿到。
  - 静默 key：一次写入，多个模块读取，不能在各模块各写一套规则。
- 下游读取字段清单：
  - `ai-reply` 读取静默 key，并在 Coze 前和最终发送前各检查一次。
  - `sop-reply` 读取同一把静默 key，并在入口、Action 最终发送前各检查一次。
  - `HomeWorkCommentService` 里任何最终会落到 `juziUtil.sendJuzi(...)` 的 helper，也必须复用同一发送前检查。
- 空对象 / 占位对象风险：
  - 不允许为了传递静默状态再塞一个空 DTO、空 JSON 或占位参数。
- 调用顺序风险：
  - `MessageServiceImpl` 当前有两个自发消息相关分支，新的写锁必须覆盖所有可能的早退路径，不能让“高工作时间直接返回”把锁写漏。
  - AI 和 SOP 都可能已经生成完内容但尚未发送，所以必须同时做入口检查和发送前检查。
- 旧逻辑保持：
  - 现有消息级 `removeCache` 保持不变。
  - `ai-reply` 现有消息级 `redisKey` 检查保留。
  - `sop-reply` 现有 `recentProcess` 去重锁保留。
  - `delay-mq` 不改。
- 需要用户确认的设计选择：
  - 无，已确认 `sop-reply` 不再额外用 `skuId == 4` 分支做静默判断，直接复用共享 key 读取结果。

## 边界情况

- 钢琴用户重复人工回复时，静默 TTL 必须刷新。
- 静默锁缺失或已过期时，AI / SOP 恢复正常发送。
- AI 或 SOP 已经在队列中、已经生成完但还没发出时，最终发送阶段仍要再校验一次。
- Redis 读取或写入失败时，按 fail open 处理，避免把整条回复链路卡死。
- `skuId` 无法被可靠解析时，不应误写到其他 SKU，必须记录日志并跳过。
- `SopReply` 之外的最终发送 helper 只要会产生用户可见消息，就要复用同一静默拦截。
- 现有 `recognitionOnly`、路由开关、标签同步和其他非发送逻辑不应因为本规则改变。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下维护本 Spec Kit 目录。
- **FR-002**：`juzi-service` MUST 在检测到钢琴用户人工回复时写入一个新的用户级静默锁。
- **FR-003**：静默锁 MUST 按 `externalUserId + userId + skuId` 维度组织，并且只对钢琴场景生效。
- **FR-004**：静默锁 TTL MUST 为 300 秒，重复人工回复 MUST 刷新 TTL。
- **FR-005**：`juzi-service` MUST 确保 `skuId` 的解析不会被自发消息早退路径吞掉，不能让静默写锁漏写。
- **FR-006**：`fc/ai-reply` MUST 在进入 Coze 前检查静默锁，并在最终发送前再次检查静默锁。
- **FR-007**：当静默锁存在时，`fc/ai-reply` MUST NOT 发送已经生成好的 AI 内容。
- **FR-008**：`fc/sop-reply` MUST 在入口阶段检查静默锁，并在最终 Action 发送阶段再次检查静默锁。
- **FR-009**：`fc/sop-reply` MUST NOT 再额外用 `skuId == 4` 分支判断静默规则，而应直接复用共享 key 读取结果。
- **FR-010**：`fc/sop-reply` 中任何最终会产生用户可见消息的发送 helper MUST 复用同一静默拦截。
- **FR-011**：本需求 MUST NOT 修改 `delay-mq`。
- **FR-012**：本需求 MUST 保留现有消息级 `removeCache`、`redisKey` 检查和 `recentProcess` 去重逻辑。
- **FR-013**：静默拦截命中时 MUST 输出可检索日志，至少包含 `externalUserId`、`userId`、`skuId`、命中阶段和静默 TTL 信息。
- **FR-014**：后续实现 MUST 增加单元测试，覆盖人工回复写锁、AI 入口拦截、AI 最终发送拦截、SOP 入口拦截、SOP Action 拦截、重复回复刷新 TTL、非钢琴不受影响。

## 成功标准 *(必填)*

- **SC-001**：钢琴用户人工回复后 5 分钟内，AI 不会发送。
- **SC-002**：钢琴用户人工回复后 5 分钟内，SOP 不会发送，即使作业识别已经完成。
- **SC-003**：AI 或 SOP 已经生成好的内容，只要最终发送阶段检测到静默锁，也不会发出去。
- **SC-004**：静默锁在 5 分钟后自动失效，恢复正常发送。
- **SC-005**：非钢琴 SKU 和 `delay-mq` 行为不回归。
- **SC-006**：本需求实现后，相关单元测试能够稳定覆盖关键路径和边界路径。

## 假设

- `skuId=4` 代表钢琴。
- 静默 key 的具体前缀由实现统一定义，但所有模块必须复用同一生成规则。
- `sop-reply` 读取端不新增额外 `skuId == 4` 分支，只按共享 key 是否存在判断是否静默。
- Redis 异常时按 fail open 处理，不把回复链路整体阻塞。

## 执行记录

### D001 - 文档记录

- 已整理本次钢琴用户级人工回复静默需求。
- 已明确静默规则覆盖 `juzi-service`、`fc/ai-reply`、`fc/sop-reply`，不改 `delay-mq`。
- 本阶段未修改业务代码。

### D002 - 实现记录

- `待实现后补充`。

### D003 - 纠正记录模板

- 触发原因：`<用户补充 / 测试失败 / 代码审查发现 / 参数遗漏 / 调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec / tasks / AGENTS / checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。

