-- 新 Agent 上线验证回复记录表 DDL 提案。
-- 当前文档阶段未执行该 SQL；生产执行前需 DBA 审核表名、字段长度、索引、字符集和发布窗口。
-- 幂等约束使用 message_id + agent_id，避免同一学员消息对同一 Agent 重复落库。

CREATE TABLE IF NOT EXISTS `drh_new_agent_reply_record` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `external_user_id` VARCHAR(128) NOT NULL DEFAULT '' COMMENT '学员externalUserId',
  `union_id` VARCHAR(128) NOT NULL DEFAULT '' COMMENT '学员unionId',
  `nick_name` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '用户昵称',
  `message_id` VARCHAR(128) NOT NULL COMMENT '学员消息message_id',
  `student_message` TEXT NOT NULL COMMENT '学员发送的消息',
  `ai_reply` MEDIUMTEXT NOT NULL COMMENT '新Agent生成的AI回复内容',
  `generated_time` DATETIME(3) NOT NULL COMMENT 'AI回复生成完成时间',
  `day_n` INT DEFAULT NULL COMMENT '学员所处dayN数字值',
  `sales_qw_user_id` VARCHAR(128) NOT NULL DEFAULT '' COMMENT '销售企业微信user_id',
  `agent_id` VARCHAR(128) NOT NULL DEFAULT '7638948127407636514' COMMENT '调用的新Agent ID',
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_message_agent` (`message_id`, `agent_id`),
  KEY `idx_external_user_id` (`external_user_id`),
  KEY `idx_sales_generated_time` (`sales_qw_user_id`, `generated_time`),
  KEY `idx_union_id` (`union_id`),
  KEY `idx_generated_time` (`generated_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='新Agent上线验证回复记录表';
