# 功能规格：OpenAI Proxy Gemini 视频识别独立项目

**功能目录**：`055-openai-proxy-gemini-video-recognition`  
**创建日期**：`2026-06-05`  
**状态**：Implemented  
**输入**：在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档；在 `C:\workspace\ju-chat` 根目录创建独立项目，不放入 `fc`；仿照 `fc\Gemini-Api` 的 HTTP Gemini 视频识别方法，优先使用 `fileUrl`，其次使用 `file_data`/`inline_data` 内嵌数据方式；接入 `https://api.openai-proxy.org/google`，模型 `gemini-3.1-pro-preview`，密钥通过本机 `.env` 或环境变量注入；默认读取 `C:\workspace\video_file\video_prompt_mapping_v2.json` 第一条 prompt 和视频 URL。

## 背景

- 当前问题：需要独立验证 CloseAI/OpenAI Proxy 的 Gemini 视频识别能力，不能影响现有 FC 工程和 `fc\Gemini-Api`。
- 当前行为：`fc\Gemini-Api` 已有 `GeminiSupplierClient`，支持 `fileData.fileUri` 与 `inline_data` 两种视频输入。
- 目标行为：新增根级 Maven CLI 项目，默认读取 mapping 第一条，先用 URL 直传调用 Gemini，失败时用本地视频 base64 内嵌数据重试。
- 非目标：不实现 Gemini Files API 上传；不新增服务端 HTTP 接口；不修改数据库、MQ、Redis、FC 配置或现有业务模块。

## 已确认事实

- CloseAI Gemini 文档推荐原生 Gemini 协议，base URL 为 `https://api.openai-proxy.org/google`，并说明 OpenAI 兼容协议不作为本需求目标。
- Gemini 官方视频理解 REST 示例支持 `file_data.file_uri` 和 `inline_data.data`；现有 Java 参考项目使用 camelCase `fileData.fileUri`。
- mapping 第一条位于 `items[0]`，包含非空 `prompt`、`file_url`、`local_file`，本地视频约 2MB，适合 inline fallback。

## 用户场景与测试

### 用户故事 1 - 独立 CLI 调用 Gemini 视频识别（优先级：P1）

用户可以在 `C:\workspace\ju-chat\gemini-video-recognition` 中运行 CLI，调用 OpenAI Proxy Gemini 视频识别模型。

**独立测试**：使用 JDK mock HTTP server 执行 `mvn test`，断言请求 path、header、model、prompt、视频字段和响应解析。

**验收场景**：

1. **Given** `.env` 或环境变量中存在 `GEMINI_PROXY_API_KEY`，**When** 执行默认 CLI，**Then** 调用 `/v1beta/models/gemini-3.1-pro-preview:generateContent` 并写入结果文件。
2. **Given** 缺少 API key，**When** 执行 CLI，**Then** 立即失败且不发起外部 HTTP 请求。

### 用户故事 2 - 使用 mapping 第一条数据（优先级：P1）

用户要求使用 `C:\workspace\video_file\video_prompt_mapping_v2.json` 中第一条 prompt 和视频 URL，不手工复制长 prompt。

**独立测试**：读取 workspace mapping 的 `items[0]`，断言 `prompt`、`file_url`、`local_file`、`bytes` 有效。

**验收场景**：

1. **Given** mapping 文件存在且第一条字段完整，**When** CLI 使用默认参数，**Then** 请求体包含第一条 prompt 和 `file_url`。
2. **Given** mapping index 越界或关键字段缺失，**When** 加载 mapping，**Then** 抛出明确参数错误。

### 用户故事 3 - fileUrl 优先并 inline fallback（优先级：P1）

系统默认先用 `fileUrl` 调用，只有失败时才读取本地文件并内嵌 base64。

**独立测试**：mock 第一次 HTTP 返回失败，断言第二次请求包含 `inline_data.data`，同时输出结果不包含 base64。

**验收场景**：

