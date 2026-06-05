# 功能规格：VectorNode Gemini 视频识别项目

**功能目录**：`054-vectronode-gemini-video-recognition`  
**创建日期**：`2026-06-05`  
**状态**：Implemented（模块与单元测试已完成，真实验证结果见执行记录）  
**输入**：创建 Spec Kit 文档和独立项目，仿照 `C:\workspace\ju-chat\fc\Gemini-Api` 调用 Gemini 视频识别模型；使用 VectorNode Lab 文档页 `https://www.vectronode.com/lab?model=gemini-3-pro-preview`；读取 `C:\workspace\video_file\video_prompt_mapping.json` 第一条 prompt 和视频 URL；路由控制使用 `success_rate`。

## 背景

- 当前问题：需要独立验证 VectorNode 的 Gemini 视频识别能力，不能影响现有 `Gemini-Api` 线上函数。
- 当前行为：`fc\Gemini-Api` 已有 Gemini native HTTP 客户端，支持 `fileData.fileUri` 和 `inline_data` 视频输入。
- 目标行为：新增 `fc\gemini-video-recognition`，使用 VectorNode、`gemini-3-pro-preview` 和 mapping 第一条数据完成可复跑验证。
- 非目标：不修改线上 FC 入口，不新增数据库、MQ、Redis、外部业务接口，不把 API key 写入仓库。

## 已确认事实

- VectorNode Lab 页面为 SPA；其静态资源中确认：
  - `gemini-3-pro-preview` 为 Google Gemini 模型。
  - Gemini native endpoint 为 `/v1beta/models/{model}:generateContent`。
  - 鉴权头为 `Authorization: Bearer <your-token>`。
  - 路由取值包含 `price`、`speed`、`success_rate`。
  - `success_rate` 对应模型后缀 `:stable`，也支持 `provider.sort` 字段。
- mapping 第一条包含：
  - `file_url`：非空 HTTPS mp4 URL。
  - `local_file`：本地 mp4 文件路径。
  - `prompt`：非空，多行钢琴作业识别提示词。

## 用户场景与测试

### 用户故事 1 - 独立项目调用 VectorNode Gemini（优先级：P1）

用户可以在不改原 `Gemini-Api` 的前提下，通过独立 Maven 模块调用 VectorNode Gemini 视频识别。

**独立测试**：执行 `mvn -pl gemini-video-recognition test`，断言 HTTP 请求路径、header、model、prompt、视频 URL、mimeType 和路由字段。

**验收场景**：

1. **Given** `VECTRONODE_API_KEY` 已设置，**When** 执行 CLI 默认参数，**Then** 调用 `https://www.vectronode.com/v1beta/models/gemini-3-pro-preview:generateContent` 并保存结果。
2. **Given** `VECTRONODE_API_KEY` 为空，**When** 执行 CLI，**Then** 立即失败，不发起外部 HTTP 请求。

### 用户故事 2 - 使用 mapping 第一条数据验证视频识别（优先级：P1）

用户要求验证指定视频和提示词，项目必须从 mapping 中读取，不手工复制长 prompt。

**独立测试**：读取 `items[0]` 并断言 `prompt`、`file_url`、`local_file` 非空。

**验收场景**：

1. **Given** mapping 文件存在且 `items[0]` 字段完整，**When** CLI 使用默认参数，**Then** 请求体包含该 prompt 和 `fileData.fileUri`。
2. **Given** mapping 缺少 prompt 或 file URL，**When** 加载数据，**Then** 抛出明确参数错误。

### 用户故事 3 - success_rate 路由控制（优先级：P1）

用户要求路由控制使用 `success_rate`，实现必须优先按请求字段控制，并保留模型后缀兼容路径。

**独立测试**：mock HTTP server 断言请求体包含 `provider.sort=success_rate`；另测 `MODEL_SUFFIX` 时请求模型变为 `gemini-3-pro-preview:stable`。

**验收场景**：

1. **Given** 路由模式为 `provider_sort`，**When** 构造请求，**Then** body 包含 `"provider":{"sort":"success_rate"}`。
2. **Given** provider 字段被 native endpoint 拒绝，**When** CLI 开启默认 fallback，**Then** 自动重试 `gemini-3-pro-preview:stable` 并记录 fallback 原因。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `mappingPath`：CLI `--mapping` 或默认路径；程序启动解析参数时赋值；mapping loader 读取。
  - `index`：CLI `--index` 或默认 `0`；程序启动解析参数时赋值；mapping loader 读取。
  - `prompt`：`items[index].prompt`；加载 mapping 后赋值；HTTP client 写入 `contents[0].parts[0].text`。
  - `fileUri`：`items[index].file_url`；加载 mapping 后赋值；HTTP client 写入 `fileData.fileUri`。
  - `apiKey`：`VECTRONODE_API_KEY`；构造 client 前校验；HTTP client 写入 Authorization header。
  - `routingPriority`：CLI 或 `VECTRONODE_ROUTING_PRIORITY`，默认 `success_rate`；构造请求前赋值；HTTP client 写入 `provider.sort` 或模型后缀。
- 下游读取字段清单：
  - `VideoPromptMappingLoader.load` 读取 `items`、`prompt`、`file_url`、`local_file`、`messageId`、`taskId`、`lineNo`、`bytes`。
  - `VectorNodeGeminiClient.generateWithFileUri` 读取 `model`、`fileUri`、`mimeType`、`prompt`、`routingMode`、`routingPriority`。
  - `GeminiResponseParser.extractText` 读取 `candidates[0].content.parts[*].text`。
