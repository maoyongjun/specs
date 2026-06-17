# 功能规格：ai-reply 函数计算异步请求积压根因分析与优化建议

**功能目录**：`098-ai-reply-fc-async-backlog-analysis`
**创建日期**：`2026-06-17`
**状态**：Draft（分析类规格）
**输入**：监控面板「异步请求积压数」显示 2026-06-16 15:12:00 积压数 426、处理中的异步请求数 31，存在明显尖峰。要求在 `specs/` 下创建 spec-kit 文档，分析函数计算数据积压原因并给出优化建议。日志 `C:\workspace\55dd9b1e-2a13-4302-a6c9-0eec893d041c.csv`，源码 `C:\workspace\ju-chat\fc\ai-reply`。

## 背景

- 当前问题：ai-reply 异步函数在 2026-06-16 15:00 后出现请求积压尖峰，积压数冲到 426，而同一时刻「处理中的异步请求数」仅 31。早间 07:00 附近也有一个约 80 的小凸起。
- 当前行为：企业微信用户消息经上游写入后，以异步方式（FC 异步调用，statefulAsyncInvocation）触发 `AppTask`，每条消息在函数内同步阻塞地调用 Coze（句子互动 AI Bot）生成回复，再回写句子互动发送。单请求执行时间长，且函数内还要做「同会话串行等待」和「全局 QPS 限速」两层阻塞等待。
- 目标行为（分析目标）：明确积压根因（吞吐瓶颈而非错误重试），量化瓶颈指标，给出能提升有效吞吐、削峰、缩短单请求占用时长的优化方向。
- 非目标：
  - 本规格不直接修改业务代码（涉及远程调用、Redis key、并发/触发器配置变更，均需先确认）。
  - 不改变 AI 回复的业务语义、敏感词重试、撤回判定、人工接管静默等既有分支。

## 关键证据（来自日志与面板，可复算）

> 数据来源：`C:\workspace\55dd9b1e-2a13-4302-a6c9-0eec893d041c.csv`，时间窗口 2026-06-16 14:50:03 ~ 16:04:55。

1. **单请求执行时长极长（核心瓶颈）**
   - FCRequestMetrics `durationMs`（样本 469）：最小 10ms，中位 41378ms，P90 94336ms，最大 195684ms，平均 44235ms。
   - 应用日志「完成处理coze聊天流…执行时长」（样本 403）：中位 44141ms，P90 95934ms，P99 125732ms，最大 195391ms，平均 49913ms。
   - 结论：单条异步请求平均占用约 **44 秒**，长尾达 **195 秒**，时间几乎全部消耗在 `coze.chat().stream(req)` 的 `blockingForEach` 流式生成上。

2. **实际并发低，完成速率远低于到达速率**
   - 面板：积压 426、处理中仅 31。
   - FCInstanceMetrics `concurrentRequests`（每实例并发，样本 447）：最大 13，平均 5.3。
   - 由 Little 定律估算完成速率 ≈ 处理中并发 / 单请求时长 ≈ 31 / 44s ≈ **0.7 条/秒 ≈ 42 条/分钟**。当上游在尖峰时段集中投递数百条消息时，到达速率远超 42 条/分，队列迅速堆到 426。

3. **不是错误重试风暴**
   - FCRequestMetrics `hasFunctionError` 全部为 `false`（469/469）。
   - 全量日志 ERROR 级 0 条、WARN 级仅 1 条；无「lockAndRunInvoke error」「等待超时」记录。
   - 结论：积压是**纯吞吐问题**，不是函数报错触发异步重投导致的二次放大。

4. **函数内阻塞等待消耗并发槽与计费时长（放大因素）**
   - 「conversationId 正在执行中…继续轮询」出现 95 次，最长「已等待 60141ms」——`waitCanRun` 对同一 conversationId 串行，单次最多轮询 90 秒、每 5 秒一次。
   - `dwellLatencyMs`（实例驻留延迟）中位 31379ms、最大 72355ms，与轮询/限速等待相吻合。
   - 「beginRun-QPS」398 次，未出现「reached QPS limit」——说明本时段 QPS 限速尚未频繁触发硬等待，但限速逻辑本身仍在每个请求里占用一次 Redis 往返。

