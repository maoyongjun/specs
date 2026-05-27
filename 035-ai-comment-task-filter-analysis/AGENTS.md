# 规格执行说明

本目录记录 `AiCommentFacade.handleAiCommentTask` 中作业进入 AI 评分任务前的过滤链路分析。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\035-ai-comment-task-filter-analysis`
- 目标项目：`C:\workspace\ju-chat\kkhc`
- 相关模块：`kkhc-bizcenter/app`、`kkhc-idc/app`、`kkhc-idc/lms-common`

## 当前目标

- 确认 `liveId=1124817`、`unionId=oNGxt59B6vrFI1LqeuKgtsrQ2_E4` 在 `pageQueryWorks` 返回后为什么未写入 `drh_fc_task`。
- 明确 `handleAiCommentTask` 中 `pageQueryWorks` 之后到 `batchInsertFcTasks` 之前的过滤条件。
- 用接口和 ClickHouse 数据留存可复查的证据。

## 执行原则

- 本阶段只做分析和文档记录，不修改业务代码。
- 先以当前源码确认真实调用链，再用接口和 ClickHouse 校验目标数据。
- 区分 `status != 0` 的“已点评过无需点评”日志与 `hasManualComment` 的“已人工点评过跳过AI点评”日志。
- 发现无日志过滤分支时，在文档中明确指出排查盲区。

## 重点代码位置

- `C:\workspace\ju-chat\kkhc\kkhc-bizcenter\app\src\main\java\com\kkhc\bizcenter\app\facade\works\AiCommentFacade.java`
- `C:\workspace\ju-chat\kkhc\kkhc-bizcenter\app\src\main\java\com\kkhc\bizcenter\app\service\work\impl\WorksServiceImpl.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\app\src\main\java\com\kkhc\idc\lms\facade\works\WorksFacade.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\app\src\main\java\com\kkhc\idc\lms\service\works\impl\HistoryPicServiceImpl.java`

## 文档维护

- `spec.md` 记录结论、数据证据、过滤链路和剩余风险。
- `tasks.md` 记录执行过的查询、代码确认和分析步骤。
- `checklists/requirements.md` 记录本次分析完整性检查。
