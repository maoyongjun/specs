# 功能规格：钢琴视频识别超时与异常告警

**功能目录**: `013-piano-video-recognition-timeout-warn`  
**创建日期**: 2026-05-11  
**状态**: Implemented  
**输入**: 用户要求修改并实现：`PianoVideoHomeWorkHandleServiceImpl#handle` 在等待 10 分钟超时后不再进行重试，而是发送告警；告警编号为 `WX003`；同一个 `externalKey` 5 分钟内最多告警一次；`campName` 和 `userName` 由 `common_warn_sender` 内部基于 `external_key` 补齐，调用方无需传入模板变量；告警调用方式参考 `C:\workspace\ju-chat\coze_plugin\external-info-save\src\main\java\com\drh\info\service\AppTask.java` 的 `notifyBookRegisterWarn` 方法。新增要求：除等待超时外，钢琴视频识别处理链路发生异常时也需要发送 `WX003` 告警；识别成功但点评标题为 `未知` 时也需要发送 `WX003` 告警；异步识别任务写入缓存 `STATUS_FAIL` 且不是显式业务失败时也需要发送 `WX003` 告警，例如 `error=new supplier SDK call failed`；新供应商识别不再使用 Google GenAI SDK，改为 HTTP `generateContent` 中直接传入原始视频 URL；补充普通聊天和视频理解两个本地 test 方法，验证 baseUrl 固定为 `https://ent.univibe.cc`。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 钢琴视频识别等待 10 分钟超时后发送告警（优先级：P1）

钢琴视频作业异步识别首次触发后，系统最多等待 10 分钟识别结果。如果 10 分钟内未命中成功结果，也未得到明确失败状态，系统应结束识别等待并发送一次告警，提醒人工关注该学员的钢琴视频识别超时。

**独立测试**：构造钢琴视频作业消息，使异步识别在 10 分钟等待窗口内一直保持 `PENDING` 或 `RUNNING` 且无结果；验证系统调用 `common_warn_sender` 发送 `WX003` 告警，且入参包含可用于解析 `campName`、`userName` 的 `external_key`。

**验收场景**：

1. **Given** 首次异步识别已提交，**When** 10 分钟内缓存未出现 `SUCCESS` 结果，**Then** 系统发送 `WX003` 告警。
2. **Given** 系统发送 `WX003` 告警，**When** 构造告警入参，**Then** `sendTemplateList` 包含且仅需包含 `WX003`。
3. **Given** 系统发送 `WX003` 告警，**When** `common_warn_sender` 处理 `external_key`，**Then** 由该接口内部补齐 `campName` 和 `userName`。
4. **Given** 首次等待已经超时，**When** 告警发送完成或发送失败被捕获，**Then** `handle` 返回空 `HomeWorkResultDto`。

### 用户故事 2 - 钢琴视频识别处理异常后发送告警（优先级：P1）

钢琴视频作业识别链路中，如果异步任务提交、异步任务执行失败、等待轮询、缓存读写、结果解析或线程等待被中断等处理环节发生异常，系统应捕获异常、记录可检索日志，并尝试发送一次 `WX003` 告警，提醒人工关注该学员的钢琴视频识别异常。

**独立测试**：构造钢琴视频作业消息，并模拟 `Piano-homework-video` 异步提交抛出异常、返回非法 `invocationId`、异步任务写入 `STATUS_FAIL` 且 `error=new supplier SDK call failed`，或等待/解析结果过程抛出运行时异常；验证系统调用 `common_warn_sender` 发送 `WX003` 告警，且入参包含可用于解析 `campName`、`userName` 的 `external_key`。

**验收场景**：

1. **Given** 首次异步识别提交过程中 `FcInvokeUtils.doTask` 抛出异常或返回失败标识，**When** 系统捕获该异常，**Then** 系统发送 `WX003` 告警。
2. **Given** `Piano-homework-video` 异步任务执行失败并写入 `STATUS_FAIL`，**When** `waitForRecognitionResult` 读取到 `error=new supplier SDK call failed`，**Then** 系统发送 `WX003` 告警并记录阶段 `initial_async_task_fail`、错误信息、`messageId`、`cacheKey` 和 `externalKey`。
3. **Given** 识别等待、缓存读取或结果解析过程中抛出异常，**When** 系统捕获该异常，**Then** 系统发送 `WX003` 告警并记录异常阶段、异常类型和 `messageId`。
4. **Given** 等待线程被中断并转为识别等待异常，**When** 系统执行异常处理，**Then** 系统恢复中断状态、尝试发送 `WX003` 告警，并返回空 `HomeWorkResultDto`。
5. **Given** 异常告警发送完成或发送失败被捕获，**When** `handle` 结束处理，**Then** 原异常不应继续向主流程抛出，`handle` 返回空 `HomeWorkResultDto`。

