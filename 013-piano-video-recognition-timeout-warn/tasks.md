# 任务清单：钢琴视频识别超时与异常告警

**输入**：来自 `specs/013-piano-video-recognition-timeout-warn/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：通过模块编译检查、关键逻辑走查、超时/异常告警入参验证。  

## Phase 1：规格与范围

- [x] T001 创建并维护 Spec Kit 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确目标文件为 `PianoVideoHomeWorkHandleServiceImpl.java`
- [x] T003 明确目标方法为 `handle`，必要时允许提取私有告警辅助方法
- [x] T004 明确新需求替换旧版“10 分钟超时后 7 分钟延迟重试”逻辑
- [x] T005 明确告警参考实现为 `AppTask#notifyBookRegisterWarn`

## Phase 2：实现

- [x] T006 移除或禁用首次 10 分钟超时后的 7 分钟延迟逻辑
- [x] T007 移除或禁用首次 10 分钟超时后的第二次 `triggerAsyncRecognitionIfNeeded` 调用
- [x] T008 保持首次触发 `triggerAsyncRecognitionIfNeeded` 后等待 10 分钟的现有窗口
- [x] T009 保留等待结果状态判断，使 `handle` 可区分成功、失败和超时
- [x] T010 新增钢琴视频识别超时告警辅助方法，参考 `notifyBookRegisterWarn`
- [x] T011 告警 `FcInvokeInput` 设置 `serviceName=service_sys`
- [x] T012 告警 `FcInvokeInput` 设置 `functionName=common_warn_sender`
- [x] T013 告警 `taskObj` 设置 `sendTemplateList=["WX003"]`
- [x] T014 告警不传 `templateVariable`，`campName` 和 `userName` 由 `common_warn_sender` 内部补齐
- [x] T015 告警 `taskObj` 设置可供 `common_warn_sender` 使用的 `external_key`
- [x] T016 告警发送异常捕获并记录日志，不影响主流程返回
- [x] T017 首次等待超时并尝试告警后返回空 `HomeWorkResultDto`
- [x] T018 增加识别等待超时、告警发送、告警失败、超时后不重试的关键日志
- [x] T029 增加 `externalKey` 维度 5 分钟 Redis 去重 key
- [x] T030 命中 5 分钟去重时跳过 `common_warn_sender`
- [x] T031 Redis 去重异常时记录日志并继续发送告警
- [x] T032 `common_warn_sender` 调用失败时不删除去重 key

## Phase 3：验证

- [x] T019 验证首次等待成功时不发送 `WX003` 告警
- [x] T020 验证首次等待明确失败时不发送超时告警、不重试
- [x] T021 验证首次等待超时后发送 `WX003` 告警
- [x] T022 验证首次等待超时后不等待 7 分钟
- [x] T023 验证首次等待超时后不再次调用 `triggerAsyncRecognitionIfNeeded`
- [x] T024 验证告警入参包含 `sendTemplateList=["WX003"]`
- [x] T025 验证告警不传 `templateVariable`，由 `common_warn_sender` 内部补齐 `campName` 和 `userName`
- [x] T026 验证告警调用目标为 `service_sys/common_warn_sender`
- [x] T027 编译 `fc/sop-reply` 模块
- [x] T028 记录验证结果和剩余风险
- [x] T033 验证去重 key 前缀为 `ai:sopReply:pianoVideo:timeoutWarn:`
- [x] T034 验证去重过期时间为 300 秒
- [x] T035 验证命中去重时不调用 `FcInvokeUtils.doTask`
- [x] T036 验证 Redis 去重异常分支继续发送告警

## Phase 4：异常告警增量实现

