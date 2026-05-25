# 028-top-sales-camp-chat-export

本目录保存“近三期封闭营 Top 销售聊天记录导出”的规格、任务拆分和执行记录。对应独立实现项目位于 `C:\workspace\ju-chat\top-sales-camp-chat-export`。

## 状态

- 文档与实现已回填完成，不再是纯文档占位阶段。
- 后续新增需求、纠正或字段变化，必须先更新 `spec.md`，再同步 `tasks.md` 和 `checklists/requirements.md`。

## 阅读顺序

1. 先看 `spec.md`，确认业务范围、字段定义、时间口径和导出结构。
2. 再看 `tasks.md`，确认事实确认、风险门禁、实现拆分、测试验证和执行记录。
3. 最后看 `checklists/requirements.md`，核对规格是否覆盖全部关键点，以及实现是否已验收。

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

## 维护原则

- `spec.md` 记录需求、实现口径、成功标准、假设和残余风险。
- `tasks.md` 记录事实确认、风险门禁、实现拆分、测试验证和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户补充、纠正或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
