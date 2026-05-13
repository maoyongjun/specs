# 功能规格：钢琴视频识别新供应商切流

**功能目录**: `014-piano-video-new-supplier-routing`  
**创建日期**: 2026-05-11  
**状态**: Implemented - Pending Supplier E2E  
**输入**: 用户要求将 `PianoHomeWorkVideoTask` 从旧 `newSupplierWeight` 二选一路由升级为 `supplierWeights` 三供应商权重路由；权重格式固定为 `旧供应商,新供应商1,新供应商2`，例如 `0.5,0,0.5`；`newSupplierWeight` 不再参与流量分配；新供应商2使用独立 `SUPPLIER2_BASE_URL/SUPPLIER2_API_KEY/SUPPLIER2_MODEL/SUPPLIER2_AUTH_MODE` 配置，默认 `baseUrl=https://api1132.xyz`、模型 `gemini-3-flash-preview`、鉴权 `X_GOOG_API_KEY`；运行时按最近 1 小时供应商成功率对基础权重做温和动态倾斜，提升整体成功率。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 按权重切换钢琴视频识别供应商（优先级：P1）

运营或研发需要在旧供应商、新供应商1、新供应商2之间按比例灰度钢琴视频识别。系统应通过环境变量 `supplierWeights` 控制三方初始流量比例，并在运行中参考最近 1 小时成功率，向成功率高的供应商温和倾斜；单次请求开始时选定供应商，后续重试保持同一供应商。

**独立测试**：分别配置 `supplierWeights=1,0,0`、`0,1,0`、`0,0,1`、`0.5,0,0.5`，调用 `PianoHomeWorkVideoTask#handleRequest` 多次，验证供应商选择符合权重策略；未配置、解析失败或全为 0 时，每次均调用旧供应商。

**验收场景**：

1. **Given** `supplierWeights=1,0,0`，**When** 发起钢琴视频识别，**Then** 系统只调用旧供应商接口。
2. **Given** `supplierWeights=0,1,0`，**When** 发起钢琴视频识别，**Then** 系统只调用新供应商1接口。
3. **Given** `supplierWeights=0,0,1`，**When** 发起钢琴视频识别，**Then** 系统只调用新供应商2接口。
4. **Given** `supplierWeights=0.5,0,0.5`，**When** 连续发起足够多请求，**Then** 旧供应商与新供应商2调用占比应接近 50%/50%，允许随机波动。
5. **Given** `supplierWeights` 未配置、解析失败或全为 0，**When** 发起钢琴视频识别，**Then** 系统按 `1,0,0` 处理并保持旧供应商行为。
6. **Given** 多个启用供应商存在最近 1 小时成功率差异，**When** 动态路由开启，**Then** 系统在基础权重上提高高成功率供应商的有效权重，降低低成功率供应商的有效权重。

### 用户故事 2 - 使用新供应商专用提示词做测试（优先级：P1）

研发需要在不影响旧供应商提示词的前提下，单独测试新供应商提示词。系统应在调用新供应商时优先读取 `resources/demo-prompt` 文件，对应仓库路径为 `fc/Gemini-Api/src/main/resources/demo-prompt`；该文件为空或读取失败时再使用入参 `prompt`。

**独立测试**：配置 `supplierWeights=0,1,0` 或 `0,0,1` 且 `resources/demo-prompt` 文件有内容，调用钢琴视频识别，拦截新供应商请求体，验证请求体使用该文件中的提示词；清空或模拟无法读取该文件后再次调用，验证回退使用入参 `prompt`。

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

