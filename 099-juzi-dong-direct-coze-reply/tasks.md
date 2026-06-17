# 任务清单：Dong 专属 Coze 直连回复

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充 Dong 分支、Coze 请求结构、Juzi 发送参数和旧链路旁路测试。

## Phase 1：代码事实确认

- [x] T001 确认入口为 `MessageServiceImpl#doSendMessage`。
- [x] T002 确认现有 Coze SDK 已支持 `MessageContentType.OBJECT_STRING`。
- [x] T003 确认 Juzi 文本发送协议使用 `juzi-api` + `functionCode=SEND_MESSAGE`。
- [x] T004 确认当前 `MessageDto` 无 `corpId` 字段，Juzi 发送只组装下游读取的必需字段。
- [x] T005 确认非 Dong 旧链路不得改变。

## Phase 2：风险门禁

- [x] T006 Coze 请求不使用空 JSON；真实调用验证后采用 SDK 原生 text object schema。
- [x] T007 Dong 命中但不可回复时返回已处理，避免 fallback 到旧链路。
- [x] T008 Juzi 发送 gateway 支持测试捕获 `FcInvokeInput`。
- [x] T009 Coze client 支持常规单测捕获请求。
- [x] T009a 新增显式开启的真实 Coze agent 集成测试。
- [x] T010 用户已确认 `userID` 使用 `demo:{botId}:{externalUserId}:{userId}:{env}`。

## Phase 3：实现

- [x] T011 新增 Dong 配置类。
- [x] T012 新增 Dong Coze DTO/client/service。
- [x] T013 新增 Juzi 文本发送 gateway。
- [x] T014 在 `MessageServiceImpl` 接入 Dong 分支。
- [x] T015 保持现有私域、权限、SOP、路由旧行为。

## Phase 4：测试与验证

- [x] T016 新增 Dong service 单元测试。
- [x] T017 新增 Juzi sender 单元测试。
- [x] T018 新增 `MessageServiceImpl` Dong 旁路测试。
- [x] T019 运行目标 Maven 测试。
- [x] T020 运行真实 agent 验证。
- [x] T021 执行 diff 检查。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `099-juzi-dong-direct-coze-reply` 完整 Spec Kit 文档。
- 验证方式：静态检查文档内容与用户确认口径一致。
- 自检结论：参数来源、调用顺序、下游读取和测试映射已记录。

### D002 - 实现记录

- 实现内容：新增 Dong 专属 Coze 直连和 Juzi 文本发送，接入 `MessageServiceImpl`。
- 测试命令：`mvn -f C:\workspace\ju-chat\data-RC\pom.xml -pl juzi-service test -DskipTests=false "-Dtest=DongDirectCozePropertiesTest,DongDirectCozeReplyServiceTest,DongJuziTextSenderTest,MessageServiceImplDongDirectCozeTest"`
- 测试结果：`Tests run: 11, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。

### D003 - 真实 agent 验证记录

- 失败验证：严格按调试页 `content_type/content` 结构调用 chat API，可成功获取 token 和 conversation，但 Coze 返回 `Request parameter error`。
- 成功验证：使用 SDK 原生 `Message.buildUserQuestionObjects(MessageObjectString.buildText("夸我"))`，真实 agent 返回非空文本。
- 成功命令：`mvn -f C:\workspace\ju-chat\data-RC\pom.xml -pl juzi-service test -DskipTests=false "-Dtest=DongDirectCozeAgentIT" "-Ddong.direct.coze.it.enabled=true" "-Dfc.endpoint=fc.cn-beijing.aliyuncs.com"`
- 成功结果：`Tests run: 1, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
