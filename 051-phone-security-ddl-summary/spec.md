# 手机号加密整改表 DDL 汇总

**功能目录**：`051-phone-security-ddl-summary`  
**创建日期**：`2026-06-04`  
**状态**：Draft  
**用途**：汇总手机号加密整改涉及表的 DDL，按 P1 / P2 / P3 分级编号，供数据库变更、回填和测试核对使用。

## 来源

- `032-phone-security-columns/add-phone-security-columns.sql`：核心 6 张表字段扩展，包含 `drh_live_user.app_phone_*`。
- `036-phone-security-save-query/phone-security-d006.sql`：核心 7 张表补齐，追加 `drh_real_address_record`。
- `048-phone-security-remaining-tables-audit/phone-security-p1-ddl.sql`：P1 扩展 19 张表。
- `048-phone-security-remaining-tables-audit/phone-security-p2-ddl.sql`：P2 扩展 12 张表。
- 用户本次补充的 12 张表 DDL：与 `phone-security-p2-ddl.sql` 一致。
- `050-phone-security-interface-db-mapping` D003：用户地址 `drh_user_address` 与作品集订单地址 `drh_order_user_address`。
- `048-phone-security-remaining-tables-audit/spec.md`：P3 待确认表清单。
- `data-RC/juzi-service/.../PhoneSecurityBackfillService.java`：当前回填目标清单，已接入 P1 + P2 共 40 个实际回填目标（`drh_specail_user` 保持注释不执行）。

## 分级口径

| 级别 | 口径 | 本文档覆盖 |
|------|------|------------|
| P1 | 核心业务表，或明文手机号清空后等值 / 批量查询直接失效的表 | 28 张表，29 个手机号字段组（`drh_live_user` 含 `phone` 与 `app_phone`） |
| P2 | 有手机号写入链路，需同步生成 `phone_mask/phone_md5/phone_aes`，但当前无关键等值查询 | 12 张表 |
| P3 | LIKE / NULL 判断 / 展示 / 日志 / 临时表 / 非标准手机号字段，需业务确认后再执行 | 4 张表建议 DDL |

执行前必须通过 `information_schema.COLUMNS` 和 `information_schema.STATISTICS` 检查字段、索引是否已存在。MySQL 不支持通用的 `ADD COLUMN IF NOT EXISTS` 语法，已存在的表必须跳过对应 `ALTER TABLE`，避免重复字段或索引报错。

## 编号清单

