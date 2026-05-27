# 功能规格：私域 AI Agent 接入配置

**功能目录**：`034-private-domain-ai-agent`  
**创建日期**：`2026-05-27`  
**状态**：Implemented  
**输入**：用户要求在 `C:\workspace\ju-chat\specs` 创建 spec-kit 文档，先不修改代码。需要在 `juzi-service` 接入私域 AI Agent，不能影响现有钢琴、声乐、以及旁路记录 AI 回复验证链路。私域 AI 通过企业微信 id 白名单控制 AI 权限，不再通过营期和 `skuId` 配置。配置功能加到以前 `juzi-service` 配置页面，功能名“私域AI配置”。白名单写入 Redis 永久缓存，未配置默认 `15311073569`，白名单逗号分隔。配置页还要配置私域 `agentId`，同样写入 Redis 永久缓存；缓存没有时默认 `7644079727246065664` 并打印日志。AI Agent 调用和微信回复沿用以前 `ai-reply` 函数计算完成。私域没有 `dayN` 概念，也没有 SOP 作业点评回复。判定是否走私域 Agent 只用企业微信 id 命中；非私域才去用旧 `skuId` 判断声乐/钢琴以及判断路由。

## 背景

- 当前问题：现有 AI 权限和 Agent 路由主要依赖营期、`skuId`、`day` 和路由配置；私域业务需要按销售企微 `user_id` 白名单直接获得 AI 能力。
- 当前行为：`MessageServiceImpl#doSendMessage` 在消息入库和基础过滤后调用 `userCheckService.selectUserPermission`，再触发旁路新 Agent 验证；无 AI 权限会返回；有权限后，声乐或空 `skuId` 走默认 AI 回复，其他 `skuId` 再走 SOP/路由判断。
- 当前行为：`DelayMessageServiceImpl#createJSONObject` 构造给 FC 的 payload，会写入 `day=dayN`、`sku_id` 和 `agent_id`；命中路由时使用 `fc.common_function_name/common_service_name`。
- 当前行为：`fc/ai-reply` 的 `AppTask` 当前会在 `agent_id` 或 `sku_id` 为空时跳过，conversation key 也绑定 `DayEnum day`；私域无 `dayN` 时需要单独私域分支或合同适配。
- 目标行为：命中私域白名单的企微 `user_id` 直接走私域 AI Agent，由 `ai-reply` 完成 Agent 调用和微信回复；非私域消息保持现有钢琴、声乐、SOP、路由和旁路验证逻辑。
- 非目标：当前阶段不修改业务代码、不执行发布、不改数据库结构、不迁移已有路由配置、不改变现有钢琴/声乐/SOP/旁路验证链路。

## 用户场景与测试

### 用户故事 1 - 配置私域 AI 白名单和 Agent（优先级：P1）

运营或开发在 `juzi-service` 配置中心打开“私域AI配置”，维护允许使用私域 AI 的企微 `user_id` 白名单和私域 Agent ID。

**独立测试**：通过配置页接口的单元测试或 MockMvc 测试，验证默认读取、保存、Redis 无 TTL 写入、逗号分隔解析和异常返回。

**验收场景**：

1. **Given** Redis 中没有私域白名单，**When** 页面加载当前配置，**Then** 返回默认白名单 `15311073569`，并标记来源为默认值。
2. **Given** Redis 中没有私域 Agent ID，**When** 业务读取 Agent ID，**Then** 返回默认 `7644079727246065664`，并打印包含 Redis key 的日志。
3. **Given** 页面提交 `A,B, C,,`，**When** 保存白名单，**Then** Redis 永久缓存规范化后的逗号分隔值，空项被忽略，后续读取命中 `A`、`B`、`C`。
4. **Given** 页面提交新的 Agent ID，**When** 保存成功，**Then** Redis 永久缓存该 Agent ID，后续私域消息使用该值调用 `ai-reply`。

### 用户故事 2 - 私域用户优先走私域 Agent（优先级：P1）

命中白名单的销售企微 `user_id` 收到学员消息后，不再依赖营期、`skuId` 或 `dayN` 判断是否有 AI 权限，而是直接构造私域 AI payload 给 `ai-reply` 函数计算处理。

**独立测试**：构造白名单命中的消息，模拟旧权限为 false、`skuId` 为空、`day` 为空，断言仍调用 `ai-reply` FC，且 payload 包含私域标记、私域 `agent_id`、`external_user_id`、`user_id`、消息文本和消息 ID，不包含必须依赖 `dayN` 的路由参数。

