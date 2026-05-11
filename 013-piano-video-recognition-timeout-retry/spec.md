# 功能规格：钢琴视频识别超时后单次延迟重试

**功能目录**: `013-piano-video-recognition-timeout-retry`  
**创建日期**: 2026-05-11  
**状态**: Implemented  
**输入**: 用户要求先创建 Spec Kit 文档，不编码；后续修改 `PianoVideoHomeWorkHandleServiceImpl#handle`，在首次等待 10 分钟超时后，再等待 7 分钟，随后再次调用 `triggerAsyncRecognitionIfNeeded` 重试一次，并再次等待 10 分钟；本次重试后不再继续重试。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 首次识别等待超时后延迟重试一次（优先级：P1）

钢琴视频作业异步识别首次触发后，系统最多等待 10 分钟识别结果。如果 10 分钟内未命中成功结果，也未得到明确失败状态，系统不应立即结束，而应再等待 7 分钟后重新尝试触发异步识别。

**独立测试**：构造钢琴视频作业消息，使首次异步识别在 10 分钟等待窗口内一直保持 `PENDING` 或 `RUNNING` 且无结果；验证系统在首次超时后等待 7 分钟，并调用一次 `triggerAsyncRecognitionIfNeeded`。

**验收场景**：

1. **Given** 首次异步识别已提交，**When** 10 分钟内缓存未出现 `SUCCESS` 结果，**Then** 系统进入重试延迟流程，而不是立即返回空结果。
2. **Given** 系统处于重试延迟流程，**When** 延迟满 7 分钟，**Then** 系统基于最新缓存状态再次调用 `triggerAsyncRecognitionIfNeeded`。
3. **Given** 7 分钟延迟期间原异步任务已经写入 `SUCCESS`，**When** 系统准备重试，**Then** 系统直接返回缓存结果，不应覆盖成功结果或重复触发识别。

### 用户故事 2 - 重试后再次等待 10 分钟（优先级：P1）

系统完成单次重试触发后，需要像首次触发一样继续等待识别结果，等待窗口仍为 10 分钟。

**独立测试**：构造首次等待超时、延迟 7 分钟后重试触发成功、重试等待期间写入 `SUCCESS` 的场景；验证 `handle` 返回解析后的识别结果。

**验收场景**：

1. **Given** 重试触发后缓存写入 `SUCCESS` 结果，**When** 结果出现在第二个 10 分钟等待窗口内，**Then** `handle` 返回该识别结果。
2. **Given** 重试触发后缓存写入 `FAIL`，**When** 第二个等待窗口读取到失败状态，**Then** `handle` 返回空 `HomeWorkResultDto` 并记录失败日志。
3. **Given** 重试触发后第二个 10 分钟等待窗口仍未得到结果，**When** 等待超时，**Then** `handle` 返回空 `HomeWorkResultDto`。

### 用户故事 3 - 重试最多一次（优先级：P1）

为避免长时间阻塞和重复提交异步任务，超时重试只能执行一次。第二次等待 10 分钟仍超时后，系统必须结束本次处理流程。

**独立测试**：构造首次等待超时、延迟 7 分钟后重试、第二次等待仍超时的场景；验证 `triggerAsyncRecognitionIfNeeded` 总调用次数最多为 2 次，且不会进入第三次等待或第三次触发。

**验收场景**：

1. **Given** 首次等待超时且重试等待也超时，**When** 第二个 10 分钟等待窗口结束，**Then** `handle` 返回空 `HomeWorkResultDto`。
2. **Given** 重试等待已经超时，**When** 缓存仍无成功结果，**Then** 系统不再等待 7 分钟，也不再调用 `triggerAsyncRecognitionIfNeeded`。
3. **Given** 同一个 `handle` 调用过程，**When** 统计异步识别触发尝试，**Then** 最多包含首次触发和一次重试触发。

## 边界情况

