# 规格执行说明

本目录记录 `013-piano-video-recognition-timeout-retry`，作用范围包含：

- 规格文档：`C:\workspace\ju-chat\specs\013-piano-video-recognition-timeout-retry`
- 目标代码：`C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\service\homeworkhandle\PianoVideoHomeWorkHandleServiceImpl.java`

## 当前目标

- 修改 `PianoVideoHomeWorkHandleServiceImpl#handle` 的钢琴视频识别等待流程。
- 首次异步识别仍等待最多 10 分钟。
- 首次等待超时后，再等待 7 分钟。
- 7 分钟后再次调用 `triggerAsyncRecognitionIfNeeded` 重试一次。
- 重试后再次等待最多 10 分钟。
- 重试等待结束后不再继续重试。

## 实现约束

- 本规格当前只创建文档，不修改业务代码。
- 行为变更必须限定在钢琴视频作业处理流程。
- 缓存命中成功、空入参、`fileUrl` 为空等现有短路逻辑必须保持不变。
- 明确失败状态不属于本规格要求的“等待 10 分钟超时后重试”场景。
- 重试前必须重新读取缓存，避免 7 分钟延迟期间原任务已成功时重复触发。
- 重试应使用新的 `taskId`，但复用同一个 `cacheKey` 与 `dispatchLockKey`。
- 重试触发仍应遵守 `triggerAsyncRecognitionIfNeeded` 内部的锁和 stale 判断。
- 同一次 `handle` 调用最多允许首次触发和一次重试触发。

## 当前实现状态

- `PianoVideoHomeWorkHandleServiceImpl#handle` 已实现首次等待超时后的 7 分钟延迟和单次重试。
- `waitForRecognitionResult` 已调整为返回 `RecognitionWaitResult`，可区分成功、失败和超时。
- 重试前会重新读取缓存，命中成功时直接返回；未命中成功时使用新的 `taskId` 再次触发。
- 重试触发后会再次等待 10 分钟，结束后不再继续重试。
- `fc/sop-reply` 模块已通过 `mvn -q -DskipTests compile` 编译验证。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录实现步骤、验证任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量和实施完整性。
