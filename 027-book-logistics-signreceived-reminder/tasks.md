# 任务清单：图书物流签收标签与暂存提醒

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**目标**：代码已落地到 `kkhc-bizcenter/schedule`、`kkhc-idc/ai`、`kkhc-idc/ai-common`、`kkhc-idc/base-common`；`scrm` 不改。

## Phase 1：事实确认

- [x] T001 阅读本目录 `AGENTS.md`，确认实现范围限定在 schedule 触发和 AI 业务处理。
- [x] T002 复查 `kkhc\kkhc-bizcenter\schedule` 中 `BookQuestionRecordCompensationJob` 和 `BookQuestionRecordFeign` 的定时任务与 Feign 调用模式。
- [x] T003 复查 `kkhc\kkhc-idc\ai` 中 `AiController`、`AiService`、`AiServiceImpl` 的现有接口组织方式。
- [x] T004 复查 `compensateBookQuestionRecordUnionIdAndSend` 中 `otsUtil.getExternalUserIdByPhoneNumber`、`getEmpExternalUserDO`、`extractLatestLId` 的实现。
- [x] T005 复查 `data-RC\juzi-service` 和 `scrm` 中 ONS 延迟消息发送/消费方式。
- [x] T006 复查 `fc\homework-review\src\main\java\com\drh\homework\service\SopHomeWorkHandleService.java` 的 `works_flow` 调用参数。
- [x] T007 复查 ShowAPI 现有代码 `CollectOrderServiceImpl`，确认 `2650-6` 和 `2650-3` 的请求参数与响应结构。
- [x] T008 固定 ShowAPI 状态规则：`104` 已签收，`112` 暂存待签收。

## Phase 2：数据库与实体

- [x] T009 `drh_book_question_record` 需增加 `sign_status`、`notice_msg`、`notice_send_status`，DDL 已记录在 `spec.md`。
- [x] T010 `drh_external_book_question_record` 需增加 `sign_status`、`notice_msg`、`notice_send_status`，DDL 已记录在 `spec.md`。
- [x] T011 `BookQuestionRecordDO` 已增加 `signStatus`、`noticeMsg`、`noticeSendStatus`。
- [x] T012 `ExternalBookQuestionRecordDO` 已增加 `signStatus`、`noticeMsg`、`noticeSendStatus`、`createTime`。
- [x] T013 AI 模块已新增 `QwTagMapper`，支持按 `name/source/isDel` 查询 `drh_qw_tag`。
- [x] T014 两张表按 `createTime -> create_time` 使用 MyBatis-Plus 驼峰映射。
- [x] T015 已新增最小延迟消息 DTO：`BookLogisticsDelayNoticeInput(recordType, recordId)`。
- [x] T016 `MessageType` 已新增 `BOOK_LOGISTICS_TEMP_NOTICE((byte)134)`。

## Phase 3：schedule 触发

- [x] T017 在 `kkhc\kkhc-bizcenter\schedule` 新增 `BookLogisticsSignStatusJob`。
- [x] T018 Job 继承 `JavaProcessor`，参考 `BookQuestionRecordCompensationJob` 使用异步提交并返回 `ProcessResult`。
- [x] T019 在 `BookQuestionRecordFeign` 新增 `GET /ai/book/logistics/sign-reminder/process`。
- [x] T020 不在仓库配置 SchedulerX cron；由阿里云分布式任务平台每日 16:00 调度该 Job。
- [x] T021 Job 日志包含开始、提交成功、Feign 失败、异常和 summary。

## Phase 4：AI 主流程

- [x] T022 在 `AiController` 新增处理入口，返回 `BaseResponse<JSONObject>`。
- [x] T023 在 `AiService` 新增 `processBookLogisticsSignReminder()`。
- [x] T024 在 `AiServiceImpl` 实现分页扫描两张表，时间窗口为最近 10 天内且 3 天之前，按 `Asia/Shanghai` 计算。
- [x] T025 过滤 `l_ids IS NOT NULL`、`sign_status IN (0,1)`，排除 `sign_status = 2`。
- [x] T026 通过 `goodsId` 批量查询 `drh_goods`，只处理 `category = 4`。
- [x] T027 复用 `extractLatestLId`，取 `l_ids` JSON 数组中最后一个非空物流单号。
- [x] T028 每条记录写入 summary 计数，单条异常不影响整批处理。

