# 规格质量检查清单：图书 UnionId 补偿与发送

**用途**：在进入实现前验证规格完整性和质量  
**创建日期**：2026-05-18  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 规格聚焦业务可见行为：当天图书记录补偿、`unionId` 回写、学员消息发送。
- [x] 明确记录 schedule job 的异步触发方式。
- [x] 明确记录 AI 补偿接口的控制器落点与路径。
- [x] 明确记录按当天范围分页处理，每页 `200` 条。
- [x] 明确记录数据链路：`phone_number -> external_user_id -> unionId`。
- [x] 明确记录消息模板来源：参考 `sendMsgStudent`。
- [x] 明确记录消息链接格式与热线号。
- [x] 面向产品、测试和开发均可读。
- [x] 所有必填章节已完成。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 标记残留。
- [x] 需求可测试且无歧义。
- [x] 成功标准可衡量。
- [x] 成功标准与业务结果绑定。
- [x] 所有验收场景已定义。
- [x] 边界情况已识别。
- [x] 范围边界清晰：Spec Kit 文档阶段只写文档；实现阶段代码范围限定在 `kkhc-idc/ai` 与 `kkhc-bizcenter/schedule`。
- [x] 依赖和假设已识别。

## 功能就绪度

- [x] 所有功能需求都有清晰验收条件。
- [x] 用户场景覆盖 job 异步触发、当天记录补偿、消息发送和失败继续处理。
- [x] 功能满足成功标准中定义的可衡量结果。
- [x] 规格文档与任务清单职责分离。
- [x] 验证命令已执行并记录：`mvn -f kkhc/kkhc-idc/pom.xml -pl ai -am -DskipTests compile`、`mvn -f kkhc/kkhc-bizcenter/pom.xml -pl schedule -am -DskipTests compile`。

## 备注

- 用户已确认：消息内容需要与参考实现 `sendMsgStudent` 保持一致。
- 用户已确认：按当天范围分页处理，每页 `200` 条。
- 实现阶段已在 `kkhc-idc/ai` 与 `kkhc-bizcenter/schedule` 完成对应代码变更并通过编译验证。