- [x] T037 将告警辅助方法从仅超时语义调整为可同时处理超时和异常触发原因
- [x] T038 在 `handle` 中捕获钢琴视频识别处理链路异常，记录异常阶段并尝试发送 `WX003` 告警
- [x] T039 覆盖 `triggerAsyncRecognitionIfNeeded` 异步提交异常或非法 `invocationId` 场景，确保会触发异常告警
- [x] T040 覆盖 `waitForRecognitionResult` 等待轮询、缓存读取和线程中断异常，确保会触发异常告警
- [x] T041 覆盖缓存成功结果解析异常，确保会触发异常告警
- [x] T042 异常告警复用 `service_sys/common_warn_sender`、`sendTemplateList=["WX003"]`、`external_key`，且不传 `templateVariable`
- [x] T043 异常告警复用 `externalKey` 维度 5 分钟 Redis 去重，沿用 key 前缀 `ai:sopReply:pianoVideo:timeoutWarn:`
- [x] T044 异常告警发送完成或发送失败被捕获后，`handle` 返回空 `HomeWorkResultDto`，不向主流程抛出识别处理异常
- [x] T045 增加识别处理异常、异常告警发送、异常告警失败、异常告警去重命中的关键日志

## Phase 5：异常告警增量验证

- [x] T046 验证异步提交异常或非法 `invocationId` 后发送 `WX003` 告警
- [x] T047 验证等待轮询、缓存读取或线程中断异常后发送 `WX003` 告警
- [x] T048 验证缓存成功结果解析异常后发送 `WX003` 告警
- [x] T049 验证异常告警入参与超时告警一致，未传 `templateVariable`
- [x] T050 验证同一 `externalKey` 5 分钟内超时和异常共用去重窗口
- [x] T051 编译 `fc/sop-reply` 模块
- [x] T052 记录异常告警实现验证结果和剩余风险

## Phase 6：点评未知告警增量实现

- [x] T053 在规格中补充识别成功但 `title=未知` 时发送 `WX003` 告警
- [x] T054 在 `PianoVideoHomeWorkHandleServiceImpl` 中新增 `WARN_REASON_UNKNOWN_TITLE`
- [x] T055 在初始缓存命中成功结果返回前检查 `title=未知`
- [x] T056 在等待异步识别成功结果返回前检查 `title=未知`
- [x] T057 新增 `notifyPianoVideoUnknownTitleWarn`、`warnIfPianoVideoTitleUnknown`、`isUnknownTitle` 私有辅助方法
- [x] T058 `title=未知` 告警复用 `service_sys/common_warn_sender`、`sendTemplateList=["WX003"]`、`external_key`，且不传 `templateVariable`
- [x] T059 `title=未知` 告警复用 `externalKey` 维度 5 分钟 Redis 去重，沿用 key 前缀 `ai:sopReply:pianoVideo:timeoutWarn:`
- [x] T060 `title=未知` 告警发送完成、发送失败或命中去重后返回原识别结果
- [x] T061 增加 `title=未知` 告警日志，包含 `cacheKey`、`messageId`、`externalKey`、`title`、`question`、`isHomeWork`、`id`

## Phase 7：点评未知告警增量验证

- [x] T062 验证 `{"id":0,"isHomeWork":"否","question":"指法没问题,手型没问题,节奏有问题,弹得还可以","title":"未知"}` 会触发 `WX003` 告警
- [x] T063 验证 `title` 非 `未知` 时不触发未知标题告警
- [x] T064 验证未知标题告警入参与超时告警一致，未传 `templateVariable`
- [x] T065 验证同一 `externalKey` 5 分钟内超时、异常和未知标题共用去重窗口
- [x] T066 编译 `fc/sop-reply` 模块
- [x] T067 记录点评未知告警实现验证结果和剩余风险

## Phase 8：异步任务失败告警补漏实现

