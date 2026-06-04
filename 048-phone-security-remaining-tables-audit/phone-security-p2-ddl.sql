-- 048-phone-security-remaining-tables-audit
-- Phone security fields (phone_mask / phone_md5 / phone_aes) for the remaining 12 P2 tables.
-- Execute with migration-tool guards: skip columns / indexes that already exist.
-- MySQL does not natively support ADD COLUMN IF NOT EXISTS;
-- run the pre-check queries below first and skip ALTER statements whose columns/indexes already exist.

-- ============================================================================
-- PRE-CHECK: verify which columns / indexes already exist
-- ============================================================================

-- Check columns before applying DDL.
SELECT TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
    'drh_ad_count',
    'drh_ad_form_answer',
    'drh_applet_order',
    'drh_applet_small_user',
    'drh_goods_user_coupon',
    'drh_koc',
    'drh_order_refund_record',
    'drh_qwb_phone_info',
    'drh_short_message_operation',
    'drh_sms_trigger_user_callback',
    'drh_submit_time',
    'drh_xe_order'
  )
  AND COLUMN_NAME IN ('phone_mask', 'phone_md5', 'phone_aes')
ORDER BY TABLE_NAME, COLUMN_NAME;

-- Check phone_md5 indexes before applying DDL.
SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
    'drh_ad_count',
    'drh_ad_form_answer',
    'drh_applet_order',
    'drh_applet_small_user',
    'drh_goods_user_coupon',
    'drh_koc',
    'drh_order_refund_record',
    'drh_qwb_phone_info',
    'drh_short_message_operation',
    'drh_sms_trigger_user_callback',
    'drh_submit_time',
    'drh_xe_order'
  )
  AND COLUMN_NAME = 'phone_md5'
ORDER BY TABLE_NAME, INDEX_NAME;

-- ============================================================================
-- ALTER TABLE statements (alphabetical order)
-- NOTE: If a pre-check above shows a column or index already exists for a
-- given table, skip that ALTER TABLE statement to avoid duplicate-column errors.
-- ============================================================================

-- 1. drh_ad_count -- 广告计数表，统计各广告投放的计数数据
ALTER TABLE drh_ad_count
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_ad_count_phone_md5 (phone_md5);

-- 2. drh_ad_form_answer -- 广告表单答案表，收集用户通过广告提交的表单回答
ALTER TABLE drh_ad_form_answer
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_ad_form_answer_phone_md5 (phone_md5);

-- 3. drh_applet_order -- 小程序订单表，记录小程序端产生的交易订单
ALTER TABLE drh_applet_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_applet_order_phone_md5 (phone_md5);

-- 4. drh_applet_small_user -- 小程序用户表，存储小程序端注册用户信息
ALTER TABLE drh_applet_small_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_applet_small_user_phone_md5 (phone_md5);

-- 5. drh_goods_user_coupon -- 商品用户优惠券表，记录用户领取的商品优惠券
ALTER TABLE drh_goods_user_coupon
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_goods_coupon_phone_md5 (phone_md5);

-- 6. drh_koc -- KOC(关键意见消费者)表，管理KOC推广人员信息
ALTER TABLE drh_koc
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_koc_phone_md5 (phone_md5);

-- 7. drh_order_refund_record -- 订单退款记录表，记录订单退款流水及处理状态
ALTER TABLE drh_order_refund_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_order_refund_phone_md5 (phone_md5);

-- 8. drh_qwb_phone_info -- 企微宝手机信息表，存储企微宝系统中的手机号关联信息
ALTER TABLE drh_qwb_phone_info
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_qwb_phone_phone_md5 (phone_md5);

-- 9. drh_short_message_operation -- 短信运营表，管理短信营销/运营活动记录
ALTER TABLE drh_short_message_operation
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_short_msg_phone_md5 (phone_md5);

-- 10. drh_sms_trigger_user_callback -- 短信触发用户回调表，记录短信触发后的用户回调事件
ALTER TABLE drh_sms_trigger_user_callback
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_sms_trigger_cb_phone_md5 (phone_md5);

-- 11. drh_submit_time -- 提交时间表，记录用户提交各类业务的时间节点
ALTER TABLE drh_submit_time
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_submit_time_phone_md5 (phone_md5);