- 空对象 / 占位对象风险：
  - 不允许空 apiKey、空 prompt、空 fileUri 或空 inlineData 继续下传；当前实现会立即抛错。
- 调用顺序风险：
  - 先完成 mapping 字段校验，再创建请求体；外部调用完成后才解析响应；结果保存不包含 API key。
- 旧逻辑保持：
  - `fc\Gemini-Api` 代码不变。
  - 现有 FC 父工程模块不改业务顺序，只新增 `gemini-video-recognition` module。
- 需要用户确认的设计选择：
  - 已由用户确认：接口文档使用 VectorNode Lab；路由控制使用 `success_rate`。

## 边界情况

- mapping 文件不存在：CLI 失败退出。
- index 越界：CLI 失败退出。
- `prompt` 缺失：CLI 失败退出。
- `file_url` 缺失：CLI 失败退出。
- `VECTRONODE_API_KEY` 缺失：CLI 失败退出，不发请求。
- HTTP 4xx/5xx：抛出 `VectorNodeApiException`，保留状态码和响应摘要。
- `provider.sort` 被拒绝：默认只在 400/422 且响应指向 provider/sort/unknown field 时 fallback 到 `:stable`。
- 响应无 text：结果文件中 `parsedText` 为 null，测试覆盖该解析路径。

## 需求

### 功能需求

- **FR-001**：系统 MUST 新建独立 Maven 子模块 `fc\gemini-video-recognition`。
- **FR-002**：系统 MUST 使用 `Authorization: Bearer <token>` 调用 VectorNode。
- **FR-003**：系统 MUST 默认调用 `/v1beta/models/{model}:generateContent`。
- **FR-004**：系统 MUST 从 mapping 第一条读取 prompt 和视频 URL。
- **FR-005**：系统 MUST 默认使用 `provider.sort=success_rate`。
- **FR-006**：系统 MUST 支持 `success_rate -> :stable` 模型后缀兼容验证。
- **FR-007**：系统 MUST 保存原始响应、解析文本、请求摘要、耗时和路由模式到 `target` 下。
- **FR-008**：系统 MUST NOT 将 API key 写入源码、测试资源、Spec Kit 文档或结果文件。
- **FR-009**：测试 MUST 断言外部 HTTP 下游参数，不只断言最终响应。

## 成功标准

- **SC-001**：`mvn -pl gemini-video-recognition test` 通过，且测试覆盖请求体和鉴权 header。
- **SC-002**：CLI 能读取 `C:\workspace\video_file\video_prompt_mapping.json` 的 `items[0]`。
- **SC-003**：真实验证产生 `target\vectronode-video-recognition\result.json`，且不包含 API key。
- **SC-004**：原 `fc\Gemini-Api` 未被修改。

## 假设

- VectorNode Gemini native endpoint 接受 Gemini REST `contents.parts.fileData.fileUri` 格式。
- VectorNode 对 `provider.sort=success_rate` 与模型后缀 `:stable` 语义等价；若 native endpoint 不接受 `provider` 字段，后缀形式作为兼容路径。
- 真实验证会消耗用户提供 token 的额度。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已确认接口文档页、模型、鉴权和路由口径。
- 已确认 API key 不写入文件。

### D002 - 实现记录

- 新增 `fc\gemini-video-recognition` Maven 模块。
- 新增 mapping loader、Gemini native HTTP client、响应 parser 和 CLI。
- 修改 `fc\pom.xml`，加入 `gemini-video-recognition` module。
- 未修改 `fc\Gemini-Api`。

### D003 - 测试记录

- 测试命令：`mvn -pl gemini-video-recognition test`
- 测试结果：`Tests run: 10, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 覆盖内容：mapping 读取、workspace 第一条读取、HTTP 请求路径/header/body、`provider.sort=success_rate`、`:stable` 后缀、HTTP 失败、响应 text 解析。

### D004 - 真实验证记录

- 打包命令：`mvn -pl gemini-video-recognition package -DskipTests`
- 打包结果：`BUILD SUCCESS`，生成 `C:\workspace\ju-chat\fc\gemini-video-recognition\target\gemini-video-recognition.jar`。
- CLI 验证命令：临时设置 `VECTRONODE_API_KEY` 后执行 `java -jar target\gemini-video-recognition.jar --output=target\vectronode-video-recognition\result.json`。
- 验证结果：HTTP `200`，`routingMode=PROVIDER_SORT`，`routingPriority=success_rate`，`requestModel=gemini-3-pro-preview`，未触发 fallback。
- 输出文件：`C:\workspace\ju-chat\fc\gemini-video-recognition\target\vectronode-video-recognition\result.json`。
- 响应摘要：`parsedText` 长度 `1122`，调用耗时约 `56601 ms`，mapping 第一条 prompt 长度 `1799`。
- 安全检查：搜索源码、文档和结果文件，未发现用户提供 API key 或环境变量携带明文 key 的写法。

### D005 - 纠正记录模板

- 触发原因：用户补充、接口失败、路由口径变化、模型名变化或测试失败。
- 修正内容：写清旧口径和新口径。
- 文档同步：说明 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 是否已同步。
- 验证结果：记录测试或真实验证结果。