## 根因链（总结）

```
上游消息尖峰（短时间集中投递）
        │
        ▼
异步队列入队速率 ≫ 出队（完成）速率
        │
        ├── 单请求时长过长：Coze 流式生成 blockingForEach，平均 44s、长尾 195s   ← 主因
        ├── 实际并发偏低：处理中仅 31，每实例并发 ≤13，实例数有限             ← 主因
        ├── 函数内阻塞等待：waitCanRun 最长 90s 轮询 + RateLimitUtil 最长 300s 等待，
        │     这些等待全程占用 FC 并发槽与计费时长，进一步压低有效吞吐          ← 放大
        └── 全局 QPS 硬上限 4：固定天花板，无法弹性吸收突发                     ← 放大
        │
        ▼
积压数冲到 426（处理中仅 31）
```

## 用户场景与测试 *(必填)*

### 用户故事 1 - 尖峰削峰，积压可收敛（优先级：P1）

作为运营/平台方，当某时段消息集中涌入时，期望 ai-reply 的异步积压能在可接受时间内收敛，不长时间停留在数百级别，用户回复不被无限期延后。

**独立测试**：用一段已知投递速率（如 5 分钟内 N 条）的回放/压测，观察积压曲线是否在投递结束后按「有效吞吐 ≈ 实际并发/单请求时长」的速率回落，并验证回落速率随并发上限提升而提升。

**验收场景**：
1. **Given** 单请求时长不变（约 44s）、并发从 31 提升到 K，**When** 同样的尖峰到达，**Then** 完成速率应约为 `K/44` 条/秒，积压峰值与清空时间相应下降。
2. **Given** 将函数内阻塞等待（waitCanRun/限速）移出计费执行体或缩短，**When** 同样尖峰到达，**Then** 单请求平均 `durationMs` 与 `dwellLatencyMs` 显著下降，单位并发吞吐上升。

### 用户故事 2 - 缩短单请求占用时长（优先级：P2）

作为开发者，期望单条请求不再因「排队等待 + 流式生成」长时间占住一个并发槽，从而用同样的实例资源处理更多请求。

**独立测试**：统计优化后 `durationMs` 分布与「执行时长」日志，比较中位/平均是否下降，以及 `concurrentRequests` 在相同负载下是否更稳定。

**验收场景**：
1. **Given** 同会话串行改为「丢弃/合并旧消息」而非阻塞轮询，**When** 同会话连续多条消息到达，**Then** 不再出现「继续轮询，已等待 N ms」长时间挂起，且回复仍只对最新有效消息生成一次。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机（分析现状，非改动）：
  - `botId`：来源 `empExternalDto.getAgent_id()`（上游传入），在 `CozeUtil.generateAndSendRetry` 调用前已具备（CozeUtil.java:451）。
  - `conversationId`：来源 Redis（`ai:coze:conversation:key:v3:...` / 私域 key），缺失时由 `cozeUtil.createConversationId()` 现算并回写（AppTask.java:242-246、414-418）。
  - `messageModels`：来源 `OtsUtil.selectUserMessage`，在调用 `sendMessage` 前查询（AppTask.java:206-234）。
  - QPS 计数：来源 Redis `ai:coze_qps_counter:<秒级时间窗>`，每请求自增（RateLimitUtil.java:9、22-25）。
  - 运行状态锁：Redis `ai:conversationId:running:<conversationId>`，`markConversationRunning` 写、`waitCanRun` 读（CozeUtil.java:300、405-412）。
- 下游读取字段清单：
  - `coze.chat().stream` 读取 `botID`、`conversationID`、`userID`、`messages`（CozeUtil.java:452-458）。
  - `sendJuzi` → juzi-api FC 读取 taskObj（文本/图片/视频号）、`type`、`functionCode`（CozeUtil.java:711-816）。
