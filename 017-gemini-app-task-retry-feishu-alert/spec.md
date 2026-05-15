# 功能规格：Gemini 任务重试超限飞书告警

**功能目录**: `017-gemini-app-task-retry-feishu-alert`  
**创建日期**: 2026-05-15  
**状态**: Ready for Implementation  
**输入**: 用户要求修改 `C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\AppTask.java`，在重试次数超过异常时触发飞书通知，参考 `C:\workspace\ju-chat\kkhc\kkhc-idc\erp\src\main\java\com\drh\idc\erp\service\impl\EmpErpPasswordServiceImpl.java` 的 `FeiShuUtil.send(...)` 用法，固定飞书用户 ID 为 `6d9e5ee3`，消息包含 `unionId`、`songName`、`nickName`、`picId`、`classId`。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 任务重试超限时应收到飞书告警（优先级：P1）

当 `AppTask` 连续重试后仍然失败，且进入“重试次数超过上限”的异常分支时，系统需要主动向固定飞书用户发送通知，避免失败任务无人感知。

**独立测试**：构造一个会触发重试超限的输入，验证飞书发送方法被调用，且发送内容包含指定业务字段。

**验收场景**：

1. **Given** 任务进入重试超限失败分支，**When** 发送飞书告警，**Then** 固定用户 `6d9e5ee3` 会收到通知。
2. **Given** 告警消息被组装，**When** 检查消息内容，**Then** 必须包含 `unionId`、`songName`、`nickName`、`picId`、`classId`。
3. **Given** 飞书发送失败，**When** 任务已经重试超限，**Then** 原始任务失败仍然继续抛出，不被告警失败掩盖。

### 用户故事 2 - 告警逻辑应保持最小侵入（优先级：P2）

重试超限通知只是失败分支的附加动作，不应影响成功路径、常规重试路径和回调行为。

**独立测试**：检查成功分支与未超限重试分支没有新增飞书发送调用。

**验收场景**：

1. **Given** 任务正常成功，**When** 执行处理，**Then** 不发送飞书失败告警。
2. **Given** 任务仍处于可重试区间，**When** 执行处理，**Then** 不发送重试超限告警。

## 边界情况

- `unionId`、`songName`、`nickName`、`picId`、`classId` 任一字段为空时，消息仍应发送，字段值以原始读取结果展示。
- 飞书发送异常时，应仅记录日志，不影响原始任务异常抛出。
- 若 `retryMaxCountNum` 使用默认值或环境变量值，告警文案中的“重试次数超过{}次”应与实际判断使用的阈值一致。

## 需求 *(必填)*

- **FR-001**：`AppTask` MUST 在重试次数超过上限进入失败分支时发送飞书通知。
- **FR-002**：飞书通知 MUST 使用 `FeiShuUtil.send(String text, String userId)` 的调用方式。
- **FR-003**：飞书接收人 MUST 固定为 `6d9e5ee3`。
- **FR-004**：通知内容 MUST 包含 `unionId`、`songName`、`nickName`、`picId`、`classId`。
- **FR-005**：飞书发送失败 MUST NOT 阻止原始异常继续抛出。
- **FR-006**：成功路径和未超限重试路径 MUST 保持原有行为。

## 成功标准 *(必填)*

- **SC-001**：`AppTask.java` 在重试超限失败分支调用 `FeiShuUtil.send(...)`。
- **SC-002**：飞书消息中可直接定位任务的 `unionId`、`songName`、`nickName`、`picId`、`classId` 均存在。
- **SC-003**：飞书发送失败时任务仍然失败退出。
- **SC-004**：任务成功和未超限重试行为不受影响。

## 假设

- 固定飞书用户 ID `6d9e5ee3` 可直接用于 `FeiShuUtil.send(...)`。
- 当前项目已可通过依赖直接引用 `com.kkhc.common.utils.FeiShuUtil`。
- 现有日志中的“重试次数超过{}次，任务失败，请检查参数，unionId=”语义应保持不变，仅补充飞书通知。