### 用户故事 3 - 超时后不重试异步识别（优先级：P1）

为避免长时间阻塞和重复提交异步任务，首次 10 分钟等待超时后不再延迟等待，也不再重新调用识别函数。

**独立测试**：构造首次等待超时场景；验证 `triggerAsyncRecognitionIfNeeded` 总调用次数最多为 1 次，且不会出现 7 分钟延迟、第二次触发或第二个 10 分钟等待窗口。

**验收场景**：

1. **Given** 首次等待 10 分钟超时，**When** 系统处理超时，**Then** 不调用 `sleepQuietly(7 * 60 * 1000L)` 或任何等价延迟。
2. **Given** 首次等待 10 分钟超时，**When** 系统处理超时，**Then** 不再次调用 `triggerAsyncRecognitionIfNeeded`。
3. **Given** 同一个 `handle` 调用过程，**When** 统计异步识别触发尝试，**Then** 最多只有首次触发一次。

### 用户故事 4 - 告警调用格式对齐参考实现（优先级：P1）

超时和异常告警发送需要复用现有 `common_warn_sender` 调用方式，入参结构参考 `AppTask#notifyBookRegisterWarn`。

参考结构：

```json
{
  "external_key": "...",
  "sendTemplateList": ["WX003"]
}
```

实际调用方只需要传 `external_key` 和 `sendTemplateList=["WX003"]`，不需要传 `templateVariable`。

**独立测试**：拦截 `FcInvokeUtils.doTask` 入参，验证超时和异常告警均使用 `serviceName=service_sys`、`functionName=common_warn_sender`，`taskObj.external_key` 有值，`sendTemplateList=["WX003"]`，且未强制传入 `templateVariable`。

**验收场景**：

1. **Given** 超时或异常告警需要发送，**When** 构造 `FcInvokeInput`，**Then** `serviceName` 为 `service_sys`。
2. **Given** 超时或异常告警需要发送，**When** 构造 `FcInvokeInput`，**Then** `functionName` 为 `common_warn_sender`。
3. **Given** 超时或异常告警需要发送，**When** 构造 `taskObj`，**Then** 入参格式与 `notifyBookRegisterWarn` 一致，并使用 `WX003`。

### 用户故事 5 - 同一 externalKey 5 分钟内只告警一次（优先级：P1）

同一个学员上下文在 5 分钟内可能触发多次钢琴视频识别超时或异常。系统需要在本地调用 `common_warn_sender` 前做一次 `externalKey` 维度的去重，避免短时间内重复告警。

**独立测试**：连续构造两个相同 `externalKey` 的钢琴视频识别超时或异常场景；验证第一次会调用 `common_warn_sender`，第二次在 5 分钟窗口内命中去重并跳过告警。

**验收场景**：

1. **Given** 某 `externalKey` 首次触发超时或异常告警，**When** Redis 去重 key 不存在，**Then** 系统写入 300 秒过期的去重 key 并发送 `WX003`。
2. **Given** 同一 `externalKey` 在 5 分钟内再次触发超时或异常，**When** Redis 去重 key 仍存在，**Then** 系统不调用 `common_warn_sender`，并记录 `piano_video_recognition_timeout_warn_repeat_limited` 日志。
3. **Given** Redis 去重操作异常，**When** 系统处理超时或异常告警，**Then** 记录降级日志并继续发送告警，避免漏告警。

### 用户故事 6 - 钢琴视频识别成功但点评标题未知后发送告警（优先级：P1）

钢琴视频作业异步识别成功返回结构化结果后，如果 `title` 去空格后等于 `未知`，说明模型未能识别到明确作业标题或课程天数。系统应发送一次 `WX003` 告警提醒人工关注，但不改变原识别结果返回值，后续 SOP 流程继续按现有逻辑处理。

