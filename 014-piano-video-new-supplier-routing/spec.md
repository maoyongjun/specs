# 功能规格：钢琴视频识别新供应商切流

**功能目录**: `014-piano-video-new-supplier-routing`  
**创建日期**: 2026-05-11  
**状态**: Implemented - Pending Supplier E2E  
**输入**: 用户要求先在 `C:\workspace\ju-chat\specs` 新建 Spec Kit 并编写文档，不编码；后续在 `C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\PianoHomeWorkVideoTask.java` 中增加调用新供应商的方法；新供应商使用 Gemini 兼容 HTTP API，默认 `baseUrl=https://ent.univibe.cc`，`apiVersion=v1beta`，模型为 `gemini-3-flash-preview`；调用形态对齐旧 `callExternalGeminiApiWithFileUri`，使用视频 URL 作为 `file_uri`；增加环境变量 `newSupplierWeight`，取值 0 到 1，`1` 表示全部使用新供应商；新供应商提示词测试时从 `resources/demo-prompt` 文件获取；人工测试方法写入 `PianoHomeWorkVideoTask`；人工测试参数内置在代码中，并新增 `GOOGLE_GEMINI_BASE_URL/GEMINI_API_KEY/GEMINI_MODEL` 供应商配置。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 按权重切换钢琴视频识别供应商（优先级：P1）

运营或研发需要灰度验证新供应商的钢琴视频识别效果。系统应通过环境变量 `newSupplierWeight` 控制新供应商流量比例，并在 `newSupplierWeight=1` 时将所有钢琴视频识别请求切到新供应商。

**独立测试**：分别配置 `newSupplierWeight=0`、`0.5`、`1`，调用 `PianoHomeWorkVideoTask#handleRequest` 多次，验证供应商选择符合权重策略；当值为 `1` 时，每次均调用新供应商；当值为 `0` 或未配置时，每次均调用旧供应商。

**验收场景**：

1. **Given** `newSupplierWeight=1`，**When** 发起钢琴视频识别，**Then** 系统只调用新供应商接口。
2. **Given** `newSupplierWeight=0`，**When** 发起钢琴视频识别，**Then** 系统保持调用现有供应商接口。
3. **Given** `newSupplierWeight` 未配置或解析失败，**When** 发起钢琴视频识别，**Then** 系统按 `0` 处理并保持现有供应商行为。
4. **Given** `newSupplierWeight=0.5`，**When** 连续发起足够多请求，**Then** 新供应商调用占比应接近 50%，允许随机波动。

### 用户故事 2 - 使用新供应商专用提示词做测试（优先级：P1）

研发需要在不影响旧供应商提示词的前提下，单独测试新供应商提示词。系统应在调用新供应商时优先读取 `resources/demo-prompt` 文件，对应仓库路径为 `fc/Gemini-Api/src/main/resources/demo-prompt`；该文件为空或读取失败时再使用入参 `prompt`。

**独立测试**：配置 `newSupplierWeight=1` 且 `resources/demo-prompt` 文件有内容，调用钢琴视频识别，拦截新供应商请求体，验证请求体使用该文件中的提示词；清空或模拟无法读取该文件后再次调用，验证回退使用入参 `prompt`。

**验收场景**：

1. **Given** 新供应商被选中且 `resources/demo-prompt` 文件有内容，**When** 构造新供应商请求体，**Then** 文本提示词使用该文件内容。
2. **Given** 新供应商被选中且 `resources/demo-prompt` 文件为空或读取失败，**When** 构造新供应商请求体，**Then** 文本提示词使用入参 `prompt`。
3. **Given** 旧供应商被选中，**When** 构造旧供应商请求体，**Then** 不使用 `resources/demo-prompt` 覆盖旧供应商提示词。

### 用户故事 3 - 新供应商兼容现有结果解析、重试和缓存流程（优先级：P1）

钢琴视频识别入口已有重试、空结果判定、可重试文案判定、缓存状态写入和分布式锁释放逻辑。引入新供应商后，这些行为应保持一致，避免影响上游等待识别结果的流程。

**独立测试**：模拟新供应商返回标准 Gemini 响应、空文本、非 200、超时和命中可重试文案的响应，验证 `PianoHomeWorkVideoTask` 的返回值、异常、重试次数、缓存状态和日志符合现有流程。

**验收场景**：

1. **Given** 新供应商返回标准 Gemini 文本响应，**When** 系统解析响应，**Then** 返回 `candidates[0].content.parts[0].text`。
2. **Given** 新供应商返回空文本，**When** 系统处理响应，**Then** 按现有空响应错误处理并写入失败状态。
3. **Given** 新供应商返回命中现有 `RETRYABLE_RESPONSE_TEXTS` 的文本，**When** 当前尝试次数未超过上限，**Then** 按现有间隔重试。
4. **Given** 新供应商调用最终失败，**When** `cacheKey` 有值，**Then** 写入 `FAIL` 缓存状态并释放 `dispatchLockKey`。

