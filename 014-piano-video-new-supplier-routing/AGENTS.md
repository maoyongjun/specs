# 规格执行说明

本目录记录 `014-piano-video-new-supplier-routing`。当前已完成文档与业务代码实现。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\014-piano-video-new-supplier-routing`
- 目标代码：`C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\PianoHomeWorkVideoTask.java`
- 参考代码：`C:\workspace\ju-chat\fc\Gemini-Api\src\main\java\com\drh\gemini\api\AppTask.java`

## 当前目标

- 在 `PianoHomeWorkVideoTask.java` 中规划新增新供应商调用方法。
- 新供应商使用 Java SDK 调用，`baseUrl=https://ent.univibe.cc`，`apiVersion=v1beta`，模型为 `gemini-3-flash-preview`。
- 新增环境变量 `newSupplierWeight`，取值范围 0 到 1。
- `newSupplierWeight=1` 时，钢琴视频识别请求全部使用新供应商。
- `newSupplierWeight=0` 或未配置时，保持全部使用现有供应商。
- `0 < newSupplierWeight < 1` 时，按权重将部分请求切到新供应商。
- 新供应商提示词测试时从 `resources/demo-prompt` 文件获取，对应仓库路径为 `C:\workspace\ju-chat\fc\Gemini-Api\src\main\resources\demo-prompt`。

## 当前实现状态

- `PianoHomeWorkVideoTask.java` 已实现 `newSupplierWeight` 解析与新供应商切流。
- `newSupplierWeight=1` 时，本次钢琴视频识别请求全部使用新供应商。
- `newSupplierWeight=0`、未配置或解析失败时，保持使用现有供应商。
- `0 < newSupplierWeight < 1` 时，按请求随机选择供应商；同一次 `analyzeVideoWithRetry` 的重试保持同一供应商。
- 新供应商被选中时优先读取 classpath resource `demo-prompt` 作为测试提示词，读取不到或为空时回退入参 `prompt`。
- 新供应商调用已对齐旧 `callExternalGeminiApiWithFileUri` 形态，使用视频 URL 作为 `file_uri`，不再把视频下载后转 base64。
- 新供应商密钥从环境变量 `new_supplier_api_key` 获取。
- `PianoHomeWorkVideoTask` 已提供 `main/testNewSupplierVideoAnalysis` 人工测试入口。
- `template.yml` 与 `README-CONFIG.md` 已补充新环境变量说明和占位配置。
- `fc/Gemini-Api` 已通过 `mvn -q -DskipTests compile` 编译验证。
- 尚未使用真实新供应商做端到端联调。

## 安全与配置约束

- 用户提供的新供应商 API key 是敏感信息，文档和代码均不得写入明文密钥。
- 新供应商密钥通过环境变量 `new_supplier_api_key` 注入。
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
