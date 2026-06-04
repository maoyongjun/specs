-- 048-phone-security-remaining-tables-audit
-- Phone security fields (phone_mask / phone_md5 / phone_aes) for the remaining 19 P1 tables.
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
    'app_study_info',
    'drh_app_white',
    'drh_applet_black_phone',
    'drh_applet_player',
    'drh_gx_channel',
    'drh_leads_noqw_send_msg_task_detail',
    'drh_live_works_user',
    'drh_renew_data',
    'drh_sms_trigger_user',
    'drh_specail_user',
    'drh_sph_supplier_info',
    'drh_user',
    'drh_user_assistant',
    'drh_user_form',
    'drh_user_service_record',
    'drh_voice_robot_callback_details',
    'drh_voice_robot_task_user',
    'drh_wechat_complaint_order',
    'order_book_reissue_detail'
  )
  AND COLUMN_NAME IN ('phone_mask', 'phone_md5', 'phone_aes')
ORDER BY TABLE_NAME, COLUMN_NAME;

-- Check phone_md5 indexes before applying DDL.
SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
    'app_study_info',
    'drh_app_white',
    'drh_applet_black_phone',
    'drh_applet_player',
    'drh_gx_channel',
    'drh_leads_noqw_send_msg_task_detail',
    'drh_live_works_user',
    'drh_renew_data',
    'drh_sms_trigger_user',
    'drh_specail_user',
    'drh_sph_supplier_info',
    'drh_user',
    'drh_user_assistant',
    'drh_user_form',
    'drh_user_service_record',
    'drh_voice_robot_callback_details',
    'drh_voice_robot_task_user',
    'drh_wechat_complaint_order',
    'order_book_reissue_detail'
  )
  AND COLUMN_NAME = 'phone_md5'
ORDER BY TABLE_NAME, INDEX_NAME;

-- ============================================================================
-- ALTER TABLE statements (alphabetical order)
-- NOTE: If a pre-check above shows a column or index already exists for a
-- given table, skip that ALTER TABLE statement to avoid duplicate-column errors.
-- ============================================================================

-- 1. app_study_info -- 学习信息表，记录用户课程学习数据
ALTER TABLE app_study_info
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_app_study_info_phone_md5 (phone_md5);

-- 2. drh_app_white -- 应用白名单表，维护允许访问的手机号白名单
ALTER TABLE drh_app_white
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_app_white_phone_md5 (phone_md5);

-- 3. drh_applet_black_phone -- 小程序黑名单表，记录被拉黑的小程序用户手机号
ALTER TABLE drh_applet_black_phone
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_applet_black_phone_md5 (phone_md5);

-- 4. drh_applet_player -- 小程序玩家表，存储小程序游戏玩家信息
ALTER TABLE drh_applet_player
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_applet_player_phone_md5 (phone_md5);

-- 5. drh_gx_channel -- 渠道信息表，管理各推广渠道及其联系方式
ALTER TABLE drh_gx_channel
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_gx_channel_phone_md5 (phone_md5);

-- 6. drh_leads_noqw_send_msg_task_detail -- 非企微线索短信发送明细表，记录短信任务逐条发送结果
ALTER TABLE drh_leads_noqw_send_msg_task_detail
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_leads_noqw_msg_phone_md5 (phone_md5);

-- 7. drh_live_works_user -- 直播作品用户表，关联直播/短视频作品与互动用户
ALTER TABLE drh_live_works_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_live_works_user_phone_md5 (phone_md5);

-- 8. drh_renew_data -- 续费数据表，跟踪用户续费/续约记录
ALTER TABLE drh_renew_data
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_renew_data_phone_md5 (phone_md5);

-- 9. drh_sms_trigger_user -- 短信触发用户表，记录触发短信发送的用户事件
ALTER TABLE drh_sms_trigger_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_sms_trigger_phone_md5 (phone_md5);

-- 10. drh_specail_user -- 特殊用户表，维护享有特殊权益或标记的用户
ALTER TABLE drh_specail_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_specail_user_phone_md5 (phone_md5);

-- 11. drh_sph_supplier_info -- 视频号供应商信息表，管理视频号业务供应商资料
ALTER TABLE drh_sph_supplier_info
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_sph_supplier_phone_md5 (phone_md5);

-- 12. drh_user -- 用户主表，存储平台核心用户信息
ALTER TABLE drh_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_user_phone_md5 (phone_md5);

-- 13. drh_user_assistant -- 用户助理表，记录用户绑定的专属助理/顾问
ALTER TABLE drh_user_assistant
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_user_assistant_phone_md5 (phone_md5);

-- 14. drh_user_form -- 用户表单表，收集用户填写的各类业务表单
ALTER TABLE drh_user_form
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_user_form_phone_md5 (phone_md5);

-- 15. drh_user_service_record -- 用户服务记录表，记录客服/售后服务流水
ALTER TABLE drh_user_service_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_user_svc_record_phone_md5 (phone_md5);

-- 16. drh_voice_robot_callback_details -- 语音机器人回调明细表，存储外呼回调的详细结果
ALTER TABLE drh_voice_robot_callback_details
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_vr_callback_phone_md5 (phone_md5);

-- 17. drh_voice_robot_task_user -- 语音机器人任务用户表，关联外呼任务与目标用户
ALTER TABLE drh_voice_robot_task_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_vr_task_user_phone_md5 (phone_md5);

