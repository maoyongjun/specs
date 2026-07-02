# 功能规格：juzi-service 书法 SKU3 固定 Agent 路由

**功能目录**：`114-calligraphy-sku3-fixed-agent`  
**创建日期**：`2026-07-01`  
**状态**：Implemented  
**输入**：用户要求在 `C:\workspace\ju-chat\data-RC\juzi-service` 中，对书法 `sku=3` 按“钢琴的雅琪”同样方式路由到新的 agent：`7638948127407636514`；补充说明目标下游为函数计算 `ai-reply`。

## 背景

- 当前问题：现有特殊固定 agent 链路只覆盖钢琴雅琪：`sku/category=4 + speakerId=113 + GENERAL_CHAT` 时固定 `agent_id=7638948127407636514`。书法 `skuId=3` 当前会继续进入通用 SOP/route 逻辑，可能使用通用配置化 agent。
- 当前行为：`MessageServiceImpl#doSendMessage` 在声乐默认分支之后优先调用 `YaqiAgentRouteService#buildPlanIfMatched`；只有钢琴雅琪命中时构造 `RouteExecutionPlanDto`，然后由 `DelayMessageServiceImpl#sendDelayMessage` 按 `fc.common_service_name/fc.common_function_name` 调用函数计算，生产目标函数为 `ai-reply`。
- 目标行为：书法 `skuId=3` 在当前消息类型配置策略为 `GENERAL_CHAT` 时，也固定生成 `agent_id=7638948127407636514` 的路由计划，并继续复用现有 `DelayMessageServiceImpl` 调用函数计算 `ai-reply`。
- 非目标：不修改函数计算 `ai-reply`；不新增数据库字段或 route 表结构；不改私域 AI、Dong 直连、声乐默认、SOP/NOOP、人工回复静默、请勿打扰、延迟 MQ、route 配置管理页面的契约。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 书法通用聊天固定 Agent（优先级：P1）

当学员消息所属商品为书法 `skuId=3`，且当前消息类型配置策略为 `GENERAL_CHAT` 时，系统必须像钢琴雅琪链路一样固定使用指定 agent 调用 `ai-reply`。

**独立测试**：构造 `UserInfoDto.skuId=3`、当前 route snapshot 中 `aiReplyRules` 对 `skuId=3/msgType` 命中 `GENERAL_CHAT`，断言 helper 返回 `routeApplied=true`、`skuId="3"`、`agentDecision.agentId=7638948127407636514`；再通过 `DelayMessageServiceImpl` 断言 FC payload 中 `agent_id`、`sku_id`、`ai_strategy` 正确。

**验收场景**：

1. **Given** `skuId=3` 且 `msgType=7` 配置为 `GENERAL_CHAT`，**When** 消息进入旧权限后的非声乐路径，**Then** 调用 `ai-reply` 且 payload 包含 `agent_id=7638948127407636514`、`sku_id=3`。
2. **Given** route rule 使用 `skuId=*` 且当前 `skuId=3`、`msgType` 命中 `GENERAL_CHAT`，**When** 书法消息进入固定 agent helper，**Then** 允许命中通配规则并固定 agent。

### 用户故事 2 - 非 GENERAL_CHAT 不接管旧链路（优先级：P1）

当书法消息当前策略为 `SOP_REVIEW`、`NOOP` 或未命中配置时，固定 agent helper 不应构造 plan，后续继续使用现有 SOP/route 行为。

**独立测试**：构造 `skuId=3` 但 route aiReplyRules 返回 `SOP_REVIEW` 或不存在匹配规则，断言 helper 返回空，`MessageServiceImpl` 后续仍执行现有 `tryInvokeSopRouteAsyncWhenNoopFallback` 和 `routeOrchestrator.buildPlan`。

**验收场景**：

1. **Given** `skuId=3` 的当前消息类型配置为 `SOP_REVIEW`，**When** 消息进入固定 agent helper，**Then** helper 不返回 plan，后续 SOP 逻辑保持不变。
2. **Given** route 功能未开启、灰度未命中或 snapshot 为空，**When** 书法消息进入 helper，**Then** 不固定 agent，旧链路继续处理。

### 用户故事 3 - 钢琴雅琪和其他 SKU 不回归（优先级：P1）

现有钢琴雅琪逻辑必须保持不变；非书法、非钢琴雅琪消息不能因本次改动被固定到新 agent。

**独立测试**：保留现有 `YaqiAgentRouteServiceTest` 钢琴雅琪用例；新增非书法非雅琪用例，断言 `skuId=5`、`skuId=4 speakerId!=113` 不命中。

**验收场景**：

