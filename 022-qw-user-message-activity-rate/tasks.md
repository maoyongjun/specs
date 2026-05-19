# 任务清单：企微用户近 30 天活跃度统计

**输入**：来自 `specs/022-qw-user-message-activity-rate/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：实现阶段需要验证 `userIds.txt` 读取、最近 30 天窗口、私聊 / 群聊合并统计、CSV 汇总、TXT 明细和总活跃人数 / 总活跃率输出；同时确认旧开口率模式不回归。

## Phase 1：规格与范围

- [x] T001 创建 `specs/022-qw-user-message-activity-rate` 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确新增模式名为 `activity-rate`
- [x] T003 明确输入文件为项目目录下的 `userIds.txt`
- [x] T004 明确 `userIds.txt` 每行一个销售 `qwUserId`
- [x] T005 明确空行、空白行跳过，重复销售默认去重
- [x] T006 明确统计窗口为最近 30 天
- [x] T007 明确按 `Asia/Shanghai` 计算时间
- [x] T008 明确私聊和群聊都纳入统计
- [x] T009 明确活跃判定为存在至少一条 `isSelf=false` 消息
- [x] T010 明确输出 CSV 汇总与 TXT 明细
- [x] T011 明确 CSV 末尾包含 `TOTAL` 汇总行
- [x] T012 明确 TXT 输出活跃 / 未活跃名单和样本消息
- [x] T013 明确旧开口率模式不变

## Phase 2：实现

- [x] T014 在 `ExportConfig.Mode` 中新增 `activity-rate`
- [x] T015 在 `MessageExportApp` 中新增 `activityRate` 调度分支
- [x] T016 读取 `userIds.txt` 并按销售逐个查询
- [x] T017 新增不限制私聊的 OTS 查询路径
- [x] T018 新增客户活跃度分析与统计模型
- [x] T019 输出 `activity_rate_report.csv`
- [x] T020 输出 `activity_rate_report.txt`
- [x] T021 生成总体 `TOTAL` 汇总行和 TXT 总体摘要

## Phase 3：验证

- [x] T022 验证 `activity-rate` 模式派发
- [x] T023 验证 `userIds.txt` 读取、空行跳过和重复去重
- [x] T024 验证最近 30 天窗口和 `Asia/Shanghai` 时间口径
- [x] T025 验证私聊和群聊都纳入活跃判定
- [x] T026 验证只有销售侧消息的客户记为未活跃
- [x] T027 验证 CSV 行、表头和 `TOTAL` 汇总行
- [x] T028 验证 TXT 的总体摘要、活跃名单、未活跃名单和样本消息
- [x] T029 验证旧 `export`、`open-rate`、`open-rate-all` 行为不回归

## 执行记录

### D001 - 文档与实现记录

- 已在 `qw-user-message-export` 中实现 `activity-rate` 模式。
- 已补充 `activity_rate_report.csv` 和 `activity_rate_report.txt` 输出。
- 已补充总体 `TOTAL` 汇总行以及 TXT 总体摘要。
- 已补充 `userIds.txt` 读取和重复去重路径。
- 已验证旧开口率模式未受影响。
