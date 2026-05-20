# 规格执行说明

本目录记录 `025-juzi-user-level-piano-mq-useridconfig` 的规格与实现约定。当前需求已完成业务代码实现和目标单元测试。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\025-juzi-user-level-piano-mq-useridconfig`
- 发送端目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 消费端目标项目：`C:\workspace\ju-chat\fc\rocket-mq-consumer`

## 当前目标

- 钢琴 `skuId=4` 用户等级生成发送 MQ 时，不再受发送端 `userIdConfig` 白名单限制。
- 非 `skuId=4` 普通用户等级生成仍保持发送端现有白名单控制。
- `UserLevelUpdateTask` 消费端全量取消 `userIdConfig` 限制，不再因白名单缺失或不命中提前跳过用户等级更新。
- 发送端用户等级生成去重间隔从 10 分钟改为 30 分钟。
- 去重间隔指 Redis key `ai:info:user:level:key:{externalUserId}:{userId}` 的 TTL，不调整 MQ 延迟投递时间。
- 用户等级 MQ body 增加 `sku_id` 字段，并兼容旧消息。

## 实现约束

- 只调整 `UserInsightUpdateServiceImpl#userLevelGenerate`、`UserLevelUpdateInput`、`UserLevelUpdateTask` 相关行为。
- 不新增数据库表。
- 不新增对外 API。
- 不修改用户等级判定规则。
- 不修改 MQ topic、tag 或现有字段名。
- 不调整普通 MQ 的 `startDeliverTime` 延迟投递逻辑。
- `signUpTushu=true` 保持现有不限白名单和快速触发行为。
- 消费端取消的是 `userIdConfig` 拦截，不取消 `external_user_id`、`day` 范围等业务校验。
- 已补充可执行单元测试，并通过测试替身避免真实 Redis、OTS、Center 或 RocketMQ 调用。
- 修改业务链路前，必须先追踪关键参数来源和赋值时机，检查是否存在占位 DTO、调用后赋值、跨层可变状态或字段来源不确定的问题。
- 发现关键参数未在当前链路中完成赋值，或需要依赖后续步骤补齐时，必须先标记为风险，并优先选择在当前层现算现用、显式构建请求对象或向用户确认。
- 任何会改变调用顺序、引入额外远程调用、或修改接口契约的修复方案，在实施前都要先确认业务意图。

## 重点代码位置

- `data-RC/juzi-service/src/main/java/com/drh/data/juzi/service/impl/UserInsightUpdateServiceImpl.java`
- `data-RC/juzi-service/src/main/java/com/drh/data/juzi/service/impl/DelayMessageServiceImpl.java`
- `data-RC/juzi-service/src/main/java/com/drh/data/juzi/service/impl/MessageServiceImpl.java`
- `fc/rocket-mq-consumer/src/main/java/com/drh/mq/dto/UserLevelUpdateInput.java`
- `fc/rocket-mq-consumer/src/main/java/com/drh/mq/service/UserLevelUpdateTask.java`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录后续实现和验证任务。
- `checklists/requirements.md` 用于验证规格质量和实施就绪度。

## 已完成补充

- 扩展基础信息生成入口不再传入空的 `UserInfoDto` 占位对象。
- `DelayMessageServiceImpl#sendExtendBaseInfoGenerate` 会在内部通过 `aiFeign.getPermission(param)` 获取真实用户信息，再触发用户等级和关单建议生成。
- `DelayMessageServiceImpl#selectUserInfo` 会先按 `getCropId(user_id, messageDto.getBotWxid())` 补齐 `cropId`，并同步写回 `messageDto`。
