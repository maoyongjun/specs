# 功能规格：钢琴作业视频 V2 入口接入

**功能目录**：`101-piano-homework-video-v2-task`  
**创建日期**：`2026-06-18`  
**状态**：Draft  
**输入**：参考 `C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\PianoHomeWorkVideoTask.java`，新增入口类 `PianoHomeWorkVideoV2Task`；接入 `C:\workspace\ju-chat\gemini-video-recognition` 的实现；用户已确认不通过 jar 引入，采用源码迁移；默认 API key 使用用户提供的 `sk-...THDB7fz40`。

## 背景

- 当前问题：现有 `PianoHomeWorkVideoTask` 入口承载旧供应商、两个新供应商路由、动态权重、Redis 指标和重试逻辑；本次需要一个独立 V2 入口，走 `gemini-video-recognition` 的 OpenAI Proxy Gemini native 请求结构。
- 当前行为：旧入口读取 `requestPayload`、`prompt`、`file_url`、`cacheKey`、`dispatchLockKey`、`taskId`，写入 Redis 状态、调用旧/新供应商并返回解析后的文本，最后释放分发锁。
- 目标行为：新增 `PianoHomeWorkVideoV2Task`，保持 FC 入参兼容和缓存/锁语义，Gemini 请求改用从 `gemini-video-recognition` 源码迁移过来的 `GeminiProxyClient`、请求对象、响应对象、解析器和枚举。
- 非目标：不替换或删除旧 `PianoHomeWorkVideoTask`；不迁移 CLI、本地 mapping loader、批处理输出逻辑；不新增 jar 依赖；不调整现有旧供应商路由权重；不新增数据库、MQ 或对外 API。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 使用 V2 入口分析钢琴作业视频（优先级：P1）

调用方可以把原来传给钢琴视频分析 FC 的 `prompt` 和 `file_url` 传给 `PianoHomeWorkVideoV2Task`，V2 使用 `gemini-video-recognition` 的请求结构调用 Gemini Proxy，并返回模型文本结果。

**独立测试**：用 mock Gemini HTTP 服务或可注入调用器验证 V2 入口把 `prompt`、`file_url`、默认 baseUrl、model、authMode、fieldStyle、mimeType 和 API key 组装进 `GeminiProxyRequest`，并用 `GeminiResponseParser` 提取 `candidates[].content.parts[].text`。

**验收场景**：

1. **Given** 入参包含 `requestPayload.prompt` 和 `requestPayload.file_url`，**When** 调用 `PianoHomeWorkVideoV2Task.handleRequest`，**Then** 入口使用源码迁移的 Gemini Proxy 客户端发起请求并返回解析文本。
2. **Given** 入参没有外部配置 key，**When** 构建 V2 Gemini 配置，**Then** 使用用户提供的默认 key 作为兜底值，且日志和异常摘要不得输出完整 key。

### 用户故事 2 - 保持旧入口的异步状态语义（优先级：P1）

调用方仍可通过 `cacheKey` 和 `dispatchLockKey` 获得 RUNNING/SUCCESS/FAIL 状态和锁释放行为，避免异步任务状态管理回归。

**独立测试**：通过静态验证和可注入 Redis/cache 包装或最小行为测试确认 V2 在调用前写 RUNNING、成功后写 SUCCESS、异常后写 FAIL，finally 中释放 `dispatchLockKey`。

**验收场景**：

1. **Given** 入参包含 `cacheKey` 和 `taskId`，**When** V2 Gemini 调用成功，**Then** 缓存值包含 `status=SUCCESS`、`taskId`、`fileUrl`、`result` 和 `updatedAt`。
2. **Given** V2 Gemini 调用抛错且入参包含 `dispatchLockKey`，**When** 入口结束，**Then** 写入 FAIL 状态并释放该锁。

### 用户故事 3 - 支持源码迁移而非 jar 接入（优先级：P2）

构建 `fc/Gemini-Api` 时不依赖 `gemini-video-recognition` 的 jar 包，而是直接编译迁移后的源码，便于 FC 模块单独打包。

**独立测试**：运行 `mvn -pl Gemini-Api test` 或在 `fc/Gemini-Api` 下运行 focused test，确认新增源码在 Java 8 下可编译，且无需新增 `gemini-video-recognition` jar 依赖。

