# 功能规格：私聊视频上传标记缓存联动

**功能目录**：`111-private-video-uploaded-cache`  
**创建日期**：`2026-06-25`  
**状态**：Draft  
**输入**：修改 `data-RC/juzi-service`：当用户私聊发送一个视频时，通过 Redis 缓存标记 `externalUserId` 是「发送视频的」，缓存 5 分钟。同时修改 `coze_plugin/external-info-select`：返回时如果该 `externalUserId` 的 Redis key 能查到数据，返回增加属性 `video_uploaded` 为「是」，其他情况为「否」。

## 背景

- 当前问题：Coze 智能体在回复用户时，无法感知「用户刚刚是否发过视频」，需要一个短时效的信号供话术判断。
- 当前行为：
  - `juzi-service` 的 `MessageServiceImpl.doSendMessage` 会消费所有句子私聊/群聊消息，对视频类型（`MessageType.VIDEO`，code=13）只在群聊分支打印日志，私聊视频无任何缓存标记。
  - `external-info-select` 的 `AppTask.handleRequest` 标准营期主路径返回 JSON 时，无 `video_uploaded` 字段。已有完全同构的 `if_register` 缓存联动作为先例。
- 目标行为：
  - 用户在私聊中主动发送视频时，`juzi-service` 写入 `ai:reply:video-uploaded:{externalUserId}` = `是`，TTL 5 分钟。
  - `external-info-select` 标准营期主路径返回前查该 key：命中返回 `video_uploaded="是"`，未命中/异常/空返回 `video_uploaded="否"`。
- 非目标：
  - 不处理群聊视频、销售/AI/系统自身发送的视频。
  - 不在私域 `private_domain` 返回路径增加该字段。
  - 不做视频计数、不做视频内容识别、不改动现有视频去重逻辑。
  - 不触碰 `ProfileTask/ProfileTaskV2`。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 用户私聊发视频后被标记（优先级：P1）

作为运营，希望当学员在私聊里发了一个视频，系统能在 5 分钟内记住「该学员刚发过视频」，以便 AI 话术据此应答。

**独立测试**：构造一条「私聊 + 视频 + 用户发送」的句子消息，调用写入端标记方法，断言向 `stringRedisTemplate` 写入了 `ai:reply:video-uploaded:{externalUserId}`、value=`是`、TTL=300 秒。

**验收场景**：

1. **Given** 一条 `type=13`、`isSelf=false`、无 `roomTopic/roomWecomChatId`、`externalUserId` 非空的消息，**When** 进入 `doSendMessage` 标记环节，**Then** 写入 key=`ai:reply:video-uploaded:{externalUserId}`、value=`是`、TTL=300 秒。
2. **Given** 同样的视频消息但带 `roomTopic` 或 `roomWecomChatId`（群聊），**When** 进入标记环节，**Then** 不写入缓存。
3. **Given** `type=13` 但 `isSelf=true`（销售/托管账号自己发），**When** 进入标记环节，**Then** 不写入缓存。
4. **Given** `isSelf=false` 但 `type=7`（文字）等非视频类型，**When** 进入标记环节，**Then** 不写入缓存。
5. **Given** `externalUserId` 为空的视频消息，**When** 进入标记环节，**Then** 不写入缓存。

### 用户故事 2 - 返回体携带 video_uploaded（优先级：P1）

作为 Coze 智能体，希望从 `external-info-select` 返回里直接读到 `video_uploaded`，无需自行查缓存。

**独立测试**：对纯逻辑方法 `applyVideoUploadedValue(jsonObject, cacheValue)`，断言命中（非空）→`是`、未命中（null/空串）→`否`。

**验收场景**：