### 用户故事 4 - 密钥通过环境变量管理（优先级：P1）

新供应商 API key 属于敏感信息，不能写入代码或文档。系统应通过环境变量读取密钥，部署时由运行环境注入用户提供的 key。

**独立测试**：确认生产路径优先读取 `GEMINI_API_KEY` 或 `new_supplier_api_key` 环境变量；运行时配置新供应商密钥环境变量后，新供应商请求认证信息正确设置；未配置密钥且非 JUnit 联调测试时，系统不打印密钥、不发送空凭据请求。

**验收场景**：

1. **Given** 新供应商被选中且新供应商密钥环境变量有值，**When** 发起 HTTP 请求，**Then** 使用该密钥构造认证信息。
2. **Given** 新供应商被选中但密钥环境变量为空，**When** 系统准备调用新供应商，**Then** 记录明确错误并进入现有失败或重试流程。
3. **Given** 系统输出日志，**When** 日志包含供应商调用上下文，**Then** 不出现明文 API key、Authorization header 或完整请求体。

## 边界情况

- 本规格当前只要求文档，不修改 `PianoHomeWorkVideoTask.java`、`AppTask.java` 或部署配置。
- 后续实现范围应优先限定在 `PianoHomeWorkVideoTask.java`；只有复用 HTTP 工具或配置模板必要时，才扩展到其他文件。
- `newSupplierWeight` 取值小于 0 时按 0 处理，大于 1 时按 1 处理；解析失败、空字符串或未配置时按 0 处理。
- `newSupplierWeight=1` 表示所有请求使用新供应商，不再调用旧供应商。
- `newSupplierWeight=0` 表示所有请求使用旧供应商，保持当前行为。
- `0 < newSupplierWeight < 1` 表示按请求随机切流；当前实现会在单次 `analyzeVideoWithRetry` 开始时选定供应商，同一次请求的后续重试保持同一供应商，避免跨供应商结果差异。
- 新供应商默认 `baseUrl` 为 `https://ent.univibe.cc`。
- 新供应商 `apiVersion` 固定为 `v1beta`。
- 新供应商默认模型为 `gemini-3-flash-preview`。
- 新增 Gemini 兼容供应商配置：`GOOGLE_GEMINI_BASE_URL`、`GEMINI_API_KEY`、`GEMINI_MODEL`；当这些变量配置时，优先使用该供应商覆盖默认 baseUrl、API key 和模型。
- 人工测试默认使用代码内置 `baseUrl=https://api1132.xyz`、模型 `gemini-3-pro-preview`、固定视频 URL 和用户提供的测试密钥，不需要命令行传参。
- 新供应商调用形态应对齐旧 `callExternalGeminiApiWithFileUri`：提示词使用 text part，视频支持 `file_uri` / `mime_type=video/mp4` 直传，也支持下载后以 `inline_data` 内嵌数据传入。
- 新供应商认证默认假设使用 `Authorization: Bearer <apiKey>`；如供应商联调要求其他 header，应更新本规格再实现。
- 生产新供应商密钥通过 `GEMINI_API_KEY` 或 `new_supplier_api_key` 环境变量读取；JUnit 联调测试按用户要求从测试配置文件读取测试密钥。
- 新供应商测试提示词只从 `resources/demo-prompt` 文件读取；该文件为空或读取失败时使用入参 `prompt`。
- `resources/demo-prompt` 对应实现路径为 `fc/Gemini-Api/src/main/resources/demo-prompt`，运行时可按 classpath resource `demo-prompt` 读取。
- 旧供应商调用继续使用现有环境变量和现有提示词逻辑。
- 日志可记录供应商名称、权重、选择结果、baseUrl、模型、响应长度和响应摘要，但不得记录密钥或完整请求体。
- 新供应商失败不应跳过 `finally` 中的 `releaseDispatchLock`。
- 供应商联调测试应独立为 JUnit 测试类，测试参数从 `src/test/resources/piano-video-supplier-test.properties` 读取；不再依赖 `PianoHomeWorkVideoTask.main` 传参，并且不读写 Redis 缓存。

