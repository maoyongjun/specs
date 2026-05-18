# 规格执行说明

本目录记录 `020-qw-user-message-export-906` 的规格与实现约定，后续修改应保持文档与项目代码同步。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\020-qw-user-message-export-906`
- 目标项目：`C:\workspace\ju-chat\qw-user-message-export`
- 输出内容：`message_source`、`isSelf`、`chat_name`、`contact_name`、`text`

## 当前目标

- 先编写 Spec Kit 文档，不修改业务代码。
- 后续实现用于导出指定三个账号的私聊聊天记录。
- 导出范围仅限 `yangfan`、`LiYan`、`ZengYan` 三个账号。
- 导出范围仅限最近 10 天内的聊天记录。
- 导出老师和用户双方消息，不做 `isSelf` 过滤。
- 不导出群聊消息。
- 只保留 `chat_name` 以 `906` 开头的记录。
- 输出格式按行文本，字段顺序为 `message_source<TAB>isSelf<TAB>chat_name<TAB>contact_name<TAB>text`，其中 `message_source` 保持原始值，`isSelf` 转换为老师/学员标签。

## 后续实现约束

- 后续实现应先确认 `yangfan`、`LiYan`、`ZengYan` 对应的查询字段。
- 查询必须支持分页，避免遗漏记录。
- 查询必须限定最近 10 天时间范围。
- 查询必须同时满足账号范围、私聊范围和 `chat_name` 前缀条件。
- 输出字段必须保持固定顺序，不额外增加列，其中 `message_source` 原样输出、`isSelf` 仅做展示转换。
- 实现阶段若发现 `chat_name` 或 `contact_name` 来源不一致，应在代码与规格中统一口径。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录后续实现和验证任务。
- `checklists/requirements.md` 用于验证规格质量和实施就绪度。
