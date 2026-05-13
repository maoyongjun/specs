# 任务清单：钢琴视频识别新供应商切流

**输入**：来自 `specs/014-piano-video-new-supplier-routing/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：已完成模块编译和静态验证；真实新供应商联调待部署环境执行。  

## Phase 1：规格与范围

- [x] T001 创建 Spec Kit 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确当前阶段只编写文档，不修改业务代码
- [x] T003 明确目标文件为 `PianoHomeWorkVideoTask.java`
- [x] T004 明确新供应商接口地址
- [x] T005 明确 `newSupplierWeight` 的取值范围和路由含义
- [x] T006 明确 `resources/demo-prompt` 文件仅用于新供应商测试提示词
- [x] T007 明确 API key 不落入文档和代码，后续通过环境变量注入

## Phase 2：后续实现

- [x] T008 在 `PianoHomeWorkVideoTask.java` 中新增读取并解析 `newSupplierWeight` 的辅助逻辑
- [x] T009 对 `newSupplierWeight` 做容错处理：未配置、空值、解析失败按 0；小于 0 按 0；大于 1 按 1
- [x] T010 在 `analyzeVideoWithRetry` 开始时按权重为本次请求选择供应商，并在重试中保持同一供应商
- [x] T011 实现 `newSupplierWeight=1` 时全部走新供应商
- [x] T012 实现 `newSupplierWeight=0` 时全部保持现有供应商
- [x] T013 实现 `0 < newSupplierWeight < 1` 时按请求随机切流
- [x] T014 新增新供应商 API key 环境变量读取逻辑，变量名 `new_supplier_api_key`
- [x] T015 新增新供应商提示词解析逻辑：优先读取 `resources/demo-prompt`，文件为空或读取失败时回退入参 `prompt`
- [x] T016 在 `PianoHomeWorkVideoTask.java` 中新增新供应商调用方法
- [x] T017 新供应商调用方法使用 Gemini 兼容 HTTP API，默认 `baseUrl=https://ent.univibe.cc`，`apiVersion=v1beta`，模型 `gemini-3-flash-preview`
- [x] T018 新供应商请求体对齐旧 `callExternalGeminiApiWithFileUri` 形态，视频以 `file_uri`、`mime_type=video/mp4` 传入
- [x] T019 新供应商认证默认使用 `Authorization: Bearer <apiKey>`
- [x] T020 新供应商响应复用现有 `extractTextFromResponse(AppTask.clearJSON(rawResponse))` 解析逻辑
- [x] T021 新供应商失败、空响应、可重试响应纳入现有 `MAX_ANALYZE_ATTEMPTS` 重试流程
- [x] T022 保持现有缓存 `RUNNING`、`SUCCESS`、`FAIL` 写入语义
- [x] T023 保持 `finally` 中释放 `dispatchLockKey` 的行为不变
- [x] T024 增加供应商选择、权重解析、新供应商状态码和错误摘要日志
- [x] T025 确保日志不打印明文 API key、Authorization header 或完整请求体
- [x] T026 如部署模板由仓库维护，则在配置文档或模板中补充 `newSupplierWeight` 和新供应商密钥变量，并确认 `resources/demo-prompt` 被打入函数包
- [x] T026A 新增独立 JUnit 供应商联调测试入口

## Phase 3：后续验证

- [x] T027 验证 `newSupplierWeight` 未配置时仍全部使用旧供应商
- [x] T028 验证 `newSupplierWeight=0` 时仍全部使用旧供应商
- [x] T029 验证 `newSupplierWeight=1` 时全部使用新供应商
- [x] T030 验证 `newSupplierWeight=0.5` 时多次调用的新供应商比例接近 50%
- [x] T031 验证 `resources/demo-prompt` 有内容时，新供应商请求使用该文件提示词
- [x] T032 验证 `resources/demo-prompt` 为空或读取失败时，新供应商请求回退入参 `prompt`
- [x] T033 验证旧供应商请求不受 `resources/demo-prompt` 影响
- [x] T034 验证新供应商标准响应可解析为文本结果
- [x] T035 验证新供应商空文本进入现有失败/重试流程
- [x] T036 验证新供应商非 200、超时或网络异常进入现有失败/重试流程
- [x] T037 验证新供应商最终失败时写入 `FAIL` 缓存状态
- [x] T038 验证成功或失败后均释放 `dispatchLockKey`
- [x] T039 确认生产路径继续优先从环境变量读取 API key；JUnit 测试路径按用户要求从测试配置文件读取 key
- [x] T040 编译 `fc/Gemini-Api` 模块
- [ ] T041 与新供应商做至少一次联调，确认认证 header、请求体和响应结构
- [x] T042 记录验证结果和剩余风险
- [x] T043 新增 Gemini 兼容供应商环境变量 `GOOGLE_GEMINI_BASE_URL/GEMINI_API_KEY/GEMINI_MODEL`
- [x] T044 将人工测试密钥、视频 URL、baseUrl、model 和 prompt 写入代码，测试时不需要传参
- [x] T045 JUnit 测试入口支持旧供应商、新供应商1、新供应商2的 fileUrl 直传和 inline_data 内嵌数据验证

## 执行记录

### D001 - 文档记录

