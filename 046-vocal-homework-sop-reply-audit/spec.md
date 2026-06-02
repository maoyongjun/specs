# 功能规格：声乐作业点评 SopReply 迁移核查

**功能目录**：`046-vocal-homework-sop-reply-audit`  
**创建日期**：`2026-06-02`  
**状态**：Audit Completed  
**输入**：用户要求在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档，并核查“声乐作业点评后来调整到调用 `sop-reply` 函数，大概 4 月 18 号左右修改的，这段代码在哪里，现在是不是不在走 `homework-review` 函数了”。

## 背景

- 当前问题：需要定位声乐作业点评迁移到 `sop-reply` 的真实代码位置，并判断当前调用链是否仍可能走 `homework-review`。
- 当前行为：`delay-mq` 作业点评入口根据灰度配置决定是否调用 `sop-reply`；未命中灰度或 `sop-reply` 异常时仍调用 `homework-review`。`sop-reply` 进入 handler 后会先做时间窗口检查，若拿不到时间窗口配置会直接跳过后续识别和点评。
- 现场排查先看三件事：作业点评开关是否开启，课程时间是否落在允许范围内，实际调用链是否为 `Delay-mq -> sop-reply`。
- 目标行为：形成可复查的代码事实文档，明确迁移提交、关键路径、运行时配置和剩余未知点。
- 非目标：本次不修改 Java 代码、不调整线上配置、不变更 FC、MQ、Redis、数据库或外部接口。

## 用户场景与测试

### 用户故事 1 - 定位迁移代码（优先级：P1）

用户需要知道 2026-04-18 前后声乐作业点评迁移到 `sop-reply` 的代码在哪里。

**独立测试**：通过 `git log`、`git show` 和 `rg` 静态核查迁移提交及相关类。

**验收场景**：

1. **Given** 本地仓库 `C:\workspace\ju-chat\fc`，**When** 查看 2026-04-16 至 2026-04-18 的提交，**Then** 能定位 `1ded7b8`、`884b064`、`6b276d4` 与迁移和匹配逻辑相关。
2. **Given** 当前代码，**When** 搜索 `sop-reply` 与 `homework-review`，**Then** 能定位 `delay-mq` 调用方、`sop-reply` handler 和 `homework-review` 旧 handler。

### 用户故事 2 - 判断当前是否还走 homework-review（优先级：P1）

用户需要知道当前是否已经完全不走 `homework-review`。

**独立测试**：静态读取 `AppTask` 和 `VoiceService` 的分支逻辑。

**验收场景**：

1. **Given** `homeWorkSopReplyPercent` 小于 100 或未配置，**When** 处理支持的作业消息，**Then** 只有命中灰度才先调用 `sop-reply`，未命中仍调用 `homework-review`。
2. **Given** `sop-reply` 调用异常，**When** 进入 catch 分支，**Then** 代码会兜底调用 `homework-review`。
3. **Given** 线上 `homeWorkSopReplyPercent=100` 且 `sop-reply` 调用成功，**When** 处理支持消息类型，**Then** 主链路可视为先走 `sop-reply`，但异常时仍保留 `homework-review` 兜底。

### 用户故事 3 - 分析 sopReply time window config is empty（优先级：P1）

用户需要知道 `sopReply time window config is empty` 的触发原因，以及它和旧 `homework-review` 时间窗口逻辑的差异。

**独立测试**：静态读取 `sop-reply/SopReply.checkTimeIsOpen()`、`getConfigTimes()`、`getHomeBeginTime()` 和旧 `homework-review/AppTask.checkTimeIsOpen()`。

**验收场景**：

1. **Given** Redis key `ai:configTime:{campDateId}:{dayNum}` 没有值，且 `/endpoint/ai/user/info` 返回缺少 `jsonObject.live_end_time`，**When** `SopReply.getConfigTimes()` 被调用，**Then** 返回空列表并触发 `sopReply time window config is empty`。
2. **Given** `sop-reply` 打出该 warning，**When** `checkTimeIsOpen()` 返回 false，**Then** `SopReply.handleRequest()` 会在作业识别前返回空 `HomeWorkResultDto`。
3. **Given** 旧 `homework-review` 的新课程时间逻辑取不到 `configTimes`，**When** `AppTask.checkTimeIsOpen()` 继续执行，**Then** 旧逻辑会 fallback 到 `checkTimeOld()`，而当前 `SopReply` 没有这个 fallback。

