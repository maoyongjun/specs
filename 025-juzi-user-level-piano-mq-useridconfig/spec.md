# 功能规格：用户等级 MQ userIdConfig 放开与触发间隔调整

**功能目录**: `025-juzi-user-level-piano-mq-useridconfig`  
**创建日期**: 2026-05-20  
**状态**: Implemented  
**输入**: 用户要求先在 `C:\workspace\ju-chat\specs` 新建 Spec Kit 文档；后续修改 `juzi-service` 的 `UserInsightUpdateServiceImpl#userLevelGenerate`，使钢琴 `skuId=4` 用户等级生成发送 MQ 时不限制 `userIdConfig`；修改 `fc/rocket-mq-consumer` 的 `UserLevelUpdateTask`，消费端全量不再限制 `userIdConfig`；并将发送端用户等级生成 Redis 去重间隔从 10 分钟改为 30 分钟。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 钢琴 SKU4 白名单外用户仍可触发用户等级 MQ（优先级：P1）

当 `juzi-service` 处理钢琴 `skuId=4` 用户消息时，即使当前企微 `userId` 不在 `userIdConfig` 中，也应允许触发用户等级生成 MQ，避免钢琴用户等级更新被发送端白名单拦截。

**独立测试**：构造 `UserInfoDto.skuId=4`、`JuziMessageDto.botWeixin` 不在 Redis 配置 `ai:info:qwUser:config:key` 中，调用 `userLevelGenerate`，验证仍发送用户等级 MQ。

**验收场景**：

1. **Given** `skuId=4` 且 `userIdConfig` 不包含当前 `userId`，**When** 调用 `userLevelGenerate`，**Then** 系统发送用户等级 MQ。
2. **Given** `skuId=4` 且 `userIdConfig` 为空，**When** 调用 `userLevelGenerate`，**Then** 系统发送用户等级 MQ。
3. **Given** `skuId=4` 且 `signUpTushu=false`，**When** 成功发送 MQ，**Then** 写入用户等级去重 key，TTL 为 30 分钟。

### 用户故事 2 - 非钢琴用户保持发送端白名单控制（优先级：P1）

当 `skuId` 不是 4 且不是图书登记触发时，发送端仍沿用现有 `needUpdate(userId)` 白名单逻辑，避免本次改动扩大非钢琴用户等级 MQ 的触发范围。

**独立测试**：构造 `UserInfoDto.skuId=5` 或其他非 4 SKU，且 Redis 白名单不包含当前 `userId`，调用 `userLevelGenerate`，验证不发送 MQ；再构造白名单包含当前 `userId`，验证正常发送。

**验收场景**：

1. **Given** `skuId=5` 且白名单不包含当前 `userId`，**When** 调用 `userLevelGenerate`，**Then** 系统不发送用户等级 MQ。
2. **Given** `skuId=6` 且白名单包含当前 `userId`，**When** 调用 `userLevelGenerate`，**Then** 系统发送用户等级 MQ。
3. **Given** 非钢琴用户 `signUpTushu=true`，**When** 调用 `userLevelGenerate`，**Then** 保持现有图书登记不限白名单触发行为。

### 用户故事 3 - 消费端全量取消 userIdConfig 拦截（优先级：P1）

当 `UserLevelUpdateTask` 收到用户等级更新 MQ 时，不应再因为 `user_id` 缺失于 `userIdConfig` 而提前跳过处理。消费端应继续执行已有参数校验、day 范围校验、同步标签、等级计算和 OTS 更新。

**独立测试**：构造 `user_id` 不在环境变量 `userIdConfig` 中或 `userIdConfig` 为空的 MQ 消息，调用消费逻辑，验证不会因白名单不命中提前返回，并能进入后续等级更新判断链路。

**验收场景**：

1. **Given** `userIdConfig` 为空，**When** `UserLevelUpdateTask` 收到有效用户等级 MQ，**Then** 不因配置为空跳过处理。
2. **Given** `userIdConfig` 不包含当前 `user_id`，**When** `UserLevelUpdateTask` 收到有效用户等级 MQ，**Then** 不因白名单不命中跳过处理。
3. **Given** `external_user_id` 为空、`day<4` 或 `day>15`，**When** 消费端处理 MQ，**Then** 仍按现有业务规则跳过。

### 用户故事 4 - 用户等级生成去重间隔改为 30 分钟（优先级：P1）

当用户等级生成 MQ 已在当前时间窗口触发过时，发送端应在 30 分钟内忽略重复触发，日志文案也应同步显示 30 分钟更新一次。该间隔指 Redis 去重 key TTL，不调整 MQ 延迟投递时间。

**独立测试**：构造用户等级去重 key 已存在，调用 `userLevelGenerate`，验证不发送 MQ；构造发送成功场景，验证写入去重 key 的 TTL 为 30 分钟。

**验收场景**：

