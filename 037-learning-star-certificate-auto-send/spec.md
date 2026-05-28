# 功能规格：学习之星奖状自动圈选与发送

**功能目录**：`037-learning-star-certificate-auto-send`  
**创建日期**：`2026-05-28`  
**状态**：Draft，先写规格文档，暂不编码  
**输入**：基于 `C:\workspace\ju-chat\learning-star-certificate-demo` 的学习之星奖状图片生成方案，在 `kkhc-idc-ai` 增加可被定时任务调用的接口，在 `kkhc-bizcenter\schedule` 增加定时 Job。按钢琴 AI 营期、渠道教辅类型、D3/D4 时间规则圈选学员，通过 OTS 标签确认学员所属营期以及 D1/D2 完课、D3 到课状态，按营期主讲老师生成签名奖状，图片上传 OSS 后使用可访问地址，通过 RocketMQ 延迟消息在 30 分钟内随机分散发送，并向学员按“两段文字 + 图片 + 两段文字”的顺序发送企微消息。

## 背景

- 当前问题：`031-learning-star-certificate-image` 已完成图片生成 demo，但生产链路还缺少营期圈选、渠道规则、学员筛选、主讲签名、图片上传、消息发送和定时触发。
- 当前行为：`learning-star-certificate-demo` 使用 Java SVG + Apache Batik 生成 PNG；`kkhc-idc-ai` 现有 `AiServiceImpl.sendJuzi` 只封装文字发送；`BookLogisticsSignStatusJob` 提供 schedule 调用 `kkhc-idc-ai` Feign 接口的参考模式。
- 目标行为：定时任务触发 `kkhc-idc-ai` 接口，系统自动识别当日满足 D3/D4 条件的钢琴 AI 营期，筛出对应销售新增好友里标签命中本营期且达到学习状态要求的学员，生成带主讲老师“院长”签名的学习之星奖状图片，上传 OSS 后取得可发送地址，再投递 RocketMQ 延迟消息；消费者按固定消息顺序发送给学员。
- 非目标：本阶段不编码、不改数据库结构、不改既有 AI 权限判断、不改图书物流任务、不把浏览器截图作为图片生成依赖、不改变既有 `sendJuzi` 文字发送行为、不使用 `FcInvokeUtils.doTaskWithDelay` 分散延迟 5 条消息。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 按渠道和开课天数触发营期（优先级：P1）

运营希望系统只处理满足钢琴 AI、渠道类型和营期天数规则的营期，避免过早或过晚发送奖状。

**独立测试**：构造不同 `category`、`ai_status`、`class_time` 和渠道 `teach_help` 数据，断言只有非图书 D3、图书 D4 的营期进入后续学员筛选。

**验收场景**：

1. **Given** 钢琴营期 `category = 4` 且销售 AI 已开启 `ai_status = 1`，渠道 `teach_help` 命中 `BOOK` 或 `HEZI`，**When** `gapDays = 4`，**Then** 营期进入处理。
2. **Given** 钢琴营期 `category = 4` 且销售 AI 已开启，渠道不命中 `BOOK` 或 `HEZI`，**When** `gapDays = 3`，**Then** 营期进入处理。
3. **Given** 其他品类、AI 未开启、图书 D3 或非图书 D4，**When** 定时接口执行，**Then** 该营期跳过并记录原因。

### 用户故事 2 - 通过好友关系、营期标签和学习标签圈选学员（优先级：P1）

系统需要只给当前销售在营期接量开始附近新增、OTS 营期标签确认为当前营期、且完课/到课标签满足渠道规则的学员发奖状。

**独立测试**：Mock `drh_emp_external_user` 列表和 OTS `ExternalUserDto.follow_user.tags`，断言仅 `chat_id`、创建时间窗口、营期标签和渠道对应学习状态标签都命中的学员被选中。

**验收场景**：

