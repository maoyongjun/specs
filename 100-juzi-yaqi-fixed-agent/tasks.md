# 任务清单：juzi-service 钢琴雅琪固定 Agent 独立链路

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标项目为 `data-RC\juzi-service`。
- [x] T002 确认真实入口为 `MessageServiceImpl#doSendMessage`。
- [x] T003 确认私域入口 `handlePrivateDomainAiIfMatched` 位于旧权限前，本需求不得修改。
- [x] T004 确认通用 agentId 来源为 `RouteOrchestrator -> AgentRouter`，本需求不得调用该路径取 agentId。
- [x] T005 确认 FC payload 由 `DelayMessageServiceImpl#createJSONObject` 读取 `RouteExecutionPlanDto.agentDecision.agentId`。

## Phase 2：风险门禁

- [x] T006 检查空对象风险：Center 无效响应返回 `null`，不缓存空对象。
- [x] T007 检查调用后赋值风险：固定 agentId 在构造 plan 时已赋值，下游调用前可读。
- [x] T008 检查下游字段：`sku_id`、`ai_strategy`、`agent_id` 均来自本次专用 plan。
- [x] T009 检查旧链路影响：未命中雅琪 `GENERAL_CHAT` 时 helper 返回空，继续旧 SOP/route。
- [x] T010 检查外部调用影响：新增 Center 查询和 Redis 缓存，失败降级不接管。
- [x] T011 建立测试映射：Center 解析、缓存、helper 命中/跳过、FC payload、私域配置不调用。

## Phase 3：实现

- [x] T012 在 `CenterUtil` 新增 `getCampInfoByCampDateId`、`parseCampInfo` 和 `CampInfo`。
- [x] T013 新增 `YaqiAgentRouteService`，封装 `campDateId -> CampInfo` 缓存。
- [x] T014 在 `YaqiAgentRouteService` 中按 `sku/category=4`、`speakerId=113`、`msgType` 和 `GENERAL_CHAT` 构造专用 plan。
- [x] T015 在 `MessageServiceImpl` 声乐默认分支之后、SOP/route 之前接入雅琪 helper。
- [x] T016 保持私域入口、SOP/NOOP、非雅琪和异常降级行为不变。

## Phase 4：测试与验证

- [x] T017 新增 `CenterUtilTest` 覆盖 JSON 对象、JSON 字符串和非法响应。
- [x] T018 新增 `YaqiAgentRouteServiceTest` 覆盖固定 agent、SOP 跳过、非雅琪跳过、非钢琴跳过、Redis 和本地缓存。
- [x] T019 更新 `DelayMessageServiceImplTest` 断言雅琪 payload 的 `agent_id` 和 `functionName=ai-reply`。
- [x] T020 更新 `MessageServiceImplPrivateDomainDoNotDisturbTest` 断言雅琪 helper 不调用私域 agent 配置。
- [x] T021 运行目标 Maven 测试并记录结果。
- [x] T022 运行完整 `juzi-service` 测试并记录结果。
- [x] T023 运行 `diff --check` 并记录结果。

## Phase 5：D003 speakerId 多条件路由

- [x] T024 确认不新增 `speakerId` 独立配置字段，不修改 route 表结构。
- [x] T025 确认 `SopConfigSender` 已支持 `&&` 拆分 `matchKey/matchValue`，普通条件使用 String 参数匹配。
- [x] T026 确认 `juzi-service` 已有 `CenterUtil.getCampInfoByCampDateId` 可获取 `speakerId`。
- [x] T027 确认 `sop-reply` 当前未自动补齐 `speakerId`，是本次运行时缺口。
- [x] T028 在 `juzi-service` SOP FC 入参补齐 `routeParams.speakerId` 和 `userMsg.speakerId`。
- [x] T029 在 `sop-reply` 增加 `WebChatVoiceDto.speakerId` 并自动补齐 route param。
- [x] T030 更新 `homework-config.html` matchKey 示例，提示 `speakerId` 多条件组合。
- [x] T031 增加/更新单元测试覆盖 `speakerId` String 精确匹配和 FC payload。
- [x] T032 运行聚焦测试和 `diff --check`。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `100-juzi-yaqi-fixed-agent` Spec Kit 文档，记录独立链路和纠正口径。
- 验证方式：静态读取消息入口、route 配置、私域配置和 FC payload 构造代码。
- 自检结论：关键参数来源、调用顺序、旧逻辑保持和测试映射已记录。

