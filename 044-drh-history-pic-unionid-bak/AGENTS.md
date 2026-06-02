# 规格执行说明

本目录用于这次 `drh_history_pic` 人工点评记录 `union_id` 备份 SQL 的 Spec Kit 文档。当前需求只做文档、SQL 脚本整理和只读查询核验，不执行数据库更新，待审核后再由人工决定是否提交。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\044-drh-history-pic-unionid-bak`
- 目标项目：`C:\workspace\ju-chat`
- 相关模块：数据库运维 / `drh_history_pic` 人工点评记录

## 当前目标

- 记录本次运维目标、筛选条件、影响范围和回滚优先策略。
- 生成可审核的 SQL，将指定 5 个 `union_id` 在课程 `胡琴说（上）` 下对应作业的 `drh_history_pic.union_id` 改为 `{union_id}_bak`。
- SQL 更新后输出 `/works/songScore` 运维接口参数，其中 `class_id` 取命中作业的 `live_id`。
- SQL 默认以 `ROLLBACK` 收尾，不在审核前提交数据库变更。

## 执行原则

- 先圈定目标行，再按 `drh_history_pic.id` 更新。
- 必须保留用户给出的筛选口径：`drh_history_pic.union_id`、`drh_works_pic.id = drh_history_pic.pic_id`、`drh_works_pic.union_id = drh_history_pic.union_id`、`drh_live.name = '胡琴说（上）'`。
- 只允许修改 `drh_history_pic.union_id`，不修改 `json`、`message_class`、`history_id`、`create_time`、`drh_works_pic` 或 `drh_live`。
- 不允许使用空集合、占位条件或未确认的额外课程/班级条件扩大范围。
- SQL 默认 `ROLLBACK`，审核确认后才能把末尾改为 `COMMIT`。

## 强制门禁

- 关键参数必须能追溯到用户输入或示例 SQL。
- 更新目标必须明确为 `drh_history_pic`，目标字段必须明确为 `union_id`。
- 更新前必须能通过临时表查询和分组计数审阅目标行。
- 更新后必须能复核 `updated_count == target_count` 且 `not_updated_count == 0`。
- 更新后必须能输出接口参数：`class_id`、`max_score`、`min_score`、`song_name`。
- 本目录阶段不得执行数据库更新。

## 重点文件

- `drh-history-pic-unionid-bak.sql`
- `ops-interface-params.json`
- `spec.md`
- `tasks.md`
- `checklists\requirements.md`

## 文档维护

- `spec.md` 记录需求背景、边界、成功标准和假设。
- `tasks.md` 记录文档准备、脚本整理和后续执行状态。
- `checklists\requirements.md` 用于确认脚本是否满足审阅和执行前置条件。
- 如果后续调整 `union_id` 列表、课程筛选或提交策略，必须追加纠正记录并同步更新相关文档。
- 如果后续补偿参数发现漏了某个 `class_id`，必须在纠正记录里说明是参数缺失、SQL 目标筛选错误，还是目标表数据本身缺失，避免混淆数据问题和运维执行问题。
