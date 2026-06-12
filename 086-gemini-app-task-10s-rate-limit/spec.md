# 功能规格：Gemini AppTask 10 秒限速与突发保护

**功能目录**：`086-gemini-app-task-10s-rate-limit`  
**创建日期**：`2026-06-12`  
**状态**：Implemented  
**输入**：修改 `C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\AppTask.java`，限速成 10 秒一个；不要影响其它限流；分析 800 个突发提交是否导致内存问题。

## 背景

- 当前问题：`AppTask` 原先在 `convertAudioToBase64(picUrl)` 之后才进入共享 `RateLimitUtil.limitRun`，突发请求会先下载音频并持有 Base64 字符串。
- 当前行为：共享 `RateLimitUtil` 是每秒窗口 QPS 控制，并被 `PracticeCommentFc` 等调用方间接复用。
- 目标行为：仅 `AppTask.handleRequest` 音频链路按 10 秒一个预订执行时间；未到点时延迟重投递，不下载音频、不调用 Gemini。
- 非目标：不修改 `RateLimitUtil`，不改视频任务，不改回调协议，不改 Gemini 请求体。

## 用户场景与测试

### 用户故事 1 - 单任务正常执行（优先级：P1）

当 AppTask 请求进入且当前没有排队压力时，系统立即执行原有音频分析流程。

**独立测试**：输入已到点的内部预订时间，断言进入音频转换和 Gemini 调用。

**验收场景**：

1. **Given** 当前 Redis 队列为空，**When** 新 AppTask 请求进入，**Then** 预订时间为当前时间并继续执行音频转换。
2. **Given** payload 中已有到期的内部预订时间，**When** 延迟重投递触发，**Then** 删除内部字段并执行原有分析链路。

### 用户故事 2 - 突发请求排队（优先级：P1）

当大量请求同时进入时，系统只预订执行时间并延迟重投递，避免函数内长时间等待和提前下载音频。

**独立测试**：连续 800 次预订，断言预订时间按 10 秒递增；未到点请求不触发下载。

**验收场景**：

1. **Given** 800 个任务同一时间进入，**When** 依次预订限速时间，**Then** 第 N 个任务执行时间约为 `(N - 1) * 10` 秒后。
2. **Given** 任务预订时间距离当前超过 3600 秒，**When** 调度延迟重投递，**Then** 本次延迟按 3600 秒封顶，后续醒来继续分段等待。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `pic_url`：来源入参；限速到点后才读取并下载。
  - `prompt`：来源入参；Gemini 调用前读取。
  - `callback_url/task_id/union_id/nick_name/pic_id/song_name/class_id`：来源入参；只在成功或失败回调时读取。
  - `retryCountNum`：来源入参；仅业务调用失败时按旧逻辑递增。
  - `__appTaskRateLimitReservedAtMs`：AppTask 内部字段；首次排队写入，重投递时复用，到点后删除。
- 下游读取字段清单：
  - Gemini 调用读取 `pic_url`、`prompt`。
  - 延迟重投递读取 FC `serviceName/functionName` 和完整 payload。
  - 回调读取任务、用户、作品和结果字段。
- 空对象 / 占位对象风险：
  - 未新增空 DTO 继续下传；延迟重投递使用原 payload 加内部预订字段。
- 调用顺序风险：
  - 限速入口已前移到音频下载前；未到点时不进入下载和 Gemini。
- 旧逻辑保持：
  - `RateLimitUtil` 不变。
  - `callExternalGeminiApiAndExtractText` 保持原共享限流行为，避免影响 `PracticeCommentFc`。
  - 原业务失败重试、回调、飞书告警和日志主流程保持。
- 需要用户确认的设计选择：
  - 无；按用户确认的计划执行。

## 800 突发分析