- `newSupplierWeight` 已废弃，不再参与钢琴视频供应商流量分配。
- `supplierWeights` 格式固定为三个逗号分隔数字：旧供应商、新供应商1、新供应商2。
- `supplierWeights` 单项小于 0 按 0、大于 1 按 1；三项正数总和大于 0 时按总和归一化后随机分配。
- `supplierWeights` 未配置、解析失败、不是三段或全为 0 时，回退为 `1,0,0`，即全部旧供应商。
- `supplierWeights=1,0,0` 表示所有请求使用旧供应商；`0,1,0` 表示所有请求使用新供应商1；`0,0,1` 表示所有请求使用新供应商2。
- `supplierDynamicRoutingEnabled` 默认开启；配置为 `false`、`0`、`no` 或 `off` 时，仅使用静态 `supplierWeights`。
- 动态路由按供应商、按分钟在 Redis 中记录最终调用 `total/success`，统计最近 60 个分钟桶，Redis key TTL 为 2 小时。
- 动态调权使用 `effectiveWeight = baseWeight * (0.5 + smoothedSuccessRate)` 后归一化；没有历史数据时等价于原始 `supplierWeights`。
- 基础权重为 0 的供应商视为禁用，不做动态探测流量。
- 新供应商缺少必需 API key 时视为不可用，从有效路由权重中剔除；若所有启用供应商不可用，则回退旧供应商。
- 当前实现会在单次 `analyzeVideoWithRetry` 开始时选定供应商，同一次请求的后续重试保持同一供应商，避免跨供应商结果差异。
- 新供应商1默认 `baseUrl` 为 `https://ent.univibe.cc`。
- 新供应商2默认 `baseUrl` 为 `https://api1132.xyz`。
- 新供应商 `apiVersion` 固定为 `v1beta`。
- 新供应商默认模型为 `gemini-3-flash-preview`。
- 新供应商1配置：`GOOGLE_GEMINI_BASE_URL`、`GEMINI_API_KEY`、`GEMINI_MODEL`；当这些变量配置时，优先覆盖新供应商1默认 baseUrl、API key 和模型。
- 新供应商2配置：`SUPPLIER2_BASE_URL`、`SUPPLIER2_API_KEY`、`SUPPLIER2_MODEL`、`SUPPLIER2_AUTH_MODE`；当 `supplierWeights` 第三段大于 0 时，`SUPPLIER2_API_KEY` 必须配置。
- 人工测试默认使用代码内置 `baseUrl=https://api1132.xyz`、模型 `gemini-3-pro-preview`、固定视频 URL 和用户提供的测试密钥，不需要命令行传参。
- 新供应商调用形态应对齐旧 `callExternalGeminiApiWithFileUri`：提示词使用 text part，视频支持 `file_uri` / `mime_type=video/mp4` 直传，也支持下载后以 `inline_data` 内嵌数据传入。
- 旧供应商视频输入形态通过环境变量 `old_supplier_video_input_mode` 选择，支持 `inlineData` 和 `fileUrl`；未配置时默认 `inlineData`，保持原有行为。
- 新供应商1认证默认使用 `x-goog-api-key`，生产密钥通过 `GEMINI_API_KEY` 或 `new_supplier_api_key` 环境变量读取。
- 新供应商2认证默认使用 `x-goog-api-key`，可通过 `SUPPLIER2_AUTH_MODE=BEARER` 改为 Bearer 认证。
- 新供应商测试提示词只从 `resources/demo-prompt` 文件读取；该文件为空或读取失败时使用入参 `prompt`。
- `resources/demo-prompt` 对应实现路径为 `fc/Gemini-Api/src/main/resources/demo-prompt`，运行时可按 classpath resource `demo-prompt` 读取。
- 旧供应商调用继续使用现有环境变量和现有提示词逻辑。
- 日志可记录供应商名称、权重、选择结果、baseUrl、模型、响应长度和响应摘要，但不得记录密钥或完整请求体。
- 日志可记录最近 1 小时供应商 `success/total/rate`、基础权重、动态权重和最终选择供应商。
- 新供应商失败不应跳过 `finally` 中的 `releaseDispatchLock`。
- 供应商联调测试应独立为 JUnit 测试类，测试参数从 `src/test/resources/piano-video-supplier-test.properties` 读取；不再依赖 `PianoHomeWorkVideoTask.main` 传参，并且不读写 Redis 缓存。

