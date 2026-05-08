# 规格质量检查清单：批量更新企微投诉链接

**用途**：在进入实现前验证规格完整性和质量  
**创建日期**：2026-05-07  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 规格聚焦业务可见行为：job 异步触发，SCRM 接口批量更新企微投诉链接。
- [x] 明确记录 job 示例来源：`IncreaseAbPlanStatusChangeJob`。
- [x] 明确记录 SCRM 新接口落点：`ComplaintController`。
- [x] 明确记录接口名：`batchUpdateWecomUser`。
- [x] 明确记录分页参数：`pageSize=100`，从第 1 页开始处理全部分页。
- [x] 明确记录 company 来源：`ComplaintConfigOutput.company`。
- [x] 明确记录更新调用：`complaintFeign::updateWecomUser`。
- [x] 明确记录相邻 company 调用间隔：2 分钟。
- [x] 明确记录指定日志模板：`更新伪投诉连接地址,company={}` 与 `更新进度{}/{}`。
- [x] 面向产品、测试和开发均可读。
- [x] 所有必填章节已完成。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 标记残留。
- [x] 需求可测试且无歧义。
- [x] 成功标准可衡量。
- [x] 成功标准与业务结果绑定。
- [x] 所有验收场景已定义。
- [x] 边界情况已识别。
- [x] 范围边界清晰：Spec Kit 文档阶段只写文档；实现阶段代码范围限定在 `schedule` 与 `scrm`。
- [x] 依赖和假设已识别。

## 功能就绪度

- [x] 所有功能需求都有清晰验收条件。
- [x] 用户场景覆盖 job 异步触发、全部分页处理、日志追踪和失败处理。
- [x] 功能满足成功标准中定义的可衡量结果。
- [x] 规格文档与任务清单职责分离。
- [x] 验证命令已执行并记录：`mvn -pl schedule,scrm -am -DskipTests compile`。

## 备注

- 本次按现有 `C:\workspace\ju-chat\specs` 下 Spec Kit 文档方式补充 `AGENTS.md`、`spec.md`、`tasks.md` 和 `checklists/requirements.md`。
- 用户已确认：异步位置为 schedule job 异步调用 SCRM 接口。
- 用户已确认：`configPage` 每页 100 条并处理全部分页。
- 用户已确认：相邻 company 调用间隔由原 5 分钟调整为 2 分钟。
- Spec Kit 文档阶段未修改 `kkhc-bizcenter/schedule` 或 `kkhc-bizcenter/scrm` 业务代码；2026-05-07 实现阶段已按 `tasks.md` 完成这两个模块的代码变更。
