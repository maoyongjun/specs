# 任务清单：用户等级 MQ userIdConfig 放开与触发间隔调整

**输入**：来自 `specs/025-juzi-user-level-piano-mq-useridconfig/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：实现阶段必须补充 `juzi-service` 与 `rocket-mq-consumer` 单元测试，覆盖钢琴不限白名单、非钢琴仍受控、30 分钟去重、MQ `sku_id` 字段和消费端取消 `userIdConfig` 拦截。

## Phase 1：规格与范围

- [x] T001 创建 `specs/025-juzi-user-level-piano-mq-useridconfig` 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确发送端目标模块为 `data-RC/juzi-service`
- [x] T003 明确消费端目标模块为 `fc/rocket-mq-consumer`
- [x] T004 明确 `skuId=4` 钢琴用户等级生成发送 MQ 不限制 `userIdConfig`
- [x] T005 明确非 `skuId=4` 普通用户等级生成仍保持发送端白名单控制
- [x] T006 明确消费端 `UserLevelUpdateTask` 全量取消 `userIdConfig` 限制
- [x] T007 明确 30 分钟间隔指发送端 Redis 去重 TTL，不调整 MQ 延迟投递时间
- [x] T008 明确后续实现必须增加单元测试

## Phase 2：发送端实现

- [x] T009 在 `UserInsightUpdateServiceImpl#userLevelGenerate` 中识别 `UserInfoDto.skuId == 4`
- [x] T010 调整发送端白名单判断：`skuId=4` 跳过 `needUpdate(userId)`；非 `skuId=4` 且非 `signUpTushu=true` 保持现有 `needUpdate(userId)`
- [x] T011 用户等级 MQ body 增加 `sku_id` 字段，保留现有字段不变
- [x] T012 将用户等级去重 key 的写入 TTL 从 10 分钟改为 30 分钟
- [x] T013 将命中去重 key 的日志文案从“10分钟更新一次”改为“30分钟更新一次”
- [x] T014 保持 MQ `startDeliverTime` 延迟投递逻辑不变
- [x] T015 保持 `signUpTushu=true` 现有不限白名单和快速触发行为

## Phase 3：消费端实现

- [x] T016 在 `UserLevelUpdateInput` 增加可选 `sku_id` 字段
- [x] T017 从 `UserLevelUpdateTask` 删除或停用 `needUpdate(userId)` 消费端拦截逻辑
- [x] T018 删除第一次 `userIdConfig` 不命中导致的提前 `return`
- [x] T019 删除同步标签后第二次 `userIdConfig` 不命中导致的提前 `return`
- [x] T020 保持 `external_user_id` 为空、`day` 为空、`day<4`、`day>15` 等既有拦截逻辑
- [x] T021 保持同步标签、等级计算、备注生成、OTS 更新逻辑不变
- [x] T022 兼容旧 MQ 消息不包含 `sku_id` 的情况

## Phase 4：单元测试

- [x] T023 `juzi-service` 单测：`skuId=4` 且 Redis 白名单不包含当前 `userId`，仍发送 MQ
- [x] T024 `juzi-service` 单测：非 `skuId=4` 且白名单不包含当前 `userId`，不发送 MQ
- [x] T025 `juzi-service` 单测：非 `skuId=4` 且白名单包含当前 `userId`，发送 MQ
- [x] T026 `juzi-service` 单测：用户等级 MQ body 包含 `sku_id`
- [x] T027 `juzi-service` 单测：成功发送后写入用户等级去重 key，TTL 为 30 分钟
- [x] T028 `juzi-service` 单测：去重 key 已存在时不发送 MQ
- [x] T029 `juzi-service` 单测：`signUpTushu=true` 保持原有不限白名单和快速触发行为
- [x] T030 `rocket-mq-consumer` 单测：`userIdConfig` 缺失或不包含当前 `user_id` 时，消费端不再跳过处理
- [x] T031 `rocket-mq-consumer` 单测：`external_user_id` 为空、`day<4`、`day>15` 等既有拦截仍生效
- [x] T032 `rocket-mq-consumer` 单测：正常消息进入等级计算 / OTS 更新路径
- [x] T033 单元测试不得真实访问 Redis、OTS、Center 或 RocketMQ

