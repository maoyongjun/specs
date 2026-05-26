-- 手机号安全字段 DDL
-- 创建日期：2026-05-26
-- 注意：执行前需确认目标环境不存在同名字段和同名索引；本脚本不做历史数据回填。

ALTER TABLE drh_h5_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_h5_order_phone_md5 (phone_md5);

ALTER TABLE drh_live_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD COLUMN app_phone_mask VARCHAR(32) DEFAULT NULL COMMENT 'APP手机号掩码展示值',
  ADD COLUMN app_phone_md5 CHAR(32) DEFAULT NULL COMMENT 'APP手机号MD5摘要，用于等值查询',
  ADD COLUMN app_phone_aes VARCHAR(255) DEFAULT NULL COMMENT 'APP手机号AES密文，用于单条结果解密',
  ADD INDEX idx_live_user_phone_md5 (phone_md5),
  ADD INDEX idx_live_user_app_phone_md5 (app_phone_md5);

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
