# 功能规格：图书物流签收标签与暂存提醒

**功能目录**：`027-book-logistics-signreceived-reminder`  
**创建日期**：`2026-05-21`  
**状态**：Implemented  
**输入**：图书签收后给用户打“已签收”标签；快递暂存后，如果用户未签收，给用户发送提醒。定时任务写在 `kkhc\kkhc-bizcenter\schedule`，业务功能写在 `kkhc\kkhc-idc\ai`，消息队列参考 `data-RC\juzi-service` 的已有延迟队列并通过独立 tag 区分，agent workflow 调用参考 `fc\homework-review\src\main\java\com\drh\homework` 的作业识别调用方式。

## 背景

- 当前图书物流发出后，系统缺少基于物流状态的自动签收标签和暂存提醒闭环。
- 运营目标是每天定时处理钢琴图书物流：已签收则自动打“已签收”标签；暂存但未签收则生成简短提醒并延迟发送给学员。
- 本规格只覆盖 `drh_book_question_record` 和 `drh_external_book_question_record` 两张图书快递记录表。
- 本规格不改变现有 `isOver` 的业务含义；新增 `sign_status` 仅表示物流签收处理状态。

## 用户故事与验收

### 用户故事 1 - 物流已签收后自动打标签（P1）

当物流状态识别为已签收时，系统应给对应用户打“已签收”标签，减少人工补标。

**验收场景**：

1. **Given** 钢琴图书物流状态为已签收，**When** 每日定时任务处理该记录，**Then** 记录更新为 `sign_status = 2`。
2. **Given** 已拿到用户 `externalUserId`、`unionId` 和销售 `empId`，**When** 执行打标，**Then** 系统通过 `empId -> drh_kk_emp.company` 获取主体 `source`，再查询 `drh_qw_tag.name = '已签收' AND source = company` 获取 `tagId`。
3. **Given** `drh_qw_tag` 未查到当前主体的“已签收”标签，**When** 处理签收记录，**Then** 不硬编码 tagId，不跨主体取其他标签，只记录失败原因。
4. **Given** 记录已经是 `sign_status = 2`，**When** 后续任务再次扫描，**Then** 不重复打标、不重复处理。

### 用户故事 2 - 暂存未签收时发送提醒（P1）

当物流轨迹解析为暂存且尚未签收时，系统应标记记录为已暂存待签收，并给学员发送简短提醒。

**验收场景**：

1. **Given** 钢琴图书物流最后一条轨迹表示暂存且未签收，**When** 任务处理该记录，**Then** 记录更新为 `sign_status = 1`。
2. **Given** 已拿到快递名称、快递单号和最后一条物流轨迹，**When** 调用 agent workflow，**Then** agent 返回面向学员的简短提醒文案。
3. **Given** agent 返回有效提醒文案，**When** 状态回写完成，**Then** 将文案保存到来源表的 `notice_msg` 字段。
4. **Given** 手机号无法解析到 `unionId`，**When** 处理暂存记录，**Then** 不发送提醒，只保留 `sign_status`、`notice_msg` 和日志。
5. **Given** 延迟消息到达消费时记录已经更新为 `sign_status = 2`，**When** consumer 准备发送提醒，**Then** 跳过发送，避免签收后仍提醒取件。
6. **Given** 提醒已经成功发送过并且 `notice_send_status = 1`，**When** 后续任务再次扫描或消费同一记录，**Then** 不再重复发送提醒。

### 用户故事 3 - 只扫描目标时间窗口内的钢琴物流（P1）

系统应只处理最近 10 天内且 3 天之前登记的未签收物流记录，并通过商品表过滤钢琴。

**验收场景**：

1. **Given** 记录登记时间在 `[当前日期-10天, 当前日期-3天)`，且 `l_ids IS NOT NULL`，**When** 定时任务执行，**Then** 记录可进入候选集。
2. **Given** 记录登记时间不足 3 天，**When** 定时任务执行，**Then** 不处理。
3. **Given** 记录登记时间早于最近 10 天，**When** 定时任务执行，**Then** 不处理。
4. **Given** 记录关联 `drh_goods.category != 4`，**When** 定时任务执行，**Then** 不处理。

## 数据模型与字段

### 表字段

两张表都需要新增相同字段：