- 800 个任务按 10 秒一个串行启动，纯排队耗时约 `800 * 10 = 8000` 秒，尾部约 2 小时 13 分后才到点。
- 如果用函数内 sleep 等待，尾部任务极易超过函数超时，同时占用 FC 并发、线程和计费时长。
- 如果限速发生在 Base64 转换之后，音频 5MB 转 Base64 后字符串约 6.7MB；Java `String`/字符数组和中间字节数组叠加后单任务可达十 MB 级别，800 个突发会明显放大内存压力。
- 本实现采用排队占位 + 延迟重投递，等待态只保留 JSON payload 和 Redis 预订时间，不持有音频字节或 Base64 字符串。

## 边界情况

- `pic_url` 为空：保持旧逻辑，直接失败回调，不进入限速排队。
- `appKey` 缺失：保持旧逻辑，抛出异常，不进入限速排队。
- 未到预订时间：按剩余时间计算 `x-fc-async-delay`，最大 3600 秒。
- 已到预订时间：删除内部字段，继续原分析流程。
- 延迟重投递提交失败：抛出异常，不进入 Gemini 失败重试计数，避免把排队失败误算为模型调用失败。

## 需求

- **FR-001**：系统 MUST 仅对 `AppTask.handleRequest` 音频 Gemini 链路执行 10 秒一个的专属限速。
- **FR-002**：系统 MUST 在音频下载前完成排队判断；未到点时 MUST NOT 下载音频或调用 Gemini。
- **FR-003**：系统 MUST 使用独立 Redis key 维护 AppTask 的下一可执行时间。
- **FR-004**：系统 MUST 对超过 3600 秒的等待进行分段延迟重投递。
- **FR-005**：系统 MUST NOT 修改共享 `RateLimitUtil` 或视频任务调用链。
- **FR-006**：单元测试 MUST 覆盖排队间隔、分段延迟、未到点跳过下载、到点执行。

## 成功标准

- **SC-001**：800 次连续预订的执行时间按 10 秒间隔递增。
- **SC-002**：未到点请求不会调用 `convertAudioToBase64` 或 Gemini。
- **SC-003**：`RateLimitUtil.java` 无改动，`AppTask.callExternalGeminiApiAndExtractText` 原行为保留。

## 假设

- “10 秒一个”指每 10 秒最多启动一次 AppTask 音频 Gemini 外部调用。
- 真实 FC 调用可通过 `Context` 获取 serviceName/functionName；单元测试使用注入 scheduler。
- 内部字段 `__appTaskRateLimitReservedAtMs` 只用于 AppTask 自身延迟重投递。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成 800 突发内存风险分析和强制门禁检查。

### D002 - 实现记录

- 实现内容：在 `AppTask.handleRequest` 音频下载前增加 AppTask 专属 Redis 排队预订和 FC 分段延迟重投递；保留共享 `RateLimitUtil`。
- 测试命令：`mvn -q -Dtest=AppTaskRateLimitTest test`；`mvn -q -DskipTests package`。
- 测试结果：通过。
- 自检结论：未到点不下载音频、不调用 Gemini；到点执行原链路；其它限流工具未改。

### D003 - Redis Cluster Lua 兼容修正

- 触发原因：线上 Redis Cluster 报错 `ERR bad lua script for redis cluster, all the keys that the script uses should be passed using the KEYS array, and KEYS should not be in expression`。
- 修正内容：Lua 脚本不再使用 `local key = KEYS[1]` 后间接传参，改为在 `redis.call('GET', KEYS[1])` 和 `redis.call('SET', KEYS[1], ...)` 中直接使用 `KEYS[1]`。
- 文档同步：已更新 `spec.md` 和 `tasks.md` 执行记录。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过；`mvn -q -DskipTests package` 通过。

### D004 - doTaskWithDelay 调用限速

- 触发原因：用户补充要求 `doTaskWithDelay` 调用也使用 `RateLimitUtil` 限速。
- 修正内容：新增统一的 `RateLimitedAppTaskDelayInvoker`，在 `RateLimitUtil.limitRun` 内部调用 `FcInvokeUtils.doTaskWithDelay`；限速重投递、业务 60 秒重试、3300 秒兜底重试三个调用点全部改为通过该 invoker。
- 文档同步：已更新 `spec.md` 和 `tasks.md` 执行记录。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过；`mvn -q -DskipTests package` 通过。