1. **Given** 非图书渠道营期在 D3 当天触发，好友关系 `chat_id` 等于营期销售 `chat_id`，`create_time` 在 `start_time - 1天` 到当前时间之间，OTS 当前销售 follow_user 的营期标签命中当前营期，且标签同时命中 `D1 完课` 与 `D2 完课`，**When** 执行处理，**Then** 该学员进入生成和发送。
2. **Given** 图书渠道营期在 D4 当天触发，好友关系和营期标签均命中，且标签同时命中 `D1 完课`、`D2 完课` 与 `D3 到课`，**When** 执行处理，**Then** 该学员进入生成和发送。
3. **Given** 好友关系时间命中但 OTS 没有当前销售 follow_user，或营期标签不等于当前营期，或缺少渠道要求的完课/到课标签，**When** 执行处理，**Then** 该学员跳过。

### 用户故事 3 - 使用主讲老师生成院长签名奖状（优先级：P1）

学员收到的奖状图片需要用其营期主讲老师签名，签名从“老师”口径转换为“院长”。

**独立测试**：给定 `camp_date_id -> camp_id -> speaker.name`，断言 `李瑶老师` 转为 `李瑶院长`，并传入图片生成请求；同一营期多名学员只查询一次主讲老师。

**验收场景**：

1. **Given** 营期对应主讲老师名称为 `李瑶老师`，**When** 生成奖状，**Then** 图片签名使用 `李瑶院长`。
2. **Given** 同一 `campDateId` 下有多个学员，**When** 批量生成奖状，**Then** 主讲老师信息从缓存复用，不对每个学员重复查询。

### 用户故事 4 - 上传 OSS 后通过 RocketMQ 延迟顺序发送（优先级：P1）

学员需要在企微中收到完整学习之星话术和个性化奖状图，图片必须使用 OSS 上传后的可访问地址，发送时间需在 30 分钟内随机分散，且消息顺序稳定。

**独立测试**：Mock 图片上传、RocketMQ 延迟生产者、延迟消费者和 FC 调用，断言每个学员只投递一条整组延迟消息，随机延迟在 0 到 30 分钟内；消费时 5 条发送请求顺序、消息类型、`unionId`、`empOneId`、图片 `payload.url` 和文字内容正确。

**验收场景**：

1. **Given** OTS 客户昵称为 `小明` 且奖状图片生成成功，**When** 图片上传 OSS 并投递 RocketMQ 延迟消息，**Then** 延迟消息体包含 5 条待发送内容，图片内容使用 OSS/CDN URL，不包含本地文件路径或图片字节。
2. **Given** 延迟消息被消费者消费，**When** 消费者执行发送，**Then** 第 1 条文字以 `小明同学` 开头，第 3 条为图片消息，第 5 条为 `希望陪您一起共同进步[加油]`。
3. **Given** 图片生成失败、上传失败或上传后 URL 为空，**When** 发送链路执行，**Then** 不投递 RocketMQ 延迟消息，也不发送任一学习之星消息，并记录失败原因。

### 用户故事 5 - 定时任务调用接口并返回汇总（优先级：P2）

研发和运维需要通过定时任务触发，并能从日志和响应汇总中看出处理结果。

**独立测试**：Mock Feign 返回成功/失败，断言 schedule Job 按参考模式异步调用接口并记录响应；Mock 服务执行返回 summary，断言各类计数准确。

**验收场景**：

1. **Given** SchedulerX 触发 Job，**When** Feign 调用成功，**Then** Job 返回 `ProcessResult(true)`，接口 summary 包含营期数、候选学员数、OSS 上传成功数、延迟消息投递成功数和跳过原因计数；最终 FC 发送成功数通过 RocketMQ 消费者日志和消费侧计数观察。
2. **Given** Feign 调用失败或抛异常，**When** Job 执行，**Then** Job 记录错误日志，不影响其他定时任务。
3. **Given** 接口圈选到多个学员，**When** 生成图片、上传 OSS 并投递延迟消息，**Then** 日志可观察每个营期、每个学员的跳过原因、OSS 路径、延迟分钟数、MQ tag、投递结果和消费发送结果。

