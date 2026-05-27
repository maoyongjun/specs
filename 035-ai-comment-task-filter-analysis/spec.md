# 功能规格：AI点评任务过滤链路分析

**功能目录**：`035-ai-comment-task-filter-analysis`  
**创建日期**：`2026-05-27`  
**状态**：Done  
**输入**：用户要求分析 `C:\workspace\ju-chat\kkhc\kkhc-bizcenter\app\src\main\java\com\kkhc\bizcenter\app\facade\works\AiCommentFacade.java` 中 `handleAiCommentTask` 方法。已知 `pageQueryWorks` 调用后存在 `oNGxt59B6vrFI1LqeuKgtsrQ2_E4`，但实际 `drh_fc_task` 未写入该用户，且日志没有 `workpic={},unionId={},已点评过无需点评`。用户补充日志：`课程1124817下一共查回来479条作业数据`、`已点评过无需点评` 203 条、`需要ai评分的数据量:109`。

## 背景

- 当前问题：目标作业进入 `pageQueryWorks` 返回列表后，没有进入 `drh_fc_task` 批量写入。
- 当前行为：`handleAiCommentTask` 从 `worksService.getLatestWorksByLiveIdPerUnionId(classId)` 取回作业列表，再依次过滤作业状态、人工点评记录、已评分记录，最后批量写入 FC 任务。
- 目标行为：确认目标数据被哪一道过滤条件拦截，并说明为什么没有出现用户关注的 `已点评过无需点评` 日志。
- 非目标：本次不修改过滤逻辑，不补日志，不修复数据。

## 结论

`oNGxt59B6vrFI1LqeuKgtsrQ2_E4` 不是被 `status != 0` 分支过滤，所以不会打印 `workpic={},unionId={},已点评过无需点评`。它被后续 `hasManualComment(works)` 分支过滤。

目标作业证据：

- `worksPicId=8701676`
- `liveId=1124817`
- `unionId=oNGxt59B6vrFI1LqeuKgtsrQ2_E4`
- 接口返回 `worksPicDO.status=0`
- 接口返回 `historyPicDO.id=3993498`
- 接口返回 `historyPicDO.picId=8701676`
- 接口返回 `historyPicDO.unionId=oNGxt59B6vrFI1LqeuKgtsrQ2_E4`
- ClickHouse `drh_history_pic` 中存在同一条记录，`create_time=2026-04-28 15:47:36`

因此 `hasManualComment` 返回 `true`，代码会打印的日志是：

```text
workPicId=8701676,unionId=oNGxt59B6vrFI1LqeuKgtsrQ2_E4,已人工点评过跳过AI点评
```

不是：

```text
workpic=8701676,unionId=oNGxt59B6vrFI1LqeuKgtsrQ2_E4,已点评过无需点评
```

## 调用链和过滤顺序

1. `AiCommentFacade.handleAiCommentTask`
2. `worksService.getLatestWorksByLiveIdPerUnionId(input.getClassId())`
3. `WorksServiceImpl.getLatestWorksByLiveIdPerUnionId` 分页调用 `worksFeign::pageQueryWorks`
4. `kkhc-idc WorksFacade.pageQueryWorksInfo` 填充 `WorksInfo.worksPicDO`、`liveUserDO`、`historyPicDO`
5. `handleAiCommentTask` stream 过滤：
   - 空对象过滤，无日志。
   - `worksPicDO.status != PicMessageStatus.NOT_EVALUATE(0)`，打印 `已点评过无需点评`。
   - `hasManualComment(works)`，打印 `已人工点评过跳过AI点评`。
   - `scoredMap.containsKey(classId_unionId)`，过滤已有评分记录，无日志。
6. 仅剩余 `tasksToCreate` 会进入 `batchInsertFcTasks` 并写入 `drh_fc_task`。

## 数据核验

### pageQueryWorks 指定 unionId

请求：

```json
{"liveId":1124817,"unionId":"oNGxt59B6vrFI1LqeuKgtsrQ2_E4","pageCurrent":1,"pageSize":20}
```

返回关键字段：