## Phase 5：ShowAPI 物流查询

- [x] T029 调用 `https://route.showapi.com/2650-6`，参数 `appKey`、`nu`，获取 `com`。
- [x] T030 调用 `https://route.showapi.com/2650-3`，参数 `appKey`、`nu`、`com`、`phone`，其中 `phone` 为手机号后四位。
- [x] T031 解析快递名称、物流单号和 `data[].time/address/status/context/location`。
- [x] T032 最新轨迹 `status = 104` 识别为已签收。
- [x] T033 最新轨迹 `status = 112` 识别为暂存待签收。
- [x] T034 接口失败、空响应、轨迹为空时不更新签收状态，记录 summary/log。

## Phase 6：已签收打标签

- [x] T035 已签收时更新来源表 `sign_status = 2`。
- [x] T036 通过手机号调用 `otsUtil.getExternalUserIdByPhoneNumber` 获取 `externalUserId`。
- [x] T037 调用现有 `getEmpExternalUserDO(externalUserId)` 获取 `unionId`、`empId`。
- [x] T038 通过 `empId` 查询 `drh_kk_emp`，获取 `qyvxUserId` 和 `company`。
- [x] T039 查询 `drh_qw_tag`：`name = '已签收' AND source = company AND is_del = 0`。
- [x] T040 使用查到的 `tagId` 调用现有打标签能力；缺少 `unionId`、`qyvxUserId`、`company` 或 `tagId` 时不打标签。
- [x] T041 不跨主体 fallback，不硬编码 tagId。

## Phase 7：暂存提醒

- [x] T042 暂存未签收时组装最后一条轨迹、快递名称、快递单号。
- [x] T043 调用 agent workflow 改写文案，调用结构参考 `invokeCozeWorkFlow`。
- [x] T044 workflow id 使用独立配置 `book.logistics.notice.workflow-id`。
- [x] T045 bot id 使用独立配置 `book.logistics.notice.bot-id`。
- [x] T046 agent 返回空、超时、解析失败时不投递消息，保留 `sign_status = 1` 以便后续补生成。
- [x] T047 agent 成功后更新来源表 `sign_status = 1` 和 `notice_msg`。
- [x] T048 `sign_status = 1` 且 `notice_msg` 非空时不重复投递；`notice_send_status = 1` 时也不重复投递；`notice_msg` 为空时允许补生成。
- [x] T049 通过 `otsUtil.getExternalUserIdByPhoneNumber` 和 `getEmpExternalUserDO` 获取 `unionId`；缺失时不投递消息。
- [x] T050 通过 `EmpExternalUserDO.empId -> drh_kk_emp.qyvxUserId/company` 获取发送所需销售和主体信息。

## Phase 8：延迟队列

- [x] T051 新增延迟消息 tag 常量：`BOOK_LOGISTICS_TEMP_STORAGE_NOTICE`。
- [x] T052 修正 AI 模块 `DelayProducerBean.sendTagMessage`，确保自定义 tag 真正生效。
- [x] T053 `startDeliverTime` 设置为当前时间加随机 `0-40` 分钟。
- [x] T054 消息体只包含 `recordType`、`recordId`，消费时重新查库获取最新状态和发送上下文。
- [x] T055 不改 `scrm`；AI 模块自建 ONS delay consumer。
- [x] T056 AI consumer 订阅现有 `mq.delay.topic` 和 tag `BOOK_LOGISTICS_TEMP_STORAGE_NOTICE`。
- [x] T057 consumer 发送前重新读取来源记录；若记录不存在、`sign_status = 2`、`notice_send_status = 1`、`sign_status != 1` 或 `notice_msg` 为空，则跳过。
- [x] T058 consumer 重新获取 `unionId`、`empId`、`qyvxUserId/company`，再调用现有 `sendJuzi` 发送。
- [x] T058A consumer 发送学员消息受 Nacos 开关 `book.logistics.notice.send-enabled` 控制，默认 `false` 只打印日志。
- [x] T058B consumer 发送成功后回写来源记录 `notice_send_status = 1`，后续扫描和重复消费跳过。