## 需求 *(必填)*

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下维护本 Spec Kit 目录。
- **FR-002**：当前阶段 MUST 只编写文档，MUST NOT 修改业务代码。
- **FR-003**：实现 MUST 在 `PianoHomeWorkVideoTask.java` 中支持旧供应商、新供应商1、新供应商2三方路由。
- **FR-004**：两个新供应商 MUST 使用 Gemini 兼容 HTTP API 调用，`apiVersion=v1beta`，默认模型为 `gemini-3-flash-preview`。
- **FR-005**：系统 MUST 新增环境变量 `supplierWeights` 控制三供应商流量比例。
- **FR-006**：`supplierWeights` MUST 使用 `旧供应商,新供应商1,新供应商2` 三段数字格式。
- **FR-007**：`supplierWeights=1,0,0` 时，系统 MUST 全部使用旧供应商。
- **FR-008**：`supplierWeights=0,1,0` 时，系统 MUST 全部使用新供应商1。
- **FR-009**：`supplierWeights=0,0,1` 时，系统 MUST 全部使用新供应商2。
- **FR-009A**：`supplierWeights` 单项 MUST 先按 0 到 1 截断，再按正数总和归一化分配。
- **FR-009B**：`supplierWeights` 未配置、解析失败、不是三段或全为 0 时，系统 MUST 回退为 `1,0,0`。
- **FR-009C**：系统 MUST 支持 `supplierDynamicRoutingEnabled` 控制成功率动态路由，默认开启。
- **FR-009D**：动态路由开启时，系统 MUST 汇总最近 1 小时各供应商最终调用成功率。
- **FR-009E**：动态路由 MUST 基于 `supplierWeights` 做温和倾斜，基础权重为 0 的供应商不得参与分配。
- **FR-010**：系统 MUST 支持 `resources/demo-prompt` 文件作为新供应商测试提示词来源。
- **FR-011**：`resources/demo-prompt` 有内容且新供应商被选中时，系统 MUST 使用该文件内容作为请求提示词。
- **FR-012**：`resources/demo-prompt` 为空或读取失败且新供应商被选中时，系统 MUST 回退使用入参 `prompt`。
- **FR-013**：旧供应商请求 MUST NOT 被 `resources/demo-prompt` 覆盖。
- **FR-014**：生产新供应商密钥 MUST 通过环境变量注入；JUnit 联调测试 MAY 按本次要求在测试配置文件中写入测试密钥。
- **FR-015**：新供应商1密钥环境变量支持 `GEMINI_API_KEY` 或 `new_supplier_api_key`。
- **FR-016**：新供应商2 MUST 支持 `SUPPLIER2_BASE_URL/SUPPLIER2_API_KEY/SUPPLIER2_MODEL/SUPPLIER2_AUTH_MODE` 环境变量。
- **FR-016A**：当 `supplierWeights` 第三段大于 0 时，`SUPPLIER2_API_KEY` MUST 配置。
- **FR-016B**：新供应商2请求认证默认 SHOULD 使用 `x-goog-api-key`，并支持 `SUPPLIER2_AUTH_MODE=BEARER`。
- **FR-017**：新供应商请求体 MUST 与现有 Gemini 响应解析兼容。
- **FR-018**：新供应商成功响应 MUST 复用或等价使用现有 `extractTextFromResponse` 解析逻辑。
- **FR-019**：新供应商调用 MUST 纳入现有 `MAX_ANALYZE_ATTEMPTS` 重试控制。
- **FR-020**：新供应商返回空文本、可重试文案或异常时，系统 MUST 保持现有失败/重试/缓存状态语义。
- **FR-021**：系统 MUST 增加可检索日志，覆盖 `supplierWeights` 解析结果、供应商选择结果、新供应商 HTTP 状态和错误摘要。
- **FR-022**：系统 MUST NOT 在日志中输出新供应商明文密钥、Authorization header 或完整请求体。
- **FR-023**：系统 SHOULD 提供独立 JUnit 测试类，用于验证旧供应商、新供应商1、新供应商2的视频识别。
- **FR-024**：新供应商视频输入 MUST 支持 `file_uri` 形态，直接传入 `file_url`。
- **FR-025**：新供应商视频输入 MUST 支持 `inline_data` 形态，将测试视频下载并转为 base64 后内嵌传入。
- **FR-026**：系统 MUST 支持新增 Gemini 兼容供应商环境变量 `GOOGLE_GEMINI_BASE_URL/GEMINI_API_KEY/GEMINI_MODEL`，并优先于默认新供应商配置。
- **FR-027**：JUnit 测试配置 MUST 写入用户提供的测试密钥、视频 URL、`https://api1132.xyz` 和 `gemini-3-pro-preview`，执行测试时不要求 main 方法传参。
- **FR-028**：旧供应商 MUST 支持通过环境变量 `old_supplier_video_input_mode` 在 `inlineData` 和 `fileUrl` 两种视频输入模式之间切换，默认 `inlineData`。
- **FR-029**：所有供应商的 `fileUrl` 与 `inlineData` JUnit 联调用例失败后 MUST 间隔 1 秒重试，最多执行 10 次。
- **FR-030**：`newSupplierWeight` MUST 不再参与 `PianoHomeWorkVideoTask` 流量分配。
- **FR-031**：系统 MUST 在每次最终成功或最终失败后，为本次选中的供应商记录一次 Redis 指标。
- **FR-032**：成功指标 MUST 只在最终返回非空且非可重试失败文本时记录；中间重试失败但最终成功，记成功一次。
- **FR-033**：最终异常、空响应、重试耗尽或配置缺失导致调用失败时，MUST 对本次选中的供应商记失败一次。

