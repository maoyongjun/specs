# 任务清单：5月28日私聊互动人数统计

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于 `qw-user-message-export` 项目。
- [x] T002 用代码搜索确认真实入口为 `MessageExportApp.run` 和 `ExportConfig.Mode`。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
- [x] T004 确认配置来源为 OTS 环境变量 `endpoint`、`accessKey`、`accessSecret`、`instance`。
- [x] T005 确认旧模式 `export`、`open-rate`、`open-rate-all`、`activity-rate` 必须保持不变。

## Phase 2：风险门禁

- [x] T006 未发现需要空 DTO、空 JSON、空 Map 作为占位传参。
- [x] T007 时间窗口和目标 `user_id` 在调用 OTS 前现算，不存在调用后赋值风险。
- [x] T008 下游读取字段已明确：分母读取 `external_user_id` / 名称 / 时间，分子读取 `payload` / 名称 / 时间 / `recall`。
- [x] T009 本方案不改变外部接口、MQ、Redis、数据库结构或旧模式调用顺序。
- [x] T010 已确认分母不按 `isSelf=true` 过滤。
- [x] T011 已建立测试映射：解析、分派、OTS 查询、分析器、输出文件和时间窗口。

## Phase 3：实现

- [x] T012 新增 `interaction-rate` 模式。
- [x] T013 新增独立统计模型、分析器和输出 formatter。
- [x] T014 新增 OTS 私聊分母 collapse 查询和回复明细查询。
- [x] T015 同步更新 Spec Kit 文档。

## Phase 4：测试与验证

- [x] T016 新增或更新单元测试，覆盖关键行为。
- [x] T017 测试断言 OTS 查询包含 `user_id`、时间窗口、私聊过滤、`isSelf=false` 回复过滤和 collapse 行为。
- [x] T018 验证默认建联文案排除、真实回复保留、TOTAL 去重。
- [x] T019 运行目标模块测试或编译命令，并记录结果。
- [x] T020 搜索确认没有残留旧口径或输出文件名遗漏。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `039-qw-user-message-may28-interaction-rate` 规格文档。
- 验证方式：代码搜索、模板比对、静态确认。
- 自检结论：满足实现前强制门禁。

### D002 - 实现记录

- 实现内容：新增 `interaction-rate` 模式、独立统计与输出、OTS 查询和测试。
- 测试命令：`mvn "-Dtest=ExportConfigTest,MessageExportAppModeTest,OtsMessageRepositoryTest,InteractionRateAnalyzerTest,MessageExportAppInteractionRateTest,ActivityRateAnalyzerTest,MessageExportAppActivityRateTest" test`。
- 测试结果：BUILD SUCCESS，Tests run: 29, Failures: 0, Errors: 0, Skipped: 0。
- 自检结论：新增模式与旧模式隔离；固定日期、固定 `user_id`、私聊过滤、默认文案排除和 TOTAL 去重均有测试覆盖；真实 OTS 跑数需补齐环境变量后执行。