- [x] T068 明确 `PianoHomeWorkVideoTask` 写入的 `STATUS_FAIL` 属于异步任务执行失败，不应被当成普通作业未命中吞掉
- [x] T069 `PianoHomeWorkVideoTask` 写入失败缓存时补充 `errorSource=ASYNC_TASK_FAIL`
- [x] T070 `PianoHomeWorkVideoTask` 写入失败缓存时补充 `errorStage=piano_homework_video_task_analyze`
- [x] T071 `PianoVideoHomeWorkHandleServiceImpl` 初始缓存读到非 `BUSINESS_FAIL` 的 `STATUS_FAIL` 时触发异常告警
- [x] T072 `PianoVideoHomeWorkHandleServiceImpl#waitForRecognitionResult` 读到非 `BUSINESS_FAIL` 的 `STATUS_FAIL` 时触发异常告警
- [x] T073 保留显式业务失败分支：只有 `errorSource=BUSINESS_FAIL` 才按普通失败返回空结果且不告警
- [x] T074 异步任务失败告警复用 `service_sys/common_warn_sender`、`sendTemplateList=["WX003"]`、`external_key`，且不传 `templateVariable`
- [x] T075 异步任务失败告警复用 `externalKey` 维度 5 分钟 Redis 去重，沿用 key 前缀 `ai:sopReply:pianoVideo:timeoutWarn:`

## Phase 9：异步任务失败告警补漏验证

- [x] T076 验证 `error=new supplier SDK call failed` 写入 `STATUS_FAIL` 后会触发 `WX003` 告警
- [x] T077 验证 `errorSource=BUSINESS_FAIL` 的 `STATUS_FAIL` 不触发异常告警
- [x] T078 验证异步任务失败告警入参与超时告警一致，未传 `templateVariable`
- [x] T079 编译 `fc/sop-reply` 模块
- [x] T080 编译 `fc/Gemini-Api` 模块
- [x] T081 记录异步任务失败告警补漏验证结果和剩余风险

## Phase 10：钢琴视频新供应商 HTTP 化实现

- [x] T082 确认 `PianoHomeWorkVideoTask` 新供应商路径不再使用 Google GenAI SDK
- [x] T083 新增直接使用业务 `file_url` 作为 `file_data.file_uri` 的逻辑
- [x] T084 移除新供应商 HTTP resumable upload 初始化和 `x-goog-upload-url` 依赖
- [x] T085 移除新供应商上传视频二进制并 finalize 的逻辑
- [x] T086 新增 HTTP `generateContent` 调用逻辑，使用 `file_data.mime_type`、`file_data.file_uri=<原始视频URL>` 和 prompt
- [x] T087 HTTP 生成成功后复用现有 `extractTextFromResponse` 解析逻辑，不写入 `STATUS_FAIL`
- [x] T088 HTTP 生成失败或响应文本为空时保持现有重试；重试耗尽后写入 `STATUS_FAIL` 并由 `sop-reply` 触发 `WX003`
- [x] T089 `PracticeCommentFc` 不纳入本次 HTTP 化改造范围，保持旧接口逻辑

## Phase 11：钢琴视频新供应商 HTTP 化验证

- [x] T090 验证 `PianoHomeWorkVideoTask` 编译通过
- [x] T091 验证 `PianoVideoHomeWorkHandleServiceImpl` 编译通过
- [x] T092 静态验证 `PianoHomeWorkVideoTask` 不包含 `com.google.genai` import
- [x] T093 静态验证 HTTP 生成使用 `x-goog-api-key`、`file_data`、`mime_type`、`file_uri`
- [x] T094 记录钢琴视频新供应商 HTTP 化实现验证结果和剩余风险

## Phase 12：Google GenAI SDK 依赖与运行时依赖验证

- [x] T093 将 `fc/Gemini-Api` 的 `com.google.genai:google-genai` 从 `1.22.0` 升级到 `1.53.0`
- [x] T094 验证 `google-genai:1.53.0` 可从 Maven 仓库解析
- [x] T095 验证 `fc/Gemini-Api` 编译通过
- [x] T096 记录依赖树解析结果，确认实际使用 `com.google.genai:google-genai:jar:1.53.0:compile`
- [x] T097 显式补充 `commons-logging:commons-logging:1.3.5`，修复 Apache HttpClient 运行时缺少 `LogFactory`
- [x] T098 执行 `mvn -q -DskipTests package`，验证 shade 后 `gemini-api.jar` 包含 `org/apache/commons/logging/LogFactory.class`

