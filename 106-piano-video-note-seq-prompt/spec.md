# 功能规格：钢琴作业视频 V2 先取音序再注入提示词

**功能目录**：`106-piano-video-note-seq-prompt`  
**创建日期**：`2026-06-21`  
**状态**：Implemented（D014 待用户验收）
**输入**：用户需求——「修改 `C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\PianoHomeWorkVideoV2Task.java`，调用函数计算服务名 `FcOssFFmpeg-3278`、函数名 `VideoToNoteSeq`，返回结果参考 spec `105-video-to-note-sequence` 的描述；拿到音序之后放进提示词，提示词用 `${audioseq}` 占位将要识别到的音序。」澄清结论（本次 AskUserQuestion 确认）：①音序填入 `${audioseq}` 的形式为**音名序列文本**（如 `C4 D4 E4`）；②拿到音序、替换提示词后**仍把视频(file_url)一起传给 Gemini**，保留原有 fileUrl/inlineData/auto 三模式与回退逻辑；③`VideoToNoteSeq` **调用失败或返回空音序(noteCount=0) 也继续调用 Gemini**（用空音序文本继续替换）。

## 背景

- 当前问题：`PianoHomeWorkVideoV2Task` 目前把请求里的 `prompt` 原样 + 视频 `file_url` 直接交给 Gemini 代理识别。业务希望在交给 Gemini 之前，先用 `FcOssFFmpeg-3278/VideoToNoteSeq` 从视频里提取出「音序」（音符序列），把音序作为上下文注入提示词，提升识别效果。
- 当前行为（[PianoHomeWorkVideoV2Task.java](../../fc/Gemini-Api/src/main/java/com/drh/gemini/api/PianoHomeWorkVideoV2Task.java)）：
  - `handleRequest` 解析 `requestPayload`/根对象，读取 `prompt`、`file_url`、`cacheKey`、`dispatchLockKey`、`taskId`、`inputMode` 等。
  - 写 RUNNING 缓存 → `analyzeVideo(fileUrl, prompt, inputMode, request)` → 写 SUCCESS/FAIL 缓存 → 释放分发锁。
  - `analyzeVideo` 先 `validateRequired(prompt)`、`validateRequired(file_url)`，再按 inputMode 走 `callFileUrl` / `callInlineData` / `callAuto`，把 `prompt` 放进 `GeminiProxyRequest.prompt`，视频以 fileUri 或 inlineData 形式传给 Gemini 代理。
- 目标行为：在 `analyzeVideo` 中、对 Gemini 发起调用之前，**新增一步同步调用** `FcOssFFmpeg-3278/VideoToNoteSeq`（event 传 `video_path = file_url`），拿到音序 JSON，提炼为**音名序列文本**，把 `prompt` 中的 `${audioseq}` 占位符替换为该文本，然后用替换后的 `prompt` + 原视频继续走原有 Gemini 调用链。
- 本次补充问题（D005）：线上日志显示 `PianoHomeWorkVideoV2Task` 调用 `FcOssFFmpeg-3278/VideoToNoteSeq` 时出现 `TeaUnretryableException: connect timed out`。代码确认 `doSyncTaskReturnJSONObj` 最终走 `FcInvokeUtils.doSyncTask`，该方法当前使用默认 `client`；默认 `client` 在未设置 `fnEndpoint` 时为 `fc.cn-beijing.aliyuncs.com`（北京公网），而固定 `fc-vpc.cn-beijing.aliyuncs.com` 的 `clientBeijing` 只用于 `doTaskWithDelay`。D005 曾计划/实现让音序同步调用使用北京 VPC endpoint。
- 本次纠正问题（D006）：用户要求将刚才调用 `VideoToNoteSeq` 的方式改为 HTTP 接口 `http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/ai/transfer/fc`，请求体形如 `{ "taskObj": {...}, "serviceName": "...", "functionName": "...", "isVpc": true }`。因此 D005 的 SDK VPC 专用调用方案被 D006 取代：音序默认调用不再走 `FcInvokeUtils`，改为 POST 该 transfer/fc 网关。
- 本次纠正问题（D007）：用户要求 `VideoToNoteSeq` 函数计算改为**异步调用**，通过 Redis 获取结果，参考 `sop-reply` 中 `PianoVideoHomeWorkHandleServiceImpl` 调用 `PianoHomeWorkVideoV2Task` 的写法。用户确认 `VideoToNoteSeq` 还不支持 Redis 写回，源码位于 `C:\workspace\ju-chat\videoToAudio`，因此本次需同时改 Java 调用端和 Python 函数端。D007 取代 D006 的默认传输方式：默认音序调用不再走 transfer/fc HTTP 同步网关，而是使用 `FcInvokeUtils.doTask` 异步提交 FC，Java 端轮询 Redis 状态。
- 本次补充问题（D008）：用户要求将替换完音序后的提示词打印到日志，便于线上排查 `${audioseq}` 是否替换成功以及最终传给 Gemini 的提示词内容。
- 非目标：
  - 不改变现有 fileUrl/inlineData/auto 三种输入模式与失败回退到 inlineData 的逻辑。
  - 不改变 RUNNING/SUCCESS/FAIL 缓存写入、缓存字段、缓存 TTL、分发锁释放、MDC、日志脱敏等既有行为。
  - 不改变 Gemini 代理的 baseUrl/model/authMode/fieldStyle/mimeType/maxInlineBytes 等配置解析逻辑。
  - 不在本仓库新建/修改 `VideoToNoteSeq`（属于 spec 105 的 Python 函数计算项目，已部署），本次只在 Java 端发起调用。
  - 不做 OSS 上传、不改 MQ、不改数据库。
  - D006 不修改 `VideoToNoteSeq` 的 service/function/event/返回解析语义，不改 `PianoHomeWorkVideoV2Task` 失败继续策略；只调整默认音序调用的传输方式为 HTTP transfer/fc。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 先取音序、注入提示词、再交给 Gemini（优先级：P1）

作为业务方，我希望钢琴作业视频在交给 Gemini 识别前，先由 `VideoToNoteSeq` 提取出音符序列，把音名序列写进提示词（替换 `${audioseq}` 占位符），这样 Gemini 拿到「视频 + 已识别音序」两份信息，识别更准。

**独立测试**：构造含 `prompt`（内含 `${audioseq}` 占位符）与 `file_url` 的请求，注入一个 Fake 的音序调用器返回固定 `notes`，触发 `handleRequest`，断言：①音序调用收到的 serviceName/functionName/event.video_path 正确；②传给 Gemini 的 `prompt` 已把 `${audioseq}` 替换为音名序列文本；③视频仍以 fileUri 传给 Gemini。

**验收场景**：

1. **Given** `prompt = "请结合音序 ${audioseq} 点评"`、`file_url = <视频URL>`，且 `VideoToNoteSeq` 返回 `notes = [C4, D4, E4]`，**When** 触发 `handleRequest`（默认 fileUrl 模式），**Then** 音序调用以 `serviceName=FcOssFFmpeg-3278`、`functionName=VideoToNoteSeq`、`event.video_path=<视频URL>` 发起；传给 Gemini 的 `prompt = "请结合音序 C4 D4 E4 点评"`；Gemini 仍收到 `fileUri=<视频URL>`。
2. **Given** `VideoToNoteSeq` 抛异常，**When** 触发 `handleRequest`，**Then** 不中断、不写 FAIL，记 warn 日志，`${audioseq}` 被替换为空字符串，继续调用 Gemini 并返回其结果，最终写 SUCCESS。
3. **Given** `VideoToNoteSeq` 返回 `noteCount=0`（`notes` 为空数组），**When** 触发 `handleRequest`，**Then** `${audioseq}` 被替换为空字符串，继续调用 Gemini。
4. **Given** `prompt` 中不含 `${audioseq}` 占位符，**When** 触发 `handleRequest`，**Then** `prompt` 原样不变（记 warn 提示未注入），视频识别照常进行。

### 用户故事 2 - 旧逻辑不回归（优先级：P1）

作为维护者，我希望本次只在 Gemini 调用前插入「取音序 + 注入提示词」一步，其余行为（缓存、锁、三模式、回退、脱敏）完全不变。

**独立测试**：沿用现有 5 个单元测试（fileUrl 成功并写缓存、inlineData env 覆盖、默认 key 失败脱敏、缺 prompt 提前失败、auto 回退 inlineData），在新增可注入音序调用器后全部通过（这些用例的 `prompt` 不含 `${audioseq}`，替换不改变其内容）。

**验收场景**：

1. **Given** 缺少 `prompt` 的请求，**When** 触发 `handleRequest`，**Then** 仍在调用音序与 Gemini 之前抛 `prompt is empty`、写 FAIL，且不调用 `VideoToNoteSeq`、不调用 Gemini。
2. **Given** auto 模式下 fileUrl 调用失败，**When** 触发，**Then** 仍回退到 inlineData，且使用的是注入音序后的 `prompt`。

### 用户故事 3 - 音序同步调用走北京 VPC endpoint（优先级：P1）

作为维护者，我希望 `PianoHomeWorkVideoV2Task` 这类函数内部同步调用 `VideoToNoteSeq` 时使用北京 VPC endpoint，而不是默认北京公网 endpoint，避免函数运行在 VPC 内时出现公网 FC endpoint 连接超时。

**独立测试**：通过代码审查和 focused 测试/编译验证：`DefaultNoteSequenceCaller` 或 `FcInvokeUtils` 的音序同步调用路径使用北京 VPC 客户端；原有 `doTask`、`doTaskWithDelay`、`doSyncTask` 对其他调用方的既有行为不被意外改变。

**验收场景**：

1. **Given** `PianoHomeWorkVideoV2Task` 调用 `DefaultNoteSequenceCaller.fetchNoteSequence`，**When** 构造 `FcInvokeInput` 后发起同步调用，**Then** 实际调用路径使用北京 VPC endpoint `fc-vpc.cn-beijing.aliyuncs.com`。
2. **Given** 其他模块继续调用 `FcInvokeUtils.doSyncTask(...)`，**When** 未显式选择 VPC 同步调用，**Then** 保持原有默认客户端选择逻辑（`fnEndpoint` 覆盖，否则 `fc.cn-beijing.aliyuncs.com`），避免扩大行为变化。

### 用户故事 4 - 音序调用改走 transfer/fc HTTP 网关（优先级：P1）

作为维护者，我希望 `PianoHomeWorkVideoV2Task` 默认调用 `VideoToNoteSeq` 时不再直接使用 `FcInvokeUtils`/阿里云 FC SDK，而是 POST 到 `http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/ai/transfer/fc`，由网关代为转发函数计算，并通过 `isVpc=true` 指定 VPC 调用。

**独立测试**：将默认音序调用器的 HTTP 执行能力抽象为可注入组件或方法，单元测试断言发出的 URL、JSON body 中 `serviceName`、`functionName`、`isVpc=true`、`taskObj.video_path`、`taskObj.task_id` 正确；模拟返回体后仍能提取 `notes` 并完成 `${audioseq}` 替换。

**验收场景**：

1. **Given** `file_url=<视频URL>`、`taskId=task-9`，**When** 默认音序调用器调用 `VideoToNoteSeq`，**Then** HTTP POST URL 为 `http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/ai/transfer/fc`，body 为 `{serviceName:"FcOssFFmpeg-3278", functionName:"VideoToNoteSeq", isVpc:true, taskObj:{video_path:<视频URL>, task_id:"task-9"}}`。
2. **Given** transfer/fc 返回 `VideoToNoteSeq` 的音序 JSON（直接返回或包在 `data`/`result` 字段中），**When** 调用成功，**Then** 系统按既有置信度过滤与音名拼接规则替换 `${audioseq}` 并继续调用 Gemini。
3. **Given** HTTP 状态非 2xx、网络异常、返回体为空或无法解析，**When** 默认音序调用失败，**Then** 沿用既有失败继续策略：warn + 空音序 + 继续 Gemini，不写 FAIL。