1. **Given** `skuId=4/category=4/speakerId=113` 且策略为 `GENERAL_CHAT`，**When** 消息进入 helper，**Then** 仍固定 `agent_id=7638948127407636514` 且 `sku_id=4`。
2. **Given** `skuId=5` 或 `skuId=4/speakerId!=113`，**When** 消息进入 helper，**Then** 不按书法分支固定 agent。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `skuId`：来源 `UserInfoDto.getSkuId()`；旧权限查询完成后已赋值；书法匹配在当前 helper 中读取并转为 String 下游写入 `RouteExecutionPlanDto.skuId`。
  - `msgType`：来源 `JuziMessageDto.getType()`；用于匹配 route `AiReplyRouteRuleDto.msgType`。
  - `route snapshot/version`：来源 `RouteConfigCache#getCurrentSnapshot(envCode)`；受 `route.feature.enable`、`grayEnable`、`grayPercent`、`envCode` 控制。
  - `primaryStrategy`：来源匹配到的 `AiReplyRouteRuleDto.primaryStrategy`；仅 `GENERAL_CHAT` 允许固定 agent。
  - `agent_id`：书法 `GENERAL_CHAT` 命中时当前层固定为 `7638948127407636514`；下游由 `DelayMessageServiceImpl#createJSONObject` 写入 FC payload。
- 下游读取字段清单：
  - `YaqiAgentRouteService#buildPlanIfMatched` 读取 `JuziMessageDto.type`、`UserInfoDto.skuId/campDateId`、Center `category/speakerId`、route `aiReplyRules`。
  - 书法新增逻辑需要读取 `UserInfoDto.skuId`、`JuziMessageDto.type`、route `aiReplyRules`，并写出 `RouteExecutionPlanDto.routeApplied/routeVersion/skuId/aiDecision/agentDecision`。
  - `DelayMessageServiceImpl#sendDelayMessage/createJSONObject` 读取 `RouteExecutionPlanDto.skuId`、`AiReplyDecisionDto.strategy`、`AgentDecisionDto.agentId`，最终写入 FC payload 的 `sku_id`、`ai_strategy`、`agent_id`。
- 空对象 / 占位对象风险：
  - route snapshot 为空、version 为空、aiReplyRules 为空时不构造空 plan，返回空并继续旧链路。
  - 不允许只创建 `RouteExecutionPlanDto` 但缺失 `aiDecision` 或 `agentDecision` 后继续传给 `DelayMessageServiceImpl`。
- 调用顺序风险：
  - 固定 agent helper 仍应位于声乐默认分支之后、异步 SOP fallback 和 `routeOrchestrator.buildPlan` 之前。
  - 不允许先调用通用 `RouteOrchestrator/AgentRouter` 再覆盖 agent，因为下游可能已经基于旧 plan 做日志、告警或分支判断。
- 旧逻辑保持：
  - 私域白名单、Dong 直连、自发消息、无权限跳过、旁路验证、声乐默认、homeworkReviewing 跳过、SOP/NOOP、route fallback 告警、延迟 MQ、Redis TTL 和 Center 缓存行为保持不变。
- 需要用户确认的设计选择：
  - 本规格默认：书法只按 `skuId=3` 命中，不额外要求 `speakerId`。
  - 本规格默认：和钢琴雅琪一致，只在 route 当前消息类型策略为 `GENERAL_CHAT` 时固定 agent；`SOP_REVIEW`/`NOOP` 不接管。

## 边界情况

- `UserInfoDto` 为空或 `skuId` 为空：不命中书法分支，继续旧链路。
- `skuId=3` 但 route 功能关闭、灰度未命中、snapshot 为空、规则为空：不命中书法分支，继续旧链路。
- `skuId=3` 且 `msgType` 为空：只允许命中 `msgType=-1` 的通配规则；否则继续旧链路。
- 匹配规则 `skuId=*`：允许作为书法上下文规则命中。
- 匹配规则 `primaryStrategy` 不是 `GENERAL_CHAT`：不固定 agent。
- 书法分支不依赖 Center `speakerId`，避免额外远程调用和缓存空对象风险。
- Redis、Center 缓存仍仅用于钢琴雅琪 speaker 判断，本次不改变其 TTL 和 key。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `skuId=3` 且当前 route AI 规则命中 `GENERAL_CHAT` 时，构造固定 agent 路由计划。
- **FR-002**：系统 MUST 将书法固定 agent plan 的 `skuId` 写为 `"3"`，`aiDecision.strategy` 写为 `GENERAL_CHAT`，`agentDecision.agentId` 写为 `7638948127407636514`。
- **FR-003**：系统 MUST 复用现有 `DelayMessageServiceImpl#sendDelayMessage` 和 `fc.common_function_name` 调用函数计算 `ai-reply`，不新增 FC 调用路径。
- **FR-004**：系统 MUST 在 `SOP_REVIEW`、`NOOP`、未命中配置、灰度未命中、route 未开启时返回空并保持旧链路。
- **FR-005**：系统 MUST NOT 改变钢琴雅琪 `sku/category=4 + speakerId=113 + GENERAL_CHAT` 的固定 agent 行为。
- **FR-006**：系统 MUST NOT 修改私域 AI、通用 AgentRouter、route 表结构、MQ body 基础契约或 FC 入参契约。
- **FR-007**：单元测试 MUST 覆盖书法命中、书法 SOP 跳过、通配 sku 命中、非书法不命中、钢琴雅琪回归和 FC payload 参数断言。

