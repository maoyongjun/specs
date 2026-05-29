# 规格执行说明

本目录用于“学习之星奖状自动圈选与发送”的 Spec Kit 文档。当前只做需求规格和实施任务拆解，暂不进入编码。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\037-learning-star-certificate-auto-send`
- 图片生成 demo：`C:\workspace\ju-chat\learning-star-certificate-demo`
- 已有图片生成规格：`C:\workspace\ju-chat\specs\031-learning-star-certificate-image`
- 目标服务模块：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`
- 定时任务模块：`C:\workspace\ju-chat\kkhc\kkhc-bizcenter\schedule`

## 当前目标

- 明确钢琴 AI 营期、渠道类型、D3/D4 触发、好友关系、OTS 营期标签、OTS 完课/到课标签、主讲签名、图片生成和消息发送的完整口径。
- 将生产接入任务拆到可编码、可测试、可回滚的最小步骤。
- 保证后续实现不会把空参数、硬编码渠道、错误签名或未生成图片下传到发送层。

## 执行原则

- 先完成 Phase 2 风险门禁，再编码。
- `drh_applet_user.emp_chat_id` 必须使用当前营期销售的 `chat_id`，不得硬编码示例值。
- 营期处理必须同时满足钢琴 `category = 4`、AI 开启 `ai_status = 1`、渠道天数规则和学员标签命中。
- 图书渠道口径为 `teach_help` 命中 `TeachHelpEnum.BOOK` 或 `TeachHelpEnum.HEZI`；非图书渠道按 D3 处理。
- OTS 标签校验必须限定到当前销售 `follow_user.userid`，不能用其他销售的标签代替。
- 非图书渠道 D3 触发后，学员必须在当前销售 OTS 标签下同时命中 `D1 完课` 和 `D2 完课`。
- 图书渠道 D4 触发后，学员必须在当前销售 OTS 标签下同时命中 `D1 完课`、`D2 完课` 和 `D3 到课`。
- `D1 完课`、`D2 完课`、`D3 到课` 的真实标签名称和标签组必须编码前确认，并集中维护为常量或配置。
- 图片生成沿用 Java SVG + Apache Batik，不引入 Chrome、Chromium、Puppeteer 或前端截图依赖。
- 图片生成、上传成功后才能投递整组发送任务；图片失败时不能先发文字，也不能投递延迟消息。
- 图片必须上传 OSS，图片消息 `payload.url` 必须使用上传后的可访问 OSS/CDN 地址，不得使用本地路径、临时路径或 Base64。
- 发送分散必须使用 RocketMQ 延迟消息，按学员维度随机延迟 0 到 30 分钟。
- RocketMQ topic 使用共有 `mq.delay.topic` / `DelayProperties.topic`，不为学习之星新增独立 topic。
- RocketMQ tag 必须使用学习之星新的专用 tag，不能复用图书物流 tag。
- RocketMQ consumer group 配置方式参考之前的 `delay-consumer-group: GID_delay_book_logistics_test`；实现时需要明确学习之星自己的 group 配置或实际 group 值。
- 每个学员只投递一条整组 RocketMQ 延迟消息，消息体承载 2 条待发送内容或可恢复 2 条内容的任务参数。
- RocketMQ 消费者必须按 2 条消息顺序调度 FC 延迟任务：图片、合并文字。
- 原 4 条文字必须合并为一条文字消息，话术顺序保持不变，段落之间使用换行。
- 每个学员和每条消息都必须有幂等设计，定时任务重复触发不能重复打扰学员。
- RocketMQ 重复消费、消费失败重试和 FC 部分成功重试时，也必须依靠整组 key 和每条 `externalRequestId` 保持幂等。
- 必须打印必要日志，覆盖营期筛选、渠道分类、学员圈选、OTS 标签匹配、图片生成、OSS 上传、MQ 投递、MQ 消费、FC 发送和跳过原因。
- 不改既有图书物流 Job、图书 unionId 补偿发送、AI 权限判断和 `sendJuzi(MsgSendInput)` 文字发送契约。

