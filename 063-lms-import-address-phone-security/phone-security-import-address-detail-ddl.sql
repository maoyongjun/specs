-- drh_import_address_record_detail 手机号安全字段补充
-- 执行前先检查字段和索引是否已存在，MySQL 不支持通用 ADD COLUMN IF NOT EXISTS。

SELECT TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'drh_import_address_record_detail'
  AND COLUMN_NAME IN ('phone_mask', 'phone_md5', 'phone_aes')
ORDER BY TABLE_NAME, COLUMN_NAME;

SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'drh_import_address_record_detail'
  AND COLUMN_NAME = 'phone_md5'
ORDER BY TABLE_NAME, INDEX_NAME;

ALTER TABLE drh_import_address_record_detail
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '收货手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '收货手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '收货手机号AES密文，用于单条结果解密',
  ADD INDEX idx_import_address_detail_phone_md5 (phone_md5);
