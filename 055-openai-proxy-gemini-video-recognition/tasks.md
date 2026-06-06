# 任务清单：OpenAI Proxy Gemini 视频识别独立项目

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标为根级独立 Maven CLI 项目。
- [x] T002 用代码搜索确认 `fc\Gemini-Api` 的 `GeminiSupplierClient` 支持 fileUrl 与 inlineData。
- [x] T003 确认 mapping 第一条字段：`prompt`、`file_url`、`local_file`、`bytes`。
- [x] T004 确认本次只新增外部 HTTP CLI，不影响 Redis、MQ、数据库、FC 配置。
- [x] T005 确认旧逻辑保持：不修改 `fc\Gemini-Api` 和 `fc\pom.xml`。

**检查点**：T001-T005 已完成。

## Phase 2：风险门禁

- [x] T006 检查空对象风险：空 key、空 prompt、空 fileUrl、空 localFile、空 inlineData 均立即失败。
- [x] T007 检查调用后赋值风险：请求体构造前完成所有参数解析。
- [x] T008 检查每个下游读取字段在调用前已有确定来源。
- [x] T009 检查外部请求变化：仅新增根级项目的 Gemini HTTP 请求。
- [x] T010 记录用户确认的业务语义：Java Maven CLI、mapping 第一条、未跟踪 `.env`。
- [x] T011 建立测试映射：mapping、HTTP 参数、fallback、边界错误、响应解析。

**检查点**：T006-T011 已完成。

## Phase 3：实现

- [x] T012 新增 `gemini-video-recognition` Maven 项目。
- [x] T013 实现 `.env` 加载、CLI 参数解析、mapping loader、HTTP client、response parser。
- [x] T014 增加外部 HTTP 参数断言点，使用 JDK mock server。
- [x] T015 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 和 checklist。

## Phase 4：测试与验证

- [x] T016 新增单元测试。
- [x] T017 测试断言请求路径、鉴权 header、fileUrl body、inline body 和结果脱敏。
- [x] T018 验证边界情况：空 key、index 越界、inline 文件过大、无 text 响应。
- [x] T019 运行 `mvn test` 并记录结果。
- [x] T020 运行 `mvn package -DskipTests` 并记录结果。
- [x] T021 搜索确认没有 API key 写入源码、spec、测试资源或结果文件。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `055-openai-proxy-gemini-video-recognition` Spec Kit 文档。
- 验证方式：对照用户计划、CloseAI 文档、Gemini 官方 REST 文档、原 `Gemini-Api` 代码和 mapping 第一条。
- 自检结论：参数来源、调用顺序、字段风格、fallback 和测试映射已记录。

### D002 - 实现记录

- 实现内容：新增根级 Maven CLI 项目。
- 测试命令：`mvn test`
- 测试结果：`Tests run: 14, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 打包命令：`mvn package -DskipTests`
- 打包结果：`BUILD SUCCESS`，生成 `C:\workspace\ju-chat\gemini-video-recognition\target\gemini-video-recognition.jar`。
- 自检结论：参数来源、调用顺序、下游 HTTP 参数断言、inline fallback、结果脱敏和旧逻辑保持均已验证。

### D003 - 纠正记录模板

- 触发原因：用户补充、接口失败、字段风格变化、模型名变化或测试失败。
- 修正内容：写清旧口径和新口径。
- 文档同步：说明 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 是否已同步。
- 验证结果：记录测试或静态检查结果。

### D004 - 真实联调记录

- 执行命令：临时设置 `GEMINI_PROXY_API_KEY` 后执行 `java -jar target\gemini-video-recognition.jar --input-mode=auto --output=target\gemini-video-recognition\real-result.json`。
- 执行结果：HTTP `200`，`inputModeUsed=fileUrl`，未触发 inline fallback。
- 输出文件：`C:\workspace\ju-chat\gemini-video-recognition\target\gemini-video-recognition\real-result.json`。
- 返回摘要：识别为 `四季歌`，主要问题 `手型`，置信度 `0.98`。
- 安全检查：结果文件未包含用户提供 key 前缀或 inline base64。

### D005 - Prompt 模板更新记录

- 执行内容：生成 `C:\workspace\video_file\video_prompt_mapping_v2.json`，不修改原 mapping。
- 实现内容：复制原 mapping 全量字段，仅替换 `items[*].prompt` 为新版 prompt 模板。
- 天数保留：从旧 prompt 提取预置天数并写入新版模板；分布 D1=125、D2=39、D3=46、D4=3、D5=2。
- 代码同步：默认 mapping 路径切换为 `video_prompt_mapping_v2.json`。
- 测试结果：`mvn test` 通过，`Tests run: 15, Failures: 0, Errors: 0, Skipped: 0`；`mvn package -DskipTests` 通过。

### D006 - Runtime Context Prompt 更新记录

- 执行内容：覆盖更新 `C:\workspace\video_file\video_prompt_mapping_v2.json` 的 `items[*].prompt`，原 mapping 不变。
- 实现内容：使用用户提供的 Runtime Context / Classification Priority / Diagnosis Rules 模板，并把每条原始预置天数替换到全部 `D%s` 位置。
- 天数保留：D1=125、D2=39、D3=46、D4=3、D5=2，共 215 条，无缺失。
- 测试结果：`mvn test` 通过，`Tests run: 15, Failures: 0, Errors: 0, Skipped: 0`；`mvn package -DskipTests` 通过。