-- 12. drh_xe_order -- 小鹅通订单表，记录小鹅通平台的交易订单数据
ALTER TABLE drh_xe_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_xe_order_phone_md5 (phone_md5);

-- ============================================================================
-- POST-CHECK: verify all columns and indexes were created successfully
-- ============================================================================

-- Verify phone_mask / phone_md5 / phone_aes columns exist on all 12 tables.
-- Expected: 36 rows (12 tables x 3 columns). Any missing row indicates a failure.
SELECT t.TABLE_NAME, c_mask.COLUMN_NAME AS phone_mask, c_md5.COLUMN_NAME AS phone_md5, c_aes.COLUMN_NAME AS phone_aes
FROM (
  SELECT 'drh_ad_count' AS TABLE_NAME
  UNION ALL SELECT 'drh_ad_form_answer'
  UNION ALL SELECT 'drh_applet_order'
  UNION ALL SELECT 'drh_applet_small_user'
  UNION ALL SELECT 'drh_goods_user_coupon'
  UNION ALL SELECT 'drh_koc'
  UNION ALL SELECT 'drh_order_refund_record'
  UNION ALL SELECT 'drh_qwb_phone_info'
  UNION ALL SELECT 'drh_short_message_operation'
  UNION ALL SELECT 'drh_sms_trigger_user_callback'
  UNION ALL SELECT 'drh_submit_time'
  UNION ALL SELECT 'drh_xe_order'
) t
LEFT JOIN information_schema.COLUMNS c_mask
  ON c_mask.TABLE_SCHEMA = DATABASE() AND c_mask.TABLE_NAME = t.TABLE_NAME AND c_mask.COLUMN_NAME = 'phone_mask'
LEFT JOIN information_schema.COLUMNS c_md5
  ON c_md5.TABLE_SCHEMA = DATABASE() AND c_md5.TABLE_NAME = t.TABLE_NAME AND c_md5.COLUMN_NAME = 'phone_md5'
LEFT JOIN information_schema.COLUMNS c_aes
  ON c_aes.TABLE_SCHEMA = DATABASE() AND c_aes.TABLE_NAME = t.TABLE_NAME AND c_aes.COLUMN_NAME = 'phone_aes'
ORDER BY t.TABLE_NAME;

-- Verify idx_*_phone_md5 indexes exist on all 12 tables.
-- Expected: 12 rows. Any missing row indicates a failure.
SELECT t.TABLE_NAME, s.INDEX_NAME
FROM (
  SELECT 'drh_ad_count' AS TABLE_NAME, 'idx_ad_count_phone_md5' AS EXPECTED_INDEX
  UNION ALL SELECT 'drh_ad_form_answer',              'idx_ad_form_answer_phone_md5'
  UNION ALL SELECT 'drh_applet_order',                 'idx_applet_order_phone_md5'
  UNION ALL SELECT 'drh_applet_small_user',            'idx_applet_small_user_phone_md5'
  UNION ALL SELECT 'drh_goods_user_coupon',            'idx_goods_coupon_phone_md5'
  UNION ALL SELECT 'drh_koc',                          'idx_koc_phone_md5'
  UNION ALL SELECT 'drh_order_refund_record',          'idx_order_refund_phone_md5'
  UNION ALL SELECT 'drh_qwb_phone_info',               'idx_qwb_phone_phone_md5'
  UNION ALL SELECT 'drh_short_message_operation',      'idx_short_msg_phone_md5'
  UNION ALL SELECT 'drh_sms_trigger_user_callback',    'idx_sms_trigger_cb_phone_md5'
  UNION ALL SELECT 'drh_submit_time',                  'idx_submit_time_phone_md5'
  UNION ALL SELECT 'drh_xe_order',                     'idx_xe_order_phone_md5'
) t
LEFT JOIN information_schema.STATISTICS s
  ON s.TABLE_SCHEMA = DATABASE() AND s.TABLE_NAME = t.TABLE_NAME AND s.INDEX_NAME = t.EXPECTED_INDEX
GROUP BY t.TABLE_NAME, t.EXPECTED_INDEX, s.INDEX_NAME
ORDER BY t.TABLE_NAME;