## 核心业务口径

### 营期筛选

钢琴 AI 营期来源：

```sql
select b.name, b.id, a.chat_id, b.start_time, b.camp_id, b.class_time, a.emp_id, a.emp_one_id
from drh_live_camp_emp a, drh_live_camp_date b
where a.camp_date_id = b.id
  and a.ai_status = 1
  and b.category = 4
```

渠道来源：

```sql
select dau.channel_id, dau.new_channel_id
from drh_applet_user dau
where dau.camp_date_id = #{drh_live_camp_date.id}
  and dau.emp_chat_id = #{drh_live_camp_emp.chat_id}
order by id desc
limit 1
```

渠道教辅判断：

```sql
select dce.teach_help
from drh_channel_emp dce
where dce.channel_id in (#{channel_id}, #{new_channel_id})
```

- `teach_help` 命中 `TeachHelpEnum.BOOK.getValue()` 或 `TeachHelpEnum.HEZI.getValue()`：图书渠道。
- 查到渠道但不命中图书/盒子：非图书渠道。
- `class_time` 天数：`LocalDate targetDate = now.toLocalDate(); long gapDays = LocalDateUtil.getGapDays(classTime.toLocalDate(), targetDate) + 1;`
- 非图书渠道在 `gapDays == 3` 处理；图书渠道在 `gapDays == 4` 处理。

### 学员圈选

- 用营期销售 `chat_id` 查询 `drh_emp_external_user.chat_id`。
- 时间范围为 `drh_live_camp_date.start_time.minusDays(1)` 到当前时间。
- 每个好友关系用 `externalUserid` 查询 OTS：`otsUtil.getExternalUserDto(externalUserId)`。
- 取 `ExternalUserDto.follow_user` 中 `userid` 等于当前销售企微 userId 的记录，再从该记录的 `tags` 获取营期标签。
- 营期标签名称获取可参考 `AiServiceImpl.getCampDateName(externalUserDto.getFollow_user(), qwUserId)`；标签营期必须能映射到当前 `drh_live_camp_date.id`，才允许发送。
- 完课/到课状态也通过同一个当前销售 `follow_user.tags` 判断，不能使用其他销售 follow_user 下的标签。
- 非图书渠道：仅在 D3 当天触发；学员必须同时具备 `D1 完课` 和 `D2 完课` 标签。
- 图书渠道：仅在 D4 当天触发；学员必须同时具备 `D1 完课`、`D2 完课` 和 `D3 到课` 标签。
- `D1 完课`、`D2 完课`、`D3 到课` 是业务语义名称；编码前需要确认真实 `tag_name` / `group_name` 命名，并集中为常量或配置，避免散落硬编码。

### 主讲签名

主讲老师来源：

```sql
select a.id, a.speaker_id, b.name
from drh_live_camp a, drh_speaker b
where a.id = #{drh_live_camp_date.camp_id}
  and a.speaker_id = b.id
```

- `b.name` 去掉末尾的 `老师` 后拼接 `院长`。
- 示例：`李瑶老师` 转为 `李瑶院长`。
- `campDateId -> signatureText` 需要缓存，避免同一营期每个学员都查询一次主讲接口或数据库。

### 消息顺序

消息分 5 条发送，顺序固定：

1. `[客户昵称]同学，本次6天课程已经完成一半了，首先啊，我要来表扬您，课程都在积极参与，利用空余时间巩固弹琴技巧，非常不错啊[强][强][强]`
2. `您也凭借自己的认真学习获取了咱们班级的“学习之星”[庆祝][庆祝][庆祝]特地来给您颁发奖状[太阳]`
3. 个性化学习之星奖状图片
4. `这也充分的说明了，您非常热爱弹琴，每节课都积极参与，好的地方继续保持，我会帮助您提升改进，把琴学好，完成自己的梦想[玫瑰]`
5. `希望陪您一起共同进步[加油]`

