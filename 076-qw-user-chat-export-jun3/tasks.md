# 任务清单：四账号 6 月 3 日起私聊导出

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：后续实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前只创建 Spec Kit 文档，目标项目为 `C:\workspace\ju-chat\qw-user-message-export`。
- [x] T002 用代码搜索确认真实入口为 `MessageExportApp.run` 和 `ExportConfig.parseMode`，核心查询为 `OtsMessageRepository.findExportMessages`。
- [x] T003 确认关键参数来源：固定四账号、固定 `2026-06-03` 起始时间、运行时刻结束时间、默认 `user_id` 查询字段。
- [x] T004 确认配置来源：OTS 环境变量为 `endpoint`、`accessKey`、`accessSecret`、`instance`；输出目录和文件大小沿用 CLI 参数。
- [x] T005 确认旧逻辑中必须保持不变的 CSV 输出、分页、时间窗切片、`union_id` 查询、错误记录和既有模式行为。

**检查点**：T001-T005 已完成；本阶段只写文档，不进入业务代码实现。

## Phase 2：风险门禁

- [x] T006 检查空 DTO、空 JSON、空 Map 或只赋值部分字段的占位传参风险；本需求后续不需要新增 DTO，fake 测试只返回空集合表达无数据。
- [x] T007 检查调用后赋值、异步后赋值、依赖后续流程补字段风险；账号列表和时间窗口必须在调用 OTS 前确定。
- [x] T008 检查下游读取字段来源；`payload`、`timestamp`、`message_source`、`isSelf`、`recall`、`is_group`、`chat_name`、`contact_name`、`external_user_id` 均来自 OTS 返回列。
- [x] T009 检查方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为；后续只新增 CLI 模式和 OTS 读查询，不新增写入或外部接口。
- [x] T010 对需要用户确认的业务语义变化做记录；已确认私聊 CSV 和新增模式，不覆盖现有 `export`。
- [x] T011 为关键行为建立测试映射：mode 解析、固定账号、时间窗口、私聊过滤、双方消息、CSV 输出、异常不中断。

**检查点**：T006-T011 已完成；后续实现前若口径变化，先更新 `spec.md`。

## Phase 3：后续实现

- [x] T012 在 `ExportConfig.Mode` 新增 `JUN3_CHAT_EXPORT`，支持 `--mode jun3-chat-export` 和可选下划线别名。
- [x] T013 在 `MessageExportApp.run` 增加新模式分派，不改变旧模式分派顺序和行为。
- [x] T014 新增固定账号列表 `maiweigml`、`LiXin`、`XieWenHao1`、`LiuYuan_3`。
- [x] T015 新增固定开始日期 `2026-06-03`，按 `Asia/Shanghai` 转为毫秒；结束时间使用 `clock.millis()`。
- [x] T016 复用现有导出流程：`OtsMessageRepository.findExportMessages`、`OtsUnionIdResolver`、`RollingCsvWriter`、`MessageTextExtractor`。
- [x] T017 确保新模式失败前缀、`summary.txt`、`errors.log` 和控制台输出清晰标识本次导出。
- [x] T018 同步更新 `README.md` 和本规格执行记录中的实现结果。

## Phase 4：后续测试与验证

- [x] T019 新增或更新 `ExportConfigTest`，断言 `jun3-chat-export` 能解析到新增枚举。
- [x] T020 新增 `MessageExportAppJun3ChatExportTest` 或同类测试，断言固定四账号和固定时间窗口。
- [x] T021 更新或新增 `MessageExportAppModeTest`，断言新模式会调用专用流程。
- [x] T022 更新或新增 `OtsMessageRepositoryTest`，确认导出查询仍使用 `user_id`、timestamp 闭区间、私聊过滤和 timestamp 升序。
- [x] T023 测试 CSV 输出字段、双方消息保留、空文本跳过、撤回跳过和单账号失败不中断。
- [x] T024 运行目标 Maven 测试，并记录命令和结果。
- [x] T025 搜索确认没有旧模式被误改、没有残留临时口径或模板占位符。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `076-qw-user-chat-export-jun3` Spec Kit 文档。
- 验证方式：检查四个文档文件存在；搜索模板占位符和未澄清标记；确认当前阶段未修改业务代码。
- 自检结论：已完成规格、代码事实确认和风险门禁；后续实现可按本文档执行。

### D002 - 实现记录

- 实现内容：新增 `jun3-chat-export` mode、`JUN3_CHAT_EXPORT` 枚举、固定四账号列表、固定 `2026-06-03 00:00:00 Asia/Shanghai` 起始窗口，并复用现有私聊 CSV 导出流程。
- 测试命令：`mvn "-Dtest=ExportConfigTest,MessageExportAppModeTest,MessageExportAppJun3ChatExportTest,OtsMessageRepositoryTest,MessageExportAppExportTest" test`。
- 测试结果：BUILD SUCCESS；Tests run: 30, Failures: 0, Errors: 0, Skipped: 0。
- 完整验证：`mvn test` BUILD SUCCESS；Tests run: 65, Failures: 0, Errors: 0, Skipped: 1。
- 自检结论：新模式固定使用 `user_id`，不受 `--field` 和 `--days` 影响；旧 `export` 模式测试仍覆盖 15 天窗口和原有两个账号；真实 OTS 跑数未执行。

### D003 - 纠正记录模板

- 触发原因：用户补充、测试失败、代码审查发现、参数遗漏或调用顺序问题。
- 修正内容：说明旧口径和新口径。
- 文档同步：说明同步了哪些文件。
- 验证结果：说明测试或静态验证结果。
