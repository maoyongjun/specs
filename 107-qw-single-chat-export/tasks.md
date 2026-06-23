# 任务清单：单账号 5 月 23 日至 6 月 23 日私聊导出

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标项目为 `C:\workspace\ju-chat\qw-user-message-export`，并确认执行范围为文档 + 实现 + 验证。
- [x] T002 用代码搜索确认真实入口为 `MessageExportApp.run` 和 `ExportConfig.parseMode`，私聊导出核心为 `OtsMessageRepository.findExportMessages → buildExportRequest`。
- [x] T003 确认现有 `export`、`jun3-chat-export`、`may15-chat-export` 都通过 `buildPrivateMessageQuery` 排除群聊（`is_group=true`），本模式复用该私聊过滤。
- [x] T004 确认关键参数来源：固定账号 `15110230427`、固定 `2026-05-23` 开始、固定 `2026-06-23` 结束、固定 `user_id` 查询字段。
- [x] T005 确认 OTS 字段：群聊与私聊同表 `juzi_private_message`，由 `is_group` 区分；返回列沿用 `EXPORT_COLUMNS`。
- [x] T006 确认配置来源：OTS 环境变量 `endpoint`、`accessKey`、`accessSecret`、`instance`；输出目录和文件大小沿用 CLI 参数。
- [x] T007 确认旧逻辑中必须保持不变的私聊查询、CSV 输出、分页、时间窗切片、`union_id` 查询、错误记录和既有模式行为。

**检查点**：不得在未完成 T001-T007 前进入实现。

## Phase 2：风险门禁

- [x] T008 检查空 DTO、空 JSON、空 Map 或部分赋值占位传参风险；本需求不新增 DTO，fake 测试只返回空集合表达无数据。
- [x] T009 检查调用后赋值、异步后赋值、依赖后续流程补字段风险；账号和时间窗口在调用 OTS 前确定，均为常量推导。
- [x] T010 检查下游读取字段来源；`payload`、`timestamp`、`message_source`、`isSelf`、`recall`、`is_group`、`chat_name`、`contact_name`、`external_user_id`、`user_id` 均来自 OTS 返回列。
- [x] T011 检查方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为；后续只新增 CLI 模式和复用既有私聊查询，不改既有方法签名语义、不新增写入。
- [x] T012 对需要用户确认的业务语义变化做记录；已确认 `user_id` 字段、时间窗口、只导出私聊、沿用七列 CSV。
- [x] T013 为关键行为建立测试映射：mode 解析、分派、固定参数、私聊过滤（排除群聊）、CSV 输出、异常不中断。

**检查点**：T008-T013 必须有明确结论；发现高风险时先更新 `spec.md` 的"历史问题防漏分析"。

## Phase 3：实现

- [x] T014 在 `ExportConfig.Mode` 新增 `SINGLE_CHAT_EXPORT`，`parseMode` 支持 `single-chat-export` 和下划线别名，更新 usage 文本。
- [x] T015 在 `MessageExportApp.run` 增加新模式分派，不改变旧模式分派顺序和行为。
- [x] T016 在 `MessageExportApp` 新增固定账号列表 `SINGLE_CHAT_EXPORT_USER_IDS`（`15110230427`）、固定开始日期 `2026-05-23`、固定结束日期 `2026-06-23`（结束取当日 23:59:59.999）。
- [x] T017 在 `MessageExportApp` 新增 `singleChatExport`，复用既有私聊 `exportMessages`（与 `may15ChatExport` 同样路径），新模式传固定账号和时间窗口。
- [x] T018 复用 `OtsUnionIdResolver`、`RollingCsvWriter`、`MessageTextExtractor`、`ExportSummary` 输出 `summary.txt`、`errors.log`、`messages_NNN.csv`。
- [x] T019 同步更新 `README.md` 和本规格文档中的实现结果。

## Phase 4：测试与验证

- [x] T020 在 `ExportConfigTest` 新增 `parsesSingleChatExportModeAndAlias`，断言连字符和下划线都解析到 `SINGLE_CHAT_EXPORT`。
- [x] T021 在 `MessageExportAppModeTest` 新增 `dispatchesSingleChatExportMode` 和 `RecordingApp` 覆写，断言只调用新模式。
- [x] T022 新增 `MessageExportAppSingleChatExportTest`，断言固定账号 `15110230427`、固定开始/结束时间戳、固定 `user_id` 字段、私聊导出、撤回与空文本跳过、单账号失败不中断。
- [x] T023 运行目标 Maven 测试和完整 `mvn test`，记录命令和结果。
- [x] T024 搜索确认没有旧模式被误改、没有残留临时口径或模板占位符。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `107-qw-single-chat-export` Spec Kit 文档。
- 验证方式：检查四个文档文件存在；确认参数来源、时间窗口、私聊口径已写清；通过 AskUserQuestion 确认关键决策。
- 自检结论：已完成规格、代码事实确认和风险门禁；可按本文档实现。

### D002 - 实现记录

- 实现内容：新增 `single-chat-export` mode、`SINGLE_CHAT_EXPORT` 枚举、固定账号 `15110230427`、固定 `2026-05-23 00:00:00`～`2026-06-23 23:59:59.999 Asia/Shanghai` 窗口；复用既有私聊 `exportMessages`；`README.md` 补充说明。
- 测试命令：`mvn "-Dtest=ExportConfigTest,MessageExportAppModeTest,MessageExportAppSingleChatExportTest,OtsMessageRepositoryTest,MessageExportAppMay15ChatExportTest,MessageExportAppJun3ChatExportTest,MessageExportAppExportTest" test`
- 测试结果：BUILD SUCCESS；Tests run: 38, Failures: 0, Errors: 0, Skipped: 0。
  - `ExportConfigTest` 新增 `parsesSingleChatExportModeAndAlias`：连字符和下划线都解析到 `SINGLE_CHAT_EXPORT`。
  - `MessageExportAppModeTest` 新增 `dispatchesSingleChatExportMode`：只调用新模式，不调用其他模式。
  - `MessageExportAppSingleChatExportTest` 2 条：固定账号、固定时间窗口、`user_id` 字段、私聊导出、撤回/空文本跳过、单账号失败不中断。
- 完整验证：`mvn test` BUILD SUCCESS；Tests run: 73, Failures: 0, Errors: 0, Skipped: 1（既有真实 OTS 集成测试条件跳过）。
- 自检结论：新模式固定使用 `user_id`，不受 `--field`/`--days` 影响；既有模式行为未改动且测试仍通过；私聊过滤有测试覆盖；当前未真实访问 OTS。

### D003 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