客户昵称来源为 OTS `drh_external_user_info` 对应的 `ExternalUserDto.external_contact.name`。

### 图片上传与延迟发送

- 奖状图片必须先由 Java SVG + Apache Batik 生成 PNG 字节，再上传 OSS。
- 图片消息发送的 `payload.url` 必须使用 OSS 上传后返回的可访问 OSS/CDN 地址；禁止使用本地文件路径、临时文件路径或 Base64 图片内容作为发送 URL。
- 推荐 OSS path 具备可追踪性，例如包含 `learning-star/certificate/{yyyyMMdd}/{campDateId}/{externalUserId或hash}.png`，日志记录 `campDateId`、`externalUserId`、`unionId`、`ossPath` 和最终发送 URL 是否生成成功。
- 图片生成、OSS 上传、URL 转换任一步失败时，当前学员整组消息不投递、不发送。
- 发送分散使用 RocketMQ 延迟消息，参考 `DelayProducerBean.sendTagMessage(MqMessage body, String tag, long time)` 和现有图书物流延迟 MQ 模式。
- RocketMQ topic 使用共有延迟 topic，即现有 `mq.delay.topic` / `DelayProperties.topic`；本需求不新增独立 topic。
- RocketMQ tag 必须使用学习之星专用新 tag，不能复用 `BookLogisticsDelayConsumerListener.TAG`。
- RocketMQ consumer group 的配置项和命名方式可参考之前的 `delay-consumer-group: GID_delay_book_logistics_test`；学习之星实现时应有清晰的专用 consumer 配置或专用 group 值，避免与图书物流消费者订阅混用。
- 每个学员只投递一条 RocketMQ 延迟消息，消息体承载整组 5 条待发送内容或可恢复 5 条内容的任务参数；禁止把 5 条文本/图片消息分别交给 `FcInvokeUtils.doTaskWithDelay`，避免延迟触发时间错乱导致消息乱序。
- 延迟时间按学员维度随机，范围为 `0 <= delayMinutes <= 30`，`deliveryTime = nowMillis + delayMinutes * 60_000L`。
- RocketMQ 消费者收到单条学员任务后，必须在同一个消费流程内按 1 到 5 顺序同步发送：文字、文字、图片、文字、文字。
- 消费者发送过程中若第 N 条失败，应记录 `seq`、`externalRequestId`、`unionId`、`externalUserId`、`campDateId`、错误信息，并依靠 RocketMQ 重试和每条消息幂等键避免重复打扰。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `now` / `targetDate`：来源于接口执行时刻，建议统一使用 `Asia/Shanghai`；营期筛选前现算。
  - `campDateId`：来源于钢琴 AI 营期 SQL 的 `b.id`；所有下游筛选、缓存和幂等 key 必须使用该值。
  - `campDateName`：来源于 `drh_live_camp_date.name` 和 OTS 营期标签 `tag_name`；学员标签校验时现算并与当前营期匹配。
  - `chatId`：来源于 `drh_live_camp_emp.chat_id`；查询渠道和好友关系前必须有值，不能写死为 `YangFan_1`。
  - `empId` / `empOneId`：来源于 `drh_live_camp_emp.emp_id`、`emp_one_id`；发送时优先使用 `emp_one_id`，同时沿用现有 `sendJuzi` 对 empId/empOneId 混用的兼容逻辑。
  - `qwUserId`：应由 `drh_kk_emp.qyvx_user_id` 根据 `emp_id` 或 `emp_one_id` 查询得到，用于匹配 OTS `follow_user.userid`；实现前必须确认真实字段。
  - `channelId` / `newChannelId`：来源于最新一条 `drh_applet_user`；渠道分类前必须取到并去重、去空。
  - `teachHelp`：来源于 `drh_channel_emp.teach_help`；营期天数规则前必须完成图书/非图书判断。
  - `gapDays`：来源于 `class_time.toLocalDate()` 与当天日期；判断是否进入处理前现算。
  - `requiredStudyTags`：来源于渠道类型和 `gapDays`；非图书 D3 要求 `D1 完课`、`D2 完课`，图书 D4 要求 `D1 完课`、`D2 完课`、`D3 到课`；学员标签校验前现算。
  - `friendExternalUserId` / `unionId`：来源于 `drh_emp_external_user.externalUserid`、`unionId`；发送前必须都有值。
  - `studentNickName`：来源于 OTS `ExternalUserDto.external_contact.name`；文字和图片生成前解析，空值兜底为 `同学`。
  - `signatureText`：来源于 `drh_live_camp.camp_id -> drh_speaker.name`；图片生成前解析为 `xxx院长`。
  - `certificateImageUrl`：来源于 Batik PNG 生成后上传 OSS/CDN 的 URL；投递 RocketMQ 延迟消息前必须非空且可追踪。
  - `delayMinutes` / `deliveryTime`：来源于按学员维度生成的 0 到 30 分钟随机延迟；RocketMQ 投递前现算并写入日志与 summary。
  - `messageGroup`：来源于当前学员的 5 条待发送内容；RocketMQ 延迟消息体必须承载整组内容或可恢复整组内容的任务参数，消费时按 `seq = 1..5` 顺序发送。
  - `delayTopic`：来源于共有 `mq.delay.topic` / `DelayProperties.topic`。
  - `learningStarDelayTag`：来源于学习之星专用新 tag 常量。
  - `learningStarDelayConsumerGroup`：配置方式参考 `delay-consumer-group: GID_delay_book_logistics_test`，实际值编码前确认并避免与图书物流消费者混用。