1. **Given** 标准营期主路径返回，缓存命中（`getStringValue` 返回非空），**When** 构建返回 JSON，**Then** `video_uploaded="是"`。
2. **Given** 标准营期主路径返回，缓存未命中（返回 null/空串）或 Redis 异常，**When** 构建返回 JSON，**Then** `video_uploaded="否"`。
3. **Given** 私域 `private_domain` 返回路径，**When** 构建返回 JSON，**Then** 不包含 `video_uploaded` 字段（保持现状）。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - 写入端 `externalUserId`：来源 `MessageServiceImpl.doSendMessage` 中的局部变量 `external_user_id`（先取 `otsDto.getString("external_user_id")`，再经 imContactId 反查补偿）；赋值时机为标记调用前已补偿；使用前判空。
  - 写入端 `isSelf`：来源 `messageDto.getIsSelf()`，由 `createOtsDto()` 在标记前已计算；用户发送为 `false`。
  - 写入端 `type`：来源 `messageDto.getType()`，`createOtsDto()` 已兼容企业级 `messageType`；视频为 13（`MessageType.VIDEO.getCode()`）。
  - 写入端「是否群聊」：复用现有私有方法 `isGroupMessage(messageDto)`（依据 `roomWecomChatId` 或 `roomTopic`）。
  - 读取端 `externalUserId`：来源 `external_key.split(":")[0]`，主路径恒非空。
- 下游读取字段清单：
  - 写入端：`RedisSafeUtil.set` 读取 key、value、timeout、unit；底层 `stringRedisTemplate.opsForValue().set(...)`。
  - 读取端：`appendVideoUploaded` 读取缓存字符串；返回 JSON 新增 `video_uploaded`，由 Coze 智能体下游读取。
- 空对象 / 占位对象风险：
  - 否。写入端不构造任何新 DTO；读取端沿用现有 `RedisClient`，不传空对象。
- 调用顺序风险：
  - 否。写入端标记在 `external_user_id` 补偿赋值之后调用，不依赖后续步骤补齐；不改变既有 return 顺序。读取端在 `chat_name` 构建及 `compensateIfRegisterByAiRegisterMailCache` 之后、return 之前调用。
- 旧逻辑保持：
  - 消息去重（`AI_MESSAGE_KEY`）、撤回标记、招呼语过滤、群聊各分支日志、延迟下发、敏感词 `setSensitiveWord`、转账 `setChatMoney`、`if_register` 补偿、私域路径、`requestId` MDC、return 时机全部不变。
- 需要用户确认的设计选择：
  - 返回路径范围：已确认「只加标准营期主路径，不加私域路径」。
  - 触发条件范围：已确认「仅用户主动私聊发视频（`isSelf=false`）」。
  - Redis 实例/库一致性：见「假设」，需部署侧核对。

## 边界情况

- `externalUserId` 为空：写入端跳过不标记；读取端按未命中返回 `video_uploaded="否"`。
- 群聊视频：写入端跳过（`isGroupMessage` 为真）。
- 销售/AI/系统发送视频（`isSelf=true`）：写入端跳过。
- 非视频消息：写入端跳过。
- Redis 写失败：`RedisSafeUtil.set` 返回 false 并记录日志，不抛异常、不影响消息主流程。
- Redis 读失败/连接异常：读取端 catch 后按未命中返回 `video_uploaded="否"`，不阻断返回。
- 重复发视频：每次发都重置 key 的 5 分钟 TTL，符合「最近发过视频」语义。

## 需求 *(必填)*

### 功能需求

- **FR-001**：`juzi-service` MUST 在「私聊 + 视频（type=13）+ 用户发送（isSelf=false）+ externalUserId 非空」时，使用 `stringRedisTemplate` 写入 key `ai:reply:video-uploaded:{externalUserId}`、value `是`、TTL 300 秒。
- **FR-002**：`juzi-service` MUST NOT 在群聊、`isSelf=true`、非视频类型或 `externalUserId` 为空时写入该缓存。
- **FR-003**：`external-info-select` 标准营期主路径 MUST 在返回 JSON 中加入 `video_uploaded`：命中缓存为 `是`，未命中/异常/空为 `否`。
- **FR-004**：`external-info-select` MUST NOT 在私域 `private_domain` 返回路径加入 `video_uploaded` 字段，且不得改动其他既有字段与逻辑。
- **FR-005**：两端 Redis key 字符串 MUST 完全一致（`ai:reply:video-uploaded:` + externalUserId）；写入端 MUST 使用纯字符串序列化模板（`stringRedisTemplate`）。
- **FR-006**：单元测试 MUST 断言写入端的 key/value/TTL/单位及各跳过分支，并断言读取端命中/未命中映射。

