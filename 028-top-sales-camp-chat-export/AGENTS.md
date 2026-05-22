# 028-top-sales-camp-chat-export

这个目录只保存“近三期封闭营 Top 销售聊天记录导出”的规格文档。

## 约束

- 这里只做规格沉淀，不创建项目、不新增业务代码、不补测试。
- 任何实现工作都必须等 `spec.md` 和 `checklists/requirements.md` 评审确认后再开始。
- 这个需求的目标是导出销售与学员的完整私聊记录，用于后续 AI Agent 话术训练与策略优化，不是做统计报表。

## 阅读顺序

1. 先看 `spec.md`，确认业务范围、字段定义、时间口径和导出结构。
2. 再看 `tasks.md`，确认哪些只是文档占位，哪些是后续实现任务。
3. 最后看 `checklists/requirements.md`，核对规格是否覆盖了全部关键点。

## 关键术语

- `qwUserId`：销售的企业微信用户 ID，导出消息时对应 `juzi_private_message.user_id`。
- `camp_date_id`：营期内部主键，用于系统侧关联营期配置。
- `camp_id`：导出结果中的营期业务标识，优先按营期配置中的业务编码/名称输出，不直接用数值主键替代。
- `union_id`：学员的统一业务标识，用于订单、标签和消息数据的跨表关联。
- `external_user_id`：学员的企微外部联系人 ID，用于私聊消息查询。

## 已确认的数据来源

- `drh_live_camp_emp`
- `drh_live_camp_date`
- `drh_external_user_info`
- `drh_emp_external_user`
- `juzi_private_message`
- `drh_collect_order`
- `drh_live`

## 需要保持的边界

- 私聊消息只取 `is_group` 为空或 `false` 的记录。
- 群发消息要保留，但由 `message_source` 区分，不需要额外打标。
- `camp_day` 和 `day_phase` 必须按营期配置逐个营期计算，不能用单一全局规则。
- 先导课不参与课前/课中/课后判定。

## 待确认项

- `paid_time` 最终要取订单创建时间、支付时间，还是两者中更权威的字段。
- 封闭营的精确识别条件以哪个营期标识字段为准。
- `drh_live` 中先导课的排除标记字段以哪个字段为准。

