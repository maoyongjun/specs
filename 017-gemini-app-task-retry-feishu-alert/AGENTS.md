# 规格执行说明

本目录记录 `017-gemini-app-task-retry-feishu-alert`，作用范围包含：

- 规格文档：`C:\workspace\ju-chat\specs\017-gemini-app-task-retry-feishu-alert`
- 目标代码：`C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\AppTask.java`

## 当前目标

- 当 `AppTask` 的重试次数超过上限并进入任务失败分支时，发送飞书消息通知固定用户 `6d9e5ee3`。
- 当 `retry(JSONObject jsonObject,String serviceName,String functionName)` 的 60 秒常规延迟重试提交超时或异常退出时，也发送飞书消息通知固定用户 `6d9e5ee3`，并在告警后执行 3300 秒兜底延迟重试。
- 飞书消息内容必须包含 `unionId`、`songName`、`nickName`、`picId`、`classId`。
- 告警发送方式仿照 `EmpErpPasswordServiceImpl` 中的 `FeiShuUtil.send(...)` 调用方式。

## 实现约束

- 只修改 `AppTask.java` 中重试超限失败分支和 `retry(...)` 常规延迟/告警兜底分支相关逻辑。
- 飞书告警失败不得覆盖原始任务失败异常。
- 不改变现有回调、重试、日志和任务处理主流程语义。
- `retry(...)` 正常提交成功时不新增飞书告警，也不触发 3300 秒兜底延迟重试。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录实现步骤、验证命令和结果。
- `checklists/requirements.md` 用于验证规格质量和实施完整性。
