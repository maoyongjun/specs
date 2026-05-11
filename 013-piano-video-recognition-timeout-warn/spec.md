# 功能规格：钢琴视频识别超时告警

**功能目录**: `013-piano-video-recognition-timeout-warn`  
**创建日期**: 2026-05-11  
**状态**: Implemented  
**输入**: 用户要求修改并实现：`PianoVideoHomeWorkHandleServiceImpl#handle` 在等待 10 分钟超时后不再进行重试，而是发送告警；告警编号为 `WX003`；同一个 `externalKey` 5 分钟内最多告警一次；`campName` 和 `userName` 由 `common_warn_sender` 内部基于 `external_key` 补齐，调用方无需传入模板变量；告警调用方式参考 `C:\workspace\ju-chat\coze_plugin\external-info-save\src\main\java\com\drh\info\service\AppTask.java` 的 `notifyBookRegisterWarn` 方法。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 钢琴视频识别等待 10 分钟超时后发送告警（优先级：P1）

钢琴视频作业异步识别首次触发后，系统最多等待 10 分钟识别结果。如果 10 分钟内未命中成功结果，也未得到明确失败状态，系统应结束识别等待并发送一次告警，提醒人工关注该学员的钢琴视频识别超时。

**独立测试**：构造钢琴视频作业消息，使异步识别在 10 分钟等待窗口内一直保持 `PENDING` 或 `RUNNING` 且无结果；验证系统调用 `common_warn_sender` 发送 `WX003` 告警，且入参包含可用于解析 `campName`、`userName` 的 `external_key`。

**验收场景**：

1. **Given** 首次异步识别已提交，**When** 10 分钟内缓存未出现 `SUCCESS` 结果，**Then** 系统发送 `WX003` 告警。
2. **Given** 系统发送 `WX003` 告警，**When** 构造告警入参，**Then** `sendTemplateList` 包含且仅需包含 `WX003`。
3. **Given** 系统发送 `WX003` 告警，**When** `common_warn_sender` 处理 `external_key`，**Then** 由该接口内部补齐 `campName` 和 `userName`。
4. **Given** 首次等待已经超时，**When** 告警发送完成或发送失败被捕获，**Then** `handle` 返回空 `HomeWorkResultDto`。

### 用户故事 2 - 超时后不重试异步识别（优先级：P1）

为避免长时间阻塞和重复提交异步任务，首次 10 分钟等待超时后不再延迟等待，也不再重新调用识别函数。

**独立测试**：构造首次等待超时场景；验证 `triggerAsyncRecognitionIfNeeded` 总调用次数最多为 1 次，且不会出现 7 分钟延迟、第二次触发或第二个 10 分钟等待窗口。

**验收场景**：

1. **Given** 首次等待 10 分钟超时，**When** 系统处理超时，**Then** 不调用 `sleepQuietly(7 * 60 * 1000L)` 或任何等价延迟。
2. **Given** 首次等待 10 分钟超时，**When** 系统处理超时，**Then** 不再次调用 `triggerAsyncRecognitionIfNeeded`。
3. **Given** 同一个 `handle` 调用过程，**When** 统计异步识别触发尝试，**Then** 最多只有首次触发一次。

### 用户故事 3 - 告警调用格式对齐参考实现（优先级：P1）

告警发送需要复用现有 `common_warn_sender` 调用方式，入参结构参考 `AppTask#notifyBookRegisterWarn`。

参考结构：

```json
{
  "external_key": "...",
  "sendTemplateList": ["WX003"]
}
```

实际调用方只需要传 `external_key` 和 `sendTemplateList=["WX003"]`，不需要传 `templateVariable`。

**独立测试**：拦截 `FcInvokeUtils.doTask` 入参，验证 `serviceName=service_sys`、`functionName=common_warn_sender`，`taskObj.external_key` 有值，`sendTemplateList=["WX003"]`，且未强制传入 `templateVariable`。

**验收场景**：

1. **Given** 超时告警需要发送，**When** 构造 `FcInvokeInput`，**Then** `serviceName` 为 `service_sys`。
2. **Given** 超时告警需要发送，**When** 构造 `FcInvokeInput`，**Then** `functionName` 为 `common_warn_sender`。
3. **Given** 超时告警需要发送，**When** 构造 `taskObj`，**Then** 入参格式与 `notifyBookRegisterWarn` 一致，并使用 `WX003`。

### 用户故事 4 - 同一 externalKey 5 分钟内只告警一次（优先级：P1）

同一个学员上下文在 5 分钟内可能触发多次钢琴视频识别超时。系统需要在本地调用 `common_warn_sender` 前做一次 `externalKey` 维度的去重，避免短时间内重复告警。

