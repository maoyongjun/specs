# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\099-juzi-dong-direct-coze-reply`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 相关模块：`MessageServiceImpl`、Dong 专属 Coze 直连 service、Juzi 文本发送 gateway、单元测试

## 当前目标

- 销售企微 `user_id=Dong` 的学员私聊文字/语音消息优先走 Dong 专属 Coze Bot。
- Coze Bot ID 固定默认 `7652273657926434831`，Coze `userID` 使用 `demo:{botId}:{externalUserId}:{userId}:{env}`。
- 收到 Coze 文本回复后，通过 `juzi-api` 发送文本消息给学员。
- Dong 命中后不进入旧私域、权限、SOP、路由或 `ai-reply FC` 链路。

## 执行原则

- 先确认入口、字段来源和下游读取，再实现。
- 不允许把空 JSON、空 DTO 或未赋值字段当成有效请求继续传递。
- Dong 分支必须可单测隔离真实 Coze、Redis、FC/Juzi。
- Coze 请求必须断言 `contentType=OBJECT_STRING` 和 SDK object JSON 数组内容。
- Juzi 发送必须断言 `functionCode=SEND_MESSAGE`、`type=1` 和 `MessageDto` 关键字段。

## 强制门禁

- 参数来源：`userId` 来自 `otsDto.user_id` / `messageDto.botWeixin`，`externalUserId` 来自 `otsDto.external_user_id`，消息文本来自入参 `text` 或 `payload.text/content`。
- 调用顺序：Dong 分支位于自消息处理之后、私域判断之前；返回 `true` 后旧链路不得继续。
- 常规单测：Coze 与 Juzi 发送必须通过可替换 gateway/client，不得真实调用。
- 真实验证：仅通过显式开启的 `DongDirectCozeAgentIT` 调用真实 Coze agent。
- 边界：非 Dong 返回 `false` 交还旧链路；Dong 但群聊、非文字/语音、空文本、Coze 空回复、异常均返回 `true` 消费消息并记录日志。

## 重点代码位置

- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\MessageServiceImpl.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\dongdirectcoze`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\test\java\com\drh\data\juzi\dongdirectcoze`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\test\java\com\drh\data\juzi\service\impl`

## 文档维护

- `spec.md` 描述场景、需求、边界、成功标准和执行记录。
- `tasks.md` 跟踪事实确认、风险门禁、实现和验证。
- `checklists/requirements.md` 验证规格质量和实施就绪度。