- 空对象 / 占位对象风险：现状未发现以空 DTO 占位下传 Coze/juzi 的情况；任何优化建议**不得**引入空占位入参（例如不得在“快速返回”分支里给 juzi 发空 taskObj）。
- 调用顺序风险：现状 `waitCanRun`（等锁）→ `RateLimitUtil.limitRun`（限速）→ `lockAndRunInvoke`（置运行态、调 Coze、清运行态）顺序固定；优化若调整该顺序（如把限速前置、把等待移出函数体），属于**调用顺序变更，需确认**。
- 旧逻辑保持（优化时必须不变）：
  - 群消息跳过（`shouldSkipGroupMessage`）、缺 agent/sku 跳过、图片/视频/文件跳过、时间间隔 gap 兜底缓存、撤回判定、人工接管静默（pre_coze/private_domain_pre_coze/final_send 三处）、敏感词重试（<2 次）、`无法回答` 不发送、`saveUserKeyInfo` 记录。
  - 「销售已手动回复/触发 SOP 则忽略」判定（`messageModels.get(last).getIsSelf()`）。
- 需要用户确认的设计选择：
  - 调整 FC 函数实例并发（instanceConcurrency）、最大实例数、异步调用并发/队列与重试策略 → **属基础设施配置变更，需确认**。
  - 把 Coze 调用由「函数内阻塞流式」改为「异步回调/拆分两段函数」→ **改变调用链与异步行为，需确认**。
  - 修改 `RateLimitUtil` QPS 口径或将限速迁移到入口/上游 → **改变限速契约，需确认**。
  - 修改 `waitCanRun` 串行策略（改为丢弃旧消息/缩短轮询/取消阻塞）→ **可能改变“等待已有任务完成”的业务语义，需确认**。

## 边界情况

- 上游突发尖峰（本次主因）：需要削峰/扩并发，而非仅靠重试。
- 长尾请求（最大 195s）：Coze 端慢响应会长时间占用并发槽；OkHttp `readTimeout=3600s`、CozeAPI `readTimeout=86400_000ms` 几乎不超时，慢请求得不到及时熔断。
- 同会话高频消息：`waitCanRun` 串行 + 90s 轮询，可能让后到消息长时间挂起占槽。
- 限速等待超时（`maxWaitTime=300000`）：等满 5 分钟后仍执行——极端情况下单请求可被限速等待拖到分钟级，全程占用并发槽与计费。
- Redis 连接 churn：`RedisClient` 每次 `new` 都 `getResource()+select(db)`，`waitCanRun` 轮询、`markConversationRunning`、`clearConversationRunning`、`RateLimitUtil` 等高频新建/关闭连接，给 Redis 与连接池增压。

## 需求 *(必填)*

### 功能需求（分析结论）

- **FR-001**：规格 MUST 给出可复算的结论——积压主因为「单请求时长过长（均 44s/尾 195s）× 实际并发低（处理中 31）导致完成速率（≈42 条/分）远低于尖峰到达速率」。
- **FR-002**：规格 MUST 明确积压**不是**函数错误重试导致（`hasFunctionError` 全 false、ERROR 0 条）。
- **FR-003**：规格 MUST 列出放大因素：函数内阻塞等待（waitCanRun 最长 90s、RateLimitUtil 最长 300s）占用并发槽与计费时长；全局 QPS 硬上限 4；Redis 连接 churn；近乎无限的 Coze 读超时。
- **FR-004**：规格 MUST NOT 在未确认前改动远程调用、Redis key/TTL、QPS 口径、FC 并发/触发器配置或 AI 业务语义。

### 优化建议（分层，标注门禁与确认要求）

> 优先级排序：A 类（吞吐与削峰，收益最大）> B 类（缩短单请求占用）> C 类（稳健性与成本）。

