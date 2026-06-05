# 任务清单：VectorNode Gemini 视频识别项目

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标为 `fc\gemini-video-recognition` 独立模块。
- [x] T002 用代码搜索确认 `fc\Gemini-Api` 的 Gemini native client 和集成测试。
- [x] T003 确认关键参数来源：mapping、env、CLI、路由默认值。
- [x] T004 确认本次只新增外部 HTTP 调用，不影响 Redis、MQ、数据库。
- [x] T005 确认旧逻辑保持：不修改 `fc\Gemini-Api`。

**检查点**：T001-T005 已完成。

## Phase 2：风险门禁

- [x] T006 检查空对象风险：空 key、空 prompt、空 fileUri、空 inlineData 均立即失败。
- [x] T007 检查调用后赋值风险：请求体构造前完成所有参数解析。
- [x] T008 检查下游读取字段：测试断言 HTTP body 和 header。
- [x] T009 检查外部请求变化：新增独立模块的 VectorNode HTTP 请求。
- [x] T010 记录用户确认的业务语义：VectorNode Lab 文档、`success_rate` 路由。
- [x] T011 建立测试映射：mapping、HTTP 参数、响应解析、错误路径。

**检查点**：T006-T011 已完成。

## Phase 3：实现

- [x] T012 新增 Maven 子模块。
- [x] T013 实现 mapping loader、HTTP client、response parser 和 CLI。
- [x] T014 增加外部 HTTP 参数断言点，使用 JDK mock server。
- [x] T015 同步更新 Spec Kit 文档。

## Phase 4：测试与验证

- [x] T016 新增单元测试。
- [x] T017 测试断言请求路径、Bearer header、provider.sort、fileData 和 mimeType。
- [x] T018 验证边界情况：空 key、HTTP 失败、无 text 响应。
- [x] T019 运行目标模块测试并记录结果。
- [x] T020 打包并执行真实 CLI 验证。
- [x] T021 搜索确认没有 API key 写入文件、没有修改原 `Gemini-Api`。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `054-vectronode-gemini-video-recognition` Spec Kit 文档。
- 验证方式：对照用户计划、VectorNode Lab 静态资源、原 `Gemini-Api` 代码。
- 自检结论：参数来源、调用顺序、路由口径和测试映射已记录。

### D002 - 实现记录

- 实现内容：新增 `gemini-video-recognition` 模块和 CLI。
- 测试命令：`mvn -pl gemini-video-recognition test`
- 测试结果：`Tests run: 10, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：单元测试覆盖下游 HTTP 参数；真实验证已完成，见 D003。

### D003 - 真实验证记录

- 打包命令：`mvn -pl gemini-video-recognition package -DskipTests`
- 打包结果：`BUILD SUCCESS`。
- CLI 命令：临时设置 `VECTRONODE_API_KEY` 后执行 `java -jar target\gemini-video-recognition.jar --output=target\vectronode-video-recognition\result.json`。
- CLI 结果：HTTP `200`，`routingMode=PROVIDER_SORT`，未触发 fallback，解析文本长度 `1122`。
- 结果文件：`C:\workspace\ju-chat\fc\gemini-video-recognition\target\vectronode-video-recognition\result.json`。
- 安全检查：`rg` 未发现用户提供 API key 写入 `specs\054-vectronode-gemini-video-recognition`、`fc\gemini-video-recognition` 或 `fc\pom.xml`。
