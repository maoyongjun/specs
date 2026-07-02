# 规格执行说明

本目录记录 `Gemini-Api` 中 `AppTask` 重试时切换 Gemini 模型的需求、事实确认、风险门禁和实现验证。
后续补充记录 AppTask mp3 URL 超过 5MiB 时裁剪为前 2MiB 的需求。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\115-gemini-app-task-retry-model`
- 目标项目：`C:\workspace\ju-chat\fc\Gemini-Api`
- 相关模块：`src\main\java\com\drh\gemini\api\AppTask.java`

## 当前目标

- 在 AppTask 音频 Gemini 调用链路中按 `retryCountNum` 选择模型。
- 首轮执行继续使用 `gemini-3-pro`。
- 重试执行使用 `gemini-3.5-flash`，同时保持现有重试调度、限流、callback 和告警行为不变。
- AppTask 传入的 mp3 URL 超过 5MiB 时，仅传前 2MiB 原始字节的 Base64；5MiB 内保持完整。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、配置来源和测试落点。
- 不允许把空对象、占位 DTO 或未赋值字段当成有效输入继续传递。
- 对跨层可变 DTO、调用后赋值、字段来源不明、旧逻辑副作用，必须先标记风险。
- 发现关键参数依赖后续步骤补齐时，优先在当前层现算现用，或改为显式请求对象；如果会改变业务语义，先确认。
- 任何会改变调用顺序、接口契约、远程调用、MQ 字段、Redis key、数据库结构或外部行为的方案，实施前必须确认业务意图。
- 单元测试不能只验证最终结果；涉及外部调用、MQ、FC、Feign、OTS、Redis 时，必须做下游参数断言，确认关键参数内容。

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：`retryCountNum` 来自输入 JSON，缺失时默认为 `0`。
- 赋值时机：失败调度前写入 `retryCountNum + 1`；重试执行开始时读取。
- 占位对象：本次不新增空对象、空 JSON 或空 Map。
- 下游读取：Gemini 调用链读取 `audioBase64`、`prompt` 和实现后显式传入的 `model`。
- 旧逻辑保持：限流、pic_id 限频、重试调度、飞书告警、callback、请求 body、token 来源和通用 `convertAudioToBase64` 保持不变。
- 影响范围：只影响音频 Gemini HTTP URL 中的模型名选择，以及 AppTask 专用 mp3 URL 转 Base64 前的大小裁剪。
- 测试映射：首轮和重试路径必须分别断言模型参数；mp3 大小必须覆盖小于、等于、超过阈值和 Content-Length 不可信路径。

## 重点代码位置

- `C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\AppTask.java`：`handleRequest`
- `C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\AppTask.java`：`callExternalGeminiApiAndExtractText`
- `C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\AppTask.java`：`callExternalGeminiApi`
- `C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\AppTask.java`：`convertAudioUrlToBase64`
- `C:\workspace\ju-chat\fc\Gemini-Api\src\test\java\com\drh\gemini\api\AppTaskRateLimitTest.java`：AppTask 行为单元测试
- `C:\workspace\ju-chat\fc\Gemini-Api\src\test\java\com\drh\gemini\api\AppTaskAudioLimitTest.java`：AppTask mp3 大小裁剪单元测试

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
