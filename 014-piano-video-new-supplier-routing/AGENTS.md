# 规格执行说明

本目录记录 `014-piano-video-new-supplier-routing`。当前已完成文档与业务代码实现。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\014-piano-video-new-supplier-routing`
- 目标代码：`C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\PianoHomeWorkVideoTask.java`
- 参考代码：`C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\AppTask.java`

## 当前目标

- 在 `PianoHomeWorkVideoTask.java` 中规划新增新供应商调用方法。
- 新供应商使用 Gemini 兼容 HTTP API 调用，默认 `baseUrl=https://ent.univibe.cc`，`apiVersion=v1beta`，模型为 `gemini-3-flash-preview`。
- 新增 Gemini 兼容供应商1环境变量 `GOOGLE_GEMINI_BASE_URL/GEMINI_API_KEY/GEMINI_MODEL`，配置后优先覆盖新供应商1默认 baseUrl、密钥和模型。
- 新增 Gemini 兼容供应商2环境变量 `SUPPLIER2_BASE_URL/SUPPLIER2_API_KEY/SUPPLIER2_MODEL/SUPPLIER2_AUTH_MODE`。
- 新增环境变量 `supplierWeights`，格式为 `旧供应商,新供应商1,新供应商2`。
- 新增环境变量 `supplierDynamicRoutingEnabled`，默认开启成功率动态调权。
- `supplierWeights=1,0,0` 时，钢琴视频识别请求全部使用旧供应商。
- `supplierWeights=0,1,0` 时，钢琴视频识别请求全部使用新供应商1。
- `supplierWeights=0,0,1` 时，钢琴视频识别请求全部使用新供应商2。
- `newSupplierWeight` 不再参与流量分配。
- 新供应商提示词测试时从 `resources/demo-prompt` 文件获取，对应仓库路径为 `C:\workspace\ju-chat\fc\Gemini-Api\src\main\resources\demo-prompt`。

## 当前实现状态

- `PianoHomeWorkVideoTask.java` 已实现 `supplierWeights` 解析与三供应商切流。
- `supplierWeights` 未配置、解析失败、不是三段或全为 0 时，保持使用旧供应商。
- `supplierWeights` 单项先截断到 0 到 1，再按正数总和归一化；同一次 `analyzeVideoWithRetry` 的重试保持同一供应商。
- 动态路由开启时，按 Redis 最近 1 小时供应商 `success/total` 指标温和调整有效权重；基础权重为 0 的供应商保持禁用。
- 本次请求最终成功或失败后，会按选中的供应商记录一次分钟桶指标。
- 新供应商被选中时优先读取 classpath resource `demo-prompt` 作为测试提示词，读取不到或为空时回退入参 `prompt`。
- 新供应商调用已对齐旧 `callExternalGeminiApiWithFileUri` 形态，支持视频 URL `file_uri` 直传，也支持 `inline_data` 内嵌数据。
- 旧供应商可通过环境变量 `old_supplier_video_input_mode` 在 `inlineData` 和 `fileUrl` 之间切换；默认 `inlineData`。
- 生产新供应商密钥从环境变量 `GEMINI_API_KEY` 或 `new_supplier_api_key` 获取；JUnit 联调测试按用户要求从测试配置文件读取测试参数。
- 供应商联调已独立到 `PianoVideoSupplierIntegrationTest`，测试参数从 `src/test/resources/piano-video-supplier-test.properties` 读取。
- `template.yml` 与 `README-CONFIG.md` 已补充新环境变量说明和占位配置。
- `fc/Gemini-Api` 已通过 `mvn -q -DskipTests compile` 编译验证。
- 尚未使用真实新供应商做端到端联调。

## 安全与配置约束

- 生产新供应商 API key 是敏感信息，应通过环境变量注入。
- 本次 JUnit 联调测试配置按用户要求写入测试 key；不要在生产配置、日志或 README 示例中输出密钥。
- 日志不得打印 API key、Authorization header 或完整请求体。
- 新供应商密钥缺失时，不应静默切到新供应商；应记录可检索错误并按规格决定失败或回退。

## 行为约束

- 现有旧供应商调用、重试次数、缓存状态写入和错误处理流程必须保持兼容。
- 新供应商响应应复用现有 Gemini 响应解析逻辑，仍从 `candidates[0].content.parts[0].text` 提取文本。
- 新供应商调用失败时，应纳入现有 `analyzeVideoWithRetry` 重试流程。
- 新供应商返回空文本或命中现有可重试文案时，应保持现有重试语义。
- `resources/demo-prompt` 只影响新供应商测试请求；旧供应商仍使用入参 `prompt`。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录后续实现和验证任务。
- `checklists/requirements.md` 用于验证规格质量和实施就绪度。
