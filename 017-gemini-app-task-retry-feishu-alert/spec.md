# 功能规格：Gemini 任务重试超限/超时飞书告警

**功能目录**: `017-gemini-app-task-retry-feishu-alert`  
**创建日期**: 2026-05-15  
**状态**: Ready for Implementation  
**输入**: 用户要求修改 `C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\AppTask.java`，在重试次数超过上限时触发飞书通知，同时在 `private void retry(JSONObject jsonObject,String serviceName,String functionName)` 的延迟重试提交超时/异常退出时也触发飞书通知；其中常规重试延迟保持 60 秒不变，告警兜底延迟使用 55 分钟（3300 秒）。参考 `C:\workspace\ju-chat\kkhc\kkhc-idc\erp\src\main\java\com\drh\idc\erp\service\impl\EmpErpPasswordServiceImpl.java` 的 `FeiShuUtil.send(...)` 用法，固定飞书用户 ID 为 `6d9e5ee3`，消息包含 `unionId`、`songName`、`nickName`、`picId`、`classId`。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 任务重试超限时应收到飞书告警（优先级：P1）

当 `AppTask` 连续重试后仍然失败，且进入“重试次数超过上限”的异常分支时，系统需要主动向固定飞书用户发送通知，避免失败任务无人感知。

**独立测试**：构造一个会触发重试超限的输入，验证飞书发送方法被调用，且发送内容包含指定业务字段。

**验收场景**：

1. **Given** 任务进入重试超限失败分支，**When** 发送飞书告警，**Then** 固定用户 `6d9e5ee3` 会收到通知。
2. **Given** 告警消息被组装，**When** 检查消息内容，**Then** 必须包含 `unionId`、`songName`、`nickName`、`picId`、`classId`。
3. **Given** 飞书发送失败，**When** 任务已经重试超限，**Then** 原始任务失败仍然继续抛出，不被告警失败掩盖。

### 用户故事 2 - `retry(...)` 超时或异常退出时也应收到飞书告警（优先级：P1）

当 `retry(JSONObject jsonObject, String serviceName, String functionName)` 触发延迟重试提交时，如果 `FcInvokeUtils.doTaskWithDelay(...)` 超时或抛出异常，导致本次重试没有成功挂起并直接退出，系统需要主动向固定飞书用户发送通知，避免重试链路静默失败。

**独立测试**：构造一个会让 `FcInvokeUtils.doTaskWithDelay(...)` 返回 `0`、超时或抛出异常的输入，验证飞书发送方法被调用，并且在告警后还会触发 3300 秒兜底延迟调用，且发送内容包含指定业务字段。

**验收场景**：

1. **Given** `retry(...)` 进入超时或异常失败分支，**When** 发送飞书告警，**Then** 固定用户 `6d9e5ee3` 会收到通知。
2. **Given** 告警消息被组装，**When** 检查消息内容，**Then** 必须包含 `unionId`、`songName`、`nickName`、`picId`、`classId`。
3. **Given** 飞书发送失败，**When** 重试提交已经超时或异常退出，**Then** 原始重试失败仍然继续抛出，不被告警失败掩盖。
4. **Given** `retry(...)` 进入告警兜底分支，**When** 检查后续调用参数，**Then** 必须使用 3300 秒的延迟。

### 用户故事 3 - 告警逻辑应保持最小侵入（优先级：P2）

重试超限通知和 `retry(...)` 超时通知只是失败分支的附加动作，不应影响成功路径、常规重试路径和回调行为。

**独立测试**：检查成功分支、未超限重试分支与 `retry(...)` 正常提交成功分支没有新增飞书发送调用。

**验收场景**：

1. **Given** 任务正常成功，**When** 执行处理，**Then** 不发送飞书失败告警。
2. **Given** 任务仍处于可重试区间，**When** 执行处理，**Then** 不发送重试超限告警。
3. **Given** `retry(...)` 正常提交成功，**When** 执行处理，**Then** 不发送 retry 超时告警。