### 用户故事 4 - 三点排查口径（优先级：P2）

用户需要一个简短的现场排查口径，能快速判断是不是开关、时间窗口、还是调用链出了问题。

**独立测试**：直接核对开关配置、课程时间 SQL、以及 `delay-mq -> sop-reply` 的调用入口。

**验收场景**：

1. **Given** `ai_auto_review_config` 中 `aiAutoReview=1` 且 `aiStatus=1`，**When** 现场核对作业点评开关，**Then** 可以判定开关已开启。
2. **Given** `drh_live` 中 `live_camp_id=1692 and mark=1 and is_del=0` 查询出的 `class_time` 落在当前时间窗内，**When** 核对课程时间，**Then** 可以判定课程时间满足点评前置条件。
3. **Given** `delay-mq` 处理消息后进入 `sop-reply`，**When** 查看调用链，**Then** 可以确认实际链路是 `Delay-mq -> sop-reply`。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `homeWorkSopReplyPercent`：来源 `ConfigUtil.getValue("homeWorkSopReplyPercent")`；在 `delay-mq/AppTask.getSopReplyPercent()` 中读取；未配置默认 `10`。
  - `sopReplyServiceName`：来源环境变量；在 `delay-mq/VoiceService.getSopReplyServiceName()` 中读取；未配置默认 `service_sys`。
  - `sopReplyFunctionName`、`sopReplyFunctionNameProd`、`sopReplyFunctionNameTest`：来源环境变量；在 `delay-mq/VoiceService.getSopReplyFunctionName()` 中读取；默认 `sop-reply-test`。
  - `recognitionOnly`：来源 `VoiceService.invokeSopReplyFc(webChatVoiceDto, true)`；用于作业点评未开启时只识别不点评。
  - `WebChatVoiceDto`：由 `delay-mq/AppTask.homeWorkHandle()` 从 `EmpExternalDto` 拷贝并补充 `messageModels`，传入 `VoiceService`。
- `configTimes`：来源 Redis key `ai:configTime:{campDateId}:{dayNum}`；无缓存时由 `CenterUtil.selectUserJson()` 返回的 `jsonObject.live_end_time` 加 1 分钟后拼接生成；生成后缓存 24 小时。
- `live_end_time`：来源 `POST {sys_domain}/endpoint/ai/user/info` 的响应字段 `jsonObject.live_end_time`；请求参数为 `external_user_id`、`emp_id`、`camp_date_id`、`user_id`。
- 作业点评开关：由 `ai_auto_review_config` 控制，现场核对时以 `aiAutoReview=1`、`aiStatus=1` 为开启条件，且需匹配对应 `chatList` / `qwUserId`。
- 课程时间：可通过 `drh_live` 查询 `live_camp_id=1692 and mark=1 and is_del=0 order by class_time limit 6` 核对 `class_time` 是否处于可点评时间段。
- 下游读取字段清单：
  - `delay-mq/AppTask.shouldInvokeSopReply()` 读取 `msgType`、`messageId`、`external_user_id`、`user_id`、`timestamp`、`camp_date_id`。
  - `delay-mq/VoiceService.buildSopReplyRequest()` 读取 `day`、`text`、`external_user_id`、`emp_id`、`camp_date_id`、`user_id`、`skuId`。
  - `sop-reply/SopReply.handleRequest()` 读取 `SopReplyRequestDto.day`、`question`、`recognitionOnly`、`userMsg`、`routeParams`。
  - `sop-reply/SopReply.checkTimeIsOpen()` 读取 `day`、`external_user_id`、`emp_id`、`camp_date_id`、`user_id`，并依赖 Redis 与 Center 用户信息接口返回课程结束时间。
  - `Delay-mq -> sop-reply`：`delay-mq` 在 AI 开启、灰度命中或识别-only 需要时调用 `sop-reply`；这就是现场判断“链路是否已切到 sop-reply”的入口。
  - `homework-review/AppTask.handleRequest()` 仍接收原始 `WebChatVoiceDto`。