**独立测试**：构造识别成功结果 `{"id":0,"isHomeWork":"否","question":"指法没问题,手型没问题,节奏有问题,弹得还可以","title":"未知"}`；验证系统调用 `common_warn_sender` 发送 `WX003` 告警，且 `handle` 仍返回该识别结果。

**验收场景**：

1. **Given** 初始缓存命中成功结果，**When** 解析出的 `title` 为 `未知`，**Then** 系统发送 `WX003` 告警并返回原识别结果。
2. **Given** 等待异步识别命中成功结果，**When** 解析出的 `title` 为 `未知`，**Then** 系统发送 `WX003` 告警并返回原识别结果。
3. **Given** 识别成功结果的 `title` 不等于 `未知`，**When** 返回结果前检查标题，**Then** 不发送未知标题告警。
4. **Given** `title=未知` 告警需要发送，**When** 构造告警入参，**Then** 复用 `service_sys/common_warn_sender`、`sendTemplateList=["WX003"]`、`external_key`，且不传 `templateVariable`。
5. **Given** 同一 `externalKey` 在 5 分钟内已触发超时、异常或未知标题告警，**When** 再次触发未知标题告警，**Then** 命中同一 Redis 去重窗口并跳过 `common_warn_sender` 调用。

### 用户故事 7 - 新供应商识别使用 HTTP 视频 URL 直传生成（优先级：P1）

钢琴视频异步识别调用新供应商时，`PianoHomeWorkVideoTask` 不使用 Google GenAI SDK，也不再上传视频文件。系统应把业务传入的 `file_url` 作为 `file_data.file_uri` 直接放入 HTTP `generateContent` 请求，最后复用现有 `extractTextFromResponse` 提取点评文本。模块中其他旧接口（如 `PracticeCommentFc`）不属于本需求改造范围。新供应商 HTTP baseUrl 固定为 `https://ent.univibe.cc`。

**独立测试**：构造新供应商路径的钢琴视频任务；验证系统只调用 `POST https://ent.univibe.cc/v1beta/models/gemini-3-flash-preview:generateContent`，请求体包含 `text` prompt 和 `file_data.file_uri=<原始视频URL>`，且 `PianoHomeWorkVideoTask` 不依赖 `com.google.genai` SDK。

**验收场景**：

1. **Given** 新供应商路径被选中，**When** 开始识别，**Then** 系统不下载、不上传视频文件，直接使用输入 `file_url`。
2. **Given** 已获得 `file_url`，**When** 生成内容，**Then** 系统调用 `https://ent.univibe.cc/v1beta/models/gemini-3-flash-preview:generateContent`，请求体包含 `file_data.mime_type`、`file_data.file_uri` 和 `text` prompt。
3. **Given** `file_url` 后缀可识别，**When** 构造 `file_data.mime_type`，**Then** `.mp4` 默认使用 `video/mp4`，`.mov`、`.avi`、`.webm` 分别映射到对应视频 MIME Type。
4. **Given** HTTP 生成返回 2xx 和原始 Gemini JSON，**When** 现有 `extractTextFromResponse` 可提取文本，**Then** 写入 `STATUS_SUCCESS` 并返回识别结果。
5. **Given** HTTP 生成失败或响应文本为空，**When** 重试耗尽，**Then** 写入 `STATUS_FAIL`、`errorSource=ASYNC_TASK_FAIL`、`errorStage=piano_homework_video_task_analyze`。

### 用户故事 8 - 新供应商普通聊天与视频理解本地验证方法（优先级：P1）

为了区分网关基础文本能力和视频 URL 理解能力，`PianoHomeWorkVideoTask` 需要提供两个独立的本地 test 方法：一个验证普通聊天 `generateContent`，一个验证视频 URL 直传 `generateContent`。两个 test 方法都必须使用 `https://ent.univibe.cc` 作为 baseUrl，并从环境变量读取 `new_supplier_api_key`，不得把测试令牌写入代码、日志或文档。