```sql
ALTER TABLE drh_book_question_record
  ADD COLUMN sign_status TINYINT NOT NULL DEFAULT 0 COMMENT '物流签收处理状态:0已发货,1已暂存待签收,2已签收',
  ADD COLUMN notice_msg VARCHAR(1024) DEFAULT NULL COMMENT '暂存提醒文案',
  ADD COLUMN notice_send_status TINYINT NOT NULL DEFAULT 0 COMMENT '暂存提醒发送状态:0未发送,1已发送';

ALTER TABLE drh_external_book_question_record
  ADD COLUMN sign_status TINYINT NOT NULL DEFAULT 0 COMMENT '物流签收处理状态:0已发货,1已暂存待签收,2已签收',
  ADD COLUMN notice_msg VARCHAR(1024) DEFAULT NULL COMMENT '暂存提醒文案',
  ADD COLUMN notice_send_status TINYINT NOT NULL DEFAULT 0 COMMENT '暂存提醒发送状态:0未发送,1已发送';
```

- `sign_status = 0`：已发货，待物流状态处理。
- `sign_status = 1`：已暂存待签收，已生成或准备发送暂存提醒。
- `sign_status = 2`：已签收，已进入签收处理闭环。
- `notice_msg`：仅保存 agent 改写后的最终提醒文案，不保存完整物流轨迹。
- `notice_send_status`：暂存提醒发送状态，`0` 表示未发送，`1` 表示已发送。
- `isOver`：保持现有“用户确认收货/业务完成”含义，不作为本任务的物流状态字段。

### 实体映射

- `BookQuestionRecordDO` 增加 `signStatus`、`noticeMsg`。
- `ExternalBookQuestionRecordDO` 增加 `signStatus`、`noticeMsg`；如实现查询登记时间需要，也应补充 `createTime` 映射。
- `QwTagDO` 已存在于 `ai-common`，字段包括 `tagId`、`name`、`source`、`isDel`；AI 模块如缺 mapper，需要新增 `QwTagMapper` 或等价查询能力。

## 数据范围

候选数据来自两张表：

```sql
SELECT *
FROM drh_book_question_record
WHERE l_ids IS NOT NULL
  AND sign_status IN (0, 1)
  AND notice_send_status = 0
  AND create_time >= #{todayMinus10Start}
  AND create_time < #{todayMinus3Start}
ORDER BY id ASC
LIMIT #{pageSize};

SELECT *
FROM drh_external_book_question_record
WHERE l_ids IS NOT NULL
  AND sign_status IN (0, 1)
  AND notice_send_status = 0
  AND create_time >= #{todayMinus10Start}
  AND create_time < #{todayMinus3Start}
ORDER BY id ASC
LIMIT #{pageSize};
```

- 时间窗口按 `Asia/Shanghai` 计算，默认日边界为 `00:00:00`。
- 分页建议按 `id > lastId ORDER BY id ASC LIMIT pageSize`，避免大偏移分页。
- 处理前必须通过 `goodsId` 关联 `drh_goods`，仅保留 `category = 4` 的钢琴记录。
- 单条记录取 `l_ids` 中最后一个非空物流单号作为本次查询单号，解析失败则跳过并记录原因。
- `sign_status = 2` 的记录不进入候选集。
- `notice_send_status = 1` 的记录不进入候选集。

## 物流接口

物流接口来源固定为 `route.showapi.com`，参考现有代码 `kkhc\kkhc-bizcenter\app\src\main\java\com\kkhc\bizcenter\app\service\order\impl\CollectOrderServiceImpl.java`。

### 快递公司识别

- URL：`https://route.showapi.com/2650-6`
- 方法：按现有代码使用 `postForm`
- 参数：
  - `appKey`：配置项 `book.logistics.showapi.app-key`，实现保留现有 ShowAPI appKey 的默认兼容值，生产可通过配置覆盖
  - `nu`：物流单号
- 输出：取返回 `showapi_res_body.data[0].com` 作为物流公司编码。

### 物流详情查询

- URL：`https://route.showapi.com/2650-3`
- 方法：按现有代码使用 `postForm`
- 参数：
  - `appKey`：同上，配置化
  - `nu`：物流单号
  - `com`：快递公司编码，例如抓包中的 `yunda`
  - `phone`：收件手机号后四位
