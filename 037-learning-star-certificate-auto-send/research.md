# 调研记录：学习之星奖状自动圈选与发送

**调研日期**：`2026-05-28`

## 已确认事实

- `learning-star-certificate-demo` 已实现 Java SVG + Apache Batik PNG 生成，`pom.xml` 使用 Java 1.8，Batik 版本为 `1.17`。
- demo 模板和字体已支持 classpath 资源：
  - `classpath:/certificates/template-clean.png`
  - `classpath:/fonts/Slideqiuhong-Regular.ttf`
- `031-learning-star-certificate-image` 已记录图片生成方案、字段解析、签名模式、headless Java 验证和 demo 测试结果。
- `AiServiceImpl.getCampDateName` 会在 `ExternalUserDto.follow_user` 中按 `userid` 找当前销售，再取 `group_name` 包含营期关键字的标签 `tag_name`。
- `AiServiceImpl.sendBookQuestionRecordByUnionId` 展示了通过 `empOneId + unionId + content` 调用 `sendJuzi` 的文本消息发送方式。
- `AiServiceImpl.sendJuzi(MsgSendInput)` 当前只组装文字消息：`messageType = 7`，`Payload.text = content`。
- `JuziMessageDto` 和 `Payload` 已具备图片消息所需字段：`messageType = 6`，`Payload.url`。
- `BookLogisticsSignStatusJob` 提供 schedule 模块异步调用 `kkhc-idc-ai` Feign 接口并返回 `ProcessResult` 的参考形态。
- `BookQuestionRecordFeign` 当前 Feign 配置为 `@FeignClient(name = "kkhc-idc-ai", path = "/kkhc-idc-ai")`，方法路径在 `/ai/...` 下。
- `AiServiceImpl.sendBookLogisticsDelayNotice` 展示了 RocketMQ 延迟投递方式：构造 `MqMessage`，计算 `deliveryTime`，调用 `DelayProducerBean.sendTagMessage(mqMessage, tag, deliveryTime)`。
- `DelayProducerBean.sendTagMessage(...)` 会设置 topic、tag、`message.setStartDeliverTime(time)`，用于 ONS/RocketMQ 定时/延迟投递。
- `BookLogisticsDelayConsumerListener` 展示了延迟消息消费者模式：按 tag/messageType 过滤，解析 input，记录 `bornTime`、`deliveryTime`，失败时返回 `Action.ReconsumeLater`。
- `BookLogisticsDelayConsumerClient` 展示了消费者订阅方式：topic 来自 `DelayProperties.topic`，tag 来自 listener 常量，group 优先从业务配置读取。
- `BookLogisticsConfig.Notice.delayConsumerGroup` 是已有 group 配置项，默认值为 `GID_delay_book_logistics`；用户补充之前环境中写过 `delay-consumer-group: GID_delay_book_logistics_test`，学习之星可参考该配置项和命名方式。
- `BookLogisticsDelayMqTest` 已有延迟投递测试参考，可复用其 producer mock 和断言思路。
- `FcInvokeUtils.doTaskWithDelay` 在仓库中存在；学习之星消费到整组任务后使用累计 delaySeconds 调度 2 条消息，保证图片先发、合并文字后发。
- `NotePicsServiceImpl` 展示了图片上传 OSS 并获取 CDN URL 的参考：`OssUtil.upload(resultStream, ossPath)` 后调用 `OssUtil.getCdnUrl(ossPath)`。
- `TeachHelpEnum` 中 `BOOK(1)`、`HEZI(2)` 是图书/盒子渠道判断口径。
- `EmpExternalUserDO` 映射 `drh_emp_external_user`，包含 `externalUserid`、`unionId`、`chatId`、`createTime`。
- `AppletUserDo` 映射 `drh_applet_user`，包含 `campDateId`、`empChatId`、`channelId`、`newChannelId`、`unionId`、`name`。
- `ChannelEmpDO` 映射 `drh_channel_emp`，包含 `channelId`、`teachHelp`。
- `LiveCampDateDO` 映射 `drh_live_camp_date`，包含 `id`、`name`、`startTime`、`classTime`、`campId`、`category`。
- `LiveCampDO` 映射 `drh_live_camp`，包含 `speakerId`。
- `SpeakerDO` 映射 `drh_speaker`，包含 `name`。
- 用户补充学习状态标签规则：非图书渠道在 D3 当天触发后，学员需满足 `D1 完课` 与 `D2 完课`；图书渠道在 D4 当天触发后，学员需满足 `D1 完课`、`D2 完课` 与 `D3 到课`。
- `LearningStarCertificateServiceImpl.processCampCandidate()` 中对每个学员的 `renderUploadCertificate()` 是串行调用（`for` 循环逐个执行 SVG 渲染 + OSS 上传），当学员较多时整体耗时线性增长。
- **并发安全性已确认**：`LearningStarCertificateRenderer`（Spring `@Component` 单例）并发执行不会导致图片生成之间相互影响。实例字段全部 effectively immutable（构造函数后不变）；`render()` 每次调用新建 `TemplateImage`、`StringBuilder`、`PNGTranscoder`、`ByteArrayOutputStream`，无共享可变状态；`Font.deriveFont()` 返回新实例，`GlyphVector`/`PathIterator` 为局部变量；`OssUtil.upload()` 底层 `OSS.putObject()` 线程安全（Apache HttpClient 连接池），每次调用独立 `ObjectMetadata`/`InputStream`/`ossPath`。
- `ThreadPoolConfig` 已定义 9 个命名线程池 Bean，`corePoolSize = 4, maxPoolSize = 8, queueCapacity = 100`，拒绝策略均为 `CallerRunsPolicy`；可参考风格新增 `learningStarRenderThreadPool`。
- `AsyncAutoConfig.MdcTaskDecorator` 已实现 MDC 上下文传递：提交前 `MDC.getCopyOfContextMap()` 保存主线程上下文，子线程执行前 `MDC.setContextMap()` 恢复，执行后恢复原始上下文或 `MDC.clear()`。该模式可直接复用于并发图片生成。
- `UserProfileSummaryFacade` 展示了 `CompletableFuture.supplyAsync(task, namedThreadPool)` + `CompletableFuture.allOf().get(timeout, unit)` 的成熟并发模式，可作为图片并发生成的参考。
- `MessageListenerFDH` 和 `TraceIdFilter` 使用 `MDC.put("requestId", ...)` 设置请求追踪 ID；`BookEditAddressCompensationController` 展示了在子线程中手动传递 `requestId` 的模式。
- `PianoVideoHomeWorkHandleServiceImpl.notifyPianoVideoRecognitionWarn()` 展示了 WX003 模板通知发送方式：构造 `taskObj` 含 `external_key` 和 `sendTemplateList`（`Collections.singletonList("WX003")`），通过 `FcInvokeInput`（`serviceName = "service_sys"`, `functionName = "common_warn_sender"`）调用 `FcInvokeUtils.doTask()`。
- WX003 的 `taskObj` 中未传递模板变量（纯模板无替换），WX_004 需要额外传递 `{sendNums}` 变量，需要在 `taskObj` 中新增模板变量字段（待确认字段名）。
- WX_004 `external_key` 已确认由 4 部分组成 `externalUserId:empId:campDateId:qwUserId`，对应 `split[0]` 至 `split[3]`；`common_warn_sender` FC 函数通过解析 `external_key` 确定通知接收人和上下文。所有字段在 `processCampCandidate` 流程中均可获取：`student.getExternalUserid()`、`candidate.getEmpId()`、`candidate.getCampDateId()`、`emp.getQyvxUserId()`。

