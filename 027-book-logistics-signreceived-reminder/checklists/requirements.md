# 规格质量检查清单：图书物流签收标签与暂存提醒

**用途**：验证需求完整性、参数完整性和实施状态  
**创建日期**：`2026-05-21`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确定时任务模块为 `kkhc\kkhc-bizcenter\schedule`。
- [x] 明确业务实现模块为 `kkhc\kkhc-idc\ai`。
- [x] 明确数据源为 `drh_book_question_record` 和 `drh_external_book_question_record`。
- [x] 明确只处理 `drh_goods.category = 4` 的钢琴物流。
- [x] 明确新增字段 `sign_status`、`notice_msg`、`notice_send_status`。
- [x] 明确 `isOver` 不参与本需求物流状态流转。
- [x] 明确仓库不配置 SchedulerX cron，由阿里云分布式任务平台每日 16:00 调度 Job。
- [x] 明确暂存提醒使用 `0-40` 分钟随机延迟。
- [x] 明确 `scrm` 不改，AI 模块自建 delay consumer。

## 需求完整性

- [x] 已签收链路包含状态回写、unionId 获取、主体映射、tag 查询和打标签。
- [x] 暂存链路包含状态回写、物流上下文组装、agent 改写、`notice_msg` 回写和延迟消息投递。
- [x] 暂存提醒成功发送后必须回写 `notice_send_status = 1`，后续扫描和重复消费不再提醒。
- [x] 无 unionId 时不发送提醒。
- [x] 延迟消息消费前重新检查 `sign_status`，签收后跳过。
- [x] 已发送提醒的记录通过 `notice_send_status = 1` 跳过，不重复提醒。
- [x] 标签查询按 `name='已签收'` 和 `source=company` 过滤。
- [x] ShowAPI 两个接口已明确：`2650-6` 获取快递公司编码，`2650-3` 获取物流详情。
- [x] ShowAPI 状态规则已固定：`104` 已签收，`112` 暂存待签收。

## 参数完整性门禁

- [x] `externalUserId` 来源明确：`otsUtil.getExternalUserIdByPhoneNumber(phone)`。
- [x] `unionId` 来源明确：`getEmpExternalUserDO(externalUserId).unionId`。
- [x] `empId` 来源明确：`getEmpExternalUserDO(externalUserId).empId`。
- [x] `qywxUserId` 来源明确：`drh_kk_emp.qyvxUserId`。
- [x] `company/source` 来源明确：`drh_kk_emp.company`。
- [x] `tagId` 来源明确：`drh_qw_tag.tagId`。
- [x] `notice_send_status` 来源明确：暂存提醒发送成功后回写为 `1`。
- [x] 快递公司编码来源明确：ShowAPI `2650-6` 返回 `com`。
- [x] 快递名称来源明确：ShowAPI `2650-3` 返回 `com_name` 或 `expTextName`。
- [x] 最后一条物流轨迹来源明确：ShowAPI `2650-3` 返回 `data`。
- [x] agent 入参明确为 `parameters.input` 口径：最后一条物流轨迹原文 + `快递名称单号：快递单号`。
- [x] MQ body 已收敛为最小载荷 `recordType + recordId`。
- [x] MQ tag 已定义为 `BOOK_LOGISTICS_TEMP_STORAGE_NOTICE`。
- [x] 已修正 AI 模块 `DelayProducerBean.sendTagMessage` 丢失自定义 tag 的实现风险。

## 实施状态

- [x] schedule 入口和 AI 业务入口已实现。
- [x] Feign 调用方向已实现：schedule -> `kkhc-idc-ai`。
- [x] 数据库字段变更已在 `spec.md` 记录，需随发布流程执行。
- [x] 实体映射变更已实现。
- [x] 延迟队列 topic 复用现有配置，不新增 topic。
- [x] ShowAPI appKey 使用 `book.logistics.showapi.app-key`，并保留现有 appKey 默认兼容值。
- [x] workflow id 使用独立配置 `book.logistics.notice.workflow-id`。
- [x] bot id 使用独立配置 `book.logistics.notice.bot-id`。
- [x] 暂存提醒实际发送使用 Nacos 开关 `book.logistics.notice.send-enabled`，默认 `false` 只打印发送日志。
- [x] 已定义 summary 统计字段，便于日志和验收。
- [x] 两张表都在扫描逻辑中覆盖。
- [x] AI 模块自建 delay consumer，消费前重查库。

## 测试覆盖要求

- [x] 候选数据筛选覆盖时间窗口、`l_ids`、`sign_status` 和钢琴 category。
- [x] 两张表都覆盖正常处理路径。
- [x] `l_ids` 解析覆盖正常、空、非法 JSON 和最后元素为空。
- [x] ShowAPI `2650-6` 参数断言覆盖 `appKey`、`nu`。
- [x] ShowAPI `2650-3` 参数断言覆盖 `appKey`、`nu`、`com`、`phone`。
- [x] 已签收链路覆盖 `sign_status = 2` 和按主体查询 tag。
- [x] tag 缺失、unionId 缺失、qywxUserId 缺失时不打标签。
- [x] 暂存链路覆盖 agent 入参、`notice_msg` 回写和延迟消息投递。
- [x] 暂存链路覆盖 `notice_send_status` 成功回写。
- [x] unionId 缺失时不投递延迟消息。
- [x] 已发送提醒的记录会在扫描和消费阶段跳过。
- [x] 延迟消息 tag 和随机延迟范围有断言。
- [x] consumer 覆盖 `sign_status = 2` 时跳过发送。
- [x] consumer 覆盖 `book.logistics.notice.send-enabled=false` 时只打印日志不发送，配置为 `true` 时实际发送。
- [x] consumer 覆盖 `notice_send_status = 1` 时跳过发送。

## 验证结果

- [x] `mvn -pl ai-common -am -DskipTests install` 通过。
- [x] `mvn -pl ai "-Dtest=AiServiceImplBookLogisticsParsingTest,AiServiceImplBookLogisticsProcessTest,BookLogisticsDelayMqTest" test` 通过，`21` 个用例全部通过。
- [x] `mvn -pl schedule -am -DskipTests compile` 通过。
- [x] `mvn -pl ai -am -DskipTests compile` 通过。

## 剩余风险

- [ ] 数据库 DDL 尚需发布流程执行。
- [ ] 生产环境需确认 `book.logistics.notice.workflow-id`、`book.logistics.notice.bot-id`、`book.logistics.notice.send-enabled` 和 `mq.delay.*` 配置。
