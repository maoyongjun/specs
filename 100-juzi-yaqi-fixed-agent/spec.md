# 功能规格：juzi-service 钢琴雅琪固定 Agent 独立链路

**功能目录**：`100-juzi-yaqi-fixed-agent`  
**创建日期**：`2026-06-18`  
**状态**：Implemented
**输入**：在 `C:\workspace\ju-chat\data-RC\juzi-service` 新增独立链路。`campDateId -> speakerId` 需要缓存；`speakerId=113` 是雅琪。钢琴雅琪命中 `GENERAL_CHAT` 时固定 agentId 为 `7638948127407636514`，调用函数计算 `ai-reply`。不调用通用 agentId 获取接口，也不调用私域接口；旧链路不改变。D003 追加：不新增 `speakerId` 独立配置字段、不改 route 表结构，复用作业点评 SOP 现有 `matchKey/matchValue` 多条件能力，例如 `currentDay&&homeworkDayRelation&&speakerId`，运行时补齐 `speakerId` 且使用 String 精确相等。

## 背景

- 当前问题：钢琴雅琪消息在配置化通用聊天路径中仍可能使用通用 agentId 配置，不能固定到雅琪新 agent。
- 当前行为：钢琴消息先经过旧权限、SOP/route 配置，`RouteOrchestrator` 会同时按配置解析 ai 策略和 agentId，`DelayMessageServiceImpl` 再写入 `agent_id`。
- 目标行为：钢琴雅琪 `speakerId=113` 且消息类型策略为 `GENERAL_CHAT` 时，独立覆盖本次 `agent_id=7638948127407636514`，并通过 `fc.common_function_name/common_service_name` 调用 `ai-reply`。
- D003 当前缺口：作业点评 SOP 运行时没有稳定把 `speakerId` 放入 `routeParams`，配置方即使写 `matchKey=speakerId` 或组合条件也可能无法命中。
- D003 目标行为：`juzi-service` 发起 SOP FC 调用、`sop-reply` 入口自动参数补齐时都能提供 String 化 `speakerId`，现有 `&&` 多条件匹配可按主讲老师区分。
- 非目标：不修改私域 AI 配置和白名单链路；不改变 SOP/NOOP 策略；不修改 `fc/ai-reply`；D003 不新增 route 独立字段、不新增 `speaker_id` 列、不修改 `route-config` AI/Agent 规则字段。

## 用户场景与测试

### 用户故事 1 - 钢琴雅琪通用聊天固定 Agent（优先级：P1）

当学员消息所属营期为钢琴雅琪老师，且消息类型配置策略为 `GENERAL_CHAT` 时，系统必须使用固定新 agent 调用 `ai-reply`。

**独立测试**：构造 `skuId=4`、`campDateId=1001`、Center 返回 `category=4/speakerId=113`、route aiReplyRules 对当前 `msgType` 返回 `GENERAL_CHAT`，断言输出 plan 的 `agentDecision.agentId=7638948127407636514`，FC payload 也包含该 `agent_id`。

**验收场景**：

1. **Given** `skuId=4`、`speakerId=113` 且 `msgType=7` 配置为 `GENERAL_CHAT`，**When** 消息进入旧权限后的钢琴路径，**Then** 调用 `ai-reply` 且 `agent_id=7638948127407636514`。
2. **Given** 同一营期重复消息，**When** 第二次解析营期，**Then** 优先命中本地或 Redis 缓存，不重复请求 Center。

### 用户故事 2 - 非 GENERAL_CHAT 不改变旧链路（优先级：P1）

当同一消息类型策略为 `SOP_REVIEW`、`NOOP` 或未命中配置时，雅琪链路不接管，继续执行原有 SOP/route 逻辑。

**独立测试**：构造 `speakerId=113` 但 route aiReplyRules 返回 `SOP_REVIEW` 或 `NOOP`，断言 helper 返回空，`MessageServiceImpl` 继续旧链路。

**验收场景**：

1. **Given** 钢琴雅琪消息类型配置为 `SOP_REVIEW`，**When** 消息进入雅琪 helper，**Then** helper 不返回 plan，后续旧 SOP/route 正常执行。
2. **Given** 当前 route 灰度未命中或配置不存在，**When** 消息进入雅琪 helper，**Then** 不调用固定 agent，旧链路不变。

### 用户故事 3 - 私域和非雅琪不回归（优先级：P1）

私域白名单命中的消息继续走私域链路；非雅琪钢琴、声乐和无权限消息不因本次改动改变行为。

**独立测试**：通过 `MessageServiceImpl` 测试断言雅琪 helper 不调用 `PrivateDomainAiConfigService#getAgentId`，私域命中仍优先返回；非雅琪返回空。

### 用户故事 4 - SOP 多条件按 speakerId 区分（优先级：P1）

运营在作业点评配置中使用 `currentDay&&homeworkDayRelation&&speakerId` 等组合条件时，系统应能用当前营期主讲老师 `speakerId` 命中特定策略。

**独立测试**：构造 `matchKey=currentDay&&homeworkDayRelation&&speakerId`、`matchValue=1&&CURRENT&&113`，实际参数 `speakerId="113"` 命中，`speakerId="110"` 不命中。