**独立测试**：执行普通聊天 test 方法时，系统直接调用 `POST https://ent.univibe.cc/v1beta/models/gemini-3-flash-preview:generateContent`，请求体只包含文本 prompt；执行视频理解 test 方法时，系统使用同一 baseUrl 调用 `generateContent`，请求体包含文本 prompt 和 `file_data.file_uri=<视频URL>`。

**验收场景**：

1. **Given** 已配置 `new_supplier_api_key`，**When** 执行普通聊天 test 方法，**Then** 系统调用 `https://ent.univibe.cc/v1beta/models/gemini-3-flash-preview:generateContent` 并输出响应文本或可诊断错误。
2. **Given** 已配置 `new_supplier_api_key`、视频 URL 和视频理解 prompt，**When** 执行视频理解 test 方法，**Then** 系统调用 `https://ent.univibe.cc/v1beta/models/gemini-3-flash-preview:generateContent`，并以 `file_data.file_uri` 直传视频 URL 完成验证。
3. **Given** 普通聊天 test 失败，**When** 排查问题，**Then** 可判断是鉴权、baseUrl、模型或网关基础能力问题，而不是视频 URL 理解链路问题。
4. **Given** 普通聊天 test 成功但视频理解 test 失败，**When** 排查问题，**Then** 可优先定位外部视频 URL 可访问性、视频 MIME Type 或视频生成请求体。
5. **Given** 任一本地 test 失败，**When** 记录日志，**Then** 日志应包含 URL 路径、HTTP statusCode、响应头摘要和响应体摘要，但不得输出 `new_supplier_api_key`。

## 边界情况

- 本需求只修改钢琴视频作业处理类 `PianoVideoHomeWorkHandleServiceImpl` 的 `handle` 超时/异常处理及必要告警辅助方法。
- 首次 10 分钟等待内读取到 `SUCCESS` 时，必须保持现有行为，直接返回识别结果，不发送告警。
- 首次 10 分钟等待内读取到显式业务 `FAIL` 时，按明确失败处理，返回空结果；显式业务失败必须通过 `errorSource=BUSINESS_FAIL` 等可识别标记表达，不能与技术性异步任务失败混用。
- 如果 `FAIL` 是由本地异步提交异常、等待轮询异常、缓存读写异常、结果解析异常或线程中断等处理异常写入或触发，系统应按异常告警处理。
- 如果 `FAIL` 是由 `Piano-homework-video` 异步任务执行失败写入，例如 `error=new supplier SDK call failed` 且未标记 `errorSource=BUSINESS_FAIL`，系统应按异常告警处理。
- 10 分钟等待超时后，即使缓存仍为 `PENDING` 或 `RUNNING`，也不再等待 7 分钟，不再二次触发异步识别。
- `common_warn_sender` 依赖 `external_key`；实现时应从当前 SOP 上下文读取或构造可用 `external_key`，并在缺失时记录告警跳过日志。
- 超时和异常 `WX003` 告警发送前都需要按 `externalKey` 做本地 Redis 去重，沿用 key `ai:sopReply:pianoVideo:timeoutWarn:{externalKey}`，过期时间为 300 秒。
- 命中 5 分钟去重时应跳过 `common_warn_sender` 调用，并记录可检索日志。
- Redis 去重操作异常时继续发送告警，优先避免漏告警；此时可能无法严格保证 5 分钟只告警一次。
- `common_warn_sender` 调用失败时不删除去重 key，避免失败期间重复尝试造成告警风暴。
- `campName` 和 `userName` 是 `WX003` 模板变量，由 `common_warn_sender` 根据 `external_key` 补齐；调用方不需要传 `templateVariable`。
- 告警发送失败不应抛出影响主流程，应捕获异常并记录错误日志。
- 线程在 10 分钟等待期间被中断时，应恢复中断状态并按识别等待异常尝试发送告警。
- 识别成功但 `HomeWorkResultDto.title` 去空格后等于 `未知` 时，应发送 `WX003` 告警；该场景属于识别质量问题，不强制返回空结果。
- `title=未知` 告警不得改变原识别结果，应在告警发送完成、发送失败或命中去重后继续返回原 `HomeWorkResultDto`。
- `title=未知` 告警与超时、异常告警共用同一个 `externalKey` 维度 5 分钟 Redis 去重窗口。
- `PianoHomeWorkVideoTask` 新供应商路径不得依赖 Google GenAI SDK；避免 SDK 字段兼容问题影响识别链路。
- `PracticeCommentFc` 等旧接口不在本次 HTTP 化改造范围内，保持原状。
- 新供应商 HTTP 生成中的鉴权、网络、超时、非 2xx 等失败继续按异步任务失败处理。
- 新供应商 HTTP baseUrl 固定为 `https://ent.univibe.cc`；本地验证不得使用其他网关地址替代。
- 本地 test 方法只能从环境变量或命令行参数读取测试令牌、视频 URL 和 prompt，不得硬编码敏感令牌。