- 输出字段：
  - `showapi_res_body.com_name`：快递名称
  - `showapi_res_body.nu`：快递单号
  - `showapi_res_body.update_time`：更新时间
  - `showapi_res_body.data[].time/address/status/context/location`：物流轨迹

### 状态识别

- 已签收：ShowAPI 最新轨迹 `status = 104`。
- 暂存待签收：ShowAPI 最新轨迹 `status = 112`。
- 其他状态：不触发标签和提醒，只记录 summary/log。

## 处理流程

### 定时任务

- 位置：`kkhc\kkhc-bizcenter\schedule`
- 参考：`BookQuestionRecordCompensationJob`
- 新增 Job：建议命名为 `BookLogisticsSignStatusJob`
- 调度：仓库不配置 cron；由阿里云分布式任务平台每日 16:00 调度该 Job。
- 行为：
  - Job 只负责触发 AI 模块处理接口。
  - 通过 `BookQuestionRecordFeign` 新增方法调用 AI。
  - 可以沿用现有异步提交模式，Job 提交成功后返回 `ProcessResult(true)`。

### AI 处理接口

- 位置：`kkhc\kkhc-idc\ai`
- 新增 controller/service 方法，例如：
  - `GET /ai/book/logistics/sign-reminder/process`
  - `AiService.processBookLogisticsSignReminder()`
- 返回值建议为 `JSONObject summary`，至少包含：
  - `total`
  - `signed`
  - `stored`
  - `tagged`
  - `noticeSaved`
  - `delaySent`
  - `skipNoLId`
  - `skipNoGoods`
  - `skipNotPiano`
  - `skipNoExternalUserId`
  - `skipNoUnionId`
  - `skipNoTag`
  - `showApiFail`
  - `agentFail`
  - `recordFail`

### 已签收链路

1. 更新来源记录 `sign_status = 2`。
2. 使用手机号优先调用 `otsUtil.getExternalUserIdByPhoneNumber(phone)` 获取 `externalUserId`。
3. 如果 OTS 未命中，则按手机号查询 `drh_applet_user`，直接获取 `unionId` 和 `empId`；若仍未命中，再按手机号查询 `drh_live_user` 获取 `unionId`，并通过 `drh_emp_external_user` 最新好友关系补齐 `externalUserId` 和 `empId`。
4. OTS 命中的场景下，通过现有 `getEmpExternalUserDO(externalUserId)` 获取 `EmpExternalUserDO`；兜底场景则直接使用查询结果中的 `unionId`、`empId`。
5. 以获取到的 `unionId` 作为消息发送和用户识别关键标识；为空则可更新签收状态，但不打标签。
6. 以获取到的 `empId` 查询 `drh_kk_emp`，获取：
   - `qyvxUserId`：打标签所需销售企微用户 id
   - `company`：主体 id，用于 `drh_qw_tag.source`
7. 查询 `drh_qw_tag`：
   - `name = '已签收'`
   - `source = company`
   - `is_del = 0` 或等价有效条件
8. 使用查到的 `tagId` 调用现有打标签能力。

#### 兜底查询 SQL

```sql
SELECT *
FROM drh_applet_user
WHERE phone = #{phone}
ORDER BY id DESC
LIMIT 1;

SELECT *
FROM drh_live_user
WHERE phone = #{phone}
ORDER BY id DESC
LIMIT 1;

SELECT *
FROM drh_emp_external_user
WHERE union_id = #{unionId}
  AND status = 0
ORDER BY id DESC
LIMIT 1;
```

### 暂存提醒链路

1. 更新来源记录 `sign_status = 1`。
2. 组装 agent 输入：
   - 快递名称：`com_name`
   - 快递单号：`nu`
   - 最后一条物流轨迹：`time`、`address`、`context`
   - 输出要求：改写为简短、清楚、适合直接发给学员的取件提醒
3. 参考 `fc\homework-review\src\main\java\com\drh\homework\service\SopHomeWorkHandleService.java` 的 `invokeCozeWorkFlow`：
   - `serviceName = ai-service`
   - `functionName = works_flow`
   - `taskObj.worksFlowId` 从配置或环境变量获取，例如 `book_logistics_notice_works_flow_id`
   - `taskObj.input.input` 放入 workflow 参数文本，格式为：最后一条物流轨迹原文 + `快递名称单号：快递单号`
   - `taskObj.botId` 从配置或环境变量获取
   - `taskObj.id = UUID`
   - `taskObj.callbackUrl = ""`
   - `taskObj.appType = 2`
   - 使用同步调用并解析返回文案
