# 规格执行说明

本目录记录 `016-qw-user-message-export` 的规格与实现约定，后续修改应保持文档与项目代码同步。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\016-qw-user-message-export`
- 参考代码：`C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\util\OtsUtil.java`
- 参考方法：`OtsUtil#getLatestMessage`
- 目标 OTS 表：`juzi_private_message`
- 目标 OTS 索引：`juzi_private_message_index`

## 当前目标

- 规划一个后续可实现的消息导出项目和开口率统计能力。
- 项目读取自身目录下的 `userIds.txt` 文件。
- `userIds.txt` 每行存放一个 `qwUserId`。
- 系统按 `qwUserId` 逐个查询最近三个月用户发送的消息。
- 导出消息到 `txt` 文件，每条消息一行。
- 单个输出文件超过 10MB 前应切换到新文件继续写入。
- 统计 5 月 8 日至执行当天的开口率，支持“新增学员模式”和“全量学员模式”，按 `user_id` 输出已开口与未开口名单，以及样本消息信息；新增学员模式兼容两种招呼语。
- 当前需要统计的 `user_id` 固定为 `15313122087`、`15110220704`、`15110180421`、`15110220914`。
- 导出结果用于后续对这些用户发送的消息做归类整理。

## 后续实现约束

- 后续实现应复用或参考 `OtsUtil#getLatestMessage` 的 OTS 客户端、SearchRequest、SearchQuery、索引和列读取方式。
- 查询必须使用 `timestamp` 限定最近三个月时间范围。
- 查询必须限定用户发送的消息，即 `isSelf=false`。
- 查询必须限定目标消息类型为 `type in (2, 7)`。
- 导出内容必须从 `payload` JSON 中解析 `text` 字段。
- 每条有效消息在输出 `txt` 中只占一行。
- 空白行、空 `qwUserId`、空 `payload.text` 不应产生输出消息行。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录后续实现和验证任务。
- `checklists/requirements.md` 用于验证规格质量和实施就绪度。
