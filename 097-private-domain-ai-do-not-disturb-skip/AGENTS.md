# 规格执行说明：私域 AI Agent「请勿打扰」标签跳过回复

本目录记录 `juzi-service` 私域 AI Agent 回复在命中「请勿打扰」客户标签时跳过回复的规格、任务、门禁和验证记录。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\097-private-domain-ai-do-not-disturb-skip`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 核心模块：`com.drh.data.juzi.service.impl.MessageServiceImpl`（私域分支 `handlePrivateDomainAiIfMatched`）
- 标签查询工具：`com.drh.data.juzi.util.OtsUtil#selectExternalUserTags`（查询 OTS `drh_external_user_info` 表）
- 私域常量：`com.drh.data.juzi.privatedomainai.PrivateDomainAiConstants`

## 当前目标

- 私域 AI Agent（默认 agentId `7644079727246065664`）回复前，先判断该客户在 OTS `drh_external_user_info` 表中是否含「请勿打扰」标签。
- 命中「请勿打扰」标签时，不调用私域 AI 回复（不下发 `sendPrivateDomainAiMessage`），并打印可定位日志后直接结束私域分支。
- 拦截作用于整个私域 AI 回复分支（命中私域白名单即生效），不限定具体 agentId 取值。
- 未命中「请勿打扰」标签或标签查询异常时，私域 AI 回复行为保持原状。

## 执行原则

- 复用现有 `OtsUtil.selectExternalUserTags(externalUserId, userId)`，不新增 OTS 表、不新增对外接口、不修改 MQ/Redis/FC 契约。
- 标签判定语义参考 `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\service\AppTask.java` 的 `com.drh.delay.consumer.service.AppTask#notNeedReplay`：先 `selectExternalUserTags` 取标签列表，再按 `tag_name` 精确匹配。
- 「请勿打扰」拦截只放在私域分支（`handlePrivateDomainAiIfMatched`）内，不得影响钢琴、声乐、SOP、路由、人工回复静默、旁路新 Agent 验证等非私域链路。
- 拦截判断放在「私域白名单命中 → 自消息过滤 → 回复时间窗校验」之后、获取 agentId 与下发回复之前，避免时间窗外多查一次 OTS。
- OTS 查询异常时降级为「不拦截、按原逻辑回复」，与参考方法 `notNeedReplay` 的异常口径一致，并打印 warn 日志。
- 涉及 OTS 读取、私域分支调用顺序的判断，测试必须断言「命中标签时不发送私域回复」「未命中时仍发送私域回复」。

## 重点代码位置

- 私域入口：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\MessageServiceImpl.java`（`handlePrivateDomainAiIfMatched`）
- 标签查询：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\util\OtsUtil.java`（`selectExternalUserTags`）
- 标签 DTO：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\dto\Juzi\FollowUser.java`（`Tag.tag_name`）
- 私域常量：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\privatedomainai\PrivateDomainAiConstants.java`
- 参考实现：`C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\service\AppTask.java`（`notNeedReplay`）
- 既有私域测试：`C:\workspace\ju-chat\data-RC\juzi-service\src\test\java\com\drh\data\juzi\service\impl\MessageServiceImplManualReplySilenceTest.java`

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：`externalUserId`、`userId` 在私域分支调用前已赋值；标签来源为 OTS `drh_external_user_info`。
- 占位对象：不引入空 DTO、空 JSON、空 Map 占位参数。
- 下游读取：仅读取 `FollowUser.Tag.tag_name`，与 `PrivateDomainAiConstants.DO_NOT_DISTURB_TAG_NAME` 精确比较。
- 旧逻辑保持：私域白名单、自消息缓存清理、回复时间窗、非私域全部链路保持不变。
- 影响范围：仅在私域分支新增一次 OTS 读取与一处提前返回，不改接口契约、MQ、Redis、数据库写入。
- 测试映射：标签匹配纯函数、命中拦截、未命中放行、异常降级、不回归均有测试或验证记录。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都追加 Dxxx 执行记录，并同步更新相关文档。