## Phase 5：验证

- [x] T034 执行 `cd C:\workspace\ju-chat\data-RC && mvn -pl juzi-service -DskipTests=false "-Dtest=UserInsightUpdateServiceImplTest" test`
- [x] T035 执行 `cd C:\workspace\ju-chat\fc && mvn -pl rocket-mq-consumer "-Dtest=UserLevelUpdateTaskTest" test`
- [x] T036 如后续改动影响公共编译，补充运行对应模块编译验证
- [x] T037 更新本文件执行记录，记录实现内容、测试命令、测试结果和自检结论

## 执行记录

### D001 - 文档记录

- 已完成规格、任务清单、执行说明和需求检查清单。
- 本轮按要求仅修改文档，未进行代码实现。

### D002 - 代码实现与单元测试

- 实现内容：`skuId=4` 用户等级 MQ 发送跳过发送端白名单；非钢琴保持原白名单；MQ body 增加 `sku_id`；用户等级去重 TTL 调整为 30 分钟；消费端移除 `userIdConfig` 拦截。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=UserInsightUpdateServiceImplTest" test`
- 测试结果：通过，`Tests run: 5, Failures: 0, Errors: 0, Skipped: 0`。
- 测试命令：`mvn -pl rocket-mq-consumer "-Dtest=UserLevelUpdateTaskTest" test`
- 测试结果：通过，`Tests run: 4, Failures: 0, Errors: 0, Skipped: 0`。
- 自检结论：目标测试均通过；单元测试通过测试替身避免真实 Redis、OTS、Center 和 RocketMQ 调用。

### D003 - 扩展基础信息兜底修复

- 实现内容：修复 `MessageServiceImpl` 传入空 `new UserInfoDto()` 的问题；`DelayMessageServiceImpl#sendExtendBaseInfoGenerate` 改为在方法内部重新获取真实 `UserInfoDto`，并在关键字段缺失时跳过后续生成。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=UserInsightUpdateServiceImplTest,DelayMessageServiceImplTest,MessageServiceImplSopGateTest" test`
- 测试结果：通过，`Tests run: 10, Failures: 0, Errors: 0, Skipped: 0`。
- 自检结论：扩展基础信息生成入口不再依赖空占位对象，且对完整/不完整用户信息均有单元测试覆盖。

### D004 - 权限信息调用切换为 aiFeign

- 实现内容：`DelayMessageServiceImpl#sendExtendBaseInfoGenerate` 不再走 endpoint 工具，改为调用 `aiFeign.getPermission(param)` 获取真实用户权限信息；参数至少包含 `external_user_id` 和 `user_id`。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=DelayMessageServiceImplTest" test`
- 测试结果：通过，`DelayMessageServiceImplTest` 覆盖 aiFeign 调用、参数构造和不完整返回值跳过逻辑。
- 自检结论：权限信息获取已切换到统一的 `aiFeign` 调用路径，避免再依赖 endpoint 直连。

### D005 - 权限查询前补齐 cropId

- 实现内容：`DelayMessageServiceImpl#selectUserInfo` 在调用 `aiFeign.getPermission(param)` 前，先按 `getCropId(user_id, messageDto.getBotWxid())` 生成 `cropId` 并写回 `messageDto`。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=DelayMessageServiceImplTest" test`
- 测试结果：通过，`DelayMessageServiceImplTest` 断言 `crop_id` 已进入权限查询参数，且 `messageDto.cropId` 已同步设置。
- 自检结论：权限查询参数与 `MessageServiceImpl` 的 cropId 取值逻辑对齐。