**验收场景**：

1. **Given** `user_id=15311073569` 且 Redis 未配置白名单，**When** 收到学员消息，**Then** 命中默认白名单并走私域 Agent。
2. **Given** `user_id` 命中白名单且旧 `selectUserPermission.permission=false`，**When** 收到学员消息，**Then** 不因旧 AI 权限失败而阻断私域 Agent 调用。
3. **Given** `user_id` 命中白名单且 `skuId/day` 缺失，**When** 构造 FC payload，**Then** 不伪造 `dayN`，也不要求 `sku_id` 参与私域权限判定。
4. **Given** 私域 Agent 返回回复内容，**When** `ai-reply` 处理成功，**Then** 仍使用既有 `sendJuzi` 微信发送能力回复学员。

### 用户故事 3 - 非私域旧链路不回归（优先级：P1）

未命中白名单的消息继续沿用现有 `skuId`、声乐/钢琴、SOP、路由和旁路记录验证流程。

**独立测试**：复用现有 `MessageServiceImpl`、路由、SOP 和 `NewAgentVerifyService` 测试，增加非私域用例，断言旧方法调用顺序和关键 payload 不变。

**验收场景**：

1. **Given** `user_id` 未命中白名单且 `skuId=5` 声乐，**When** 收到学员消息，**Then** 继续走原默认 AI 回复分支，不进入私域 Agent。
2. **Given** `user_id` 未命中白名单且 `skuId=4` 钢琴，**When** 收到学员消息，**Then** 继续执行原 SOP/路由判断，不进入私域 Agent。
3. **Given** 旁路新 Agent 验证白名单命中，**When** 非私域消息进入原流程，**Then** 旁路记录 AI 回复验证仍按当前逻辑触发或跳过，不被私域配置影响。
4. **Given** 销售手动发送消息，**When** 系统处理该消息，**Then** 仍执行现有人工回复清理/静默逻辑，不触发私域 AI 回复。

### 用户故事 4 - 私域 Agent 查询通用用户画像（优先级：P1）

私域 Agent 调用 `select_user_info` 插件时，使用 `private-domain:{agentId}:{externalUserId}:{userId}:{env}` 作为 `external_key`，插件不再按旧营期 key 解析，而是按 `external_user_id` 查询通用用户画像。

**独立测试**：构造私域 key，mock `drh_external_user_info` 单行结果和 `drh_ai_external_base_info` 多条搜索结果，断言返回通用画像字段，不返回 `day/campDateId/transfer_amount` 等营期字段。

**验收场景**：