```json
{
  "worksPicId": 8701676,
  "unionId": "oNGxt59B6vrFI1LqeuKgtsrQ2_E4",
  "status": 0,
  "isDel": 0,
  "auditStatus": 2,
  "createTime": "2026-04-22T17:19:11",
  "commentTime": "2026-04-28T15:47:37",
  "historyPicId": 3993498,
  "historyPicPicId": 8701676,
  "historyUnionId": "oNGxt59B6vrFI1LqeuKgtsrQ2_E4",
  "historyCreateTime": "2026-04-28T15:47:36"
}
```

### querySongScoreList 指定 unionId

请求：

```json
{"classId":1124817,"unionId":"oNGxt59B6vrFI1LqeuKgtsrQ2_E4"}
```

返回 `data=[]`。所以目标不是被 `scoredMap.containsKey(...)` 过滤。

### ClickHouse history_pic

查询条件：

```sql
SELECT id, pic_id, union_id, message_class, history_id, create_time
FROM drh_history_pic
WHERE pic_id = 8701676
   OR union_id = 'oNGxt59B6vrFI1LqeuKgtsrQ2_E4'
ORDER BY create_time DESC, id DESC
LIMIT 20;
```

目标行：

```text
id=3993498, pic_id=8701676, union_id=oNGxt59B6vrFI1LqeuKgtsrQ2_E4, message_class=2, history_id=144675, create_time=2026-04-28 15:47:36
```

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `classId/liveId`：来源 `SongScoreInput.classId`；在 `handleAiCommentTask` 调用 `getLatestWorksByLiveIdPerUnionId` 前已有值；下游用于 `pageQueryWorks` 和 `buildScoreKey`。
  - `worksPicDO.status`：来源 `pageQueryWorks` 返回的 `WorksInfo.worksPicDO.status`；下游在 `AiCommentFacade` 状态过滤读取。
  - `historyPicDO`：来源 `kkhc-idc WorksFacade.pageQueryWorksInfo` 查询 `drh_history_pic` 后填充；下游在 `hasManualComment` 读取。
  - `scoredMap`：来源 `querySongScoreList(classId)`；下游用 `classId_unionId` 判断是否已有评分。
- 下游读取字段清单：
  - `hasManualComment` 读取 `worksPicDO.id`、`worksPicDO.unionId`、`historyPicDO.picId`、`historyPicDO.unionId`。
  - `batchInsertFcTasks` 读取 `SongScoreBO.unionId`、`category`、序列化后的 `userRequestInput`。
- 空对象 / 占位对象风险：
  - `handleAiCommentTask` 过滤了 `WorksInfo` 和 `worksPicDO` 空对象。
  - `historyPicDO` 为空时 `hasManualComment` 返回 `false`，不会过滤。
- 调用顺序风险：
  - `historyPicDO` 在 `pageQueryWorksInfo` 返回前已填充；`handleAiCommentTask` 在拿到 `allWorks` 后直接读取。
- 旧逻辑保持：
  - `status != 0` 仍跳过。
  - 已人工点评仍跳过。
  - 已存在歌曲评分仍跳过。
  - 只有 `tasksToCreate` 才批量写入 `drh_fc_task`。
- 需要用户确认的设计选择：
  - 如果业务希望“有人工点评也继续 AI 评分”，需要明确改变 `hasManualComment` 过滤语义，并补充日志与测试。

## 边界情况

- `status=1` 但无 `historyPicDO`：会被 `status != 0` 过滤，并打印 `已点评过无需点评`。
- `status=0` 且有匹配 `historyPicDO`：会被 `hasManualComment` 过滤，并打印 `已人工点评过跳过AI点评`。
- `status=0` 且无人工点评，但 `drh_song_score` 已有同 `classId + unionId`：会被 `scoredMap` 过滤，当前没有日志。
- ClickHouse `drh_works_pic` 可能能看到同 id 的更新历史行；以接口当前返回为本次链路判断依据。

## 排查手册

遇到 `handleAiCommentTask` 没有写入 `drh_fc_task` 时，按下面顺序排查：

1. 先确认日志命中了哪一层过滤。
   - `workpic={},unionId={},已点评过无需点评`：只说明 `worksPicDO.status != 0`。
   - `workPicId={},unionId={},已人工点评过跳过AI点评`：说明 `historyPicDO.picId` 和 `historyPicDO.unionId` 与作业匹配。
   - 没有这两类日志但未写入任务：重点查 `querySongScoreList(classId)` 返回的 `scoredMap`，该分支当前无日志。