## 强制门禁

- 编码前必须确认 `ai_status` 字段真实名称和 DO/Mapper 可用性。
- 编码前必须确认当前销售企微 `qwUserId` 的真实来源。
- 编码前必须确认 `D1 完课`、`D2 完课`、`D3 到课` 在 OTS 中的真实 `tag_name` / `group_name`。
- 编码前必须确认好友关系是否要额外过滤 `status = 0`。
- 编码前必须确认渠道缺失时跳过还是默认非图书；当前规格默认跳过。
- 编码前必须确认 `kkhc-idc-ai` 加 Batik 依赖后仍兼容 JDK 1.8 和当前依赖树。
- 编码前必须确认学习之星 RocketMQ 延迟消息的 `MessageType`、新 tag 常量和 consumer group 实际值；topic 已明确复用共有 `mq.delay.topic`。
- 新增图片发送 helper 时必须断言 `messageType = 6`、`payload.url`、`externalUserId`、`wecomUserId`、`corpId`。
- 新增延迟投递 helper 时必须断言单学员单条整组消息、延迟范围 0 到 30 分钟、共有 topic、新 tag、messageType、body、deliveryTime 正确。
- 任何会新增数据库表、修改 FC 契约、修改现有 `MsgSendInput` 行为或改变图书物流任务的方案，都必须先更新规格并确认。

## 重点代码位置

- 图片 demo 入口：`C:\workspace\ju-chat\learning-star-certificate-demo\src\main\java\com\juchat\demo\LearningStarCertificateRenderer.java`
- demo 依赖参考：`C:\workspace\ju-chat\learning-star-certificate-demo\pom.xml`
- AI 服务实现参考：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\impl\AiServiceImpl.java`
- AI Controller：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\controller\AiController.java`
- AI Service 接口：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\AiService.java`
- 定时任务参考：`C:\workspace\ju-chat\kkhc\kkhc-bizcenter\schedule\src\main\java\com\kkhc\bizcenter\schedule\task\book\BookLogisticsSignStatusJob.java`
- Schedule Feign 参考：`C:\workspace\ju-chat\kkhc\kkhc-bizcenter\schedule\src\main\java\com\kkhc\bizcenter\schedule\feign\book\BookQuestionRecordFeign.java`
- 渠道教辅枚举：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\constant\ai\TeachHelpEnum.java`
- 文字发送入参：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\input\ai\MsgSendInput.java`
- Juzi 消息 DTO：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\dto\ai\JuziMessageDto.java`
- Juzi Payload：`C:\workspace\ju-chat\kkhc\kkhc-idc\base-common\src\main\java\com\kkhc\common\dto\juzi\Payload.java`
- 好友关系 DO：`C:\workspace\ju-chat\kkhc\kkhc-idc\lms-common\src\main\java\com\kkhc\idc\lms\common\module\dao\emp\EmpExternalUserDO.java`
- OTS 外部联系人 DTO：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\domain\external_user\ExternalUserDto.java`
- RocketMQ 延迟生产者：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\lms\mq\producer\DelayProducerBean.java`
- RocketMQ 延迟消费者参考：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\lms\mq\consumer\BookLogisticsDelayConsumerListener.java`
- RocketMQ 延迟测试参考：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\test\java\com\kkhc\idc\crm\service\ai\impl\BookLogisticsDelayMqTest.java`
- OSS 上传参考：`C:\workspace\ju-chat\kkhc\kkhc-idc\lms\src\main\java\com\kkhc\idc\lms\service\works\impl\NotePicsServiceImpl.java`

## 文档维护

- `spec.md` 描述业务需求、验收场景、参数来源、边界和成功标准。
- `tasks.md` 记录事实确认、风险门禁、实现任务和测试任务。
- `checklists\requirements.md` 验证规格质量和实施就绪度。
- 每次用户补充或推翻口径，必须追加 Dxxx 记录并同步更新相关文档。