## Phase 13：新供应商本地验证 test 方法规格

- [x] T099 在规格中明确新供应商 HTTP baseUrl 固定为 `https://ent.univibe.cc`
- [x] T100 在规格中补充普通聊天本地 test 方法，用于验证纯文本 `generateContent`
- [x] T101 在规格中补充视频理解本地 test 方法，用于验证视频 URL 直传 `generateContent` 和响应文本提取
- [x] T102 在 `PianoHomeWorkVideoTask` 中实现普通聊天 test 方法
- [x] T103 在 `PianoHomeWorkVideoTask` 中实现视频 URL 直传 test 方法或调整现有 `testNewSupplierVideoAnalysis` 使其固定使用 `https://ent.univibe.cc`
- [x] T104 验证普通聊天 test 方法调用 `POST https://ent.univibe.cc/v1beta/models/gemini-3-flash-preview:generateContent`
- [x] T105 验证视频理解 test 方法只调用 `POST https://ent.univibe.cc/v1beta/models/gemini-3-flash-preview:generateContent`，并传入 `file_data.file_uri=<视频URL>`
- [x] T106 验证两个 test 方法均从 `new_supplier_api_key` 读取令牌，且不在代码、日志或文档中暴露令牌
- [x] T107 记录普通聊天与视频理解本地 test 方法的执行结果和剩余风险

## 执行记录

### D001 - 文档记录

- 已按用户要求修改 Spec Kit 文档。
- 已将旧版“首次 10 分钟超时后等待 7 分钟并重试一次”改为“首次 10 分钟超时后发送 `WX003` 告警且不重试”。
- 已记录告警变量 `campName` 和 `userName` 由 `common_warn_sender` 内部基于 `external_key` 补齐，调用方无需传入。
- 已记录告警调用参考 `external-info-save` 模块 `AppTask#notifyBookRegisterWarn`，目标函数为 `common_warn_sender`。
- D001 仅为文档修改记录；业务代码已在 D002 中按原超时告警规格实现。

### D002 - 实现记录

- `HomeWorkMessageDto` 新增 `externalKey` 字段，用于向钢琴视频识别处理器传递告警上下文。
- `SopReply#resolveHomeworkMessage` 从 `userMsg.externalKey`、路由参数 `externalKey` 或 `buildExternalKey(userMsg)` 填充 `externalKey`。
- `PianoVideoHomeWorkHandleServiceImpl#handle` 首次等待超时后不再执行 7 分钟延迟。
- `PianoVideoHomeWorkHandleServiceImpl#handle` 首次等待超时后不再第二次调用 `triggerAsyncRecognitionIfNeeded`。
- 新增 `notifyPianoVideoTimeoutWarn`，按 `notifyBookRegisterWarn` 结构调用 `service_sys/common_warn_sender`。
- 告警 `taskObj` 仅传 `external_key` 和 `sendTemplateList=["WX003"]`；`campName`、`userName` 由 `common_warn_sender` 内部补齐。
- 告警发送异常会被捕获并记录，不影响 `handle` 返回空 `HomeWorkResultDto`。

### D003 - 验证记录

- 执行命令：`mvn -q -DskipTests compile`
- 执行目录：`C:\workspace\ju-chat\fc\sop-reply`
- 执行结果：编译通过。
- 静态检查确认 `RETRY_DELAY_MILLIS` 和超时重试触发逻辑已移除。
- 静态检查确认首次等待超时后调用 `notifyPianoVideoTimeoutWarn`，并直接返回空结果。
- 静态检查确认告警入参包含 `external_key` 和 `sendTemplateList=["WX003"]`，未传 `templateVariable`。
- 剩余风险：未接入真实 Redis、FC 异步任务和 `common_warn_sender` 做端到端联调；当前验证覆盖编译和关键逻辑走查。