## 边界情况

- `unionId`、`songName`、`nickName`、`picId`、`classId` 任一字段为空时，消息仍应发送，字段值以原始读取结果展示。
- 飞书发送异常时，应仅记录日志，不影响原始任务异常抛出。
- 若 `retryMaxCountNum` 使用默认值或环境变量值，告警文案中的“重试次数超过{}次”应与实际判断使用的阈值一致。
- `retry(...)` 的延迟重试提交超时或异常退出时，也应发送飞书告警；若飞书发送失败，只记录日志，不影响原始失败抛出。
- `retry(...)` 的常规延迟重试保持 60 秒不变；当这次提交失败、超时或抛出异常时，才触发 3300 秒（55 分钟）兜底延迟重试。
- `retry(...)` 正常提交成功时，不应发送 retry 超时告警。

## 需求 *(必填)*

- **FR-001**：`AppTask` MUST 在重试次数超过上限进入失败分支时发送飞书通知。
- **FR-002**：飞书通知 MUST 使用 `FeiShuUtil.send(String text, String userId)` 的调用方式。
- **FR-003**：飞书接收人 MUST 固定为 `6d9e5ee3`。
- **FR-004**：通知内容 MUST 包含 `unionId`、`songName`、`nickName`、`picId`、`classId`。
- **FR-005**：飞书发送失败 MUST NOT 阻止原始异常继续抛出。
- **FR-006**：成功路径、未超限重试路径和 `retry(...)` 正常提交成功路径 MUST 保持原有行为。
- **FR-007**：`retry(...)` 的延迟重试提交超时或异常退出时 MUST 发送飞书通知。
- **FR-008**：`retry(...)` 超时/异常告警失败 MUST NOT 阻止原始失败继续抛出。
- **FR-009**：`retry(...)` 调用 `FcInvokeUtils.doTaskWithDelay(...)` 时 MUST 先使用 60 秒作为常规延迟。
- **FR-010**：当 60 秒常规延迟提交返回 `0`、超时或抛出异常时，`retry(...)` MUST 发送飞书通知并再尝试 3300 秒（55 分钟）兜底延迟重试。
- **FR-011**：3300 秒兜底延迟重试失败 MUST NOT 阻止原始失败继续抛出。

## 成功标准 *(必填)*

- **SC-001**：`AppTask.java` 在重试超限失败分支调用 `FeiShuUtil.send(...)`。
- **SC-002**：飞书消息中可直接定位任务的 `unionId`、`songName`、`nickName`、`picId`、`classId` 均存在。
- **SC-003**：飞书发送失败时任务仍然失败退出。
- **SC-004**：任务成功和未超限重试行为不受影响。
- **SC-005**：`retry(...)` 的超时/异常失败分支调用 `FeiShuUtil.send(...)`。
- **SC-006**：`retry(...)` 超时/异常告警发送失败时，原始失败仍然继续抛出。
- **SC-007**：`retry(...)` 正常提交成功时不发送飞书告警。
- **SC-008**：`retry(...)` 的常规延迟重试固定使用 60 秒。
- **SC-009**：`retry(...)` 的兜底延迟重试固定使用 3300 秒（55 分钟）。

## 假设

- 固定飞书用户 ID `6d9e5ee3` 可直接用于 `FeiShuUtil.send(...)`。
- 当前项目已可通过依赖直接引用 `com.kkhc.common.utils.FeiShuUtil`。
- 现有日志中的“重试次数超过{}次，任务失败，请检查参数，unionId=”语义应保持不变，仅补充飞书通知。
- `retry(...)` 的“超时”场景以延迟重试提交未成功挂起为准，告警目标与超限失败分支一致。
- `retry(...)` 的常规延迟重试仍为 60 秒；3300 秒仅用于告警后的兜底重试。
