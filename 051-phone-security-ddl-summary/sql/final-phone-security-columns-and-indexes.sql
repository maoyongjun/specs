-- Final phone security DDL.
-- The deprecated special-user table is intentionally excluded.
-- Execute section 1 first, then execute section 2 after columns are verified.
-- MySQL does not support a portable ADD COLUMN IF NOT EXISTS syntax; check information_schema before execution.

-- ============================================================================
-- Section 1: add columns only
-- ============================================================================

ALTER TABLE drh_h5_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_live_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD COLUMN app_phone_mask VARCHAR(32) DEFAULT NULL COMMENT 'APP手机号掩码展示值',
  ADD COLUMN app_phone_md5 CHAR(32) DEFAULT NULL COMMENT 'APP手机号MD5摘要，用于等值查询',
  ADD COLUMN app_phone_aes VARCHAR(255) DEFAULT NULL COMMENT 'APP手机号AES密文，用于单条结果解密';

ALTER TABLE drh_applet_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_book_question_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_external_book_question_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_book_edit_address_compensation
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_real_address_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_import_address_record_detail
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '收货手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '收货手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '收货手机号AES密文，用于单条结果解密';

ALTER TABLE drh_user_address
  ADD COLUMN receiver_phone_mask VARCHAR(32) DEFAULT NULL COMMENT '收货人手机号掩码展示值',
  ADD COLUMN receiver_phone_md5 CHAR(32) DEFAULT NULL COMMENT '收货人手机号MD5摘要，用于等值查询',
  ADD COLUMN receiver_phone_aes VARCHAR(255) DEFAULT NULL COMMENT '收货人手机号AES密文，用于单条结果解密';

ALTER TABLE drh_order_user_address
  ADD COLUMN receiver_phone_mask VARCHAR(32) DEFAULT NULL COMMENT '收货人手机号掩码展示值',
  ADD COLUMN receiver_phone_md5 CHAR(32) DEFAULT NULL COMMENT '收货人手机号MD5摘要，用于等值查询',
  ADD COLUMN receiver_phone_aes VARCHAR(255) DEFAULT NULL COMMENT '收货人手机号AES密文，用于单条结果解密';

ALTER TABLE app_study_info
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_app_white
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_applet_black_phone
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_applet_player
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_gx_channel
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_leads_noqw_send_msg_task_detail
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_live_works_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_renew_data
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_sms_trigger_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_sph_supplier_info
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_user_assistant
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_user_form
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_user_service_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_voice_robot_callback_details
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_voice_robot_task_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_wechat_complaint_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE order_book_reissue_detail
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_ad_count
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_ad_form_answer
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_applet_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_applet_small_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_goods_user_coupon
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_koc
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_order_refund_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_qwb_phone_info
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_short_message_operation
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_sms_trigger_user_callback
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_submit_time
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_xe_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_register_works
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_sms_deal
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_temp_phone
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密';

ALTER TABLE drh_mall_order
  ADD COLUMN reciver_phone_mask VARCHAR(32) DEFAULT NULL COMMENT '收货手机号掩码展示值',
  ADD COLUMN reciver_phone_md5 CHAR(32) DEFAULT NULL COMMENT '收货手机号MD5摘要，用于等值查询',
  ADD COLUMN reciver_phone_aes VARCHAR(255) DEFAULT NULL COMMENT '收货手机号AES密文，用于单条结果解密';

-- ============================================================================
-- Section 2: add indexes only
-- ============================================================================

ALTER TABLE drh_h5_order ADD INDEX idx_h5_order_phone_md5 (phone_md5);
ALTER TABLE drh_h5_order ADD INDEX idx_h5_order_phone_aes (phone_aes);

ALTER TABLE drh_live_user ADD INDEX idx_live_user_phone_md5 (phone_md5);
ALTER TABLE drh_live_user ADD INDEX idx_live_user_phone_aes (phone_aes);
ALTER TABLE drh_live_user ADD INDEX idx_live_user_app_phone_md5 (app_phone_md5);
ALTER TABLE drh_live_user ADD INDEX idx_live_user_app_phone_aes (app_phone_aes);

ALTER TABLE drh_applet_user ADD INDEX idx_applet_user_phone_md5 (phone_md5);
ALTER TABLE drh_applet_user ADD INDEX idx_applet_user_phone_aes (phone_aes);

ALTER TABLE drh_book_question_record ADD INDEX idx_book_q_record_phone_md5 (phone_md5);
ALTER TABLE drh_book_question_record ADD INDEX idx_book_q_record_phone_aes (phone_aes);