4. 将文案回写到来源表 `notice_msg`。
5. 使用手机号优先解析 `externalUserId`；取不到时依次通过 `drh_applet_user` 和 `drh_live_user` 兜底获取 `unionId`、`empId`，再结合 `drh_emp_external_user` 最新好友关系补齐发送上下文。
6. 如果 `unionId` 为空，不投递消息。
7. 如果 `unionId` 存在，投递延迟消息，随机延迟 `0-40` 分钟。
8. 延迟消息消费时，发送学员消息受 Nacos 配置 `book.logistics.notice.send-enabled` 控制，默认 `false`。默认只打印将要发送的学员消息日志，不实际调用发送接口；配置为 `true` 后才调用现有发送能力。
9. 学员消息成功发送后，必须将来源记录 `notice_send_status` 更新为 `1`；后续扫描和消费都要跳过 `notice_send_status = 1` 的记录。

## 延迟队列

- 参考代码：`data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\DelayMessageServiceImpl.java`
- 使用已有 ONS 延迟消息能力。
- 通过独立 tag 区分本业务：`BOOK_LOGISTICS_TEMP_STORAGE_NOTICE`。
- 发送时设置：
  - `topic`：沿用当前 AI 模块延迟队列配置，不新建 topic
  - `tag`：`BOOK_LOGISTICS_TEMP_STORAGE_NOTICE`
  - `startDeliverTime`：当前时间加随机 `0-40` 分钟
  - `body`：JSON
- AI 模块 `DelayProducerBean.sendTagMessage` 已修正为显式发送带自定义 tag 的 `Message`，确保业务 tag 真正生效。

消息体使用最小载荷，外层由 `MqMessage` 包装 `MessageType.BOOK_LOGISTICS_TEMP_NOTICE`：

```json
{
  "recordType": "drh_book_question_record",
  "recordId": 123
}
```

AI 模块自建 ONS delay consumer，发送前必须重新读取来源记录：

- 记录不存在：跳过。
- `sign_status = 2`：跳过。
- `sign_status != 1`：跳过。
- `notice_msg` 为空：跳过。
- `unionId` 或 `qywxUserId` 为空：跳过。
- 仍为 `sign_status = 1`：调用现有消息发送能力发送 `noticeMsg`。
- `book.logistics.notice.send-enabled = false`：只打印将要发送的学员消息日志，不实际发送。
- `book.logistics.notice.send-enabled = true`：调用现有消息发送能力发送 `noticeMsg`。

## 需求

- **FR-001**：必须在 `kkhc\kkhc-bizcenter\schedule` 新增可由阿里云分布式任务平台调度的 Job；仓库内不配置 SchedulerX cron。
- **FR-002**：必须在 `kkhc\kkhc-idc\ai` 实现图书物流签收与暂存提醒业务处理。
- **FR-003**：必须处理 `drh_book_question_record` 和 `drh_external_book_question_record` 两张表。
- **FR-004**：必须新增 `sign_status` 和 `notice_msg` 字段，并同步实体映射。
- **FR-005**：必须按登记时间筛选最近 10 天内且 3 天之前的数据。
- **FR-006**：必须只处理 `l_ids IS NOT NULL` 且 `drh_goods.category = 4` 的钢琴物流。
- **FR-007**：必须使用 `route.showapi.com/2650-6` 识别快递公司编码。
- **FR-008**：必须使用 `route.showapi.com/2650-3` 查询物流详情。
- **FR-009**：ShowAPI `appKey` 使用 `book.logistics.showapi.app-key` 配置，可兼容现有默认值。
- **FR-010**：已签收时必须更新 `sign_status = 2`。
- **FR-011**：已签收打标签时必须按 `empId -> drh_kk_emp.company -> drh_qw_tag.source` 查询当前主体的“已签收”标签。
- **FR-012**：`tagId` 必须来自 `drh_qw_tag.tagId`，不得硬编码。
- **FR-013**：暂存未签收时必须更新 `sign_status = 1`。
- **FR-014**：暂存提醒文案必须由 agent workflow 基于最后一条物流轨迹改写。
- **FR-015**：agent 改写后的文案必须保存到来源表 `notice_msg`。
- **FR-016**：发送提醒前必须通过 `otsUtil.getExternalUserIdByPhoneNumber` 获取 `externalUserId`，取不到时依次兜底 `drh_applet_user`、`drh_live_user` 和 `drh_emp_external_user` 获取 `unionId`。
- **FR-017**：无法获取 `unionId` 时必须不发送提醒。
- **FR-018**：提醒消息必须使用已有延迟队列并通过独立 tag 区分。
- **FR-019**：提醒消息必须随机延迟 `0-40` 分钟。
- **FR-020**：延迟消息消费前必须重新检查 `sign_status`，签收后不得继续发送暂存提醒。
- **FR-021**：暂存提醒实际发送必须受 Nacos 配置 `book.logistics.notice.send-enabled` 控制，默认 `false`，仅打印发送日志。
- **FR-022**：学员暂存提醒成功发送后必须回写 `notice_send_status = 1`，重复扫描和重复消费都不得再次发送。