- 下游读取字段清单：
  - 营期筛选读取 `campDateId`、`name`、`chatId`、`startTime`、`campId`、`classTime`、`empId`、`empOneId`。
  - 渠道分类读取 `campDateId`、`chatId`、`channelId`、`newChannelId`、`teachHelp`。
  - 学员圈选读取 `chatId`、`startTime`、`externalUserid`、`unionId`、`createTime`、OTS `follow_user.userid`、`tags.group_name`、`tags.tag_name`，并在当前销售 tags 中同时判断营期标签和渠道要求的学习状态标签。
  - 图片生成读取 `studentNickName`、`issueDate`、`signatureText`、模板资源和字体资源。
  - 图片上传读取 PNG 字节、OSS path，返回 `certificateImageUrl`。
  - RocketMQ 延迟投递读取 `campDateId`、`externalUserId`、`unionId`、`empOneId`、`messageGroup`、`delayMinutes`、`deliveryTime`、共有 `delayTopic` 和学习之星专用 `tag`。
  - 消息消费发送读取 `empOneId`、`unionId`、`externalUserId`、`qyvxUserId`、`corpId`、`messageType`、`payload.text` 或 `payload.url`，并按 `seq` 顺序执行。
- 空对象 / 占位对象风险：
  - 不允许用空 DTO、空 JSON、空 Map 继续下传到图片生成或发送层。
  - OTS 查询失败、`follow_user` 为空、营期标签缺失、完课/到课标签缺失、`unionId` 为空、主讲为空、图片 URL 为空时均跳过当前学员或营期，并写 summary。
  - `certificateImageUrl` 未生成前不能创建图片发送请求。
- 调用顺序风险：
  - 必须先筛营期，再判渠道和 D3/D4，再筛好友，再校验 OTS 营期标签和学习状态标签，再获取主讲签名，再生成/上传图片，再投递 RocketMQ 延迟消息，最后由消费者发送 5 条消息。
  - 不能先发文字再异步补图片；若图片失败，应整组消息都不投递、不发送。
  - 发送需要顺序稳定；消费者必须按 1 到 5 顺序执行并记录每条结果。
  - 禁止使用 `FcInvokeUtils.doTaskWithDelay` 分别延迟 5 条消息，因为多条延迟 FC 调用可能造成文本、图片顺序错乱。