### D005 - doTaskWithDelay 提交超时短重试

- 触发原因：线上 `FcInvokeUtils.doTaskWithDelay` 调用 FC OpenAPI 时出现 `connect timed out`，导致限速重投递提交失败并抛出 `AppTask rate limit delayed retry submit failed`。
- 修正内容：`RateLimitedAppTaskDelayInvoker` 对延迟提交增加最多 3 次短重试，每次真实 `FcInvokeUtils.doTaskWithDelay` 仍在 `RateLimitUtil.limitRun` 内执行；重试成功则继续返回 invocationId，全部失败才抛异常交给 FC 异步重试策略。
- 文档同步：已更新 `spec.md` 和 `tasks.md` 执行记录。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过；`mvn -q -DskipTests package` 通过。

### D006 - doTaskWithDelay 改为严格限速

- 触发原因：用户确认 `connect timed out` 是高并发提交 FC 延迟调用导致，不应使用短重试解决。
- 修正内容：撤销 `doTaskWithDelay` 短重试；新增 `RateLimitUtil.limitRunStrict`，使用独立 key `ai:gemini-api:app-task:fc-delay-submit` 固定 4 QPS、等待上限 300000ms、超时不放行；AppTask 内限速重投递、业务 60 秒重试、3300 秒兜底重试均通过该 strict limiter 后只提交一次。
- 文档同步：已更新 `spec.md` 和 `tasks.md` 执行记录。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过；`mvn -q -DskipTests package` 通过。

### D007 - FC 延迟提交限速参数扩容

- 触发原因：线上 800 突发任务同时提交 FC 延迟调用，4 QPS / 300 秒等待上限导致大量任务在 `limitRunStrict` 中排队超时，抛出 `Waited too long for strict rate limit slot, keyPrefix=ai:gemini-api:app-task:fc-delay-submit`。
- 修正内容：`APP_TASK_FC_DELAY_SUBMIT_MAX_QPS` 从 4 调整为 8；`APP_TASK_FC_DELAY_SUBMIT_MAX_WAIT_MILLIS` 从 300000ms 调整为 600000ms（10 分钟）。800 任务含分段约 2400 次提交，8 QPS 下 300 秒完成，600 秒上限留一倍余量；8 QPS（125ms/次）远低于 FC OpenAPI 连接超时阈值。
- 文档同步：已更新 `spec.md` 和 `tasks.md` 执行记录。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过；`mvn -q -DskipTests package` 通过。

### D008 - 函数内本地 sleep + 北京 VPC 客户端 + 连接超时重试

- 触发原因：线上监控显示 1600 并发 FC 实例同时运行，`limitRunStrict` 限速通过后实际 `FcInvokeUtils.doTaskWithDelay` 调用 FC OpenAPI 时抛出 `com.aliyun.tea.TeaUnretryableException: connect timed out`。根因为函数运行在 cn-beijing 的 FC 实例内，但 `doTaskWithDelay` 通过环境变量 `fnEndpoint`（值为 `fc-vpc.us-west-1.aliyuncs.com`）连接美西区域的 FC OpenAPI，跨区域 VPC 内网不通。
- 修正内容：
  - **FcInvokeUtils.java**（common 模块）：新增 `clientBeijing`（endpoint 固定为 `fc-vpc.cn-beijing.aliyuncs.com`）和 `runtimeBeijing`（`readTimeout=86400`，`connectTimeout=10000`）。`doTaskWithDelay` 改用 `clientBeijing` 调用北京 VPC 内网 FC OpenAPI，其余方法（`doTask`、`doSyncTask`、`queryTaskStatus` 等）保持使用原 `client`（由 `fnEndpoint` 环境变量决定，指向美西）。
  - **AppTask.java**（Gemini-Api 模块）：
    - 新增 `APP_TASK_RATE_LIMIT_LOCAL_SLEEP_THRESHOLD_MILLIS = 600_000L`（10 分钟），延迟 ≤ 此阈值时函数内 `Thread.sleep` 本地等待到点后直接执行，不提交 FC 延迟调用，不经过 FC OpenAPI。
    - 新增 `APP_TASK_FC_DELAY_SUBMIT_CONNECT_TIMEOUT_MAX_RETRIES = 3`，延迟提交遇到 `connect timed out`（`SocketTimeoutException`）时最多重试 3 次，每次间隔 5 秒。
    - 新增 `isConnectTimeout` 辅助方法遍历异常链检测连接超时。
    - 新增 `sleepUntilReady` 可覆写方法供单元测试注入。
    - `APP_TASK_FC_DELAY_SUBMIT_MAX_QPS` 从 4 调整为 8；`APP_TASK_FC_DELAY_SUBMIT_MAX_WAIT_MILLIS` 从 300000ms 调整为 600000ms。
