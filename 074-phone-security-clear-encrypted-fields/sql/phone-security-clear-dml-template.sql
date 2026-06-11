-- DML template for database-sql-skill analyze only.
-- Do not run this file directly for production cleanup.
-- Batch size represented in template: 500

-- drh_h5_order.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_h5_order`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_h5_order`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_live_user.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_live_user`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_live_user`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_live_user.app_phone
-- Candidate condition: app_phone_md5 is not null and not empty.
UPDATE `drh_live_user`
SET `app_phone_mask` = NULL, `app_phone_md5` = NULL, `app_phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_live_user`
    WHERE `app_phone_md5` IS NOT NULL AND `app_phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_applet_user.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_applet_user`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_applet_user`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_book_question_record.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_book_question_record`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_book_question_record`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_external_book_question_record.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_external_book_question_record`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_external_book_question_record`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_book_edit_address_compensation.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_book_edit_address_compensation`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_book_edit_address_compensation`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_real_address_record.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_real_address_record`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_real_address_record`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_import_address_record_detail.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_import_address_record_detail`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_import_address_record_detail`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_user_address.receiver_phone
-- Candidate condition: receiver_phone_md5 is not null and not empty.
UPDATE `drh_user_address`
SET `receiver_phone_mask` = NULL, `receiver_phone_md5` = NULL, `receiver_phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_user_address`
    WHERE `receiver_phone_md5` IS NOT NULL AND `receiver_phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_order_user_address.receiver_phone
-- Candidate condition: receiver_phone_md5 is not null and not empty.
UPDATE `drh_order_user_address`
SET `receiver_phone_mask` = NULL, `receiver_phone_md5` = NULL, `receiver_phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_order_user_address`
    WHERE `receiver_phone_md5` IS NOT NULL AND `receiver_phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- app_study_info.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `app_study_info`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `app_study_info`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_app_white.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_app_white`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_app_white`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_applet_black_phone.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_applet_black_phone`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_applet_black_phone`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_applet_player.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_applet_player`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_applet_player`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_gx_channel.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_gx_channel`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_gx_channel`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_leads_noqw_send_msg_task_detail.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_leads_noqw_send_msg_task_detail`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_leads_noqw_send_msg_task_detail`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_live_works_user.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_live_works_user`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_live_works_user`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_renew_data.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_renew_data`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_renew_data`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_sms_trigger_user.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_sms_trigger_user`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_sms_trigger_user`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_sph_supplier_info.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_sph_supplier_info`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_sph_supplier_info`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_user.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_user`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_user`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_user_assistant.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_user_assistant`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_user_assistant`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_user_form.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_user_form`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_user_form`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_user_service_record.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_user_service_record`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_user_service_record`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_voice_robot_callback_details.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_voice_robot_callback_details`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_voice_robot_callback_details`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_voice_robot_task_user.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_voice_robot_task_user`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_voice_robot_task_user`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_wechat_complaint_order.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_wechat_complaint_order`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_wechat_complaint_order`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- order_book_reissue_detail.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `order_book_reissue_detail`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `order_book_reissue_detail`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_ad_count.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_ad_count`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_ad_count`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_ad_form_answer.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_ad_form_answer`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_ad_form_answer`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_applet_order.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_applet_order`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_applet_order`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_applet_small_user.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_applet_small_user`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_applet_small_user`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_goods_user_coupon.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_goods_user_coupon`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_goods_user_coupon`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_koc.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_koc`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_koc`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_order_refund_record.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_order_refund_record`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_order_refund_record`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_qwb_phone_info.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_qwb_phone_info`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_qwb_phone_info`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_short_message_operation.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_short_message_operation`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_short_message_operation`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_sms_trigger_user_callback.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_sms_trigger_user_callback`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_sms_trigger_user_callback`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_submit_time.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_submit_time`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_submit_time`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_xe_order.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_xe_order`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_xe_order`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_register_works.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_register_works`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_register_works`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_sms_deal.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_sms_deal`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_sms_deal`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_temp_phone.phone
-- Candidate condition: phone_md5 is not null and not empty.
UPDATE `drh_temp_phone`
SET `phone_mask` = NULL, `phone_md5` = NULL, `phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_temp_phone`
    WHERE `phone_md5` IS NOT NULL AND `phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);

-- drh_mall_order.reciver_phone
-- Candidate condition: reciver_phone_md5 is not null and not empty.
UPDATE `drh_mall_order`
SET `reciver_phone_mask` = NULL, `reciver_phone_md5` = NULL, `reciver_phone_aes` = NULL
WHERE `id` IN (
  SELECT `id` FROM (
    SELECT `id` FROM `drh_mall_order`
    WHERE `reciver_phone_md5` IS NOT NULL AND `reciver_phone_md5` <> ''
    ORDER BY `id`
    LIMIT 500
  ) AS batch_ids
);