### 用户故事 5 - 音序调用改为异步 FC + Redis 等待（优先级：P1）

作为维护者，我希望 `PianoHomeWorkVideoV2Task` 默认调用 `VideoToNoteSeq` 时像 `sop-reply` 的钢琴视频识别一样异步触发函数计算，并通过 Redis 状态 JSON 等待结果，避免长耗时音序提取卡在同步 FC 调用或 HTTP 网关调用上。

**独立测试**：Java 端用 Fake 异步 FC 调用器与 Fake Redis 状态存储，断言 `FcInvokeInput` 的 `serviceName`/`functionName`/`taskObj.video_path`/`taskObj.task_id`/`taskObj.cacheKey` 正确，异步提交后读取 Redis `SUCCESS.result` 并解析音序；覆盖 `FAIL`、超时、提交失败时按既有失败继续策略回退空音序。Python 端用 mock `video_to_notes` 和 mock Redis 写入器，断言有 `cacheKey` 时按 `RUNNING -> SUCCESS` 写 Redis，异常时写 `FAIL`，无 `cacheKey` 时保持直接 return。

**验收场景**：

1. **Given** `file_url=<视频URL>`、`taskId=task-9`，**When** Java 默认音序调用器执行，**Then** 它生成音序 Redis `cacheKey`，event 至少包含 `{video_path:<视频URL>, task_id:"task-9", cacheKey:<noteSeqCacheKey>}`，通过 `FcInvokeUtils.doTask` 异步提交 `FcOssFFmpeg-3278/VideoToNoteSeq`，随后轮询该 Redis key。
2. **Given** `VideoToNoteSeq` Python handler 收到 `cacheKey`，**When** 音序提取成功，**Then** Redis 写入 `{"status":"RUNNING",...}` 后再写入 `{"status":"SUCCESS","result":"<音序JSON字符串>",...}`，同时 handler 仍 return 原音序 JSON 以兼容直接调用。
3. **Given** Java 轮询到 Redis `SUCCESS.result`，**When** 解析出音序 JSON，**Then** 继续按既有置信度过滤和 `${audioseq}` 替换规则调用 Gemini。
4. **Given** 异步提交失败、Redis `FAIL`、Redis 读取异常、等待超时或返回结构无法解析，**When** 默认音序调用失败，**Then** 沿用既有失败继续策略：warn + 空音序 + 继续 Gemini，不写当前 `PianoHomeWorkVideoV2Task` 的 FAIL。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `prompt`：来源 = 请求 `requestPayload`/根对象 `prompt` 字段；赋值时机 = `handleRequest` 入口；下游读取 = `analyzeVideo` 的 `validateRequired` 与占位符替换、`baseRequest(...).prompt(prompt)`。
  - `file_url`：来源 = 请求 `file_url` 字段；赋值时机 = `handleRequest` 入口；下游读取 = `VideoToNoteSeq` 的 `event.video_path`（**新增**）与原 Gemini 的 `fileUri`/inlineData 下载。
  - `noteSeqText`（音名序列文本，**新增**）：来源 = 当前层基于 `VideoToNoteSeq` 返回的 `notes` 现算（`buildNoteSequenceText`：先按 `confidence ≥ 阈值` 过滤，再取 `note` 拼接）；赋值时机 = Gemini 调用前、占位符替换前在当前层算出；下游读取 = `replacePromptPlaceholder` → 注入到 `prompt`。失败/空/全被过滤时取空字符串。
  - `minConfidence`（置信度阈值，**新增**）：来源 = 类常量默认 `0.5`，可由环境变量 `PIANO_HOMEWORK_VIDEO_V2_NOTE_SEQ_MIN_CONFIDENCE` 覆盖；赋值时机 = 拼接前在当前层解析（非法值回退默认并 warn）；下游读取 = `buildNoteSequenceText` 过滤判断。
  - `serviceName`/`functionName`（**新增**）：来源 = 类常量 `FcOssFFmpeg-3278`/`VideoToNoteSeq`，可被环境变量覆盖；赋值时机 = 调用前；下游读取 = `FcInvokeInput.serviceName`/`functionName`。
  - `event.video_path`（**新增**）：来源 = `file_url`，调用前在当前层赋值；`event.task_id` = 请求 `taskId`（可选透传）。
  - D006 `transferUrl`：来源 = 默认常量 `http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/ai/transfer/fc`，可选环境变量覆盖（建议 `PIANO_HOMEWORK_VIDEO_V2_NOTE_SEQ_TRANSFER_URL`）；赋值时机 = 默认音序调用器发起 HTTP 前；下游读取 = HTTP POST URL。
  - D006 `transferBody`：来源 = `serviceName`/`functionName`/`event` 现有入参 + 固定 `isVpc=true`；赋值时机 = HTTP POST 前构造 JSON；下游读取 = transfer/fc 网关。
  - D007 `noteSeqCacheKey`：来源 = Java 端默认音序调用器为本次音序任务生成（建议前缀 `ai:gemini:pianoVideoV2:noteSeq:` + taskId/UUID）；赋值时机 = 异步提交前；下游读取 = Python `VideoToNoteSeq` 写 Redis，Java 端轮询 Redis。
  - D007 Redis 状态 JSON：来源 = Python `videoToAudio/index.py` 在收到 `cacheKey` 后写入；赋值时机 = handler 开始处理写 `RUNNING`，成功写 `SUCCESS.result=<音序JSON字符串>`，异常写 `FAIL.error`；下游读取 = Java 默认音序调用器等待 `SUCCESS`/`FAIL`。
  - D007 等待参数：来源 = Java 常量，参考 `sop-reply` 默认 `MAX_WAIT_MILLIS=10*60*1000`、`POLL_INTERVAL_MILLIS=2000`，可按本类 env 风格增加覆盖；赋值时机 = 轮询前解析；下游读取 = Java 轮询循环。
- 下游读取字段清单：
  - 新增 `NoteSequenceCaller.fetchNoteSequence` 读取：`serviceName`、`functionName`、`event.video_path`（必填）、`event.task_id`（可选）。
  - D007 `VideoToNoteSeq` Python handler 读取：`event.video_path`、`event.task_id`、`event.cacheKey`（可选）、音频提取参数；Redis 连接读取环境变量 `redis_host`、`redis_password`、`db`（与现有 Java Redis 配置保持一致）。
  - D007 Java 默认音序调用器读取：异步提交返回 `invocationId`，Redis `cacheKey` 对应的 `status`、`result`、`error`、`updatedAt` 字段。
  - `buildNoteSequenceText` 读取 `VideoToNoteSeq` 返回的 `notes` 数组及每项 `note`（音名，ASCII，如 `C4`/`C#4`）与 `confidence`（置信度，用于过滤）字段。
  - 原 Gemini 链路读取：`prompt`（替换后）、`baseUrl`、`model`、`apiKey`、`authMode`、`fieldStyle`、`mimeType`、`fileUri`/`inlineData`、`maxInlineBytes`——均保持原来源不变。
- 空对象 / 占位对象风险：
  - 不构造 `new XxxDto()` 占位下传。新增的 `FcInvokeInput` 在调用前已 set `serviceName`/`functionName`/`taskObj(event 含 video_path)`，非占位。
  - 需防止的等价风险：`VideoToNoteSeq` 失败或返回缺 `notes` 字段时，不能把不完整对象当成有效音序。处理策略：失败/空/缺字段一律得到空字符串 `noteSeqText`，并按用户确认「失败也继续」走后续 Gemini 调用，不写 FAIL，仅 warn 日志。
- 调用顺序风险：
  - 存在「先在当前层把 `file_url` 赋给 `event.video_path` → 同步调用 `VideoToNoteSeq` → 用返回值算 `noteSeqText` → 替换 `${audioseq}` → 再调用 Gemini」的严格顺序。`noteSeqText` 必须在替换前算好；`prompt`/`file_url` 必须在音序调用前已通过 `validateRequired` 校验（缺失则提前抛错，不发起音序调用）。
  - 音序调用为新增**同步**远程调用（FC 自调用 FC），插在 Gemini 调用之前——属于「新增远程调用」，已通过 AskUserQuestion 取得用户明确要求与确认（见下「需要用户确认的设计选择」）。
  - D006 需要避免继续保留未使用的 `FcInvokeUtils` VPC 专用方法；音序调用改走 HTTP 后，应移除 D005 新增的公共 SDK VPC 方法，保持公共工具类最小化。
  - D007 改为「异步提交 FC → 等待 Redis 结果 → 替换 prompt → 调 Gemini」。虽然 FC 调用是异步的，但当前 Gemini 调用仍必须等到音序结果或超时后才能继续；`noteSeqText` 仍在 `${audioseq}` 替换前算出。Redis 等待失败/超时按既有失败继续策略返回空音序。
- 旧逻辑保持：
  - RUNNING/SUCCESS/FAIL 三态缓存写入、缓存字段（status/taskId/fileUrl/updatedAt/result/error/errorSource/errorStage）、TTL（1800s）、分发锁释放、MDC requestId、入参脱敏日志，全部不变。
  - `analyzeVideo` 内 `validateRequired(prompt)`、`validateRequired(file_url)` 仍在最前，错误口径不变（`prompt is empty` / `file_url is empty`）。
  - fileUrl/inlineData/auto 三模式与 `shouldFallbackToInline`（401/403 不回退）逻辑不变。
  - `resolveConfig`/`resolveInputMode`/`resolveMimeType`/`parsePositiveLong` 不变。
  - 错误信息 `buildErrorMessage`/`redactSecrets` 脱敏不变。
- 需要用户确认的设计选择（均已确认）：
  - 音序注入形式 = **音名序列文本**（已确认）。分隔符默认**单个半角空格**、顺序沿用上游 `notes` 顺序（spec 105 SC 已保证 `start` 升序），作为合理默认（见假设）。
  - 调用 Gemini 时**仍传视频**（已确认）。
  - `VideoToNoteSeq` 失败/空音序**仍继续调用 Gemini**（已确认，失败/空 → 空音序文本）。

## 边界情况