**验收场景**：

1. **Given** `fc/Gemini-Api/pom.xml` 不新增 `gemini-video-recognition` 依赖，**When** 执行测试或编译，**Then** V2 入口和迁移源码可通过编译。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `prompt`：来源 `input.requestPayload.prompt` 或 `input.prompt`；入口解析后、构建 `GeminiProxyRequest` 前赋值；下游读取位置 `GeminiProxyClient.validateCommon` 和请求 body 构造。
  - `file_url`：来源 `input.requestPayload.file_url` 或 `input.file_url`；入口解析后、fileUrl/inlineData 调用前赋值；下游读取位置 `GeminiProxyRequest.fileUri` 或 inline 下载转换逻辑。
  - `cacheKey`：来源入参；Gemini 调用前写 RUNNING，成功/失败后写终态；下游读取位置 Redis `setTokenWithExpire`。
  - `dispatchLockKey`：来源入参；finally 阶段释放；下游读取位置 Redis `deleteKey`。
  - `taskId`：来源入参；写缓存状态时使用；下游读取位置缓存 JSON。
  - `apiKey`：优先从 V2 环境变量解析，缺失时使用用户提供默认 key；构建请求前赋值；下游读取位置鉴权 header。
  - `baseUrl/model/authMode/fieldStyle/mimeType/inputMode`：来源 V2 环境变量或默认值；构建请求前赋值；下游读取位置 `GeminiProxyClient`。
- 下游读取字段清单：
  - `GeminiProxyClient.generateWithFileUrl` 读取 `baseUrl`、`apiVersion`、`model`、`apiKey`、`authMode`、`fieldStyle`、`mimeType`、`prompt`、`fileUri`。
  - `GeminiProxyClient.generateWithInlineData` 读取 `baseUrl`、`apiVersion`、`model`、`apiKey`、`authMode`、`mimeType`、`prompt`、`inlineData`。
  - `GeminiResponseParser.extractText` 读取 Gemini 原始响应中的 `candidates[].content.parts[].text`。
  - 缓存写入读取 `cacheKey`、`status`、`result`、`error`、`taskId`、`fileUrl`、`errorSource`、`errorStage`。
- 空对象 / 占位对象风险：
  - 不传递空 `GeminiProxyRequest`；构建前校验 `prompt`、`file_url`、`apiKey`、`baseUrl`、`model`。
  - 空 `input` 只作为兼容处理，但缺少关键字段时应进入 FAIL 或抛出明确异常，不能继续调用远程 Gemini。
- 调用顺序风险：
  - 必须先解析入参和配置，再写 RUNNING，再调用 Gemini，再写 SUCCESS/FAIL，最后释放锁。
  - 不允许调用 Gemini 后才补 `prompt`、`fileUri`、`apiKey` 或 `mimeType`。
- 旧逻辑保持：
  - `requestPayload` 包装兼容保持不变。
  - `cacheKey` 状态字段、30 分钟 TTL、`errorSource=ASYNC_TASK_FAIL`、`errorStage=piano_homework_video_task_analyze` 语义保持。
  - `dispatchLockKey` finally 释放保持。
  - 旧入口类不修改，旧供应商动态路由、指标 Redis key 和重试逻辑不受 V2 影响。
- 需要用户确认的设计选择：
  - 已确认接入方式为源码迁移，不使用 jar 依赖。
  - 默认 API key 将按用户要求写入 V2 代码作为兜底值；实现时会尽量通过环境变量优先生效，并在日志/异常中脱敏。

## 边界情况

