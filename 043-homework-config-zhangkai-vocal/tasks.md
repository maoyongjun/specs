# 任务清单：zhangkai 声乐作业点评配置

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须记录数据库行数、音频文件、接口返回和路由命中验证。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标为 `juzi-service` 作业点评配置模块。
- [x] T002 确认配置入口：`HomeworkConfigAdminController` 和 `/admin/homework-config/**`。
- [x] T003 确认核心服务：`HomeworkConfigService` 负责策略、动作、路由写入。
- [x] T004 确认落表：`drh_ai_config_homework_strategy`、`drh_ai_config_homework_action`、`drh_ai_config_homework_route`。
- [x] T005 确认声乐 sku 为 `SkuIdEnum.VOCAL_MUSIC=5`。
- [x] T006 确认 SOP 下游使用 `homeworkDayRelation`、`qwUserId_RLike`、`skuId` 做 route/action 匹配。

## Phase 2：风险门禁

- [x] T007 确认空策略为显式人工回复策略，不是未赋值对象。
- [x] T008 确认新增 route 必须同时包含 `currentDay&&homeworkDayRelation&&qwUserId_RLike`，保证运行时排序优先命中 `zhangkai` 专属配置。
- [x] T009 确认第 4 次及以上必须通过 `GTE=4` 空策略覆盖，避免落到旧默认配置。
- [x] T010 确认过去和未来作业通过 `PAST/FUTURE` 空策略覆盖。
- [x] T011 确认同步正式数据失败时不得清理测试库。
- [x] T012 确认新增 SQL 只包含本次新增配置。

## Phase 3：实现

- [x] T013 创建 Spec Kit 文档目录。
- [x] T014 从正式只读库导出三张作业点评配置表。
- [x] T015 清空测试库三张作业点评配置表并导入正式数据。
- [x] T016 生成 Day1-Day6 第二次点评克隆语音。
- [x] T017 通过 `localhost:9011` 创建 `zhangkai` 专属策略、动作、路由。
- [x] T018 生成 `zhangkai-homework-config-added.sql`。
- [x] T019 回填执行记录和验证结果。

## Phase 4：测试与验证

- [x] T020 校验正式库与测试库三张表行数一致。
- [x] T021 校验 6 个克隆语音文件存在且非空。
- [x] T022 校验 `GET /api/homework-config/config?skuId=5` 包含 `zhangkai` 专属配置。
- [x] T023 校验 Day1-Day6 第 1、2 次命中文字 + 语音策略。
- [x] T024 校验 Day1-Day4 第 3 次命中文本策略。
- [x] T025 校验 Day5/Day6 第 3 次、Day1-Day6 第 4 次及以上命中空策略。
- [x] T026 校验过去/未来作业命中空策略。
- [x] T027 校验其他企业微信 id 不命中 `zhangkai` 专属 route。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `043-homework-config-zhangkai-vocal` 规格目录和初始文档。
- 验证方式：本地文件检查。
- 自检结论：已完成实现前事实确认和风险门禁。

### D002 - 实现记录

- 实现内容：已将正式只读库三张作业点评配置表同步到测试库；同步基线为 strategy `46`、action `276`、route `39`。已生成 Day1-Day6 第二次克隆语音到 `C:\workspace\homework_file\kelong`。已通过 `localhost:9011` 创建 `zhangkai` 声乐配置：strategy `34`、route `34`；Day1-Day5 首次点评语音已按分段 MP3 更新，当前启用 action 为 `34`。已生成最终态 SQL：`zhangkai-homework-config-added.sql`。
- 测试命令：`python C:\workspace\ju-chat\specs\043-homework-config-zhangkai-vocal\scripts\verify_zhangkai_homework_config.py`；数据库行数静态查询；本地音频文件大小检查；SQL 文本检查。
- 测试结果：当前 `zhangkai` 启用数据为 strategy `34`、action `34`、route `34`；5 条旧首评 VOICE action 已禁用，11 条分段 VOICE action 已启用；6 个克隆 mp3 均非空；`zhangkai` route 全部使用 `currentDay&&homeworkDayRelation&&qwUserId_RLike`；服务重启后通过 `/api/homework-config/config?skuId=5` 重跑运行时兼容匹配验证，摘要写入 `verification-summary.json`。
- 自检结论：本次配置已完成并验证通过，未修改非作业点评三表。

### D003 - 路由优先级纠正记录

- 触发原因：全量配置按运行时排序选择 route 时，旧通用 `homeworkDayRelation` route 可能先于 `zhangkai` 专属 route 命中。
- 修正内容：将本次新增 route 的 `matchKey` 从 `homeworkDayRelation&&qwUserId_RLike` 修正为 `currentDay&&homeworkDayRelation&&qwUserId_RLike`，`matchValue` 修正为 `day&&relation&&zhangkai`。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 的路由匹配口径。
- 验证结果：数据库和 `/api/homework-config/config?skuId=5` 中 `zhangkai` route 共 `34` 条，全部使用修正后的三段 matchKey；Day6 FUTURE 已落库并通过接口返回为 `currentDay&&homeworkDayRelation&&qwUserId_RLike=6&&FUTURE&&zhangkai`，策略 `zhangkai-vocal-day6-future-manual`，actions 为空；Day1-Day6 当前、过去、未来及其他用户回归验证通过。简易 `/admin/homework-config/config/{day}/{commentIndex}` 查询接口不解析 `&&` 组合，不作为本次验收依据。

### D004 - Day1-Day5 首评语音分段更新记录

- 触发原因：Day1-Day5 首次点评语音从原单条语音调整为多个分段 MP3，需要去掉原语音。
- 修正内容：通过 `scripts/update_first_comment_split_voice.py` 删除 Day1-Day5 首评策略下旧 VOICE action `312/314/316/318/320`，并按文件名顺序新增分段语音 action `339-349`。
- 分段结果：Day1、Day2、Day4、Day5 各 `2` 段 VOICE；Day3 `3` 段 VOICE；Day6 保持原 `1` 段 VOICE。
- SQL 同步：已刷新最终态 `zhangkai-homework-config-added.sql`，并新增增量 SQL `sql/zhangkai-split-voice-update.sql`。
- 验证结果：`verify_zhangkai_homework_config.py` 已更新并通过；当前 `zhangkai` 启用 action 共 `34` 条，旧 5 条 VOICE 均为禁用态。
