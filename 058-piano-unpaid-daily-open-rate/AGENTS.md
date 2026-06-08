# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\058-piano-unpaid-daily-open-rate`
- 目标项目：`C:\workspace\ju-chat\qw-user-message-export`
- 相关模块：企微消息 OTS 导出、外部联系人好友关系 OTS 查询、开口率分析与报告输出

## 当前目标

- 新增 `--mode piano-daily-open-rate`，固定统计 2026-05-27 和 2026-06-06 两批钢琴未付费用户。
- 通过 OTS 好友关系 `drh_external_user_info.follow_user` 获取批次实际人数，并与用户提供数量比对。
- 按天输出当日新增开口率和截至当日累计开口率，排除默认建联文案。

## 执行原则

- 先复用 `interaction-rate` 的真实回复判定，再扩展为多批次、逐日和好友关系分母。
- 好友关系主口径使用 `follow_user.userid` 与 `follow_user.createtime`，不引入 MySQL/JDBC 依赖。
- 开口消息仅统计私聊、`isSelf=false`、非回撤、可解析且非默认建联文案的学员侧文本。
- 固定账号、批次日期、提供数量和统计结束日期均在当前模式内显式定义，不从外部文件读取。
- 不修改 `export`、`open-rate`、`open-rate-all`、`activity-rate`、`interaction-rate` 的既有口径和输出文件。

## 强制门禁

- 关键参数必须在调用 OTS 前确定：账号、批次日期、好友关系秒级时间窗、消息毫秒时间窗、批次 external_user_id 集合。
- 下游读取字段必须有来源：好友关系读取 `external_user_id`、`name`、`follow_user`；消息读取 `message_id`、`payload`、`timestamp`、`recall`、`external_user_id`、`contact_name`。
- 不允许空 DTO、空 JSON 或空 Map 作为占位参数继续下传；空集合只表示无数据。
- 新增 OTS 查询必须有单元测试断言 nested 条件和时间窗。
- 单元测试必须覆盖默认建联文案排除、跨天累计、数量差异和输出文件内容。

## 重点代码位置

- `com.juchat.qwexport.MessageExportApp`
- `com.juchat.qwexport.OtsFriendRelationRepository`
- `com.juchat.qwexport.PianoDailyOpenRateAnalyzer`
- `src/test/java/com/juchat/qwexport/*PianoDailyOpenRate*Test.java`

## 文档维护

- `spec.md` 描述业务口径、需求、边界、成功标准和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务和测试结果。
- `checklists/requirements.md` 用于确认规格质量和参数完整性。
