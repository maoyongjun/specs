# 规格执行说明：私域 AI Agent 接入配置

本目录记录 `juzi-service` 接入私域 AI Agent 的规格、任务、门禁和后续验证记录。当前阶段只创建 Spec Kit 文档，不修改业务代码。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\034-private-domain-ai-agent`
- 主要目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 合同相关模块：`C:\workspace\ju-chat\fc\ai-reply`
- 页面相关目录：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\resources\static`

## 当前目标

- 在原 `juzi-service` 配置中心新增功能入口，功能名称为“私域AI配置”。
- 使用 Redis 永久缓存维护私域企微 `user_id` 白名单和私域 Agent ID。
- 白名单未配置时默认 `15311073569`；Agent ID 未配置时默认 `7644079727246065664` 并打印可定位日志。
- 接收到消息后，先用企微 `user_id` 是否命中白名单判定私域；命中即走私域 Agent。
- 非私域消息才继续走现有 `skuId` 判断钢琴/声乐和旧路由逻辑。
- 私域 AI Agent 调用与微信回复仍由现有 `ai-reply` 函数计算完成。
- 私域没有 `dayN` 概念，也不走 SOP 作业点评回复。

## 执行原则

- 当前阶段只维护 `specs` 文档，不修改 `data-RC/juzi-service` 或 `fc/ai-reply` 业务代码。
- 实现前必须复核 `MessageServiceImpl#doSendMessage` 的真实分支位置，不允许只凭需求文本猜测。
- 私域 AI 权限只由企微 `user_id` 白名单控制，不允许再通过营期、`skuId`、`dayN` 判断私域权限。
- 私域命中后不得进入钢琴、声乐、SOP 作业点评或路由策略判定。
- 非私域路径必须保持现有钢琴、声乐、SOP、路由、延迟、幂等、人工回复静默和旁路新 Agent 验证链路不变。
- `ai-reply` 私域分支不得要求 `sku_id` 或 `DayEnum day`；如果为了兼容传入标记字段，也不能把标记当作旧 `skuId` 参与旧业务判断。
- Redis 写入私域配置必须无 TTL；读取失败或值为空时使用默认值，并记录可定位日志。
- 涉及 FC payload、Redis key、配置页面接口或 `ai-reply` 入参合同时，测试必须断言关键下游参数。

## 建议 Redis Key

- 私域白名单：`ai:private-domain:config:white-list:v1`
- 私域 Agent ID：`ai:private-domain:config:agent-id:v1`
- 私域会话：`ai:private-domain:coze:conversation:key:v1:{agentId}:{externalUserId}:{userId}:{env}`

以上 key 为规格建议；实现前若发现项目已有统一命名规范，可以更新本目录 Dxxx 记录后调整。

## 重点代码位置

- 主入口：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\MessageServiceImpl.java`
- 延迟/FC payload 构造：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\DelayMessageServiceImpl.java`
- FC 配置：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\config\FcConfig.java`
- Redis 安全工具：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\util\RedisSafeUtil.java`
- 配置中心鉴权路径：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\config\WebConfig.java`
- 配置中心首页：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\resources\static\index.html`
- 路由配置后台参考：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\controller\admin\RouteConfigAdminController.java`
- 学员下线 Redis 配置页参考：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\controller\admin\ExternalUserOnOffAdminController.java`
- `ai-reply` 入口：`C:\workspace\ju-chat\fc\ai-reply\src\main\java\com\drh\delay\consumer\service\AppTask.java`
- `ai-reply` Coze 调用和微信回复：`C:\workspace\ju-chat\fc\ai-reply\src\main\java\com\drh\delay\consumer\util\CozeUtil.java`
- `ai-reply` 入参 DTO：`C:\workspace\ju-chat\fc\ai-reply\src\main\java\com\drh\delay\consumer\dto\EmpExternalDto.java`
- 旁路新 Agent 验证：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\newagentverify`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户补充或纠正私域口径，都必须追加 Dxxx 执行记录，并同步更新本目录所有相关文档。
