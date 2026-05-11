# 任务清单：钢琴视频识别超时后单次延迟重试

**输入**：来自 `specs/013-piano-video-recognition-timeout-retry/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：通过模块编译检查、关键逻辑走查和可控缓存状态验证。  

## Phase 1：规格与范围

- [x] T001 创建 Spec Kit 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确目标文件为 `PianoVideoHomeWorkHandleServiceImpl.java`
- [x] T003 明确目标方法为 `handle`，必要时允许提取私有辅助方法承载等待结果状态
- [x] T004 明确本次只先写文档，不修改业务代码

## Phase 2：实现

- [x] T005 为 7 分钟重试延迟新增私有常量，例如 `RETRY_DELAY_MILLIS`
- [x] T006 调整等待结果返回结构，使调用方能区分 `SUCCESS`、`FAIL` 和 `TIMEOUT`
- [x] T007 保持首次触发 `triggerAsyncRecognitionIfNeeded` 后等待 10 分钟的现有窗口
- [x] T008 在首次等待超时后调用 `sleepQuietly(RETRY_DELAY_MILLIS)` 延迟 7 分钟
- [x] T009 7 分钟延迟结束后重新读取缓存状态，若已成功则直接返回缓存结果
- [x] T010 未命中成功缓存时，使用新的 `taskId` 再次调用 `triggerAsyncRecognitionIfNeeded`
- [x] T011 重试触发后再次等待 10 分钟识别结果
- [x] T012 第二次等待结束后直接返回结果或空 `HomeWorkResultDto`，不再继续重试
- [x] T013 增加首次超时、延迟重试、重试完成和不再重试的关键日志

## Phase 3：验证

- [x] T014 验证首次等待成功时不进入重试流程
- [x] T015 验证首次等待明确失败时保持返回空结果，不进入超时重试
- [x] T016 验证首次等待超时后延迟 7 分钟再调用一次 `triggerAsyncRecognitionIfNeeded`
- [x] T017 验证 7 分钟延迟期间缓存成功时不重复触发识别
- [x] T018 验证重试等待成功时返回识别结果
- [x] T019 验证重试等待超时后不再第三次重试
- [x] T020 编译 `fc/sop-reply` 模块
- [x] T021 记录验证结果和剩余风险

## 执行记录

### D001 - 文档记录

- 已按用户要求先创建 Spec Kit 文档。
- 未修改 `PianoVideoHomeWorkHandleServiceImpl.java` 或其他业务代码。
- 已将需求拆分为首次 10 分钟等待、7 分钟延迟、单次重试、第二次 10 分钟等待和不再重试的可验证任务。

### D002 - 实现记录

- `PianoVideoHomeWorkHandleServiceImpl` 新增 `RETRY_DELAY_MILLIS = 7 * 60 * 1000L`。
- `waitForRecognitionResult` 调整为返回 `RecognitionWaitResult`，可区分 `SUCCESS`、`FAIL` 和 `TIMEOUT`。
- `handle` 在首次等待超时后记录重试调度日志，等待 7 分钟后重新读取缓存。
- 7 分钟延迟期间若缓存已经成功，`handle` 直接解析并返回缓存结果，不再触发重试。
- 未命中成功缓存时，`handle` 使用新的 `retryTaskId` 再次调用 `triggerAsyncRecognitionIfNeeded`。
- 重试触发后再次等待 10 分钟；第二次等待结束后直接返回结果或空结果，不再继续重试。
- 新增可检索日志：`piano_video_recognition_initial_wait_timeout_retry_scheduled`、`piano_video_recognition_retry_delay_success_cache_hit`、`piano_video_recognition_retry_trigger`、`piano_video_recognition_retry_wait_timeout_no_more_retry`。

### D003 - 验证记录

- 执行命令：`mvn -q -DskipTests compile`
- 执行目录：`C:\workspace\ju-chat\fc\sop-reply`
- 执行结果：编译通过。
- 静态检查确认首次等待成功或明确失败时不进入延迟重试。
- 静态检查确认首次等待超时后执行 7 分钟延迟，并最多再次调用一次 `triggerAsyncRecognitionIfNeeded`。
- 静态检查确认重试前重新读取缓存，命中成功时直接返回。
- 静态检查确认重试等待结束后不再继续重试。
- 剩余风险：未接入真实 Redis、FC 异步任务和企微链路做端到端联调；当前验证覆盖编译和关键逻辑走查。