- 旧逻辑保持：
  - 保持 `BookLogisticsSignStatusJob`、图书物流补偿和既有 `sendJuzi` 文字发送行为不变。
  - 保持 `learning-star-certificate-demo` 的 Java SVG + Apache Batik 思路，不引入 Chrome/Chromium 运行时依赖。
  - 保持 `JuziMessageDto` 现有 `functionCode = SEND_MESSAGE`、`type = 1` 的发送契约；新增图片发送能力时只补充图片消息组装，不破坏现有文本入口。
- 需要用户确认的设计选择：
  - 定时任务执行频率和 SchedulerX 配置时间不在仓库内，需上线时在调度平台配置。
  - 渠道缺失时是否跳过还是默认非图书；本规格默认“查到渠道但非图书/盒子才算非图书，完全查不到渠道则跳过”。
  - 是否需要持久化发送记录到数据库；本规格默认不新增表，使用 Redis key 和 `externalRequestId` 做幂等。

## 边界情况

- 钢琴 AI 营期 SQL 查不到数据：接口成功返回空 summary。
- `class_time` 或 `start_time` 为空：跳过营期，计入 `skipInvalidCampTime`。
- `drh_applet_user` 未查到渠道：跳过营期，计入 `skipNoChannel`。
- `drh_channel_emp` 没有命中 `BOOK/HEZI`：按非图书渠道处理。
- 同一营期多个销售都开启 AI：按 `campDateId + chatId + externalUserId` 去重，再按学员维度幂等，避免重复发送。
- `drh_emp_external_user.unionId` 为空：跳过学员，不尝试空 unionId 发送。
- OTS `errcode != 0`、`external_contact` 为空或 `follow_user` 为空：跳过学员并记录。
- 非图书渠道 D3 缺少 `D1 完课` 或 `D2 完课`：跳过学员，计入 `skipStudyTagNotMatch`。
- 图书渠道 D4 缺少 `D1 完课`、`D2 完课` 或 `D3 到课` 任一标签：跳过学员，计入 `skipStudyTagNotMatch`。
- OTS 学员昵称为空：文字昵称兜底为 `同学`；图片姓名按 `031` 姓名规则兜底。
- 主讲老师不存在或签名解析为空：跳过营期或学员，不使用错误默认签名。
- 图片生成、上传、图片 URL 转换任一步失败：不发送该学员任一消息。
- RocketMQ 延迟消息投递失败：不发送该学员任一消息，计入 `delaySendFail` 并保留足够日志便于重试。
- RocketMQ 消费重复投递或重试：通过学员整组幂等 key 与每条消息 `externalRequestId` 保证不重复打扰。
- 发送第 N 条失败：本组标记失败；通过每条消息 `externalRequestId` 保证重试不重复发送已接受的消息。
- 定时任务重复触发：使用 Redis 幂等 key 和 Juzi `externalRequestId` 防重复。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `kkhc-idc-ai` 提供一个学习之星奖状处理接口，供 `kkhc-bizcenter\schedule` 定时调用。
- **FR-002**：系统 MUST 按 `category = 4` 且 `ai_status = 1` 查询钢琴开启 AI 的营期销售记录。
- **FR-003**：系统 MUST 使用当前记录的 `chat_id` 查询渠道和好友关系，禁止写死 `YangFan_1`。
- **FR-004**：系统 MUST 通过 `drh_applet_user.channel_id/new_channel_id` 与 `drh_channel_emp.teach_help` 判断图书/非图书渠道。
- **FR-005**：系统 MUST 在非图书渠道 `D3`、图书渠道 `D4` 时才处理营期。
- **FR-006**：系统 MUST 只圈选 `drh_emp_external_user.chat_id` 命中且 `create_time` 在 `start_time - 1天` 到当前时间的好友关系。
- **FR-007**：系统 MUST 通过 OTS `ExternalUserDto.follow_user` 中当前销售 `userid` 的营期标签确认学员属于当前营期。
- **FR-008**：系统 MUST 对非图书 D3 学员要求当前销售 OTS 标签同时命中 `D1 完课` 和 `D2 完课`。
- **FR-009**：系统 MUST 对图书 D4 学员要求当前销售 OTS 标签同时命中 `D1 完课`、`D2 完课` 和 `D3 到课`。
- **FR-010**：系统 MUST 从 `drh_live_camp` 与 `drh_speaker` 获取主讲老师名称，并转换为 `xxx院长` 签名。
- **FR-011**：系统 MUST 缓存 `campDateId -> signatureText`，避免同一营期重复查询主讲老师。
- **FR-012**：系统 MUST 基于 `learning-star-certificate-demo` 的 Java SVG + Apache Batik 方案生成 PNG 图片，上传 OSS，并取得可用于企微图片消息的 OSS/CDN URL。
- **FR-013**：系统 MUST 使用 RocketMQ 延迟消息按学员投递整组发送任务，随机延迟范围为 0 到 30 分钟。
- **FR-014**：系统 MUST NOT 使用 `FcInvokeUtils.doTaskWithDelay` 分别延迟 5 条文本/图片消息。
- **FR-015**：系统 MUST 在 RocketMQ 消费者中按“两段文字 + 图片 + 两段文字”顺序发送 5 条消息，图片消息 `messageType = 6`，文字消息 `messageType = 7`。
- **FR-016**：系统 MUST 复用共有 `mq.delay.topic`，并为学习之星定义新的 RocketMQ tag；consumer group 配置参考 `delay-consumer-group: GID_delay_book_logistics_test` 的方式，但不得复用图书物流 tag。
- **FR-017**：系统 MUST 对每个学员和每条消息生成稳定 `externalRequestId` 或等效幂等键，防止重复调度、重复消费或部分失败重试造成重复发送。
- **FR-018**：处理接口 MUST 返回 summary，至少包含营期扫描数、命中营期数、候选学员数、学习标签不匹配数、图片成功数、OSS 上传成功数、延迟消息投递成功数、投递失败数和主要跳过原因；RocketMQ 消费者 MUST 记录消费侧发送成功数、失败数和失败序号。
- **FR-019**：系统 MUST 在营期筛选、渠道判断、学员圈选、OTS 标签校验、图片生成、OSS 上传、RocketMQ 投递、MQ 消费和 FC 发送节点打印必要日志，便于上线后观察。
- **FR-020**：系统 MUST NOT 在图片生成失败、上传失败或 URL 为空时投递 RocketMQ 延迟消息，也不得发送任一学习之星文字或图片消息。
- **FR-021**：单元测试 MUST 覆盖渠道分类、D3/D4 计算、好友时间窗口、OTS 营期标签匹配、OTS 完课/到课标签匹配、签名转换、OSS URL 下传、RocketMQ 延迟范围、共有 topic、新 tag、单学员单条整组延迟消息、消费发送顺序、日志关键计数和幂等。