**独立测试**：连续构造两个相同 `externalKey` 的钢琴视频识别超时场景；验证第一次会调用 `common_warn_sender`，第二次在 5 分钟窗口内命中去重并跳过告警。

**验收场景**：

1. **Given** 某 `externalKey` 首次触发超时告警，**When** Redis 去重 key 不存在，**Then** 系统写入 300 秒过期的去重 key 并发送 `WX003`。
2. **Given** 同一 `externalKey` 在 5 分钟内再次触发超时，**When** Redis 去重 key 仍存在，**Then** 系统不调用 `common_warn_sender`，并记录 `piano_video_recognition_timeout_warn_repeat_limited` 日志。
3. **Given** Redis 去重操作异常，**When** 系统处理超时告警，**Then** 记录降级日志并继续发送告警，避免漏告警。

## 边界情况

- 本需求只修改钢琴视频作业处理类 `PianoVideoHomeWorkHandleServiceImpl` 的 `handle` 超时处理及必要告警辅助方法。
- 首次 10 分钟等待内读取到 `SUCCESS` 时，必须保持现有行为，直接返回识别结果，不发送告警。
- 首次 10 分钟等待内读取到 `FAIL` 时，按明确失败处理，返回空结果；本规格不要求对明确失败状态发送 `WX003` 超时告警。
- 10 分钟等待超时后，即使缓存仍为 `PENDING` 或 `RUNNING`，也不再等待 7 分钟，不再二次触发异步识别。
- `common_warn_sender` 依赖 `external_key`；实现时应从当前 SOP 上下文读取或构造可用 `external_key`，并在缺失时记录告警跳过日志。
- `WX003` 告警发送前需要按 `externalKey` 做本地 Redis 去重，key 为 `ai:sopReply:pianoVideo:timeoutWarn:{externalKey}`，过期时间为 300 秒。
- 命中 5 分钟去重时应跳过 `common_warn_sender` 调用，并记录可检索日志。
- Redis 去重操作异常时继续发送告警，优先避免漏告警；此时可能无法严格保证 5 分钟只告警一次。
- `common_warn_sender` 调用失败时不删除去重 key，避免失败期间重复尝试造成告警风暴。
- `campName` 和 `userName` 是 `WX003` 模板变量，由 `common_warn_sender` 根据 `external_key` 补齐；调用方不需要传 `templateVariable`。
- 告警发送失败不应抛出影响主流程，应捕获异常并记录错误日志。
- 线程在 10 分钟等待期间被中断时，沿用现有中断处理策略。

## 需求 *(必填)*

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下维护本 Spec Kit 目录。
- **FR-002**：实现范围 MUST 限定在 `PianoVideoHomeWorkHandleServiceImpl.java` 的 `handle` 超时处理及必要私有辅助方法。
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
- **FR-013**：首次等待成功、明确失败、空入参、`fileUrl` 为空、缓存命中成功等现有短路行为 MUST 保持不变。
- **FR-014**：系统 SHOULD 增加可检索日志，覆盖识别等待超时、告警入参、告警发送成功或失败、超时后不重试。
- **FR-015**：系统 MUST 在调用 `common_warn_sender` 前按 `externalKey` 做 5 分钟 Redis 去重。
- **FR-016**：去重 key MUST 为 `ai:sopReply:pianoVideo:timeoutWarn:{externalKey}`。
- **FR-017**：去重 key 过期时间 MUST 为 300 秒。
- **FR-018**：同一个 `externalKey` 在 5 分钟内再次触发超时告警时，系统 MUST NOT 调用 `common_warn_sender`。
- **FR-019**：Redis 去重操作异常时，系统 MUST 记录日志并继续发送告警。
- **FR-020**：`common_warn_sender` 调用失败时，系统 MUST NOT 删除去重 key。

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

## 假设

- `waitForRecognitionResult` 需要能区分成功、失败与超时，或通过等价辅助结构让 `handle` 判断是否需要发送超时告警。
- 现有 `MAX_WAIT_MILLIS` 继续表示单次等待窗口 10 分钟。
- 旧版 7 分钟延迟重试需求已被本规格替换，当前实现已移除延迟重试逻辑。
- `common_warn_sender` 会基于 `external_key` 自动补齐基础变量，`WX003` 仍以 `campName`、`userName` 作为业务变量。
- “只告警一次”按同一 `externalKey` 维度计算，不区分 `messageId`。
- 5 分钟限制的是发送尝试次数；即使 `common_warn_sender` 调用失败，也不会在 5 分钟内重复尝试。
- 本规格已实现并通过 `fc/sop-reply` 模块编译验证。