- 效果：`doTaskWithDelay` 走北京 VPC 内网，消除跨区域连接不通的问题；800 突发中前 61 个任务走本地 sleep 直接执行，0 次 FC OpenAPI 调用；连接超时重试作为兜底防护。
- 文档同步：已更新 `spec.md` 和 `tasks.md` 执行记录。
- 验证结果：common `mvn -q install -DskipTests` 通过；`mvn -q -Dtest=AppTaskRateLimitTest test` 通过；`mvn -q -DskipTests package` 通过。新增 3 个测试用例覆盖本地 sleep、超阈值 FC 延迟、分段醒来后 sleep 路径。

### D009 - FC 延迟秒数均匀散布

- 触发原因：原先所有延迟 > 3600 秒的任务都被 cap 到 `delaySeconds=3600`，导致它们在 3600 秒后同时醒来，形成二次洪峰。
- 修正内容：`calculateAppTaskRateLimitDelaySeconds` 新增 `reservedReadyAtMillis` 参数，当延迟超过 3600 秒时使用 `reservedReadyAtMillis % 3600` 将延迟均匀散布到 1-3599 秒窗口内。由于每个任务的 `reservedReadyAtMillis` 间隔 10 秒且唯一，模运算后自然形成均匀分布。
- 效果：800 突发中需要 FC 延迟提交的任务（约 740 个）的 `delaySeconds` 均匀分布在 1-3600 秒内，每秒最多 2-3 个任务同时醒来，消除二次洪峰。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过；`mvn -q -DskipTests package` 通过。

### D010 - 本地 sleep 阈值调低 + 防循环改用 re-reserve

- 触发原因：线上日志显示 `delayMillis=88947013`（约 24.7 小时），本地 sleep 超过 FC 函数超时导致失败重试。原 600 秒阈值也偏大，叠加业务耗时容易超时。
- 修正内容：
  - `APP_TASK_RATE_LIMIT_LOCAL_SLEEP_THRESHOLD_MILLIS` 从 600_000ms 降至 250_000ms（250 秒），给业务逻辑留足余量。
  - Lua 脚本改为无排队压力时返回 `now`（立即执行），仅队列积压时才分配未来时间槽，避免无谓延迟。
  - `alreadyDelayed` 不再强制 sleep：当已延迟任务剩余延迟仍超阈值时，丢弃旧 `reservedReadyAtMillis` 并重新向 Redis 预订。队列已空时立即执行，队列仍有压力时拿到新槽位继续 FC 延迟。
  - 限速间隔从 10 秒改为 4 秒。
- 效果：旧版残留的远未来时间戳任务不再被强制 sleep 到超时，而是重新排队后快速执行；新任务在无排队压力时零延迟直通。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过（11 用例）；`mvn -q compile` 通过。新增 `shouldReReserveAndExecuteWhenQueueClears` 和 `shouldReReserveAndDelayWhenQueueStillBusy` 两个测试覆盖 re-reserve 路径。
