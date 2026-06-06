# 规格执行说明

本目录记录 OpenAI Proxy / CloseAI Gemini 视频识别独立项目的规格、任务和验证结果。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\055-openai-proxy-gemini-video-recognition`
- 目标项目：`C:\workspace\ju-chat\gemini-video-recognition`
- 相关参考：`C:\workspace\ju-chat\fc\Gemini-Api`

## 当前目标

- 在 `C:\workspace\ju-chat` 根目录创建独立 Maven CLI 项目，不进入 `fc`。
- 默认读取 `C:\workspace\video_file\video_prompt_mapping_v2.json` 的 `items[0]`。
- 使用 CloseAI Gemini 原生协议调用 `gemini-3.1-pro-preview` 视频理解，优先 `fileUrl`，失败后使用本地视频 `inline_data` fallback。

## 执行原则

- 不修改 `fc\Gemini-Api`、`fc\pom.xml` 或任何 FC 业务模块。
- 不把真实 API key 写入源码、spec、测试资源、README 或结果文件。
- `.env` 只作为本机运行时配置文件，必须被项目 `.gitignore` 忽略；仓库内只提交 `.env.example`。
- 外部 HTTP 调用必须有单元测试断言请求路径、鉴权 header、model、prompt、视频字段和 fallback 行为。
- `fileUrl` 请求默认使用 `fileData.mimeType/fileUri`，可通过 `--field-style=snake` 使用 `file_data.mime_type/file_uri`。
- `inlineData` 请求使用官方 REST 兼容的 `inline_data.mime_type/data`。

## 强制门禁

- `mappingPath`、`index`、`prompt`、`file_url`、`local_file`、`bytes`、`apiKey`、`baseUrl`、`model`、`inputMode`、`fieldStyle` 必须在发起 HTTP 前确定。
- 缺少 key、prompt、file URL 或 mapping index 越界时立即失败，不发起 HTTP。
- `auto` 模式只在 fileUrl 调用失败后读取本地文件并转 base64；成功时不读取 inline 数据。
- inline fallback 必须检查本地文件大小，默认上限 20MB。
- 输出结果必须排除 API key 和 inline base64。

## 重点代码位置

- CLI 入口：`C:\workspace\ju-chat\gemini-video-recognition\src\main\java\com\drh\gemini\video\GeminiVideoCli.java`
- HTTP 客户端：`C:\workspace\ju-chat\gemini-video-recognition\src\main\java\com\drh\gemini\video\GeminiProxyClient.java`
- Mapping loader：`C:\workspace\ju-chat\gemini-video-recognition\src\main\java\com\drh\gemini\video\VideoPromptMappingLoader.java`
- 测试目录：`C:\workspace\ju-chat\gemini-video-recognition\src\test\java\com\drh\gemini\video`

## 文档维护

- `spec.md` 描述需求、边界、成功标准和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务和测试结果。
- `checklists/requirements.md` 验证规格质量和参数完整性。
- 若接口口径、字段风格或 fallback 策略变化，必须同步更新本目录所有相关文档。