## 需求 *(必填)*

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下维护本 Spec Kit 目录。
- **FR-002**：实现范围 MUST 限定在 `PianoVideoHomeWorkHandleServiceImpl.java` 的 `handle` 超时/异常处理及必要私有辅助方法。
- **FR-003**：首次调用 `triggerAsyncRecognitionIfNeeded` 后，系统 MUST 等待最多 10 分钟识别结果。
- **FR-004**：首次等待 10 分钟超时且未读取到 `SUCCESS` 或 `FAIL` 时，系统 MUST 发送 `WX003` 告警。
- **FR-005**：首次等待 10 分钟超时后，系统 MUST NOT 再等待 7 分钟。
- **FR-006**：首次等待 10 分钟超时后，系统 MUST NOT 再次调用 `triggerAsyncRecognitionIfNeeded`。
- **FR-007**：同一次 `handle` 调用中，`triggerAsyncRecognitionIfNeeded` MUST 最多被调用一次。
- **FR-008**：`WX003` 告警 MUST 通过 `FcInvokeUtils.doTask` 调用 `service_sys/common_warn_sender`。
- **FR-009**：`WX003` 告警入参 MUST 设置 `sendTemplateList=["WX003"]`。
- **FR-010**：`WX003` 告警的 `campName` 和 `userName` MUST 由 `common_warn_sender` 内部根据 `external_key` 补齐，调用方 MUST NOT 依赖本地解析这两个变量。
- **FR-011**：`WX003` 告警入参 SHOULD 包含 `external_key`，格式和来源需满足 `common_warn_sender` 要求。
- **FR-012**：告警发送失败 MUST 被捕获并记录日志，不应中断或抛出主流程。
- **FR-013**：首次等待成功、明确业务失败、空入参、`fileUrl` 为空、缓存命中成功等现有短路行为 MUST 保持不变。
- **FR-014**：系统 SHOULD 增加可检索日志，覆盖识别等待超时、处理链路异常、告警入参、告警发送成功或失败、超时后不重试。
- **FR-015**：系统 MUST 在调用 `common_warn_sender` 前按 `externalKey` 做 5 分钟 Redis 去重。
- **FR-016**：去重 key MUST 为 `ai:sopReply:pianoVideo:timeoutWarn:{externalKey}`。
- **FR-017**：去重 key 过期时间 MUST 为 300 秒。
- **FR-018**：同一个 `externalKey` 在 5 分钟内再次触发超时或异常告警时，系统 MUST NOT 调用 `common_warn_sender`。
- **FR-019**：Redis 去重操作异常时，系统 MUST 记录日志并继续发送告警。
- **FR-020**：`common_warn_sender` 调用失败时，系统 MUST NOT 删除去重 key。
- **FR-021**：钢琴视频识别处理链路发生异常时，系统 MUST 发送 `WX003` 告警，异常范围包括异步提交异常、非法异步提交返回值、异步任务执行失败、等待轮询异常、缓存读写异常、结果解析异常和等待线程中断。
- **FR-022**：异常告警 MUST 复用与超时告警相同的 `service_sys/common_warn_sender`、`sendTemplateList=["WX003"]`、`external_key` 和不传 `templateVariable` 的入参约定。
- **FR-023**：异常告警 MUST 复用与超时告警相同的 5 分钟 `externalKey` Redis 去重规则。
- **FR-024**：异常告警发送完成或发送失败被捕获后，`handle` MUST 返回空 `HomeWorkResultDto`，不应继续向主流程抛出识别处理异常。
- **FR-025**：异常告警日志 MUST 包含异常阶段、异常类型或消息、`messageId`、`cacheKey` 和 `externalKey` 中可获得的信息。
- **FR-026**：钢琴视频识别成功结果解析后，如果 `HomeWorkResultDto.title` 去空格后等于 `未知`，系统 MUST 发送 `WX003` 告警。
- **FR-027**：`title=未知` 告警 MUST 复用与超时告警相同的 `service_sys/common_warn_sender`、`sendTemplateList=["WX003"]`、`external_key` 和不传 `templateVariable` 的入参约定。
- **FR-028**：`title=未知` 告警 MUST 复用与超时、异常告警相同的 5 分钟 `externalKey` Redis 去重规则。
- **FR-029**：`title=未知` 告警发送完成、发送失败或命中去重后，`handle` MUST 返回原识别结果，不应因该告警场景改为空结果。
- **FR-030**：`title=未知` 告警日志 MUST 包含 `messageId`、`cacheKey`、`externalKey`、`title`、`question`、`isHomeWork` 和 `id` 中可获得的信息。
- **FR-031**：系统读取到缓存 `STATUS_FAIL` 且未显式标记 `errorSource=BUSINESS_FAIL` 时，MUST 按异步任务执行失败发送 `WX003` 告警。
- **FR-032**：异步任务执行失败告警 MUST 复用异常告警的 `service_sys/common_warn_sender`、`sendTemplateList=["WX003"]`、`external_key`、不传 `templateVariable` 和 5 分钟 `externalKey` Redis 去重规则。
- **FR-033**：异步任务执行失败告警发送完成或发送失败被捕获后，`handle` MUST 返回空 `HomeWorkResultDto`，不应继续向主流程抛出异常。
- **FR-034**：`PianoHomeWorkVideoTask` 新供应商路径 MUST 使用 HTTP `generateContent`，并把原始视频 URL 作为 `file_data.file_uri` 传入；该类 MUST NOT 使用 Google GenAI SDK。
- **FR-035**：系统 MUST 使用 `NEW_SUPPLIER_BASE_URL=https://ent.univibe.cc` 替换示例中的 Google Base URL，并使用 `NEW_SUPPLIER_API_VERSION`、`NEW_SUPPLIER_MODEL` 和 `new_supplier_api_key` 构造 HTTP 请求。
- **FR-036**：系统 MUST 使用原始 `file_url` 作为 `file_data.file_uri`，并通过 URL 后缀推断 MIME Type；无法明确识别时默认 `video/mp4`。
- **FR-037**：系统 MUST NOT 调用 `{baseUrl}/upload/{apiVersion}/files`，也不得依赖 `x-goog-upload-url`。
- **FR-038**：新供应商路径 MUST NOT 下载视频字节或上传视频二进制；旧供应商路径保留原有行为。
- **FR-039**：系统 MUST 调用 `{baseUrl}/{apiVersion}/models/{model}:generateContent`，请求体包含 `file_data.file_uri`、`file_data.mime_type` 和 prompt 文本。
- **FR-040**：HTTP 生成成功返回 2xx 时，系统 MUST 返回原始响应 JSON，并继续复用现有 `extractTextFromResponse` 解析逻辑。
- **FR-041**：`PianoHomeWorkVideoTask` SHOULD 提供普通聊天本地 test 方法，用于验证 `POST https://ent.univibe.cc/v1beta/models/gemini-3-flash-preview:generateContent` 的纯文本 `generateContent` 能力。
- **FR-042**：`PianoHomeWorkVideoTask` SHOULD 提供视频理解本地 test 方法，用于验证 `https://ent.univibe.cc` 下的视频 URL 直传 `generateContent` 和响应文本提取。
- **FR-043**：普通聊天和视频理解 test 方法 MUST 从 `new_supplier_api_key` 读取令牌，不得硬编码测试令牌，不得在日志中输出令牌。
- **FR-044**：普通聊天和视频理解 test 方法失败时 SHOULD 输出可诊断的 statusCode、响应头摘要和响应体摘要。

