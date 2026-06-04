-- Generated from check-missing-before.json on 2026-06-04.
-- Target profile: dev-mysql (test).
-- Scope: only missing columns / indexes on existing P2 and P3 tables.
-- Excluded: P1 drh_specail_user because the table itself does not exist in the test database.

-- P2-001. drh_ad_count
ALTER TABLE drh_ad_count
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_ad_count_phone_md5 (phone_md5);

-- P2-002. drh_ad_form_answer
ALTER TABLE drh_ad_form_answer
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_ad_form_answer_phone_md5 (phone_md5);

-- P2-003. drh_applet_order
ALTER TABLE drh_applet_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_applet_order_phone_md5 (phone_md5);

-- P2-004. drh_applet_small_user
ALTER TABLE drh_applet_small_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_applet_small_user_phone_md5 (phone_md5);

-- P2-005. drh_goods_user_coupon
ALTER TABLE drh_goods_user_coupon
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_goods_coupon_phone_md5 (phone_md5);

-- P2-006. drh_koc
ALTER TABLE drh_koc
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_koc_phone_md5 (phone_md5);

-- P2-007. drh_order_refund_record
ALTER TABLE drh_order_refund_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_order_refund_phone_md5 (phone_md5);

-- P2-008. drh_qwb_phone_info
ALTER TABLE drh_qwb_phone_info
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_qwb_phone_phone_md5 (phone_md5);

-- P2-009. drh_short_message_operation
ALTER TABLE drh_short_message_operation
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_short_msg_phone_md5 (phone_md5);

-- P2-010. drh_sms_trigger_user_callback
ALTER TABLE drh_sms_trigger_user_callback
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_sms_trigger_cb_phone_md5 (phone_md5);

-- P2-012. drh_xe_order
ALTER TABLE drh_xe_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_xe_order_phone_md5 (phone_md5);

-- P3-001. drh_register_works
ALTER TABLE drh_register_works
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_register_works_phone_md5 (phone_md5);

-- P3-002. drh_sms_deal
ALTER TABLE drh_sms_deal
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_sms_deal_phone_md5 (phone_md5);

-- P3-003. drh_temp_phone
ALTER TABLE drh_temp_phone
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_temp_phone_phone_md5 (phone_md5);

-- P3-004. drh_mall_order
ALTER TABLE drh_mall_order
  ADD COLUMN reciver_phone_mask VARCHAR(32) DEFAULT NULL COMMENT '收货手机号掩码展示值',
  ADD COLUMN reciver_phone_md5 CHAR(32) DEFAULT NULL COMMENT '收货手机号MD5摘要，用于等值查询',
  ADD COLUMN reciver_phone_aes VARCHAR(255) DEFAULT NULL COMMENT '收货手机号AES密文，用于单条结果解密',
  ADD INDEX idx_mall_order_reciver_phone_md5 (reciver_phone_md5);