## 边界情况

- `l_ids` 为空、非法 JSON、数组内无有效单号：跳过并计入 `skipNoLId`。
- `goodsId` 为空或查不到商品：跳过并计入 `skipNoGoods`。
- 商品不是 `category = 4`：跳过并计入 `skipNotPiano`。
- ShowAPI 公司识别失败或物流详情失败：不更新签收状态，记录 `showApiFail`。
- ShowAPI 返回轨迹为空：跳过并记录原因。
- 已签收但缺少 `unionId`：允许更新 `sign_status = 2`，但不打标签。
- 已签收但缺少当前主体“已签收”标签：不打标签，不跨主体 fallback。
- 暂存但 agent 返回空文案或超时：保持或更新 `sign_status = 1`，不投递消息，后续扫描可在 `notice_msg` 为空时补生成。
- 延迟消息发送失败：保留 `notice_msg`，记录失败，后续可通过 `sign_status = 1` 重新补偿。
- 暂存提醒发送成功后必须将 `notice_send_status` 更新为 `1`，避免后续扫描或重复消费再次发送。
- 多次扫描同一条暂存记录：不得重复生成多条提醒；如需要重试，只允许针对发送失败或 `notice_msg` 为空的记录补偿。

## 成功标准

- **SC-001**：符合时间窗口、`l_ids` 非空、钢琴 `category = 4` 的两类记录能被稳定筛出。
- **SC-002**：已签收物流能更新 `sign_status = 2`，并按主体查询“已签收”标签。
- **SC-003**：暂存未签收物流能更新 `sign_status = 1`、保存 `notice_msg` 并投递延迟消息。
- **SC-004**：`unionId` 获取失败时不会发送提醒。
- **SC-005**：延迟消息使用独立 tag，且随机延迟范围为 `0-40` 分钟。
- **SC-006**：延迟消息消费前记录已签收时不会继续发送提醒。
- **SC-007**：ShowAPI appKey、agent workflow id、MQ tag 均通过配置或集中常量管理，不散落硬编码。
- **SC-008**：暂存提醒发送成功后会回写 `notice_send_status = 1`，后续扫描/消费不会再次发送。

## 假设与待补充

- 时间窗口按 `Asia/Shanghai` 日期边界计算。
- `phone` 传给 ShowAPI 详情接口时使用收件手机号后四位。
- ShowAPI 状态规则固定为：`104` 已签收，`112` 暂存待签收。
- agent workflow id 使用独立配置 `book.logistics.notice.workflow-id`，不复用作业识别 workflow；bot 使用 `book.logistics.notice.bot-id`。
- 学员暂存提醒发送开关使用 `book.logistics.notice.send-enabled`，默认 `false`，需要实际发送时通过 Nacos 改为 `true`。
- 延迟队列 topic 沿用现有配置，只新增本业务 tag。

## 执行记录

### D001 - 初始文档

- 已创建图书物流签收标签与暂存提醒 Spec Kit 文档。
- 已明确状态字段、时间窗口、钢琴过滤、标签来源、提醒回写和定时策略。
- 本阶段未修改业务代码。