1. **Given** `external_key=private-domain:7644449532675866662:wmQcc1XAAAMcqWzuGhnxeimIFnLjFpHA:15311073569:default`，**When** 插件处理请求，**Then** 解析出 `agent_id`、`external_user_id`、`user_id` 和 `env`。
2. **Given** `drh_external_user_info` 中存在 `external_user_id` 对应记录，**When** 私域插件查询，**Then** 返回 `name` 等外部联系人通用信息。
3. **Given** `drh_ai_external_base_info` 中同一个 `external_user_id` 可能命中多条基础信息，**When** 私域插件查询，**Then** 搜索 `limit=1` 并取其中一条即可。
4. **Given** 私域无营期和天数概念，**When** 返回插件结果，**Then** 不返回 `day`、`camp_date_id`、`transfer_amount`、`class_info`、`song`、`week_num`、`task_class_session`。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
- `user_id`：来源 `MessageServiceImpl#doSendMessage` 中 `otsDto.getString("user_id")`，含义为销售企微 id；私域白名单匹配必须在调用私域 Agent 前完成。
- `external_user_id`：来源 `otsDto.getString("external_user_id")`，必要时通过 `imContactId` 兜底回填；为空时沿用现有 `user_info_empty_ignore` 跳过。
- 私域白名单：来源 Redis key `ai:private-domain:config:white-list:v1`；读取为空或缺失时使用默认 `15311073569`；写入时无 TTL。
- 私域 `agent_id`：来源 Redis key `ai:private-domain:config:agent-id:v1`；读取为空或缺失时使用默认 `7644079727246065664` 并记录日志；写入时无 TTL。
- `fc.common_function_name/common_service_name`：来源 `FcConfig`；私域仍调用 `ai-reply` 函数计算，具体函数名必须实现前确认当前环境配置。
- `skuId`：来源 `UserInfoDto.getSkuId()`，只允许非私域旧链路使用；私域不得通过 `skuId` 判定权限。
- `day` / `dayN`：来源 `UserInfoDto.getDay()`，只允许旧链路使用；私域不得依赖或伪造 `dayN`。
- 下游读取字段清单：
- `MessageServiceImpl#doSendMessage` 读取 `external_user_id`、`user_id`、`payload.text`、`messageDto.isSelf`、`source`、`roomTopic`、`type`、`UserInfoDto.permission`、`skuId`、`day`。
- `DelayMessageServiceImpl#createJSONObject` 当前读取 `UserInfoDto.campDateId`、`empId`、`day`、`routeExecutionPlanDto.skuId`、`agentDecision.agentId` 并写入 FC payload。
- `fc/ai-reply AppTask` 当前读取 `redisKey`、`timestamp`、`agent_id`、`sku_id`、`day`、`isGroup`、`msgType`、`messageId`，并按 OTS 历史消息构造 Coze 请求。
- `fc/ai-reply CozeUtil` 当前读取 `agent_id` 作为 Coze `botID`，读取 `DayEnum` 构建旧 conversation key 和部分后置逻辑。
- `coze_plugin/external-info-select AppTask` 当前按旧 `external_key=external_user_id:emp_id:camp_date_id:user_id...` 解析，随后调用 `CenterUtil.selectUserJson`、`DayEnum.createCozeJson` 和 `setChatMoney`；私域 key 必须在旧解析前分流。
- 私域 `select_user_info` key：`private-domain:{agentId}:{externalUserId}:{userId}:{env}`，例如 `private-domain:7644449532675866662:wmQcc1XAAAMcqWzuGhnxeimIFnLjFpHA:15311073569:default`。
- 私域用户画像来源：`drh_external_user_info` 可按 `external_user_id` 单行读取；`drh_ai_external_base_info` 需按 `external_user_id` 搜索，可能多条，取任意一条即可。
- 空对象 / 占位对象风险：
- 当前旧 FC payload 默认写入 `sku_id=null`、`agent_id=null`，命中路由时才赋值；私域不能沿用这种“空字段继续传递”方式，必须在当前层构造明确的私域 payload。
- 私域配置读取到空白字符串时不能视为有效配置，必须回退默认值。
- 调用顺序风险：
- 当前 `triggerNewAgentVerifyAndShouldSkipForNoAiPermission` 同时触发旁路验证和旧权限早退；实现私域时不得让旧权限早退阻断白名单命中的私域 AI。
- 当前销售自发消息的清理逻辑在旧权限判断后；实现私域时必须保证自发消息仍不会触发私域 AI。
- 当前 `ai-reply` conversation key 绑定 `day`；私域无 `dayN` 时必须使用独立私域 conversation key。
- 旧逻辑保持：
- 非私域消息继续执行 `userCheckService.selectUserPermission`、无权限跳过、声乐默认分支、钢琴 SOP/路由分支、延迟合并、撤回检查、人工回复静默、媒体跳过、Redis 幂等和告警。
- 旁路 `NewAgentVerifyService` 相关逻辑不得被私域配置替换或删除。
- 需要用户确认的设计选择：
- 无。当前规格采用“私域命中优先，非私域走旧链路”的用户口径；若后续需要私域也参与群聊、SOP 或作业点评，必须追加纠正记录。

## 边界情况

- Redis 白名单 key 不存在、值为空、全是空格或全是逗号：使用默认 `15311073569`。
- Redis Agent ID key 不存在、值为空或全是空格：使用默认 `7644079727246065664`，打印包含 key、默认值、触发场景的日志。
- 白名单项前后有空格：匹配前 trim；空项忽略；重复项不影响匹配。
- `user_id` 为空：沿用现有空用户跳过逻辑，不进入私域 Agent。
- `external_user_id` 为空：沿用现有空用户跳过逻辑，不进入私域 Agent。
- 销售自发消息：不触发私域 Agent，仍保留现有 `removeCache` 和人工回复静默相关行为。
- 撤回消息、招呼语、当前已被旧前置过滤 return 的消息：不新增私域处理能力。
- 私域消息不读取 SOP 作业点评 gate，不触发 `sop-reply`，不构造 `routeParams.day` 或 `actualDayNum` 作为私域必需参数。
- 私域 `select_user_info` 不调用旧营期权限接口，不构造 `DayEnum` 返回体，不伪造 `day0`。
- 私域 `select_user_info` 若 `drh_ai_external_base_info` 未命中或搜索异常，仍返回 `drh_external_user_info` 中可用的通用字段。
- Redis 读取异常：记录日志并使用默认配置；Redis 写入异常：配置接口返回失败，避免页面误报保存成功。
- `ai-reply` 私域 Agent 调用失败：由 `ai-reply` 记录错误，不回退到旧钢琴/声乐/SOP/路由分支。

