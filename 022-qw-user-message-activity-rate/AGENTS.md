# 规格执行说明

本目录记录 `022-qw-user-message-activity-rate` 的规格与实现约定，后续修改应保持文档与项目代码同步。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\022-qw-user-message-activity-rate`
- 目标项目：`C:\workspace\ju-chat\qw-user-message-export`

## 当前目标

- 规划并实现 `qw-user-message-export` 的 `activity-rate` 模式。
- `activity-rate` 模式读取项目目录下的 `userIds.txt` 销售名单。
- `userIds.txt` 每行一个 `qwUserId`，空行和空白行跳过，重复项默认去重。
- 统计窗口为最近 30 天，按 `Asia/Shanghai` 计算。
- 统计私聊和群聊中的用户侧消息，销售仅发消息但客户未回复的用户计入总数，不计入活跃。
- 输出 `activity_rate_report.csv` 汇总文件和 `activity_rate_report.txt` 明细文件。
- CSV 需要输出每个销售的活跃度，并在末尾输出 `TOTAL` 汇总行，包含总活跃人数和总活跃率。
- TXT 需要输出每个销售的活跃 / 未活跃名单，并保留一条样本消息。
- 现有 `export`、`open-rate`、`open-rate-all` 的开口率口径保持不变。

## 后续实现约束

- 后续实现应复用现有 `MessageExportApp`、`OtsMessageRepository` 和 `UserIdReader` 的基础能力。
- 新模式必须支持 `--mode activity-rate`，并与旧模式并列。
- 新模式必须按 `external_user_id` 维度统计客户活跃度。
- 新模式必须把群聊消息纳入统计，不再限制私聊。
- 新模式必须允许 `isSelf=false` 的用户消息作为活跃信号。
- 新模式必须输出 CSV 和 TXT 两份结果，且不要改变旧模式的输出文件名。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录实现和验证任务。
- `checklists/requirements.md` 用于验证规格质量和实施就绪度。
