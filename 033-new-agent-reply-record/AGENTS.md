# 规格执行说明

本目录记录新 Agent 上线验证结果落库需求。当前已完成 `juzi-service` 代码实现与文档状态更新，DDL 仍只作为提案未执行。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\033-new-agent-reply-record`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 参考项目：`C:\workspace\ju-chat\fc\delay-mq`
- 相关模块：消息接收、延迟 AI 回复、Coze Agent 调用、OTS 历史消息查询、MySQL 结果落库、Nacos 配置。

## 当前目标

- 对配置的销售企业微信 `user_id` 做新 Agent `7638948127407636514` 上线验证。
- 默认销售 `user_id` 白名单为 `ZhangFuYi02`、`liuyongqi02`、`DengPiaoPiao_1`、`ShuDie2`、`LiXin9_1`，Nacos 配置为空时使用该默认值。
- 只处理私聊学员消息，群聊消息不进入验证链路。
- 原 AI 权限为 `false` 时，只要可通过 `IdSetDto.empId`、企微“营期”标签名映射出的 `campDateId` 和营期 `dayNum` 补齐验证上下文，也进入新 Agent 影子验证。
- 新 Agent 回复只写入 `drh_new_agent_reply_record`，不发送给学员。
- 原延迟 MQ / AI 回复链路保持不变，新 Agent 是影子调用。

## 执行原则

- 先读代码，再定方案，后实现。
- `juzi-service` 业务代码改动必须服务于本需求范围，并保持原延迟 MQ / AI 回复链路不变。
- 新 Agent 验证必须封装为单独 service 方法，由 `MessageServiceImpl` 调用。
- 不允许将新 Agent 返回内容传给任何发送学员消息的能力。
- 不允许因为新 Agent 调用失败影响原 `sendDelayMessage`、路由、SOP、作业点评或原 Coze 回复链路。
- 不允许处理群聊消息；`roomWecomChatId` 或 `roomTopic` 任一存在时必须跳过验证。
- 不允许把空 `external_user_id`、空 `message_id`、空销售 `user_id`、空历史消息请求继续下传给 Coze。
- 涉及 Coze、OTS、MySQL、Redis conversation key 和 Nacos 配置时，测试必须断言关键下游参数。

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：销售 `user_id`、`external_user_id`、`message_id`、`student_message`、`day_n`、`agent_id` 从哪里来。
- 赋值时机：验证 service 调用前必须已经获取 `external_user_id`、销售 `user_id`，且 `selectUserPermission` 已返回；触发点必须在原 AI 权限 `return` 前。
- 无权限上下文：`UserInfoDto` 缺少 `empId/campDateId/day` 时，必须优先使用 `IdSetDto.empId`、企微“营期”标签名到 `drh_live_camp_date.name -> id` 的缓存映射和营期接口 `dayNum` 兜底，仍不允许用空值调用 Coze。
- 营期缓存：新 Agent 验证必须使用独立 Redis key `ai:juzi:new-agent:camp-date-id-map:v1` 和 lock key `ai:juzi:new-agent:camp-date-id-map:lock:v1`，不得复用 `kkhc-idc-ai` 的 `ai:camp_date_id_list`。
- Coze 消息前缀：历史消息不得追加 `"&&" + request.getUserId() + "&&  "`；该前缀只追加到最后一条学员消息，最后一条为销售自己消息时跳过 Coze。
- 当前消息类型：新 Agent 仅处理文字 `MessageType.TEXT(7)` 与语音 `MessageType.VOICE(2)`；图片、视频、表情、文件、图文等其他类型必须在验证入口跳过。
- 多段回复落库：Coze stream 中多个 `CONVERSATION_MESSAGE_COMPLETED + ANSWER` 事件必须按顺序合并记录到 `ai_reply`，不得覆盖成最后一条。
- 异步日志：新 Agent 异步入口必须绑定 MDC `requestId`，触发异步前应从当前线程 MDC 补齐 DTO requestId，异步结束后清理。
- 占位对象：不得把空 DTO、空历史消息列表、空 Coze 请求或空落库对象当作有效输入。
- 下游读取：Coze 请求和落库字段必须全部有来源，允许 `union_id`、`nick_name` 为空但要记录来源策略。
- 旧逻辑保持：原 MQ body、发送逻辑、路由表契约和群聊现有行为不变。
- 影响范围：新增 Nacos 配置、Coze SDK 依赖、MySQL 表、Mapper 扫描和验证 service；不得改动无关模块。
- 测试映射：每个关键行为至少对应一条单元测试或静态验证记录。

## 重点代码位置

- 入口类：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\MessageServiceImpl.java`
- 延迟任务构造参考：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\DelayMessageServiceImpl.java`
- 原 Coze 调用参考：`C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\util\CozeUtilV2.java`
- 原历史消息查询参考：`C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\util\OtsUtil.java`
- Mapper 扫描配置：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\route\config\RouteMybatisPlusConfig.java`
- 测试目录：`C:\workspace\ju-chat\data-RC\juzi-service\src\test\java\com\drh\data\juzi`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- `create-new-agent-reply-record.sql` 是未执行 DDL 提案，执行前必须重新审核并由 DBA 或发布流程确认。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
- 最新执行记录为 D010：Coze 多个 completed answer 事件已按顺序合并落库，不再只记录最后一条 Agent 回复。
