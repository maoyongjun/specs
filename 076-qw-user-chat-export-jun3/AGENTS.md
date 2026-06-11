# 规格执行说明

本目录记录“四账号 6 月 3 日起私聊导出”的 Spec Kit 文档。当前阶段只创建规格文档，不修改业务代码。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\076-qw-user-chat-export-jun3`
- 目标项目：`C:\workspace\ju-chat\qw-user-message-export`
- 相关模块：Java 8 Maven CLI，包名 `com.juchat.qwexport`

## 当前目标

- 后续新增专用 CLI 模式 `--mode jun3-chat-export`，不覆盖现有 `export`、`open-rate`、`interaction-rate` 等模式。
- 通过 OTS 表 `juzi_private_message` 和索引 `juzi_private_message_index` 导出固定四个 `user_id` 的私聊聊天记录。
- 固定账号为 `maiweigml`、`LiXin`、`XieWenHao1`、`LiuYuan_3`。
- 固定时间窗口为 `2026-06-03 00:00:00 Asia/Shanghai` 到程序运行时刻，区间两端包含。
- 输出沿用现有私聊 CSV 七列：`message_source,isSelf,chat_name,contact_name,union_id,timestamp,text`。

## 执行原则

- 先读代码，再定方案，后实现。
- 本规格当前只落文档，不修改 `qw-user-message-export` 代码。
- 后续实现必须保持既有模式行为不变，新增模式独立分派。
- 后续查询必须使用 OTS `user_id` 字段，不切换到 `external_user_id`。
- 后续导出必须排除群聊：`is_group` 不存在或为 `false` 才进入结果。
- 后续导出必须保留老师和学员双方消息，不按 `isSelf` 过滤。
- 后续导出只输出 `payload.text` 可解析且非空的文本；`recall=1` 撤回消息跳过。
- 单个账号查询、单条消息解析或单行写入失败时，应记录错误并继续处理其他账号或消息。
- 测试不能只断言最终文件存在；必须断言下游 OTS 查询参数、固定账号列表、时间窗口、私聊过滤和 CSV 字段内容。

## 强制门禁

后续编码前必须完成并记录以下检查：

- 关键参数来源：固定四账号、固定开始时间、运行时刻结束时间、OTS 字段名和输出目录。
- 赋值时机：账号列表和时间窗口必须在调用 `OtsMessageRepository` 前确定。
- 占位对象：不得把空 DTO、空 JSON、空 Map 或未赋值字段作为有效查询条件下传。
- 下游读取：`OtsMessageRepository` 查询读取 `user_id`、`timestamp`、`is_group`、`payload`、`message_source`、`isSelf`、`chat_name`、`contact_name`、`external_user_id`、`recall`。
- 旧逻辑保持：既有模式、CSV 写入、`union_id` 查询、分页、切片、错误日志和 10MB 切分口径保持不变。
- 测试映射：新增 mode 解析、分派、固定参数、输出字段、异常不中断都要有测试或静态验证记录。

## 重点代码位置

- `C:\workspace\ju-chat\qw-user-message-export\src\main\java\com\juchat\qwexport\MessageExportApp.java`
- `C:\workspace\ju-chat\qw-user-message-export\src\main\java\com\juchat\qwexport\ExportConfig.java`
- `C:\workspace\ju-chat\qw-user-message-export\src\main\java\com\juchat\qwexport\OtsMessageRepository.java`
- `C:\workspace\ju-chat\qw-user-message-export\src\main\java\com\juchat\qwexport\RollingCsvWriter.java`
- `C:\workspace\ju-chat\qw-user-message-export\src\test\java\com\juchat\qwexport`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、后续实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 用户后续补充或纠正需求时，追加 Dxxx 执行记录，并同步更新 `spec.md`、`tasks.md` 和本文件。
