-- Generated from final-phone-security-ddl-and-indexes.sql on 2026-06-10.
-- Purpose: report missing target tables, columns, and named indexes in the current database.

SELECT object_type, table_name, object_name, expected_definition, existing_equivalent_index
FROM (
  SELECT 'TABLE' AS object_type,
         et.table_name,
         et.table_name AS object_name,
         'target table must exist before ALTER TABLE' AS expected_definition,
         NULL AS existing_equivalent_index,
         1 AS sort_group
  FROM (
    SELECT 'drh_h5_order' AS table_name
    UNION ALL SELECT 'drh_live_user'
    UNION ALL SELECT 'drh_applet_user'
    UNION ALL SELECT 'drh_book_question_record'
    UNION ALL SELECT 'drh_external_book_question_record'
    UNION ALL SELECT 'drh_book_edit_address_compensation'
    UNION ALL SELECT 'drh_real_address_record'
    UNION ALL SELECT 'drh_import_address_record_detail'
    UNION ALL SELECT 'drh_user_address'
    UNION ALL SELECT 'drh_order_user_address'
    UNION ALL SELECT 'app_study_info'
    UNION ALL SELECT 'drh_app_white'
    UNION ALL SELECT 'drh_applet_black_phone'
    UNION ALL SELECT 'drh_applet_player'
    UNION ALL SELECT 'drh_gx_channel'
    UNION ALL SELECT 'drh_leads_noqw_send_msg_task_detail'
    UNION ALL SELECT 'drh_live_works_user'
    UNION ALL SELECT 'drh_renew_data'
    UNION ALL SELECT 'drh_sms_trigger_user'
    UNION ALL SELECT 'drh_sph_supplier_info'
    UNION ALL SELECT 'drh_user'
    UNION ALL SELECT 'drh_user_assistant'
    UNION ALL SELECT 'drh_user_form'
    UNION ALL SELECT 'drh_user_service_record'
    UNION ALL SELECT 'drh_voice_robot_callback_details'
    UNION ALL SELECT 'drh_voice_robot_task_user'
    UNION ALL SELECT 'drh_wechat_complaint_order'
    UNION ALL SELECT 'order_book_reissue_detail'
    UNION ALL SELECT 'drh_ad_count'
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
    UNION ALL SELECT 'drh_register_works'
    UNION ALL SELECT 'drh_sms_deal'
    UNION ALL SELECT 'drh_temp_phone'
    UNION ALL SELECT 'drh_mall_order'
  ) et
  LEFT JOIN information_schema.TABLES t
    ON t.TABLE_SCHEMA = DATABASE()
   AND t.TABLE_NAME = et.table_name
  WHERE t.TABLE_NAME IS NULL

  UNION ALL

  SELECT 'COLUMN' AS object_type,
         ec.table_name,
         ec.column_name AS object_name,
         CONCAT('ADD COLUMN ', ec.column_name, ' ', ec.column_def) AS expected_definition,
         NULL AS existing_equivalent_index,
         2 AS sort_group
  FROM (
    SELECT 'drh_h5_order' AS table_name, 'phone_mask' AS column_name, 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值''' AS column_def
    UNION ALL SELECT 'drh_h5_order', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_h5_order', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_live_user', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_live_user', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_live_user', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_live_user', 'app_phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''APP手机号掩码展示值'''
    UNION ALL SELECT 'drh_live_user', 'app_phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''APP手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_live_user', 'app_phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''APP手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_applet_user', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_applet_user', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_applet_user', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_book_question_record', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_book_question_record', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_book_question_record', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_external_book_question_record', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_external_book_question_record', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_external_book_question_record', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_book_edit_address_compensation', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_book_edit_address_compensation', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_book_edit_address_compensation', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_real_address_record', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_real_address_record', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_real_address_record', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_import_address_record_detail', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''收货手机号掩码展示值'''
    UNION ALL SELECT 'drh_import_address_record_detail', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''收货手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_import_address_record_detail', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''收货手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_user_address', 'receiver_phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''收货人手机号掩码展示值'''
    UNION ALL SELECT 'drh_user_address', 'receiver_phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''收货人手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_user_address', 'receiver_phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''收货人手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_order_user_address', 'receiver_phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''收货人手机号掩码展示值'''
    UNION ALL SELECT 'drh_order_user_address', 'receiver_phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''收货人手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_order_user_address', 'receiver_phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''收货人手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'app_study_info', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'app_study_info', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'app_study_info', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_app_white', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_app_white', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_app_white', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_applet_black_phone', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_applet_black_phone', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_applet_black_phone', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_applet_player', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_applet_player', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_applet_player', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_gx_channel', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_gx_channel', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_gx_channel', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_leads_noqw_send_msg_task_detail', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_leads_noqw_send_msg_task_detail', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_leads_noqw_send_msg_task_detail', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_live_works_user', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_live_works_user', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_live_works_user', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_renew_data', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_renew_data', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_renew_data', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_sms_trigger_user', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_sms_trigger_user', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_sms_trigger_user', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_sph_supplier_info', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_sph_supplier_info', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_sph_supplier_info', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_user', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_user', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_user', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_user_assistant', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_user_assistant', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_user_assistant', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_user_form', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_user_form', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_user_form', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_user_service_record', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_user_service_record', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_user_service_record', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_voice_robot_callback_details', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_voice_robot_callback_details', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_voice_robot_callback_details', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_voice_robot_task_user', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_voice_robot_task_user', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_voice_robot_task_user', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_wechat_complaint_order', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_wechat_complaint_order', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_wechat_complaint_order', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'order_book_reissue_detail', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'order_book_reissue_detail', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'order_book_reissue_detail', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_ad_count', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_ad_count', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_ad_count', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_ad_form_answer', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_ad_form_answer', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_ad_form_answer', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_applet_order', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_applet_order', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_applet_order', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_applet_small_user', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_applet_small_user', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_applet_small_user', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_goods_user_coupon', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_goods_user_coupon', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_goods_user_coupon', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_koc', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_koc', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_koc', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_order_refund_record', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_order_refund_record', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_order_refund_record', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_qwb_phone_info', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_qwb_phone_info', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_qwb_phone_info', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_short_message_operation', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_short_message_operation', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_short_message_operation', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_sms_trigger_user_callback', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_sms_trigger_user_callback', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_sms_trigger_user_callback', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_submit_time', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_submit_time', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_submit_time', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_xe_order', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_xe_order', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_xe_order', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_register_works', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_register_works', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_register_works', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_sms_deal', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_sms_deal', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_sms_deal', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_temp_phone', 'phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''手机号掩码展示值'''
    UNION ALL SELECT 'drh_temp_phone', 'phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_temp_phone', 'phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''手机号AES密文，用于单条结果解密'''
    UNION ALL SELECT 'drh_mall_order', 'reciver_phone_mask', 'VARCHAR(32) DEFAULT NULL COMMENT ''收货手机号掩码展示值'''
    UNION ALL SELECT 'drh_mall_order', 'reciver_phone_md5', 'CHAR(32) DEFAULT NULL COMMENT ''收货手机号MD5摘要，用于等值查询'''
    UNION ALL SELECT 'drh_mall_order', 'reciver_phone_aes', 'VARCHAR(255) DEFAULT NULL COMMENT ''收货手机号AES密文，用于单条结果解密'''
  ) ec
  JOIN information_schema.TABLES t
    ON t.TABLE_SCHEMA = DATABASE()
   AND t.TABLE_NAME = ec.table_name
  LEFT JOIN information_schema.COLUMNS c
    ON c.TABLE_SCHEMA = DATABASE()
   AND c.TABLE_NAME = ec.table_name
   AND c.COLUMN_NAME = ec.column_name
  WHERE c.COLUMN_NAME IS NULL

  UNION ALL

  SELECT 'INDEX' AS object_type,
         ei.table_name,
         ei.index_name AS object_name,
         CONCAT('ADD INDEX ', ei.index_name, ' (', ei.column_name, ')') AS expected_definition,
         same_col.same_column_indexes AS existing_equivalent_index,
         3 AS sort_group
  FROM (
    SELECT 'drh_h5_order' AS table_name, 'idx_h5_order_phone_md5' AS index_name, 'phone_md5' AS column_name
    UNION ALL SELECT 'drh_h5_order', 'idx_h5_order_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_live_user', 'idx_live_user_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_live_user', 'idx_live_user_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_live_user', 'idx_live_user_app_phone_md5', 'app_phone_md5'
    UNION ALL SELECT 'drh_live_user', 'idx_live_user_app_phone_aes', 'app_phone_aes'
    UNION ALL SELECT 'drh_applet_user', 'idx_applet_user_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_applet_user', 'idx_applet_user_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_book_question_record', 'idx_book_q_record_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_book_question_record', 'idx_book_q_record_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_external_book_question_record', 'idx_ext_book_q_record_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_external_book_question_record', 'idx_ext_book_q_record_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_book_edit_address_compensation', 'idx_book_addr_comp_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_book_edit_address_compensation', 'idx_book_addr_comp_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_real_address_record', 'idx_real_addr_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_real_address_record', 'idx_real_addr_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_import_address_record_detail', 'idx_import_address_detail_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_import_address_record_detail', 'idx_import_address_detail_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_user_address', 'idx_user_address_receiver_phone_md5', 'receiver_phone_md5'
    UNION ALL SELECT 'drh_user_address', 'idx_user_address_receiver_phone_aes', 'receiver_phone_aes'
    UNION ALL SELECT 'drh_order_user_address', 'idx_order_user_address_receiver_phone_md5', 'receiver_phone_md5'
    UNION ALL SELECT 'drh_order_user_address', 'idx_order_user_address_receiver_phone_aes', 'receiver_phone_aes'
    UNION ALL SELECT 'app_study_info', 'idx_app_study_info_phone_md5', 'phone_md5'
    UNION ALL SELECT 'app_study_info', 'idx_app_study_info_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_app_white', 'idx_app_white_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_app_white', 'idx_app_white_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_applet_black_phone', 'idx_applet_black_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_applet_black_phone', 'idx_applet_black_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_applet_player', 'idx_applet_player_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_applet_player', 'idx_applet_player_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_gx_channel', 'idx_gx_channel_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_gx_channel', 'idx_gx_channel_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_leads_noqw_send_msg_task_detail', 'idx_leads_noqw_msg_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_leads_noqw_send_msg_task_detail', 'idx_leads_noqw_msg_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_live_works_user', 'idx_live_works_user_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_live_works_user', 'idx_live_works_user_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_renew_data', 'idx_renew_data_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_renew_data', 'idx_renew_data_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_sms_trigger_user', 'idx_sms_trigger_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_sms_trigger_user', 'idx_sms_trigger_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_sph_supplier_info', 'idx_sph_supplier_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_sph_supplier_info', 'idx_sph_supplier_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_user', 'idx_user_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_user', 'idx_user_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_user_assistant', 'idx_user_assistant_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_user_assistant', 'idx_user_assistant_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_user_form', 'idx_user_form_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_user_form', 'idx_user_form_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_user_service_record', 'idx_user_svc_record_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_user_service_record', 'idx_user_svc_record_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_voice_robot_callback_details', 'idx_vr_callback_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_voice_robot_callback_details', 'idx_vr_callback_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_voice_robot_task_user', 'idx_vr_task_user_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_voice_robot_task_user', 'idx_vr_task_user_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_wechat_complaint_order', 'idx_wechat_complaint_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_wechat_complaint_order', 'idx_wechat_complaint_phone_aes', 'phone_aes'
    UNION ALL SELECT 'order_book_reissue_detail', 'idx_book_reissue_phone_md5', 'phone_md5'
    UNION ALL SELECT 'order_book_reissue_detail', 'idx_book_reissue_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_ad_count', 'idx_ad_count_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_ad_count', 'idx_ad_count_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_ad_form_answer', 'idx_ad_form_answer_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_ad_form_answer', 'idx_ad_form_answer_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_applet_order', 'idx_applet_order_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_applet_order', 'idx_applet_order_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_applet_small_user', 'idx_applet_small_user_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_applet_small_user', 'idx_applet_small_user_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_goods_user_coupon', 'idx_goods_coupon_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_goods_user_coupon', 'idx_goods_coupon_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_koc', 'idx_koc_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_koc', 'idx_koc_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_order_refund_record', 'idx_order_refund_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_order_refund_record', 'idx_order_refund_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_qwb_phone_info', 'idx_qwb_phone_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_qwb_phone_info', 'idx_qwb_phone_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_short_message_operation', 'idx_short_msg_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_short_message_operation', 'idx_short_msg_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_sms_trigger_user_callback', 'idx_sms_trigger_cb_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_sms_trigger_user_callback', 'idx_sms_trigger_cb_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_submit_time', 'idx_submit_time_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_submit_time', 'idx_submit_time_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_xe_order', 'idx_xe_order_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_xe_order', 'idx_xe_order_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_register_works', 'idx_register_works_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_register_works', 'idx_register_works_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_sms_deal', 'idx_sms_deal_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_sms_deal', 'idx_sms_deal_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_temp_phone', 'idx_temp_phone_phone_md5', 'phone_md5'
    UNION ALL SELECT 'drh_temp_phone', 'idx_temp_phone_phone_aes', 'phone_aes'
    UNION ALL SELECT 'drh_mall_order', 'idx_mall_order_reciver_phone_md5', 'reciver_phone_md5'
    UNION ALL SELECT 'drh_mall_order', 'idx_mall_order_reciver_phone_aes', 'reciver_phone_aes'
  ) ei
  JOIN information_schema.TABLES t
    ON t.TABLE_SCHEMA = DATABASE()
   AND t.TABLE_NAME = ei.table_name
  LEFT JOIN information_schema.STATISTICS s
    ON s.TABLE_SCHEMA = DATABASE()
   AND s.TABLE_NAME = ei.table_name
   AND s.INDEX_NAME = ei.index_name
   AND s.COLUMN_NAME = ei.column_name
   AND s.SEQ_IN_INDEX = 1
  LEFT JOIN (
    SELECT TABLE_NAME,
           COLUMN_NAME,
           GROUP_CONCAT(DISTINCT INDEX_NAME ORDER BY INDEX_NAME SEPARATOR ',') AS same_column_indexes
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND SEQ_IN_INDEX = 1
    GROUP BY TABLE_NAME, COLUMN_NAME
  ) same_col
    ON same_col.TABLE_NAME = ei.table_name
   AND same_col.COLUMN_NAME = ei.column_name
  WHERE s.INDEX_NAME IS NULL
) missing_objects
ORDER BY table_name, sort_group, object_name;