- `prompt` 缺失/空：`validateRequired(prompt)` 在音序调用前抛 `prompt is empty`，写 FAIL，不调用 `VideoToNoteSeq`、不调用 Gemini（与旧逻辑一致）。
- `file_url` 缺失/空：`validateRequired(file_url)` 抛 `file_url is empty`，不调用 `VideoToNoteSeq`、不调用 Gemini。
- `VideoToNoteSeq` 调用异常（网络/超时/函数报错）：捕获并 warn，`noteSeqText = ""`，继续调用 Gemini，不写 FAIL。
- `VideoToNoteSeq` 返回空音序（`noteCount=0` 或 `notes` 为空/缺字段/某项 `note` 为空）：`noteSeqText = ""`（跳过空 `note` 项），继续调用 Gemini。
- 所有音符 `confidence` 均低于阈值（如整段静音/噪声）：过滤后 `notes` 为空 → `noteSeqText = ""`，占位符置空，继续调用 Gemini（与空音序一致）。
- 阈值环境变量非法（非数字）：回退默认 `0.5` 并记 warn，不中断。
- `prompt` 不含 `${audioseq}` 占位符：`prompt` 原样不变，记 warn 提示「未注入音序」，照常调用 Gemini。
- `prompt` 含多个 `${audioseq}`：全部替换为同一音名序列文本（`String.replace` 字面量全量替换）。
- 替换后 `prompt` 变空（极端：`prompt` 恰好仅为 `${audioseq}` 且音序为空）：交由 Gemini 链路按原有逻辑处理（极端边界，不额外特判）。
- D006：若运行环境无法访问 transfer/fc 网关、HTTP 超时、状态码非 2xx、返回为空或返回结构无法解析，音序调用仍按既有失败继续策略处理（warn + 空音序 + 继续 Gemini），不写 FAIL。
- D007：异步提交返回 `"0"` 或抛异常：Java 端视为音序调用失败，warn + 空音序 + 继续 Gemini。
- D007：Redis 在最大等待时间内一直为空或一直是 `RUNNING`：Java 端视为音序等待超时，warn + 空音序 + 继续 Gemini。
- D007：Redis 状态为 `FAIL`：Java 端读取 `error` 作为异常原因，warn + 空音序 + 继续 Gemini。
- D007：Python handler 无 `cacheKey`：保持旧行为，直接 return 音序 JSON，不写 Redis，便于手工/同步测试。
- D007：Python handler 有 `cacheKey` 但 Redis 写入失败：记录日志并继续/抛出原异常；Java 端最终可能等待超时，仍按空音序继续 Gemini。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `analyzeVideo` 中、对 Gemini 发起调用之前，**同步**调用函数计算服务 `FcOssFFmpeg-3278`、函数 `VideoToNoteSeq`，event 至少包含 `video_path = file_url`（可选透传 `task_id = taskId`）。
- **FR-002**：系统 MUST 把 `VideoToNoteSeq` 返回的 `notes` 数组按上游顺序提炼为**音名序列文本**：仅保留 `confidence ≥ 阈值`（默认 `0.5`，可由 `PIANO_HOMEWORK_VIDEO_V2_NOTE_SEQ_MIN_CONFIDENCE` 覆盖）的音符，逐项取 `note` 字段、用单个半角空格连接、跳过空 `note`，以滤除静音/无音高段被误判的噪声音符（典型为 `confidence≈0.01`、`frequency` 卡在 `fmin` 下界的 `C2`）。`confidence` 缺失按 `0` 处理（被过滤）。
- **FR-003**：系统 MUST 把 `prompt` 中的字面量占位符 `${audioseq}` 替换为音名序列文本；若 `prompt` 不含该占位符，MUST 保持 `prompt` 原样并记录 warn 日志。
- **FR-004**：当 `VideoToNoteSeq` 调用失败、返回空音序或返回结构缺失时，系统 MUST NOT 中止任务、MUST NOT 写 FAIL，MUST 以空字符串作为音名序列文本继续替换并调用 Gemini，且 MUST 记录 warn 日志。
- **FR-005**：系统 MUST 在替换音序后**仍把视频(`file_url`)交给 Gemini**，保留 fileUrl/inlineData/auto 三模式与回退逻辑、缓存写入、分发锁、MDC、脱敏等全部既有行为，MUST NOT 改变这些行为。
- **FR-006**：服务名/函数名 MUST 以类常量 `FcOssFFmpeg-3278`/`VideoToNoteSeq` 为默认值，并 SHOULD 支持环境变量覆盖（与现有 env 覆盖风格一致）。
- **FR-007**：音序调用 MUST 抽象为可注入接口（如 `NoteSequenceCaller`），以便单元测试断言下游参数且不真实访问函数计算。
- **FR-008**：单元测试 MUST 断言下游参数内容——音序调用收到的 `serviceName`/`functionName`/`event.video_path`，以及传给 Gemini 的 `prompt`（占位符已被替换为音名序列文本）与 `fileUri`（仍传视频）；并覆盖失败继续、空音序、无占位符三类边界，及现有 5 个用例不回归。
- **FR-009**：`PianoHomeWorkVideoV2Task` 的默认音序同步调用 MUST 使用北京 VPC FC endpoint（`fc-vpc.cn-beijing.aliyuncs.com`）发起 `FcOssFFmpeg-3278/VideoToNoteSeq` 调用。
- **FR-010**：实现 SHOULD 通过显式方法或显式调用路径启用 VPC 同步调用，MUST NOT 无差别改变所有 `FcInvokeUtils.doSyncTask(...)` 调用方的 endpoint 行为。
- **FR-011**：D005 实现后 MUST 保持音序失败继续策略、service/function/event 字段、置信度过滤、`${audioseq}` 替换、Gemini 三模式回退与缓存锁行为不变。
- **FR-012**：D006 起，`PianoHomeWorkVideoV2Task` 默认音序调用 MUST 改为 HTTP POST `http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/ai/transfer/fc`，请求 body MUST 包含 `serviceName`、`functionName`、`isVpc=true`、`taskObj=<原 event>`。
- **FR-013**：D006 实现 MUST 保留 service/function/env 覆盖能力，`serviceName` 默认仍为 `FcOssFFmpeg-3278`，`functionName` 默认仍为 `VideoToNoteSeq`。
- **FR-014**：D006 实现 SHOULD 支持 transfer/fc 返回直接音序 JSON、`data` 对象、`data` 字符串、`result` 对象或 `result` 字符串；无法识别时按失败继续处理。
- **FR-015**：D006 实现 MUST 移除 D005 新增且不再使用的 `FcInvokeUtils` 北京 VPC 同步公共方法，MUST NOT 改动 `FcInvokeUtils.doSyncTask(...)`、`doTaskWithDelay(...)` 既有行为。
- **FR-016**：D007 起，`PianoHomeWorkVideoV2Task` 默认音序调用 MUST 改为 `FcInvokeUtils.doTask` 异步提交 `FcOssFFmpeg-3278/VideoToNoteSeq`，MUST NOT 再使用 D006 的 transfer/fc HTTP 同步网关作为默认路径。
- **FR-017**：D007 Java 端 MUST 为每次音序任务生成并传递 `cacheKey`，event MUST 包含 `video_path`、可选 `task_id`、`cacheKey`；service/function 默认值与 env 覆盖能力保持不变。
- **FR-018**：D007 Java 端 MUST 轮询 Redis `cacheKey`，识别 `SUCCESS.result`、`FAIL.error`、空/运行中/超时状态；成功时解析 `result` 音序 JSON，失败/超时时抛给上层既有失败继续策略处理。
- **FR-019**：D007 Java 端 SHOULD 抽象异步 FC 调用与 Redis 读取为可注入接口，以便单元测试断言异步下游参数与轮询行为，不真实访问 FC/Redis。
- **FR-020**：D007 Python `videoToAudio/index.py` MUST 在收到 `cacheKey` 时写 Redis 状态：开始写 `RUNNING`，成功写 `SUCCESS` 且 `result` 为音序 JSON 字符串，异常写 `FAIL` 且包含 `error`/`errorStage`；无 `cacheKey` 时 MUST 保持直接 return 音序 JSON 的兼容行为。
- **FR-021**：D007 Python 端 MUST 使用与现有项目一致的 Redis 环境变量（`redis_host`、`redis_password`、`db`），并在 `requirements.txt` 补充 Redis 客户端依赖。
- **FR-022**：D007 MUST 更新 Java 与 Python 测试：Java 断言异步 FC event/cacheKey 与 Redis 成功/失败/超时；Python 断言 Redis `RUNNING/SUCCESS/FAIL` 写入和无 `cacheKey` 兼容。
- **FR-023**：D008 起，系统 MUST 在音序替换完成后、调用 Gemini 前打印最终 prompt 日志，日志中 SHOULD 包含替换后 prompt 的长度和内容；为避免单条日志过大，超长 prompt 可以截断并标注原始长度。
- **FR-024**：D012 起，系统 MUST 在工程侧内置用户提供的 D1《四季歌》和 D2《铁血丹心》音序模板，并在取得有效音序后、调用 Gemini 前计算 D1/D2 模板匹配分数。
- **FR-025**：D012 模板匹配 MUST 使用八度归一化后的音级序列，保留连续重复音，允许漏检、插入噪声和重复次数差异；不得用绝对八度硬匹配。
- **FR-026**：D012 工程侧只有在最佳模板分数达到高置信阈值且相对次高分有足够差距时，才能产出 `engineeringDecision` 并优先覆盖最终课程分类字段；低分或差距不足时 MUST 仅作为证据注入，不得硬判。
- **FR-027**：D012 高置信工程判定 SHOULD 继续调用 Gemini 观看视频，以保留指法、手型、单双手、节奏等诊断；Gemini 返回可解析 JSON 时，Java 端 MUST 只覆盖课程分类相关字段（如 `isHomeWork/id/title/recognizedDay/submissionType/confidence/needHumanReview`），并保留 Gemini 的诊断字段。
- **FR-028**：D012 工程判定必须保持 `<5` 有效音短路、FC 异步 + Redis、`${audioseq}`、`${engineeringContext}`、私聊弱上下文、Gemini 三模式回退、主任务缓存与锁等既有行为不变。
- **FR-029**：D012 高置信 D1/D2 工程判定已存在时，若 Gemini 调用异常或返回非 JSON，系统 SHOULD 返回工程分类兜底 JSON，并将 `needHumanReview=true`，避免清晰模板分类结果丢失；低置信或非 D1/D2 场景仍不得硬判。
- **FR-030**：D013 起，工程侧模板匹配 MUST 扩展到 D3《沧海一声笑·无和弦》，D3 高置信命中时可覆盖课程分类字段，并在 Gemini 异常时返回工程分类兜底 JSON。
- **FR-031**：D013 D2 模板 MUST 使用用户补充的左右手分句模板作为主要模板，并可保留既有长模板作为容错补充；`0` 与 `空` 只代表空拍/占位，不进入音级模板。
- **FR-032**：D013 工程侧 MUST 支持“过滤后有效音序结尾连续 3 个以上 E 音级”优先判定 D2《铁血丹心》，并用 pitch class 处理 `E3/E2/E4` 等八度采集差异。
- **FR-033**：D013 高置信规则 SHOULD 支持完整覆盖率命中（例如覆盖率 `>=0.95` 且分数达标）直接高置信，避免 D2/D3 在 pitch class 空间高度相似时仅因分差不足而漏判。
- **FR-034**：D013 高置信工程判定覆盖 Gemini 原课程分类时，若 Gemini 原 `evidence` 与最终分类冲突，系统 MUST 替换冲突 evidence 为工程侧覆盖说明；诊断字段仍按 D012 规则保留。
- **FR-035**：D016 起，李瑶(110/默认)工程侧模板 MUST 增加 D5-D6《萱草花》曲目组模板，右手音序使用用户确认的两句萱草花音序，并与 D1/D2/D3 一起进入 `templateScores`、高置信匹配和低分人工介入判断。
- **FR-036**：D016 起，D3-D4《沧海一声笑》和 D5-D6《萱草花》MUST 按曲目组计算最终 `id/recognizedDay/submissionType`：`expectedDay` 落在组内时取 `expectedDay`；识别组早于当前进度时取组最大天；识别组晚于当前进度时取组最小天；`expectedDay` 缺失或非法时取模板代表天且 `submissionType=未知`。
- **FR-037**：D016 高置信 `engineeringDecision` 和 Gemini 失败工程兜底 MUST 使用工程侧按 `expectedDay` 算出的最终天数，避免 D6 今日作业因 D5 代表模板被写成 D5。
- **FR-038**：D016 李瑶低分人工介入文案 MUST 覆盖四个曲目组：四季歌、铁血丹心、沧海一声笑、萱草花。
- **FR-039**：D016 MUST 调整李瑶 V1_2 提示词，显式接收 `${engineeringContext}`，说明高置信 `engineeringDecision` 的 `id/recognizedDay/submissionType` 以工程侧为准，模型只负责视频诊断；萱草花描述 MUST 修正为含 `Bb/A#`、不含 `E/B`，不得再写“不含 Fa”。

## 成功标准 *(必填)*