| 编号 | 级别 | 表名 | 原手机号字段 | 新增字段 | 索引 | 来源 / 备注 |
|------|------|------|--------------|----------|------|-------------|
| P1-001 | P1 | `drh_h5_order` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_h5_order_phone_md5` | 032/036 |
| P1-002 | P1 | `drh_live_user` | `phone`, `app_phone` | `phone_*`, `app_phone_*` | `idx_live_user_phone_md5`, `idx_live_user_app_phone_md5` | 032/036；`app_phone` 仅历史回填 |
| P1-003 | P1 | `drh_applet_user` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_applet_user_phone_md5` | 032/036 |
| P1-004 | P1 | `drh_book_question_record` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_book_q_record_phone_md5` | 032/036 |
| P1-005 | P1 | `drh_external_book_question_record` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_ext_book_q_record_phone_md5` | 032/036 |
| P1-006 | P1 | `drh_book_edit_address_compensation` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_book_addr_comp_phone_md5` | 032/036 |
| P1-007 | P1 | `drh_real_address_record` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_real_addr_phone_md5` | 036 |
| P1-008 | P1 | `app_study_info` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_app_study_info_phone_md5` | 048 P1 |
| P1-009 | P1 | `drh_app_white` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_app_white_phone_md5` | 048 P1 |
| P1-010 | P1 | `drh_applet_black_phone` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_applet_black_phone_md5` | 048 P1 |
| P1-011 | P1 | `drh_applet_player` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_applet_player_phone_md5` | 048 P1 |
| P1-012 | P1 | `drh_gx_channel` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_gx_channel_phone_md5` | 048 P1 |
| P1-013 | P1 | `drh_leads_noqw_send_msg_task_detail` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_leads_noqw_msg_phone_md5` | 048 P1 |
| P1-014 | P1 | `drh_live_works_user` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_live_works_user_phone_md5` | 048 P1 |
| P1-015 | P1 | `drh_renew_data` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_renew_data_phone_md5` | 048 P1 |
| P1-016 | P1 | `drh_sms_trigger_user` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_sms_trigger_phone_md5` | 048 P1 |
| P1-017 | P1 | `drh_specail_user` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_specail_user_phone_md5` | 048 P1 DDL 与回填清单均包含 |
| P1-018 | P1 | `drh_sph_supplier_info` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_sph_supplier_phone_md5` | 048 P1 |
| P1-019 | P1 | `drh_user` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_user_phone_md5` | 048 P1 |
| P1-020 | P1 | `drh_user_assistant` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_user_assistant_phone_md5` | 048 P1 |
| P1-021 | P1 | `drh_user_form` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_user_form_phone_md5` | 048 P1 |
| P1-022 | P1 | `drh_user_service_record` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_user_svc_record_phone_md5` | 048 P1 |
| P1-023 | P1 | `drh_voice_robot_callback_details` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_vr_callback_phone_md5` | 048 P1 |
| P1-024 | P1 | `drh_voice_robot_task_user` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_vr_task_user_phone_md5` | 048 P1 |
| P1-025 | P1 | `drh_wechat_complaint_order` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_wechat_complaint_phone_md5` | 048 P1 |
| P1-026 | P1 | `order_book_reissue_detail` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_book_reissue_phone_md5` | 048 P1 |
| P1-027 | P1 | `drh_user_address` | `receiver_phone` | `receiver_phone_mask`, `receiver_phone_md5`, `receiver_phone_aes` | `idx_user_address_receiver_phone_md5` | 用户补充 / D003 |
| P1-028 | P1 | `drh_order_user_address` | `receiver_phone` | `receiver_phone_mask`, `receiver_phone_md5`, `receiver_phone_aes` | `idx_order_user_address_receiver_phone_md5` | 用户补充 / D003 |
| P2-001 | P2 | `drh_ad_count` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_ad_count_phone_md5` | 用户补充 / 048 P2 |
| P2-002 | P2 | `drh_ad_form_answer` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_ad_form_answer_phone_md5` | 用户补充 / 048 P2 |
| P2-003 | P2 | `drh_applet_order` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_applet_order_phone_md5` | 用户补充 / 048 P2 |
| P2-004 | P2 | `drh_applet_small_user` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_applet_small_user_phone_md5` | 用户补充 / 048 P2 |
| P2-005 | P2 | `drh_goods_user_coupon` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_goods_coupon_phone_md5` | 用户补充 / 048 P2 |
| P2-006 | P2 | `drh_koc` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_koc_phone_md5` | 用户补充 / 048 P2 |
| P2-007 | P2 | `drh_order_refund_record` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_order_refund_phone_md5` | 用户补充 / 048 P2 |
| P2-008 | P2 | `drh_qwb_phone_info` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_qwb_phone_phone_md5` | 用户补充 / 048 P2 |
| P2-009 | P2 | `drh_short_message_operation` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_short_msg_phone_md5` | 用户补充 / 048 P2 |
| P2-010 | P2 | `drh_sms_trigger_user_callback` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_sms_trigger_cb_phone_md5` | 用户补充 / 048 P2 |
| P2-011 | P2 | `drh_submit_time` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_submit_time_phone_md5` | 用户补充 / 048 P2 |
| P2-012 | P2 | `drh_xe_order` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_xe_order_phone_md5` | 用户补充 / 048 P2 |
| P3-001 | P3 | `drh_register_works` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_register_works_phone_md5` | LIKE 查询，待确认 |
| P3-002 | P3 | `drh_sms_deal` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_sms_deal_phone_md5` | 日志 / INSERT 表，待确认 |
| P3-003 | P3 | `drh_temp_phone` | `phone` | `phone_mask`, `phone_md5`, `phone_aes` | `idx_temp_phone_phone_md5` | 临时表 / JOIN，待确认 |
| P3-004 | P3 | `drh_mall_order` | `reciver_phone` | `reciver_phone_mask`, `reciver_phone_md5`, `reciver_phone_aes` | `idx_mall_order_reciver_phone_md5` | 非标准字段名，待确认 |

## 缺失 / 差异记录

- `048-phone-security-remaining-tables-audit/spec.md` 曾将 `drh_import_address_record_detail` 标为 P1，但 `phone-security-p1-ddl.sql` 未生成该表 DDL，执行记录说明“实体类在 drh 工程中未找到，跳过”。本次代码搜索也未在 `C:\workspace\drh` / `C:\workspace\ju-chat` 找到该表或实体引用。暂不纳入 DDL 执行清单，如数据库确认存在且仍需按手机号查询，应另行补充 DDL。
- `050-phone-security-interface-db-mapping/spec.md` 将 `drh_specail_user` 写为关联辅助表，但实际 P1 DDL 和 `PhoneSecurityBackfillService` 均已包含 `drh_specail_user`。本文档按实际 DDL 与回填目标保留为 P1-017。
- D003 新增的 `drh_user_address` 和 `drh_order_user_address` 源字段为 `receiver_phone`，安全字段沿用源字段前缀 `receiver_phone_*`，索引列为 `receiver_phone_md5`。
- 附件中 `drh_live_user.app_phone_*` 曾出现 `NOT NULL DEFAULT ''` 口径；前置正式规格 `032-phone-security-columns` 使用 `DEFAULT NULL` 和索引 `idx_live_user_app_phone_md5`。本文档以 `032` 正式 DDL 为准。

## 执行前检查模板

```sql
-- 检查目标字段是否已存在：TABLE_NAME 列表按待执行级别替换
SELECT TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('<table_name>')
  AND COLUMN_NAME IN (
    'phone_mask', 'phone_md5', 'phone_aes',
    'app_phone_mask', 'app_phone_md5', 'app_phone_aes',
    'receiver_phone_mask', 'receiver_phone_md5', 'receiver_phone_aes',
    'reciver_phone_mask', 'reciver_phone_md5', 'reciver_phone_aes'
  )