**A. 提升有效吞吐 / 削峰（最高优先级，需确认基础设施变更）**
- **OPT-A1（提并发上限）**：核实并提高 FC 异步函数的实例并发（instanceConcurrency）与最大实例数/异步并发上限。结论依据：完成速率 ≈ 并发/44s，把处理中并发从 31 提升到 ~150，理论完成速率可从 42 条/分升到约 200 条/分。⚠️ 基础设施配置变更，需确认；注意下游 Coze/句子互动是否能承接更高并发（与 OPT-A3 联动）。
- **OPT-A2（异步并发与重试策略）**：核实异步调用配置的最大并发与失败重试次数/死信队列；确保积压期不会因默认重试把队列二次放大；为长尾设置合理的函数超时与异步消息保留时间。⚠️ 配置变更，需确认。
- **OPT-A3（限速从“函数内阻塞”改为“入口准入/分片”）**：当前 `RateLimitUtil` 在已计费的函数体内 `Thread.sleep` 等待 QPS 槽，等待期间仍占用并发槽。建议将限速前移到「触发器/入口准入」或改为「按 Coze 实际承载能力的令牌桶」，让拿不到令牌的请求快速让出执行体（如延迟重投）而非占槽空等。⚠️ 改变限速契约与调用顺序，需确认；需配套下游参数断言（QPS 计数 key 与口径不变验证）。

**B. 缩短单请求对并发槽的占用（高优先级，多为代码层）**
- **OPT-B1（同会话等待去阻塞）**：`waitCanRun` 改为「检测到同会话在执行则直接放弃本次（旧消息作废）或快速让出」，避免最长 90s 的轮询挂起占槽（已观测 95 次轮询、最长 60s）。需保留「只对最新有效消息回复一次」的语义。⚠️ 可能改变“等待已完成”语义，需确认。
- **OPT-B2（拆分两段式，建议作为中期架构）**：把「接收/聚合/准入」与「Coze 生成/回写」拆成两个函数或一次异步回调，使长达数十秒的 AI 生成不占用聚合阶段的并发；或采用 Coze 端的异步/回调模式替代 `blockingForEach` 长占。⚠️ 改变调用链与异步行为，需确认。
- **OPT-B3（收紧 Coze 客户端超时）**：`OkHttpClient.readTimeout=3600s`、`CozeAPI.readTimeout=86400_000ms` 过大，长尾慢请求得不到熔断。建议设为与业务可接受时延一致（如 60~120s），让异常慢请求快速失败并交由既有重试/作废逻辑，释放并发槽。⚠️ 改变远程调用超时，需确认。

**C. 稳健性与成本（中优先级，代码层为主）**
- **OPT-C1（复用客户端）**：`CozeAPI`/`OkHttpClient` 当前每次 `new CozeUtil` 都新建（dispatcher 虽 static，但 client 实例每请求新建）。建议按 token/Bot 维度复用客户端，减少建连开销。
- **OPT-C2（降低 Redis 连接 churn）**：`RedisClient` 每次构造都 `getResource()+select(db)`，且 `waitCanRun` 轮询、mark/clear、限速高频新建连接。建议单次请求内复用一个连接、或减少 select 往返、把高频小操作合并。
- **OPT-C3（可观测性）**：补充「积压来源画像」——按 camp_date_id / agentId / 是否私域 统计请求量与时长，定位是否某活动/某 Bot 在尖峰时段贡献了大部分慢请求，便于针对性限流。

## 最终优化方案（前提：FC 并发已改为 150、上游不可改）

> 约束更新（见 D003）：A 类「提并发」已落地——FC 异步并发已从约 31 提升到 150；上游投递方无法改造，故 OPT-A4「上游入队前防抖」不可行，移出方案。
> 算账：完成速率 = 并发 / 单请求占槽时长。31×44s≈0.7/s≈42/分；150×44s≈3.4/s≈204/分（理论 5 倍，426 积压可降到约 2 分钟级清空）。但「理论值」要兑现，必须清除提并发后浮现的次级瓶颈。本方案按「先让 150 兑现 → 再压单请求占槽 → 最后根治时长」三梯队推进。

### 梯队 0：先确认「150 是真的」（不做这步，后续改动均无效）

