# 规格执行说明

本目录记录“13 账号 5 月 15 日至 6 月 15 日私聊导出”的 Spec Kit 文档。本规格为文档与实现一体：先落文档，再在 `qw-user-message-export` 新增导出模式并补测试验证。

> 口径变更（见 spec.md D003）：最初要求“群聊+私聊都导出”，用户随后纠正为**只导出私聊、排除群聊**。目录名保留历史编号 `092-...-group-private`，当前实际口径为仅私聊。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\092-qw-chat-export-may15-group-private`
- 目标项目：`C:\workspace\ju-chat\qw-user-message-export`
- 相关模块：Java 8 Maven CLI，包名 `com.juchat.qwexport`

## 当前目标

- 新增专用 CLI 模式 `--mode may15-chat-export`，不覆盖现有 `export`、`jun3-chat-export`、`open-rate`、`activity-rate`、`interaction-rate`、`piano-daily-open-rate` 等模式。
- 通过 OTS 表 `juzi_private_message` 和索引 `juzi_private_message_index` 导出固定 13 个 `user_id` 的**私聊**聊天记录。
- 口径与既有 `export`/`jun3-chat-export` 一致：**只导出私聊**，排除群聊（`is_group=true`），复用私聊查询 `findExportMessages`/`buildExportRequest`。
- 固定账号（按下列顺序处理，均为企业微信员工 `user_id`，手机号串与字符串句柄都是合法取值）：
  `15101530402`、`15711286796`、`15711287096`、`15711287178`、`17801336372`、`15810091597`、`15711307826`、`15711287256`、`15711369328`、`15711287069`、`ZhangLiang_2`、`XiaoLiWei_1`、`zhonganqi1`。
- 固定时间窗口为 `2026-05-15 00:00:00 Asia/Shanghai` 到 `2026-06-15 23:59:59.999 Asia/Shanghai`，区间两端包含，且为固定窗口（不依赖运行时刻）。
- 输出沿用现有导出 CSV 七列：`message_source,isSelf,chat_name,contact_name,union_id,timestamp,text`。

## 执行原则

- 先读代码，再定方案，后实现。
- 后续实现必须保持既有模式行为不变，新增模式独立分派。
- 查询必须使用 OTS `user_id` 字段，不切换到 `external_user_id`，即使传入 `--field external_user_id` 也固定使用 `user_id`。
- 本模式**只导出私聊**：排除 `is_group=true`；`is_group=false` 或 `is_group` 不存在视为私聊进入结果。
- 保留老师和学员双方消息，不按 `isSelf` 过滤。
- 只输出 `payload.text` 可解析且非空的文本；`recall=1` 撤回消息跳过。
- 单个账号查询、单条消息解析或单行写入失败时，应记录错误并继续处理其他账号或消息。
- 测试不能只断言最终文件存在；必须断言下游 OTS 查询参数（固定 13 账号、固定时间窗口、`user_id` 字段、私聊过滤即排除群聊、时间闭区间、timestamp 升序）和 CSV 字段内容。

## 强制门禁

编码前必须完成并记录以下检查：

- 关键参数来源：固定 13 账号、固定开始时间、固定结束时间、OTS 字段名和输出目录。
- 赋值时机：账号列表和时间窗口必须在调用 `OtsMessageRepository` 前确定，均为编译期常量推导，无运行期占位。
- 占位对象：不得把空 DTO、空 JSON、空 Map 或未赋值字段作为有效查询条件下传。
- 下游读取：本模式复用私聊 `buildExportRequest`，查询读取 `user_id`、`timestamp` + 私聊 should 子句（`is_group` 不存在或 `false`），返回 `payload`、`timestamp`、`message_source`、`isSelf`、`type`、`recall`、`is_group`、`chat_name`、`contact_name`、`external_user_id`、`user_id`。
- 旧逻辑保持：既有模式、私聊 `buildExportRequest`、CSV 写入、`union_id` 查询、分页、切片、错误日志和 10MB 切分口径保持不变。
- 测试映射：新增 mode 解析、分派、固定参数、私聊过滤（排除群聊）、输出字段、异常不中断都要有测试覆盖。

## 重点代码位置

- `C:\workspace\ju-chat\qw-user-message-export\src\main\java\com\juchat\qwexport\MessageExportApp.java`
- `C:\workspace\ju-chat\qw-user-message-export\src\main\java\com\juchat\qwexport\ExportConfig.java`
- `C:\workspace\ju-chat\qw-user-message-export\src\main\java\com\juchat\qwexport\OtsMessageRepository.java`
- `C:\workspace\ju-chat\qw-user-message-export\src\main\java\com\juchat\qwexport\RollingCsvWriter.java`
- `C:\workspace\ju-chat\qw-user-message-export\src\test\java\com\juchat\qwexport`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 用户后续补充或纠正需求时，追加 Dxxx 执行记录，并同步更新 `spec.md`、`tasks.md` 和本文件。
