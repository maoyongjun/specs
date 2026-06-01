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
- [x] T008 确认新增 route 必须同时包含 `homeworkDayRelation&&qwUserId_RLike`。
- [x] T009 确认第 4 次及以上必须通过 `GTE=4` 空策略覆盖，避免落到旧默认配置。
- [x] T010 确认过去和未来作业通过 `PAST/FUTURE` 空策略覆盖。
- [x] T011 确认同步正式数据失败时不得清理测试库。
- [x] T012 确认新增 SQL 只包含本次新增配置。

## Phase 3：实现

- [x] T013 创建 Spec Kit 文档目录。
- [ ] T014 从正式只读库导出三张作业点评配置表。
- [ ] T015 清空测试库三张作业点评配置表并导入正式数据。
- [ ] T016 生成 Day1-Day6 第二次点评克隆语音。
- [ ] T017 通过 `localhost:9011` 创建 `zhangkai` 专属策略、动作、路由。
- [ ] T018 生成 `zhangkai-homework-config-added.sql`。
- [ ] T019 回填执行记录和验证结果。

## Phase 4：测试与验证

- [ ] T020 校验正式库与测试库三张表行数一致。
- [ ] T021 校验 6 个克隆语音文件存在且非空。
- [ ] T022 校验 `GET /api/homework-config/config?skuId=5` 包含 `zhangkai` 专属配置。
- [ ] T023 校验 Day1-Day6 第 1、2 次命中文字 + 语音策略。
- [ ] T024 校验 Day1-Day4 第 3 次命中文本策略。
- [ ] T025 校验 Day5/Day6 第 3 次、Day1-Day6 第 4 次及以上命中空策略。
- [ ] T026 校验过去/未来作业命中空策略。
- [ ] T027 校验其他企业微信 id 不命中 `zhangkai` 专属 route。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `043-homework-config-zhangkai-vocal` 规格目录和初始文档。
- 验证方式：本地文件检查。
- 自检结论：已完成实现前事实确认和风险门禁。

### D002 - 实现记录

- 实现内容：`<执行后填写>`
- 测试命令：`<执行后填写>`
- 测试结果：`<执行后填写>`
- 自检结论：`<执行后填写>`

### D003 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`
- 修正内容：`<说明具体修正>`
- 文档同步：`<说明同步了哪些文件>`
- 验证结果：`<说明测试或静态验证>`
