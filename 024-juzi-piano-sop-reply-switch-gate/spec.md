# 功能规格：juzi-service SOP 点评开关门禁

**功能目录**: `024-juzi-piano-sop-reply-switch-gate`  
**创建日期**: 2026-05-19  
**状态**: Implemented

**输入**: 用户要求先修改 `C:\workspace\ju-chat\specs`，不编码；后续在 `juzi-service` 中修改 SOP 点评处理，仿照 `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\service\AppTask.java` 中 `isAiOpen`、`isHomeworkReviewOpen` 和 `isGroupOpen` 的逻辑，只有 AI 开关、作业点评开关以及群聊群 ID 校验满足条件时，才允许继续调用 `sop-reply` 函数。该门禁不再限制为钢琴 `skuId=4`，除 `skuId=5` 明确例外外，其他 SKU 进入 SOP 点评时也必须校验同一套开关逻辑。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 受控 SKU 开关全开时允许进入 SOP 点评（优先级：P1）

当 `juzi-service` 处理命中 SOP 点评的消息，并且该销售在当前营期的 AI 开关与 AI 自动作业点评开关均为开启时，系统应保持现有 SOP 路由和 `sop-reply` 调用行为不变。该规则适用于 `skuId=4` 以及除 `skuId=5` 外的其他 SOP SKU；`skuId=5` 不校验开关状态，保持可调用 `sop-reply`。

**独立测试**：分别构造 `UserInfoDto.skuId=4` 与除 `skuId=5` 外的其他 SKU、`campDateId`、`empId`，使开关配置返回 `aiStatus=1` 且 `aiAutoReview=1`，验证 SOP 识别 / SOP 异步调用路径仍会调用 `sop-reply` FC；同时构造 `skuId=5`，验证不依赖开关配置也可继续调用。

**验收场景**：

1. **Given** `skuId=4` 且 `aiStatus=1`、`aiAutoReview=1`，**When** 命中 SOP 路由规则，**Then** 系统允许继续执行 `sop-reply` 调用。
2. **Given** `skuId=5` 且开关配置为空或关闭，**When** 命中 SOP 路由规则，**Then** 系统仍允许继续执行 `sop-reply` 调用。
3. **Given** 除 `skuId=5` 外的任意 SOP SKU 开关全开，**When** SOP 判断为非作业，**Then** 仍按现有路由 fallback 规则处理。

### 用户故事 2 - 受控 SKU AI 开关关闭时禁止调用 SOP 点评（优先级：P1）

当除 `skuId=5` 外的任意 SKU 消息命中 SOP 处理路径，但 `aiStatus` 不是开启状态时，系统不得继续调用 `sop-reply` 函数，避免绕过销售 / 营期维度的 AI 总开关。`skuId=5` 不校验该开关状态。

**独立测试**：分别构造 `skuId=4`、除 `skuId=5` 外的其他 SKU 且 `aiStatus=0` 或配置为空，验证 `tryInvokeSopRouteAsyncWhenNoopFallback` 和 SOP 路由评估路径均不会调用 `FcInvokeUtils` 的 `sop-reply` 相关方法；构造 `skuId=5` 且 `aiStatus=0`，验证不会因 AI 开关关闭被拦截。

**验收场景**：

1. **Given** `skuId=4` 且 `aiStatus=0`，**When** 命中 SOP 路由规则，**Then** 系统不调用 `sop-reply` FC。
2. **Given** `skuId=6` 且 `aiStatus=0`，**When** 命中 SOP 路由规则，**Then** 系统不调用 `sop-reply` FC。
3. **Given** `skuId=5` 且 `aiStatus=0`，**When** 命中 SOP 路由规则，**Then** 系统仍允许继续执行 `sop-reply` 调用。
4. **Given** 除 `skuId=5` 外的任意 SKU 且 `aiStatus` 为空或配置查询失败，**When** 命中 SOP 路由规则，**Then** 按未开启处理，不调用 `sop-reply` FC。

### 用户故事 3 - 受控 SKU 作业点评开关关闭时禁止调用 SOP 点评（优先级：P1）

当除 `skuId=5` 外的任意 SKU 消息命中 SOP 处理路径，但 `aiAutoReview` 不是开启状态时，系统不得继续调用 `sop-reply` 函数；如果路由规则配置了通用聊天 fallback，则继续由既有 fallback 规则决定是否进入通用聊天。`skuId=5` 不校验该开关状态。

