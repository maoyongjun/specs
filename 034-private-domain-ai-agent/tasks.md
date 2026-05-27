# 任务清单：私域 AI Agent 接入配置

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前主要目标为 `C:\workspace\ju-chat\data-RC\juzi-service`，合同相关模块为 `C:\workspace\ju-chat\fc\ai-reply`。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和测试落点。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
- [x] T004 确认配置来源、Redis key、FC 调用、配置页面、MQ/数据库影响范围。
- [x] T005 确认已有旧逻辑中必须保持不变的过滤、幂等、异常处理、日志、延迟、fallback 和旁路验证。

**检查点**：已完成只读事实确认，当前未进入实现。

### Phase 1 事实记录

- 主入口为 `MessageServiceImpl#doSendMessage`，企微 `user_id` 当前来自 `otsDto.getString("user_id")`。
- 旧权限入口为 `userCheckService.selectUserPermission(messageDto, external_user_id, user_id)`。
- 旁路新 Agent 验证当前由 `triggerNewAgentVerifyAndShouldSkipForNoAiPermission` 触发，并和旧无权限早退耦合。
- 旧声乐分支位于 `skuId == null || skuId == 5`，旧钢琴/其他分支继续走 SOP/路由。
- 路由计划由 `RouteOrchestratorImpl` 按 `skuId`、`day`、消息类型和 route config 生成。
- 旧 FC payload 由 `DelayMessageServiceImpl#createJSONObject` 构造，包含 `day=dayN`、`sku_id`、`agent_id`。
- `fc/ai-reply AppTask` 当前会在 `agent_id` 或 `sku_id` 为空时跳过；旧 conversation key 绑定 `empExternalDto.getDay()`。
- `fc/ai-reply CozeUtil` 当前使用 `empExternalDto.getAgent_id()` 作为 Coze `botID`，但方法签名仍要求 `DayEnum dayEnum`。
- 配置中心首页为 `static/index.html`，受保护路径由 `WebConfig` 维护。
- Redis 安全读写工具 `RedisSafeUtil` 已支持无 TTL `set(redisTemplate, key, value, scene)`。

## Phase 2：风险门禁

- [x] T006 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为。
- [x] T010 对需要用户确认的业务语义变化做记录；当前无待确认项。
- [x] T011 为每个关键行为建立测试映射，至少覆盖正常路径、边界路径和不回归路径。

**检查点**：私域实现会改变 FC payload 合同和 `ai-reply` 入参处理，必须在实现阶段同步测试；不会新增数据库表。

### Phase 2 风险记录

- 当前旧 payload 会写 `sku_id=null`、`agent_id=null`，但 `ai-reply` 会在空值时跳过；私域必须显式传 `agent_id`，并增加私域标记绕开旧 `sku_id/day` 强依赖。
- 当前旧无权限早退和旁路验证在同一个 helper 中；私域命中不能被旧 `permission=false` 阻断，同时非私域旁路验证行为不得改变。
- 当前销售自发消息清理逻辑晚于旧权限判断；私域实现要保证自发消息不触发 AI。
- 私域 Redis 配置要求永久缓存，不得误用已有带 TTL 的缓存 helper。
- 私域无 `dayN`，不得把 `day0` 或 `*` 作为业务假值写入 Agent conversation 维度。

## Phase 3：实现

- [x] T012 在 `juzi-service` 新增私域配置常量，包含白名单 key、Agent ID key、默认白名单和默认 Agent ID。
- [x] T013 新增私域配置 DTO 和 service，支持读取默认值、解析逗号白名单、保存 Redis 永久缓存、Redis 异常处理和默认 Agent 日志。
- [x] T014 新增 `PrivateDomainAiConfigAdminController`，提供页面跳转、当前配置读取和保存接口。
- [x] T015 在 `WebConfig` 增加 `/admin/private-domain-ai-config/**` 和 `/private-domain-ai-config.html` 鉴权路径。
- [x] T016 在 `static/index.html` 增加“私域AI配置”入口，保持配置中心现有视觉和访问密钥机制。
- [x] T017 新增 `static/private-domain-ai-config.html`，支持白名单 textarea、Agent ID 输入、加载、保存和错误提示。
- [x] T018 在 `MessageServiceImpl#doSendMessage` 引入私域判定，使用企微 `user_id` 命中白名单作为唯一私域 AI 权限来源。
- [x] T019 调整私域命中后的流程，确保不被旧 `selectUserPermission.permission=false`、`skuId`、`day` 阻断。
- [x] T020 保留销售自发消息清理和静默逻辑，确保自发消息不触发私域 AI。
- [x] T021 保留非私域旧链路，非私域继续执行声乐默认分支、钢琴 SOP/路由分支和旁路验证链路。
- [x] T022 新增私域 AI FC payload 构造，调用 `ai-reply` 函数计算，payload 包含私域标记、`agent_id`、`external_user_id`、`user_id`、`user_bot_id`、`messageId`、`msgType`、`text`、`timestamp`、`redisKey` 等关键字段。
- [x] T023 在 `fc/ai-reply` 入参 DTO 增加私域标记字段，或用等价方式识别私域 payload。
- [x] T024 在 `fc/ai-reply AppTask` 增加私域分支，命中私域时不要求 `sku_id` 和 `DayEnum day`。
- [x] T025 在 `fc/ai-reply` 私域分支使用独立 conversation key，维度包含 `agent_id`、`external_user_id`、`user_id` 和环境，不包含 `dayN`。
- [x] T026 在 `fc/ai-reply CozeUtil` 或新增 helper 中支持私域 Agent 调用，使用 payload `agent_id` 作为 Coze `botID`，微信回复仍复用既有 `sendJuzi`。
- [x] T027 确认私域路径不调用 `sop-reply`，不构造 SOP 作业点评 payload，不读取 `dayN` 作为私域必要参数。
- [x] T028 同步更新本目录文档中因实现发现而变化的 key、字段名、接口路径或测试命令。