## 成功标准 *(必填)*

- **SC-001**：书法 `skuId=3 + GENERAL_CHAT` 消息的 FC payload 包含 `agent_id=7638948127407636514`、`sku_id=3`、`ai_strategy=GENERAL_CHAT`。
- **SC-002**：书法 `SOP_REVIEW`、`NOOP`、未命中配置和 route 功能关闭场景不被固定 agent helper 接管。
- **SC-003**：现有钢琴雅琪固定 agent 单元测试继续通过。
- **SC-004**：目标 Maven 测试通过，并记录测试命令和结果。
- **SC-005**：本次改动不新增 DB DDL、外部接口或函数计算参数字段。

## 假设

- `skuId=3` 表示书法，尽管当前 `SkuIdEnum` 只枚举了钢琴 `4` 和声乐 `5`。
- `7638948127407636514` 是书法固定 agent 目标 ID，且与现有钢琴雅琪固定 agent ID 相同。
- 生产环境 `fc.common_function_name` 配置为 `ai-reply`；代码层只复用该配置，不硬编码函数名。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成代码事实确认：目标项目为 `data-RC\juzi-service`，核心入口为 `MessageServiceImpl#doSendMessage`，现有特殊链路为 `YaqiAgentRouteService`，FC payload 由 `DelayMessageServiceImpl` 构造。
- 已完成历史问题防漏分析和 Phase 1 / Phase 2 门禁。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 已在 `YaqiAgentRouteService#buildPlanIfMatched` 增加书法 `skuId=3` 分支：命中后按 route snapshot 的当前 `msgType` 查找 AI 规则，仅 `GENERAL_CHAT` 构造固定 agent plan；`SOP_REVIEW`、`NOOP`、未命中配置、route 未开启或灰度未命中时返回空并继续旧链路。
- 已将固定 agent plan 构造抽成复用方法，钢琴雅琪仍按 `sku/category=4 + speakerId=113` 判定，书法不查询 Center、不依赖 `speakerId`。
- 已新增常量 `CALLIGRAPHY_SKU_ID=3`、`CALLIGRAPHY_AGENT_ID=7638948127407636514`，并确保书法 plan 写入 `skuId="3"`、`aiDecision.strategy=GENERAL_CHAT`、`agentDecision.agentId=7638948127407636514`。
- 已更新 `YaqiAgentRouteServiceTest`，覆盖书法固定 agent 命中、通配 `skuId=*` 命中、书法 `SOP_REVIEW` 跳过，并保留钢琴雅琪回归覆盖。
- 已更新 `DelayMessageServiceImplTest`，断言书法 FC payload 的 `functionName=ai-reply`、`agent_id=7638948127407636514`、`sku_id=3`、`ai_strategy=GENERAL_CHAT`。
- 验证结果：`mvn -DskipTests=false "-Dtest=YaqiAgentRouteServiceTest,DelayMessageServiceImplTest,MessageServiceImplPrivateDomainDoNotDisturbTest" test` 通过，21 tests, 0 failures, 0 errors。
- 静态检查：`git -C C:\workspace\ju-chat\data-RC diff --check -- juzi-service/src/main/java/com/drh/data/juzi/route/service/YaqiAgentRouteService.java juzi-service/src/test/java/com/drh/data/juzi/route/service/YaqiAgentRouteServiceTest.java juzi-service/src/test/java/com/drh/data/juzi/service/impl/DelayMessageServiceImplTest.java` 通过，仅有 Git 换行风格提示。
- 自检结论：本次未修改 `MessageServiceImpl` 入口调用顺序，未新增 DB/FC/MQ/Redis 契约，私域勿扰相关聚焦测试通过。

### D003 - 纠正记录

- 当前暂无纠正记录。
- 后续如用户补充、测试失败、代码审查发现参数遗漏或调用顺序问题，将追加新的 Dxxx 记录，并同步 `spec.md`、`tasks.md`、`AGENTS.md` 和 `checklists/requirements.md`。