## 成功标准 *(必填)*

- **SC-001**：本目录包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：本次变更包含 Spec Kit 文档、`PianoHomeWorkVideoTask.java`、`README-CONFIG.md` 和 `template.yml` 更新。
- **SC-003**：规格明确 `supplierWeights=1,0,0` 时全部使用旧供应商。
- **SC-004**：规格明确 `supplierWeights` 异常配置或全为 0 时保持旧供应商。
- **SC-005**：规格明确新供应商测试提示词可从 `resources/demo-prompt` 文件获取，并只影响新供应商。
- **SC-006**：规格明确新供应商 URL、认证方式假设、密钥环境变量和密钥脱敏要求。
- **SC-007**：`fc/Gemini-Api` 模块编译通过。
- **SC-008**：`PianoVideoSupplierIntegrationTest` 可通过 Maven 执行 fileUrl 直传和 inline_data 内嵌数据两种视频测试。
- **SC-009**：`PianoHomeWorkVideoTaskRouteTest` 覆盖动态权重、成功率窗口、零权重禁用和动态开关。

## 假设

- 新供应商接口兼容 Gemini `generateContent` 请求和响应结构。
- 新供应商1和新供应商2 API key 可通过 `x-goog-api-key` 方式认证；新供应商2也可按配置使用 Bearer token。
- 新供应商使用 `file_uri` 形态直接传视频 URL；旧供应商仍沿用下载后转 base64 的现有行为。
- 现有 `PianoHomeWorkVideoTask#analyzeVideoWithRetry` 的重试和缓存语义仍适用于新供应商。
- Redis 可用于记录供应商成功率分钟桶；如果 Redis 读取指标失败，动态路由回退为空历史数据，不阻断主流程。
- 生产部署仍建议通过环境变量注入密钥；本次按用户要求仅在 JUnit 测试配置文件中写入测试参数。
- 当前已完成编译和静态检查，尚未调用真实新供应商接口做端到端联调。