## 成功标准 *(必填)*

- **SC-001**：本目录包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：首次等待 10 分钟超时后，系统发送 `WX003` 告警。
- **SC-003**：首次等待 10 分钟超时后，系统不再延迟 7 分钟，也不再二次调用 `triggerAsyncRecognitionIfNeeded`。
- **SC-004**：告警 `taskObj.sendTemplateList` 为 `["WX003"]`。
- **SC-005**：告警入参不要求传 `templateVariable`；`common_warn_sender` 能根据 `external_key` 补齐 `campName` 和 `userName`。
- **SC-006**：告警调用使用 `serviceName=service_sys`、`functionName=common_warn_sender`。
- **SC-007**：`fc/sop-reply` 模块编译通过。
- **SC-008**：同一 `externalKey` 在 5 分钟窗口内第二次触发超时时，不调用 `common_warn_sender`。
- **SC-009**：Redis 去重异常时仍继续调用 `common_warn_sender`。
- **SC-010**：异步提交、异步任务执行失败、等待轮询、缓存读写、结果解析或线程中断等识别处理异常后，系统发送 `WX003` 告警。
- **SC-011**：同一 `externalKey` 在 5 分钟窗口内先后触发超时和异常时，第二次不调用 `common_warn_sender`。
- **SC-012**：识别成功结果为 `{"id":0,"isHomeWork":"否","question":"指法没问题,手型没问题,节奏有问题,弹得还可以","title":"未知"}` 时，系统发送 `WX003` 告警并返回原识别结果。
- **SC-013**：识别成功结果的 `title` 不等于 `未知` 时，不发送未知标题告警。
- **SC-014**：同一 `externalKey` 在 5 分钟窗口内先后触发超时、异常或未知标题告警时，后续告警不调用 `common_warn_sender`。
- **SC-015**：当日志出现 `钢琴视频识别异步任务失败, cacheKey=..., waitStage=initial, error=new supplier SDK call failed` 对应场景时，系统发送 `WX003` 告警并返回空 `HomeWorkResultDto`。
- **SC-016**：`PianoHomeWorkVideoTask.java` 不包含 `com.google.genai` import，不调用 Google GenAI SDK。
- **SC-017**：新供应商路径通过 HTTP 完成视频 URL 直传、`generateContent` 和响应文本提取；HTTP 成功时不写入 `STATUS_FAIL`。
- **SC-018**：普通聊天 test 方法使用 `https://ent.univibe.cc/v1beta/models/gemini-3-flash-preview:generateContent` 完成纯文本 `generateContent` 验证。
- **SC-019**：视频理解 test 方法使用 `https://ent.univibe.cc/v1beta/models/gemini-3-flash-preview:generateContent`，并以 `file_data.file_uri=<视频URL>` 完成视频理解验证。
- **SC-020**：普通聊天和视频理解 test 方法均不在代码、日志或文档中暴露测试令牌。