## 需求

### 功能需求

- **FR-001**：系统 MUST 在配置中心新增“私域AI配置”入口，页面可读取和保存私域白名单与私域 Agent ID。
- **FR-002**：系统 MUST 将私域白名单写入 Redis 永久缓存，不设置 TTL。
- **FR-003**：系统 MUST 将私域 Agent ID 写入 Redis 永久缓存，不设置 TTL。
- **FR-004**：系统 MUST 在白名单未配置时使用默认 `15311073569`。
- **FR-005**：系统 MUST 在 Agent ID 未配置时使用默认 `7644079727246065664`，并打印可定位日志。
- **FR-006**：系统 MUST 按逗号分隔解析白名单，trim 每个企微 `user_id`，忽略空项。
- **FR-007**：系统 MUST 使用消息中的销售企微 `user_id` 命中白名单作为私域判定条件。
- **FR-008**：系统 MUST 在私域命中后跳过旧 `skuId` 权限判断、声乐/钢琴分支、SOP 作业点评和路由判断，直接构造私域 AI FC payload。
- **FR-009**：系统 MUST 在非私域消息上保持现有 `skuId`、声乐、钢琴、SOP、路由和延迟回复逻辑不变。
- **FR-010**：系统 MUST 继续通过 `ai-reply` 函数计算完成私域 Agent 调用和微信回复。
- **FR-011**：系统 MUST 为 `ai-reply` 提供明确私域标记，例如 `private_ai=true` 或 `ai_scene=PRIVATE_DOMAIN`，避免与旧路由 payload 混淆。
- **FR-012**：`ai-reply` 私域分支 MUST 使用 payload 中的私域 `agent_id` 作为 Coze Agent，不依赖 `DayEnum` 默认 botId。
- **FR-013**：`ai-reply` 私域分支 MUST NOT 因 `sku_id` 为空或 `day` 为空而跳过。
- **FR-014**：`ai-reply` 私域分支 MUST 使用独立 conversation key，不包含 `dayN` 维度。
- **FR-015**：系统 MUST NOT 修改或删除旁路新 Agent 验证链路；非私域下该链路行为必须不回归。
- **FR-016**：单元测试 MUST 覆盖默认配置、Redis 保存、白名单命中、旧权限 false 仍走私域、非私域旧链路不变、`ai-reply` 私域无 `day/sku` 仍调用 Agent。
- **FR-017**：`select_user_info` 插件 MUST 识别 `private-domain:{agentId}:{externalUserId}:{userId}:{env}` 格式的私域 `external_key`。
- **FR-018**：私域 `select_user_info` MUST 按 `external_user_id` 查询 `drh_external_user_info` 和 `drh_ai_external_base_info`，其中 `drh_ai_external_base_info` 使用搜索并 `limit=1`。
- **FR-019**：私域 `select_user_info` MUST 返回 `name`、`age`、`gender`、`base` 等通用画像字段，并返回私域标记字段。
- **FR-020**：私域 `select_user_info` MUST NOT 返回或伪造 `day`、`camp_date_id`、`transfer_amount`、`class_info`、`song`、`week_num`、`task_class_session`。

## 成功标准

- **SC-001**：Redis 未配置时，白名单默认 `15311073569`，Agent ID 默认 `7644079727246065664`，且 Agent 默认命中会打印日志。
- **SC-002**：白名单命中的企微 `user_id` 在旧权限 false、`skuId` 为空、`day` 为空时仍能向 `ai-reply` 提交私域 Agent payload。
- **SC-003**：白名单未命中的声乐、钢琴、SOP/路由消息关键调用和 FC payload 与改造前保持一致。
- **SC-004**：私域路径不触发 SOP 作业点评，不读取 `dayN`，不构造依赖 `dayN` 的 conversation key。
- **SC-005**：目标测试通过，且测试中断言 Redis key、FC service/function、`agent_id`、私域标记、`external_user_id`、`user_id`、`messageId` 等关键下游参数。
- **SC-006**：私域 Agent 调用 `select_user_info` 时，示例 key 能返回 `drh_external_user_info.name` 和 `drh_ai_external_base_info` 中一条通用基础信息，且不依赖 `day/campDateId`。

