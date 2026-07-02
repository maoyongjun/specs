# 功能规格：Gemini AppTask 重试模型切换

**功能目录**：`115-gemini-app-task-retry-model`  
**创建日期**：`2026-07-02`  
**状态**：Draft  
**输入**：用户要求修改 `C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\AppTask.java`，重试的时候更换模型使用 `gemini-3.5-flash`；后续补充要求传入的 mp3 URL 超过 5M 时裁剪成 2M 以内。

## 背景

- 当前问题：`AppTask` 在首轮和重试执行中调用音频 Gemini API 时都固定使用 `gemini-3-pro`，无法在重试时切换到用户指定的模型。
- 当前行为：`handleRequest` 读取 `retryCountNum`，失败后写入 `retryCountNum + 1` 并通过 FC 延迟重试；音频 URL 通过 `convertAudioUrlToBase64(picUrl)` 转成 Base64 后传给 Gemini。补充需求前，AppTask 音频 URL 会全量下载后 Base64，超过 5MiB 的 mp3 不会裁剪。
- 目标行为：首轮执行继续使用现有模型；当输入中的 `retryCountNum > 0` 表示重试执行时，音频 Gemini API 使用 `gemini-3.5-flash`。AppTask 传入的 mp3 URL 超过 5MiB 时，只取前 2MiB 原始字节转 Base64；不超过 5MiB 时保持完整音频。
- 非目标：不修改视频/文件 URI 路径的 `callExternalGeminiApiWithMimeType`、`callExternalGeminiApiWithFileUri` 默认模型；不修改通用静态 `convertAudioToBase64` 的全量下载行为；不修改 FC 延迟重试、飞书告警、pic_id 限频、callback、Redis key、环境变量或请求体结构。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 重试时切换 Gemini 模型（优先级：P1）

当 AppTask 任务失败后由 FC 延迟再次触发，系统应使用 `gemini-3.5-flash` 重新请求 Gemini 音频分析，以提高重试路径的模型可用性。

**独立测试**：构造 `retryCountNum=1` 的 AppTask 输入，通过测试子类拦截 Gemini 调用参数，断言选择的模型为 `gemini-3.5-flash` 且不访问真实 HTTP。

**验收场景**：

1. **Given** 输入 `retryCountNum=1`，**When** `handleRequest` 执行到 Gemini 音频分析，**Then** 外部 Gemini API 的模型为 `gemini-3.5-flash`。
2. **Given** 输入缺失 `retryCountNum` 或 `retryCountNum=0`，**When** `handleRequest` 首轮执行 Gemini 音频分析，**Then** 仍使用现有首轮模型 `gemini-3-pro`。

### 用户故事 2 - 原有重试调度保持不变（优先级：P2）

模型切换只影响重试执行的 Gemini 模型选择，不改变失败后的重试次数递增、60 秒延迟提交、兜底延迟和失败回调逻辑。

**独立测试**：沿用现有 `AppTaskRateLimitTest` 中对重试/限流调用次数的断言，并补充模型选择测试，确认不新增真实外部调用。

**验收场景**：

1. **Given** Gemini 调用异常且 `retryCountNum + 1 < retryMaxCountNum`，**When** 进入 catch 分支，**Then** 仍写入 `retryCountNum + 1` 并调用原有 `retry(...)` 调度。

### 用户故事 3 - mp3 大文件裁剪（优先级：P1）

当 AppTask 接收到超过 5MiB 的 mp3 URL 时，系统应只把前 2MiB 原始字节转为 Base64 传给 Gemini，避免大音频直接进入 inlineData。

**独立测试**：使用内存 InputStream 模拟不同 Content-Length 和实际大小，不访问真实 URL，断言 Base64 解码后的原始字节长度。

**验收场景**：