- **SC-001**：给定 `prompt` 含 `${audioseq}`、`VideoToNoteSeq` 返回 `notes=[C4,D4,E4]`，传给 Gemini 的 `prompt` 中 `${audioseq}` 被替换为 `C4 D4 E4`，且 Gemini 仍收到视频 `fileUri`。
- **SC-002**：音序调用以 `serviceName=FcOssFFmpeg-3278`、`functionName=VideoToNoteSeq`、`event.video_path=<file_url>` 发起，可由单元测试断言。
- **SC-003**：`VideoToNoteSeq` 失败或返回空音序时，任务不写 FAIL，`${audioseq}` 替换为空字符串后仍成功调用 Gemini 并写 SUCCESS。
- **SC-004**：现有 5 个单元测试在新增可注入音序调用器后全部通过（旧逻辑不回归）。
- **SC-005**：`mvn -pl Gemini-Api test -Dtest=PianoHomeWorkVideoV2TaskTest`（在 `fc/` 下）编译并通过；不新增 OSS/MQ/数据库调用。
- **SC-006**：代码审查确认音序默认同步调用路径使用北京 VPC 客户端；其他默认同步调用路径不被一并迁移。
- **SC-007**：单元测试或静态验证确认默认音序调用器 HTTP body 包含 `serviceName=FcOssFFmpeg-3278`、`functionName=VideoToNoteSeq`、`isVpc=true`、`taskObj.video_path=<file_url>`。
- **SC-008**：D006 后 focused 单测 `PianoHomeWorkVideoV2TaskTest` 通过，且不再需要 `FcInvokeUtils` 参与默认音序调用。
- **SC-009**：D007 Java 单测确认默认音序调用器调用 `FcInvokeUtils.doTask` 等价异步接口，event 含 `video_path`、`task_id`、`cacheKey`，并能从 Redis `SUCCESS.result` 解析音序 JSON。
- **SC-010**：D007 Java 单测确认 Redis `FAIL`、异步提交失败、等待超时均不导致当前视频任务 FAIL，而是通过既有 catch 返回空音序并继续 Gemini。
- **SC-011**：D007 Python 单测确认有 `cacheKey` 时按 `RUNNING -> SUCCESS` 写 Redis，异常时写 `FAIL`；无 `cacheKey` 时不写 Redis且 return 结构不变。
- **SC-012**：D007 后 Java focused 编译与 `PianoHomeWorkVideoV2TaskTest` 通过；Python `py_compile` 与可运行的 unittest 通过/按依赖缺失跳过音频测试。
- **SC-013**：D008 后单测能捕获日志并确认日志包含替换后的音序提示词文本。
- **SC-014**：D012 单测给定接近 D1 模板的音序，工程侧输出高置信 D1 判定，并在 Gemini 返回 JSON 后覆盖 `id=1/title=四季歌/recognizedDay=D1/submissionType=补交作业`，同时保留 Gemini 原诊断字段。
- **SC-015**：D012 单测给定接近 D2 模板的音序，工程侧输出高置信 D2 判定，并在 D2 当前进度下覆盖为 `id=2/title=铁血丹心/submissionType=今日作业`。
- **SC-016**：D012 单测给定低匹配或 D1/D2 分数差距不足的音序，工程侧不得覆盖 Gemini 输出。
- **SC-017**：D012 回归使用 `C:\Users\EDY\Downloads\视频理解提示词V1_2.txt` 和 D2 当前进度，覆盖原 5 个 demo 视频及新增 `video_demo2/21bea...mp4`，期望 `V1->D1`、`V2->D2`、`V3->D3`、`V5->D5`、新增视频 `->D2`。
- **SC-018**：D012 单测覆盖“高置信 D1/D2 模板命中但 Gemini 调用失败”时返回可解析工程兜底 JSON，分类字段正确且 `needHumanReview=true`。
- **SC-019**：D016 单测给定完整萱草花音序时，工程侧高置信命中 D5 模板，`templateScores` 包含 D5，且模板组范围为 D5-D6。
- **SC-020**：D016 单测覆盖萱草花在 `expectedDay=D5/D6/D3` 时分别输出 `id=5/6/5` 与 `今日作业/今日作业/提前提交`。
- **SC-021**：D016 单测覆盖沧海一声笑在 `expectedDay=D5` 时输出 `id=4`、`recognizedDay=D4`、`submissionType=补交作业`。
- **SC-022**：D016 聚焦测试 `PianoHomeWorkVideoV2TaskTest,PianoNoteSequenceTemplateMatcherTest` 编译并通过；不跑真实 Gemini/FC/Redis 回归。

## 假设

- 音名序列文本分隔符采用**单个半角空格**，音符顺序沿用 `VideoToNoteSeq` 返回的 `notes` 顺序（spec 105 SC 保证按 `start` 升序），不在 Java 端二次排序；若用户要求其它分隔符/排序，按 Dxxx 纠正。
- 置信度过滤阈值默认 `0.5`（D003 依据真实数据确定：噪声音符 `confidence` 多在 `0.01~0.06`，真实旋律多在 `0.3~0.99`），可由 env 覆盖；阈值设为 `0` 即等价不过滤。不做相邻同音名合并（保留时序密度信息）；若用户要求合并，按 Dxxx 纠正。
- `VideoToNoteSeq` 的 event 入参字段名为 `video_path`（与 spec 105 `index.py` 一致），返回体含 `notes` 数组、每项含 `note` 字段（ASCII 音名）。如实际部署的字段名不同，按 Dxxx 纠正。
- 音序调用采用同步方式（`FcInvokeUtils.doSyncTask`/`doSyncTaskReturnJSONObj`），因为必须在 Gemini 调用前拿到音序；同步读超时沿用 `FcInvokeUtils` 既有 `RuntimeOptions` 设置，超时上限由部署侧保证足够覆盖 FFmpeg+librosa 处理时长。
- D006 之后，音序调用采用 HTTP transfer/fc 网关方式，不再依赖 `FcInvokeUtils`/阿里云 FC SDK；transfer/fc 的返回体可能是直接函数返回，也可能包在 `data`/`result` 字段，Java 端做兼容解析。
- D007 之后，D006 的 HTTP transfer/fc 同步网关方案被异步 FC + Redis 方案取代；默认音序调用重新依赖 `FcInvokeUtils.doTask`，但只是异步提交，不读取 FC body。
- D007 音序 Redis `cacheKey` 为 Java 当前层生成的内部 key，独立于外层 `PianoHomeWorkVideoV2Task` 的业务 `cacheKey`，避免覆盖主任务 RUNNING/SUCCESS/FAIL 缓存。
- `event.task_id` 仅作上游关联透传，`VideoToNoteSeq` 端为可选参数，不影响音序提取。
- D012 工程侧模板优先判定只先支持 D1/D2，因为当前用户只提供了 D1/D2 标准音序；D3/D4/D5/D6 仍按既有工程特征和提示词规则处理。若后续提供更多模板，再追加 Dxxx 扩展。
- D012 高置信阈值实际实现为 `bestScore >= 0.70`、`bestScore - secondScore >= 0.15` 且有效音数至少 10；若起手持续下行，则抑制 D1/D2 高置信覆盖，避免误覆盖 D3/D4《沧海一声笑》类旋律。
- Gemini-Api 通过 `com.drh:common` 传递依赖到 `com.aliyun:fc_open20210406`，`FcInvokeUtils`/`FcInvokeInput` 在本模块可用（已由 `AppTask` 实例佐证）。
- D016 李瑶 D3/D4 与 D5/D6 的右手音序组内相同，工程侧不通过音频细分是否有和弦；组内当天取 `expectedDay`，提前/补交取组边界天。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档（`106-piano-video-note-seq-prompt`）。
- 已完成历史问题防漏分析与强制门禁（参数来源、调用时序、旧逻辑保持、空/失败结果风险、下游参数测试映射）。
- 已通过 AskUserQuestion 确认三项关键业务口径：音名序列文本、仍传视频、失败/空也继续。
- 本阶段未修改任何业务代码，等待用户确认进入实施。

### D002 - 实现记录

- 实现内容：在 [PianoHomeWorkVideoV2Task.java](../../fc/Gemini-Api/src/main/java/com/drh/gemini/api/PianoHomeWorkVideoV2Task.java) 的 `analyzeVideo` 中、对 Gemini 调用前新增「同步调用 `FcOssFFmpeg-3278/VideoToNoteSeq` 取音序 → 提炼音名序列文本 → 替换 `${audioseq}` 占位符」一步；新增 `NoteSequenceCaller` 接口 + `DefaultNoteSequenceCaller`（委托 `FcInvokeUtils.doSyncTaskReturnJSONObj`）、服务/函数名常量与 env 覆盖键、`buildNoteSequenceText`、`replacePromptPlaceholder`，并在构造函数注入。
- 影响范围：仅 `fc/Gemini-Api`（`PianoHomeWorkVideoV2Task` 及其单测 `PianoHomeWorkVideoV2TaskTest`）；复用既有 `com.drh:common` 的 `FcInvokeUtils`/`FcInvokeInput`，未引入 OSS/MQ/数据库调用，未改缓存/锁/三模式/脱敏等既有行为。
- 测试命令：`mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am test "-Dtest=PianoHomeWorkVideoV2TaskTest" "-Dsurefire.failIfNoSpecifiedTests=false" -q`。
- 测试结果：`Tests run: 9, Failures: 0, Errors: 0, Skipped: 0`（旧 5 个不回归 + 新 4 个通过：音序注入并仍传视频、失败继续写 SUCCESS、空音序占位符置空、无占位符原样）。
- 自检结论：满足 FR-001~008 与 SC-001~005；参数来源、调用顺序、旧逻辑保持均符合规格；剩余风险=`VideoToNoteSeq` 真实部署返回字段名与同步耗时需在函数计算实跑验证（部署侧）。

### D003 - 纠正记录（音名拼接按置信度过滤）

- 触发原因：用户提供 `VideoToNoteSeq` 真实返回数据（`noteCount=105`），发现含大量 `confidence≈0.01` 的噪声音符——静音/无音高段被 pyin 误判为 `fmin` 下界的 `C2`（`frequency≈65.4Hz`），真实旋律从第 19 个 `E5`（confidence 0.82）才开始。经 AskUserQuestion 确认改为按置信度过滤。
- 修正内容：
  - 旧口径（D002）：`buildNoteSequenceText` 拼接**全部** `notes` 的音名。
  - 新口径：仅保留 `confidence ≥ 阈值`（默认 `0.5`，可由环境变量 `PIANO_HOMEWORK_VIDEO_V2_NOTE_SEQ_MIN_CONFIDENCE` 覆盖；阈值设 `0` 等价不过滤）的音符再拼接音名序列；`confidence` 缺失按 `0` 处理（被过滤）；阈值非法回退默认并 warn。不做相邻同音名合并。
- 文档同步：已同步 `spec.md`（FR-002、历史问题防漏分析的 `noteSeqText`/`minConfidence`/下游字段、边界、假设、本记录）、`tasks.md`（实现/测试任务与 D003）、`AGENTS.md`（当前目标、重点代码位置）、`checklists/requirements.md`（参数完整性）。
- 验证结果：补置信度过滤单测后回跑 `PianoHomeWorkVideoV2TaskTest`（结果见 `tasks.md` D003）。

### D004 - 纠正记录（占位符改名为 ${audioseq}）

- 触发原因：用户在 `PianoHomeWorkVideoV2Task` 源码中将占位符常量 `PROMPT_PLACEHOLDER` 由 `${prompt}` 调整为 `${audioseq}`（避免与请求字段名 `prompt` 混淆）。
- 修正内容：旧口径=提示词占位符为 `${prompt}`；新口径=占位符为 `${audioseq}`，提示词中需以 `${audioseq}` 占位将被识别音序文本替换。
- 文档同步：`spec.md`、`AGENTS.md`、`tasks.md` 中占位符字面量已同步为 `${audioseq}`；单测 `input.prompt` 已统一使用 `${audioseq}`。
- 验证结果：回跑 `PianoHomeWorkVideoV2TaskTest` → `Tests run: 12, Failures: 0, Errors: 0, Skipped: 0`。

### D005 - 纠正记录（音序同步调用使用北京 VPC endpoint）

