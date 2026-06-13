# 规格质量检查清单：0310 营期作业状态回退、历史点评与五维分数 union_id 备份

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-06-13`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目、模块、入口和核心实现位置。
- [x] 明确用户目标、成功标准和非目标。
- [x] 明确新增、修改和禁止改变的行为。
- [x] 明确数据库写入风险、默认回滚、正式提交和回滚快照要求。
- [x] 明确后续实现必须增加静态验证和提交后只读验证记录。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 或未替换占位内容残留。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖正常路径、边界路径和不回归路径。
- [x] 边界情况已识别，并明确阻断、回滚或复核策略。

## 参数完整性门禁

- [x] 已列出关键参数来源和赋值时机。
- [x] 已列出下游读取字段清单。
- [x] 没有未解释的 `new XxxDto()`、空 JSON、空 Map 或占位参数。
- [x] 下游读取字段在 SQL 中已有明确来源，或无应用下游调用变更。
- [x] 已处理调用顺序和 MySQL DDL 隐式提交风险。
- [x] 数据库写入的关键参数已有预览 CSV、临时表固化和提交后断言方案。
- [x] 用户已通过本轮 `PLEASE IMPLEMENT THIS PLAN` 确认执行生产写入。

## 实施就绪度

- [x] 实现范围已限定，不扩散到无关模块。
- [x] 不新增数据库表、不新增对外 API、不修改 MQ / Redis / 配置契约。
- [x] 已确认旧逻辑中必须保持不变的筛选条件和目标字段。
- [x] 每个关键需求至少有一条 SQL 分析、只读预览、演练或提交后验证任务。
- [x] 不需要联调外部系统。
- [x] 补充需求或纠正需求时，已同步更新 `spec.md`、`tasks.md` 和 `AGENTS.md`。

## SQL 审阅清单

- [x] 预览 SQL 均为 `readonly`。
- [x] 写 SQL 被 `database-sql-skill analyze` 标记为非只读风险。
- [x] 目标营期固定为 3 个 0310 进阶班。
- [x] 目标课程固定为 `胡琴说（下）`。
- [x] workPicId 目标数为 `1623`。
- [x] 历史点评目标数为 `114`。
- [x] 五维分数目标数为 `579`。
- [x] `UPDATE drh_works_pic` 只设置 `status=0`。
- [x] `UPDATE drh_history_pic` 只设置 `union_id=target_union_id`。
- [x] `UPDATE drh_song_score` 只设置 `union_id=target_union_id`。
- [x] 写入范围使用临时表固化的 `work_pic_id` / `history_id` / `song_score_id`。
- [x] 仓库内 SQL 默认以 `ROLLBACK` 收尾。
- [x] 临时 `COMMIT` 副本已执行并通过提交后验证。

## 提交后结果

- [x] `drh_works_pic`：3 个营期共 `1623` 条目标作业全部 `status=0`。
- [x] `drh_history_pic`：原始 `union_id` 命中为 `0`，`_bak` 命中为 `114`。
- [x] `drh_song_score`：原始 `union_id` 命中为 `0`，`_bak` 命中为 `579`。
- [x] 提交后验证结果已导出到 `verify-drh-0310-workpic-history-songscore-bak-after.csv`。

## 备注

- 回滚必须基于本目录的三份预览 CSV 快照重新构造临时表，并重新走 `database-sql-skill` 写入门禁。