## 成功标准 *(必填)*

- **SC-001**：给定图书渠道 D4 和非图书渠道 D3 的测试数据，只有满足规则的营期进入处理，其他营期明确计入跳过原因。
- **SC-002**：给定非图书 D3 学员，只有 OTS 当前销售标签同时命中当前营期、`D1 完课` 和 `D2 完课` 时，才会生成图片和发送消息。
- **SC-003**：给定图书 D4 学员，只有 OTS 当前销售标签同时命中当前营期、`D1 完课`、`D2 完课` 和 `D3 到课` 时，才会生成图片和发送消息。
- **SC-004**：给定主讲 `李瑶老师`，图片生成请求中的签名字段为 `李瑶院长`。
- **SC-005**：一次成功处理会先上传 OSS 并投递 1 条学员维度 RocketMQ 延迟消息；消费成功后产生 5 条 FC 请求，顺序为文字、文字、图片、文字、文字，图片请求 payload 的 `url` 等于生成后的奖状 OSS/CDN URL。
- **SC-006**：同一学员重复执行时，不会重复发送已成功处理的学习之星消息。
- **SC-007**：延迟投递测试中随机延迟分钟数始终位于 0 到 30 分钟，且不会出现 5 条消息分别独立延迟导致的顺序不确定。
- **SC-008**：新增代码编译和目标单元测试通过，且不影响现有图书物流相关测试。

