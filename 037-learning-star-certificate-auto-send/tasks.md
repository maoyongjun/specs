# 任务清单：学习之星奖状自动圈选与发送

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的单元测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前阶段只写规格文档，不编码。
- [x] T002 确认图片生成 demo 位置：`C:\workspace\ju-chat\learning-star-certificate-demo`，方案为 Java SVG + Apache Batik PNG。
- [x] T003 确认已有图片生成规格：`C:\workspace\ju-chat\specs\031-learning-star-certificate-image`。
- [x] T004 确认 AI 服务落点：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`，参考实现类为 `AiServiceImpl`，接口为 `AiController` / `AiService`。
- [x] T005 确认定时任务落点：`C:\workspace\ju-chat\kkhc\kkhc-bizcenter\schedule`，参考 Job 为 `BookLogisticsSignStatusJob`。
- [x] T006 确认现有 schedule Feign 模式：`BookQuestionRecordFeign` 调用 `kkhc-idc-ai` 的 `/kkhc-idc-ai/ai/...` 接口。
- [x] T007 确认 `TeachHelpEnum.BOOK = 1`、`TeachHelpEnum.HEZI = 2`、`TeachHelpEnum.NULL_SET = 3`。
- [x] T008 确认 `MsgSendInput` 当前只有 `empOneId`、`unionId`、`content`，现有 `sendJuzi` 只封装文字消息。
- [x] T009 确认 `JuziMessageDto.messageType` 支持图片 `6`、文字 `7`，`Payload.url` 可承载图片 URL。
- [x] T010 确认 `EmpExternalUserDO` 包含 `externalUserid`、`unionId`、`chatId`、`createTime`。
- [x] T011 确认 `ExternalUserDto` 包含 `external_contact.name/unionid` 和 `follow_user.userid/tags`。
- [x] T012 确认 `LiveCampDateDO` 包含 `id/name/startTime/campId/classTime/category/speakerId`，`LiveCampDO` 包含 `speakerId`，`SpeakerDO` 包含 `name`。
- [x] T012A 确认现有 RocketMQ 延迟参考：`DelayProducerBean.sendTagMessage(...)`、`BookLogisticsDelayConsumerListener`、`BookLogisticsDelayMqTest`。
- [x] T012B 确认 `FcInvokeUtils.doTaskWithDelay` 可用于 MQ 消费后的秒级累计延迟调度；每条消息使用累计秒数，避免同组消息连续刷屏。
- [x] T012C 确认 OSS 上传参考：`NotePicsServiceImpl` 使用 `OssUtil.upload(...)` 后通过 `OssUtil.getCdnUrl(...)` 取得可访问 URL。
- [x] T012D 确认 RocketMQ 配置口径：topic 使用共有 `mq.delay.topic`，tag 使用学习之星新 tag，consumer group 配置方式参考 `delay-consumer-group: GID_delay_book_logistics_test`。

**检查点**：已完成文档阶段静态确认；编码前仍需二次确认真实 mapper/service 是否已有可复用方法，尤其是 `drh_live_camp_emp` 查询和 `qwUserId` 来源。

## Phase 2：风险门禁

- [ ] T013 编码前确认 `drh_live_camp_emp.ai_status` 字段和 DO/Mapper 的真实字段名，避免用户文本中的 `ai_statu` 拼写误差带入实现。
- [ ] T014 编码前确认 `drh_applet_user.emp_chat_id` 与 `drh_live_camp_emp.chat_id` 是否同一口径，不允许硬编码示例 `YangFan_1`。
- [ ] T015 编码前确认 OTS `follow_user.userid` 应使用 `KkEmpDo.qyvxUserId` 还是其他字段。
- [ ] T016 编码前确认好友关系是否需要附加 `status = 0` 过滤；未确认前按规格只使用 `chat_id` 和时间范围。
- [ ] T017 编码前确认渠道完全缺失时是否跳过；本规格默认跳过，不默认非图书。
- [ ] T018 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用；编码前必须确认 `D1 完课`、`D2 完课`、`D3 到课` 的真实 `tag_name` / `group_name`。
- [ ] T019 检查是否存在空 DTO、空 JSON、空 Map、空图片 URL 或只 set 部分字段后继续传递。
- [ ] T020 检查新增图片发送 helper 是否改变现有 `sendJuzi(MsgSendInput)` 文字发送契约。
- [ ] T021 检查新增 Batik 依赖是否与 JDK 1.8、`kkhc-idc-ai` 现有依赖树兼容。
- [ ] T022 检查 Redis 幂等 key、`externalRequestId`、日志字段是否包含足够定位信息且不泄露敏感内容。
- [ ] T022A 编码前确认学习之星 RocketMQ 专用 `MessageType`、新 tag 常量和 consumer group 实际配置值；topic 已明确复用共有 `mq.delay.topic`，consumer group 写法参考 `delay-consumer-group: GID_delay_book_logistics_test`。
- [x] T022B 检查延迟投递方案是否为“每个学员一条整组 RocketMQ 消息”，消费后再把 2 条消息（图片、合并文字）使用 `doTaskWithDelay` 按累计秒数调度。
- [ ] T022C 检查随机延迟范围为 0 到 30 分钟，并能在日志和 summary 中观察共有 topic、新 tag、投递成功/失败。

**检查点**：T013-T022C 必须在编码前有明确结论；发现口径变化时先更新 `spec.md`。

## Phase 3：实现

- [ ] T023 在 `kkhc-idc-ai` 增加学习之星处理接口，例如 `GET /kkhc-idc-ai/ai/learning-star/certificate/send/process`。
- [ ] T024 在 `AiService` 增加处理方法，返回 `JSONObject` summary。
- [ ] T025 在 `AiServiceImpl` 或独立 service 中实现营期扫描：钢琴 `category = 4`、AI 开启 `ai_status = 1`。
- [ ] T026 实现渠道解析：用 `campDateId + chatId` 查询最新 `drh_applet_user`，再用新旧渠道查 `drh_channel_emp.teach_help`。
- [ ] T027 实现 D3/D4 判断：非图书 `gapDays == 3`，图书 `gapDays == 4`。
- [ ] T028 实现好友关系查询：`chatId` 命中，`createTime` 在 `startTime.minusDays(1)` 到当前时间。
- [ ] T029 实现 OTS 标签校验：只取当前销售 `follow_user.userid` 下的营期标签和学习状态标签；营期标签映射回当前 `campDateId`，非图书要求 `D1 完课` + `D2 完课`，图书要求 `D1 完课` + `D2 完课` + `D3 到课`。
- [ ] T030 实现主讲签名解析和缓存：`speaker.name` 去尾部 `老师` 后拼接 `院长`。
- [ ] T031 将 demo 渲染能力接入生产：模板和字体作为 classpath 资源，Batik 输出 PNG 字节。
- [ ] T032 实现图片上传：PNG 上传 OSS，返回可用于图片消息的 OSS/CDN URL，禁止本地路径或 Base64 下传。
- [ ] T033 实现学习之星整组发送任务模型：包含 `campDateId`、`externalUserId`、`unionId`、`empOneId`、图片与合并文字 2 条消息内容、`certificateImageUrl`、`externalRequestId` 或可生成它们的参数。
- [ ] T034 实现 RocketMQ 延迟投递：复用共有 `mq.delay.topic`，使用学习之星新 tag；每个学员投递一条整组消息，随机延迟 0 到 30 分钟，记录 `delayMinutes`、`deliveryTime`、topic、tag、投递结果。
- [x] T035 实现学习之星延迟消费者：consumer group 配置方式参考 `delay-consumer-group: GID_delay_book_logistics_test`；消费单条整组任务后，按图片、合并文字顺序使用 FC 累计延迟调度。
- [ ] T036 实现图片消息发送 helper：构造 `JuziMessageDto`，`messageType = 6`，`Payload.url = certificateImageUrl`。
- [x] T036A 实现 2 条消息顺序调度，文字消息复用 Juzi 消息结构，图片消息使用 `messageType = 6` 和 `payload.url`，发送顺序为图片、合并文字。
- [x] T036B 实现幂等：每个学员和每条消息有稳定 `externalRequestId` / scheduled key，整组成功后写 Redis 已处理标记，消费重试跳过已调度序号。
- [x] T036C 实现 summary 计数和日志：营期、渠道、学员、学习状态标签不匹配、图片、OSS 上传、MQ 投递、MQ 消费、FC 调度、跳过原因。
- [x] T036D 实现昵称优先级：OTS `drh_ai_external_base_info.name_tushu` > OTS `drh_external_user_info.external_contact.name` > 本地好友关系 `drh_emp_external_user.name`。
- [x] T036E 新增测试发送接口 `POST /kkhc-idc-ai/ai/learning-star/certificate/send/test`，入参 `userId`、`externalUserId`，跳过营期/完课/到课标签校验，不投递 RocketMQ。
- [x] T036F 新增消息间隔配置 `message-interval-min-seconds` / `message-interval-max-seconds`，默认 4-7，异常配置回退默认值。
- [ ] T037 在 `kkhc-bizcenter\schedule` 增加 Feign 接口方法或独立 Feign，调用 `kkhc-idc-ai` 新接口。
- [ ] T038 在 `kkhc-bizcenter\schedule\task` 增加 Job，参考 `BookLogisticsSignStatusJob` 异步调用并记录响应。
- [ ] T039 保持本需求不改图书物流、AI 权限、现有文字发送和其他定时任务逻辑。
- [x] T052 在 `juzi-service` 配置管理界面新增学习之星测试发送台入口、页面和首页跳转。
- [x] T053 为 `juzi-service` 学习之星测试发送台补充真实发送按钮、后端环境控制代理接口和图片版取号引导。

## Phase 4：测试与验证

- [ ] T040 新增渠道分类测试：BOOK/HEZI 为图书，其他 teach_help 为非图书，渠道缺失跳过。
- [ ] T041 新增 D3/D4 天数测试：固定 Clock，覆盖 `class_time` 当天、D3、D4 和错日跳过。
- [ ] T042 新增好友关系时间窗口测试：`start_time - 1天` 边界、当前时间边界、窗口外跳过。
- [ ] T043 新增 OTS 标签匹配测试：当前销售 userid 命中、其他销售 userid 命中但当前不命中、无营期标签、非图书缺 D1/D2 完课、图书缺 D1/D2 完课或 D3 到课。
- [ ] T044 新增主讲签名测试：`李瑶老师 -> 李瑶院长`、无 `老师` 后缀、空主讲跳过。
- [ ] T045 新增图片生成接入测试：Mock 模板/字体或复用测试资源，断言 PNG 非空、可读、OSS 上传参数正确、返回 URL 用于图片 payload。
- [ ] T046 新增 RocketMQ 延迟投递测试：单个学员只投递一条整组消息，共有 topic、新 tag、messageType、body、deliveryTime 正确，随机延迟分钟数始终在 0 到 30。
- [x] T046A 新增延迟消费顺序测试：消费者消费一条整组任务后，2 条 FC 调度顺序、累计 delaySeconds、messageType、payload.text/url、externalUserId、wecomUserId、corpId 正确。
- [ ] T046C 新增消费者配置测试或静态验证：学习之星消费者使用新 tag，topic 复用共有 `mq.delay.topic`，consumer group 配置参考 `delay-consumer-group` 写法且不复用图书物流 tag。
- [x] T046B 新增乱序防护验证：测试确认学习之星链路使用累计 delaySeconds 调度文本和图片消息，顺序为图片、合并文字。
- [x] T047 新增幂等测试：重复执行、RocketMQ 重复消费、部分失败重试不重复调度已接受消息。
- [x] T047B 新增昵称优先级测试：覆盖 `name_tushu`、OTS 企微昵称、本地好友昵称三级兜底。
- [x] T047C 新增测试发送服务测试：覆盖测试接口不走 MQ、生成奖状并调度 2 条 FC 延迟消息。
- [ ] T047A 新增日志与 summary 测试：覆盖 OSS 上传成功/失败、MQ 投递成功/失败、消费发送成功/失败的关键计数。
- [ ] T048 新增 schedule Job 测试：Feign 成功/失败/异常均有预期日志和 `ProcessResult`。
- [x] T049 运行 `kkhc-idc-ai` 目标测试或至少相关测试类，记录命令和结果。
- [ ] T050 运行 `kkhc-bizcenter\schedule` 目标测试或至少新增 Job 测试，记录命令和结果。
- [ ] T051 搜索确认没有硬编码 `YangFan_1`，没有把旧 `实践之星`、`作业情况` 或浏览器截图方案带入生产链路。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `037-learning-star-certificate-auto-send` Spec Kit 文档，记录业务口径、代码事实、风险门禁、实现任务和测试映射。
- 验证方式：静态读取 `031-learning-star-certificate-image`、demo README/pom/src、`AiServiceImpl`、`AiController`、`AiService`、`BookLogisticsSignStatusJob`、`BookQuestionRecordFeign`、`TeachHelpEnum`、`MsgSendInput`、`JuziMessageDto`、`Payload`、`EmpExternalUserDO`、`ExternalUserDto`、`LiveCampDateDO`、`LiveCampDO`、`SpeakerDO`、`ChannelEmpDO`。
- 自检结论：本阶段未修改业务代码；实现前需完成 Phase 2 风险门禁。

### D002 - 补充学习状态标签规则

- 执行内容：同步用户补充规则：非图书 D3 要求 `D1 完课` + `D2 完课`；图书 D4 要求 `D1 完课` + `D2 完课` + `D3 到课`。
- 验证方式：更新 Phase 2 门禁、Phase 3 实现任务和 Phase 4 测试映射。
- 自检结论：本阶段仍未修改业务代码；真实标签名和标签组需编码前确认。

### D003 - 补充 OSS、RocketMQ 延迟、日志和测试规则

- 执行内容：同步用户当时补充规则：奖状图片上传 OSS 后使用 OSS/CDN 地址发送；发送通过 RocketMQ 延迟消息随机分散到 0 到 30 分钟；每个学员投递一条整组延迟消息。后续 D009 已调整为 MQ 消费后使用 `doTaskWithDelay` 按累计秒数调度 2 条消息（图片、合并文字）。
- 验证方式：更新 Phase 1 事实确认、Phase 2 门禁、Phase 3 实现任务和 Phase 4 测试映射。
- 自检结论：本阶段仍未修改业务代码；编码前需确认学习之星 MQ tag/messageType/consumer group 命名与配置方式。

### D004 - 补充 RocketMQ topic、tag 和 consumer group 口径

- 执行内容：同步用户补充规则：topic 使用共有延迟 topic；tag 使用新的学习之星 tag；consumer group 配置方式参考之前的 `delay-consumer-group: GID_delay_book_logistics_test`。
- 验证方式：更新 Phase 1 事实确认、Phase 2 门禁、Phase 3 实现任务和 Phase 4 测试映射。
- 自检结论：本阶段仍未修改业务代码；编码前只需确认学习之星新 tag、MessageType 和 consumer group 实际命名。

### D005 - 昵称、测试发送与 FC 累计延迟实现

- 执行内容：新增 `OtsUtil.getNameTushuByExternalUserId`；调整学习之星昵称优先级；新增测试发送 DTO 和 `POST /ai/learning-star/certificate/send/test`；正式 MQ 消费和测试发送均改为调度 2 个 FC 延迟任务（图片、合并文字）；新增 4-7 秒间隔配置和 scheduled key 幂等。
- 验证方式：运行 `mvn -pl ai -am -Dtest=LearningStarCertificateServiceImplTest test`。
- 验证结果：通过，`Tests run: 14, Failures: 0, Errors: 0, Skipped: 0`。
- 自检结论：学习之星新增逻辑已完成单元测试覆盖；仍需上线后通过日志观察 FC 异步调用真实 requestId 和字体加载情况。

### D006 - 补充 juzi-service 配置管理入口

- 执行内容：在 `data-RC/juzi-service` 新增学习之星测试发送台页面，展示正式/测试环境完整 URL、`userId` / `externalUserId` 示例参数和“学员微信号从句子后台客户跟进复制”的说明；同时补充首页入口、admin page redirect 和 `WebConfig` 放行。
- 验证方式：静态检查页面、首页入口和拦截器配置，并准备后续通过编译验证。
- 自检结论：学习之星测试接口已补入配置管理界面，方便运营直接复制调用。

### D007 - 补充奖状昵称截断规则

- 执行内容：将奖状显示昵称的截断长度调整为 6 位，超过后追加 `...`；话术仍使用完整昵称，不做截断。
- 验证方式：更新渲染器单元测试，覆盖奖状显示昵称和 SVG 输出中的截断结果。
- 自检结论：改动仅影响奖状图片展示，不影响消息话术。

### D008 - 学习之星测试发送台补充真实发送能力

- 执行内容：在 `data-RC/juzi-service` 增加 `GET /admin/learning-star-certificate-test/env` 和 `POST /admin/learning-star-certificate-test/send`，后端根据 `mq.juzi_tag` 选择测试/正式 `kkhc-idc-ai` 网关地址；页面补充发送按钮、最近一次结果、目标环境展示、请求体预览和图片版取号引导，并将该页面纳入专项密码校验。
- 验证方式：运行 `mvn -pl juzi-service -DskipTests compile` 和 `mvn -pl juzi-service -DskipTests=false -Dtest=LearningStarCertificateTestSendServiceTest test`，并静态检查页面请求只调用本服务 admin 接口，不由前端选择环境。
- 自检结论：学习之星测试发送台从“接口说明页”升级为“可执行操作台”，环境由后端统一控制。

### D009 - 调整学习之星消息顺序与文字合并

- 执行内容：将原 4 条文字合并为 1 条合并文字，消息列表改为 2 条：`seq=1` 图片、`seq=2` 合并文字；正式 MQ 消费和测试发送复用同一组消息结构。
- 验证方式：更新 `LearningStarCertificateServiceImplTest`，覆盖消息构造、消费累计延迟、重试跳过、部分失败重试和测试发送；运行 `mvn -pl ai -am "-Dtest=LearningStarCertificateServiceImplTest,LearningStarCertificateRendererTest" test`。
- 验证结果：通过，`Tests run: 17, Failures: 0, Errors: 0, Skipped: 0`。
- 自检结论：学习之星链路现在先发奖状图片，再按累计延迟发送合并后的完整话术。