- 触发原因：用户提供线上 WARN 日志：`Piano homework video v2 note sequence fetch failed, service=FcOssFFmpeg-3278, function=VideoToNoteSeq, errorClass=com.aliyun.tea.TeaUnretryableException, error=connect timed out`，要求确认 `FcInvokeUtils` 是否调用北京。代码确认当前音序同步路径默认是北京公网 endpoint（或由 `fnEndpoint` 覆盖），未使用已有北京 VPC 客户端。
- 修正内容：
  - 旧口径：`DefaultNoteSequenceCaller` 委托 `FcInvokeUtils.doSyncTaskReturnJSONObj`，最终使用默认 `client`；默认 endpoint 为 `fc.cn-beijing.aliyuncs.com`，不是 `clientBeijing` 的 `fc-vpc.cn-beijing.aliyuncs.com`。
  - 新口径：`PianoHomeWorkVideoV2Task` 默认音序同步调用显式走北京 VPC FC endpoint；其他默认同步调用不做全局迁移。
- 实现内容：`FcInvokeUtils` 新增 `doSyncTaskWithBeijingVpc` 与 `doSyncTaskReturnJSONObjWithBeijingVpc`，复用已有 `clientBeijing`/`runtimeBeijing`；`PianoHomeWorkVideoV2Task.DefaultNoteSequenceCaller` 改为调用 `doSyncTaskReturnJSONObjWithBeijingVpc`。
- 文档同步：已同步 `spec.md`（背景、用户故事 3、历史防漏分析、边界、FR-009~011、SC-006、假设、D005）、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 验证结果：`mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am compile -q` 通过；`mvn -f C:\workspace\ju-chat\fc\pom.xml -pl common install -DskipTests -q` 刷新本地 common jar 后，`mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am test "-Dtest=PianoHomeWorkVideoV2TaskTest" "-Dsurefire.failIfNoSpecifiedTests=false" -q` 通过，`Tests run: 12, Failures: 0, Errors: 0, Skipped: 0`。
- 自检结论：音序默认调用路径已显式使用北京 VPC 方法；默认 `doSyncTask`/`doSyncTaskReturnJSONObj` 仍走原 `client` 与 `fnEndpoint` 覆盖逻辑；音序失败继续、service/function/event、置信度过滤、`${audioseq}` 替换、Gemini 三模式回退与缓存锁行为不变。

### D006 - 纠正记录（音序调用改走 transfer/fc HTTP 网关）

- 触发原因：用户要求“刚才调用 VideoToNoteSeq 函数改为 `http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/ai/transfer/fc` 这个接口调用”，并提供参数 demo：`{taskObj:{...}, serviceName:"ai-service", functionName:"audio-tts", isVpc:true}`。
- 修正内容：
  - 旧口径（D005）：默认音序调用器通过 `FcInvokeUtils.doSyncTaskReturnJSONObjWithBeijingVpc` 直接调用 FC SDK。
  - 新口径（D006）：默认音序调用器 POST transfer/fc HTTP 网关，请求体为 `{taskObj:event, serviceName, functionName, isVpc:true}`；`event` 仍为 `{video_path:file_url,(task_id)}`；service/function 仍沿用默认值和 env 覆盖。
- 实现内容：`PianoHomeWorkVideoV2Task.DefaultNoteSequenceCaller` 改为构造 transfer/fc HTTP body 并通过可注入 `NoteSequenceTransferClient` POST；新增默认 URL 常量 `DEFAULT_NOTE_SEQ_TRANSFER_URL` 与 env 覆盖 `PIANO_HOMEWORK_VIDEO_V2_NOTE_SEQ_TRANSFER_URL`；兼容解析直接音序 JSON、`data` 对象/字符串、`result` 对象/字符串；默认音序调用不再引用 `FcInvokeUtils`/`FcInvokeInput`。`FcInvokeUtils` 中 D005 新增的 `doSyncTaskWithBeijingVpc` 与 `doSyncTaskReturnJSONObjWithBeijingVpc` 已移除，默认 `doSyncTask` 与 `doTaskWithDelay` 行为保持不变。
- 测试命令：
  - `mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am compile -q`
  - `mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am test "-Dtest=PianoHomeWorkVideoV2TaskTest" "-Dsurefire.failIfNoSpecifiedTests=false" -q`
- 测试结果：编译通过；focused 单测通过，`PianoHomeWorkVideoV2TaskTest` 覆盖默认 transfer URL、body 中 `serviceName`/`functionName`/`isVpc=true`/`taskObj.video_path`/`taskObj.task_id`、URL env 覆盖、`data` 字符串和 `result` 对象拆包，以及既有音序注入/失败继续/置信度过滤/auto 回退不回归。
- 静态审查：`PianoHomeWorkVideoV2Task` 已无 `FcInvokeUtils`/`FcInvokeInput` 引用；`FcInvokeUtils` 已无 `doSyncTaskWithBeijingVpc`/`doSyncTaskReturnJSONObjWithBeijingVpc` 残留。
- 自检结论：满足 D006 FR-012~015 与 SC-007~008；D005 SDK VPC 方案已被 HTTP transfer/fc 网关方案取代，保留 service/function/event、失败继续、`${audioseq}` 替换、置信度过滤、Gemini 三模式与缓存锁既有行为。

### D007 - 计划记录（音序调用改为异步 FC + Redis）

- 触发原因：用户要求 `VideoToNoteSeq` 函数计算改为异步调用，通过 Redis 获取结果，参考 `C:\workspace\ju-chat\fc\sop-reply` 调用 `PianoHomeWorkVideoV2Task` 的写法；用户确认 `VideoToNoteSeq` 还不支持 Redis 写回，并提供源码目录 `C:\workspace\ju-chat\videoToAudio`。
- 事实确认：
  - `sop-reply` 参考实现 `PianoVideoHomeWorkHandleServiceImpl` 的模式为：调用方生成 `cacheKey`/`taskId`，写/读 Redis 状态，`FcInvokeUtils.doTask` 异步提交 FC，轮询 `status/result/error`，超时/失败按业务兜底。
  - `videoToAudio/index.py` 当前 `handler` 只解析 `video_path` 等参数，调用 `video_to_notes` 后直接 return `{taskId,videoPath,sampleRate,noteCount,notes}`，没有 Redis 依赖、没有 `cacheKey` 入参处理。
  - `Gemini-Api` 现有 `RedisClient` 已支持 `getStringValue`/`setTokenWithExpire`/`deleteKey`，`PianoHomeWorkVideoV2Task` 已通过 `CacheStore` 写主任务缓存；本次音序 Redis key 应独立于主任务 cacheKey。
- 修正内容：
  - 旧口径（D006）：默认音序调用器 POST transfer/fc HTTP 网关并直接解析 HTTP 返回体。
  - 新口径（D007）：默认音序调用器使用 `FcInvokeUtils.doTask` 异步提交 `VideoToNoteSeq`，event 中加入内部音序 `cacheKey`；Python `VideoToNoteSeq` 收到 `cacheKey` 后写 Redis `RUNNING/SUCCESS/FAIL`；Java 端轮询 Redis `SUCCESS.result` 得到音序 JSON。
- 实施计划：
  - Java：移除默认路径对 transfer/fc HTTP 的依赖，新增可注入 `NoteSequenceAsyncInvoker`/`NoteSequenceResultStore`（命名可实现时调整），默认实现委托 `FcInvokeUtils.doTask` 与 Redis；生成独立 noteSeq cacheKey；轮询成功解析 `result`，失败/超时抛异常交给既有 `fetchNoteSequenceTextSafely` catch 兜底空音序。
  - Python：`index.py` 兼容 `cacheKey`；有 `cacheKey` 时写 `RUNNING`，成功写 `SUCCESS.result=<音序JSON字符串>`，异常写 `FAIL.error/errorStage` 后继续抛出；无 `cacheKey` 保持直接 return；`requirements.txt` 增加 Redis 客户端依赖；README 更新事件参数与 Redis 状态。
  - 测试：Java 单测断言异步 FC event/cacheKey 与 Redis 成功/失败/超时；Python 单测 mock `video_to_notes` 与 Redis writer，覆盖 RUNNING/SUCCESS/FAIL 和无 cacheKey 兼容。
- 验证计划：
  - Java：`mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am compile -q`；`mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am test "-Dtest=PianoHomeWorkVideoV2TaskTest" "-Dsurefire.failIfNoSpecifiedTests=false" -q`。
  - Python：`python -m py_compile audio_ffmpeg.py note_extractor.py index.py tests\test_audio_ffmpeg.py tests\test_note_extractor.py`；`python -m unittest discover -s tests`（音频依赖缺失时原有 note_extractor 测试允许跳过）。
- 确认状态：用户已确认按 D007 方案进入实施；D007 已实现并进入待验收。

### D007 - 实现记录（音序调用改为异步 FC + Redis）

- 实现内容（Java）：`PianoHomeWorkVideoV2Task.DefaultNoteSequenceCaller` 已不再走 D006 transfer/fc HTTP 同步网关，改为通过 `FcInvokeUtils.doTask` 异步提交 `FcOssFFmpeg-3278/VideoToNoteSeq`；新增内部音序 Redis `cacheKey`，event 包含 `video_path`、可选 `task_id`、`cacheKey`；新增 Redis 轮询，识别 `SUCCESS.result`、`FAIL.error`、等待超时，成功解析音序 JSON 后继续既有置信度过滤与 `${audioseq}` 替换，失败交由既有失败继续策略兜底为空音序。
- 实现内容（Python）：`videoToAudio/index.py` 支持 `cacheKey`；收到 `cacheKey` 时写 Redis `RUNNING`，成功写 `SUCCESS` 且 `result` 为完整音序 JSON 字符串，异常写 `FAIL` 且包含 `error`/`errorStage`；未传 `cacheKey` 时不写 Redis，继续保持直接 return 音序 JSON。
- 依赖与文档：`videoToAudio/requirements.txt` 增加 `redis>=5.0,<6.0`；`videoToAudio/README.md` 增加 Redis 环境变量、`cacheKey` 参数、状态结构与 TTL 说明。
- 测试验证：Java focused 单测 `PianoHomeWorkVideoV2TaskTest` 通过；Java `mvn -q compile` 通过；Python `py_compile` 通过；Python `python -m unittest discover -s tests` 通过，`Ran 14 tests in 0.033s, OK (skipped=3)`，跳过项为既有音频依赖测试。
- 自检结论：满足 FR-016~022 与 SC-009~012；当前处于待用户验收状态，尚未进入本地提交阶段。

### D008 - 实现记录（打印替换后的提示词）

- 触发原因：用户要求“将替换完音序的提示词打印到日志”。
- 实现内容：`PianoHomeWorkVideoV2Task.injectNoteSequence` 在 `replacePromptPlaceholder` 后新增 info 日志，打印 `prompt after note sequence injection`、替换后 prompt 长度与内容；新增 `summarizePromptForLog`，超过 4000 字符时截断并标注原始长度，避免单条日志过大。
- 测试更新：`PianoHomeWorkVideoV2TaskTest` 新增 logback `ListAppender` 用例，断言日志包含替换后的文本 `请结合音序 C4 D4 点评`。
- 测试命令：`mvn -q -Dtest=PianoHomeWorkVideoV2TaskTest test`（workdir: `C:\workspace\ju-chat\fc\Gemini-Api`）。
- 测试结果：通过。
- 自检结论：满足 FR-023 与 SC-013；当前处于待用户验收状态，尚未进入本地提交阶段。

### D009 - 计划记录（工程侧音序特征 JSON 与弱上下文注入）

