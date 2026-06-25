# 任务清单：私聊视频上传标记缓存联动

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认涉及两个项目：`data-RC/juzi-service`（写）与 `coze_plugin/external-info-select`（读）。
- [x] T002 确认入口与调用链：写入端 `MessageListenerServiceImpl.consume` → `MessageServiceImpl.doSendMessage`；读取端 `AppTask.handleRequest` 标准营期主路径（279 行）与私域路径（166 行）。
- [x] T003 确认关键参数：`external_user_id`（otsDto/imContactId 反查补偿）、`isSelf`（createOtsDto 计算）、`type`（13=视频）、群聊判断 `isGroupMessage`。
- [x] T004 确认配置/契约：写入端用 `stringRedisTemplate`（Spring Boot 默认，纯字符串序列化）；读取端用 Jedis（env `redis_host`/`db`/`redis_password`）；新增 key `ai:reply:video-uploaded:{externalUserId}`、TTL 300s；不涉及 MQ/OTS/HTTP 变更。
- [x] T005 确认必须保持不变的旧逻辑：去重、撤回、招呼语过滤、群聊分支、延迟下发、敏感词、转账、`if_register`、私域返回、return 时机。

**检查点**：T001-T005 已完成，可进入实现（待用户确认方案）。

## Phase 2：风险门禁

- [x] T006 占位对象检查：无 `new XxxDto()`/空 JSON/空 Map 占位；写入端仅写 key/value。结论：无风险。
- [x] T007 调用后赋值检查：标记在 `external_user_id` 补偿赋值之后调用，不依赖后续补齐。结论：无风险。
- [x] T008 下游字段来源检查：key 由 `externalUserId` 现算；value 为常量；读取端字段 `video_uploaded` 当前层现算。结论：来源完整。
- [x] T009 影响范围检查：仅新增一个 Redis key/TTL（写）与一个返回字段（读），不改调用顺序、接口契约、MQ body、OTS、HTTP。结论：影响最小且可控。
- [x] T010 业务语义确认：返回路径范围（仅主路径）、触发条件（仅 isSelf=false）已与用户确认；Redis 实例/库一致性列为假设并要求部署侧核对。
- [x] T011 测试映射：写入端 key/value/TTL + 4 类跳过分支；读取端命中/未命中纯逻辑 + 常量 key 测试。

**检查点**：T006-T011 均有明确结论，无未决高风险。

## Phase 3：实现

- [x] T012 `juzi-service` `RedisConstants` 新增 `VIDEO_UPLOADED_TTL_SECONDS=300`、`VIDEO_UPLOADED_CACHE_VALUE="是"`、`getVideoUploadedKey(externalUserId)`。
- [x] T013 `juzi-service` `MessageServiceImpl` 新增 `markExternalUserVideoUploadedIfPrivateVideo(messageDto, externalUserId)`，并在 `markExternalUserOfflineIfCustomerServiceMessage` 之后调用；保持其余流程不变。
- [x] T014 `external-info-select` `RedisContants` 新增 `VIDEO_UPLOADED_VALUE="是"`、`VIDEO_NOT_UPLOADED_VALUE="否"`、`getVideoUploadedCacheKey(externalUserId)`（key 与写入端逐字符一致）。
- [x] T015 `external-info-select` `AppTask` 新增 static `applyVideoUploadedValue` 与 private `appendVideoUploaded`，仅在标准营期主路径 `compensateIfRegisterByAiRegisterMailCache` 之后调用。

## Phase 4：测试与验证

- [x] T016 `juzi-service` 新增 `MessageServiceImplVideoUploadedTest`：私聊视频用户发送 → 写入；群聊（roomWecomChatId/roomTopic）/isSelf/非视频/空 externalUserId → 不写。
- [x] T017 断言写入端下游参数：`valueOperations.set(eq(key), eq("是"), eq(300L), eq(SECONDS))`。
- [x] T018 `external-info-select` 新增 `AppTaskVideoUploadedTest` 覆盖命中/未命中/空串/null；`RedisContantsTest` 增加 key 与常量断言。
- [x] T019 运行两端目标测试：coze 11 通过、juzi-service MessageServiceImpl* 33 通过，均 BUILD SUCCESS。
- [x] T020 搜索确认两端 key 字符串一致（`ai:reply:video-uploaded:`+externalUserId），无残留旧字段/旧调用。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 111 号规格文档（spec/tasks/AGENTS/checklist），完成 Phase 1/2 门禁。
- 验证方式：阅读 `MessageServiceImpl`、`RedisAutoConfiguration`、`AppTask`、`RedisContants`、既有测试与 110 号同构需求。
- 自检结论：满足强制门禁；仅余 Redis 实例/库一致性这一部署侧假设待核对。

### D002 - 实现记录

- 实现内容：两端各改 1 个常量类 + 1 个核心类，新增 2 个测试类并扩充 1 个常量测试。详见 `spec.md` D002。
- 测试命令：见 `spec.md` D002（coze 与 juzi-service 各一条 mvn 命令）。
- 测试结果：coze 11 通过；juzi-service MessageServiceImpl* 33 通过（含新增 6）；均 BUILD SUCCESS。
- 自检结论：参数来源完整、调用顺序未变、旧逻辑保持、异常不阻断；剩余风险为 Redis 同实例同库的部署侧假设。

### D003 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
