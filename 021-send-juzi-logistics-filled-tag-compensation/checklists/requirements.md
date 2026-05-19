# 规格质量检查清单：发送物流时补偿“已填写”标签

**用途**：验证发送物流时补偿“已填写”标签需求完整性和实现可测性  
**创建日期**：2026-05-19  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标代码文件和作用范围。
- [x] 明确物流消息分支是唯一触发点，非物流消息不触发。
- [x] 明确 `MqQwTagEnum.Write_Over` 的动态查询方式。
- [x] 明确 `QwAutoTag` 查询条件为 `source + type`。
- [x] 明确 `externalUserId`、`userId`、`unionId`、`companyId` 的参数来源。
- [x] 明确中文日志要求和 best-effort 降级策略。
- [x] 明确补偿 FC 的函数名通过 `mq.delay.topic` 区分，`test_delay` 走测试函数，`delay` 走正式函数。
- [x] 所有必填章节已完成。

## 需求完整性

- [x] 无 `[NEEDS_CLARIFICATION]` 标记残留。
- [x] 需求可测试且无歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖物流消息、非物流消息、配置缺失和补偿异常场景。
- [x] 边界情况已识别。

## 实施就绪度

- [x] 实现范围限定在 `AiController`、`AiServiceImpl`、`QwAutoTagService` 相关逻辑。
- [x] 不涉及新增 endpoint、DTO、配置或数据库表。
- [x] `invokeFc` 参数映射已明确。
- [x] `QwAutoTag` 动态查询条件已明确。
- [x] 日志与降级策略已明确。
- [x] 测试/正式 FC 函数名分流规则已明确。

## 备注

- 物流消息判定沿用现有 `sendJuzi` 逻辑，不重新发明新的识别规则。
- 标签补偿是附加副作用，失败时不应阻断消息发送。
- 实现已完成，并通过 `mvn -f kkhc/kkhc-idc/pom.xml -pl ai -am -DskipTests compile` 验证。
- 测试/正式环境的 FC 函数名不再依赖 `SpringUtil.isDev()`，而是由 `mq.delay.topic` 是否为 `test_delay` 决定。
