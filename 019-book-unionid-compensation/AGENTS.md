# 规格执行说明

本目录记录 `019-book-unionid-compensation`，作用范围包含：

- 规格文档：`C:\workspace\ju-chat\specs\019-book-unionid-compensation`
- 目标代码：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\controller\AiController.java`
- 目标代码：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\impl\AiServiceImpl.java`
- 目标代码：`C:\workspace\ju-chat\kkhc\kkhc-bizcenter\schedule\src\main\java\com\kkhc\bizcenter\schedule\feign\book\BookQuestionRecordFeign.java`
- 目标代码：`C:\workspace\ju-chat\kkhc\kkhc-bizcenter\schedule\src\main\java\com\kkhc\bizcenter\schedule\task\book\BookQuestionRecordCompensationJob.java`

## 当前目标

- 在 AI 服务侧提供图书 `unionId` 补偿接口。
- 按当天范围分页处理，每页 `200` 条待补偿记录。
- 通过 `phone_number -> external_user_id -> unionId` 补全数据，再向学员发送消息。
- 学员消息内容必须与参考实现 `sendMsgStudent` 保持一致，`type=1`，热线 `4006689062`。
- schedule 侧 job 仅负责异步触发，不等待批处理结束。

## 实现约束

- 不新增数据库表、公共 DTO 或配置项。
- `drh_ai_external_base_info` 的 OTS 索引名按项目现有约定落地，如实际命名不同只改常量。
- `lIds` 按 JSON 数组字符串解析，使用最后一个有效单号作为本次发送 `lId`。
- job / Feign 采用现有项目的异步与日志风格。

## 文档维护

- `spec.md` 描述用户场景、功能需求、边界情况、成功标准和假设。
- `tasks.md` 记录实现任务拆分与验证项。
- `checklists/requirements.md` 用于进入实现前验证规格质量。