## 推荐实现结构

1. 在 `kkhc-idc-ai` 新增接口方法，例如 `processLearningStarCertificateSend()`，返回 `JSONObject` summary。
2. 新增独立的应用服务类承载批处理逻辑，避免继续膨胀 `AiServiceImpl`；若仓库风格要求放入 `AiServiceImpl`，也应将纯函数拆为包内可测试方法。
3. 新增营期候选 DTO：包含 `campDateId`、`campDateName`、`chatId`、`startTime`、`classTime`、`campId`、`empId`、`empOneId`、`qwUserId`。
4. 新增学员候选 DTO：包含 `externalUserId`、`unionId`、`studentNickName`、`campDateId`、`chatId`、`empOneId`。
5. 新增标签匹配器：在当前销售 `follow_user.tags` 中同时判断营期标签和学习状态标签；非图书要求 D1/D2 完课，图书要求 D1/D2 完课 + D3 到课。
6. 图片生成代码从 demo 提炼到生产 service，模板和字体随 `kkhc-idc-ai` 资源打包。
7. PNG 生成后用 `OssUtil.upload(InputStream, path)` 上传，使用 `OssUtil.getCdnUrl(path)` 得到发送 URL；图片消息只能使用该 OSS/CDN URL。
8. 新增学习之星 RocketMQ 延迟任务 input，按学员维度承载 2 条待发送消息或可恢复这些消息的参数。
9. 投递延迟消息时使用 `DelayProducerBean.sendTagMessage(...)`，topic 复用共有 `mq.delay.topic`，tag 使用学习之星新 tag；按学员随机 `delayMinutes`，范围 0 到 30 分钟；每个学员只投递一条整组任务。
10. 新增学习之星延迟消费者，consumer group 配置方式参考 `delay-consumer-group: GID_delay_book_logistics_test`，消费单条任务后按 1 到 2 顺序调度图片、合并文字。
11. 图片发送新增内部 helper，不直接复用只有文本字段的 `MsgSendInput`：
   - 文字可继续复用现有 `sendJuzi` 或统一走新 helper。
   - 图片 helper 直接构造 `JuziMessageDto`，设置 `messageType = 6` 和 `Payload.url`。