**独立测试**：分别构造 `skuId=4`、除 `skuId=5` 外的其他 SKU 且 `aiStatus=1`、`aiAutoReview=0`，验证不会调用 `sop-reply` FC；构造 `skuId=5` 且 `aiAutoReview=0`，验证不会因作业点评开关关闭被拦截；若规则配置 `fallbackOnPrimaryFalse=true` 且 `secondaryStrategy=GENERAL_CHAT`，则仍可进入现有通用聊天延迟消息流程。

**验收场景**：

1. **Given** `skuId=4` 且 `aiStatus=1`、`aiAutoReview=0`，**When** 命中 SOP 路由规则，**Then** 系统不调用 `sop-reply` FC。
2. **Given** `skuId=6` 且 `aiStatus=1`、`aiAutoReview=0`，**When** 命中 SOP 路由规则，**Then** 系统不调用 `sop-reply` FC。
3. **Given** `skuId=5` 且 `aiStatus=1`、`aiAutoReview=0`，**When** 命中 SOP 路由规则，**Then** 系统仍允许继续执行 `sop-reply` 调用。
4. **Given** SOP 因作业点评开关关闭被拦截，**When** 构建路由决策，**Then** 按现有 fallback 规则进入 `GENERAL_CHAT` 或 `NOOP`。

### 用户故事 4 - 受控 SKU 群聊必须命中群 ID 白名单（优先级：P1）

当 `juzi-service` 处理除 `skuId=5` 外任意 SKU 的群聊 SOP 点评消息时，即使 AI 开关和作业点评开关均开启，也必须继续校验当前群 ID 是否在配置 `chatList` 中。只有 `chatList.contains(roomWecomChatId)` 成立时，才允许继续调用 `sop-reply`。`skuId=5` 不因群 ID 白名单未命中被拦截。

**独立测试**：分别构造 `skuId=4` 和除 `skuId=5` 外其他 SKU 的群聊消息，配置 `aiStatus=1`、`aiAutoReview=1`，并让 `chatList` 包含当前 `roomWecomChatId`、不包含当前群 ID、为空或配置为空，验证只有命中群 ID 时才会调用 `sop-reply` FC；构造 `skuId=5` 群聊，验证不因 `chatList` 或 `roomWecomChatId` 被拦截。

**验收场景**：

1. **Given** `skuId=4`、群聊、`aiStatus=1`、`aiAutoReview=1` 且 `chatList` 包含当前 `roomWecomChatId`，**When** 命中 SOP 路由规则，**Then** 系统允许继续调用 `sop-reply`。
2. **Given** `skuId=4`、群聊、`aiStatus=1`、`aiAutoReview=1` 但 `chatList` 不包含当前 `roomWecomChatId`，**When** 命中 SOP 路由规则，**Then** 系统不调用 `sop-reply`。
3. **Given** 除 `skuId=5` 外的任意 SKU 群聊且 `chatList` 为空或配置为空，**When** 判断是否允许 SOP 点评，**Then** 按群聊作业点评未开启处理，不调用 `sop-reply`。
4. **Given** `skuId=5` 群聊且 `chatList` 为空、配置为空或 `roomWecomChatId` 为空，**When** 判断是否允许 SOP 点评，**Then** 系统仍允许继续执行 `sop-reply` 调用。
5. **Given** 除 `skuId=5` 外的任意 SKU 单聊且 `aiStatus=1`、`aiAutoReview=1`，**When** 判断是否允许 SOP 点评，**Then** 不因为缺少 `roomWecomChatId` 被群 ID 门禁拦截。

### 用户故事 5 - 非 SOP 点评链路保持现有行为（优先级：P1）

本次门禁只限制是否允许调用 `sop-reply` 进行 SOP 点评。未命中 SOP 点评、通用聊天、声乐默认链路和其他非 SOP 处理流程不得因为新增门禁改变既有行为。

**独立测试**：构造未命中 SOP 点评的消息并关闭 `aiAutoReview`，验证不会因为本次门禁影响既有通用聊天或非 SOP 路由。

**验收场景**：

1. **Given** 路由策略不是 `SOP_REVIEW`，**When** 处理消息，**Then** 不应用 SOP 点评门禁。
2. **Given** SOP 门禁关闭且规则配置通用聊天 fallback，**When** 构建路由决策，**Then** 仍按现有 fallback 进入通用聊天。
3. **Given** 除 `skuId=5` 外的任意 SKU 命中 SOP 点评，**When** 准备调用 `sop-reply`，**Then** 必须先通过开关与群 ID 门禁。

