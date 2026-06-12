# 任务清单：Gemini AppTask 10 秒限速与突发保护

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段补充与关键行为一一对应的单元测试和编译验证。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标为 `fc/Gemini-Api` 的 `AppTask`。
- [x] T002 用代码搜索确认真实入口为 `AppTask.handleRequest`，原音频调用点为 `convertAudioToBase64(picUrl)` 后调用 Gemini。
- [x] T003 确认关键参数来自入参 JSON，内部排队字段由 AppTask 写入并在到点后删除。
- [x] T004 确认受影响外部资源为 Redis 独立 key 和 FC async delay；不改 MQ、数据库、回调协议。
- [x] T005 确认共享 `RateLimitUtil`、视频任务、回调、业务失败重试和飞书告警必须保持不变。

## Phase 2：风险门禁

- [x] T006 未新增空 DTO、空 JSON、空 Map 继续下传。
- [x] T007 调用顺序已调整为先排队、到点后再下载音频。
- [x] T008 未到点时下游 Gemini 参数不会被读取或构造。
- [x] T009 改动外部行为仅限 AppTask 专属 Redis key 和 FC 延迟重投递。
- [x] T010 不修改共享限流，避免影响其它调用方。
- [x] T011 测试映射覆盖 800 预订、分段延迟、未到点跳过下载、到点执行。

## Phase 3：实现

- [x] T012 在 `AppTask` 增加 Redis 排队预订逻辑和可测试注入点。
- [x] T013 在 `handleRequest` 下载音频前接入排队判断。
- [x] T014 未到点时用现有 `FcInvokeUtils.doTaskWithDelay` 重投递，最大延迟 3600 秒。
- [x] T015 保留 `callExternalGeminiApiAndExtractText` 的共享 `RateLimitUtil` 调用。

## Phase 4：测试与验证

- [x] T016 新增 `AppTaskRateLimitTest`。
- [x] T017 测试断言未到点时不下载、不调用 Gemini。
- [x] T018 测试断言到点后执行并清理内部字段。
- [x] T019 已运行 `mvn -q -Dtest=AppTaskRateLimitTest test`。
- [x] T020 运行模块打包验证并搜索确认无共享限流改动。

## 执行记录

### D001 - 文档记录

- 执行内容：创建规格文档目录并记录需求、风险和测试映射。
- 验证方式：文档检查和代码搜索。
- 自检结论：满足进入实现的强制门禁。

### D002 - 实现记录

- 实现内容：AppTask 专属排队限速、FC 分段延迟重投递、单元测试。
- 测试命令：`mvn -q -Dtest=AppTaskRateLimitTest test`；`mvn -q -DskipTests package`。
- 测试结果：通过。
- 自检结论：未到点请求不会持有音频 Base64；共享限流未改。

### D003 - Redis Cluster Lua 兼容修正

- 触发原因：线上 Redis Cluster 不允许 Lua 脚本把 `KEYS[1]` 赋值给局部变量后再作为 key 传入 `redis.call`。
- 修正内容：Lua 脚本改为直接在 `redis.call` 中使用 `KEYS[1]`。
- 文档同步：已同步 `spec.md` 和 `tasks.md`。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过；`mvn -q -DskipTests package` 通过。

### D004 - doTaskWithDelay 调用限速

- 触发原因：用户补充要求通过 `doTaskWithDelay` 的重投递调用也要限速。
- 修正内容：限速重投递、业务 60 秒重试、3300 秒兜底重试统一通过 `RateLimitedAppTaskDelayInvoker`，真实 `FcInvokeUtils.doTaskWithDelay` 在 `RateLimitUtil.limitRun` 内执行。
- 文档同步：已同步 `spec.md` 和 `tasks.md`。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过；`mvn -q -DskipTests package` 通过。

### D005 - doTaskWithDelay 提交超时短重试