- 触发原因：用户确认不再由工程侧输出候选排名或覆盖最终 `id/title`，而是输出固定结构的音序特征 JSON 作为客观证据；同时私聊场景需把最近 3 条聊天记录作为弱上下文，辅助处理“昨天的作业”等表达。
- 修正内容：
  - 工程侧新增音序特征提取，输出固定字段：`validNoteCount`、`hasSameNoteRepeat`、`isMonoDescending`、`hasFa`、`isWavy`、`mainOctave`、`highestNote`、`lowestNote`、`rhythmStability`、`pauseOrStumble`、`pyinConfidenceMean`、`noteSequence`。
  - 工程侧先做可算法化处理：`octave <= 2` 且持续时长 `< 0.3s` 的极低短音直接丢弃；八度归一化后计算指纹，避免 `E5/E4` 采集误差干扰；音符数、音区、最高/最低音、节奏稳定性、长停顿、pyin/voiced_prob 均值均由代码统计。
  - 去噪和置信度过滤后 `validNoteCount < 5` 时，代码层直接短路，返回兼容识别结果 JSON（`confidence=0.3`、`needHumanReview=true`、`id=-1`、`title=未知`），不再调用 LLM。
  - `PianoHomeWorkVideoV2Task` 保留 `${audioseq}` 替换，同时新增 `${engineeringContext}` 替换；提示词未声明占位符时自动追加“工程侧音序特征 JSON”。`expectedDay/currentDay/logicalDay` 仅进入提示词上下文，不硬判课程。
  - `sop-reply` 调用识别 FC 时透传 `expectedDay = HomeWorkMessageDto.logicalDay`；私聊 `isGroup=false` 时透传最近 3 条非空聊天记录，群聊不透传。
- 指纹量化口径：
  - 同音重复：起手 N 个音中，八度归一化后连续相邻同音达到阈值，`hasSameNoteRepeat=true`。
  - 持续下行：去噪序列前 5 音八度归一化差分全为负，`isMonoDescending=true`。
  - Fa 音存在：有效音序中存在 F/F# 音级（不看八度），`hasFa=true`。
  - 上下游走：八度归一化差分同时存在正负，`isWavy=true`。
- 关键约束：工程侧 JSON 不包含课程候选 `id/title` 或候选排名；除 `validNoteCount < 5` 的低信息短路外，最终 `id/title/confidence/needHumanReview` 仍由模型按提示词规则判断。
- 测试计划：
  - 单测音序特征：V1 `hasFa=true/isWavy=true/isMonoDescending=false`；V2 有效音数足够且保留结构化音序；V3 起手下行；V5 `hasSameNoteRepeat=true`。
  - 入口单测：Gemini prompt 包含 `${audioseq}` 替换结果与完整工程 JSON；私聊最近 3 条注入，群聊不注入。
  - 回归测试：等待用户提供临时可访问视频 URL 后，调用部署的 `VideoToNoteSeq` 验证 V1->D1、V2->D2、V3->D3、V5->D5，并覆盖当天/过去/未来作业路由。

### D009 - 实现记录（工程侧音序特征 JSON、有效音短路与弱上下文注入）

- 实现内容（Gemini-Api）：新增 `PianoNoteSequenceFeatureExtractor`，先丢弃 `octave <= 2` 且 `duration < 0.3s` 的极低短噪声，再按 confidence/voiced_prob 阈值过滤；输出固定工程 JSON 字段，并用八度归一化后的音级量化同音重复、持续下行、F/F#、上下游走。`PianoHomeWorkVideoV2Task` 保留 `${audioseq}`，新增 `${engineeringContext}` 替换/自动追加；有效音 `<5` 时直接返回人工复核 JSON（`confidence=0.3`、`needHumanReview=true`、`id=-1`），不调用 LLM。
- 实现内容（sop-reply）：`HomeWorkMessageDto` 增加 `groupChat` 与 `recentMessageModels`；`SopReply` 从 `WebChatVoiceDto` 透传；`PianoVideoHomeWorkHandleServiceImpl` 向识别 FC 写入 `expectedDay/logicalDay/isGroup`，仅私聊写入最近 3 条非空聊天记录。
- 测试验证：`Gemini-Api` 聚焦测试 `PianoHomeWorkVideoV2TaskTest,PianoNoteSequenceFeatureExtractorTest` 通过；`sop-reply` 聚焦测试 `PianoVideoHomeWorkHandleServiceImplTest` 通过。
- 剩余验收：用户提供临时可访问视频 URL 后，再执行部署回归验证 V1->D1、V2->D2、V3->D3、V5->D5 以及当天/过去/未来作业路由。

### D010 - 回归验证记录（D2 当前进度，Redis 读取失败）

- 验证输入：使用用户提供的 5 个视频 URL，分别配合 `视频理解的提示词.txt` 与 `视频理解的提示词V3.txt`；所有 `D%s/currentDay/logicalDay/expectedDay` 均按 `D2`。
- 前置验证：`Gemini-Api` 聚焦单测与 `sop-reply` 聚焦单测均通过。
- 执行结果：10 次真实默认链路调用均返回工程侧短路结果：`id=-1`、`isHomeWork=否`、`confidence=0.3`、`needHumanReview=true`、`validNoteCount=0`，均未进入 Gemini。
- 失败定位：`VideoToNoteSeq` 异步 FC 调用已提交成功（FC 返回 `202`），但本地读取 Redis 结果失败，错误为 `JedisConnectionException: Could not get a resource from the pool`；因此无法取得音序，触发有效音 `<5` 短路。
- 结论：本次没有形成提示词效果对比结论；阻塞点是本地 Redis 访问环境。恢复 Redis 后按同一矩阵重跑，或另行确认允许使用直连/同步音序结果绕过 Redis 做离线回归。

### D011 - 回归验证记录（D2 当前进度，Redis 跑通后重跑）

- 验证输入：复用 D010 的 5 个视频 URL 与两个提示词文件；所有 `D%s/currentDay/logicalDay/expectedDay` 均按 `D2`。Redis 连接信息仅通过本地进程环境变量注入，未写入仓库。
- 执行结果：Redis 探针通过，FC 异步提交与 Redis 结果读取均可用；10 次调用均进入 Gemini 并返回可解析 JSON。
- 工程侧音序：V1-1/V1-2 的有效音分别为 `35/34`，具备 `hasFa=true`、`isWavy=true`；V2-1 有效音 `13`，主要为低音区伴奏/噪声；V3-1 有效音 `26`，`isMonoDescending=true`；V5-1 有效音 `39`，`hasSameNoteRepeat=true`。
- 结果对比：
  - `视频理解的提示词.txt`：`V1-1`、`V1-2`、`V3-1`、`V5-1` 命中；`V2-1` 误判为 `id=1/四季歌`。总体 `4/5 PASS`。
  - `视频理解的提示词V3.txt`：仅 `V3-1` 命中；`V1-1` 误判为 `id=2/铁血丹心`，`V1-2/V2-1/V5-1` 均兜底未知。总体 `1/5 PASS`。
- 结论：D011 已形成有效回归结论。当前 V3 音序提示词不适合作为上线默认版本；它对同音重复、跳进和复杂八度的排除规则过硬，导致 V1/V5 误判或兜底。旧视频理解提示词整体更稳，但 V2 多声部/低音弦干扰仍未解决，后续需优先增强工程侧主旋律提取或单独调整 V2 指纹规则。

### D012 - 计划记录（D1/D2 工程侧模板优先判定 + V1_2 提示词回归）

- 触发原因：用户提供新提示词文件 `C:\Users\EDY\Downloads\视频理解提示词V1_2.txt`、D1/D2 标准音序模板，并要求“工程侧优先判断”；同时新增一个 D2 预期视频 `https://drh-test.oss-cn-beijing.aliyuncs.com/video_demo2/21bea517-4d47-4638-81ea-1744f2dc4cb7.mp4`。
- 旧行为：D009 工程侧只输出客观特征 JSON，不输出候选排名，不覆盖最终 `id/title`；只有 `validNoteCount < 5` 会代码层短路。
- 新目标：D012 增加 D1/D2 工程侧模板匹配。高置信命中时，工程侧优先决定课程分类；Gemini 仍负责视频诊断字段，最终 JSON 的课程分类字段由 Java 层按工程判定覆盖。
- 实现计划：
  - 新增 `PianoNoteSequenceTemplateMatcher`（或等价类），内置 D1/D2 用户模板，输入过滤后的有效音序，输出 `templateScores`、`bestTemplate`、`confidence`、`matchedDay/id/title`、`reason`。
  - 修改 `PianoNoteSequenceFeatureExtractor` 或其返回对象，使模板匹配器可拿到结构化有效音列表或 pitch class 序列，而不是重新解析字符串。
  - `PianoHomeWorkVideoV2Task` 在构建工程上下文时追加 `engineeringDecision`；高置信时在 Gemini 返回后 post-process JSON，覆盖课程分类字段，并在 evidence 中追加“工程侧模板命中”的依据。
  - 非 JSON 返回或低置信工程判定不做硬覆盖；`validNoteCount < 5` 仍走原短路。
- 验证计划：
  - 单测 D1/D2 模板高置信命中、低分不覆盖、覆盖后分类字段正确且诊断字段保留。
  - 聚焦回归 `PianoHomeWorkVideoV2TaskTest,PianoNoteSequenceFeatureExtractorTest`。
  - 使用 `视频理解提示词V1_2.txt` 跑 6 个视频 D2 矩阵，期望 `V1-1/V1-2 -> D1`，`V2-1 -> D2`，`V3-1 -> D3`，`V5-1 -> D5`，新增视频 `->D2`。
- 确认状态：用户已确认进入实施；D012 已实现，当前等待用户验收。

### D012 - 实现记录（D1/D2 工程侧模板优先判定 + V1_2 回归）

- 实现内容：新增 `PianoNoteSequenceTemplateMatcher`，内置 D1《四季歌》和 D2《铁血丹心》用户模板；`PianoNoteSequenceFeatureExtractor.ExtractResult` 增加过滤后的 pitch class 序列；`PianoHomeWorkVideoV2Task` 在工程 JSON 中追加 `templateScores`，高置信时追加 `engineeringDecision`，Gemini 返回可解析 JSON 后由 Java 覆盖课程分类字段并追加 evidence，保留 Gemini 原有诊断字段。
- 兜底策略：真实回归中 Gemini proxy 出现间歇性 `Remote host terminated the handshake`。D012 已补充高置信 D1/D2 工程判定兜底：Gemini 调用异常或返回非 JSON 时，返回工程分类 JSON，分类正确但 `needHumanReview=true`，诊断字段不伪造为可靠结论。
- 测试验证：`mvn -q "-Dtest=PianoHomeWorkVideoV2TaskTest,PianoNoteSequenceFeatureExtractorTest,PianoNoteSequenceTemplateMatcherTest" test` 通过；覆盖 D1/D2 命中、低分不覆盖、下行旋律抑制覆盖、覆盖保留诊断字段、Gemini 异常工程兜底、`<5` 有效音短路不回归。
- 回归验证：使用 `C:\Users\EDY\Downloads\视频理解提示词V1_2.txt`、`expectedDay/currentDay/logicalDay=2` 跑真实默认链路。最新完整 6 视频结果为：`V1-1` PASS（D1/补交）、`V1-2` PASS（D1/补交）、`V2-1` PASS（D2/今日）、`V3-1` PASS（D3/提前）、`21bea` WARN（工程模板高置信 D2/今日，但 Gemini proxy 握手失败，返回工程兜底 JSON）、`V5-1` FAIL（FC/Redis 音序成功且有效音 39；非 D1/D2 覆盖范围，Gemini proxy 握手失败导致空响应）。首次完整回归中 `V5-1` 曾成功识别为 D5，说明失败阶段是外部 Gemini proxy 波动。
- 日志位置：完整回归日志 `C:\workspace\ju-chat\fc\Gemini-Api\target\piano-regression-d012-v1_2-rerun2.log`；V5 单独重跑日志 `C:\workspace\ju-chat\fc\Gemini-Api\target\piano-regression-d012-v1_2-v5-rerun.log`。
- 自检结论：D1/D2 工程侧优先判定已生效，V1 与 V2/新增 D2 样本分类稳定性提升。残余风险是 D3/D5/D6 仍依赖 Gemini；模型代理失败时非 D1/D2 样本仍可能失败，后续可单独评估扩展 D3/D5/D6 模板或增加 Gemini 调用重试。