## 边界情况

- `campDateId` 或 `empId` 为空，无法查询开关配置。
- 配置查询返回 `null`、空 JSON、字段缺失或字段不是 `1`。
- 配置查询异常或缓存内容解析失败。
- `skuId` 来源可能是 `UserInfoDto.skuId`、路由上下文 `context.skuId`、字符串 `"4"` / `"5"`、通配规则 `"*"` 或为空。
- `skuId=5` 命中 SOP 点评时不校验 AI 开关、作业点评开关和群 ID 白名单，不应因配置缺失、开关关闭或群 ID 未命中被拦截。
- 路由规则使用 `skuId=*` 命中任意 SKU 的 SOP 点评。
- 群聊消息的 `roomWecomChatId` 为空。
- 群聊配置 `chatList` 为空、缺失或不包含当前 `roomWecomChatId`。
- 群聊配置 `chatList` 包含当前 `roomWecomChatId`，但其他开关未开启。
- 单聊消息没有 `roomWecomChatId`，不应触发群 ID 白名单校验。
- `tryInvokeSopRouteAsyncWhenNoopFallback` 直接异步调用 `sop-reply`，需要同样受门禁控制。
- `DefaultSopRouteEvaluator` 同步评估 SOP 时调用 `sop-reply`，需要同样受门禁控制。
- 非 SOP 点评链路不应触发新增开关查询或新增拦截。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下维护本 Spec Kit 目录。
- **FR-002**：`juzi-service` MUST 对除 `skuId=5` 外所有命中 SOP 点评的 SKU 应用本门禁，不得限制为 `skuId=4`。
- **FR-003**：门禁 MUST 使用 `campDateId + empId` 获取 AI 自动作业点评配置，逻辑仿照 `AppTask.java#getAiReviewConfig`。
- **FR-004**：`isAiOpen` 判定 MUST 仿照 `AppTask.java#isAiOpen`，仅当 `aiStatus == 1` 时视为开启。
- **FR-005**：`isHomeworkReviewOpen` 判定 MUST 仿照 `AppTask.java#isHomeworkReviewOpen`，仅当 `aiAutoReview == 1` 时视为开启。
- **FR-006**：除 `skuId=5` 外，任意 SKU 调用 `sop-reply` FC 前，`isAiOpen == true` 且 `isHomeworkReviewOpen == true` MUST 是共同前置条件。
- **FR-007**：除 `skuId=5` 外，任意 SKU 且 `aiStatus` 未开启时，系统 MUST NOT 调用 `sop-reply` FC。
- **FR-008**：除 `skuId=5` 外，任意 SKU 且 `aiAutoReview` 未开启时，系统 MUST NOT 调用 `sop-reply` FC。
- **FR-009**：除 `skuId=5` 外，配置为空、字段缺失、查询失败或解析失败时，系统 MUST 按未开启处理，不调用 `sop-reply` FC。
- **FR-010**：门禁 MUST 覆盖 `MessageServiceImpl#tryInvokeSopRouteAsyncWhenNoopFallback` 的异步 `sop-reply` 调用。
- **FR-011**：门禁 MUST 覆盖 `DefaultSopRouteEvaluator#evaluate` 的同步 SOP 评估调用。
- **FR-012**：门禁拦截后 MUST 交由现有路由 fallback 规则处理，不额外强制发送 SOP 点评。
- **FR-013**：门禁拦截时 MUST 输出可检索日志，至少包含 `campDateId`、`empId`、`externalUserId`、`skuId`、`roomWecomChatId` 和配置内容或失败原因。
- **FR-014**：非 SOP 点评链路 MUST 保持现有路由和通用聊天行为不变。
- **FR-015**：群聊 SOP 点评门禁 MUST 仿照 `AppTask.java#isGroupOpen`，仅当 `isHomeworkReviewOpen(config)` 且 `chatList.contains(roomWecomChatId)` 时视为群聊作业点评开启。
- **FR-016**：除 `skuId=5` 外，任意 SKU 的群聊 SOP 点评中，`chatList` 为空、配置为空、不包含当前 `roomWecomChatId` 或 `roomWecomChatId` 为空时，系统 MUST NOT 调用 `sop-reply` FC。
- **FR-017**：单聊 SOP 点评 MUST NOT 要求校验群 ID，不能因 `roomWecomChatId` 为空被拦截。
- **FR-018**：后续实现 MUST 增加单元测试覆盖 AI 开关、作业点评开关、群 ID 门禁、`skuId=4`、`skuId=5` 例外和非 SOP 链路。
- **FR-019**：`skuId=5` 命中 SOP 点评时 MUST 跳过本门禁，不因 AI 开关、作业点评开关、配置缺失、群 ID 白名单未命中或 `roomWecomChatId` 为空而拒绝调用 `sop-reply`。

