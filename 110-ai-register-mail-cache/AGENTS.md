# 规格执行说明

本目录记录 `AI 登记邮寄缓存联动` 的规格、任务和验证结果。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\110-ai-register-mail-cache`
- 目标项目：
  - `C:\workspace\ju-chat\fc\ai-reply`
  - `C:\workspace\ju-chat\fc\delay-mq`
  - `C:\workspace\ju-chat\coze_plugin\external-info-select`
- 相关模块：AI Coze 回复发送、Redis 缓存、`AppTask` 外部信息返回。

## 当前目标

- AI 最终待发送内容包含 `已经给您登记邮寄` 时写入 5 分钟 Redis 缓存。
- Redis key 必须包含 `external_user_id`，统一为 `ai:reply:register-mail:if_register:{external_user_id}`。
- `external-info-select` 的 `AppTask` 返回前检查缓存，命中后强制 `if_register="是"`。

## 执行原则

- 先读代码，再定方案，后实现。
- 不扩大到 `ProfileTask/ProfileTaskV2`。
- Redis 读写异常只记录 warn，不阻断主流程。
- 写缓存必须位于发送前校验通过后，避免未发送的 AI 内容污染登记状态。
- 不修改 MQ body、FC 调用参数、OTS 表结构、外部 HTTP 请求和现有标签/物流解析规则。
- 单元测试覆盖 key、TTL、触发文案和 `AppTask` 纯逻辑覆盖。

## 强制门禁

- 参数来源：`external_user_id` 来自 `EmpExternalDto` 或 `external_key` 解析，使用前必须判空。
- 赋值时机：AI 内容来自 Coze answer 清洗后，缓存写入在实际发送前。
- 占位对象：`AppTask` 空 JSON 早退不做缓存覆盖。
- 下游读取：`AppTask` 返回前读取缓存并覆盖 `if_register`。
- 旧逻辑保持：敏感词、撤回、人工回复、空内容、`无法回答`、MD5 缓存、用户信息保存、标签和物流逻辑不变。
- 影响范围：只新增 Redis key/TTL 行为和 `AppTask` 返回字段覆盖。
- 测试映射：三个模块均有常量或纯逻辑测试。

## 重点代码位置

- `C:\workspace\ju-chat\fc\ai-reply\src\main\java\com\drh\delay\consumer\util\CozeUtil.java`
- `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\util\CozeUtil.java`
- `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\util\CozeUtilV2.java`
- `C:\workspace\ju-chat\coze_plugin\external-info-select\src\main\java\com\drh\select\service\AppTask.java`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