1. **Given** `fileUrl` 调用成功，**When** `--input-mode=auto`，**Then** 不读取 inline 数据，结果标记 `inputModeUsed=fileUrl`。
2. **Given** `fileUrl` 调用失败且本地文件小于 20MB，**When** `--input-mode=auto`，**Then** 自动改用 `inline_data` 重试并记录 fallback 原因。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `mappingPath`：CLI `--mapping` 或默认路径；启动解析参数时赋值；loader 读取。
  - `index`：CLI `--index` 或默认 `0`；启动解析参数时赋值；loader 读取。
  - `prompt`：`items[index].prompt`；mapping 加载后赋值；HTTP client 写入 `contents[].parts[].text`。
  - `fileUrl`：`items[index].file_url`；mapping 加载后赋值；HTTP client 写入 `fileData.fileUri` 或 `file_data.file_uri`。
  - `localFile`：`items[index].local_file`；mapping 加载后赋值；仅 inline 路径读取文件。
  - `bytes`：`items[index].bytes`；mapping 加载后校验；inline 大小检查以本地文件实际大小为准。
  - `apiKey`：`.env` 或环境变量 `GEMINI_PROXY_API_KEY`；构造 client 前校验；HTTP header 写入，不进入结果文件。
  - `baseUrl`：CLI、`.env`、环境变量或默认 `https://api.openai-proxy.org/google`；构造 URL 前确定。
  - `model`：CLI、`.env`、环境变量或默认 `gemini-3.1-pro-preview`；构造 URL 前确定。
  - `inputMode`：CLI 或默认 `auto`；发起调用前确定。
  - `fieldStyle`：CLI 或默认 `camel`；构造 fileUrl body 前确定。
- 下游读取字段清单：
  - `VideoPromptMappingLoader.load` 读取 `items`、`prompt`、`file_url`、`local_file`、`bytes`、`messageId`、`taskId`、`lineNo`。
  - `GeminiProxyClient.generateWithFileUrl` 读取 `baseUrl`、`apiVersion`、`model`、`apiKey`、`authMode`、`fieldStyle`、`prompt`、`fileUri`、`mimeType`。
  - `GeminiProxyClient.generateWithInlineData` 读取 `inlineData`、`mimeType`、`prompt` 和同一组配置字段。
  - `GeminiResponseParser.extractText` 读取 `candidates[].content.parts[].text`。
- 空对象 / 占位对象风险：
  - 不允许空 key、空 prompt、空 file URL、空 local file 或空 inline data 继续下传；立即抛错。
- 调用顺序风险：
  - 先加载并校验 mapping，再构造请求；`auto` 模式只有 fileUrl 失败后才读取本地视频并构造 inline 请求。
- 旧逻辑保持：
  - 不修改 `fc\Gemini-Api`、`fc\pom.xml`、Redis、MQ、数据库或现有 FC 入口。
- 需要用户确认的设计选择：
  - 已确认：项目形态为 Java Maven CLI；输入来源为 mapping 第一条；密钥通过本机未跟踪 `.env`。

## 边界情况

- mapping 文件不存在：CLI 失败退出。
- `items` 缺失、为空或 index 越界：CLI 失败退出。
- `prompt`、`file_url`、`local_file` 缺失：CLI 失败退出。
- `GEMINI_PROXY_API_KEY` 缺失：CLI 失败退出，不发请求。
- HTTP 4xx/5xx：保留状态码和截断响应摘要；`auto` 模式可进入 inline fallback。
- inline 本地文件不存在或超过默认 20MB：CLI 失败退出，不发 inline 请求。
- 响应无 text：结果文件中 `parsedText` 为 null，原始响应仍保存。

## 需求

### 功能需求

- **FR-001**：系统 MUST 新建根级独立 Maven 项目 `gemini-video-recognition`。
- **FR-002**：系统 MUST 新建 `055-openai-proxy-gemini-video-recognition` Spec Kit 文档。
- **FR-003**：系统 MUST 默认使用 `https://api.openai-proxy.org/google`、`v1beta`、`gemini-3.1-pro-preview`。
- **FR-004**：系统 MUST 默认读取 `C:\workspace\video_file\video_prompt_mapping_v2.json` 的 `items[0]`。
- **FR-005**：系统 MUST 支持 `auto`、`fileUrl`、`inlineData` 三种输入模式，默认 `auto`。
- **FR-006**：系统 MUST 支持 `camel` 与 `snake` 两种 fileUrl 字段风格。
- **FR-007**：系统 MUST 通过 `.env` 或环境变量读取 API key，并忽略真实 `.env`。
- **FR-008**：系统 MUST NOT 将 API key 或 inline base64 写入源码、spec、测试资源或结果文件。
- **FR-009**：单元测试 MUST 断言外部 HTTP 下游参数，不只断言最终响应。

## 成功标准

