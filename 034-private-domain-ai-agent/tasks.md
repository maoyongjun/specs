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

## Phase 5：select_user_info 插件私域兼容

- [x] T042 在 `spec.md` 和 `tasks.md` 记录 `select_user_info` 私域 key、双表查询、字段返回和测试计划。
- [x] T043 在 `external-info-select AppTask` 中识别 `private-domain:{agentId}:{externalUserId}:{userId}:{env}`，并在旧 key 解析前分流。
- [x] T044 新增私域 key 解析 helper，严格校验 5 段参数，缺少关键字段时返回空 JSON 并记录日志。
- [x] T045 私域分支按 `external_user_id` 单行查询 `drh_external_user_info`。
- [x] T046 私域分支按 `external_user_id` 搜索 `drh_ai_external_base_info`，使用 `drh_ai_external_base_info_index`，`limit=1`，多条取第一条。
- [x] T047 私域返回体合并外部联系人表和基础信息表，基础信息表覆盖同名字段，并过滤为通用画像字段。
- [x] T048 私域返回体固定包含 `private_domain`、`ai_scene`、`agent_id`、`external_user_id`、`user_id`、`env`、`current_time`、`today`。
- [x] T049 私域返回体不返回 `day`、`camp_date_id`、`transfer_amount`、`class_info`、`song`、`week_num`、`task_class_session`。
- [x] T050 新增 `AppTaskPrivateDomainTest` 覆盖私域解析、双表合并、多条基础信息取第一条、字段过滤和非私域不接管。
- [x] T051 运行 `mvn -pl external-info-select -am -Dmaven.test.skip=false -DskipTests=false test` 与目标 `diff --check`，并回填 D004。

## Phase 6：私域回复时间窗口配置

- [x] T052 在 `spec.md` 和 `tasks.md` 记录私域回复时间 Redis key、默认值、边界规则、测试计划和 D005。
- [x] T053 在 `PrivateDomainAiConstants` 增加回复时间 Redis key 和默认 `05:00-00:00`。
- [x] T054 在 `PrivateDomainAiConfigDto` 增加 `replyTimeRange` 和 `replyTimeRangeDefaulted` 字段。
- [x] T055 在 `PrivateDomainAiConfigService` 增加时间配置读取、保存、格式校验、默认回退和永久写入。
- [x] T056 在 `PrivateDomainAiConfigService` 增加可测试的允许回复时间判断，支持含起不含止和跨午夜窗口。
- [x] T057 在 `private-domain-ai-config.html` 增加私域回复时间输入、默认标记、加载和保存字段。
- [x] T058 在 `MessageServiceImpl#handlePrivateDomainAiIfMatched` 中，私域白名单命中且非自发消息时先判断时间窗口。
- [x] T059 不在允许回复窗口内时打印 `private_domain_ai_reply_time_blocked` 日志，不调用私域 AI，并消费消息不回落旧链路。
- [x] T060 补充配置 service/controller 测试，覆盖默认值、保存、非法格式、空白默认和边界时间。
- [x] T061 补充消息入口测试，覆盖窗口内调用私域 AI、窗口外阻断且不触发旁路验证、私域自发消息保持不触发 AI。
- [x] T062 运行目标 Maven 测试、完整 `juzi-service` 测试和目标 `diff --check`，并回填 D005。

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

### D004 - select_user_info 私域兼容

- 实现内容：已在 `coze_plugin/external-info-select` 的 `AppTask` 中新增私域 `external_key` 前置分流，支持 `private-domain:{agentId}:{externalUserId}:{userId}:{env}`；私域路径按 `external_user_id` 读取 `drh_external_user_info`，并通过 `drh_ai_external_base_info_index` 搜索 `drh_ai_external_base_info`，`limit=1`，返回首条基础信息。
- 实现内容：私域返回体先合并外部联系人信息，再合并基础信息，基础信息覆盖同名字段；固定返回 `private_domain`、`ai_scene`、`agent_id`、`external_user_id`、`user_id`、`env`、`current_time`、`today`，并仅输出通用画像字段与必要补充字段。
- 实现内容：私域路径不调用旧 `CenterUtil.selectUserJson`、`CropService#getCropIdByEmpIdFromCache`、`DayEnum.createCozeJson`、`setTushu`、`setChatMoney`，不返回 `day/camp_date_id/transfer_amount/class_info/song/week_num/task_class_session`。
- 测试命令：`mvn -pl external-info-select -am "-Dmaven.test.skip=false" "-DskipTests=false" test`
- 测试命令：`git -C C:\workspace\ju-chat\coze_plugin diff --check -- external-info-select`
- 测试命令：`git -C C:\workspace\ju-chat\specs diff --check -- 034-private-domain-ai-agent`
- 测试结果：`external-info-select` 目标验证 BUILD SUCCESS；`AppTaskPrivateDomainTest` 7 tests 通过；`common` 现有 `OtsUtilIntegrationTest` 2 tests 运行，1 skipped，0 failures，0 errors。
- 测试结果：`coze_plugin` 与 `specs` 目标 `diff --check` 均通过；仅有 Windows 工作区 LF/CRLF 提示，无空白错误。
- 自检结论：私域 `select_user_info` 已绕开旧营期 key、`day`、营期和转账依赖；非 `private-domain` key 不被私域分支接管；当前未触碰 `external-info-save/dependency-reduced-pom.xml`、`voice-send/dependency-reduced-pom.xml` 等无关改动。

### D005 - 私域回复时间窗口配置

- 实现内容：已在 `juzi-service` 私域配置中新增 Redis key `ai:private-domain:config:reply-time-range:v1` 和默认允许回复时间 `05:00-00:00`；`PrivateDomainAiConfigDto` 新增 `replyTimeRange`、`replyTimeRangeDefaulted`。
- 实现内容：`PrivateDomainAiConfigService` 已支持时间配置读取、永久保存、空白保存默认、非法格式保存失败、Redis 空/非法回退默认并打印日志；时间窗口按 `HH:mm-HH:mm`、含起不含止、支持跨午夜判定。
- 实现内容：`private-domain-ai-config.html` 已新增“私域回复时间”输入；`MessageServiceImpl#handlePrivateDomainAiIfMatched` 在私域白名单命中且非自发消息时，先判断允许回复时间，不在窗口内打印 `private_domain_ai_reply_time_blocked` 并消费消息，不回落旧链路。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=PrivateDomainAiConfigServiceTest,PrivateDomainAiConfigAdminControllerTest,MessageServiceImplManualReplySilenceTest" test`
- 测试命令：`mvn -pl juzi-service -DskipTests=false test`
- 测试命令：`git -C C:\workspace\ju-chat\data-RC\juzi-service diff --check`
- 测试命令：`git -C C:\workspace\ju-chat\specs diff --check -- 034-private-domain-ai-agent`
- 测试结果：目标测试通过，23 tests，0 failures，0 errors，0 skipped。
- 测试结果：完整 `juzi-service` 测试通过，87 tests，0 failures，0 errors，1 skipped。
- 测试结果：`juzi-service` 与 `specs` 目标 `diff --check` 均通过；仅有 Windows 工作区 LF/CRLF 提示，无空白错误。
- 自检结论：私域时间窗口只影响白名单命中的学员消息；自发消息仍清理缓存且不触发 AI；窗口外私域消息不会调用 `ai-reply`，也不会触发旧权限、旁路验证、SOP 或路由。
