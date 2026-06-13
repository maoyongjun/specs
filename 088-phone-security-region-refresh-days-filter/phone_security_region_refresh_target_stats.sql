SELECT
  t.target_name,
  t.table_name,
  t.source_column,
  t.row_count,
  GROUP_CONCAT(
    CASE
      WHEN c.data_type IN ('datetime', 'timestamp', 'date')
       AND (
            LOWER(c.column_name) IN (
              'create_time',
              'createtime',
              'created_at',
              'createdat',
              'created_time',
              'createdtime',
              'gmt_create',
              'create_date',
              'created_date',
              'add_time',
              'addtime'
            )
            OR LOWER(c.column_name) LIKE '%create%'
       )
      THEN CONCAT(c.column_name, ':', c.data_type)
      ELSE NULL
    END
    ORDER BY c.ordinal_position
    SEPARATOR ','
  ) AS candidate_time_columns
FROM (
  SELECT 'drh_h5_order.phone' AS target_name, 'drh_h5_order' AS table_name, 'phone' AS source_column, COUNT(*) AS row_count FROM `drh_h5_order`
  UNION ALL SELECT 'drh_live_user.phone', 'drh_live_user', 'phone', COUNT(*) FROM `drh_live_user`
  UNION ALL SELECT 'drh_live_user.app_phone', 'drh_live_user', 'app_phone', COUNT(*) FROM `drh_live_user`
  UNION ALL SELECT 'drh_applet_user.phone', 'drh_applet_user', 'phone', COUNT(*) FROM `drh_applet_user`
  UNION ALL SELECT 'drh_book_question_record.phone', 'drh_book_question_record', 'phone', COUNT(*) FROM `drh_book_question_record`
  UNION ALL SELECT 'drh_external_book_question_record.phone', 'drh_external_book_question_record', 'phone', COUNT(*) FROM `drh_external_book_question_record`
  UNION ALL SELECT 'drh_book_edit_address_compensation.phone', 'drh_book_edit_address_compensation', 'phone', COUNT(*) FROM `drh_book_edit_address_compensation`
  UNION ALL SELECT 'drh_real_address_record.phone', 'drh_real_address_record', 'phone', COUNT(*) FROM `drh_real_address_record`
  UNION ALL SELECT 'drh_import_address_record_detail.phone', 'drh_import_address_record_detail', 'phone', COUNT(*) FROM `drh_import_address_record_detail`
  UNION ALL SELECT 'drh_user_address.receiver_phone', 'drh_user_address', 'receiver_phone', COUNT(*) FROM `drh_user_address`
  UNION ALL SELECT 'drh_order_user_address.receiver_phone', 'drh_order_user_address', 'receiver_phone', COUNT(*) FROM `drh_order_user_address`
  UNION ALL SELECT 'app_study_info.phone', 'app_study_info', 'phone', COUNT(*) FROM `app_study_info`
  UNION ALL SELECT 'drh_app_white.phone', 'drh_app_white', 'phone', COUNT(*) FROM `drh_app_white`
  UNION ALL SELECT 'drh_applet_black_phone.phone', 'drh_applet_black_phone', 'phone', COUNT(*) FROM `drh_applet_black_phone`
  UNION ALL SELECT 'drh_applet_player.phone', 'drh_applet_player', 'phone', COUNT(*) FROM `drh_applet_player`
  UNION ALL SELECT 'drh_gx_channel.phone', 'drh_gx_channel', 'phone', COUNT(*) FROM `drh_gx_channel`
  UNION ALL SELECT 'drh_leads_noqw_send_msg_task_detail.phone', 'drh_leads_noqw_send_msg_task_detail', 'phone', COUNT(*) FROM `drh_leads_noqw_send_msg_task_detail`
  UNION ALL SELECT 'drh_live_works_user.phone', 'drh_live_works_user', 'phone', COUNT(*) FROM `drh_live_works_user`
  UNION ALL SELECT 'drh_renew_data.phone', 'drh_renew_data', 'phone', COUNT(*) FROM `drh_renew_data`
  UNION ALL SELECT 'drh_sms_trigger_user.phone', 'drh_sms_trigger_user', 'phone', COUNT(*) FROM `drh_sms_trigger_user`
  UNION ALL SELECT 'drh_sph_supplier_info.phone', 'drh_sph_supplier_info', 'phone', COUNT(*) FROM `drh_sph_supplier_info`
  UNION ALL SELECT 'drh_user.phone', 'drh_user', 'phone', COUNT(*) FROM `drh_user`
  UNION ALL SELECT 'drh_user_assistant.phone', 'drh_user_assistant', 'phone', COUNT(*) FROM `drh_user_assistant`
  UNION ALL SELECT 'drh_user_form.phone', 'drh_user_form', 'phone', COUNT(*) FROM `drh_user_form`
  UNION ALL SELECT 'drh_user_service_record.phone', 'drh_user_service_record', 'phone', COUNT(*) FROM `drh_user_service_record`
  UNION ALL SELECT 'drh_voice_robot_callback_details.phone', 'drh_voice_robot_callback_details', 'phone', COUNT(*) FROM `drh_voice_robot_callback_details`
  UNION ALL SELECT 'drh_voice_robot_task_user.phone', 'drh_voice_robot_task_user', 'phone', COUNT(*) FROM `drh_voice_robot_task_user`
  UNION ALL SELECT 'drh_wechat_complaint_order.phone', 'drh_wechat_complaint_order', 'phone', COUNT(*) FROM `drh_wechat_complaint_order`
  UNION ALL SELECT 'order_book_reissue_detail.phone', 'order_book_reissue_detail', 'phone', COUNT(*) FROM `order_book_reissue_detail`
  UNION ALL SELECT 'drh_ad_count.phone', 'drh_ad_count', 'phone', COUNT(*) FROM `drh_ad_count`
  UNION ALL SELECT 'drh_ad_form_answer.phone', 'drh_ad_form_answer', 'phone', COUNT(*) FROM `drh_ad_form_answer`
  UNION ALL SELECT 'drh_applet_order.phone', 'drh_applet_order', 'phone', COUNT(*) FROM `drh_applet_order`
  UNION ALL SELECT 'drh_applet_small_user.phone', 'drh_applet_small_user', 'phone', COUNT(*) FROM `drh_applet_small_user`
  UNION ALL SELECT 'drh_goods_user_coupon.phone', 'drh_goods_user_coupon', 'phone', COUNT(*) FROM `drh_goods_user_coupon`
  UNION ALL SELECT 'drh_koc.phone', 'drh_koc', 'phone', COUNT(*) FROM `drh_koc`
  UNION ALL SELECT 'drh_order_refund_record.phone', 'drh_order_refund_record', 'phone', COUNT(*) FROM `drh_order_refund_record`
  UNION ALL SELECT 'drh_qwb_phone_info.phone', 'drh_qwb_phone_info', 'phone', COUNT(*) FROM `drh_qwb_phone_info`
  UNION ALL SELECT 'drh_short_message_operation.phone', 'drh_short_message_operation', 'phone', COUNT(*) FROM `drh_short_message_operation`
  UNION ALL SELECT 'drh_sms_trigger_user_callback.phone', 'drh_sms_trigger_user_callback', 'phone', COUNT(*) FROM `drh_sms_trigger_user_callback`
  UNION ALL SELECT 'drh_submit_time.phone', 'drh_submit_time', 'phone', COUNT(*) FROM `drh_submit_time`
  UNION ALL SELECT 'drh_xe_order.phone', 'drh_xe_order', 'phone', COUNT(*) FROM `drh_xe_order`
  UNION ALL SELECT 'drh_register_works.phone', 'drh_register_works', 'phone', COUNT(*) FROM `drh_register_works`
  UNION ALL SELECT 'drh_sms_deal.phone', 'drh_sms_deal', 'phone', COUNT(*) FROM `drh_sms_deal`
  UNION ALL SELECT 'drh_temp_phone.phone', 'drh_temp_phone', 'phone', COUNT(*) FROM `drh_temp_phone`
  UNION ALL SELECT 'drh_mall_order.reciver_phone', 'drh_mall_order', 'reciver_phone', COUNT(*) FROM `drh_mall_order`
) t
LEFT JOIN information_schema.columns c
  ON c.table_schema = DATABASE()
 AND c.table_name = t.table_name
GROUP BY t.target_name, t.table_name, t.source_column, t.row_count
ORDER BY t.row_count DESC, t.target_name;