- 已按用户要求创建 Spec Kit 文档。
- 当前阶段未修改 `PianoHomeWorkVideoTask.java` 或任何业务代码。
- 已记录新供应商接口地址、权重环境变量、测试提示词资源文件、密钥环境变量建议和脱敏要求。
- 已记录后续实现任务和验证任务。
- 为避免泄露敏感信息，文档未写入用户提供的明文 API key。

### D002 - 实现记录

- `PianoHomeWorkVideoTask` 新增 `newSupplierWeight` 解析逻辑，异常配置按 0 处理，小于 0 归 0，大于 1 归 1。
- `PianoHomeWorkVideoTask` 在单次 `analyzeVideoWithRetry` 开始时按权重选择供应商，并在本次重试中保持同一供应商。
- 新增新供应商调用方法，使用 Gemini 兼容 HTTP API，默认 `baseUrl=https://ent.univibe.cc`，`apiVersion=v1beta`，模型为 `gemini-3-flash-preview`。
- 新供应商生产 API key 从环境变量 `new_supplier_api_key` 读取；JUnit 测试路径按用户要求从测试配置文件读取测试 key。
- 新供应商被选中时优先读取 classpath resource `demo-prompt`，为空或读取失败时回退入参 `prompt`。
- 新供应商输入对齐 `callExternalGeminiApiWithFileUri`，使用 `text + file_uri` 结构。
- 新供应商响应复用 `AppTask#extractTextFromResponse(AppTask.clearJSON(rawResponse))` 解析。
- 新供应商异常、空文本和可重试文案纳入最多 3 次重试。
- `template.yml` 新增 `newSupplierWeight` 和 `new_supplier_api_key` 占位变量。
- `README-CONFIG.md` 补充新供应商环境变量和 `demo-prompt` 资源说明。

### D003 - 验证记录

- 执行命令：`mvn -q -DskipTests compile`
- 执行目录：`C:\workspace\ju-chat\fc\Gemini-Api`
- 执行结果：编译通过。
- 静态检查确认 `newSupplierWeight=0` 或未配置时走现有供应商。
- 静态检查确认 `newSupplierWeight=1` 时走新供应商。
- 静态检查确认 `0 < newSupplierWeight < 1` 时按请求随机选择供应商。
- 静态检查确认新供应商提示词优先读取 `src/main/resources/demo-prompt`。
- 静态检查确认生产调用优先读取环境变量；人工测试参数按用户要求内置在代码中。
- 剩余风险：未调用真实新供应商接口做端到端联调；认证方式、模型响应和供应商错误格式仍需部署环境验证。

### D004 - 模型与早期人工测试入口调整

- 按用户要求将新供应商模型从 `gemini-3.1-pro-preview` 改为 `gemini-3-flash-preview`。
- `PianoHomeWorkVideoTask` 曾新增 `main/testNewSupplierVideoAnalysis` 人工测试入口，现已由独立 JUnit 测试替代。
- 该人工测试入口现已由独立 JUnit 联调测试替代；测试参数改为从测试配置文件读取，不读写 Redis 缓存。
- 执行命令：`mvn -q -DskipTests compile`
- 执行目录：`C:\workspace\ju-chat\fc\Gemini-Api`
- 执行结果：编译通过。
- 使用 `gemini-3-flash-preview` 做极小文本请求时，新供应商网关返回 `522 Connect origin timed out`；该问题需要供应商侧确认上游模型可用性。

### D005 - file_uri 调用调整

- 按用户要求改为对齐旧 `AppTask#callExternalGeminiApiWithFileUri` 的调用形态。
- 新供应商调用改为 Gemini 兼容 HTTP API。
- HTTP 调用设置 `baseUrl=https://ent.univibe.cc`、`apiVersion=v1beta`、`timeout=600000`。
- 新供应商视频输入使用 `Part.fromUri(fileUrl, "video/mp4")`，提示词使用 `Part.fromText(prompt)`。
- 旧供应商仍保留现有 base64 调用方式。
- 已移除新供应商明文 key fallback。

### D006 - 新增 Gemini 兼容供应商与无参测试

- 新增 `GOOGLE_GEMINI_BASE_URL`、`GEMINI_API_KEY`、`GEMINI_MODEL` 供应商配置，优先级高于默认新供应商 baseUrl、key 和模型。
- JUnit 测试配置写入测试参数：`https://api1132.xyz`、`gemini-3-pro-preview`、用户提供的测试密钥、固定视频 URL 和默认钢琴点评 prompt。
- `PianoVideoSupplierIntegrationTest` 使用 `fileData/fileUri` 直传和 `inline_data` 内嵌数据验证三类供应商。
- `README-CONFIG.md` 和 `template.yml` 已补充新增供应商环境变量和测试方法。

### D007 - 独立 JUnit 供应商联调测试

- 新增 `GeminiSupplierClient`，统一 Gemini 兼容供应商 HTTP 调用，支持 Bearer 和 `x-goog-api-key` 两种认证。
- `AppTask` 新增显式 `apiKey/baseUrl/model` 重载，供旧供应商 JUnit 测试使用，避免修改进程环境变量。
- 新增 `src/test/resources/piano-video-supplier-test.properties`，测试参数包含旧供应商、新供应商1、新供应商2的 key、baseUrl、model、视频 URL 和 prompt。
- 新增 `PianoVideoSupplierIntegrationTest`，包含 6 个真实联调用例。
- `PianoHomeWorkVideoTask` 已移除 main 参数测试入口，测试统一通过 `mvn -q -Dtest=PianoVideoSupplierIntegrationTest test` 执行。
