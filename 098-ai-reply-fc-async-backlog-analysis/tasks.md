# 任务清单：ai-reply 函数计算异步请求积压根因分析与优化建议

**输入**：来自 `spec.md` 的功能规格
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`
**说明**：本规格为分析类，Phase 1/2 已在分析阶段完成；Phase 3/4 为「若用户确认推进某条 OPT 建议」时的落地任务模板，未确认前不实施。

## Phase 1：代码事实确认（已完成）

- [x] T001 确认链路：fc/ai-reply，异步入口 `AppTask`（PojoRequestHandler<JSONObject,Void>），AI 调用 `CozeUtil`。
- [x] T002 确认调用链：`AppTask.handleRequest` → 校验/聚合 → `CozeUtil.sendMessage` → `handleSendMessage` → `waitCanRun` → `RateLimitUtil.limitRun` → `lockAndRunInvoke` → `generateAndSendRetry`（`coze.chat().stream` + `blockingForEach`）→ `sendJuzi`。
- [x] T003 确认关键参数来源：botId（上游 agent_id）、conversationId（Redis，缺失现算）、messageModels（OTS）、QPS 计数（Redis 秒级 key）、运行锁（Redis running key）。
- [x] T004 确认外部依赖：Coze（句子互动 AI）、juzi-api FC、OTS、Redis；Redis key `ai:coze_qps_counter:*`、`ai:conversationId:running:*`、`ai:coze:conversation:key:v3:*`。
- [x] T005 确认必须保持不变的旧逻辑：群消息/缺字段/图片视频文件跳过、gap 兜底、撤回、人工接管静默、敏感词重试、`无法回答` 不发、`saveUserKeyInfo`、`isSelf` 已回复忽略。

**检查点**：已完成，结论见 `spec.md` 关键证据与根因链。

## Phase 2：风险门禁（已完成，针对优化建议）

- [x] T006 占位对象：现状无空 DTO 占位下传；建议中禁止引入空占位入参。
- [x] T007 调用后赋值：现状 conversationId 缺失时当前层现算并回写，无“调用后才赋值”遗漏；建议不得破坏该现算时机。
- [x] T008 下游读取字段来源：Coze 入参、juzi-api taskObj 字段均在调用前具备来源，已记录于 spec「防漏分析」。
- [x] T009 影响范围标注：每条 OPT 建议已标注是否触及调用顺序/远程调用/MQ/Redis/并发配置/异步行为。
- [x] T010 需确认项登记：OPT-A1/A2/A3、OPT-B1/B2/B3 均标注「需确认」，未确认不实施。
- [x] T011 测试映射占位：为可落地建议预置「下游参数断言」测试方向（Coze 入参 / juzi-api 入参 / QPS 计数 key/口径 / 运行锁 key），见下方 Phase 4。

**检查点**：高风险项均已在 `spec.md` 防漏分析与「优化建议」中标注确认要求。

## Phase 3：实现（最终方案三梯队，待确认后启用）

> 前提（D003）：FC 并发已改 150、上游不可改；下列任务对应 `spec.md`「最终优化方案」STEP 编号，按梯队顺序推进。

梯队 0 — 先让 150 兑现（否则后续无效）：
- [~] T012 [STEP-0-1] 代码侧已外部化限速 `coze_max_qps`（默认 4，不改原行为）；**coze 真实容量压测确认仍待运维**，确认后调该 env 即可。（见 D004）
- [x] T013 [STEP-0-2] 已反编译确认 coze stream 为异步 `enqueue` 路径；`maxRequestsPerHost` 20→默认 64（env 可配）、`maxRequests`→256、线程池上限同步。（见 D004）
- [x] T014 [STEP-0-3] 已提高 `maxIdle` 15→64、`minIdle`→16，db 下沉连接池并去除借连接 `select`；`maxTotal=400` 与服务端 `maxclients` 仅记录未改。彻底单连接复用留待梯队 1。（见 D004）

梯队 1 — 压缩单请求占槽：
- [ ] T015 [STEP-1-1] `waitCanRun` 去阻塞：同会话在跑则立即让出 + 延迟重投，保留「仅回复最新一次」语义。⚠️需确认
- [ ] T016 [STEP-1-2] `limitRun` 改令牌桶（Redis+Lua 原子）+ 快速让出 + 重投；退避抖动、时间戳去重、重试耗尽兜底告警；桶速率随 coze 容量。⚠️需确认
- [ ] T017 [STEP-1-3] 收紧 `OkHttpClient`/`CozeAPI` 读超时到 60~120s，长尾快速失败释放槽。⚠️需确认
- [ ] T018 [STEP-1-4] 修串行失效：协调锁 TTL/等待上限与 coze 时长；补发送前 `currentTimeStamp==timestamp` 校验，过时不发。⚠️需确认

梯队 2 + 兜底：
- [ ] T019 [STEP-2-1] （中期）评估两段式拆分 / coze 异步回调，使 AI 生成不占 FC 执行槽。⚠️需确认
- [ ] T020 [STEP-3-1~3-3] 过时丢弃、重试耗尽告警/落库、积压熔断降级。
- [ ] T021 同步更新 `spec.md`/`tasks.md`/`AGENTS.md`/`checklist` 中因实现产生的口径变化，并追加 Dxxx。

## Phase 4：测试与验证（待确认后启用）

- [ ] T022 单元测试断言下游参数：Coze `CreateChatReq`（botID/conversationID/userID/messages）内容、juzi-api `FcInvokeInput.taskObj` 内容，不只断言最终回复。
- [ ] T023 限速口径回归：断言令牌桶 / `ai:coze_qps_counter` 计数与 TTL 行为；改造后准入逻辑不改变既有统计语义；重投消息体字段（含 retryCount/延迟）断言正确。
- [ ] T024 同会话语义回归：连续多条同会话消息，断言仅对最新有效消息生成一次回复（含发送前时间戳作废），且不再长时间阻塞占槽。
- [ ] T025 旧逻辑不回归：群消息/图片视频文件跳过、gap 兜底、撤回、人工静默、敏感词重试、`无法回答` 不发、`isSelf` 忽略。
- [ ] T026 压测/回放：固定投递速率下观测积压曲线与 `durationMs`/`concurrentRequests`，验证完成速率随并发提升、单请求时长随去阻塞下降；并验证 coze/OkHttp/Redis 三处不再卡（梯队 0）。
- [ ] T027 运行目标模块编译/测试命令并记录：`mvn -pl ai-reply -am test`（从 `fc/` 目录）。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 098 规格文档，完成代码事实确认与日志指标统计，给出根因链与分层优化建议。
- 验证方式：源码阅读（AppTask/CozeUtil/RateLimitUtil/RedisClient）+ CSV 日志统计（durationMs、concurrentRequests、dwellLatencyMs、hasFunctionError、轮询/限速计数）。
- 自检结论：积压为吞吐瓶颈（时长×低并发），非错误重试；所有改动类建议均标注需确认，本阶段未改代码，满足门禁。

### D002 - 实现记录

- `<确认推进后填写：代码改动摘要、测试命令、测试结果、自检结论、剩余风险。>`

### D003 - 最终方案落档与前提变更

- 触发原因：用户给出新前提（FC 并发已改 150、上游不可处理），并经多轮深挖（根因辨析、消息合并评估、令牌桶+重投参数评估），要求形成最终优化方案并落档全部证据。
- 修正内容：
  - 前提变更：并发 31→150；OPT-A4「上游入队前防抖」因上游不可改而移出。
  - Phase 3 由原 OPT-A/B/C 重排为最终方案三梯队（梯队 0 确认 150 兑现 → 梯队 1 压占槽 → 梯队 2 根治时长 + 兜底），任务对齐 `spec.md` STEP 编号（T012-T021）。
  - Phase 4 测试任务重排为 T022-T027，避免编号冲突，并补「重投消息体断言」「发送前时间戳作废回归」「梯队 0 三处不卡验证」。
- 文档同步：已同步 `spec.md`（新增「最终优化方案」章节 + D003 五类证据）与本 `tasks.md`（Phase 3/4 重排 + 本 D003）；`AGENTS.md`、`checklists/requirements.md` 口径不变。
- 验证结果：分析与方案落档阶段，未改业务代码；所有改动类任务标注「需确认」，下游参数断言测试方向已在 Phase 4 列明。

### D004 - 梯队 0 代码改造实现记录

- 触发原因：用户确认推进梯队 0（FC 并发已改 150），完成 STEP-0-1/0-2/0-3 代码改造。
- 改动文件：`CozeUtil.java`（dispatcher 上限可配+提高）、`RedisConnectionPool.java`（maxIdle/minIdle 提高 + db 下沉池）、`RedisClient.java`（去除借连接 select）、`RateLimitUtil.java`（maxQPS 外部化，默认 4 不变）。
- 取证：反编译确认 `ChatStream.stream` 用 `Call.enqueue`（异步，受 dispatcher 限制）；Jedis 3.2.0 支持带 database 的 JedisPool 构造；select/db 仅 RedisClient 一处。
- 测试命令：`mvn -pl ai-reply -am compile`（从 `fc/`）→ BUILD SUCCESS；`mvn -pl ai-reply test` → Tests run: 16, Failures: 0, Errors: 0。
- 自检结论：均为容量/配置改动，默认值保持原行为或更稳健，现有 16 个测试全绿、无回归；未改业务语义/Redis key/远程契约/MQ。
- 剩余风险：coze 真实容量需压测（T012）；dispatcher/线程池值需与 instanceConcurrency 及 512MB 内存匹配；Redis maxTotal×实例数 注意服务端 maxclients；彻底单连接复用留梯队 1。详见 `spec.md` D004。