12. 幂等设计：
   - Redis group key：`ai:learning-star:certificate:sent:{campDateId}:{externalUserId}`。
   - 每条消息 externalRequestId：`learning-star:{campDateId}:{externalUserId}:{seq}`。
   - 延迟消息投递成功可记录投递计数；全部 2 条消费调度成功后写 sent key。
   - 部分失败时允许 RocketMQ 重试，但 Juzi 层 externalRequestId 防止重复已接收消息。
13. schedule 模块新增 Job 和 Feign 方法，参考 `BookLogisticsSignStatusJob` 的日志与异步调用模式。
14. 图片生成并发化改造：
   - 在 `ThreadPoolConfig` 新增 `learningStarRenderThreadPool`（`corePoolSize = 4, maxPoolSize = 4, queueCapacity = 100, CallerRunsPolicy`，线程前缀 `learning-star-render-`）。
   - 将 `processCampCandidate` 中的学员循环改为 `CompletableFuture.supplyAsync()` 提交到 `learningStarRenderThreadPool`。
   - 每个并发任务执行：OTS 标签校验 → `renderUploadCertificate`（SVG 渲染 + OSS 上传）；并发执行完成后，在主线程中串行执行 RocketMQ 延迟投递，避免 `DelayProducerBean` 线程安全问题。
   - 提交前保存 `MDC.getCopyOfContextMap()`，任务内恢复并补充 `campDateId`、`externalUserId`；任务结束后恢复原始上下文。
   - 使用 `CompletableFuture.allOf(futures).get(timeout, unit)` 等待所有学员完成，设置合理超时（如 5 分钟）。
   - `CompletableFuture.exceptionally()` 捕获单学员异常，记录日志并计入 summary，不影响其他学员。
15. WX_004 完成通知：
   - 在每个营期候选（`processCampCandidate`）所有学员处理完成后，从该营期候选的 summary 中读取成功投递学员数。
   - 若 `sendNums > 0`，构造 `FcInvokeInput`（`serviceName = "service_sys"`, `functionName = "common_warn_sender"`）。
   - `taskObj` 包含 `sendTemplateList = ["WX_004"]`、`templateVariable` 含 `sendNums` 值，并传 `appendJumpLink=false`。
   - `external_key` 由 `externalUserId:empId:campDateId:qwUserId` 组成：`externalUserId` 取该营期候选中任一成功发送学员的 `student.getExternalUserid()`，`empId` 来自 `candidate.getEmpId()`，`campDateId` 来自 `candidate.getCampDateId()`，`qwUserId` 来自 `emp.getQyvxUserId()`。
   - 使用 Redis key `ai:learning-star:certificate:wx004:notify:{campDateId}:{empId}` 做按营期候选去重。
   - 通知发送异常时 try-catch，仅记录日志，不影响主流程返回。

## 主要风险

