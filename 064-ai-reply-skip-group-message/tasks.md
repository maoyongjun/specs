# 任务清单：ai-reply 群消息跳过

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：目标模块 JUnit 4 测试和静态位置确认。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标项目为 `fc\ai-reply`。
- [x] T002 确认真实入口为 `AppTask.handleRequest(JSONObject, Context)`。
- [x] T003 确认关键参数 `isGroup` 来源于上游 FC 入参，解析后由 `EmpExternalDto.getIsGroup()` 读取。
- [x] T004 确认本次不修改配置、环境变量、Redis key、MQ body、FC 入参或数据库。
- [x] T005 确认非群消息旧逻辑必须保持不变。

**检查点**：已完成 T001-T005。

## Phase 2：风险门禁

- [x] T006 无新增 `new XxxDto()`、空 JSON、空 Map 或占位传参。
- [x] T007 无调用后赋值或依赖后续流程补齐字段的新增风险。
- [x] T008 群消息门禁只读取解析后的 `isGroup`，调用前已有来源。
- [x] T009 本次只减少群消息在 `ai-reply` 内的处理，不修改外部契约。
- [x] T010 用户已确认群消息在 `ai-reply` 内完全跳过，包括转账/红包提醒副作用。
- [x] T011 测试映射覆盖 `isGroup=true`、`false`、`null` 和完整群消息入口早返回。

**检查点**：已完成 T006-T011。

## Phase 3：实现

- [x] T012 在 `AppTask.handleRequest` 入口新增群消息早返回。
- [x] T013 保持未声明的非群消息旧行为不变。
- [x] T014 新增包内静态 helper `shouldSkipGroupMessage` 作为测试断言点。
- [x] T015 同步更新本规格文档。

## Phase 4：测试与验证

- [x] T016 更新 `PrivateDomainAppTaskTest`。
- [x] T017 测试断言群消息早返回，不依赖真实 Redis/OTS/Coze。
- [x] T018 验证私域 AI 和缺失 agent/sku 既有测试不回归。
- [x] T019 运行目标模块测试并记录结果。
- [x] T020 搜索确认门禁位置和上游契约未改。

## 执行记录

### D001 - 文档记录

- 执行内容：从 `_template` 创建 `064-ai-reply-skip-group-message` 并填写规格。
- 验证方式：代码搜索、入口阅读、字段来源确认。
- 自检结论：满足强制门禁。

### D002 - 实现记录

- 实现内容：新增 `AppTask.shouldSkipGroupMessage`；`isGroup=true` 时入口日志后直接返回；新增对应 JUnit 测试。
- 测试命令：`mvn -pl ai-reply -am -Dtest=PrivateDomainAppTaskTest -DfailIfNoTests=false '-Dsurefire.failIfNoSpecifiedTests=false' test`
- 测试结果：`Tests run: 6, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：门禁位于 `handlePrivateDomainAi` 和 `new RedisClient()` 之前；非群消息旧逻辑未改；剩余风险为依赖上游继续正确写入 `isGroup`。
