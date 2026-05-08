# 规格执行说明

本目录记录 `004-ai-comment-skip-manual-review` 功能规格，作用范围仅限当前规格目录及其子目录。

## 当前阶段

- 当前阶段已进入实现与收尾记录。
- 业务代码改动仅限 `kkhc-bizcenter/app` 的 `AiCommentFacade.java`。
- 当前目录应包含 `AGENTS.md`、`spec.md`、`tasks.md` 和 `checklists/requirements.md`。

## 实现约束

- 目标改动文件仅限 `C:\workspace\ju-chat\kkhc\kkhc-bizcenter\app\src\main\java\com\kkhc\bizcenter\app\facade\works\AiCommentFacade.java`。
- 目标方法为 `handleAiCommentTask(SongScoreInput input)`。
- 不新增数据库查询；必须复用 `WorksInfo.getHistoryPicDO()` 中已查出的 `drh_history_pic` 最新人工点评记录。
- 不修改 `WorksInfo`、`HistoryPicDO`、`WorksFeign`、`WorksService`、Feign 查询入参或数据库表结构。
- 现有空值过滤、已 AI 打分跳过、任务批量插入和 FC 调用流程需要保持不变。
- 只有 `WorksPicDO.status == 0`（待点评）时才允许继续 AI 点评筛选；非待点评状态必须跳过，并打印日志：`workpic={},unionId={},已点评过无需点评`。
- 人工点评命中时必须跳过 AI 点评任务创建，并打印日志：`workPicId={},unionId={},已人工点评过跳过AI点评`。

## 文档维护

- `spec.md` 描述用户场景、功能需求、边界情况、成功标准和假设。
- `tasks.md` 记录实现任务拆分、验收任务和执行结果。
- `checklists/requirements.md` 用于进入实现前验证规格质量。
- 如果需求变化，先更新 `spec.md`，再同步 `tasks.md` 与检查清单。