### D004 - 5 分钟去重实现记录

- `PianoVideoHomeWorkHandleServiceImpl` 新增 `TIMEOUT_WARN_DEDUP_KEY_PREFIX = "ai:sopReply:pianoVideo:timeoutWarn:"`。
- `PianoVideoHomeWorkHandleServiceImpl` 新增 `TIMEOUT_WARN_DEDUP_EXPIRE_SECONDS = 5 * 60`。
- `notifyPianoVideoTimeoutWarn` 调用 `common_warn_sender` 前先执行 `isTimeoutWarnRepeatLimited`。
- 去重逻辑通过 `RedisClient#setIfAbsentWithExpire` 写入 `ai:sopReply:pianoVideo:timeoutWarn:{externalKey}`。
- 同一 `externalKey` 在 5 分钟内再次触发时，记录 `piano_video_recognition_timeout_warn_repeat_limited` 并跳过告警。
- Redis 去重异常时记录 `piano_video_recognition_timeout_warn_dedup_error_continue` 并继续发送告警。
- `common_warn_sender` 发送失败时不删除去重 key，避免 5 分钟内重复尝试。

### D005 - 5 分钟去重验证记录

- 执行命令：`mvn -q -DskipTests compile`
- 执行目录：`C:\workspace\ju-chat\fc\sop-reply`
- 执行结果：编译通过。
- 静态检查确认告警发送前调用 `isTimeoutWarnRepeatLimited`。
- 静态检查确认去重 key 前缀为 `ai:sopReply:pianoVideo:timeoutWarn:`，过期时间为 `5 * 60` 秒。
- 静态检查确认命中去重时直接返回，不调用 `FcInvokeUtils.doTask`。
- 静态检查确认 Redis 去重异常时返回 `false`，继续执行告警发送流程。

### D006 - 异常告警增量规格记录

- 已按用户新增要求将“异常也需要告警”写入 Spec Kit。
- 异常告警范围包括异步提交异常、非法异步提交返回值、等待轮询异常、缓存读写异常、结果解析异常和等待线程中断。
- 异常告警复用超时告警的 `WX003` 模板、`service_sys/common_warn_sender` 调用方式、`external_key` 入参和 5 分钟 `externalKey` 去重规则。
- 明确业务 `FAIL` 不等同于处理链路异常；由本地异常写入或触发的失败状态应按异常告警处理。
- D006 先完成规格与任务清单更新；业务代码已在 D007 中按 Phase 4/Phase 5 补充实现和验证。

### D007 - 异常告警实现与验证记录

- `PianoVideoHomeWorkHandleServiceImpl#handle` 新增处理链路异常兜底捕获，记录异常阶段并调用异常告警。
- `triggerAsyncRecognitionIfNeeded` 改为返回派发结果；异步提交异常或 `invocationId=0` 时写入本地异常来源并触发 `WX003`。
- `waitForRecognitionResult` 增加缓存读取、结果解析和线程等待异常结果，异常会回到 `handle` 统一告警并返回空结果。
- 告警方法调整为同时支持 `TIMEOUT` 和 `EXCEPTION` 触发原因，入参仍仅包含 `external_key` 和 `sendTemplateList=["WX003"]`。
- 超时和异常共用 `ai:sopReply:pianoVideo:timeoutWarn:{externalKey}` 5 分钟 Redis 去重窗口。
- 执行命令：`mvn -q -DskipTests compile`
- 执行目录：`C:\workspace\ju-chat\fc\sop-reply`
- 执行结果：编译通过。
- 剩余风险：未接入真实 Redis、FC 异步任务和 `common_warn_sender` 做端到端联调；当前验证覆盖编译和关键逻辑静态检查。

### D008 - 点评未知告警实现与验证记录

