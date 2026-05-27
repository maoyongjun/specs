# 任务清单：AI点评任务过滤链路分析

**输入**：来自 `spec.md` 的分析规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：本阶段为数据分析，不改代码；验证方式为源码静态确认、HTTP 接口调用和 ClickHouse 查询。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标为 `AiCommentFacade.handleAiCommentTask` 数据过滤链路。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和任务写入位置。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
- [x] T004 确认涉及外部接口 `pageQueryWorks`、`querySongScoreList`、`batchInsertFcTask` 和数据库表 `drh_history_pic`。
- [x] T005 确认旧逻辑中必须保持不变的过滤：状态过滤、人工点评过滤、已有评分过滤。

**检查点**：已完成 T001-T005；本次不进入业务代码实现。

## Phase 2：风险门禁

- [x] T006 检查空对象过滤：`WorksInfo` 和 `worksPicDO` 已在 stream 前两层过滤。
- [x] T007 检查调用后赋值风险：`historyPicDO` 由 `pageQueryWorksInfo` 返回前填充，`handleAiCommentTask` 只读取。
- [x] T008 检查下游读取字段：`hasManualComment` 所需 `picId`、`unionId` 均有接口返回值。
- [x] T009 检查本次方案是否改变接口契约、远程调用、数据库写入或异步行为：不改变。
- [x] T010 记录需要用户确认的业务语义变化：若要人工点评后仍触发 AI 评分，需要另起需求确认。
- [x] T011 为关键行为建立验证映射：接口返回、ClickHouse 历史点评、源码过滤分支。

**检查点**：已完成 T006-T011；结论见 `spec.md`。

## Phase 3：分析执行

- [x] T012 调用 `pageQueryWorks` 全量分页，确认 `liveId=1124817` 返回 `479` 条，目标在返回列表中。
- [x] T013 调用 `pageQueryWorks` 指定 `unionId`，确认目标 `worksPicId=8701676`、`status=0`、`historyPicDO.id=3993498`。
- [x] T014 调用 `querySongScoreList` 指定 `classId + unionId`，确认目标无歌曲评分记录。
- [x] T015 查询 ClickHouse `drh_history_pic`，确认 `pic_id=8701676` 存在匹配人工点评记录。
- [x] T016 对照 `handleAiCommentTask` 过滤顺序，定位目标命中 `hasManualComment`。

## Phase 4：验证与记录

- [x] T017 记录用户日志数字：`479`、`203`、`109`。
- [x] T018 解释 `479 - 203 - 109 = 167` 的剩余过滤来自人工点评或已有评分分支。
- [x] T019 明确目标不是 `已点评过无需点评` 分支，而是 `已人工点评过跳过AI点评` 分支。
- [x] T020 搜索确认本次未修改业务代码。
- [x] T021 追加 `8823989 / oNGxt58zLAx0AeQsiiflgW9IScTo` 状态过滤案例，记录旧版本 `status=1` 与当前 `status=0` 的差异。
- [x] T022 补充通用排查手册，覆盖日志分支、接口当前值、ClickHouse 多版本、`history_pic` 和 `song_score`。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `035-ai-comment-task-filter-analysis` 并记录源码、接口和 ClickHouse 分析结论。
- 验证方式：源码静态检查、HTTP 接口调用、ClickHouse 查询。
- 自检结论：目标 unionId 被 `hasManualComment` 过滤，未进入 `batchInsertFcTasks`，因此 `drh_fc_task` 未写入。

### D002 - 状态过滤案例记录

- 执行内容：追加 `workpic=8823989` 的排查记录和复用排查手册。
- 验证方式：`getOneById`、`pageQueryWorks`、`querySongScoreList`、ClickHouse `drh_works_pic`、ClickHouse `drh_history_pic`。
- 自检结论：该日志来自历史运行时的 `status=1`；当前数据已回改为 `status=0`，因此当前结果不能直接解释历史日志。