1. **Given** 去重 key 已存在且 `signUpTushu=false`，**When** 调用 `userLevelGenerate`，**Then** 系统不发送 MQ。
2. **Given** 去重 key 不存在且 MQ 发送成功，**When** 写入去重 key，**Then** TTL 为 30 分钟。
3. **Given** 命中去重拦截，**When** 记录日志，**Then** 日志文案表达为 30 分钟更新一次。
4. **Given** 普通用户等级 MQ，**When** 设置 MQ 延迟投递时间，**Then** 保持现有延迟投递逻辑不变。

## 边界情况

- `UserInfoDto.skuId` 为空。
- `UserInfoDto.skuId` 为 4、字符串兼容字段为 `sku_id=4`。
- Redis `ai:info:qwUser:config:key` 为空、缺失、读取异常或不包含当前 `userId`。
- `JuziMessageDto.signUpTushu` 为空、`false` 或 `true`。
- 用户等级去重 key 已存在。
- MQ 发送成功但 Redis 写入去重 key 失败。
- 消费端环境变量 `userIdConfig` 为空、缺失或不包含当前 `user_id`。
- 消费端 `external_user_id` 为空、`user_id` 为空、`day` 为空、`day<4`、`day>15`。
- MQ body 中没有 `sku_id` 的旧消息仍可兼容消费。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下维护本 Spec Kit 目录。
- **FR-002**：`juzi-service` 中 `skuId=4` 的用户等级生成 MUST 跳过 `needUpdate(userId)` 白名单限制。
- **FR-003**：`juzi-service` 中非 `skuId=4` 且非 `signUpTushu=true` 的用户等级生成 MUST 保持现有 `needUpdate(userId)` 过滤逻辑。
- **FR-004**：用户等级 MQ body MUST 增加 `sku_id` 字段，值来自 `UserInfoDto.skuId`。
- **FR-005**：用户等级 MQ body MUST 保留现有字段，不破坏旧消费逻辑。
- **FR-006**：普通用户等级生成成功发送 MQ 后，发送端 MUST 将用户等级去重 key TTL 从 10 分钟改为 30 分钟。
- **FR-007**：命中用户等级去重 key 时，日志文案 MUST 从“10分钟更新一次”同步调整为“30分钟更新一次”。
- **FR-008**：本需求 MUST NOT 调整 MQ 延迟投递时间。
- **FR-009**：`UserLevelUpdateInput` MUST 增加可选 `sku_id` 字段。
- **FR-010**：`UserLevelUpdateTask` MUST 全量取消 `userIdConfig` 消费端拦截。
- **FR-011**：`UserLevelUpdateTask` MUST 删除或停止调用因 `needUpdate(userId)` 返回 false 而提前跳过的逻辑。
- **FR-012**：消费端 MUST 保持 `external_user_id` 为空、day 范围、同步标签、等级计算和 OTS 更新的既有业务逻辑。
- **FR-013**：后续实现 MUST 增加单元测试覆盖发送端钢琴不限白名单、非钢琴仍受控、30 分钟去重、MQ `sku_id` 字段和消费端全量不拦截。
- **FR-014**：后续单元测试 MUST 避免真实访问 Redis、OTS、Center 或 RocketMQ。

## 成功标准 *(必填)*

- **SC-001**：`skuId=4` 且白名单不包含当前 `userId` 时，用户等级 MQ 可以发送。
- **SC-002**：非 `skuId=4` 且白名单不包含当前 `userId` 时，发送端仍不发送普通用户等级 MQ。
- **SC-003**：普通用户等级生成成功发送后，去重 TTL 为 30 分钟。
- **SC-004**：命中去重拦截时，日志文案为 30 分钟更新一次。
- **SC-005**：消费端收到白名单外 `user_id` 的有效消息时，不再因为 `userIdConfig` 跳过。
- **SC-006**：旧消息不包含 `sku_id` 时，消费端仍能按现有字段处理。
- **SC-007**：`juzi-service` 和 `rocket-mq-consumer` 后续实现包含可执行单元测试。
- **SC-008**：本需求不新增数据库表、不新增对外 API、不修改用户等级判定规则。

## 假设

- `skuId=4` 代表钢琴。
- 消费端 `userIdConfig` 限制按用户确认口径全量取消。
- “30 分钟间隔”只调整发送端 Redis 去重 TTL 和对应日志文案，不调整 MQ 延迟投递时间。
- `signUpTushu=true` 保持现有不限白名单与快速触发行为。
- 本次规格阶段只写文档，不修改业务代码。

## 执行记录

### D001 - 文档记录

- 已新增本 Spec Kit 文档，记录用户等级 MQ 发送端与消费端调整需求。
- 本轮仅修改文档，未修改 `juzi-service` 或 `rocket-mq-consumer` 业务代码。

### D002 - 代码实现与单元测试

- 已实现 `skuId=4` 用户等级生成发送 MQ 不限制发送端 `userIdConfig`。
- 已为用户等级 MQ body 增加 `sku_id` 字段。
- 已将用户等级生成 Redis 去重间隔从 10 分钟改为 30 分钟，并同步日志文案。
- 已取消 `UserLevelUpdateTask` 消费端 `userIdConfig` 拦截。
- 已补充 `juzi-service` 与 `rocket-mq-consumer` 单元测试，覆盖发送端白名单、去重 TTL、MQ 字段和消费端不拦截逻辑。