- **STEP-0-1（确认 coze 下游容量，最高风险）**：限速 `maxQPS=4` 大概率为保护下游 coze（句子互动 AI）而设；150 槽会让 coze 同时承载约 150 个流。必须确认 coze 真实约束是「并发数」还是「QPS」。若 coze 扛不住 → 超时/429 → 触发 `lockAndRunInvoke` 换会话重试 → 单请求时长翻倍 + 二次放大，积压不降反升。行动：小步压测（先 50 并发观察错误率），据容量重设限速值。⚠️需确认。
- **STEP-0-2（解除 OkHttp 隐藏并发上限）**：`CozeUtil` static dispatcher `maxRequests=100`、`maxRequestsPerHost=20`、线程池 `max=20`（CozeUtil.java:80-99），dispatcher 为单实例共享。若 coze SDK 走异步 enqueue，单实例 coze 并发会被 `20/host` 卡死——FC 给 150 槽、coze 这层只放 20。行动：确认 stream 是同步 `execute`（不受限）还是异步 `enqueue`（受限）；受限则把 `maxRequests/maxRequestsPerHost/线程池` 调到匹配单实例并发期望。⚠️需确认。
- **STEP-0-3（修 Redis 连接池，150 并发下必爆点）**：`RedisConnectionPool` `maxTotal=400`、`maxIdle=15`、`testOnBorrow=true`，且 `RedisClient` 每次构造都 `select(db)`（RedisConnectionPool.java:17-25、RedisClient.java:23）。三处问题：
  - `maxIdle=15` 与 `maxTotal=400` 严重不匹配 → 高并发借还产生大量「建连-销毁」churn；建议 `maxIdle` 提到与单实例并发×每请求连接数相当（如 50~100）。
  - `testOnBorrow=true` + `select(db)` → 每次 `new RedisClient` 多 2 次往返，而单请求会 new 多次 → 往返爆炸；建议**单请求复用一个连接**。
  - `maxTotal=400` 为每实例值，约十几个实例 × 400 = 数千连接打到 Redis，注意服务端 `maxclients` 反向风险，必要时调小单实例 `maxTotal`。⚠️需确认（连接池参数变更）。

### 梯队 1：压缩「单请求占槽时长」（低风险、性价比最高）

- **STEP-1-1（`waitCanRun` 去阻塞）**：检测到同会话在跑时不再 `sleep` 轮询最长 90s 占槽，改为「立即让出 + 延迟重投」，保留「仅回复最新有效消息一次」语义。⚠️语义变更需确认。
- **STEP-1-2（`limitRun` 改令牌桶 + 快速让出 + 重投）**：并发 150 后限速 4/s 已逼近瓶颈（3.4/s vs 4/s，几乎无余量），`sleep` 占槽浪费显现。落地口径：令牌桶用 Redis+Lua 原子化；桶速率按 STEP-0-1 的 coze 容量重设（不死守 4）；重投延迟用**退避+抖动**（不固定 10s，防惊群）；**必加时间戳去重 + 重试耗尽兜底告警**（见 D003 参数评估）。⚠️限速口径+调用顺序变更需确认。
- **STEP-1-3（收紧 coze 读超时）**：`OkHttpClient.readTimeout=3600s`、`CozeAPI.readTimeout=86400_000ms` → 调到业务可接受值（如 60~120s），长尾快速失败释放槽（CozeUtil.java:116-120）。⚠️远程调用超时变更需确认。
- **STEP-1-4（修串行失效 + 发送前时间戳作废）**：锁 TTL 120s / 等待 90s 均 < coze 最大 195s，会让同会话并发跑、回过时内容；补发送前 `currentTimeStamp==timestamp` 校验，省约 9% 无效 coze 调用并避免发陈旧回复（CozeUtil.java:405-412、503-512）。⚠️语义变更需确认。

### 梯队 2：根治「单请求时长」（中期，改动大、收益上限最高）

- **STEP-2-1（两段式拆分 / coze 异步回调）**：把「接收-聚合-准入」与「coze 生成-回写」拆开，让约 44s 的 AI 生成不占 FC 执行槽，使吞吐由 coze 自身容量决定，而非受 FC 并发×时长约束。⚠️调用链/异步行为变更需确认。

