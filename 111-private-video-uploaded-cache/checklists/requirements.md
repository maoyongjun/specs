# 规格质量检查清单：私聊视频上传标记缓存联动

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-06-25`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目、模块、入口和核心实现位置（juzi-service 写入端、external-info-select 读取端）。
- [x] 明确用户目标、成功标准和非目标。
- [x] 明确新增、修改和禁止改变的行为。
- [x] 明确日志、TTL、幂等（重置 TTL）、异常 fallback、兼容性处理要求。
- [x] 明确后续实现必须增加测试或静态验证记录。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 或未替换占位内容残留（除标准 D002/D003 待填模板）。
- [x] 需求可测试且无明显歧义（触发条件、返回路径已确认）。
- [x] 成功标准可衡量（5 分钟时效、命中/未命中取值）。
- [x] 验收场景覆盖正常路径、边界路径和不回归路径。
- [x] 边界情况已识别，并明确跳过、兜底、记录日志的策略。

## 参数完整性门禁

- [x] 已列出关键参数来源和赋值时机（externalUserId/isSelf/type/群聊判断）。
- [x] 已列出下游读取字段清单（RedisSafeUtil.set 参数、返回 JSON 的 video_uploaded）。
- [x] 没有未解释的 `new XxxDto()`、空 JSON、空 Map 或占位参数。
- [x] 下游读取字段在调用前已赋值，或在当前层现算现用。
- [x] 不存在未处理的调用后赋值风险。
- [x] Redis 写入/读取关键参数已有下游参数断言方案（key/value/TTL/单位、命中映射）。
- [x] 改变调用顺序/契约/语义的点已确认：返回路径范围、触发条件已与用户确认。

## 实施就绪度

- [x] 实现范围已限定，不扩散到 ProfileTask/ProfileTaskV2 或私域路径。
- [x] 不新增数据库表、不新增对外 API、不修改 MQ/OTS/配置契约；仅新增一个 Redis key 与一个返回字段。
- [x] 已确认旧逻辑中必须保持不变的过滤、异常、日志、延迟和 fallback。
- [x] 每个关键需求至少有一条测试、编译或静态验证任务。
- [x] 单元测试计划避免真实访问 Redis/OTS/Center/FC（写入端 mock `stringRedisTemplate`，读取端测 static 纯逻辑）。
- [x] 补充/纠正需求时，已同步更新 spec/tasks/AGENTS/checklist。

## 备注

- 强制门禁未完成前，不进入实现。
- 待核对的部署侧假设：juzi-service 的 `spring.redis` 与 external-info-select FC 的 `redis_host`/`db` 须为同一实例同一库（见 spec「假设」）。
