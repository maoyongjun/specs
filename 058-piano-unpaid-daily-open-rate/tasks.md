# 任务清单：钢琴未付费批次每日开口率统计

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须覆盖 mode 解析、好友关系 nested 查询、批次去重、每日累计、默认文案排除、输出文件和旧逻辑不回归。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标项目为 `qw-user-message-export`。
- [x] T002 确认入口为 `MessageExportApp.run` 和 `ExportConfig.Mode`。
- [x] T003 确认现有开口/互动口径位于 `OpenRateAnalyzer`、`InteractionRateAnalyzer`。
- [x] T004 确认消息数据源为 OTS `juzi_private_message` / `juzi_private_message_index`。
- [x] T005 确认好友关系优先走 OTS `drh_external_user_info` / `drh_external_user_info_index`，不新增 MySQL 依赖。

## Phase 2：风险门禁

- [x] T006 未发现需要空 DTO、空 JSON、空 Map 作为占位传参。
- [x] T007 批次日期、账号、提供数量、统计结束日期均在调用 OTS 前确定。
- [x] T008 下游读取字段已明确：好友关系读取 `external_user_id/name/follow_user`，消息读取 `payload/timestamp/recall/external_user_id/contact_name`。
- [x] T009 本方案不改变外部 API、MQ、Redis、数据库结构或旧模式调用顺序。
- [x] T010 已确认主分母用企微添加时间，日报同时输出当日和累计开口率。
- [x] T011 已建立测试映射：解析、OTS 查询、分析器、formatter、app 输出。

## Phase 3：实现

- [x] T012 新增 `piano-daily-open-rate` 模式和别名。
- [x] T013 新增好友关系 OTS repository。
- [x] T014 新增批次模型、每日分析器、报告模型和 CSV/TXT formatter。
- [x] T015 在 `MessageExportApp` 中串联四个固定批次、好友关系分母、私聊回复和输出文件。
- [x] T016 同步更新 README 和 Spec Kit 执行记录。

## Phase 4：测试与验证

- [x] T017 新增 mode 解析测试。
- [x] T018 新增好友关系 nested 查询和时间窗测试。
- [x] T019 新增分析器测试，覆盖默认文案排除、跨天累计和非批次过滤。
- [x] T020 新增 formatter 与 app 级输出测试。
- [x] T021 运行目标 Maven 测试并记录结果。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `058-piano-unpaid-daily-open-rate` 规格文档。
- 验证方式：代码搜索、历史规格比对、静态确认。
- 自检结论：满足实现前强制门禁。

### D002 - 实现记录

- 执行内容：新增 `piano-daily-open-rate` 模式、好友关系 OTS 查询、四个固定批次分析、CSV/TXT 输出和 README 文档。
- 验证方式：目标 Maven 测试和模块全量 `mvn test`。
- 测试结果：目标测试通过；全量测试结果为 `Tests run: 61, Failures: 0, Errors: 0, Skipped: 1`。
- 自检结论：新增模式满足本规格，既有模式测试无回归。

### D003 - 真实跑数记录

- 执行内容：使用生产 OTS 公网 endpoint 运行 `--mode piano-daily-open-rate`。
- 输出目录：`C:\workspace\ju-chat\qw-user-message-export\output\piano-daily-open-rate-20260608-1627-prod-public`。
- 验证方式：检查生成的 `piano_daily_open_rate_report.csv`、`piano_daily_open_rate_detail.csv`、`piano_daily_open_rate_report.txt`。
- 数据结果：四个批次均成功，好友关系总数 `10129`，与提供总数一致；汇总 CSV `32` 条统计数据，明细 CSV `10129` 个批次学员。
