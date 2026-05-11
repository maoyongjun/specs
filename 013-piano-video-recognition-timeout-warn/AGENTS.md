# 规格执行说明

本目录记录 `013-piano-video-recognition-timeout-warn`，作用范围包含：

- 规格文档：`C:\workspace\ju-chat\specs\013-piano-video-recognition-timeout-warn`
- 目标代码：`C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\service\homeworkhandle\PianoVideoHomeWorkHandleServiceImpl.java`
- 参考代码：`C:\workspace\ju-chat\coze_plugin\external-info-save\src\main\java\com\drh\info\service\AppTask.java#notifyBookRegisterWarn`

## 当前目标

- 修改 `PianoVideoHomeWorkHandleServiceImpl#handle` 的钢琴视频识别等待超时处理。
- 首次异步识别仍等待最多 10 分钟。
- 首次等待 10 分钟超时后，不进行 7 分钟延迟。
- 首次等待 10 分钟超时后，不再次调用 `triggerAsyncRecognitionIfNeeded`。
- 首次等待 10 分钟超时后，发送告警 `WX003`。
- 告警模板变量为 `campName` 和 `userName`，由 `common_warn_sender` 内部基于 `external_key` 补齐。

## 实现约束

- 本次用户要求是修改文档；当前业务代码尚未按新规格调整。
- 行为变更必须限定在钢琴视频作业处理流程。
- 缓存命中成功、空入参、`fileUrl` 为空等现有短路逻辑必须保持不变。
- 明确失败状态不属于本规格要求的“等待 10 分钟超时告警”场景。
- 超时后不能再等待 7 分钟，不能再二次触发异步识别。
- 告警发送方式参考 `notifyBookRegisterWarn`：构造 `taskObj`，调用 `FcInvokeUtils.doTask`，目标为 `service_sys/common_warn_sender`。
- 告警 `sendTemplateList` 使用 `WX003`。
- 调用方不需要传 `templateVariable`；`campName` 和 `userName` 由 `common_warn_sender` 内部解析。
- 告警异常必须捕获并记录日志，不能影响主流程返回。

## 当前实现状态

- 当前代码已按本规格移除“首次等待超时后延迟 7 分钟并单次重试”逻辑。
- 当前代码已改为首次等待 10 分钟超时后发送 `WX003` 告警。
- `waitForRecognitionResult` 当前已能区分成功、失败和超时，可复用该能力判断是否发送告警。
- `fc/sop-reply` 模块已通过 `mvn -q -DskipTests compile` 编译验证。

## 告警入参约定

参考 `notifyBookRegisterWarn`，钢琴视频识别超时告警建议结构：

```json
{
  "external_key": "...",
  "sendTemplateList": ["WX003"]
}
```

`FcInvokeInput`：

- `serviceName`: `service_sys`
- `functionName`: `common_warn_sender`
- `taskObj`: 上述告警 JSON

`campName` 和 `userName` 不在调用方传入，由 `common_warn_sender` 内部根据 `external_key` 补齐。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录实现步骤、验证任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量和实施完整性。
