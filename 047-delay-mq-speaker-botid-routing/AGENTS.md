# 规格执行说明

本目录记录 `delay-mq` 通用聊天 Coze `botId` 按 `speakerId` 路由的实现规格。本阶段仅修改文档，不修改业务代码。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\047-delay-mq-speaker-botid-routing`
- 目标项目：`C:\workspace\ju-chat\fc\delay-mq`
- 参考项目：`C:\workspace\ju-chat\fc\audio-tts`
- 相关模块：`service`、`util`、`constants`、`dto`

## 当前目标

- 明确 `delay-mq` 获取 `speakerId` 的来源：通过 `campDateId` 调用 Center 查询 `CampInfo`。
- 明确 Coze `botId` 路由规则：赵曼固定、张曼默认、其他固定。
- 明确后续实现必须覆盖 V1、V2 通用聊天路径，并保护既有消息处理行为。

## 路由规则

- `speakerId=106`，赵曼：使用固定 `botId=7638948127407636514`。
- `speakerId=39`，张曼：使用原默认 botId，即当前 `dayEnum.getBotId()`。
- 其他 `speakerId`、null、Center 查询失败：使用固定 `botId=7638948127407636514`。

## 执行原则

- 本目录创建阶段不编码，只维护规格文档。
- 后续实现前必须重新读取当前业务代码，尤其注意 `fc/delay-mq` 可能已有未提交改动。
- 不把 `EmpExternalDto.user_bot_id` 当成 Coze `botID`；它当前用于 `LocalCacheUtil.getCorpId(...)`，语义必须保持不变。
- `speakerId=39` 的“原来默认”按 `DayEnum.getBotId()` 解释；如业务确认默认来源不同，先更新规格再实现。
- `resolvedBotId` 必须在 `CreateChatReq.builder().botID(...)` 前确定，并在日志中输出关键路由信息。
- Center 查询失败不得阻断原消息流程；按固定 botId 兜底。
- 不修改 MQ body、Redis key/TTL、OTS 查询、conversation key、作业点评分支、敏感词重试和企微发送行为。

## 强制门禁

后续实现前必须完成以下检查，并同步记录到 `tasks.md` 或 `spec.md`：

- 确认 `campDateId` 在 `AppTask` 和 `AppTaskV2` 进入 Coze 发送前可用。
- 确认 `CenterUtil.getCampInfoByCampDateId(campDateId)` 的异常、空响应、`data` 对象或字符串解析策略。
- 确认 `CozeUtil`、`CozeUtilV2` 中所有 `CreateChatReq.botID(...)` 调用都被覆盖。
- 确认 `speakerId=39` 不绕过现有 `dayEnum` 空值早退逻辑。
- 确认 `user_bot_id`、corpId 查询、企微消息发送链路没有被修改。
- 为每个路由分支建立 Coze 请求参数断言，不只断言最终回复是否发送。
- 单元测试不得真实访问 Redis、OTS、Center、Coze、RocketMQ 或 FC，除非另行明确做联调。

## 重点代码位置

- `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\service\AppTask.java`
- `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\service\AppTaskV2.java`
- `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\util\CozeUtil.java`
- `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\util\CozeUtilV2.java`
- `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\util\CenterUtil.java`
- `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\constants\DayEnum.java`
- `C:\workspace\ju-chat\fc\audio-tts\src\main\java\com\drh\audio\service\AppTask.java`
- `C:\workspace\ju-chat\fc\audio-tts\src\main\java\com\drh\audio\util\CenterUtil.java`

## 文档维护

- `spec.md` 描述用户场景、路由规则、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、后续实现任务和测试任务。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