## 假设

- “企业微信 id”指当前代码中的销售企微 `user_id`，即 `otsDto.getString("user_id")` / `messageDto.getBotWeixin()` 对应值。
- “以前 juzi-service 的配置页面”指 `src/main/resources/static/index.html` 所在配置中心，新增入口使用普通配置页面访问密码。
- 私域配置使用 `juzi-service` 现有 Redis 连接；实现前可根据已有配置页使用的 RedisTemplate 选择具体 Bean，但必须无 TTL。
- 私域 `ai-reply` payload 可以增加私域标记字段；若后续决定只复用旧字段，必须证明不会被旧 `skuId/day` 逻辑误判。
- `drh_ai_external_base_info` 存在可按 `external_user_id` 搜索的索引，默认名为 `drh_ai_external_base_info_index`。
- 私域 `select_user_info` 多条基础信息无需排序，任意取一条即可。
- 如以上假设被推翻，需要追加 Dxxx 纠正记录。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已只读检查 `juzi-service` 配置中心、`MessageServiceImpl`、`DelayMessageServiceImpl`、`RedisSafeUtil`、`RouteOrchestrator`、`fc/ai-reply AppTask` 和 `CozeUtil`。
- 已明确私域默认白名单、默认 Agent ID、Redis 永久缓存、配置页面、私域优先、非私域旧链路保持、无 `dayN`、无 SOP 作业点评和 `ai-reply` 合同适配要求。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：
- `juzi-service` 新增 `privatedomainai` 包，包含 Redis key/default 常量、配置 DTO、配置 service 和 `PrivateDomainAiConfigAdminController`。
- 新增配置接口 `GET /admin/private-domain-ai-config/page`、`GET /admin/private-domain-ai-config/config`、`POST /admin/private-domain-ai-config/config`，并新增 `/private-domain-ai-config.html` 页面及配置中心入口。
- `WebConfig` 已加入 `/admin/private-domain-ai-config/**` 与 `/private-domain-ai-config.html` 普通配置页鉴权。
- 私域白名单 Redis key 为 `ai:private-domain:config:white-list:v1`，Agent Redis key 为 `ai:private-domain:config:agent-id:v1`；保存使用永久缓存，不设置 TTL。
- Redis 白名单缺失或空白时默认 `15311073569`；Agent 缺失或空白时默认 `7644079727246065664`，并打印包含 key、默认值和 scene 的日志。
- `MessageServiceImpl#doSendMessage` 在 `external_user_id/user_id` 校验与自发消息基础清理后，旧 `selectUserPermission` 前进行私域白名单判定。
- 私域命中且销售自发消息时只执行旧 `removeCache` 清理并返回；私域命中且学员消息时调用 `DelayMessageService#sendPrivateDomainAiMessage(...)` 后返回。
- 非私域仍走原 `selectUserPermission`、旁路新 Agent 验证、声乐默认、钢琴/SOP/路由链路。
- `DelayMessageServiceImpl` 新增私域 FC payload，调用 `fc.common_service_name/common_function_name`，payload 包含 `private_ai=true`、`ai_scene=PRIVATE_DOMAIN`、`agent_id`、`external_user_id`、`user_id`、`user_bot_id`、`timestamp`、`redisKey`、`messageId`、`msgType`、`text` 等字段，不写入私域必需的 `day/sku_id`。
- `fc/ai-reply` 的 `EmpExternalDto` 新增 `private_ai`、`ai_scene` 字段。
- `AppTask` 新增私域前置分支，私域 payload 不因 `sku_id/day` 缺失跳过，并跳过旧 camp/sku 依赖判断。
- `CozeUtil` 新增私域 conversation key：`ai:private-domain:coze:conversation:key:v1:{agentId}:{externalUserId}:{userId}:{env}`，不包含 `dayN`，并使用 payload `agent_id` 作为 Coze botId。
- 私域回复继续复用现有 `sendJuzi`，保留文本、图片占位和视频号占位发送能力。
- 影响范围：
- `juzi-service`：配置页面、admin 接口、Redis 配置 service、消息入口私域优先分支、私域 FC payload。
- `fc/ai-reply`：入参 DTO、AppTask 私域分支、CozeUtil 私域会话 key 和发送入口。
- 未触碰 `033-new-agent-reply-record/create-new-agent-reply-record.sql` 既有未提交改动。
- 测试命令：
- `mvn -pl juzi-service -DskipTests=false "-Dtest=PrivateDomainAiConfigServiceTest,PrivateDomainAiConfigAdminControllerTest,DelayMessageServiceImplTest,MessageServiceImplManualReplySilenceTest" test`
- `mvn -pl ai-reply "-Dtest=PrivateDomainAppTaskTest,PrivateDomainCozeUtilTest" test`
- `mvn -pl juzi-service -DskipTests=false test`
- `mvn -pl ai-reply -am test`
- `git -C C:\workspace\ju-chat\data-RC\juzi-service diff --check`
- `git -C C:\workspace\ju-chat\fc diff --check -- ai-reply`
- `git -C C:\workspace\ju-chat\specs diff --check -- 034-private-domain-ai-agent`
- 测试结果：
- 目标 `juzi-service` 测试通过：21 tests, 0 failures, 0 errors。
- 目标 `ai-reply` 测试通过：6 tests, 0 failures, 0 errors。
- 完整 `juzi-service` 验证通过：82 tests, 0 failures, 0 errors, 1 skipped。
- 完整 `fc -pl ai-reply -am` 验证通过：reactor `fc/common/ai-reply` BUILD SUCCESS；common 22 tests 通过，ai-reply 14 tests 通过。
- `diff --check` 验证通过；仅输出 Windows 工作区 LF/CRLF 提示，无空白错误。
- 自检结论：
- 私域白名单命中优先级已前置到旧权限、`skuId/day`、旁路验证、SOP/路由之前。
- 非私域旧链路代码路径保持原有顺序，现有声乐、钢琴、SOP/路由和旁路验证测试继续通过。
- 私域 `ai-reply` 分支不依赖 `sku_id/day`，conversation key 不包含 `dayN`。
- Maven 输出仅包含既有 POM warning、Coze `LATEST` warning 和测试中预期异常日志，不影响验证结果。