- 已按用户新增要求将“识别成功但 `title=未知` 也需要告警”写入 Spec Kit。
- `PianoVideoHomeWorkHandleServiceImpl` 新增 `WARN_REASON_UNKNOWN_TITLE`。
- 初始缓存命中成功结果和等待异步识别成功结果返回前，都会执行 `warnIfPianoVideoTitleUnknown`。
- 判断规则固定为 `title != null && title.trim().equals("未知")`。
- 示例结果 `{"id":0,"isHomeWork":"否","question":"指法没问题,手型没问题,节奏有问题,弹得还可以","title":"未知"}` 会触发 `WX003` 告警。
- 未知标题告警复用 `service_sys/common_warn_sender`、`sendTemplateList=["WX003"]`、`external_key`，且不传 `templateVariable`。
- 未知标题告警与超时、异常共用 `ai:sopReply:pianoVideo:timeoutWarn:{externalKey}` 5 分钟 Redis 去重窗口。
- 未知标题告警发送完成、发送失败或命中去重后，`handle` 返回原识别结果，不强制返回空结果。
- 验证命令：`mvn -q -DskipTests compile`
- 验证目录：`C:\workspace\ju-chat\fc\sop-reply`
- 剩余风险：未接入真实 Redis、FC 异步任务和 `common_warn_sender` 做端到端联调；当前验证覆盖编译和关键逻辑静态检查。

### D009 - 异步任务失败告警补漏实现与验证记录

- 根因确认：截图中的 `new supplier SDK call failed` 由 `fc/Gemini-Api` 的 `PianoHomeWorkVideoTask` 捕获异常后写入 Redis `STATUS_FAIL`；`fc/sop-reply` 轮询读到后只按普通 `fail()` 返回空结果，未进入告警链路。
- `PianoHomeWorkVideoTask` 写入失败缓存时新增 `errorSource=ASYNC_TASK_FAIL` 和 `errorStage=piano_homework_video_task_analyze`。
- `PianoVideoHomeWorkHandleServiceImpl` 读到 `STATUS_FAIL` 时，只有 `errorSource=BUSINESS_FAIL` 才按普通业务失败处理；其他失败均按异步任务执行异常触发 `WX003` 告警。
- 截图场景 `钢琴视频识别异步任务失败, cacheKey=..., waitStage=initial, error=new supplier SDK call failed` 会触发异常告警，并返回空 `HomeWorkResultDto`。
- 异步任务失败告警复用 `service_sys/common_warn_sender`、`sendTemplateList=["WX003"]`、`external_key`，且不传 `templateVariable`。
- 异步任务失败告警与超时、异常、未知标题共用 `ai:sopReply:pianoVideo:timeoutWarn:{externalKey}` 5 分钟 Redis 去重窗口。
- 验证命令：`mvn -q -DskipTests compile`
- 验证目录：`C:\workspace\ju-chat\fc\sop-reply`、`C:\workspace\ju-chat\fc\Gemini-Api`
- 剩余风险：未接入真实 Redis、FC 异步任务和 `common_warn_sender` 做端到端联调；当前验证覆盖编译和关键逻辑静态检查。

### D010 - 钢琴视频新供应商 HTTP 化实现与验证记录

