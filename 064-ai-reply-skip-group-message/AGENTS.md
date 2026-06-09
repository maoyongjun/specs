# 规格执行说明：ai-reply 群消息跳过

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\064-ai-reply-skip-group-message`
- 目标项目：`C:\workspace\ju-chat\fc\ai-reply`
- 相关模块：`ai-reply` FC 入口 `com.drh.delay.consumer.service.AppTask`

## 当前目标

- `isGroup=true` 的消息进入 `fc/ai-reply` 后直接跳过。
- 群消息不访问 Redis、OTS、Coze，不执行红包/转账识别和提醒。
- 保持非群消息现有普通 AI 和私域 AI 回复链路不变。

## 已确认事实

- 上游 `juzi-service` 构造 `ai-reply` 入参时，以 `roomWecomChatId` 是否为空写入 `isGroup`。
- `rocket-mq-consumer` 对 `sku_id=4` 的消息转发到 `ai-reply`，不负责群消息过滤。
- `AppTask.handleRequest` 原先在 `isGroup=true` 时会查询群 OTS 消息，并继续创建 Coze 会话和发送。
- 用户确认本需求采用“完全跳过”口径：群消息在 `ai-reply` 内不保留任何副作用。

## 执行原则

- 只改 `fc/ai-reply`，不改上游 `juzi-service`、`rocket-mq-consumer`、MQ body、Redis key、数据库或配置契约。
- 仅使用 `EmpExternalDto.isGroup` 判定群消息，不新增 `roomWecomChatId` 兜底规则。
- 群消息门禁必须早于 `RedisClient` 创建、私域 AI 分流、红包/转账识别、OTS 查询和 Coze 调用。
- 非群消息旧逻辑保持不变。

## 重点代码位置

- `C:\workspace\ju-chat\fc\ai-reply\src\main\java\com\drh\delay\consumer\service\AppTask.java`
- `C:\workspace\ju-chat\fc\ai-reply\src\test\java\com\drh\delay\consumer\service\PrivateDomainAppTaskTest.java`

## 验证命令

- `mvn -pl ai-reply -am -Dtest=PrivateDomainAppTaskTest -DfailIfNoTests=false '-Dsurefire.failIfNoSpecifiedTests=false' test`

## 文档维护

- `spec.md` 记录目标、边界、成功标准和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现和测试结果。
- `checklists/requirements.md` 记录规格质量和实施就绪度。