- `input == null` 或 `requestPayload == null`：按空 JSON 兼容处理；缺少关键字段时抛出明确异常，若有 `cacheKey` 则写 FAIL。
- `prompt` 为空：不调用 Gemini，抛出 `prompt is empty` 类明确异常。
- `file_url` 为空：不调用 Gemini，抛出 `file_url is empty` 类明确异常。
- `inputMode` 非法：记录警告或抛出明确异常；计划优先复用 `InputMode.parse` 口径。
- Gemini HTTP 非 2xx：迁移的 `GeminiProxyApiException` 记录状态码和脱敏响应摘要；入口写 FAIL。
- 响应无文本：入口判定为空结果并失败，避免返回空成功。
- inlineData 模式：若实现自动下载远程 `file_url` 转 base64，应保留大小限制，默认值参考 `gemini-video-recognition` 的 20 MiB。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 新增 `com.drh.gemini.api.PianoHomeWorkVideoV2Task`，实现 `PojoRequestHandler<JSONObject, String>`。
- **FR-002**：系统 MUST 以源码迁移方式把 V2 所需的 `com.drh.gemini.video` 客户端类纳入 `fc/Gemini-Api` 编译范围，不新增 `gemini-video-recognition` jar 依赖。
- **FR-003**：系统 MUST 保持旧入口入参兼容：支持 `requestPayload`、`prompt`、`file_url`、`cacheKey`、`dispatchLockKey`、`taskId`。
- **FR-004**：系统 MUST 使用用户提供默认 API key 作为 V2 兜底 key，同时允许环境变量覆盖默认值。
- **FR-005**：系统 MUST 对完整 API key 做日志/异常脱敏，不能在运行日志中输出完整默认 key。
- **FR-006**：系统 MUST 保持缓存状态和锁释放语义，不改变旧入口行为。
- **FR-007**：系统 MUST NOT 修改旧 `PianoHomeWorkVideoTask` 的供应商路由、权重、Redis 指标、旧模型配置和重试逻辑。
- **FR-008**：单元测试 MUST 覆盖 V2 默认配置、入参兼容、请求参数构造、响应解析和 key 脱敏。

## 成功标准 *(必填)*

- **SC-001**：`fc/Gemini-Api` 测试或编译通过，且 `pom.xml` 不新增 `gemini-video-recognition` jar 依赖。
- **SC-002**：V2 正常路径能把入参 `prompt` 和 `file_url` 传入迁移后的 `GeminiProxyClient` 并返回解析文本。
- **SC-003**：异常路径能写 FAIL、释放锁，并且错误信息不包含完整 API key。
- **SC-004**：旧入口相关测试仍通过或至少不因本次新增入口产生编译回归。

## 假设

- V2 使用 `gemini-video-recognition` 默认 baseUrl `https://api.openai-proxy.org/google`、默认 model `gemini-3.1-pro-preview`、默认 authMode `X_GOOG_API_KEY`，除非环境变量覆盖。
- V2 不需要复用旧入口的三供应商动态路由；该入口是独立新路径。
- 源码迁移只迁移运行时必要类，不迁移 CLI、`.env` loader、mapping loader、本地批处理输出。
- 若后续要求 V2 完全复刻 CLI 的 `auto` fileUrl 失败后 inlineData fallback，需要在实施记录中明确下载大小限制和测试覆盖。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成历史问题防漏分析和强制门禁检查。
- 已根据用户补充将接入方式修正为源码迁移，不使用 jar 依赖。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 已完成源码迁移方式接入，不新增 jar 依赖。
- 已新增 `PianoHomeWorkVideoV2Task`，保持 `requestPayload`、`prompt`、`file_url`、`cacheKey`、`dispatchLockKey`、`taskId` 兼容。
- 已新增 V2 单元测试，覆盖默认配置、环境变量覆盖、fileUrl 请求、inlineData 请求、auto fallback、缓存状态、锁释放、缺少 prompt 和默认 key 脱敏。
- 验证结果：
  - `mvn -Dtest=PianoHomeWorkVideoV2TaskTest test`：5 tests，0 failures，BUILD SUCCESS。
  - `mvn '-Dtest=PianoHomeWorkVideoTaskRouteTest,PianoHomeWorkVideoV2TaskTest' test`：20 tests，0 failures，BUILD SUCCESS。
  - 静态搜索确认 `Gemini-Api` 未新增 `gemini-video-recognition` jar 依赖，完整默认 key 仅存在于 V2 默认常量。
- 剩余风险：
  - 未运行真实供应商集成测试，避免访问外部 Gemini/供应商接口。
  - 默认 key 按用户要求写入代码；运行时建议用环境变量覆盖以便后续轮换。

### D003 - 纠正记录模板

- 触发原因：用户补充、测试失败、代码审查发现、参数遗漏或调用顺序问题。
- 修正内容：写清楚旧口径和新口径。
- 文档同步：确认 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 是否已同步。
- 验证结果：记录测试或静态检查结果。