### 兜底（上游不能削峰，下游兜底更重要）

- **STEP-3-1（过时丢弃）**：重投/取令牌时校验非最新即丢（不计入失败），尖峰下剪除大量无效处理。
- **STEP-3-2（重试耗尽告警）**：20 次×10s=200s 在 1 小时级尖峰下会丢消息，耗尽必须告警/落库，不得静默丢。
- **STEP-3-3（积压熔断降级）**：积压超阈值时只回最新、丢弃过老消息，防雪崩。

### 执行顺序与预期效果

```
梯队0（确认 coze/OkHttp/Redis 不卡）  → 让 150 真正兑现：42/min → ~200/min（5x），积压 2 分钟级清空
梯队1（去阻塞 + 令牌桶 + 超时 + 去重） → 把 150 槽从"睡觉"改为"干活"，吞吐再上一截、成本下降
梯队2（拆分 / 异步回调）              → 时长出表，吞吐由 coze 容量决定，根治
```

最关键三件事，按序：① 确认 coze 扛得住 150（STEP-0-1）；② 解除 OkHttp `maxRequestsPerHost=20` 与 Redis `maxIdle=15` 两个隐藏天花板（STEP-0-2/0-3）；③ `waitCanRun`/`limitRun` 去 `sleep` 占槽 + 超时收紧（STEP-1-1~1-4）。

## 成功标准 *(必填)*

- **SC-001**：分析结论可由日志复算：单请求 `durationMs` 中位约 41s、平均约 44s、最大约 195s；处理中并发约 31；由此得出完成速率约 42 条/分，能解释 426 的积压尖峰。
- **SC-002**：明确区分「主因（时长×低并发）」与「放大因素（函数内阻塞等待、QPS 硬上限、连接 churn、超时过大）」，且每条都对应到具体源码位置与日志数字。
- **SC-003（不回归）**：所有优化建议均标注是否触及强制门禁与是否需确认；不存在「直接改远程调用/Redis/并发配置/AI 语义」而未标注确认的建议。

## 假设

- 假设面板「处理中的异步请求数」对应 FC 异步「执行中」的请求数，「积压数」对应已入队未开始执行的异步请求数；据此用 Little 定律估算完成速率。若该口径与控制台定义不同，需追加 Dxxx 修正。
- 假设本时段未配置会导致二次放大的异步失败重投（因 `hasFunctionError` 全 false 无法直接证伪重试配置，需向控制台核实，列入 OPT-A2）。
- 假设上游尖峰为真实业务投递（如某营期/活动集中触达），而非上游 bug 重复投递；建议用 OPT-C3 画像核实。
- 假设 Coze（句子互动 AI）与句子互动发送接口在更高并发下仍能承接（OPT-A1/A3 落地前需联合压测确认下游容量）。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档（AGENTS/spec/tasks/checklist）。
- 已完成代码事实确认（AppTask/CozeUtil/RateLimitUtil/RedisClient）与日志指标统计（durationMs、concurrentRequests、dwellLatencyMs、hasFunctionError、轮询/限速日志计数）。
- 已完成历史问题防漏分析与门禁标注。
- 本阶段未修改任何业务代码。

### D002 - 实现记录

- `<若用户确认推进某条 OPT 建议，再在此记录：实现内容、影响范围、测试命令（含下游参数断言）、测试结果、自检结论。>`

### D003 - 多轮深挖证据补充与前提变更

- 触发原因：用户连续追问根因辨析（阻塞是 coze 时长还是锁泄漏）、消息合并思路评估、限速改造方案（令牌桶+重投参数）、并给出新前提（FC 并发已改 150、上游不可处理），要求形成最终优化方案并落档全部证据。

- 前提变更（影响原「假设」与 A 类建议）：
  - 并发：FC 异步并发已由约 31 提升到 **150**（A 类 OPT-A1 已落地）。完成速率理论值由 42/分升至约 204/分。
  - 上游：投递方**无法改造**，OPT-A4「上游入队前防抖」不可行，移出方案；削峰责任全部落到 ai-reply 自身（去阻塞 + 重投 + 兜底）。

