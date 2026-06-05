# 规格执行说明

本目录记录“VectorNode Gemini 视频识别验证项目”的 Spec Kit 文档。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\054-vectronode-gemini-video-recognition`
- 目标项目：`C:\workspace\ju-chat\fc`
- 新增模块：`C:\workspace\ju-chat\fc\gemini-video-recognition`
- 参考项目：`C:\workspace\ju-chat\fc\Gemini-Api`
- 验证数据：`C:\workspace\video_file\video_prompt_mapping.json` 的 `items[0]`

## 当前目标

- 新建独立 Maven 项目，仿照 `Gemini-Api` 的 Gemini native HTTP 调用方式。
- 接入 VectorNode：`https://www.vectronode.com`，模型 `gemini-3-pro-preview`。
- 使用第一条视频 URL 和 prompt 真实验证视频识别。
- 路由控制默认使用 `success_rate`，主方式为 `provider.sort`，兼容方式为模型后缀 `:stable`。

## 执行原则

- 不修改 `fc\Gemini-Api` 的线上函数逻辑。
- API key 只从 `VECTRONODE_API_KEY` 环境变量读取，不写入源码、测试资源、Spec Kit 文档或日志。
- 请求必须使用 `Authorization: Bearer <token>`。
- 默认使用 `fileData.fileUri` 直传视频 URL；`inline_data` 只作为兼容验证模式。
- 外部 HTTP 单元测试必须断言请求路径、鉴权头、模型、prompt、视频 URL、mimeType 和路由字段。
- 真实联调结果只记录状态、耗时、路由模式、响应文本长度和结果文件位置，不记录完整 key。

## 强制门禁

- 参数来源：
  - `baseUrl`：CLI 或 `VECTRONODE_BASE_URL`，默认 `https://www.vectronode.com`。
  - `model`：CLI 或 `VECTRONODE_MODEL`，默认 `gemini-3-pro-preview`。
  - `apiKey`：`VECTRONODE_API_KEY` 或 CLI 临时参数；禁止写入文件。
  - `routingPriority`：CLI 或 `VECTRONODE_ROUTING_PRIORITY`，默认 `success_rate`。
  - `prompt` / `file_url`：mapping 文件 `items[index]`。
- 下游读取：
  - HTTP client 读取 `baseUrl`、`apiVersion`、`model`、`apiKey`、`prompt`、`fileUri`、`routingMode`、`routingPriority`。
- 占位对象：
  - prompt、file URL、apiKey 缺失时立即失败，不构造空请求。
- 调用顺序：
  - 先读取 mapping 并校验必填字段，再构造请求体，再调用外部 HTTP，再解析响应文本并保存结果。
- 旧逻辑保持：
  - 原 `Gemini-Api` 不变；父工程只新增 module 引用。

## 重点代码位置

- CLI：`C:\workspace\ju-chat\fc\gemini-video-recognition\src\main\java\com\drh\vectronode\gemini\VectorNodeVideoRecognitionCli.java`
- HTTP client：`C:\workspace\ju-chat\fc\gemini-video-recognition\src\main\java\com\drh\vectronode\gemini\VectorNodeGeminiClient.java`
- 测试：`C:\workspace\ju-chat\fc\gemini-video-recognition\src\test\java\com\drh\vectronode\gemini`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务和验证任务。
- `checklists/requirements.md` 验证规格质量和参数完整性。
- 后续若调整接口形态、路由策略或模型名，必须同步更新本目录全部相关文档。