1. **Given** mp3 实际大小小于或等于 5MiB，**When** AppTask 转 Base64，**Then** 返回完整音频内容。
2. **Given** `Content-Length > 5MiB`，**When** AppTask 转 Base64，**Then** 最多读取并返回前 2MiB 原始字节。
3. **Given** `Content-Length` 缺失或不可信且实际读取超过 5MiB，**When** AppTask 转 Base64，**Then** 返回前 2MiB 原始字节。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `retryCountNum`：来源 `handleRequest(JSONObject input, Context context)` 的输入 JSON 字段；方法开始处读取并默认置为 `0`；失败后在 catch 中写入 `retryCountNum + 1`，下次 FC 调用开始时读取。
  - `model`：应由当前层基于 `retryCountNum > 0` 现算现用；传入音频 Gemini 调用链；不得依赖后续流程补齐。
  - `audioBase64`：来源 `convertAudioUrlToBase64(picUrl)`；限流和 pic_id 检查通过后才转换；超过 5MiB 的 AppTask mp3 音频裁剪为前 2MiB 原始字节后再 Base64。
  - `contentLength`：来源 `URLConnection.getContentLengthLong()`；在读取 InputStream 前取得，用于提前判断是否超过 5MiB。
  - `prompt`：来源输入 JSON 字段 `prompt`；在调用 Gemini 前已读取。
- 下游读取字段清单：
  - `handleRequest` 读取 `retryCountNum`、`prompt`、`pic_url`、`callback_url`、`task_id`、`nick_name`、`union_id`、`pic_id`、`song_name`、`class_id`。
  - `callExternalGeminiApiAndExtractText` 当前读取 `audioBase64`、`prompt`，实现后还应读取显式 `model` 或通过封装方法取得模型。
  - `callExternalGeminiApi` 当前读取 `audioBase64`、`prompt`，实现后应读取 `model` 并拼接模型 URL。
  - `convertAppTaskMp3AudioToBase64` 读取 `InputStream`、`contentLength`、`audioUrl`，输出 Base64 字符串。
- 空对象 / 占位对象风险：
  - 本次不新增空 DTO、空 JSON 或空 Map。现有 `input` JSON 会在失败分支写入 `retryCountNum` 后传给 FC 延迟重试，保持原行为。
- 调用顺序风险：
  - 模型必须在 `callExternalGeminiApiAndExtractText` 前根据当前 `retryCountNum` 计算；不能在 Gemini 调用后再写入或依赖下一步补齐。
- 旧逻辑保持：
  - 保持限流在下载音频前执行。
  - 保持 pic_id 6 小时内最多 3 次检查。
  - 保持失败后 `retryCountNum + 1`、60 秒延迟重试、3300 秒兜底延迟、飞书告警和失败 callback 行为。
  - 保持首轮默认模型为 `gemini-3-pro`。
  - 保持通用 `convertAudioToBase64` 全量下载行为，避免影响视频任务和其他复用方。
  - 保持 `GEMINI_API_TOKEN`、baseUrl、请求 body、Authorization header 和超时参数不变。
- 需要用户确认的设计选择：
  - 无额外业务语义选择。本规格将“重试的时候”解释为输入 `retryCountNum > 0` 的重试执行，而不是同一次失败 catch 内立即再次调用 Gemini。

## 边界情况

- `retryCountNum` 缺失或为 `0`：按首轮处理，继续使用 `gemini-3-pro`。
- `retryCountNum > 0`：按重试执行处理，使用 `gemini-3.5-flash`。
- `retryCountNum` 为负数：沿用当前兼容口径，不额外抛错；按非重试处理，避免扩大行为。
- `pic_url` 为空：仍直接失败回调并返回，不触发模型选择。
- 限流导致 FC 延迟：仍在实际 Gemini 调用前返回；延迟后的实际执行再按输入 `retryCountNum` 选择模型。
- Gemini 远程调用失败：仍进入原有 catch 分支并按重试上限调度或失败回调。
- mp3 `Content-Length > 5MiB`：读取前 2MiB 后返回，不继续下载剩余内容。
- mp3 `Content-Length <= 5MiB` 或未知：边读边保留完整内容；实际读取超过 5MiB 时返回已缓存的前 2MiB。
- mp3 恰好 5MiB：不裁剪，返回完整音频。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 AppTask 音频 Gemini 调用前基于 `retryCountNum` 选择模型。
- **FR-002**：系统 MUST 在 `retryCountNum > 0` 时使用 `gemini-3.5-flash`。
- **FR-003**：系统 MUST 在 `retryCountNum` 缺失或为 `0` 时保持现有首轮模型 `gemini-3-pro`。
- **FR-004**：系统 MUST NOT 改变 FC 延迟重试、限流、pic_id 限频、callback、飞书告警、Redis key、环境变量和请求体结构。
- **FR-005**：单元测试 MUST 断言首轮和重试路径传入 Gemini 调用的模型值。
- **FR-006**：系统 MUST 在 AppTask mp3 音频超过 5MiB 时只将前 2MiB 原始字节转为 Base64。
- **FR-007**：系统 MUST 保持 5MiB 以内 AppTask mp3 音频完整传入。
- **FR-008**：系统 MUST NOT 修改通用 `convertAudioToBase64` 的全量下载行为。

