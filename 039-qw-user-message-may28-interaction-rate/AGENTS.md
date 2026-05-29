# 规格执行说明

本目录记录 `039-qw-user-message-may28-interaction-rate` 的规格与实现约定，后续修改应保持文档与 `qw-user-message-export` 项目代码同步。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\039-qw-user-message-may28-interaction-rate`
- 目标项目：`C:\workspace\ju-chat\qw-user-message-export`
- 相关模块：`com.juchat.qwexport`

## 当前目标

- 新增 `--mode interaction-rate`，统计 2026-05-28 当天私聊互动人数。
- 固定统计 `user_id`：`15311073569`、`15313302127`。
- 输出发送学员总数、回复学员总数、比值和明细数据。

## 执行原则

- 新模式独立实现，不改变既有 `export`、`open-rate`、`open-rate-all`、`activity-rate` 口径。
- 分母按用户已确认口径：当天私聊范围内 `external_user_id` 去重，不额外按 `isSelf=true` 过滤。
- 分子只统计 `isSelf=false` 且回复内容不是默认建联文案的学员，并记录任意一条有效回复内容；实现默认记录当天最早有效回复。
- OTS 查询必须限定 `is_group` 不存在或为 `false` 的私聊记录。

## 强制门禁

- 关键参数必须有明确来源：固定日期、固定 user_id、OTS 表/索引、私聊过滤、回复过滤。
- 回复查询不得提前按 `external_user_id` collapse；必须拉取明细后在 Java 侧排除默认文案，避免漏掉默认文案后续真实回复。
- 输出必须同时包含汇总和明细，便于人工核对。
- 单元测试必须覆盖窗口、分母口径、默认文案排除、输出字段和 CLI 分派。

## 重点代码位置

- `C:\workspace\ju-chat\qw-user-message-export\src\main\java\com\juchat\qwexport\MessageExportApp.java`
- `C:\workspace\ju-chat\qw-user-message-export\src\main\java\com\juchat\qwexport\OtsMessageRepository.java`
- `C:\workspace\ju-chat\qw-user-message-export\src\test\java\com\juchat\qwexport`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和执行记录。
- `tasks.md` 记录代码事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