### D002 - 实现记录

- 执行内容：
  - 新增 `CenterUtil.getCampInfoByCampDateId(Integer campDateId)`、`parseCampInfo` 和 `CampInfo`，支持 Center `data` 为 JSON 对象或 JSON 字符串。
  - 新增 `YaqiAgentRouteService`，封装 `campDateId -> CampInfo(category/speakerId)` Redis + 本地 TTL 缓存，TTL 35 分钟。
  - 在 `MessageServiceImpl#doSendMessage` 的声乐默认分支之后、现有 SOP/route 分支之前接入雅琪独立链路。
  - 命中 `sku/category=4 + speakerId=113 + GENERAL_CHAT` 时构造本次专用 `RouteExecutionPlanDto`，固定 `agent_id=7638948127407636514`。
  - 未命中、`SOP_REVIEW`、`NOOP`、灰度未命中、配置缺失或 Center 失败时返回空，继续旧链路。
- 验证结果：
  - `mvn -pl juzi-service -DskipTests=false "-Dtest=CenterUtilTest,YaqiAgentRouteServiceTest,MessageServiceImplPrivateDomainDoNotDisturbTest,DelayMessageServiceImplTest" test` 通过；20 tests, 0 failures, 0 errors。
  - `mvn -pl juzi-service -DskipTests=false test` 通过；159 tests, 0 failures, 0 errors, 1 skipped。
  - `git -C C:\workspace\ju-chat\data-RC diff --check` 通过；仅有 Git 换行提示。
  - `git -C C:\workspace\ju-chat\specs diff --check -- 100-juzi-yaqi-fixed-agent` 通过。

### D003 - speakerId 多条件路由文档记录

- 执行内容：
  - 复查 `fc\sop-reply` 发送链路和 `data-RC\juzi-service` 配置链路，确认 `matchKey/matchValue` 可承载 `speakerId` 多条件，不需要新增字段。
  - 确认缺口是运行时未稳定注入 `speakerId`，导致配置 `currentDay&&homeworkDayRelation&&speakerId` 时缺少实际参数。
  - 确认比较口径为 `String.valueOf(speakerId).trim()` 后参与普通条件精确相等。
- 自检结论：D003 可在不改表结构、不改 `route-config` AI/Agent 字段的前提下，通过补齐 SOP 路由参数实现。
- 实现结果：
  - `juzi-service` 的 `DefaultSopRouteEvaluator` 和 `MessageServiceImpl` 异步 SOP 入参已写入 `routeParams.speakerId`、`userMsg.speakerId`。
  - `fc\sop-reply` 已新增 `WebChatVoiceDto.speakerId`，`SopReply` 上游优先、缺失时按 `camp_date_id` 查询 Center 补齐。
  - `SopConfigSender` 已从 `userMsg.speakerId` 补齐匹配参数；`speakerId` 与配置值均按 String 精确相等。
  - `homework-config.html` 的 route match 示例已更新为 `currentDay&&homeworkDayRelation&&speakerId`。
- 验证结果：
  - `mvn -pl juzi-service -DskipTests=false "-Dtest=DefaultSopRouteEvaluatorTest,MessageServiceImplSopGateTest,YaqiAgentRouteServiceTest" test` 通过，11 tests, 0 failures, 0 errors。
  - `mvn -pl sop-reply -DskipTests=false "-Dtest=SopConfigSenderTest#shouldMatchSpeakerIdInAndRouteConditions" test` 通过，1 test, 0 failures, 0 errors。
  - `git -C C:\workspace\ju-chat\data-RC diff --check` 通过，仅有换行提示。
  - `git -C C:\workspace\ju-chat\fc diff --check -- sop-reply/...` 通过，仅有换行提示。
  - `git -C C:\workspace\ju-chat\specs diff --check -- 100-juzi-yaqi-fixed-agent` 通过，仅有换行提示。
