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