ORDER BY TABLE_NAME, COLUMN_NAME;

-- 检查目标索引是否已存在：TABLE_NAME 列表按待执行级别替换
SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('<table_name>')
  AND COLUMN_NAME IN ('phone_md5', 'app_phone_md5', 'receiver_phone_md5', 'reciver_phone_md5')
ORDER BY TABLE_NAME, INDEX_NAME;
```

## P1 DDL

```sql
-- P1-001. drh_h5_order -- H5 图书订单表
ALTER TABLE drh_h5_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_h5_order_phone_md5 (phone_md5);

-- P1-002. drh_live_user -- 学员表；phone 在线改造，app_phone 仅历史回填
ALTER TABLE drh_live_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD COLUMN app_phone_mask VARCHAR(32) DEFAULT NULL COMMENT 'APP手机号掩码展示值',
  ADD COLUMN app_phone_md5 CHAR(32) DEFAULT NULL COMMENT 'APP手机号MD5摘要，用于等值查询',
  ADD COLUMN app_phone_aes VARCHAR(255) DEFAULT NULL COMMENT 'APP手机号AES密文，用于单条结果解密',
  ADD INDEX idx_live_user_phone_md5 (phone_md5),
  ADD INDEX idx_live_user_app_phone_md5 (app_phone_md5);

-- P1-003. drh_applet_user -- 小程序线索表
ALTER TABLE drh_applet_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_applet_user_phone_md5 (phone_md5);

-- P1-004. drh_book_question_record -- 图书登记留资表
ALTER TABLE drh_book_question_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_book_q_record_phone_md5 (phone_md5);

-- P1-005. drh_external_book_question_record -- 图书登记非留资表
ALTER TABLE drh_external_book_question_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_ext_book_q_record_phone_md5 (phone_md5);

-- P1-006. drh_book_edit_address_compensation -- 图书地址补偿表
ALTER TABLE drh_book_edit_address_compensation
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_book_addr_comp_phone_md5 (phone_md5);

-- P1-007. drh_real_address_record -- 真实地址记录表
ALTER TABLE drh_real_address_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_real_addr_phone_md5 (phone_md5);

-- P1-008. app_study_info -- 学习信息表，记录用户课程学习数据
ALTER TABLE app_study_info
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_app_study_info_phone_md5 (phone_md5);

-- P1-009. drh_app_white -- 应用白名单表，维护允许访问的手机号白名单
ALTER TABLE drh_app_white
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_app_white_phone_md5 (phone_md5);