- 本需求只修改钢琴视频作业处理类 `PianoVideoHomeWorkHandleServiceImpl` 的 `handle` 相关流程。
- 首次 10 分钟等待内读取到 `SUCCESS` 时，必须保持现有行为，直接返回识别结果，不进入重试延迟。
- 首次 10 分钟等待内读取到 `FAIL` 时，按明确失败处理，返回空结果；本规格不要求对明确失败状态执行延迟重试。
- 7 分钟延迟期间缓存可能由原异步任务写入 `SUCCESS`；重试前必须重新读取缓存并优先返回成功结果。
- 重试触发应复用同一个 `cacheKey` 与 `dispatchLockKey`，确保结果仍通过同一缓存键读取。
- 重试触发应使用新的 `taskId`，避免与首次任务的日志、锁值和 trace 混淆。
- 如果重试前缓存仍为 `PENDING` 或 `RUNNING`，`triggerAsyncRecognitionIfNeeded` 应继续遵守现有 `shouldTriggerAsync`、分布式锁和 stale 判断，不强行绕过锁机制。
- 线程在 7 分钟延迟或 10 分钟等待期间被中断时，沿用现有中断处理策略。

## 需求 *(必填)*

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下创建本 Spec Kit 目录。
- **FR-002**：实现范围 MUST 限定在 `PianoVideoHomeWorkHandleServiceImpl.java` 的 `handle` 相关流程及必要私有辅助方法。
- **FR-003**：首次调用 `triggerAsyncRecognitionIfNeeded` 后，系统 MUST 等待最多 10 分钟识别结果。
- **FR-004**：首次等待 10 分钟超时且未读取到 `SUCCESS` 或 `FAIL` 时，系统 MUST 再等待 7 分钟后进入重试流程。
- **FR-005**：重试流程开始前，系统 MUST 重新读取缓存状态。
- **FR-006**：如果 7 分钟延迟期间缓存已经变为 `SUCCESS`，系统 MUST 直接返回该缓存结果，不再触发重试。
- **FR-007**：如果重试前缓存不是可返回的 `SUCCESS`，系统 MUST 再次调用 `triggerAsyncRecognitionIfNeeded`。
- **FR-008**：重试调用 `triggerAsyncRecognitionIfNeeded` 时 MUST 使用新的 `taskId`。
- **FR-009**：重试触发后，系统 MUST 再等待最多 10 分钟识别结果。
- **FR-010**：第二次 10 分钟等待结束后，无论是否超时，系统 MUST 结束本次 `handle` 流程，不再继续重试。
- **FR-011**：同一次 `handle` 调用中，`triggerAsyncRecognitionIfNeeded` MUST 最多被调用两次。
- **FR-012**：首次等待成功、明确失败、空入参、`fileUrl` 为空、缓存命中成功等现有短路行为 MUST 保持不变。
- **FR-013**：系统 SHOULD 增加可检索日志，覆盖首次等待超时、7 分钟延迟开始、重试触发、重试等待结束和不再重试。

## 成功标准 *(必填)*

- **SC-001**：本目录包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：首次等待 10 分钟超时后，系统不会立即返回，而是进入 7 分钟延迟。
- **SC-003**：7 分钟延迟结束后，系统在未命中成功缓存时调用一次 `triggerAsyncRecognitionIfNeeded`。
- **SC-004**：重试触发后，系统再次等待 10 分钟识别结果。
- **SC-005**：重试等待超时后，系统返回空 `HomeWorkResultDto`，且不再继续重试。
- **SC-006**：7 分钟延迟期间原任务写入成功结果时，系统返回该成功结果，不发起重复识别。
- **SC-007**：`fc/sop-reply` 模块编译通过。

## 假设

- `waitForRecognitionResult` 需要能区分成功、失败与超时，或通过等价辅助结构让 `handle` 判断是否需要延迟重试。
- 现有 `MAX_WAIT_MILLIS` 继续表示单次等待窗口 10 分钟。
- 新增的 7 分钟延迟可定义为私有常量，例如 `RETRY_DELAY_MILLIS = 7 * 60 * 1000L`。
- 现有 `DISPATCH_LOCK_EXPIRE_SECONDS=6 * 60` 与 `STALE_STATE_MILLIS` 逻辑可以继续约束是否真正重新提交异步任务。
- 本规格已实现并通过 `fc/sop-reply` 模块编译验证。