## 成功标准 *(必填)*

- **SC-001**：用户私聊发一个视频后 5 分钟内，`external-info-select` 主路径返回 `video_uploaded="是"`；超过 5 分钟或未发视频返回 `否`。
- **SC-002**：群聊视频、销售自发视频、非视频消息不产生该缓存，主路径相应返回 `否`。
- **SC-003**：原有去重、延迟、路由、敏感词、转账、`if_register`、私域返回等行为无回归；新增逻辑异常不阻断主流程。

## 假设

- `juzi-service` 的 `spring.redis`（host/database/password）与 `external-info-select` FC 的环境变量 `redis_host`/`db`/`redis_password` 指向**同一 Redis 实例、同一 DB**。依据：本工作区已有 `fc/*` 写、`coze` 读的跨项目缓存联动（如 `if_register`、敏感词、转账）在生产成立。若该假设被推翻，需追加 Dxxx 并由部署侧统一 host/db。
- `stringRedisTemplate`（Spring Boot 默认 bean，key/value 均 `StringRedisSerializer`）写入的纯字符串可被 coze 端 Jedis `get` 正确读取。
- value 具体取值不影响读取端判断（读取端只判「非空即命中」），统一写 `是` 以便排查。
- 如假设被推翻，需要追加 Dxxx 纠正记录。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成历史问题防漏分析和强制门禁检查（Phase 1 代码事实确认完成）。
- 已与用户确认两项关键口径：只加标准营期主路径、仅用户主动私聊发视频。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：
  - juzi-service：`RedisConstants` 新增 `VIDEO_UPLOADED_TTL_SECONDS=300`、`VIDEO_UPLOADED_CACHE_VALUE="是"`、`getVideoUploadedKey()`；`MessageServiceImpl` 新增 `markExternalUserVideoUploadedIfPrivateVideo(messageDto, externalUserId)`，在 `markExternalUserOfflineIfCustomerServiceMessage` 之后旁路调用，复用 `isGroupMessage`，用 `stringRedisTemplate` 写入。
  - external-info-select：`RedisContants` 新增 `VIDEO_UPLOADED_VALUE`/`VIDEO_NOT_UPLOADED_VALUE`/`getVideoUploadedCacheKey()`；`AppTask` 新增 static `applyVideoUploadedValue` 与 private `appendVideoUploaded`，仅在标准营期主路径 `compensateIfRegisterByAiRegisterMailCache` 之后调用。
- 影响范围：新增一个 Redis key（写）+ 一个返回字段（读）；未改动 MQ/OTS/HTTP/私域路径/原有 return 顺序。
- 测试命令：
  - `mvn -pl external-info-select -am clean test -Dmaven.test.skip=false -Dtest=RedisContantsTest,AppTaskVideoUploadedTest -Dsurefire.failIfNoSpecifiedTests=false`
  - `mvn -f data-RC/pom.xml -pl juzi-service -am test -DskipTests=false -Dtest='MessageServiceImpl*' -Dsurefire.failIfNoSpecifiedTests=false`
- 测试结果：
  - coze：RedisContantsTest 5 + AppTaskVideoUploadedTest 6 = 11 通过，BUILD SUCCESS。
  - juzi-service：MessageServiceImplVideoUploadedTest 6 通过；全部 MessageServiceImpl* 共 33 通过无回归，BUILD SUCCESS。
- 自检结论：参数来源完整（externalUserId/isSelf/type/群聊判断均在调用前确定）；调用顺序未变；旧逻辑保持；新增逻辑异常不阻断主流程。剩余风险：juzi-service 与 external-info-select 的 Redis 须同实例同库（部署侧假设，待上线前核对）。

### D003 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
