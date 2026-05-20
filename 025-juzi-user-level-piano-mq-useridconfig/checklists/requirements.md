# 规格质量检查清单：用户等级 MQ userIdConfig 放开与触发间隔调整

**用途**：验证用户等级 MQ 调整需求完整性和后续实现可测性  
**创建日期**：2026-05-20  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标发送端模块为 `data-RC/juzi-service`。
- [x] 明确目标消费端模块为 `fc/rocket-mq-consumer`。
- [x] 明确 `skuId=4` 钢琴用户等级生成发送 MQ 不限制 `userIdConfig`。
- [x] 明确非 `skuId=4` 普通用户等级生成仍保持发送端白名单控制。
- [x] 明确 `UserLevelUpdateTask` 消费端全量取消 `userIdConfig` 限制。
- [x] 明确 30 分钟间隔是 Redis 去重 TTL。
- [x] 明确不调整 MQ 延迟投递时间。
- [x] 明确命中去重 key 的日志文案需要同步调整为 30 分钟。
- [x] 明确 MQ body 增加 `sku_id` 字段，并保留现有字段。
- [x] 明确 `UserLevelUpdateInput` 增加可选 `sku_id` 字段。
- [x] 明确后续实现必须增加单元测试。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 标记残留。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖钢琴 `skuId=4` 白名单外发送。
- [x] 验收场景覆盖非钢琴白名单外不发送。
- [x] 验收场景覆盖消费端白名单缺失或不命中时不跳过。
- [x] 验收场景覆盖 30 分钟去重 TTL。
- [x] 验收场景覆盖去重命中时不发送 MQ。
- [x] 验收场景覆盖 `signUpTushu=true` 不回归。
- [x] 验收场景覆盖旧 MQ 消息缺少 `sku_id` 的兼容性。
- [x] 边界情况已识别。

## 实施就绪度

- [x] 实现范围限定为 `juzi-service` 发送端和 `rocket-mq-consumer` 消费端。
- [x] 本次不新增数据库表。
- [x] 本次不新增对外 API。
- [x] 本次不修改用户等级判定规则。
- [x] 本次不修改 MQ topic 或 tag。
- [x] 明确后续实现需要避免真实 Redis、OTS、Center 或 RocketMQ 的单元测试依赖。
- [x] 明确后续实现需要运行目标模块单元测试。

## 备注

- 当前需求已完成代码实现和目标单元测试。
- 消费端取消 `userIdConfig` 限制是全量取消。
- 30 分钟间隔只调整 `ai:info:user:level:key:{externalUserId}:{userId}` 去重 TTL 和对应日志文案。