## 需求 *(必填)*

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下维护本 Spec Kit 目录。
- **FR-002**：当前阶段 MUST 只编写文档，MUST NOT 修改业务代码。
- **FR-003**：后续实现 MUST 在 `PianoHomeWorkVideoTask.java` 中新增新供应商调用能力。
- **FR-004**：新供应商 MUST 使用 Gemini 兼容 HTTP API 调用，默认 `baseUrl=https://ent.univibe.cc`，`apiVersion=v1beta`，模型为 `gemini-3-flash-preview`。
- **FR-005**：系统 MUST 新增环境变量 `newSupplierWeight` 控制新供应商流量比例。
- **FR-006**：`newSupplierWeight` MUST 支持 0 到 1 的小数值。
- **FR-007**：`newSupplierWeight=1` 时，系统 MUST 全部使用新供应商。
- **FR-008**：`newSupplierWeight=0`、未配置或解析失败时，系统 MUST 保持全部使用旧供应商。
- **FR-009**：`0 < newSupplierWeight < 1` 时，系统 SHOULD 按权重随机选择供应商。
- **FR-010**：系统 MUST 支持 `resources/demo-prompt` 文件作为新供应商测试提示词来源。
- **FR-011**：`resources/demo-prompt` 有内容且新供应商被选中时，系统 MUST 使用该文件内容作为请求提示词。
- **FR-012**：`resources/demo-prompt` 为空或读取失败且新供应商被选中时，系统 MUST 回退使用入参 `prompt`。
- **FR-013**：旧供应商请求 MUST NOT 被 `resources/demo-prompt` 覆盖。
- **FR-014**：生产新供应商密钥 MUST 通过环境变量注入；JUnit 联调测试 MAY 按本次要求在测试配置文件中写入测试密钥。
- **FR-015**：新供应商密钥环境变量建议命名为 `new_supplier_api_key`。
- **FR-016**：新供应商请求认证 SHOULD 使用 `Authorization: Bearer <apiKey>`，除非供应商联调确认需要其他认证方式。
- **FR-017**：新供应商请求体 MUST 与现有 Gemini 响应解析兼容。
- **FR-018**：新供应商成功响应 MUST 复用或等价使用现有 `extractTextFromResponse` 解析逻辑。
- **FR-019**：新供应商调用 MUST 纳入现有 `MAX_ANALYZE_ATTEMPTS` 重试控制。
- **FR-020**：新供应商返回空文本、可重试文案或异常时，系统 MUST 保持现有失败/重试/缓存状态语义。
- **FR-021**：系统 MUST 增加可检索日志，覆盖 `newSupplierWeight` 解析结果、供应商选择结果、新供应商 HTTP 状态和错误摘要。
- **FR-022**：系统 MUST NOT 在日志中输出新供应商明文密钥、Authorization header 或完整请求体。
- **FR-023**：系统 SHOULD 提供独立 JUnit 测试类，用于验证旧供应商、新供应商1、新供应商2的视频识别。
- **FR-024**：新供应商视频输入 MUST 支持 `file_uri` 形态，直接传入 `file_url`。
- **FR-025**：新供应商视频输入 MUST 支持 `inline_data` 形态，将测试视频下载并转为 base64 后内嵌传入。
- **FR-026**：系统 MUST 支持新增 Gemini 兼容供应商环境变量 `GOOGLE_GEMINI_BASE_URL/GEMINI_API_KEY/GEMINI_MODEL`，并优先于默认新供应商配置。
- **FR-027**：JUnit 测试配置 MUST 写入用户提供的测试密钥、视频 URL、`https://api1132.xyz` 和 `gemini-3-pro-preview`，执行测试时不要求 main 方法传参。

## 成功标准 *(必填)*

- **SC-001**：本目录包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：本次变更包含 Spec Kit 文档、`PianoHomeWorkVideoTask.java`、`README-CONFIG.md` 和 `template.yml` 更新。
- **SC-003**：规格明确 `newSupplierWeight=1` 时全部使用新供应商。
- **SC-004**：规格明确 `newSupplierWeight=0` 或异常配置时保持旧供应商。
- **SC-005**：规格明确新供应商测试提示词可从 `resources/demo-prompt` 文件获取，并只影响新供应商。
- **SC-006**：规格明确新供应商 URL、认证方式假设、密钥环境变量和密钥脱敏要求。
- **SC-007**：`fc/Gemini-Api` 模块编译通过。
- **SC-008**：`PianoVideoSupplierIntegrationTest` 可通过 Maven 执行 fileUrl 直传和 inline_data 内嵌数据两种视频测试。

## 假设

- 新供应商接口兼容 Gemini `generateContent` 请求和响应结构。
- 新供应商 API key 可通过 Bearer token 方式认证；该假设需要后续联调验证。
- 新供应商使用 `file_uri` 形态直接传视频 URL；旧供应商仍沿用下载后转 base64 的现有行为。
- 现有 `PianoHomeWorkVideoTask#analyzeVideoWithRetry` 的重试和缓存语义仍适用于新供应商。
- 生产部署仍建议通过环境变量注入密钥；本次按用户要求仅在 JUnit 测试配置文件中写入测试参数。
- 当前已完成编译和静态检查，尚未调用真实新供应商接口做端到端联调。