- 触发原因：线上 `doTaskWithDelay` 调用 FC OpenAPI 偶发 `connect timed out`。
- 修正内容：`RateLimitedAppTaskDelayInvoker` 增加最多 3 次短重试，并新增测试覆盖前两次失败、第三次成功。
- 文档同步：已同步 `spec.md` 和 `tasks.md`。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过；`mvn -q -DskipTests package` 通过。

### D006 - doTaskWithDelay 改为严格限速

- 触发原因：用户确认不使用短重试，应从限速角度降低 FC OpenAPI 并发提交压力。
- 修正内容：撤销短重试；新增 `RateLimitUtil.limitRunStrict`；AppTask 的三个 `doTaskWithDelay` 调用点统一使用独立 key 严格 4 QPS 限速，超过等待上限直接抛异常，不 fail-open。
- 文档同步：已同步 `spec.md` 和 `tasks.md`。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过；`mvn -q -DskipTests package` 通过。

### D007 - FC 延迟提交限速参数扩容

- 触发原因：线上 800 突发任务同时竞争 FC 延迟提交通道，4 QPS / 300 秒等待上限不足，`limitRunStrict` 抛出 `Waited too long for strict rate limit slot`。
- 修正内容：`APP_TASK_FC_DELAY_SUBMIT_MAX_QPS` 从 4 调整为 8；`APP_TASK_FC_DELAY_SUBMIT_MAX_WAIT_MILLIS` 从 300000ms 调整为 600000ms。
- 文档同步：已同步 `spec.md` 和 `tasks.md`。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过；`mvn -q -DskipTests package` 通过。

### D008 - 函数内本地 sleep + 北京 VPC 客户端 + 连接超时重试

- 触发原因：`doTaskWithDelay` 通过 `fnEndpoint`（`fc-vpc.us-west-1.aliyuncs.com`）连接美西 FC OpenAPI，但函数运行在 cn-beijing，跨区域 VPC 内网不通导致 `connect timed out`。
- 修正内容：
  - **FcInvokeUtils.java**：新增 `clientBeijing`（`fc-vpc.cn-beijing.aliyuncs.com`），`doTaskWithDelay` 改用北京 VPC 客户端；其余方法保持原 `client`。
  - **AppTask.java**：新增本地 sleep（≤ 600 秒）、连接超时重试（3 次/5 秒间隔）、QPS 4→8、等待上限 300s→600s。
- 测试：新增 3 个用例；common `mvn install` 通过；Gemini-Api 测试和打包通过。
- 文档同步：已同步 `spec.md` 和 `tasks.md`。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过；`mvn -q -DskipTests package` 通过。

### D009 - FC 延迟秒数均匀散布

- 触发原因：所有延迟 > 3600 秒的任务都被 cap 到 `delaySeconds=3600`，导致同时醒来形成二次洪峰。
- 修正内容：`calculateAppTaskRateLimitDelaySeconds` 新增 `reservedReadyAtMillis` 参数，超过 3600 秒时使用 `reservedReadyAtMillis % 3600` 均匀散布。
- 文档同步：已同步 `spec.md` 和 `tasks.md`。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过；`mvn -q -DskipTests package` 通过。

### D010 - 本地 sleep 阈值调低 + 防循环改用 re-reserve

- 触发原因：线上 `delayMillis=88947013`（约 24.7 小时），本地 sleep 超 FC 函数超时导致失败重试；原 600s 阈值也偏大。
- 修正内容：
  - 本地 sleep 阈值 600s → 250s；限速间隔 10s → 4s。
  - Lua 脚本改为无排队压力时返回 `now`（零延迟直通）。
  - `alreadyDelayed` 不再强制 sleep；超阈值时丢弃旧时间戳重新预订，队列空则立即执行。
- 测试调整：新增 `shouldReReserveAndExecuteWhenQueueClears` 和 `shouldReReserveAndDelayWhenQueueStillBusy`。
- 文档同步：已同步 `spec.md` 和 `tasks.md`。
- 验证结果：`mvn -q -Dtest=AppTaskRateLimitTest test` 通过（11 用例）；`mvn -q compile` 通过。