**验收场景**：

1. **Given** 上游 SOP FC 入参已有 `routeParams.speakerId=113`，**When** `sop-reply` 自动补参，**Then** 保留上游值，不二次覆盖。
2. **Given** 上游未传 `speakerId` 但 `userMsg.camp_date_id` 可查到 Center 营期信息，**When** `sop-reply` 构造路由参数，**Then** 写入 `speakerId` 的 String 值。
3. **Given** `matchKey` 包含 `speakerId` 且运行时实际值为数字来源，**When** 执行匹配，**Then** 使用 String 值精确相等，避免 Integer/String 类型不一致。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `campDateId`：来源 `UserInfoDto.getCampDateId()`；旧权限查询完成后已有值；下游用于 Center 查询和缓存 key。
  - `skuId`：优先来源 `UserInfoDto.getSkuId()`；为空时用 `CampInfo.category` 兜底判定钢琴。
  - `speakerId`：来源 `CenterUtil.getCampInfoByCampDateId(campDateId).getSpeakerId()`；查询后写入 Redis + 本地缓存。
  - `msgType`：来源 `JuziMessageDto.getType()`；用于匹配 route `aiReplyRules.msgType`。
  - `agent_id`：雅琪 `GENERAL_CHAT` 命中时当前层固定为 `7638948127407636514`；下游 `DelayMessageServiceImpl#createJSONObject` 写入 FC payload。
  - D003 `speakerId routeParam`：来源优先为上游 `routeParams.speakerId` 或 `userMsg.speakerId`；缺失时通过 `camp_date_id` 查询 Center，统一 `String.valueOf(...).trim()` 后写入。
- 下游读取字段清单：
  - `YaqiAgentRouteService` 读取 `campDateId`、`skuId/category`、`speakerId`、`msgType`、`aiReplyRules.primaryStrategy`。
  - `DelayMessageServiceImpl#createJSONObject` 读取 `RouteExecutionPlanDto.skuId`、`aiDecision.strategy`、`agentDecision.agentId`。
  - D003 `DefaultSopRouteEvaluator` 与 `MessageServiceImpl` 异步 SOP 调用写入 `routeParams.speakerId`；`SopReply.resolveRouteParams` 与 `SopConfigSender` 读取该参数参与 `&&` 多条件匹配。
- 空对象 / 占位对象风险：
  - Center 响应非法、无 `data` 或 `category/speakerId` 均为空时返回 `null`，不缓存空对象。
  - 未命中雅琪链路时不构造空 `RouteExecutionPlanDto`。
- 调用顺序风险：
  - 雅琪 helper 必须放在私域分支之后、旧权限通过之后、现有 SOP/route 之前。
  - 不允许使用 `RouteOrchestrator` 完整构建 plan，因为它会调用通用 `AgentRouter` 获取配置化 agentId。
- 旧逻辑保持：
  - 私域、Dong 直连、无权限跳过、旁路验证、声乐默认、SOP/NOOP、延迟 MQ、人工回复静默、请勿打扰等行为不变。
- 需要用户确认的设计选择：
  - 已确认：命中条件为 `speakerId=113 + 钢琴 sku/category=4`。
  - 已确认：只对配置策略为 `GENERAL_CHAT` 的消息类型覆盖 agentId。

## 边界情况

- `campDateId` 为空：不查询 Center，不接管，继续旧链路。
- Center 查询失败、`sys_domain` 缺失、响应非法：不缓存，不接管，继续旧链路。
- `speakerId` 非 113：不接管。
- `speakerId=113` 但 `skuId/category` 非 4：不接管。
- `SOP_REVIEW`、`NOOP`、未命中消息类型配置：不接管。
- route 功能未开启或灰度未命中：不接管。
- Redis 异常：记录日志并降级走 Center 查询；Center 成功后尽量刷新本地缓存。
- D003 `speakerId` 获取失败或为空：不写入 `speakerId` 参数，只命中不带 `speakerId` 的旧配置。
- D003 上游已传 `speakerId`：优先保留上游值，避免因 Center 查询失败或延迟覆盖正确上下文。

## 需求

### 功能需求

- **FR-001**：系统 MUST 新增 `CenterUtil.getCampInfoByCampDateId(Integer campDateId)`，解析 `category` 和 `speakerId`。
- **FR-002**：系统 MUST 对成功解析的 `campDateId -> CampInfo(category/speakerId)` 做 Redis + 本地 TTL 缓存，TTL 为 35 分钟。
- **FR-003**：系统 MUST 在 `skuId=4` 或 `CampInfo.category=4` 且 `speakerId=113` 时，继续读取消息类型配置策略。
- **FR-004**：系统 MUST 仅在消息类型策略为 `GENERAL_CHAT` 时固定 `agent_id=7638948127407636514`。
- **FR-005**：系统 MUST NOT 调用私域 agent 配置接口或通用 AgentRouter 来获取本链路 agentId。
- **FR-006**：系统 MUST 在 `SOP_REVIEW`、`NOOP`、未命中配置或查询失败时保持旧链路。
- **FR-007**：单元测试 MUST 断言 `agent_id`、`functionName`、缓存命中和私域配置接口未调用。
- **FR-008**：D003 MUST 不新增 `speakerId` 独立配置字段、不新增数据库列、不修改 `route-config` AI/Agent 规则模型。
- **FR-009**：D003 MUST 在 `juzi-service` 构造 SOP FC 入参时写入 String 化 `routeParams.speakerId` 和 `userMsg.speakerId`。
- **FR-010**：D003 MUST 在 `sop-reply` 自动路由参数中补齐 `speakerId`，且上游已传值优先。
- **FR-011**：D003 MUST 通过现有 `matchKey/matchValue` 的 `&&` 多条件能力完成 `speakerId` 匹配，普通参数使用 String 精确相等。