### D003 - 纠正记录模板

- 触发原因：用户补充、测试失败、代码审查发现、参数遗漏或调用顺序问题。
- 修正内容：写清楚旧口径和新口径。
- 文档同步：说明 `spec.md`、`tasks.md`、`AGENTS.md`、checklist 是否已同步。
- 验证结果：记录测试或静态检查结果。

### D004 - select_user_info 私域兼容

- 实现内容：
- `coze_plugin/external-info-select AppTask` 已在旧 `external_key` 解析前识别 `private-domain:{agentId}:{externalUserId}:{userId}:{env}` 并前置返回私域画像。
- 私域路径按 `external_user_id` 查询 `drh_external_user_info`，并通过 `drh_ai_external_base_info_index` 搜索 `drh_ai_external_base_info`，`limit=1`，多条时使用第一条。
- 私域返回合并顺序为外部联系人表在前、基础信息表在后，基础信息表覆盖同名字段；返回 `private_domain`、`ai_scene=PRIVATE_DOMAIN`、`agent_id`、`external_user_id`、`user_id`、`env`、`current_time`、`today` 与通用画像字段。
- 私域路径保留设备品牌和敏感词补充，但不返回 `day`、`camp_date_id`、`campDateId`、`transfer_amount`、`class_info`、`song`、`week_num`、`task_class_session`。
- 影响范围：
- 仅修改 `coze_plugin/external-info-select` 的 `AppTask` 和新增 `AppTaskPrivateDomainTest`；不触碰 `external-info-save/dependency-reduced-pom.xml`、`voice-send/dependency-reduced-pom.xml` 等既有无关改动。
- 测试命令：
- `mvn -pl external-info-select -am "-Dmaven.test.skip=false" "-DskipTests=false" test`
- `git -C C:\workspace\ju-chat\coze_plugin diff --check -- external-info-select`
- `git -C C:\workspace\ju-chat\specs diff --check -- 034-private-domain-ai-agent`
- 测试结果：
- `external-info-select` 目标验证 BUILD SUCCESS；`AppTaskPrivateDomainTest` 7 tests 通过；`common` 现有 `OtsUtilIntegrationTest` 2 tests 运行，1 skipped，0 failures，0 errors。
- `coze_plugin` 与 `specs` 目标 `diff --check` 均通过；仅有 Windows 工作区 LF/CRLF 提示，无空白错误。
- 自检结论：
- 私域 `select_user_info` 不再进入旧营期权限、DayEnum、图书物流、转账金额逻辑；非私域 key 保持旧链路入口；私域返回只包含通用画像和私域上下文字段。
