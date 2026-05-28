-- 036-phone-security-save-query
-- Phone security fields for the current 7 target tables.
-- Execute with migration-tool guards: skip columns / indexes that already exist.
-- app_phone is intentionally excluded from this change.

-- Check columns before applying DDL.
SELECT TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
    'drh_h5_order',
    'drh_live_user',
    'drh_applet_user',
    'drh_book_question_record',
    'drh_external_book_question_record',
    'drh_book_edit_address_compensation',
    'drh_real_address_record'
  )
  AND COLUMN_NAME IN ('phone_mask', 'phone_md5', 'phone_aes')
ORDER BY TABLE_NAME, COLUMN_NAME;

-- Check phone_md5 indexes before applying DDL.
SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
    'drh_h5_order',
    'drh_live_user',
    'drh_applet_user',
    'drh_book_question_record',
    'drh_external_book_question_record',
    'drh_book_edit_address_compensation',
    'drh_real_address_record'
  )
  AND COLUMN_NAME = 'phone_md5'
ORDER BY TABLE_NAME, INDEX_NAME;

ALTER TABLE drh_h5_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_h5_order_phone_md5 (phone_md5);

ALTER TABLE drh_live_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_live_user_phone_md5 (phone_md5);

ALTER TABLE drh_applet_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_applet_user_phone_md5 (phone_md5);

ALTER TABLE drh_book_question_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_book_q_record_phone_md5 (phone_md5);

ALTER TABLE drh_external_book_question_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_ext_book_q_record_phone_md5 (phone_md5);

ALTER TABLE drh_book_edit_address_compensation
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_book_addr_comp_phone_md5 (phone_md5);

ALTER TABLE drh_real_address_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_real_addr_phone_md5 (phone_md5);