- 空对象 / 占位对象风险：
  - 本次不改代码，仅记录风险。当前调用链存在返回 `new HomeWorkResultDto()` 表示未命中或跳过的旧口径，后续实现不得误判为空对象等同成功点评。
- 调用顺序风险：
  - `delay-mq/AppTask` 先判断 AI/作业点评开关和群聊配置，再进入 `sop-reply`/`homework-review` 分支。
  - `SopReply.handleRequest()` 在作业识别前先调用 `checkTimeIsOpen()`；如果时间窗口配置为空，会直接返回空结果，不会进入 `recognizeHomeworkIfNeeded()`。
  - `sop-reply` 成功发送后才持久化点评进度和打标签；预览发送模式会跳过持久化和标签。
- 旧逻辑保持：
  - `homework-review` fallback 必须保持，除非业务明确取消。
  - 群聊分支、作业点评未开启时的 `recognitionOnly` 分支、消息类型过滤、时间窗口、去重、异常日志和通用聊天回退不得因文档核查而改变。
  - 旧 `homework-review` 的时间窗口逻辑在新课程时间获取为空时会 fallback 到 `checkTimeOld()`，其中包括 `enableTime` 配置和部分特殊企微账号时间窗口；当前 `SopReply` 没有该 fallback。
- 需要用户确认的设计选择：
  - 是否把 `homeWorkSopReplyPercent` 调到 100。
  - 是否移除 `homework-review` fallback。
  - 是否将 prod 默认 function 从 `sop-reply-test` 改为其他函数名。

## 边界情况

- `homeWorkSopReplyPercent` 缺失：代码默认 10%，不是全量 `sop-reply`。
- `homeWorkSopReplyPercent` 非法：代码记录 warning 并回退默认 10%。
- `homeWorkSopReplyPercent <= 0`：不调用 `sop-reply`，走 `homework-review`。
- `homeWorkSopReplyPercent >= 100`：支持消息类型全部先调 `sop-reply`。
- `sop-reply` 调用异常：catch 后调用 `homework-review`。
- 非支持消息类型：`shouldInvokeSopReply()` 返回 false，不走 `sop-reply` 灰度。
- 作业点评未开启且语音消息：调用 `sop-reply` 的 `recognitionOnly`，识别是作业则不回复；识别非作业继续通用聊天。
- 仓库无法确认线上配置值：必须查运行时配置或 FC 环境变量。
- `sopReply time window config is empty`：只在 `day/userMsg` 有效、`getConfigTimes()` 返回空时出现；这不是“当前时间不在窗口”的同义日志，而是“没有任何可用时间窗口配置”。
- Redis 无缓存且 Center 接口无 `live_end_time`：`getConfigTimes()` 返回空列表，`SopReply` 直接跳过点评。
- Center 接口异常或 `live_end_time` 格式解析失败：会触发 `sopReply time window check failed`，不是 `config is empty`。
- `day` 非法或 `userMsg` 为空：会触发 `sopReply time window check skipped because day/userMsg is invalid`，不是 `config is empty`。
- 旧 `homework-review` 取不到新课程时间时会 fallback 到旧时间配置；`sop-reply` 当前不会 fallback，所以迁移后同一用户可能在 `homework-review` 可点评、在 `sop-reply` 被时间窗口拦截。
- 现场排查顺序建议：先确认开关，再确认课程时间，最后确认是否走到 `Delay-mq -> sop-reply`。

## 需求

### 功能需求