### D002 - 用户补充细化

- 固定定时任务模块：`kkhc\kkhc-bizcenter\schedule`。
- 固定业务实现模块：`kkhc\kkhc-idc\ai`。
- 固定延迟队列参考：`data-RC\juzi-service`，通过 tag 区分。
- 固定 agent workflow 参考：`fc\homework-review\src\main\java\com\drh\homework`。
- 固定 unionId 获取参考：`compensateBookQuestionRecordUnionIdAndSend` 中 `otsUtil.getExternalUserIdByPhoneNumber` 与 `getEmpExternalUserDO`，并补充 `drh_applet_user` / `drh_live_user` / `drh_emp_external_user` 兜底链路。
- 固定 tag 主体映射：`drh_emp_external_user.empId -> drh_kk_emp.company -> drh_qw_tag.source`。
- 补充 ShowAPI 接口：`2650-6` 获取快递公司编码，`2650-3` 获取物流详情；appKey 需配置化。

### D003 - 实现完成

- 已新增 `BookLogisticsSignStatusJob` 和 schedule Feign 入口；仓库不配置 SchedulerX cron。
- 已在 AI 模块实现 `GET /ai/book/logistics/sign-reminder/process`，按两张表、时间窗口、`l_ids`、`sign_status`、`notice_send_status` 和钢琴 `category = 4` 扫描。
- 已补用户解析兜底链路：OTS -> `drh_applet_user` -> `drh_live_user` -> `drh_emp_external_user`。
- 已固定 ShowAPI 最新轨迹状态：`104` 更新 `sign_status = 2` 并按主体打“已签收”标签；`112` 更新 `sign_status = 1`、调用 agent 改写提醒、保存 `notice_msg` 并投递延迟消息。
- 已新增 AI 自建 delay consumer，订阅 `BOOK_LOGISTICS_TEMP_STORAGE_NOTICE`，消费前按 `recordType + recordId` 重新查库并在签收后或 `notice_send_status = 1` 后跳过。
- 已新增 Nacos 开关 `book.logistics.notice.send-enabled`，默认只打印暂存提醒学员消息日志，不实际发送。
- 已修复 AI `DelayProducerBean.sendTagMessage`，确保自定义 tag 真正发送。
- 验证命令：
  - `mvn -pl schedule -am -DskipTests compile`：通过。
  - `mvn -pl ai -am -DskipTests compile`：通过。

### D004 - 测试完成

- 已新增 `AiServiceImplBookLogisticsParsingTest`，覆盖 `l_ids` 解析、ShowAPI 参数构造、成功码解析、最新轨迹选择、agent 文案解析、workflow prompt 组装和 workflow 调用参数捕获。
- 已新增 `AiServiceImplBookLogisticsProcessTest`，覆盖候选筛选条件、两张表扫描、钢琴过滤、签收打标签、tag 缺失、unionId 缺失、qywxUserId 缺失、暂存文案回写、无 unionId 不投递，以及 `applet_user` / `live_user` 兜底解析。
- 已新增 `BookLogisticsDelayMqTest`，覆盖延迟消息 tag、`0-40` 分钟随机延迟、producer 失败不计入 `delaySent`、consumer 在 `sign_status = 2` 时跳过发送、`notice_send_status = 1` 时跳过发送，以及 `book.logistics.notice.send-enabled` 默认关闭只打印日志、开启后实际发送和成功后回写 `notice_send_status`。
- 已在 `ai/pom.xml` 显式覆盖父 POM 的 surefire `skip=true`，确保固定验证命令真实执行测试。
- 预处理命令：`mvn -pl ai-common -am -DskipTests install`，用于将新增 `BookLogisticsDelayNoticeInput` 安装到本地仓库供 `ai` 模块单独测试引用。
- 验证命令：
  - `mvn -pl ai "-Dtest=AiServiceImplBookLogisticsParsingTest,AiServiceImplBookLogisticsProcessTest,BookLogisticsDelayMqTest,AiServiceImplLogisticsTagCompensationTest" test`：通过，`31` 个用例全部通过。
  - `mvn -pl ai -am -DskipTests compile`：通过。
  - `mvn -pl schedule -am -DskipTests compile`：通过。