-- 18. drh_wechat_complaint_order -- 微信投诉工单表，记录微信渠道用户投诉及处理状态
ALTER TABLE drh_wechat_complaint_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_wechat_complaint_phone_md5 (phone_md5);

-- 19. order_book_reissue_detail -- 图书补发订单明细表，记录图书补发逐条明细
ALTER TABLE order_book_reissue_detail
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_book_reissue_phone_md5 (phone_md5);

-- ============================================================================
-- POST-CHECK: verify all columns and indexes were created successfully
-- ============================================================================

-- Verify phone_mask / phone_md5 / phone_aes columns exist on all 19 tables.
-- Expected: 57 rows (19 tables x 3 columns). Any missing row indicates a failure.
SELECT t.TABLE_NAME, c_mask.COLUMN_NAME AS phone_mask, c_md5.COLUMN_NAME AS phone_md5, c_aes.COLUMN_NAME AS phone_aes
FROM (
  SELECT 'app_study_info' AS TABLE_NAME
  UNION ALL SELECT 'drh_app_white'
  UNION ALL SELECT 'drh_applet_black_phone'
  UNION ALL SELECT 'drh_applet_player'
  UNION ALL SELECT 'drh_gx_channel'
  UNION ALL SELECT 'drh_leads_noqw_send_msg_task_detail'
  UNION ALL SELECT 'drh_live_works_user'
  UNION ALL SELECT 'drh_renew_data'
  UNION ALL SELECT 'drh_sms_trigger_user'
  UNION ALL SELECT 'drh_specail_user'
  UNION ALL SELECT 'drh_sph_supplier_info'
  UNION ALL SELECT 'drh_user'
  UNION ALL SELECT 'drh_user_assistant'
  UNION ALL SELECT 'drh_user_form'
  UNION ALL SELECT 'drh_user_service_record'
  UNION ALL SELECT 'drh_voice_robot_callback_details'
  UNION ALL SELECT 'drh_voice_robot_task_user'
  UNION ALL SELECT 'drh_wechat_complaint_order'
  UNION ALL SELECT 'order_book_reissue_detail'
) t
LEFT JOIN information_schema.COLUMNS c_mask
  ON c_mask.TABLE_SCHEMA = DATABASE() AND c_mask.TABLE_NAME = t.TABLE_NAME AND c_mask.COLUMN_NAME = 'phone_mask'
LEFT JOIN information_schema.COLUMNS c_md5
  ON c_md5.TABLE_SCHEMA = DATABASE() AND c_md5.TABLE_NAME = t.TABLE_NAME AND c_md5.COLUMN_NAME = 'phone_md5'
LEFT JOIN information_schema.COLUMNS c_aes
  ON c_aes.TABLE_SCHEMA = DATABASE() AND c_aes.TABLE_NAME = t.TABLE_NAME AND c_aes.COLUMN_NAME = 'phone_aes'
ORDER BY t.TABLE_NAME;

-- Verify idx_*_phone_md5 indexes exist on all 19 tables.
-- Expected: 19 rows. Any missing row indicates a failure.
SELECT t.TABLE_NAME, s.INDEX_NAME
FROM (
  SELECT 'app_study_info' AS TABLE_NAME, 'idx_app_study_info_phone_md5' AS EXPECTED_INDEX
  UNION ALL SELECT 'drh_app_white',              'idx_app_white_phone_md5'
  UNION ALL SELECT 'drh_applet_black_phone',     'idx_applet_black_phone_md5'
  UNION ALL SELECT 'drh_applet_player',          'idx_applet_player_phone_md5'
  UNION ALL SELECT 'drh_gx_channel',             'idx_gx_channel_phone_md5'
  UNION ALL SELECT 'drh_leads_noqw_send_msg_task_detail', 'idx_leads_noqw_msg_phone_md5'
  UNION ALL SELECT 'drh_live_works_user',        'idx_live_works_user_phone_md5'
  UNION ALL SELECT 'drh_renew_data',             'idx_renew_data_phone_md5'
  UNION ALL SELECT 'drh_sms_trigger_user',       'idx_sms_trigger_phone_md5'
  UNION ALL SELECT 'drh_specail_user',           'idx_specail_user_phone_md5'
  UNION ALL SELECT 'drh_sph_supplier_info',      'idx_sph_supplier_phone_md5'
  UNION ALL SELECT 'drh_user',                   'idx_user_phone_md5'
  UNION ALL SELECT 'drh_user_assistant',         'idx_user_assistant_phone_md5'
  UNION ALL SELECT 'drh_user_form',              'idx_user_form_phone_md5'
  UNION ALL SELECT 'drh_user_service_record',    'idx_user_svc_record_phone_md5'
  UNION ALL SELECT 'drh_voice_robot_callback_details', 'idx_vr_callback_phone_md5'
  UNION ALL SELECT 'drh_voice_robot_task_user',  'idx_vr_task_user_phone_md5'
  UNION ALL SELECT 'drh_wechat_complaint_order', 'idx_wechat_complaint_phone_md5'
  UNION ALL SELECT 'order_book_reissue_detail',  'idx_book_reissue_phone_md5'
) t
LEFT JOIN information_schema.STATISTICS s
  ON s.TABLE_SCHEMA = DATABASE() AND s.TABLE_NAME = t.TABLE_NAME AND s.INDEX_NAME = t.EXPECTED_INDEX
GROUP BY t.TABLE_NAME, t.EXPECTED_INDEX, s.INDEX_NAME
ORDER BY t.TABLE_NAME;
