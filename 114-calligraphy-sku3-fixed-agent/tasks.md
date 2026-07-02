# 任务清单：juzi-service 书法 SKU3 固定 Agent 路由

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标项目为 `C:\workspace\ju-chat\data-RC\juzi-service`。
- [x] T002 用代码搜索确认真实入口为 `MessageServiceImpl#doSendMessage`，现有钢琴雅琪特殊链路为 `YaqiAgentRouteService#buildPlanIfMatched`。
- [x] T003 确认关键参数来源：`skuId` 来自 `UserInfoDto.getSkuId()`，`msgType` 来自 `JuziMessageDto.getType()`，agent 下游读取来自 `RouteExecutionPlanDto.agentDecision.agentId`。
- [x] T004 确认配置来源：route 开关和灰度来自 `RouteFeatureProperties`，当前规则来自 `RouteConfigCache#getCurrentSnapshot(envCode)`，FC 函数名来自 `FcConfig.common_function_name`。
- [x] T005 确认旧逻辑：声乐默认分支在固定 helper 之前；固定 helper 未命中后继续异步 SOP fallback 和 `RouteOrchestrator`；FC payload 由 `DelayMessageServiceImpl` 统一构造。

**检查点**：T001-T005 已完成，可以进入风险门禁；尚未修改业务代码。

## Phase 2：风险门禁

- [x] T006 检查占位对象风险：书法分支未命中时必须返回空，不创建缺字段的 `RouteExecutionPlanDto`。
- [x] T007 检查调用后赋值风险：`skuId`、`aiDecision.strategy`、`agentDecision.agentId` 必须在传给 `DelayMessageServiceImpl` 前完整赋值。
- [x] T008 检查下游读取字段：`DelayMessageServiceImpl` 会读取 `skuId`、`aiDecision.strategy`、`agentDecision.agentId` 并写入 `sku_id`、`ai_strategy`、`agent_id`。
- [x] T009 检查外部行为影响：本次不新增 FC 调用、不改 MQ 基础字段、不改 Redis TTL、不改 DB 表；只改变书法 `GENERAL_CHAT` 的 agent 选择。
- [x] T010 记录业务语义确认点：默认书法按 `skuId=3` 命中，不要求 `speakerId`；默认仅 `GENERAL_CHAT` 接管，SOP/NOOP 不接管。
- [x] T011 建立测试映射：书法命中、SOP 跳过、通配规则、非书法不命中、钢琴雅琪回归、FC payload 参数断言。

**检查点**：T006-T011 已有明确结论；进入实现前等待用户确认本规格口径。

## Phase 3：实现

- [x] T012 按规格实现最小范围改动，优先复用或扩展 `YaqiAgentRouteService` 的 snapshot 匹配和 plan 构造逻辑。
- [x] T013 保持 `MessageServiceImpl` 调用顺序不变：声乐默认之后、异步 SOP 和通用 route 之前。
- [x] T014 确保书法 plan 写入 `skuId="3"`、`GENERAL_CHAT`、`agentId=7638948127407636514`。
- [x] T015 不修改 route 表结构、管理页面字段、FC 入参契约、私域 AI 或通用 AgentRouter。

## Phase 4：测试与验证

- [x] T016 更新 `YaqiAgentRouteServiceTest` 或新增对应测试，覆盖书法固定 agent 命中。
- [x] T017 覆盖书法 `SOP_REVIEW`/未命中配置跳过和 `skuId=*` 通配规则。
- [x] T018 更新 `DelayMessageServiceImplTest`，断言书法 FC payload 的 `agent_id`、`sku_id`、`ai_strategy` 和 `functionName=ai-reply`。
- [x] T019 运行目标 Maven 测试并记录结果。
- [x] T020 运行静态检查或 `diff --check`，确认无残留占位、旧口径或格式问题。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `114-calligraphy-sku3-fixed-agent` Spec Kit 文档，记录书法 `skuId=3` 固定 agent 到 FC `ai-reply` 的目标行为。
- 验证方式：静态读取 `YaqiAgentRouteService`、`MessageServiceImpl`、`DelayMessageServiceImplTest`、`RouteFeatureProperties`、`RouteConstants`、`SkuIdEnum` 和既有 `100-juzi-yaqi-fixed-agent` 文档。
- 自检结论：参数来源、调用顺序、旧逻辑保持、下游字段和测试映射已记录；业务代码尚未修改。

### D002 - 实现记录

- 实现内容：
  - 在 `YaqiAgentRouteService` 中新增书法 `CALLIGRAPHY_SKU_ID=3` 和 `CALLIGRAPHY_AGENT_ID=7638948127407636514`。
  - `skuId=3` 消息优先在 helper 内按 route snapshot 匹配当前 `msgType` 的 AI 规则；仅 `GENERAL_CHAT` 构造固定 agent plan。
  - 复用固定 agent plan 构造逻辑，钢琴雅琪仍按 `sku/category=4 + speakerId=113` 判定；书法不查询 Center、不依赖 `speakerId`。
  - 更新 `YaqiAgentRouteServiceTest` 覆盖书法命中、通配 sku 命中、SOP 跳过和钢琴雅琪回归。
  - 更新 `DelayMessageServiceImplTest` 断言书法 FC payload 中的 `functionName=ai-reply`、`agent_id`、`sku_id`、`ai_strategy`。
- 测试命令：
  - `mvn -DskipTests=false "-Dtest=YaqiAgentRouteServiceTest,DelayMessageServiceImplTest" test`
  - `mvn -DskipTests=false "-Dtest=YaqiAgentRouteServiceTest,DelayMessageServiceImplTest,MessageServiceImplPrivateDomainDoNotDisturbTest" test`
  - `git -C C:\workspace\ju-chat\data-RC diff --check -- juzi-service/src/main/java/com/drh/data/juzi/route/service/YaqiAgentRouteService.java juzi-service/src/test/java/com/drh/data/juzi/route/service/YaqiAgentRouteServiceTest.java juzi-service/src/test/java/com/drh/data/juzi/service/impl/DelayMessageServiceImplTest.java`
- 测试结果：
  - 首次聚焦测试通过，14 tests, 0 failures, 0 errors。
  - 含私域勿扰回归的聚焦测试通过，21 tests, 0 failures, 0 errors。
  - `diff --check` 通过，仅有 Git 换行风格提示。
- 自检结论：关键参数均在传给 `DelayMessageServiceImpl` 前赋值；未传递空 plan；未修改 `MessageServiceImpl` 调用顺序；未新增 DB/FC/MQ/Redis 契约。

### D003 - 纠正记录

- 当前暂无纠正记录。
- 后续如用户补充、测试失败或代码审查发现问题，将追加新的 Dxxx 记录并同步相关文档。