## Phase 9：测试与验证

- [x] T059 单测候选数据筛选：时间窗口、`l_ids`、`sign_status`、`goods.category = 4`。
- [x] T060 单测两张表分别被扫描和处理。
- [x] T061 单测 `l_ids` 解析：正常数组、空数组、非法 JSON、最后一个元素为空。
- [x] T062 单测 ShowAPI 客户端参数：`2650-6` 带 `appKey/nu`，`2650-3` 带 `appKey/nu/com/phone`。
- [x] T063 单测已签收链路：更新 `sign_status = 2`，按 `company` 查询 `drh_qw_tag.source`。
- [x] T064 单测 tag 缺失、unionId 缺失、qywxUserId 缺失时不打标签。
- [x] T065 单测暂存链路：agent 入参、`notice_msg` 回写、延迟消息投递。
- [x] T066 单测 unionId 缺失时不投递延迟消息。
- [x] T067 单测延迟消息 tag 为 `BOOK_LOGISTICS_TEMP_STORAGE_NOTICE`，延迟范围为 `0-40` 分钟。
- [x] T068 单测 consumer 在 `sign_status = 2` 时跳过发送。
- [x] T068A 单测 `book.logistics.notice.send-enabled=false` 时只打印日志不发送，配置为 `true` 时实际发送。
- [x] T069 编译目标模块，并在执行记录写明命令和结果。

## 执行记录

### D001 - 初始文档

- 执行内容：创建图书物流签收标签与暂存提醒 Spec Kit 文档。
- 验证方式：文档检查、目录结构确认。
- 自检结论：已完成规格骨架，未进入业务代码实现。

### D002 - 文档细化

- 执行内容：按用户补充固定 schedule、AI、延迟队列、agent workflow、unionId 获取、tag 主体筛选和 ShowAPI 接口。
- 验证方式：代码搜索和参考文件读取。
- 自检结论：后续实现任务已拆分到数据库、schedule、AI、ShowAPI、标签、agent、MQ、测试各阶段。

### D003 - 代码实现

- 执行内容：新增 schedule Job/Feign，AI Controller/Service/Impl 主处理链路，实体字段，QwTagMapper，MessageType 枚举，最小 MQ payload，AI 自建 delay consumer，并修复 `DelayProducerBean.sendTagMessage`。
- 额外兼容修复：`base-common` 的 `AESUtils` 将 JDK 内部 `UrlUtil` 替换为标准 `URLDecoder`，否则当前 JDK 下 `base-common` 无法编译。
- 验证命令：`mvn -pl schedule -am -DskipTests compile`。
- 验证结果：通过。
- 验证命令：`mvn -pl ai -am -DskipTests compile`。
- 验证结果：通过。
- 剩余风险：数据库 DDL 需随发布流程执行；生产需确认 `book.logistics.notice.workflow-id`、`book.logistics.notice.bot-id`、`book.logistics.notice.send-enabled` 和 `mq.delay.*` 配置。

### D004 - 测试与文档收尾

- 执行内容：新增 `AiServiceImplBookLogisticsParsingTest`、`AiServiceImplBookLogisticsProcessTest`、`BookLogisticsDelayMqTest`，并在 `ai/pom.xml` 显式覆盖父 POM 的 surefire `skip=true`，确保固定验证命令真实执行测试。
- 预处理命令：`mvn -pl ai-common -am -DskipTests install`。
- 预处理结果：通过，用于将新增 `BookLogisticsDelayNoticeInput` 安装到本地仓库，供 `ai` 模块单独测试引用。
- 验证命令：`mvn -pl ai "-Dtest=AiServiceImplBookLogisticsParsingTest,AiServiceImplBookLogisticsProcessTest,BookLogisticsDelayMqTest" test`。
- 验证结果：通过，`25` 个用例全部通过，`0` failures，`0` errors，`0` skipped。
- 验证命令：`mvn -pl ai -am -DskipTests compile`。
- 验证结果：通过。
- 验证命令：`mvn -pl schedule -am -DskipTests compile`。
- 验证结果：通过。