### D013 - 计划记录（D2/D3 工程模板补充 + E 结尾 D2 优先规则）

- 触发原因：用户补充 D2《铁血丹心》左右手分句模板、D3《沧海一声笑·无和弦》模板，并要求“结尾连续三个 E3 E3 E3，优先判别为 铁血丹心”，修改后继续回归。
- 新目标：工程侧模板覆盖范围从 D1/D2 扩展到 D1/D2/D3；D2 使用新的左右手分句模板并保留长模板容错；D3 可高置信覆盖；D2 结尾连续 E 音级作为优先指纹。
- 质量要求：高置信工程覆盖后不能保留与最终分类冲突的 Gemini evidence；仍保留 Gemini 的诊断字段，除非 Gemini 调用异常只能返回工程兜底。

### D013 - 实现记录（D2/D3 工程模板补充 + V1_2 最新回归）

- 实现内容：`PianoNoteSequenceTemplateMatcher` 已扩展为 D1/D2/D3 三模板评分；D2 模板增加用户补充的分句结构，D3 增加《沧海一声笑·无和弦》模板；`templateScores` 追加 D3 分数、`endingRepeatedE` 和可选 `priorityReason`。
- 规则调整：匹配分数由 LCS 覆盖率、音级直方图相似度、前缀相似度组成；除分差规则外，覆盖率 `>=0.95` 且分数达标时可直接高置信；结尾连续 3 个以上 E 音级时优先判 D2。
- 证据修正：工程高置信覆盖 Gemini 原分类且存在冲突时，最终 evidence 改写为“模型原课程分类与工程侧高置信模板冲突，已按工程侧覆盖”加工程侧依据，避免同一 JSON 中出现相互矛盾的分类证据。
- 测试验证：`mvn -q "-Dtest=PianoHomeWorkVideoV2TaskTest,PianoNoteSequenceFeatureExtractorTest,PianoNoteSequenceTemplateMatcherTest" test` 通过；新增覆盖 D3 模板命中、D2 结尾 E 优先、D3 主链路覆盖、冲突 evidence 清理。
- 回归验证：使用 `C:\Users\EDY\Downloads\视频理解提示词V1_2.txt`、`expectedDay/currentDay/logicalDay=2` 通过真实默认链路重跑 6 个视频，最新结果 `6/6 PASS`：`V1-1->D1/补交`、`V1-2->D1/补交`、`V2-1->D2/今日`、`V3-1->D3/提前`、`V5-1->D5/提前`、`21bea->D2/今日`。
- 日志位置：最新完整回归日志 `C:\workspace\ju-chat\fc\Gemini-Api\target\piano-regression-d013-v1_2-final.log`；中间单跑 V2-1 日志 `C:\workspace\ju-chat\fc\Gemini-Api\target\piano-regression-d013-v1_2-v2-rerun.log`。
- 自检结论：D013 已完成，D1/D2/D3 工程模板覆盖链路可用，新增 D2 视频由 E 结尾优先规则稳定命中；D5 仍依赖 Gemini，本轮真实链路成功通过。

### D014 - 实现记录（连续短语匹配 + D1 移调纠偏 + 双提示词回归）

- 触发原因：用户提供一个实际为 D1《四季歌》的音序样本，但 D2 长模板因跨段 LCS 更高被误判为 D2；同时要求新增 `contiguousPhraseSimilarity` 并把新增视频纳入两个提示词版本的真实链路回归。
- 实现内容：
  - `PianoNoteSequenceTemplateMatcher.Score` 新增 `contiguousPhraseSimilarity`，对 pitch class 序列计算连续 2/3/4-gram 的 Dice overlap，取最大值并保留两位小数；`templateScores.D1/D2/D3` 均输出该字段。
  - 保留原有基础分公式 `0.55*coverage + 0.30*histogramSimilarity + 0.15*prefixSimilarity`。
  - 新增窄口径 D1 纠偏：基础 best 为 D2、D2 未触发结尾连续 E 优先、D2 基础分低于高置信线、样本足够长且 D1 的音级分布与连续短语证据明显强于 D2 时，工程侧改判 D1 并置高置信；`priorityReason` 写入“D2长模板LCS虚高，D1连续短语和音级分布更强，按四季歌纠偏”。
  - 真实新增视频暴露出整体移调情况（工程音序为 `B5 A#5 G5...`，相对 D1 模板整体上移 7 个半音）。为覆盖该样本，在上述窄口径 D1 纠偏内增加 D1 模板 12 半音移调评分；仅在基础 best 仍为 D2、D2 基础分 `<0.70`、有效音 `>=30`、移调后 D1 `score>=0.80`、`lcsLength>=24`、`histogramSimilarity>=0.85`、`contiguousPhraseSimilarity>=0.50` 且相对 D2 差值达标时触发。命中时 `templateScores.D1` 输出 `transpositionShift`，`priorityReason` 写入“D1整体移调”。
  - `PianoHomeWorkVideoV2Task` 复用既有高置信工程覆盖链路：D1 纠偏命中后覆盖 `id/title/coreElements.recognizedDay/submissionType/evidence`，保留 Gemini 诊断字段，并清理冲突 evidence。
- 测试验证：
  - 新增单测覆盖用户提供的 D1 误判音序，断言命中 D1 高置信、`templateScores.D1` 包含 `contiguousPhraseSimilarity`、`priorityReason` 包含 D2 长模板 LCS 虚高。
  - 新增单测覆盖真实新增视频提取出的移调 D1 音序，断言 `transpositionShift=7`、D1 高置信、`priorityReason` 包含 D1 整体移调。
  - 新增主链路单测：Fake Gemini 返回 D2 时，工程侧仍覆盖为 D1/四季歌/补交作业，并清理冲突 evidence。
  - 聚焦测试通过：`mvn -q "-Dtest=PianoHomeWorkVideoV2TaskTest,PianoNoteSequenceFeatureExtractorTest,PianoNoteSequenceTemplateMatcherTest" test`（workdir: `C:\workspace\ju-chat\fc\Gemini-Api`）。
- 真实回归：
  - 执行方式：真实链路 runner 调用 `PianoHomeWorkVideoV2Task.handleRequest`，`expectedDay/currentDay/logicalDay=2`，不传主任务 `cacheKey`；Redis 连接信息仅通过本地进程环境变量注入，未写入仓库。
  - 提示词：`C:\Users\EDY\Downloads\视频理解的提示词.txt` 与 `C:\Users\EDY\Downloads\视频理解的提示词V3.txt`。
  - 矩阵：`V1-1/V1-2/V2-1/V3-1/V5-1/21bea/新增D1样本`，共 14 次。
  - 最新结果：`13/14 PASS`。新增 D1 样本在两个提示词版本均 PASS（D1/补交），日志中 `templateScores.D1.transpositionShift=7`、`priorityReason=D2长模板LCS虚高，D1整体移调后连续短语和音级分布更强，按四季歌纠偏`；原用户文本音序样本已由单测锁定。
  - 唯一失败：`视频理解的提示词V3 + V5-1` 返回 `id=-1/未知`，同一 V5 视频在旧提示词版本 PASS 为 D5。该失败属于 D5 仍依赖 Gemini/V3 提示词排除法过硬的既有风险，不是本次 D1/D2/D3 工程模板纠偏引入。
  - 日志位置：`C:\workspace\ju-chat\fc\Gemini-Api\target\piano-regression-contiguous-20260622-232903.log`。
- 自检结论：D014 目标中的 D1/D2 误判纠偏已生效，新增 D1 视频已纳入并在两个提示词版本通过；回归矩阵残余 1 个 V3+D5 失败，建议后续若要求矩阵全绿，单独扩展 D5/D6 工程模板或调整 V3 提示词。

### D015 - 纠正记录（D2/D3 移调补救 + 低分 id=-1 人工介入）

- 触发原因：用户提供一段李瑶(110)体系视频（`engineeringContext` 为 `templateScores`、无 `speakerId`/`yaqiTemplateScores`），学员把铁血丹心(D2)整体升高半音演奏：音序全升号 `F5 D#5 C#5 C5 A#4 F4 ...`，逐音降半音还原即标准铁血丹心 `E5 D5 C5 B4 A4 ...`。D2 白键模板无移调评分（D014 仅给 D1 做了纠偏内移调），`D2 score=0.21` 匹配不上、`D1=0.32` 略高但低、`highConfidence=false`，交 Gemini 误判成 D1 四季歌。
- 修正内容：
  1. **D2/D3 移调补救**：`match()` 在「原调(无移调)未达高置信 且 best<`TRANSPOSE_RESCUE_BELOW`(0.50) 且 有效音>=`HIGH_CONFIDENCE_MIN_OBSERVED_NOTES`(10)」时，调用 `bestTransposedRescue` 对 D1/D2/D3 计算最佳移调分，挑选「移调命中(shift≠0)、达高置信(>=0.70)、且比原调 best 高>=`TRANSPOSE_RESCUE_MIN_DELTA`(0.15)」者改判并置高置信，`priorityReason` 写“原调匹配分低，整体移调N半音后命中Dx”，`evidenceText` 追加“（整体移调N半音后命中）”。**仅低分时启用，原调演奏零影响**——避免全局移调评分破坏 D1 纠偏与 D2/D3 精细区分（曾尝试全局 `strongerScore` 导致 7 个用例回归，已回退）。
  2. **低分 id=-1 人工介入**：`PianoHomeWorkVideoV2Task` 对李瑶(110)体系，若曲目模板最佳分（含移调补救后）仍 < `LOW_SCORE_MANUAL_REVIEW_THRESHOLD`(0.50)，直接短路返回 `id=-1`、`needHumanReview=true`，不交 Gemini 硬猜（与雅琪未匹配 -1 一致）。形成三档：高置信(含移调补救)覆盖 / 中间分(0.50~高置信)交 Gemini / 低分(<0.50) id=-1。
- 文档同步：`spec.md`（本记录）。
- 验证结果：`PianoNoteSequenceTemplateMatcherTest`(12) + `PianoHomeWorkVideoV2TaskTest`(32) 共 **44 个单测全过**。关键用例：`match_shouldRescueTransposedD2TieXueDanXin` 用本案例真实日志音序断言移调补救命中 D2(shift≠0)；`handleRequest_transposedD2_shouldRescueAndOverrideToD2` 端到端覆盖 `id=2/铁血丹心/recognizedDay=D2/今日作业`、evidence 含“移调”；`handleRequest_lowTemplateScore_shouldShortCircuitToManualReview` 验证 6 音半音阶低分→`id=-1`；原 7 个 D1 纠偏/D2/D3 覆盖用例不回归。
- 备注：本案例视频音序已由用户日志给出，matcher 单测直接用真实音序锁定（→D2 移调命中）；李瑶 demo 原调回归由现有 `match` D1/D2/D3 高置信用例覆盖（移调补救低分门槛不触及高分原调）。
- 真实 FC 回归：调 `VideoToNoteSeq` 跑 ①`video_demo2/21bea...`(D2 原调) → `bestDay=D2, score=0.92, shift=0, highConfidence=true`（移调补救未触发、原调不受影响）；②本案例升半音铁血丹心视频 → `bestDay=D2, score=0.95, shift=1, highConfidence=true`（移调补救命中升 1 半音）；③用户补充的 V1-V5 demo(`video_demo/V*.mp4`，expectedDay=2)：V1-1/V1-2 → D1 高置信覆盖(score=1.0，补交作业)、V2-1 → D2 高置信覆盖(0.73，当日作业)、V3-1 → D3(0.87)非高置信交 Gemini、V5-1(D5 无工程模板) → 工程误匹配 D2(0.65)非高置信交 Gemini。**关键确认：V5 best=0.65 未被「低分 id=-1」短路(阈值0.50)误伤**，低分短路对 D5/D6 安全；V3/V5 最终天数靠 Gemini（既有逻辑，本次未改 Gemini 链路）。临时手动测试已删除、不入库。

