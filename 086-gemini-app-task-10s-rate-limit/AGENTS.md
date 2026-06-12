# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\086-gemini-app-task-10s-rate-limit`
- 目标项目：`C:\workspace\ju-chat\fc\Gemini-Api`
- 相关模块：`com.drh.gemini.api.AppTask`

## 当前目标

- 只对 `AppTask.handleRequest` 的音频 Gemini 调用链增加 10 秒一个的专属限速。
- 限速入口必须在音频下载和 Base64 转换之前，避免突发请求持有大对象等待。
- 不修改共享 `RateLimitUtil`，不改变视频任务、供应商路由和其它复用 `AppTask.callExternalGeminiApiAndExtractText` 的调用方。

## 执行原则

- 先读代码，再定方案，后实现。
- 排队等待不在函数内长时间 sleep；使用 Redis 预订执行时间并通过 FC 延迟异步重投递。
- 内部排队字段只用于 AppTask 自身重投递，不进入回调数据。
- 业务失败重试、回调、飞书告警、Gemini HTTP 请求体和响应解析保持旧逻辑。

## 强制门禁

- 关键参数必须在调用前有来源：`pic_url`、`prompt`、`callback_url`、`retryCountNum`、FC `serviceName/functionName`。
- 限速未到点时不得调用 `convertAudioToBase64`，不得调用 Gemini API。
- 单元测试必须覆盖 800 连续预订、1 小时以上分段延迟、未到点跳过下载、到点执行。
- 共享限流工具 `RateLimitUtil.java` 不得修改。

## 重点代码位置

- `C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\AppTask.java`
- `C:\workspace\ju-chat\fc\Gemini-Api\src\test\java\com\drh\gemini\api\AppTaskRateLimitTest.java`

## 文档维护

- `spec.md` 记录需求、边界、800 突发分析和执行记录。
- `tasks.md` 记录事实确认、实现任务、测试任务和结果。
- `checklists/requirements.md` 记录规格质量和参数完整性检查。
