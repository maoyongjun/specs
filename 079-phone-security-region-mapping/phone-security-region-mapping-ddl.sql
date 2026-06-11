-- 手机号安全字段与省市映射表
-- 注意：本表不保存明文手机号，也不保存 segment。

CREATE TABLE IF NOT EXISTS drh_phone_security_region (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  phone_mask VARCHAR(32) NOT NULL COMMENT '手机号掩码展示值',
  phone_md5 CHAR(32) NOT NULL COMMENT '手机号MD5摘要，用于唯一幂等判断',
  phone_aes VARCHAR(255) NOT NULL COMMENT '手机号AES密文',
  province VARCHAR(64) NOT NULL DEFAULT '' COMMENT '省',
  city VARCHAR(64) NOT NULL DEFAULT '' COMMENT '城市',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_phone_md5 (phone_md5),
  KEY idx_province_city (province, city)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='手机号安全字段与省市映射表';

-- 元数据检查：确认本表不存在 segment 字段
SELECT TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'drh_phone_security_region'
  AND COLUMN_NAME = 'segment';

-- 元数据检查：确认索引存在
SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME, NON_UNIQUE
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'drh_phone_security_region'
ORDER BY INDEX_NAME, SEQ_IN_INDEX;