- 新增证据 1（会话重复度，支撑「消息合并」评估）：
  - 完成 coze 共 403 次，去重后仅 **185 个会话**，平均 **2.2 次/会话**；Top 会话 13 次。
  - 同会话相邻 coze 调用间隔分布：<30s 7 次、30–60s 29 次、60–120s 61 次、120–300s 73 次、>300s 48 次。
  - 结论：间隔 <60s 的「本可避免重复」仅 **36 次 ≈ 8.9%**；大头（间隔几分钟）是真实多轮人机对话，**不可合并**。故「消息合并」方向正确但收益有限（约 9%~20%），且函数内合并降的是 coze 次数/占槽，**降不了「积压数」本身**（积压数=异步队列长度，在投递端产生）。

- 新增证据 2（阻塞根因辨析：是 coze 时长，非锁泄漏）：
  - 「等待超时」日志 **0 次**，「继续轮询」95 次且最长「已等待 60141ms」（< 90s 上限）→ 等待均正常等到锁释放，无锁泄漏特征。
  - 等待时长样本（45/50/55/60s）≈ 5s 轮询步长的倍数，与 coze 执行时长分布（中位 44s、P90 96s）吻合 → 等待 = 前一条消息 coze 跑完的时间。
  - 锁释放健全：`clearConversationRunning` 在 finally + 120s TTL 双保险（CozeUtil.java:369-371、405-412）。

- 新增证据 3（串行失效 / TTL 隐患，独立真实 bug）：
  - 运行锁 TTL=120s、`waitCanRun` 上限=90s，**均小于** coze 最大执行 195s（P99 126s）。
  - 后果（与「锁泄漏」方向相反）：coze 超 120s 时锁自动过期 / 等待方 90s 超时后仍继续执行 → 同会话并发跑多个 stream，回复乱序/重复。本时段因无超 120s 长尾叠加新消息而未爆发（超时 0 次），长尾增多即触发。对应修复 STEP-1-4。

- 新增证据 4（提并发后浮现的隐藏瓶颈）：
  - OkHttp：static dispatcher `maxRequests=100`、`maxRequestsPerHost=20`、线程池 `max=20`（CozeUtil.java:80-99）→ 异步路径下单实例 coze 并发或被卡在 20，使 150 槽打折。
  - Redis：`maxTotal=400`、`maxIdle=15`、`testOnBorrow=true` + 每次 `select(db)`（RedisConnectionPool.java:17-25、RedisClient.java:23）→ maxIdle 过小致 churn、每次借连接 2 次额外往返、多实例 ×400 有打爆服务端 maxclients 风险。

- 新增证据 5（令牌桶 + 重投参数评估，针对「10s 延迟 / 20 次重试」提案）：
  - 关键前提：当前限速**根本没触发**（`reached QPS limit` 0 次），瓶颈是并发非限速；故单改限速对当时积压无效。
  - 重投副作用：「投递给自己」= 每次重投一次新入队，会**推高「积压数」曲线与计费**（粗算尖峰下放大近 10 倍）。
  - 参数判定：延迟固定 10s 有**惊群**风险 → 改退避+抖动；20 次×10s=200s 覆盖窗口 < 1 小时尖峰 → 早期消息会被丢弃，**必须定义耗尽兜底**（告警/落库，禁止静默丢）；桶速率按 coze 实际容量定、与并发联动（4/s 与 150 并发基本匹配但无余量）。
  - 必备配套：重投/取令牌后做**时间戳去重**（非最新即丢，不再重投也不调 coze），既避免回复过时内容，又大幅剪除无效重投、缓解放大。

- 形成结论：已新增「最终优化方案」章节（梯队 0 确认 150 兑现 / 梯队 1 压占槽 / 梯队 2 根治时长 + 兜底 + 执行顺序），并将上述证据纳入规格。