-- P1-010. drh_applet_black_phone -- 小程序黑名单表
ALTER TABLE drh_applet_black_phone
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_applet_black_phone_md5 (phone_md5);

-- P1-011. drh_applet_player -- 小程序玩家表
ALTER TABLE drh_applet_player
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_applet_player_phone_md5 (phone_md5);

-- P1-012. drh_gx_channel -- 渠道信息表
ALTER TABLE drh_gx_channel
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_gx_channel_phone_md5 (phone_md5);

-- P1-013. drh_leads_noqw_send_msg_task_detail -- 非企微线索短信发送明细表
ALTER TABLE drh_leads_noqw_send_msg_task_detail
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_leads_noqw_msg_phone_md5 (phone_md5);

-- P1-014. drh_live_works_user -- 直播作品用户表
ALTER TABLE drh_live_works_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_live_works_user_phone_md5 (phone_md5);

-- P1-015. drh_renew_data -- 续费数据表
ALTER TABLE drh_renew_data
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_renew_data_phone_md5 (phone_md5);

-- P1-016. drh_sms_trigger_user -- 短信触发用户表
ALTER TABLE drh_sms_trigger_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_sms_trigger_phone_md5 (phone_md5);

-- P1-017. drh_specail_user -- 特殊用户表
ALTER TABLE drh_specail_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_specail_user_phone_md5 (phone_md5);

-- P1-018. drh_sph_supplier_info -- 视频号供应商信息表
ALTER TABLE drh_sph_supplier_info
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_sph_supplier_phone_md5 (phone_md5);

-- P1-019. drh_user -- 用户主表
ALTER TABLE drh_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_user_phone_md5 (phone_md5);

-- P1-020. drh_user_assistant -- 用户助理表
ALTER TABLE drh_user_assistant
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_user_assistant_phone_md5 (phone_md5);

-- P1-021. drh_user_form -- 用户表单表
ALTER TABLE drh_user_form
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_user_form_phone_md5 (phone_md5);

-- P1-022. drh_user_service_record -- 用户服务记录表
ALTER TABLE drh_user_service_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_user_svc_record_phone_md5 (phone_md5);

-- P1-023. drh_voice_robot_callback_details -- 语音机器人回调明细表
ALTER TABLE drh_voice_robot_callback_details
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_vr_callback_phone_md5 (phone_md5);

-- P1-024. drh_voice_robot_task_user -- 语音机器人任务用户表
ALTER TABLE drh_voice_robot_task_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_vr_task_user_phone_md5 (phone_md5);

-- P1-025. drh_wechat_complaint_order -- 微信投诉工单表
ALTER TABLE drh_wechat_complaint_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_wechat_complaint_phone_md5 (phone_md5);

-- P1-026. order_book_reissue_detail -- 图书补发订单明细表
ALTER TABLE order_book_reissue_detail
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_book_reissue_phone_md5 (phone_md5);

-- P1-027. drh_user_address -- 用户收货地址表
ALTER TABLE drh_user_address
  ADD COLUMN receiver_phone_mask VARCHAR(32) DEFAULT NULL COMMENT '收货人手机号掩码展示值',
  ADD COLUMN receiver_phone_md5 CHAR(32) DEFAULT NULL COMMENT '收货人手机号MD5摘要，用于等值查询',
  ADD COLUMN receiver_phone_aes VARCHAR(255) DEFAULT NULL COMMENT '收货人手机号AES密文，用于单条结果解密',
  ADD INDEX idx_user_address_receiver_phone_md5 (receiver_phone_md5);

-- P1-028. drh_order_user_address -- 作品集订单收货地址表
ALTER TABLE drh_order_user_address
  ADD COLUMN receiver_phone_mask VARCHAR(32) DEFAULT NULL COMMENT '收货人手机号掩码展示值',
  ADD COLUMN receiver_phone_md5 CHAR(32) DEFAULT NULL COMMENT '收货人手机号MD5摘要，用于等值查询',
  ADD COLUMN receiver_phone_aes VARCHAR(255) DEFAULT NULL COMMENT '收货人手机号AES密文，用于单条结果解密',
  ADD INDEX idx_order_user_address_receiver_phone_md5 (receiver_phone_md5);