- `drh_live_camp_emp` 的 DO/Mapper 未在本轮文档阶段展开确认，编码前需确认字段和服务复用点。
- 用户 SQL 中 `ai_statu` 与示例 SQL 中 `ai_status` 存在拼写差异，编码时必须以真实表字段为准。
- OTS `follow_user.userid` 的销售字段需要真实数据确认；代码参考中来自接口入参 `user_id`，批任务中需从员工信息反查。
- `D1 完课`、`D2 完课`、`D3 到课` 的真实标签名称和标签组未在本轮文档阶段确认，编码前需从 OTS 标签数据或既有打标代码核实。
- 渠道缺失是否默认非图书会影响发送日期，本规格先采用保守跳过。
- 现有 `sendJuzi` 不设置 `externalRequestId`，若文字复用现有方法，需补等效幂等能力或统一新建发送 helper。
- 批量任务可能对 OTS、OSS、FC 形成突发压力，需要分页、限流和 summary 计数。
- 本规格要求单学员单条整组 RocketMQ 延迟消息，消费时按累计 delaySeconds 调度 2 条消息，顺序为图片、合并文字。
- topic 是共有的，隔离主要依赖新 tag、专用 MessageType 和 consumer group 配置；实现时不能复用图书物流 tag。
- RocketMQ 消费存在重试和重复消费可能，必须将学员整组 key 与每条 `externalRequestId` 一起纳入幂等测试。
- OSS 上传成功但 MQ 投递失败会留下未发送图片文件；日志必须记录 `ossPath`、`campDateId`、`externalUserId`、`unionId`，便于排查和必要时清理。
- 并发执行风险：4 个并发线程同时对 OSS 上传，已确认 `OssUtil.upload()` 底层 `OSS.putObject()` 线程安全（阿里 OSS SDK 使用 Apache HttpClient 连接池），无共享可变状态，并发安全。
- 并发 MDC 传递风险：`MDC.getCopyOfContextMap()` 返回 null 时（如主线程无 MDC 上下文），子线程不应调用 `MDC.setContextMap(null)`，需做 null 检查。
- 并发异常传播风险：`CompletableFuture` 中未捕获的异常会导致 `allOf().get()` 抛出 `ExecutionException`；需使用 `exceptionally()` 或 `handle()` 确保单学员异常不中断整体。
- `CompletableFuture.allOf().get(timeout)` 超时后，未完成的 Future 仍在后台执行；需要处理超时场景的日志记录和 summary 更新。
- WX_004 通知风险：`common_warn_sender` FC 函数模板变量字段已确认为 `templateVariable`；WX_004 需要额外传 `appendJumpLink=false` 避免追加聊天窗口。
- WX_004 `external_key` 已确认由 `externalUserId:empId:campDateId:qwUserId` 组成，所有字段在 `processCampCandidate` 流程中均可获取（`candidate.getEmpId()`、`candidate.getCampDateId()`、`emp.getQyvxUserId()`、`student.getExternalUserid()`）；通知按营期候选维度发送，去重 key 按 `campDateId:empId` 维度。
- WX_004 按营期候选去重（`campDateId:empId`），已确认不再按天去重。
- 并发执行中 RocketMQ 延迟投递已设计为在并发完成后主线程串行执行，规避了 `DelayProducerBean.sendTagMessage()` 的线程安全问题；若后续调整为并发投递，需先确认线程安全性。

## 待实现测试映射

| 行为 | 测试方式 |
| --- | --- |
| 钢琴 AI 营期筛选 | Mock mapper/service，断言 SQL 条件或 QueryWrapper 条件 |
| 图书/非图书渠道判断 | 单元测试 teachHelp 集合 |
| D3/D4 日期判断 | 固定 Clock 单元测试 |
| 好友关系窗口 | 构造 createTime 边界测试 |
| OTS 营期标签和学习状态标签 | 构造 ExternalUserDto 测试，覆盖非图书 D1/D2 完课、图书 D1/D2 完课 + D3 到课及缺失标签 |
| 主讲签名 | 纯函数测试 |
| 图片生成上传 | Mock 渲染器和 OssUtil 包装层，断言 OSS path、URL 非空且用于图片 payload |
| RocketMQ 延迟投递 | Mock DelayProducerBean，断言单学员单条整组消息、共有 topic、新 tag、messageType、body、deliveryTime、随机延迟 0 到 30 分钟 |
| RocketMQ 消费者配置 | 静态验证 topic 复用 `mq.delay.topic`，tag 为学习之星新 tag，consumer group 配置方式参考 `delay-consumer-group` |
| 消息顺序 | Mock 延迟消费者和 FC 调用，消费一条整组任务后捕获 2 条 payload，顺序必须为图片、合并文字 |
| 乱序防护 | 测试确认学习之星链路使用累计 delaySeconds 调度图片和合并文字 |
| 日志与 summary | Mock 成功/失败路径，断言 OSS 上传、MQ 投递、MQ 消费、FC 发送关键计数 |
| 幂等 | Redis mock 或包装层测试，覆盖重复调度、RocketMQ 重复消费、部分发送失败重试 |
| schedule Job | Mock Feign 成功、失败、异常 |
| 图片生成并发执行 | Mock 渲染器和 OssUtil 并设置耗时，断言 8 学员总耗时接近 2 批、并发度不超过 4 |
| 并发 MDC 追踪 | 断言并发线程日志含主线程 `requestId`、`campDateId`、`externalUserId` |
| 并发异常隔离 | Mock 某学员渲染抛异常，断言其他学员正常完成 |
| WX_004 通知发送 | Mock `common_warn_sender` FC，断言 `sendNums > 0` 时调用一次、模板码和变量正确、`external_key` 四部分正确 |
| WX_004 去重 | 模拟同一营期候选两次执行，断言第二次跳过（`campDateId:empId` 维度） |
| WX_004 异常容错 | Mock FC 抛异常，断言主流程正常返回 |
