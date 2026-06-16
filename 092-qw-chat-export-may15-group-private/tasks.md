# 任务清单：13 账号 5 月 15 日至 6 月 15 日群聊+私聊导出

**输入**：来自 `spec.md` 的功能规格
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标项目为 `C:\workspace\ju-chat\qw-user-message-export`，并确认执行范围为文档 + 实现 + 验证。
- [x] T002 用代码搜索确认真实入口为 `MessageExportApp.run` 和 `ExportConfig.parseMode`，私聊导出核心为 `OtsMessageRepository.findExportMessages → buildExportRequest`。
- [x] T003 确认现有 `export`、`jun3-chat-export` 都通过 `buildPrivateMessageQuery` 排除群聊（`is_group=true`），本模式必须不应用该过滤。
- [x] T004 确认关键参数来源：固定 13 账号、固定 `2026-05-15` 开始、固定 `2026-06-15` 结束、固定 `user_id` 查询字段。
- [x] T005 确认 OTS 字段：群聊与私聊同表 `juzi_private_message`，由 `is_group` 区分；返回列沿用 `EXPORT_COLUMNS`；`user_id` 可为手机号串或字符串句柄。
- [x] T006 确认配置来源：OTS 环境变量 `endpoint`、`accessKey`、`accessSecret`、`instance`；输出目录和文件大小沿用 CLI 参数。
- [x] T007 确认旧逻辑中必须保持不变的私聊查询、CSV 输出、分页、时间窗切片、`union_id` 查询、错误记录和既有模式行为。

**检查点**：T001-T007 已完成。

## Phase 2：风险门禁

- [x] T008 检查空 DTO、空 JSON、空 Map 或部分赋值占位传参风险；本需求不新增 DTO，fake 测试只返回空集合表达无数据。
- [x] T009 检查调用后赋值、异步后赋值、依赖后续流程补字段风险；账号列表和时间窗口在调用 OTS 前确定，均为常量推导。
- [x] T010 检查下游读取字段来源；`payload`、`timestamp`、`message_source`、`isSelf`、`recall`、`is_group`、`chat_name`、`contact_name`、`external_user_id`、`user_id` 均来自 OTS 返回列。
- [x] T011 检查方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为；后续只新增 CLI 模式和一条 OTS 读查询，不改既有方法签名语义、不新增写入。
- [x] T012 对需要用户确认的业务语义变化做记录；已确认 `user_id` 字段、时间窗口、群聊+私聊都导出、沿用七列 CSV。
- [x] T013 为关键行为建立测试映射：mode 解析、分派、固定账号、时间窗口、群聊不排除、CSV 输出、异常不中断。

**检查点**：T008-T013 已完成。

## Phase 3：实现

- [x] T014 在 `ExportConfig.Mode` 新增 `MAY15_CHAT_EXPORT`，`parseMode` 支持 `may15-chat-export` 和下划线别名，更新 usage 文本。
- [x] T015 在 `MessageExportApp.run` 增加新模式分派，不改变旧模式分派顺序和行为。
- [x] T016 在 `MessageExportApp` 新增固定 13 账号列表、固定开始日期 `2026-05-15`、固定结束日期 `2026-06-15`（结束取当日 23:59:59.999）。
- [x] T017 在 `MessageExportApp` 新增 `may15ChatExport`，给 `exportMessages`/`exportUser` 增加 `includeGroupMessages` 开关；新模式传 `true`，既有模式继续传 `false`（私聊）。
- [x] T018 在 `OtsMessageRepository` 新增 `findAllChatMessages`（时间切片 + range-split + 分页/token）和 `buildAllChatExportRequest`（不含私聊 should、不含 `external_user_id` exists、固定 `user_id`、timestamp 闭区间、timestamp ASC、`EXPORT_COLUMNS`）。
- [x] T019 复用 `OtsUnionIdResolver`、`RollingCsvWriter`、`MessageTextExtractor`、`ExportSummary` 输出 `summary.txt`、`errors.log`、`messages_NNN.csv`。
- [x] T020 同步更新 `README.md` 和本规格执行记录中的实现结果。

## Phase 4：测试与验证

- [x] T021 在 `ExportConfigTest` 新增 `parsesMay15ChatExportModeAndAlias`，断言连字符和下划线都解析到 `MAY15_CHAT_EXPORT`。
- [x] T022 在 `MessageExportAppModeTest` 新增 `dispatchesMay15ChatExportMode` 和 `RecordingApp` 覆写，断言只调用新模式。
- [x] T023 在 `OtsMessageRepositoryTest` 新增 `allChatExportRequestIncludesGroupChatsAndKeepsTimestampSort`，断言 `user_id` term、timestamp 闭区间、无私聊 should 子句、无 `external_user_id` exists、timestamp ASC、`EXPORT_COLUMNS`、token/offset。
- [x] T024 新增 `MessageExportAppMay15ChatExportTest`，断言固定 13 账号顺序、固定开始/结束时间戳、固定 `user_id` 字段、群聊消息进入结果、撤回与空文本跳过、单账号失败不中断。
- [x] T025 运行目标 Maven 测试和完整 `mvn test`，记录命令和结果。
- [x] T026 搜索确认没有旧模式被误改、没有残留临时口径或模板占位符。