## 成功标准

- **SC-001**：钢琴雅琪 `GENERAL_CHAT` 消息的 FC payload 中 `agent_id=7638948127407636514`。
- **SC-002**：`SOP_REVIEW`、`NOOP` 和非雅琪消息不被雅琪链路接管。
- **SC-003**：Center 查询成功后同一 `campDateId` 在 TTL 内复用缓存。
- **SC-004**：目标单元测试和 `diff --check` 通过。
- **SC-005**：配置 `currentDay&&homeworkDayRelation&&speakerId` 时，`speakerId=113` 和 `speakerId=110` 可区分命中。

## 假设

- `speakerId=113` 表示雅琪。
- `category=4` 表示钢琴。
- 生产 `fc.common_function_name` 配置为 `ai-reply`；测试中显式设置为 `ai-reply` 验证下游函数名。
- D003 多条件分隔符沿用现有 `&&`；`speakerId` 配置值和实际值统一按 String 精确相等。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已记录纠正口径：这是独立链路，不修改私域链路。

### D002 - 实现记录

- 已在 `CenterUtil` 新增 `getCampInfoByCampDateId(Integer campDateId)`、`parseCampInfo` 和 `CampInfo`，Center `data` 支持 JSON 对象和 JSON 字符串，非法响应返回空且不写缓存。
- 已新增 `YaqiAgentRouteService`，对成功解析的 `campDateId -> CampInfo(category/speakerId)` 做 Redis + 本地 35 分钟 TTL 缓存。
- 已在 `MessageServiceImpl#doSendMessage` 的声乐默认分支之后、现有 SOP/route 分支之前接入雅琪独立链路；私域入口、旧权限、旁路验证、自发消息、声乐默认和旧 SOP/route 顺序保持不变。
- 雅琪独立链路只读取 route snapshot 的 `aiReplyRules` 判断当前消息类型策略；仅 `GENERAL_CHAT` 构造本次专用 plan 并固定 `agent_id=7638948127407636514`，不调用私域 agent 配置接口，也不调用通用 `AgentRouter` 获取 agentId。
- 目标测试通过：`mvn -pl juzi-service -DskipTests=false "-Dtest=CenterUtilTest,YaqiAgentRouteServiceTest,MessageServiceImplPrivateDomainDoNotDisturbTest,DelayMessageServiceImplTest" test`，20 tests, 0 failures, 0 errors。
- 全量 `juzi-service` 测试通过：`mvn -pl juzi-service -DskipTests=false test`，159 tests, 0 failures, 0 errors, 1 skipped。
- `diff --check` 通过：`data-RC` 仅有 Git 换行提示；`specs/100-juzi-yaqi-fixed-agent` 无输出。

### D003 - speakerId 多条件路由追加记录

- 触发原因：用户要求不新增 `speakerId` 配置字段，复用现有 `matchKey/matchValue` 多参数组合能力区分主讲老师。
- 修正口径：`speakerId` 只作为运行时路由参数补齐，不新增 `speaker_id` 列，不修改 `route-config` AI/Agent 规则 DTO/实体。
- 实现内容：`juzi-service` 同步/异步 SOP FC 入参补齐 `routeParams.speakerId` 和 `userMsg.speakerId`；`sop-reply` 支持 `WebChatVoiceDto.speakerId`，未传时按 `camp_date_id` 查询 Center 补齐；`SopConfigSender` 从 `userMsg` 补充 `speakerId` 并继续使用现有 `&&` 多条件解析。
- String 比较：雅琪固定链路的 `speakerId=113` 判断改为 String 相等；SOP 普通条件使用 String 参数表精确相等，避免 Integer/String 类型不一致。
- 验证结果：`mvn -pl juzi-service -DskipTests=false "-Dtest=DefaultSopRouteEvaluatorTest,MessageServiceImplSopGateTest,YaqiAgentRouteServiceTest" test` 通过，11 tests, 0 failures, 0 errors。
- 验证结果：`mvn -pl sop-reply -DskipTests=false "-Dtest=SopConfigSenderTest#shouldMatchSpeakerIdInAndRouteConditions" test` 通过，1 test, 0 failures, 0 errors。
- 静态检查：`data-RC diff --check`、`fc` 本次相关文件 `diff --check`、`specs/100-juzi-yaqi-fixed-agent diff --check` 均通过，仅有 Git 换行提示。