## 假设

- `waitForRecognitionResult` 需要能区分成功、明确业务失败、超时与处理异常，或通过等价辅助结构让 `handle` 判断是否需要发送超时/异常告警。
- 现有 `MAX_WAIT_MILLIS` 继续表示单次等待窗口 10 分钟。
- 旧版 7 分钟延迟重试需求已被本规格替换，当前实现已移除延迟重试逻辑。
- `common_warn_sender` 会基于 `external_key` 自动补齐基础变量，`WX003` 仍以 `campName`、`userName` 作为业务变量。
- “只告警一次”按同一 `externalKey` 维度计算，不区分 `messageId`，也不区分超时或异常触发原因。
- 5 分钟限制的是发送尝试次数；即使 `common_warn_sender` 调用失败，也不会在 5 分钟内重复尝试。
- 原超时告警规格已实现并通过 `fc/sop-reply` 模块编译验证；异常告警增量规格已实现并通过 `fc/sop-reply` 模块编译验证。
- “点评的是未知”按 `HomeWorkResultDto.title == "未知"` 理解，不检查 `question` 内容。
- `title=未知` 是识别质量问题，不等同于超时或本地异常，所以告警后仍返回识别结果，不强制返回空结果。
- 当前 `Piano-homework-video` 的 `STATUS_FAIL` 来源是异步任务执行失败；若未来需要表达明确业务失败，应显式写入 `errorSource=BUSINESS_FAIL`。
- 新供应商 HTTP 接口固定使用 `https://ent.univibe.cc`，兼容 Gemini `v1beta/models/{model}:generateContent` 路径，并接受 `x-goog-api-key` 认证头。