## Phase 5：D003 纠正（群聊+私聊 → 仅私聊）

- [x] T027 `MessageExportApp.may15ChatExport` 改为调用私聊 `exportMessages`；移除 `includeGroupMessages` 开关和 6 参重载，`exportUser` 恢复只调用 `findExportMessages`。
- [x] T028 `OtsMessageRepository` 移除 `findAllChatMessages` 及其时间切片/range-split/fetch 私有方法和 `buildAllChatExportRequest`，避免残留未使用口径。
- [x] T029 `OtsMessageRepositoryTest` 移除 `allChatExportRequestIncludesGroupChatsAndKeepsTimestampSort` 及其 `hasExists` 辅助；私聊过滤改由既有 `exportRequestFiltersPrivateChatsAndKeepsTimestampSort` 覆盖。
- [x] T030 `MessageExportAppMay15ChatExportTest` 改为私聊语义：覆写 `findExportMessages`，断言固定 13 账号、固定窗口、`user_id` 字段、私聊导出、撤回/空文本跳过、单账号失败不中断。
- [x] T031 `README.md` 改为“只导出私聊（排除 `is_group=true`）”。
- [x] T032 重新打包并真实重跑 `may15-chat-export`，记录命令与结果。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `092-qw-chat-export-may15-group-private` Spec Kit 文档。
- 验证方式：检查四个文档文件存在；确认参数来源、时间窗口、群聊+私聊口径已写清；通过 AskUserQuestion 确认关键决策。
- 自检结论：已完成规格、代码事实确认和风险门禁；可按本文档实现。

### D002 - 实现记录

- 实现内容：新增 `may15-chat-export` mode、`MAY15_CHAT_EXPORT` 枚举、固定 13 账号、固定 `2026-05-15 00:00:00`～`2026-06-15 23:59:59.999 Asia/Shanghai` 窗口；新增 `findAllChatMessages`/`buildAllChatExportRequest` 群聊+私聊查询；`exportMessages`/`exportUser` 增加 `includeGroupMessages` 开关，复用既有 CSV/union_id/分页/切片/错误日志逻辑。
- 测试命令：`mvn "-Dtest=ExportConfigTest,MessageExportAppModeTest,MessageExportAppMay15ChatExportTest,OtsMessageRepositoryTest,MessageExportAppJun3ChatExportTest,MessageExportAppExportTest" test`
- 测试结果：BUILD SUCCESS；Tests run: 35, Failures: 0, Errors: 0, Skipped: 0。
  - `MessageExportAppMay15ChatExportTest` 2 条：群聊行被导出、固定 13 账号顺序、固定起止时间戳、`user_id` 字段、撤回与空文本跳过、单账号失败不中断。
  - `OtsMessageRepositoryTest` 新增 `allChatExportRequestIncludesGroupChatsAndKeepsTimestampSort`：无私聊 should 子句、无 `external_user_id` exists、`user_id` term、timestamp 闭区间、timestamp ASC、`EXPORT_COLUMNS`、token/offset。
- 完整验证：`mvn test` BUILD SUCCESS；Tests run: 70, Failures: 0, Errors: 0, Skipped: 1（跳过项为既有真实 OTS 集成测试条件不满足时的条件跳过，与本次改动无关）。
- 自检结论：新模式固定使用 `user_id`，不受 `--field`/`--days` 影响；既有私聊 `findExportMessages`/`buildExportRequest` 与 `export`/`jun3-chat-export` 行为未改动且测试仍通过；群聊不排除有测试覆盖；当前未真实访问 OTS。

### D003 - 纠正：群聊+私聊改为仅私聊

- 触发原因：D002 真实跑数后，用户纠正“不导出群聊，只导出私聊的”。
- 旧口径 → 新口径：`may15-chat-export` 由“群聊+私聊”（`findAllChatMessages`/`buildAllChatExportRequest`，不应用私聊过滤）改为“仅私聊”（复用 `findExportMessages`/`buildExportRequest`，私聊 should 子句排除 `is_group=true`）；固定 13 账号和窗口不变。
- 代码修改：见 `spec.md` D003（MessageExportApp / OtsMessageRepository / 两个测试 / README）。
- 文档同步：`spec.md`、`AGENTS.md`、`checklists/requirements.md`、本文件已同步为仅私聊口径。
- 测试命令：`mvn "-Dtest=ExportConfigTest,MessageExportAppModeTest,MessageExportAppMay15ChatExportTest,OtsMessageRepositoryTest,MessageExportAppJun3ChatExportTest,MessageExportAppExportTest" test`
- 测试结果：BUILD SUCCESS；Tests run: 34, Failures: 0, Errors: 0, Skipped: 0（移除 1 条群聊请求断言用例，新 may15 用例改为私聊语义）。
- 完整验证：`mvn test` BUILD SUCCESS；Tests run: 69, Failures: 0, Errors: 0, Skipped: 1（既有真实 OTS 集成测试条件跳过）。
- 真实重跑：`java -jar target\qw-user-message-export-1.0.0.jar --mode may15-chat-export --output output\may15-private`（运行后回填 summary）。
