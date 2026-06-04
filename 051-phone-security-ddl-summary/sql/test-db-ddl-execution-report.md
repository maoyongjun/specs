# 测试库手机号安全字段 DDL 执行报告

**执行日期**：2026-06-04  
**执行 profile**：`dev-mysql`  
**数据库环境**：`test`  
**数据库**：`drh`  
**技能**：`database-sql-skill`

## 执行文件

- 检查 SQL：`check-phone-security-ddl-status.sql`
- 执行前缺失结果：`check-missing-before.json`
- 缺失项 DDL：`add-missing-phone-security-columns-test.sql`
- DDL 执行结果：`add-missing-result.json`
- 执行后复检结果：`check-missing-after.json`

## 执行前缺失项

| 级别 | 表 | 缺失对象 |
|------|----|----------|
| P1 | `drh_specail_user` | 表本身不存在，未执行字段添加 |
| P2 | `drh_ad_count` | `phone_mask`、`phone_md5`、`phone_aes`、`idx_ad_count_phone_md5` |
| P2 | `drh_ad_form_answer` | `phone_mask`、`phone_md5`、`phone_aes`、`idx_ad_form_answer_phone_md5` |
| P2 | `drh_applet_order` | `phone_mask`、`phone_md5`、`phone_aes`、`idx_applet_order_phone_md5` |
| P2 | `drh_applet_small_user` | `phone_mask`、`phone_md5`、`phone_aes`、`idx_applet_small_user_phone_md5` |
| P2 | `drh_goods_user_coupon` | `phone_mask`、`phone_md5`、`phone_aes`、`idx_goods_coupon_phone_md5` |
| P2 | `drh_koc` | `phone_mask`、`phone_md5`、`phone_aes`、`idx_koc_phone_md5` |
| P2 | `drh_order_refund_record` | `phone_mask`、`phone_md5`、`phone_aes`、`idx_order_refund_phone_md5` |
| P2 | `drh_qwb_phone_info` | `phone_mask`、`phone_md5`、`phone_aes`、`idx_qwb_phone_phone_md5` |
| P2 | `drh_short_message_operation` | `phone_mask`、`phone_md5`、`phone_aes`、`idx_short_msg_phone_md5` |
| P2 | `drh_sms_trigger_user_callback` | `phone_mask`、`phone_md5`、`phone_aes`、`idx_sms_trigger_cb_phone_md5` |
| P2 | `drh_xe_order` | `phone_mask`、`phone_md5`、`phone_aes`、`idx_xe_order_phone_md5` |
| P3 | `drh_register_works` | `phone_mask`、`phone_md5`、`phone_aes`、`idx_register_works_phone_md5` |
| P3 | `drh_sms_deal` | `phone_mask`、`phone_md5`、`phone_aes`、`idx_sms_deal_phone_md5` |
| P3 | `drh_temp_phone` | `phone_mask`、`phone_md5`、`phone_aes`、`idx_temp_phone_phone_md5` |
| P3 | `drh_mall_order` | `reciver_phone_mask`、`reciver_phone_md5`、`reciver_phone_aes`、`idx_mall_order_reciver_phone_md5` |

`drh_submit_time` 未出现在缺失清单中，说明测试库执行前已具备 `phone_mask`、`phone_md5`、`phone_aes` 和 `idx_submit_time_phone_md5`。

## 已执行添加

已通过 `database-sql-skill` 执行 `add-missing-phone-security-columns-test.sql`，补齐以下现存表的字段和索引：

- P2：`drh_ad_count`、`drh_ad_form_answer`、`drh_applet_order`、`drh_applet_small_user`、`drh_goods_user_coupon`、`drh_koc`、`drh_order_refund_record`、`drh_qwb_phone_info`、`drh_short_message_operation`、`drh_sms_trigger_user_callback`、`drh_xe_order`
- P3：`drh_register_works`、`drh_sms_deal`、`drh_temp_phone`、`drh_mall_order`

## 执行后复检

执行后重新运行 `check-phone-security-ddl-status.sql`，剩余缺失项只有：

| 级别 | 表 | 缺失对象 | 处理结论 |
|------|----|----------|----------|
| P1 | `drh_specail_user` | 表本身不存在 | 无法添加字段；需确认测试库是否应该存在该表 |

除 `drh_specail_user` 表不存在外，测试库中所有已存在的 P1、P2、P3 表均已具备目标手机号安全字段和对应 MD5 索引。