ALTER TABLE drh_external_book_question_record ADD INDEX idx_ext_book_q_record_phone_md5 (phone_md5);
ALTER TABLE drh_external_book_question_record ADD INDEX idx_ext_book_q_record_phone_aes (phone_aes);

ALTER TABLE drh_book_edit_address_compensation ADD INDEX idx_book_addr_comp_phone_md5 (phone_md5);
ALTER TABLE drh_book_edit_address_compensation ADD INDEX idx_book_addr_comp_phone_aes (phone_aes);

ALTER TABLE drh_real_address_record ADD INDEX idx_real_addr_phone_md5 (phone_md5);
ALTER TABLE drh_real_address_record ADD INDEX idx_real_addr_phone_aes (phone_aes);

ALTER TABLE drh_import_address_record_detail ADD INDEX idx_import_address_detail_phone_md5 (phone_md5);
ALTER TABLE drh_import_address_record_detail ADD INDEX idx_import_address_detail_phone_aes (phone_aes);

ALTER TABLE drh_user_address ADD INDEX idx_user_address_receiver_phone_md5 (receiver_phone_md5);
ALTER TABLE drh_user_address ADD INDEX idx_user_address_receiver_phone_aes (receiver_phone_aes);

ALTER TABLE drh_order_user_address ADD INDEX idx_order_user_address_receiver_phone_md5 (receiver_phone_md5);
ALTER TABLE drh_order_user_address ADD INDEX idx_order_user_address_receiver_phone_aes (receiver_phone_aes);

ALTER TABLE app_study_info ADD INDEX idx_app_study_info_phone_md5 (phone_md5);
ALTER TABLE app_study_info ADD INDEX idx_app_study_info_phone_aes (phone_aes);

ALTER TABLE drh_app_white ADD INDEX idx_app_white_phone_md5 (phone_md5);
ALTER TABLE drh_app_white ADD INDEX idx_app_white_phone_aes (phone_aes);

ALTER TABLE drh_applet_black_phone ADD INDEX idx_applet_black_phone_md5 (phone_md5);
ALTER TABLE drh_applet_black_phone ADD INDEX idx_applet_black_phone_aes (phone_aes);

ALTER TABLE drh_applet_player ADD INDEX idx_applet_player_phone_md5 (phone_md5);
ALTER TABLE drh_applet_player ADD INDEX idx_applet_player_phone_aes (phone_aes);

ALTER TABLE drh_gx_channel ADD INDEX idx_gx_channel_phone_md5 (phone_md5);
ALTER TABLE drh_gx_channel ADD INDEX idx_gx_channel_phone_aes (phone_aes);

ALTER TABLE drh_leads_noqw_send_msg_task_detail ADD INDEX idx_leads_noqw_msg_phone_md5 (phone_md5);
ALTER TABLE drh_leads_noqw_send_msg_task_detail ADD INDEX idx_leads_noqw_msg_phone_aes (phone_aes);

ALTER TABLE drh_live_works_user ADD INDEX idx_live_works_user_phone_md5 (phone_md5);
ALTER TABLE drh_live_works_user ADD INDEX idx_live_works_user_phone_aes (phone_aes);

ALTER TABLE drh_renew_data ADD INDEX idx_renew_data_phone_md5 (phone_md5);
ALTER TABLE drh_renew_data ADD INDEX idx_renew_data_phone_aes (phone_aes);

ALTER TABLE drh_sms_trigger_user ADD INDEX idx_sms_trigger_phone_md5 (phone_md5);
ALTER TABLE drh_sms_trigger_user ADD INDEX idx_sms_trigger_phone_aes (phone_aes);

ALTER TABLE drh_sph_supplier_info ADD INDEX idx_sph_supplier_phone_md5 (phone_md5);
ALTER TABLE drh_sph_supplier_info ADD INDEX idx_sph_supplier_phone_aes (phone_aes);

ALTER TABLE drh_user ADD INDEX idx_user_phone_md5 (phone_md5);
ALTER TABLE drh_user ADD INDEX idx_user_phone_aes (phone_aes);

ALTER TABLE drh_user_assistant ADD INDEX idx_user_assistant_phone_md5 (phone_md5);
ALTER TABLE drh_user_assistant ADD INDEX idx_user_assistant_phone_aes (phone_aes);

ALTER TABLE drh_user_form ADD INDEX idx_user_form_phone_md5 (phone_md5);
ALTER TABLE drh_user_form ADD INDEX idx_user_form_phone_aes (phone_aes);

ALTER TABLE drh_user_service_record ADD INDEX idx_user_svc_record_phone_md5 (phone_md5);
ALTER TABLE drh_user_service_record ADD INDEX idx_user_svc_record_phone_aes (phone_aes);