- **SC-001**：`mvn test` 在 `gemini-video-recognition` 下通过。
- **SC-002**：`mvn package -DskipTests` 生成可执行 `target\gemini-video-recognition.jar`。
- **SC-003**：测试覆盖 mapping 第一条读取、fileUrl 请求、inline fallback、空 key、index 越界、过大 inline 文件和响应解析。
- **SC-004**：`fc` 目录未被本需求修改。

## 假设

- CloseAI `/google` 原生 Gemini 协议支持 `generateContent`。
- CloseAI 文档说明不支持 file 独立上传，因此本项目不实现 Files API。
- mapping 第一条本地视频存在且小于 20MB，可作为 inline fallback 输入。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成参数来源、下游读取字段、fallback 策略和不改 `fc` 的门禁记录。

### D002 - 实现记录

- 已新增根级 Maven CLI 项目 `gemini-video-recognition`。
- 已实现 mapping loader、Gemini HTTP client、响应 parser、CLI、`.env.example` 和项目 `.gitignore`。
- 已新增单元测试覆盖下游 HTTP 参数和 fallback 行为。

### D003 - 测试记录

- 测试命令：`mvn test`
- 测试结果：`Tests run: 14, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 打包命令：`mvn package -DskipTests`
- 打包结果：`BUILD SUCCESS`，生成 `C:\workspace\ju-chat\gemini-video-recognition\target\gemini-video-recognition.jar`。
- 安全检查：未在 `specs\055-openai-proxy-gemini-video-recognition` 或 `gemini-video-recognition` 中发现用户提供 key；未创建真实 `.env`。
- 旧逻辑检查：未修改 `fc\Gemini-Api` 或 `fc\pom.xml`；`fc` 中已有 unrelated dirty 文件未触碰。

### D004 - 真实联调记录

- 执行命令：临时设置 `GEMINI_PROXY_API_KEY` 后执行 `java -jar target\gemini-video-recognition.jar --input-mode=auto --output=target\gemini-video-recognition\real-result.json`。
- 执行结果：HTTP `200`，`durationMillis=36741`，`inputModeUsed=fileUrl`，未触发 inline fallback。
- 请求摘要：`baseUrl=https://api.openai-proxy.org/google`，`model=gemini-3.1-pro-preview`，`authMode=X_GOOG_API_KEY`，`fieldStyle=camel`，`promptLength=1799`。
- 输出文件：`C:\workspace\ju-chat\gemini-video-recognition\target\gemini-video-recognition\real-result.json`。
- 返回摘要：`parsedText` 长度 `598`，识别结果为作业视频，曲目 `四季歌`，置信度 `0.98`，主要问题为 `手型`，无需人工复核。
- 安全检查：结果文件未包含用户提供 key 前缀，且本次 fileUrl 成功未写入 inline base64。

### D005 - Prompt 模板更新记录

- 用户要求：不修改原 `C:\workspace\video_file\video_prompt_mapping.json`，另存新版 mapping，并把代码默认输入切到新版。
- 新文件：`C:\workspace\video_file\video_prompt_mapping_v2.json`。
- 更新内容：复制原 mapping 全量字段，仅替换 `items[*].prompt` 为新版识别提示词，并保留每条原始预置天数。
- 天数提取：优先从 `大概率是属于 D几 课程` 提取；取不到时从 `当前课程进度是：D几` 或 `大概率是今天 D几 的作业` 提取。
- 提取结果：D1=125、D2=39、D3=46、D4=3、D5=2，共 215 条，无缺失。
- 代码同步：`CliOptions.DEFAULT_MAPPING_PATH` 已改为 `C:\workspace\video_file\video_prompt_mapping_v2.json`。

### D006 - Runtime Context Prompt 更新记录

- 用户要求：继续使用 `video_prompt_mapping_v2.json`，把其中 `items[*].prompt` 换成 Runtime Context、Classification Priority、Diagnosis Rules、Confidence Rules 版本。
- 天数替换：仍从原始 `video_prompt_mapping.json` 中解析每条预置 D 几，替换模板中所有 `D%s` 位置。
- 提取结果：D1=125、D2=39、D3=46、D4=3、D5=2，共 215 条，无缺失。
- 模板版本：`prompt_template_version=v3-runtime-context-priority-rules`。
- 代码同步：默认 mapping 路径无需变化，仍为 `C:\workspace\video_file\video_prompt_mapping_v2.json`。