## 成功标准 *(必填)*

- **SC-001**：`skuId=4` 单聊且 `aiStatus=1`、`aiAutoReview=1` 时，`sop-reply` 调用路径保持可用。
- **SC-002**：`skuId=5` 单聊或群聊时，不因开关配置为空、开关关闭、群列表为空或群 ID 未命中被拦截。
- **SC-003**：除 `skuId=5` 外，任意 SKU 且 `aiStatus!=1` 时，不发生任何 `sop-reply` FC 调用。
- **SC-004**：除 `skuId=5` 外，任意 SKU 且 `aiAutoReview!=1` 时，不发生任何 `sop-reply` FC 调用。
- **SC-005**：除 `skuId=5` 外，配置为空、异常或字段缺失时，不发生任何 `sop-reply` FC 调用。
- **SC-006**：异步 SOP 调用路径和同步 SOP 评估路径都受同一门禁控制。
- **SC-007**：非 SOP 点评链路行为不回归。
- **SC-008**：`data-RC/juzi-service` 编译通过，后续实现无新增接口或数据库表。
- **SC-009**：除 `skuId=5` 外，任意 SKU 群聊且 `chatList` 包含当前 `roomWecomChatId`、两个开关均开启时，`sop-reply` 调用路径保持可用。
- **SC-010**：除 `skuId=5` 外，任意 SKU 群聊但 `chatList` 未命中、为空或 `roomWecomChatId` 为空时，不发生任何 `sop-reply` FC 调用。
- **SC-011**：后续实现包含可执行的单元测试，覆盖 `skuId=4`、`skuId=5` 例外、其他 SKU、开关全开、AI 关闭、作业点评关闭、群 ID 命中、群 ID 未命中、空群列表、空群 ID、单聊和非 SOP 链路场景。

## 假设

- 开启值沿用现有枚举口径：`1` 表示开启，其他值或空值均视为未开启。
- 开关配置来源沿用 `AppTask.java` 参考逻辑中的 `ai_auto_review_config:{campDateId}:{empId}` 缓存和 `/kk/cms/ai/getAiAutoReviewConfig` 查询能力，后续实现可在 `juzi-service` 内补齐等价 DTO / 工具方法。
- 群聊判断字段沿用现有上下文中的 `isGroup` / `roomWecomChatId` 语义。
- 群 ID 匹配采用参考逻辑的精确包含判断：`chatList.contains(roomWecomChatId)`。
- 本需求只限制是否调用 `sop-reply`，不调整 SOP 配置表、路由规则表、AI 总开关后台接口或 `fc/sop-reply` 内部逻辑。
- 门禁命中关闭状态时，后续是否通用聊天由现有路由 fallback 配置决定。

## 执行记录

### D001 - 文档记录

- 已新增本 Spec Kit 文档，记录 SOP 点评开关门禁需求。
- 本轮仅修改文档，未修改 `juzi-service` 代码。

### D002 - 群 ID 与单元测试补充

- 已补充判断是否需要 SOP 点评时必须校验 `roomWecomChatId`，逻辑仿照 `AppTask.java#isGroupOpen`。
- 已补充后续实现必须增加单元测试，覆盖开关门禁和群 ID 门禁。

### D003 - 全 SKU 范围补充（已被 D004 调整）

- 曾将门禁范围从钢琴 `skuId=4` 扩展为所有命中 SOP 点评的 SKU。
- 该范围已在 D004 中调整为 `skuId=5` 例外，除 `skuId=5` 外的其他 SOP SKU 仍必须校验同一套开关和群 ID 门禁。

### D004 - skuId=5 例外补充

- 已将 `skuId=5` 调整为 SOP 门禁例外，不校验开关状态和群 ID 白名单。
- 已明确除 `skuId=5` 外的其他 SOP SKU 仍需校验 AI 开关、作业点评开关和群 ID 门禁。