## 假设

- `drh_applet_user.emp_chat_id` 应使用当前营期销售记录的 `chat_id`，用户 SQL 中的 `YangFan_1` 只是示例值。
- OTS `follow_user.userid` 匹配值来自当前销售的 `KkEmpDo.qyvxUserId`，需在实现前通过真实数据再确认。
- `D1 完课`、`D2 完课`、`D3 到课` 暂按业务语义描述；真实标签名称和标签组需在编码前通过 OTS 标签数据或已有代码再确认。
- 生产图片模板、字体和坐标沿用 `learning-star-certificate-demo` 当前资源：`classpath:/certificates/template-clean.png` 和 `classpath:/fonts/Slideqiuhong-Regular.ttf`。
- 发送图片可复用 `JuziMessageDto` + `Payload.url`，新增内部 helper 即可，不需要修改 FC `SEND_MESSAGE` 契约。
- 延迟发送使用现有 RocketMQ 延迟能力和共有 `mq.delay.topic`，新增学习之星专用 tag/messageType/consumer；consumer group 配置方式参考 `delay-consumer-group: GID_delay_book_logistics_test`，不复用 `doTaskWithDelay`。
- 本需求不新增数据库表；发送幂等优先使用 Redis 和 `JuziMessageDto.externalRequestId`。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成对 `031-learning-star-certificate-image`、`learning-star-certificate-demo`、`AiServiceImpl`、`BookLogisticsSignStatusJob`、`BookQuestionRecordFeign`、`MsgSendInput`、`JuziMessageDto`、`Payload`、`TeachHelpEnum` 和相关 DO 字段的静态确认。
- 已明确本阶段只写文档，不修改业务代码。

### D002 - 补充学习状态标签规则

- 用户补充非图书渠道 D3 当天触发时，学员必须满足 `D1 完课` 且 `D2 完课`。
- 用户补充图书渠道 D4 当天触发时，学员必须满足 `D1 完课` 且 `D2 完课` 且 `D3 到课`。
- 已将该规则同步到用户故事、核心业务口径、参数门禁、边界情况、功能需求、成功标准和假设。

### D003 - 补充 OSS、RocketMQ 延迟、日志和测试规则

- 用户补充奖状图片需要上传 OSS，发送图片消息时使用 OSS 上传后的可访问地址。
- 用户补充发送时间要在 30 分钟内随机分散。
- 用户明确最终采用 RocketMQ 延迟消息，不使用 `doTaskWithDelay`，原因是文本、图片多条消息分别延迟可能导致顺序错乱。
- 已将发送口径调整为“每个学员投递一条整组 RocketMQ 延迟消息，消费者按 1 到 5 顺序同步发送”。
- 已补充必要日志和测试覆盖要求。

### D004 - 补充 RocketMQ topic、tag 和 consumer group 口径

- 用户补充可参考之前写过的 `delay-consumer-group: GID_delay_book_logistics_test`。
- 用户补充 tag 使用新的学习之星 tag，topic 使用共有延迟 topic。
- 已将规格同步为：复用共有 `mq.delay.topic`，新增学习之星专用 tag，consumer group 配置方式参考既有 `delay-consumer-group` 写法，避免复用图书物流 tag。
