# Requirements Checklist

- [x] 已明确需求目标：导出 Top 销售近 3 期封闭营的完整私聊记录。
- [x] 已列出 9 位目标销售姓名。
- [x] 已区分 `qwUserId`、`camp_date_id`、`camp_id`、`union_id`、`external_user_id`。
- [x] 已说明营期范围取近 3 期已结束的封闭营。
- [x] 已说明消息来源于 `juzi_private_message`，且仅过滤真正的群聊消息。
- [x] 已说明 `is_group` 为空或 `false` 的私聊消息保留。
- [x] 已说明标签来源于 `drh_external_user_info`，并复用同一次查询结果做营期与日标签判断。
- [x] 已说明订单来源于 `drh_collect_order`，并支持按 `union_id` 批量查询。
- [x] 已定义 `camp_day` 的取值与计算口径。
- [x] 已定义 `day_phase` 的取值、时间范围与边界优先级。
- [x] 已定义 `user_attend_today`、`user_complete_today`、`user_hw_today`、`user_total_attend`、`user_paid`、`paid_time`，且按消息时间截面计算。
- [x] 已定义导出排序规则：`camp_id + union_id + timestamp`。
- [x] 已定义两级文件夹输出结构：销售昵称 / 营期名称。
- [x] 已记录待确认项，包括 `paid_time` 权威来源、封闭营识别条件与先导课排除字段。
- [x] 已明确当前阶段只做规格文档，不创建项目、不写实现代码。