## 成功标准 *(必填)*

- **SC-001**：`retryCountNum=1` 的测试输入最终选择 `gemini-3.5-flash`。
- **SC-002**：缺失 `retryCountNum` 或 `retryCountNum=0` 的测试输入仍选择 `gemini-3-pro`。
- **SC-003**：超过 5MiB 的 AppTask mp3 音频 Base64 解码后长度为 2MiB。
- **SC-004**：小于或等于 5MiB 的 AppTask mp3 音频 Base64 解码后长度保持原始长度。
- **SC-005**：目标模块相关单元测试通过，且不需要真实访问 Gemini、Redis、FC 或外部 HTTP。

## 假设

- 用户要求的 `gemini-3.5-flash` 是供应商代理支持的模型 ID，可直接用于现有 `/v1beta/models/{model}:generateContent` URL。
- “重试的时候”指延迟重试后的新一次 `handleRequest` 执行，判断条件为输入 JSON 中 `retryCountNum > 0`。
- “5M / 2M”按 MiB 处理，即 `5 * 1024 * 1024` 和 `2 * 1024 * 1024` 字节。
- mp3 裁剪采用前 2MiB 字节截断，不重新编码为完整 MP3 文件。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档：`C:\workspace\ju-chat\specs\115-gemini-app-task-retry-model`。
- 已完成代码事实确认：入口为 `AppTask.handleRequest`，核心调用为 `callExternalGeminiApiAndExtractText` / `callExternalGeminiApi`。
- 已完成历史问题防漏分析和 Phase 1 / Phase 2 门禁记录。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：在 `AppTask` 中新增首轮模型 `gemini-3-pro`、重试模型 `gemini-3.5-flash` 和 `selectAppTaskGeminiModel`；`handleRequest` 在 Gemini 音频调用前按 `retryCountNum > 0` 选择模型；`callExternalGeminiApiAndExtractText` / `callExternalGeminiApi` 新增显式模型参数重载并保持原两参方法兼容默认模型。
- 影响范围：仅影响 AppTask 音频 Gemini HTTP URL 的模型名；FC 延迟重试、限流、pic_id 限频、callback、飞书告警、Redis key、环境变量和请求体结构保持不变。
- 测试命令：`mvn -pl Gemini-Api -Dtest=AppTaskRateLimitTest test`（工作目录 `C:\workspace\ju-chat\fc`）。
- 测试结果：BUILD SUCCESS；`Tests run: 16, Failures: 0, Errors: 0, Skipped: 0`。
- 自检结论：首轮路径断言模型为 `gemini-3-pro`，`retryCountNum=1` 重试路径断言模型为 `gemini-3.5-flash`；未发现调用后赋值或占位对象风险。

### D003 - mp3 大文件裁剪补充记录

- 触发原因：用户补充要求“传入的 mp3 的 url 超过 5M 的裁剪成 2M 以内”。
- 修正内容：旧口径为 AppTask 音频 URL 全量下载后转 Base64；新口径为 AppTask 专用音频下载逻辑在 `Content-Length` 或实际读取超过 5MiB 时，只返回前 2MiB 原始字节的 Base64。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 验证结果：`mvn -pl Gemini-Api '-Dtest=AppTaskRateLimitTest,AppTaskAudioLimitTest' test` 通过；`Tests run: 21, Failures: 0, Errors: 0, Skipped: 0`。

### D004 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