## Phase 4：测试与验证

- [x] T029 新增 `juzi-service` 私域配置 service 测试：Redis 缺失时默认白名单、默认 Agent、Agent 默认日志、逗号解析、永久写入。
- [x] T030 新增 `juzi-service` 配置 controller 测试：当前配置读取、保存成功、保存失败、空白配置校验。
- [x] T031 新增 `MessageServiceImpl` 私域命中测试：旧权限 false、`skuId/day` 为空仍调用 `ai-reply` FC。
- [x] T032 新增 `MessageServiceImpl` 非私域不回归测试：声乐继续旧默认分支，钢琴继续 SOP/路由分支，不调用私域 FC。
- [x] T033 新增旁路验证不回归测试：非私域下 `NewAgentVerifyService` 触发/跳过行为和当前逻辑一致。
- [x] T034 新增自发消息测试：销售手动发送时不触发私域 AI，仍执行旧缓存清理。
- [x] T035 新增 FC payload 参数断言：`serviceName`、`functionName`、私域标记、`agent_id`、`external_user_id`、`user_id`、`messageId`、`text` 正确。
- [x] T036 新增 `fc/ai-reply` 私域入参测试：无 `sku_id`、无 `day` 时不跳过，并使用私域 `agent_id`。
- [x] T037 新增 `fc/ai-reply` 私域 conversation key 测试：key 不包含 `dayN`，不同 `agent_id/user_id/external_user_id/env` 隔离。
- [x] T038 新增 `fc/ai-reply` 私域微信回复测试：Agent 输出仍进入既有 `sendJuzi` 拆分和发送逻辑。
- [x] T039 运行 `mvn -pl juzi-service -DskipTests=false test` 或目标测试类，并记录结果。
- [x] T040 运行 `mvn -pl ai-reply -am test` 或目标测试类，并记录结果。
- [x] T041 执行 `git diff --check`，确认没有空白和格式问题。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `034-private-domain-ai-agent` Spec Kit 文档，包含 `AGENTS.md`、`spec.md`、`tasks.md` 和 `checklists/requirements.md`。
- 验证方式：只读搜索并检查 `juzi-service` 配置中心、消息入口、Redis 工具、路由、延迟 FC payload、`fc/ai-reply` 入口和 Coze 调用代码。
- 自检结论：已记录关键参数来源、调用顺序风险、旧逻辑保持要求、Redis/FC 合同变更和测试映射；本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：已完成 `juzi-service` 私域配置、配置页、Redis 永久缓存、消息入口私域优先分支、私域 FC payload；已完成 `fc/ai-reply` 私域入参字段、AppTask 私域分支、Coze 私域 conversation key 和私域发送入口。
- 测试命令：
- `mvn -pl juzi-service -DskipTests=false "-Dtest=PrivateDomainAiConfigServiceTest,PrivateDomainAiConfigAdminControllerTest,DelayMessageServiceImplTest,MessageServiceImplManualReplySilenceTest" test`
- `mvn -pl ai-reply "-Dtest=PrivateDomainAppTaskTest,PrivateDomainCozeUtilTest" test`
- `mvn -pl juzi-service -DskipTests=false test`
- `mvn -pl ai-reply -am test`
- `git -C C:\workspace\ju-chat\data-RC\juzi-service diff --check`
- `git -C C:\workspace\ju-chat\fc diff --check -- ai-reply`
- `git -C C:\workspace\ju-chat\specs diff --check -- 034-private-domain-ai-agent`
- 测试结果：目标测试和完整验证均通过；`juzi-service` 完整验证 82 tests 通过、1 skipped；`fc -pl ai-reply -am` reactor BUILD SUCCESS，common 22 tests、ai-reply 14 tests 通过；`diff --check` 通过，仅有 LF/CRLF 提示。
- 自检结论：私域命中不触发旧权限、旁路验证、SOP 或路由；非私域旧链路保持；私域 `ai-reply` 无 `sku_id/day` 不跳过，conversation key 不含 `dayN`。

### D003 - 纠正记录模板

- 触发原因：说明为什么需要纠正。
- 修正内容：说明具体修正。
- 文档同步：说明同步了哪些文件。
- 验证结果：说明测试或静态验证。
