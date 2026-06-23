SELECT
  id,
  strategy_id,
  order_index,
  action_type,
  condition_key,
  condition_value,
  text_content,
  material_url,
  oss_url,
  voice_duration_millis,
  pdf_file_name,
  pdf_file_size_bytes,
  delay_millis,
  enabled,
  created_by,
  updated_by,
  DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s.%f') AS created_at,
  DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s.%f') AS updated_at
FROM drh_ai_config_homework_action
ORDER BY id;