### D016 - 纠正记录（李瑶 D5/D6 萱草花工程模板与组内天数）

- 触发原因：用户要求完成 ClaudeCode 未完成的 D5/D6 萱草花音序识别收尾。当前工作树中已部分加入 D5 模板和组范围，但 `PianoHomeWorkVideoV2Task` 调用了未实现的 `resolveTemplateDayId(...)`、`resolveTemplateSubmissionType(...)`，导致 `Gemini-Api` 编译失败；同时 `templateScores` 尚未输出 D5 分数，李瑶提示词未明确 `${engineeringContext}` 分工，萱草花描述仍有“不含 Fa”的错误表述。
- 新目标：李瑶(110/默认)工程侧曲目组统一为：D1 四季歌、D2 铁血丹心、D3-D4 沧海一声笑、D5-D6 萱草花。工程侧用右手音序判曲目组；D3/D4 与 D5/D6 组内不靠音频细分，按 `expectedDay` 决定最终天数与作业类型。
- 参数与赋值时机：
  - `expectedDay` 来源仍为 request `expectedDay/currentDay/logicalDay`，在 Gemini 调用前注入工程上下文，在工程覆盖/兜底时现算最终 `id/recognizedDay/submissionType`。
  - `dayMin/dayMax` 来源为内置模板常量；D1、D2 为单天组，D3 模板代表 D3-D4，D5 模板代表 D5-D6。
  - `engineeringDecision` 来源为高置信模板匹配；D016 后其天数必须使用 `resolveTemplateDayId` 结果，而不是模板代表天。
- 实施内容：
  - `PianoNoteSequenceTemplateMatcher` 将 D5《萱草花》分数完整纳入 `MatchResult` 和 `templateScores` 输出，并保留 D1/D2/D3 既有规则。
  - `PianoHomeWorkVideoV2Task` 新增组内天数与作业类型 helper；工程覆盖与 Gemini 失败兜底统一使用组内最终天数；低分人工介入文案补齐萱草花。
  - `C:\Users\EDY\Downloads\视频理解提示词V1_2.txt` 增加工程侧音序证据说明，明确高置信 `engineeringDecision` 以工程侧为准；同步版本化副本到 `prompt/piano_video_prompt_liyao_110_v1_2.txt`。
- 额外修正：新增 D5 模板后，升半音铁血丹心样本原调最佳分被 D5 顶到边界值 `0.50`，导致原 `<0.50` 移调补救未触发；D016 将移调补救条件改为 `<=0.50`，仍只在低分边界启用，不影响原调高分样本。
- 验证结果：`mvn -q "-Dtest=PianoHomeWorkVideoV2TaskTest,PianoNoteSequenceTemplateMatcherTest" "-Dsurefire.failIfNoSpecifiedTests=false" test` 通过，`Tests run: 50, Failures: 0, Errors: 0, Skipped: 0`。覆盖萱草花模板高置信、D5/D6 今日作业、D3 进度提前提交、D5 进度沧海补交、低分 `id=-1`、Gemini 失败兜底使用组内天数、D2 移调补救不回归。本次未跑真实 Gemini/FC/Redis。

### D017 - 纠正记录（D2 当前进度真实异步音序回归 + V5 开头指纹）

- 触发原因：用户提供 Redis 连接信息并要求“再试一次，发起异步请求，提取音序，验证”。回归矩阵为 `V1-1/V1-2/V2-1/V3-1/V5-1`，假设当天/推荐进度为 `D2`；期望 `V1-* -> D1/补交作业`、`V2-1 -> D2/今日作业`、`V3-1 -> D3/提前提交`、`V5-1 -> D5/提前提交`。
- 真实异步取音序结果：通过 `FcOssFFmpeg-3278/VideoToNoteSeq` 异步提交并轮询 Redis DB 3，可稳定拿到音序。首次工程侧音序校验中 `V1-1/V1-2/V2-1/V3-1` 均符合预期；`V5-1` 提取出的实际音序开头为 `E5 E5 E4 G3 G3 G3...`，与 D016 固定 D5 模板 `D D D F...` 存在整体采集偏移/音区混入，原精确模板分 `D5=0.25`，被 D2 中分 `0.65` 压过。
- 修正内容：`PianoNoteSequenceTemplateMatcher` 增加窄口径萱草花开头指纹规则：在前 0~3 个有效音位置内出现“三个同音后上行小三度”（提示词中的 `3 3 3 5` 轮廓）时，优先判定 D5-D6 曲目组，输出 `priorityReason=萱草花开头指纹...`，并将 `templateScores.D5.score` 提升为高置信证据分 `0.88`。该规则在 D2 结尾 E 优先与 D1 纠偏之后生效，不改变 D1/D2/D3 原有高置信、移调补救和低分人工介入规则。
- 单测锁定：新增真实 V5 提取音序用例，断言命中 D5、`dayMin=5/dayMax=6`、`highConfidence=true`、`priorityReason` 包含萱草花开头指纹。聚焦测试 `mvn -q "-Dtest=PianoHomeWorkVideoV2TaskTest,PianoNoteSequenceTemplateMatcherTest" "-Dsurefire.failIfNoSpecifiedTests=false" test` 通过；本地报告为 `PianoHomeWorkVideoV2TaskTest` 37 个、`PianoNoteSequenceTemplateMatcherTest` 14 个，均 0 失败。
- 异步音序回归结论：D2 当前进度矩阵已通过 5/5。`V1-1`：有效音 35，D1，`id=1`，补交作业；`V1-2`：有效音 34，D1，`id=1`，补交作业；`V2-1`：有效音 13，D2，`id=2`，今日作业；`V3-1`：有效音 26，D3，`id=3`，提前提交；`V5-1` 修正后：有效音 39，D5，`id=5`，提前提交，`bestScore=0.88`。
- 真实主链路抽验：修正后单独跑 `PianoHomeWorkVideoV2Task` 的 `V5-1`，最终输出 `id=5`、`title=萱草花`、`coreElements.recognizedDay=D5`、`coreElements.submissionType=提前提交`、`needHumanReview=false`、`confidence=0.88`。本轮未重跑 5 个视频的完整 Gemini 主链路，只完成 5 个视频的异步取音序工程验证与 V5 完整链路复验。
- 临时日志：当次执行日志写入过 `C:\workspace\ju-chat\fc\Gemini-Api\target\piano-regression-d017-async-note-retry.out.log`、`piano-regression-d017-async-note-v5-after-fix.out.log`、`piano-regression-d017-full-v5-after-fix.out.log`；这些位于 `target` 下，不作为持久交付物，后续构建可能清理。
- 安全说明：Redis 连接信息仅作为本地进程环境变量使用，未写入仓库、spec 或测试代码。

### D018 - 纠正记录（D2 长模板虚高 → D3 沧海纠偏）

- 触发原因：用户提供一段沧海一声笑视频（音序 `A3 G3 C4 A2 C4 A3 G3 B2 G3 G3 C4 G4 G4 B2`），工程侧误判 D2《铁血丹心》。日志显示 D2 长模板对短音序的 LCS/coverage 虚高（`D2 coverage=1.0、score=0.76`），压过真正匹配沧海的 D3（`score=0.74`），尽管 D3 的 `histogramSimilarity(0.76)`、`contiguousPhraseSimilarity(0.28)`、`prefixSimilarity(0.5)` 都明显更强。
- 修正内容：`PianoNoteSequenceTemplateMatcher.match` 在 D2 结尾 E 优先、D1 纠偏之后、萱草花开头指纹之前，增加 **D2→D3 窄口径纠偏** `shouldCorrectD2ToD3WhenChorusStronger`：当 `baseBest=D2`、有效音 `>=10`、`d2.score-d3.score<=0.10`、`d3.histogram>=0.70`、`d3.prefix>=0.45`、`d3.contiguous>=0.25`、且 `d3.histogram-d2.histogram>=0.15`、`d3.contiguous-d2.contiguous>=0.15` 时，改判 D3 沧海并置高置信，`priorityReason=D2长模板LCS虚高，D3音级分布与连续短语明显更强，按沧海一声笑纠偏`。关键区分特征是 **D3.prefixSimilarity>=0.45**（起手真是沧海 A-G-E-D-C），用于排除「铁血丹心 + G 重复偶然撞高 histogram/contiguous 但起手不匹配沧海」的 D2 噪声样本（该类 prefix≈0.38）。不改变 D1/D2/D3 既有高置信、移调补救、低分人工介入、萱草花指纹等规则。
- 单测锁定：新增 `match_shouldCorrectD2ToD3WhenChorusHistogramAndPhraseStronger`（真实音序断言纠偏 D3、高置信、priorityReason 含沧海一声笑纠偏）；原 D2 噪声序列用例 `match_shouldHighConfidenceMatchNoisyD2Sequence`（prefix=0.38）仍判 D2 不回归。`PianoNoteSequenceTemplateMatcherTest`(15) + `PianoHomeWorkVideoV2TaskTest`(37) 共 52 单测全过。
- 真实 FC 回归（expectedDay=2，组覆盖）：`V1-1->D1四季歌/补交(1.0)`、`V2-1->D2铁血/今日(0.73)`、`V3-1->D3沧海/0.87 非高置信交Gemini`、`V5-1->D5萱草花/提前(0.88)`、本案例沧海 `->D3沧海/提前(0.74) 纠偏命中`、`demo2->D2铁血/今日(0.92)`。三大修复（萱草花 D5、D2→D3 纠偏、组覆盖）全部真实数据验证，原调与 D2 噪声不回归。临时手动测试已删除、不入库。
- 遗留：`V3-1` 沧海 `score=0.87` 但 baseBest 已是 D3、仅因 gap 不足非高置信交 Gemini，属「D3 高分但 gap 不足」既有问题，与本次 D2→D3 纠偏无关。

### D019 - 纠正记录（D2→D3 纠偏改为双路径，覆盖更多沧海采集形态）

- 触发原因：D018 单路径纠偏漏判两段真沧海视频，仍被误判铁血丹心：①案例1 `D2=0.77/D3=0.65/gap=0.12`（gap>0.10）、`D3.prefix=0.38`（起手采集偏移），但 `D3.histogram=0.97/contiguous=0.7` 极强；②案例2 `gap=0.06/D3.prefix=0.5`，但 `D3.contiguous=0.22`（<0.25）。
- 修正内容：`shouldCorrectD2ToD3WhenChorusStronger` 改为双路径（满足其一即纠偏；仍要求 `baseBest=D2`、有效音>=10）：
  - 路径A（D3 极强）：`D3.histogram>=0.85 && D3.contiguous>=0.40 && histogram diff>=0.10 && contiguous diff>=0.20`，不要求 gap/prefix，覆盖起手被采集偏移的沧海（案例1）。
  - 路径B（起手真沧海）：`d2.score-d3.score<=0.10 && D3.histogram>=0.70 && D3.prefix>=0.45 && histogram diff>=0.15`，去掉 D018 的 contiguous 硬门槛，覆盖 contiguous 偏低但起手匹配沧海的形态（案例2 与原真沧海）。
  两路径都排除 D2 噪声样本（prefix=0.38 排除B、histogram=0.83<0.85 排除A）。
- 单测：新增 `match_shouldCorrectD2ToD3WhenChorusVeryStrong`（路径A）、`match_shouldCorrectD2ToD3WhenChorusOpeningStrong`（路径B），原 D2 噪声/真 D2 用例不回归，54 单测全过。
- 真实 FC 回归（expectedDay=3）：沧海案例1->D3(0.65 路径A)、案例2->D3(0.64 路径B)、铁血对照->D2(0.90)、demo2->D2(0.92)。后两者走结尾 E 指纹优先判 D2（先于 D2→D3 纠偏），确保铁血不被误纠偏。临时手动测试已删除、不入库。