- `PianoHomeWorkVideoTask` 新供应商路径已改为全 HTTP：直接把业务 `file_url` 作为 `file_data.file_uri` 调用 HTTP `generateContent`。
- `PianoHomeWorkVideoTask` 不再导入或调用 `com.google.genai` SDK。
- HTTP 生成使用 `POST https://ent.univibe.cc/{NEW_SUPPLIER_API_VERSION}/models/{NEW_SUPPLIER_MODEL}:generateContent`。
- HTTP 请求体使用同一 `prompt` 和原始视频 URL，格式为 `contents[].parts[].text` 与 `contents[].parts[].file_data`。
- HTTP 生成返回 2xx 时直接返回原始 JSON，继续复用现有 `extractTextFromResponse` 提取点评文本。
- HTTP 生成失败或响应文本为空时仍进入现有重试流程；重试耗尽后写入 `STATUS_FAIL`、`errorSource=ASYNC_TASK_FAIL`，并由 `sop-reply` 发送 `WX003`。
- `PracticeCommentFc` 不属于本次 HTTP 化范围，保持旧接口逻辑。
- 验证命令：`mvn -q -DskipTests compile`
- 验证目录：`C:\workspace\ju-chat\fc\Gemini-Api`、`C:\workspace\ju-chat\fc\sop-reply`
- 剩余风险：未用真实新供应商响应做端到端验证；当前验证覆盖编译、打包和关键逻辑静态检查。

### D011 - Google GenAI SDK 依赖升级记录

- `fc/Gemini-Api/pom.xml` 中 `com.google.genai:google-genai` 已从 `1.22.0` 升级到 `1.53.0`。
- `fc/Gemini-Api/pom.xml` 显式新增 `commons-logging:commons-logging:1.3.5`，用于补齐 Apache HttpClient 运行时依赖 `org/apache/commons/logging/LogFactory`。
- 执行命令：`mvn -q -DskipTests compile`
- 执行目录：`C:\workspace\ju-chat\fc\Gemini-Api`
- 执行结果：编译通过。
- 执行命令：`mvn dependency:tree "-Dincludes=com.google.genai:google-genai"`
- 解析结果：`com.google.genai:google-genai:jar:1.53.0:compile`。
- 执行命令：`mvn -q -DskipTests package`
- 打包结果：`target/gemini-api.jar` 包含 `org/apache/commons/logging/LogFactory.class` 和 `org/apache/http/impl/client/HttpClientBuilder.class`。

### D012 - 新供应商本地 test 方法规格记录

- 已按用户要求先修改 Spec Kit 文档，补充普通聊天和视频理解两个本地 test 方法的验收要求。
- 普通聊天 test 方法用于验证 `POST https://ent.univibe.cc/v1beta/models/gemini-3-flash-preview:generateContent` 的纯文本 `generateContent` 能力。
- 视频理解 test 方法用于验证 `https://ent.univibe.cc` 下的视频 URL 直传、`POST /v1beta/models/gemini-3-flash-preview:generateContent` 和响应文本提取。
- 两个 test 方法都必须从 `new_supplier_api_key` 读取令牌，不得把测试令牌写入代码、日志或文档。
- 代码实现已完成：`main chat ...` 执行普通聊天 test，`main video ...` 或默认 main 执行视频 URL 直传 test。
- 执行 `mvn -q -DskipTests package`，目录 `C:\workspace\ju-chat\fc\Gemini-Api`，结果通过。
- 执行 `mvn -q -DskipTests compile`，目录 `C:\workspace\ju-chat\fc\sop-reply`，结果通过。
- 静态检查确认 `PianoHomeWorkVideoTask` 不再包含 `callNewSupplierGeminiHttpWithUpload`、`startNewSupplierFileUpload`、`uploadNewSupplierFile`、`HttpGet`、`ByteArrayEntity` 和 `new_supplier_base_url`。
- 静态检查确认 `PracticeCommentFc` 未被本次修改触及。
- 普通聊天本地 test 已成功返回文本，验证 `https://ent.univibe.cc/v1beta/models/gemini-3-flash-preview:generateContent` 可用。
- 视频理解本地 test 已确认调用同一 `generateContent` URL，并以 `file_data.file_uri=<视频URL>` 直传视频；本次外部网关返回 `503 model_not_found`，错误为 `gemini-slb` 分组下 `gemini-3-flash-preview` 无可用渠道。
- 本次验证未暴露测试令牌；剩余风险是新供应商网关当前视频模型渠道不可用，需要供应商侧恢复或调整渠道后再做成功态视频理解联调。