2. 用当前接口查主记录。
   - `GET /kkhc-idc-app/works/getOneById?id={picId}`
   - `POST /kkhc-idc-app/works/pageQueryWorks`，入参带 `liveId`、`unionId`、`pageCurrent=1`、`pageSize=20`
3. 用 ClickHouse 查 `drh_works_pic` 同 `id` 的多版本状态。
   - 如果旧版本 `status=1`，新版本 `status=0`，而日志时间早于回改时间，则日志按旧状态过滤是正常的。
4. 查 `drh_history_pic`。
   - 只要存在 `pic_id={picId}` 且 `union_id={unionId}` 的记录，当前 `pageQueryWorks` 可能会填充 `historyPicDO`，后续 `hasManualComment` 会过滤。
5. 查 `querySongScoreList`。
   - 如果 `classId + unionId` 已有评分记录，即使当前作业 `status=0` 且无人工点评，也会被 `scoredMap` 过滤。

常用 SQL：

```sql
SELECT id, status, comment_time, ai_check, update_time, _sign, _version
FROM drh_works_pic
WHERE id = {picId}
ORDER BY _version DESC, update_time DESC;

SELECT id, pic_id, union_id, message_class, history_id, create_time
FROM drh_history_pic
WHERE pic_id = {picId}
   OR union_id = '{unionId}'
ORDER BY create_time DESC, id DESC
LIMIT 30;
```

## 需求

### 功能需求

- **FR-001**：分析 MUST 明确目标 unionId 未写入 `drh_fc_task` 的过滤分支。
- **FR-002**：分析 MUST 区分 `status` 过滤日志和人工点评过滤日志。
- **FR-003**：分析 MUST 用接口和 ClickHouse 数据交叉验证目标作业状态和历史点评记录。
- **FR-004**：本阶段 MUST NOT 修改业务代码。

## 成功标准

- **SC-001**：能解释 `pageQueryWorks` 有目标数据但 `drh_fc_task` 无目标数据的原因。
- **SC-002**：能解释为什么没有 `已点评过无需点评` 日志。
- **SC-003**：文档记录可复查的接口入参、关键字段和数据库证据。

## 假设

- 用户日志来自同一次 `handleAiCommentTask` 执行。
- `drh_fc_task` 只由 `batchInsertFcTasks(tasksToCreate)` 写入本批 AI 评分任务。
- 本次判断以接口返回的 `WorksInfo` 为主，ClickHouse 用于佐证历史点评数据。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成 `handleAiCommentTask` 过滤链路分析。
- 已确认目标作业命中 `hasManualComment`，不是命中 `status != 0`。
- 本阶段未修改业务代码。

### D002 - `8823989 / oNGxt58zLAx0AeQsiiflgW9IScTo` 状态过滤案例

- 用户问题：日志出现 `workpic=8823989,unionId=oNGxt58zLAx0AeQsiiflgW9IScTo,已点评过无需点评`，需要确认原因。
- 代码结论：该日志只会在 `worksPicDO.status != PicMessageStatus.NOT_EVALUATE(0)` 时打印。
- 历史数据证据：ClickHouse `drh_works_pic` 中 `id=8823989` 有旧版本 `status=1`、`comment_time=2026-05-08 18:36:02`、`update_time=2026-05-08 18:36:02`。
- 人工点评证据：`drh_history_pic` 存在 `id=4027067`、`pic_id=8823989`、`union_id=oNGxt58zLAx0AeQsiiflgW9IScTo`、`create_time=2026-05-08 18:36:02`。
- 当前状态证据：`getOneById?id=8823989` 和当前 `pageQueryWorks` 已返回 `status=0`；ClickHouse 最新版本显示 `status=0`、`update_time=2026-05-27 13:37:36`。
- 解释：日志对应的是回改之前的运行，当时 `status=1`，所以命中“已点评过无需点评”；当前再跑不应继续命中状态过滤，但如果 `historyPicDO` 仍匹配，可能改由人工点评过滤拦截。
- 排查提醒：遇到历史日志和当前接口状态不一致时，必须先查 `drh_works_pic` 多版本记录或更新时间，避免用当前状态反推历史日志。