ALTER TABLE drh_voice_robot_callback_details ADD INDEX idx_vr_callback_phone_md5 (phone_md5);
ALTER TABLE drh_voice_robot_callback_details ADD INDEX idx_vr_callback_phone_aes (phone_aes);

ALTER TABLE drh_voice_robot_task_user ADD INDEX idx_vr_task_user_phone_md5 (phone_md5);
ALTER TABLE drh_voice_robot_task_user ADD INDEX idx_vr_task_user_phone_aes (phone_aes);

ALTER TABLE drh_wechat_complaint_order ADD INDEX idx_wechat_complaint_phone_md5 (phone_md5);
ALTER TABLE drh_wechat_complaint_order ADD INDEX idx_wechat_complaint_phone_aes (phone_aes);

ALTER TABLE order_book_reissue_detail ADD INDEX idx_book_reissue_phone_md5 (phone_md5);
ALTER TABLE order_book_reissue_detail ADD INDEX idx_book_reissue_phone_aes (phone_aes);

ALTER TABLE drh_ad_count ADD INDEX idx_ad_count_phone_md5 (phone_md5);
ALTER TABLE drh_ad_count ADD INDEX idx_ad_count_phone_aes (phone_aes);

ALTER TABLE drh_ad_form_answer ADD INDEX idx_ad_form_answer_phone_md5 (phone_md5);
ALTER TABLE drh_ad_form_answer ADD INDEX idx_ad_form_answer_phone_aes (phone_aes);

ALTER TABLE drh_applet_order ADD INDEX idx_applet_order_phone_md5 (phone_md5);
ALTER TABLE drh_applet_order ADD INDEX idx_applet_order_phone_aes (phone_aes);

ALTER TABLE drh_applet_small_user ADD INDEX idx_applet_small_user_phone_md5 (phone_md5);
ALTER TABLE drh_applet_small_user ADD INDEX idx_applet_small_user_phone_aes (phone_aes);

ALTER TABLE drh_goods_user_coupon ADD INDEX idx_goods_coupon_phone_md5 (phone_md5);
ALTER TABLE drh_goods_user_coupon ADD INDEX idx_goods_coupon_phone_aes (phone_aes);

ALTER TABLE drh_koc ADD INDEX idx_koc_phone_md5 (phone_md5);
ALTER TABLE drh_koc ADD INDEX idx_koc_phone_aes (phone_aes);

ALTER TABLE drh_order_refund_record ADD INDEX idx_order_refund_phone_md5 (phone_md5);
ALTER TABLE drh_order_refund_record ADD INDEX idx_order_refund_phone_aes (phone_aes);

ALTER TABLE drh_qwb_phone_info ADD INDEX idx_qwb_phone_phone_md5 (phone_md5);
ALTER TABLE drh_qwb_phone_info ADD INDEX idx_qwb_phone_phone_aes (phone_aes);

ALTER TABLE drh_short_message_operation ADD INDEX idx_short_msg_phone_md5 (phone_md5);
ALTER TABLE drh_short_message_operation ADD INDEX idx_short_msg_phone_aes (phone_aes);

ALTER TABLE drh_sms_trigger_user_callback ADD INDEX idx_sms_trigger_cb_phone_md5 (phone_md5);
ALTER TABLE drh_sms_trigger_user_callback ADD INDEX idx_sms_trigger_cb_phone_aes (phone_aes);

ALTER TABLE drh_submit_time ADD INDEX idx_submit_time_phone_md5 (phone_md5);
ALTER TABLE drh_submit_time ADD INDEX idx_submit_time_phone_aes (phone_aes);

ALTER TABLE drh_xe_order ADD INDEX idx_xe_order_phone_md5 (phone_md5);
ALTER TABLE drh_xe_order ADD INDEX idx_xe_order_phone_aes (phone_aes);

ALTER TABLE drh_register_works ADD INDEX idx_register_works_phone_md5 (phone_md5);
ALTER TABLE drh_register_works ADD INDEX idx_register_works_phone_aes (phone_aes);

ALTER TABLE drh_sms_deal ADD INDEX idx_sms_deal_phone_md5 (phone_md5);
ALTER TABLE drh_sms_deal ADD INDEX idx_sms_deal_phone_aes (phone_aes);

ALTER TABLE drh_temp_phone ADD INDEX idx_temp_phone_phone_md5 (phone_md5);
ALTER TABLE drh_temp_phone ADD INDEX idx_temp_phone_phone_aes (phone_aes);

ALTER TABLE drh_mall_order ADD INDEX idx_mall_order_reciver_phone_md5 (reciver_phone_md5);
ALTER TABLE drh_mall_order ADD INDEX idx_mall_order_reciver_phone_aes (reciver_phone_aes);