- 文档同步：本次已同步 `spec.md`（新增最终方案章节 + 本 D003）与 `tasks.md`（追加梯队任务与 D003 记录）；`AGENTS.md`、`checklists/requirements.md` 口径不变，无需改动。

- 验证结果：本阶段为分析与方案落档，未改动业务代码；所有改动类步骤均标注「需确认」，未确认不实施。梯队 0/1/2 的下游参数断言测试方向见 `tasks.md` Phase 4。

### D004 - 梯队 0 代码改造实现记录

- 触发原因：用户确认推进梯队 0（FC 并发已改 150），要求完成 STEP-0-1/0-2/0-3 代码改造。
- 前置确认（反编译取证）：`coze.chat().stream` → `ChatStream.stream(Call)` 用 `retrofit2.Call.enqueue`（**异步路径**），经 OkHttp Dispatcher 队列，确受 `maxRequestsPerHost` 约束 → STEP-0-2 为真瓶颈。Jedis 3.2.0 存在 `JedisPool(config,host,port,timeout,password,database)` 构造；`select`/`getenv("db")` 仅 `RedisClient` 一处使用 → 可安全下沉到池。
- 改动内容（fc/ai-reply）：
  - **STEP-0-2**（`CozeUtil.java` static 块）：`maxRequestsPerHost` 20→默认 64（env `coze_okhttp_max_per_host`）、`maxRequests` 100→默认 256（env `coze_okhttp_max_requests`）；线程池上限与 perHost 同步（异步 call 各占一线程读 SSE，避免线程不足排队/无界放大）；新增 `envInt` 与初始化日志。
  - **STEP-0-3**（`RedisConnectionPool.java`）：`maxIdle` 15→默认 64（env `redis_max_idle`）、`minIdle` 5→默认 16（env `redis_min_idle`），降低建连-销毁 churn；db 下沉到 JedisPool 构造，连接创建即 select。
  - **STEP-0-3**（`RedisClient.java`）：删除构造内 `instance.select(getenv("db"))`，借出连接不再重复 select（每次省一次往返）；行为差异：db 缺失由「每次构造抛异常」变为「回退 db 0」（生产必配，仅健壮性兜底）。
  - **STEP-0-1 配套**（`RateLimitUtil.java`）：`maxQPS` 硬编码 4 → env `coze_max_qps`（默认 4、非法/≤0 回退 4）；默认值不变即不改现有行为，便于压测确认容量后调整。令牌桶重构仍属梯队 1。
- 新增可配置环境变量（均有安全默认，不配置则保持/接近原行为）：`coze_okhttp_max_per_host`(64)、`coze_okhttp_max_requests`(256)、`redis_max_idle`(64)、`redis_min_idle`(16)、`coze_max_qps`(4)。
- 影响范围：仅并发/资源容量与连接初始化；未改业务语义、未改 Redis key/TTL、未改远程调用契约与 MQ。FC 并发=150 属控制台/IaC 配置（仓库无 ai-reply 部署 yaml），已由用户在平台侧完成。
- 测试命令与结果：`mvn -pl ai-reply -am compile` → BUILD SUCCESS；`mvn -pl ai-reply test` → Tests run: 16, Failures: 0, Errors: 0（含 `PrivateDomainCozeUtilTest`，验证 CozeUtil 静态 dispatcher 初始化正常）。
- 自检结论：四处均为容量/配置改动，默认值保持原行为或更稳健，现有测试全绿、无回归。
- 剩余风险/待办：
  - STEP-0-1 真实容量需对 coze 压测确认（代码仅提供可调开关，默认仍 4）；提并发后 coze 是否限流/429 必须先验，否则会触发换会话重试放大。
  - `coze_okhttp_max_per_host` 与线程池上限需与 FC 实际 `instanceConcurrency` 及 512MB 内存匹配（线程栈成本），上线后据内存/coze 错误率再调。
  - Redis `maxTotal=400` 为每实例值，多实例×400 注意服务端 `maxclients`（本次未改）。
  - 「单请求复用一个连接」的彻底复用属梯队 1，本次仅做池级复用（maxIdle + 去 select）。