- **FR-001**：文档 MUST 明确迁移代码位置、旧入口位置和当前调用链判断。
- **FR-002**：文档 MUST 记录 2026-04-16 至 2026-04-18 的相关提交及变更含义。
- **FR-003**：文档 MUST 明确当前代码仍可能走 `homework-review` 的条件。
- **FR-004**：文档 MUST 区分仓库代码事实和线上运行时配置未知点。
- **FR-005**：本次 MUST NOT 修改业务代码、线上配置、FC、MQ、Redis 或数据库。
- **FR-006**：文档 MUST 记录 `sopReply time window config is empty` 的触发链路、直接影响和与旧 `homework-review` 时间窗口 fallback 的差异。
- **FR-007**：文档 MUST 记录现场排查的三步口径：开关、课程时间、调用链。

## 成功标准

- **SC-001**：`046-vocal-homework-sop-reply-audit` 目录包含完整 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：文档中不残留模板占位符。
- **SC-003**：文档明确回答“当前不是无条件不走 `homework-review`，仍受灰度和 fallback 影响”。
- **SC-004**：`specs` 仓库只新增本需求目录，不触碰 `fc` 的既有未提交变更。
- **SC-005**：文档明确说明 `sopReply time window config is empty` 的最可能原因是 Redis 时间窗口无缓存且 Center 用户信息返回缺少 `live_end_time`，导致 `SopReply` 在识别前返回空结果。
- **SC-006**：文档包含开关、课程时间和调用链三点的简明排查口径。

## 假设

- 本次核查仅基于本地仓库代码和 git 历史。
- 线上运行时配置未在本地仓库中保存；需要单独查询才能确认当前实际灰度比例和 FC handler。
- `sop-reply-test` 是代码默认函数名；线上可通过环境变量覆盖。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成代码事实确认：`delay-mq` 中存在 `sop-reply` 灰度调用和 `homework-review` fallback。
- 已完成历史提交确认：
  - `1ded7b8`，2026-04-16 19:00:55 +0800，`声乐作业点评迁移`。
  - `523c387`，2026-04-17 15:27:48 +0800，`声乐点评作业`。
  - `884b064`，2026-04-18 18:52:33 +0800，`声乐点评作业按企业微信配置语音`。
  - `6b276d4`，2026-04-18 19:22:28 +0800，`多条件匹配的处理`。
- 本阶段未修改业务代码。

### D002 - 后续运行时配置核验

- 待查询：线上 `homeWorkSopReplyPercent` 当前值。
- 待查询：线上 `sopReplyServiceName` 和 `sopReplyFunctionName*` 环境变量。
- 待查询：线上 `sop-reply` 函数实际 handler 绑定。

### D003 - time window config is empty 分析

- 触发位置：`C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\service\SopReply.java` 的 `checkTimeIsOpen()`。
- 触发条件：`getConfigTimes(dayNum, externalUserId, empId, campDateId, userId)` 返回空。
- 配置来源：先读 Redis key `ai:configTime:{campDateId}:{dayNum}`；未命中时调用 `CenterUtil.selectUserJson()`，从响应 `jsonObject.live_end_time` 推导时间窗口。
- 直接影响：`checkTimeIsOpen()` 返回 false，`handleRequest()` 在作业识别前返回空 `HomeWorkResultDto`，因此不会继续 SOP 发送。
- 与旧逻辑差异：旧 `homework-review/AppTask.checkTimeIsOpen()` 在课程时间为空时会 fallback 到 `checkTimeOld()`；当前 `SopReply.checkTimeIsOpen()` 没有 fallback。
- 待核验运行时数据：Redis key 是否存在、`/endpoint/ai/user/info` 请求参数是否完整、接口响应是否包含 `jsonObject.live_end_time`、`sys_domain` 是否正确。

### D004 - 三点排查口径

- 作业点评开关：核对 `ai_auto_review_config:568:269` 或 `ai_auto_review_config:%s:%s`，确认 `{"aiAutoReview":1,"aiStatus":1,"chatList":["wraZOBSgAAH9bUZP_bubjJNTu5Lz5h0A"],"qwUserId":"Dong"}` 这类配置处于开启状态。
- 课程时间：核对 `drh_live`，示例条件为 `live_camp_id=1692 and mark=1 and is_del=0 order by class_time limit 6`，确认 `class_time` 落在允许时间内。
- 调用链：确认实际链路是 `Delay-mq -> sop-reply`。