```

## P2 DDL

```sql
-- P2-001. drh_ad_count -- 广告计数表，统计各广告投放的计数数据
ALTER TABLE drh_ad_count
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_ad_count_phone_md5 (phone_md5);

-- P2-002. drh_ad_form_answer -- 广告表单答案表，收集用户通过广告提交的表单回答
ALTER TABLE drh_ad_form_answer
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_ad_form_answer_phone_md5 (phone_md5);

-- P2-003. drh_applet_order -- 小程序订单表，记录小程序端产生的交易订单
ALTER TABLE drh_applet_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_applet_order_phone_md5 (phone_md5);

-- P2-004. drh_applet_small_user -- 小程序用户表，存储小程序端注册用户信息
ALTER TABLE drh_applet_small_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_applet_small_user_phone_md5 (phone_md5);

-- P2-005. drh_goods_user_coupon -- 商品用户优惠券表，记录用户领取的商品优惠券
ALTER TABLE drh_goods_user_coupon
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_goods_coupon_phone_md5 (phone_md5);

-- P2-006. drh_koc -- KOC 表，管理 KOC 推广人员信息
ALTER TABLE drh_koc
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_koc_phone_md5 (phone_md5);

-- P2-007. drh_order_refund_record -- 订单退款记录表
ALTER TABLE drh_order_refund_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_order_refund_phone_md5 (phone_md5);

-- P2-008. drh_qwb_phone_info -- 企微宝手机信息表
ALTER TABLE drh_qwb_phone_info
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_qwb_phone_phone_md5 (phone_md5);

-- P2-009. drh_short_message_operation -- 短信运营表
ALTER TABLE drh_short_message_operation
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_short_msg_phone_md5 (phone_md5);

-- P2-010. drh_sms_trigger_user_callback -- 短信触发用户回调表
ALTER TABLE drh_sms_trigger_user_callback
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_sms_trigger_cb_phone_md5 (phone_md5);

-- P2-011. drh_submit_time -- 提交时间表
ALTER TABLE drh_submit_time
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_submit_time_phone_md5 (phone_md5);

-- P2-012. drh_xe_order -- 小鹅通订单表
ALTER TABLE drh_xe_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_xe_order_phone_md5 (phone_md5);
```

## P3 建议 DDL

P3 表历史文档标注为“需业务确认”。以下 DDL 只作为确认后执行的建议口径，不纳入当前 `PhoneSecurityBackfillService` 回填目标。

```sql
-- P3-001. drh_register_works -- 注册作品表；当前存在 phone LIKE 查询
ALTER TABLE drh_register_works
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_register_works_phone_md5 (phone_md5);

-- P3-002. drh_sms_deal -- 短信处理记录表；日志 / INSERT 类手机号
ALTER TABLE drh_sms_deal
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_sms_deal_phone_md5 (phone_md5);

-- P3-003. drh_temp_phone -- 临时手机号表；当前作为 JOIN 排除临时号码
ALTER TABLE drh_temp_phone
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_temp_phone_phone_md5 (phone_md5);

-- P3-004. drh_mall_order -- 商城订单表；原字段名为 reciver_phone，沿用现有拼写
ALTER TABLE drh_mall_order
  ADD COLUMN reciver_phone_mask VARCHAR(32) DEFAULT NULL COMMENT '收货手机号掩码展示值',
  ADD COLUMN reciver_phone_md5 CHAR(32) DEFAULT NULL COMMENT '收货手机号MD5摘要，用于等值查询',
  ADD COLUMN reciver_phone_aes VARCHAR(255) DEFAULT NULL COMMENT '收货手机号AES密文，用于单条结果解密',
  ADD INDEX idx_mall_order_reciver_phone_md5 (reciver_phone_md5);
```

## 后续执行说明

- P1 / P2 的 DDL 已有前置规格和回填目标支撑，可按环境字段存在情况分批执行。
- P3 执行前需先确认业务搜索方案：MD5 只支持精确匹配，不支持原 `LIKE` 模糊搜索。
- DDL 执行后需要同步确认实体字段、Mapper 查询、Service 保存链路和历史回填目标，否则只加字段不能完成手机号安全整改。
- 生产执行建议按 P1 核心表、P1 扩展表、P2 表、P3 确认表分批上线，并在每批后执行字段 / 索引验证与回填抽样检查。
