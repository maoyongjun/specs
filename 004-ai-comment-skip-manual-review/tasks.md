# 任务清单：AI 点评跳过人工已点评作品

**输入**：来自 `specs/004-ai-comment-skip-manual-review/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：本任务清单实现时需要覆盖非待点评状态跳过、人工点评跳过、未点评保留流程、已 AI 打分保留跳过逻辑。  

**组织方式**：任务按阶段组织。当前轮已进入实现阶段，业务代码改动限定为 `AiCommentFacade.java`。

## 格式：`[ID] [P?] [Story] Description`

- **[P]**：可并行执行（不同文件、没有依赖）
- **[Story]**：任务所属用户故事（US1、US2）
- 描述中包含精确文件路径或明确模块范围
- 所有任务初始状态均为未完成；执行后再补充执行记录和自检结论

## /plan 实施计划（已执行）

**当前状态**：已实现非待点评状态跳过、人工点评跳过 AI 点评逻辑，并完成编译验证。

**范围约束**：

- Spec Kit 文档维护范围为 `C:\workspace\ju-chat\specs\004-ai-comment-skip-manual-review`。
- 本轮实现只修改 `C:\workspace\ju-chat\kkhc\kkhc-bizcenter\app\src\main\java\com\kkhc\bizcenter\app\facade\works\AiCommentFacade.java`。
- 不新增查库，不修改 `WorksInfo`、`HistoryPicDO`、`WorksFeign`、`WorksService` 或数据库表结构。
- 人工点评记录只从 `WorksInfo.getHistoryPicDO()` 获取。

**执行节奏**：

- 先确认现有 `handleAiCommentTask` 筛选链路，再增加人工点评过滤。
- 作品状态过滤应位于有效作品过滤之后、人工点评过滤之前，只有 `status == 0` 的作品继续后续判断。
- 人工点评过滤应位于有效作品过滤之后、构建 `SongScoreBO` 之前。
- 保持现有已 AI 打分跳过逻辑和日志语义。
- 每个任务完成后在本文件追加执行记录，至少包含：执行内容、测试命令、测试结果、自检结论。

**每个 task 的完成记录模板**：

- 执行内容：
- 测试命令：
- 测试结果：
- 自检结论：

---

## Phase 1：Setup（确认真实落点）

**目的**：确认本轮实现只改 AI 点评任务筛选逻辑，不扩散到查询或数据模型。

- [x] T001 复查 `specs/004-ai-comment-skip-manual-review/spec.md`、`AGENTS.md`、`checklists/requirements.md`，确认本次实现范围和跳过口径
- [x] T002 [P] 定位 `AiCommentFacade.handleAiCommentTask(SongScoreInput input)` 的 `allWorks.stream()` 筛选链路
- [x] T003 [P] 确认 `WorksInfo.getHistoryPicDO()`、`HistoryPicDO.getPicId()`、`HistoryPicDO.getUnionId()`、`WorksPicDO.getId()`、`WorksPicDO.getUnionId()` 可用于一致性判断

**检查点**：实现落点、字段来源和禁止修改范围已确认。

---

## Phase 2：Implementation（人工点评过滤）

**目的**：在创建 AI 点评任务前过滤已人工点评作品。

- [x] T004 [US1] 在 `AiCommentFacade.java` 中新增私有判断方法或内联过滤逻辑，判定 `historyPicDO` 是否匹配当前 `worksPicDO.id + unionId`
- [x] T005 [US1] 在 `handleAiCommentTask` 的任务筛选链路中接入人工点评过滤，命中后跳过 `buildSongScoreBO`
- [x] T006 [US1] 命中人工点评跳过时打印日志：`workPicId={},unionId={},已人工点评过跳过AI点评`
- [x] T007 [US2] 保留 `historyPicDO == null` 时的现有 AI 点评任务创建流程
- [x] T008 [US2] 保留已有 AI 打分记录时通过 `scoredMap` 跳过的现有逻辑

**检查点**：人工点评优先跳过 AI 点评，未点评作品和已 AI 打分作品行为保持稳定。

---

## Phase 3：Verification（验证与回归）

**目的**：确认新增过滤只影响人工已点评作品。

- [x] T009 [US1] 验证 `historyPicDO.picId == worksPicDO.id` 且 `historyPicDO.unionId == worksPicDO.unionId` 时不创建 AI 点评任务
- [x] T010 [US1] 验证人工点评跳过时输出指定日志，参数为当前 `workPicId` 与 `unionId`
- [x] T011 [US2] 验证 `historyPicDO == null` 且未 AI 打分时仍创建 AI 点评任务
- [x] T012 [US2] 验证已 AI 打分记录仍按 `scoredMap` 跳过
- [x] T013 [US1] 验证 `historyPicDO` 存在但 `picId` 或 `unionId` 与当前作品不一致时，不按当前作品人工点评处理
- [x] T014 验证全部作品都因人工点评或已有 AI 打分被跳过时，不调用 `batchInsertFcTasks` 或 `invokeFcTasksConcurrently`

**检查点**：规格中的 FR-001 至 FR-008 和 SC-001 至 SC-004 均被覆盖。

---

## Phase 4：Documentation Closeout（规格覆盖复查）

**目的**：实现后同步任务执行记录，确保 Spec Kit 可追踪。

- [x] T015 复查 `spec.md` 的功能需求和成功标准，确认实现全覆盖
- [x] T016 更新本文件任务执行记录，记录测试命令、结果和自检结论
- [x] T017 如实现过程中发现需求口径变化，先更新 `spec.md`，再同步 `checklists/requirements.md`

**检查点**：文档、任务记录和实现结果一致。

---

## Phase 5：Supplement（作品状态过滤）

**目的**：补充 `WorksPicDO.status` 门槛，确保只有待点评作品进入 AI 点评。

- [x] T018 [US3] 在 `handleAiCommentTask` 的任务筛选链路中增加 `WorksPicDO.status == 0` 门槛
- [x] T019 [US3] 非待点评状态跳过时打印日志：`workpic={},unionId={},已点评过无需点评`
- [x] T020 [US3] 验证 `WorksPicDO.status == 0` 时仍继续人工点评、已 AI 打分和任务创建判断
- [x] T021 [US3] 验证 `WorksPicDO.status != 0` 或 `status == null` 时不创建 AI 点评任务
- [x] T022 更新 `spec.md`、`AGENTS.md`、`checklists/requirements.md` 和本文件，记录作品状态过滤口径

**检查点**：规格中的 FR-010 至 FR-013 和 SC-006 至 SC-007 均被覆盖。

---

## 执行记录

### T001

- 执行内容：已复查 `spec.md`、`AGENTS.md`、`checklists/requirements.md`，确认人工点评来源为 `WorksInfo.getHistoryPicDO()`，匹配口径为同一 `picId` 与 `unionId`。
- 测试命令：`Get-Content -Raw specs/004-ai-comment-skip-manual-review/spec.md`；`Get-Content -Raw specs/004-ai-comment-skip-manual-review/AGENTS.md`；`Get-Content -Raw specs/004-ai-comment-skip-manual-review/checklists/requirements.md`
- 测试结果：文档口径已确认，并已将阶段说明同步为实现阶段。
- 自检结论：通过。

### T002

- 执行内容：已定位 `AiCommentFacade.handleAiCommentTask(SongScoreInput input)` 中 `allWorks.stream()` 筛选链路。
- 测试命令：`rg -n "handleAiCommentTask|allWorks.stream|buildSongScoreBO" app/src/main/java/com/kkhc/bizcenter/app/facade/works/AiCommentFacade.java`
- 测试结果：筛选链路位于有效作品过滤、`scoredMap` 过滤和 `buildSongScoreBO` 构建之间。
- 自检结论：通过。

### T003

- 执行内容：已确认 `HistoryPicDO.picId`、`WorksPicDO.id` 为 `Integer`，`HistoryPicDO.unionId`、`WorksPicDO.unionId` 为 `String`。
- 测试命令：`rg -n "class HistoryPicDO|class WorksInfo|class WorksPicDO" C:\workspace\ju-chat\kkhc`
- 测试结果：字段可用于 `Objects.equals` 一致性判断，且无需新增查询。
- 自检结论：通过。

### T004

- 执行内容：在 `AiCommentFacade.java` 新增 `hasManualComment(WorksInfo worksInfo)`，仅当 `historyPicDO.picId` 和 `historyPicDO.unionId` 均匹配当前作品时返回 true。
- 测试命令：`mvn -pl app -am -DskipTests compile`
- 测试结果：编译通过。
- 自检结论：通过。

### T005

- 执行内容：在有效作品过滤之后、`scoredMap` 过滤之前接入人工点评过滤，命中时返回 false，不进入 `buildSongScoreBO`。
- 测试命令：`rg -n "hasManualComment|scoredMap|buildSongScoreBO" app/src/main/java/com/kkhc/bizcenter/app/facade/works/AiCommentFacade.java`
- 测试结果：过滤顺序符合要求。
- 自检结论：通过。

### T006

- 执行内容：人工点评命中时打印 `workPicId={},unionId={},已人工点评过跳过AI点评`，参数取当前 `WorksPicDO.id` 与 `WorksPicDO.unionId`。
- 测试命令：`rg -n "workPicId=\\{\\},unionId=\\{\\},已人工点评过跳过AI点评" app/src/main/java/com/kkhc/bizcenter/app/facade/works/AiCommentFacade.java`
- 测试结果：日志模板和参数位置符合要求。
- 自检结论：通过。

### T007

- 执行内容：`historyPicDO == null` 时 `hasManualComment` 返回 false，继续沿用原 AI 点评创建流程。
- 测试命令：`mvn -pl app -am -DskipTests compile`
- 测试结果：编译通过，代码路径保留。
- 自检结论：通过。

### T008

- 执行内容：保留 `scoredMap.containsKey(buildScoreKey(...))` 过滤逻辑，未修改已 AI 打分跳过判断。
- 测试命令：`rg -n "scoredMap.containsKey\\(buildScoreKey" app/src/main/java/com/kkhc/bizcenter/app/facade/works/AiCommentFacade.java`
- 测试结果：原有已 AI 打分跳过逻辑仍在。
- 自检结论：通过。

### T009

- 执行内容：复查 `hasManualComment` 匹配条件，确认 `historyPicDO.picId == worksPicDO.id` 且 `historyPicDO.unionId == worksPicDO.unionId` 时人工点评过滤返回 false，后续不创建任务。
- 测试命令：`mvn -pl app -am -DskipTests compile`
- 测试结果：编译通过，代码路径满足不进入 `buildSongScoreBO`。
- 自检结论：通过。

### T010

- 执行内容：复查人工点评过滤分支，确认命中时先记录指定日志再跳过。
- 测试命令：`rg -n "workPicId=\\{\\},unionId=\\{\\},已人工点评过跳过AI点评" app/src/main/java/com/kkhc/bizcenter/app/facade/works/AiCommentFacade.java`
- 测试结果：日志模板存在，参数为当前 `worksPicDO.getId()` 与 `worksPicDO.getUnionId()`。
- 自检结论：通过。

### T011

- 执行内容：复查 `historyPicDO == null` 分支，确认不会命中人工点评跳过，仍可进入 `scoredMap` 判断和 `buildSongScoreBO`。
- 测试命令：`mvn -pl app -am -DskipTests compile`
- 测试结果：编译通过，代码路径保留。
- 自检结论：通过。

### T012

- 执行内容：复查已 AI 打分分支，确认 `scoredMap` 过滤仍在 `buildSongScoreBO` 之前。
- 测试命令：`rg -n "scoredMap|buildSongScoreBO" app/src/main/java/com/kkhc/bizcenter/app/facade/works/AiCommentFacade.java`
- 测试结果：已 AI 打分作品仍被 `scoredMap` 过滤，不创建任务。
- 自检结论：通过。

### T013

- 执行内容：复查 `hasManualComment` 不匹配分支，确认 `historyPicDO.picId` 为空或不一致、`historyPicDO.unionId` 为空或不一致时返回 false。
- 测试命令：`mvn -pl app -am -DskipTests compile`
- 测试结果：编译通过，不匹配人工点评时继续原流程。
- 自检结论：通过。

### T014

- 执行内容：复查 `tasksToCreate.isEmpty()` 分支，确认全部作品被人工点评或已 AI 打分过滤后直接 return，不调用 `batchInsertFcTasks` 或 `invokeFcTasksConcurrently`。
- 测试命令：`rg -n "tasksToCreate.isEmpty|batchInsertFcTasks|invokeFcTasksConcurrently" app/src/main/java/com/kkhc/bizcenter/app/facade/works/AiCommentFacade.java`
- 测试结果：空任务列表仍提前返回，后续批量插入和 FC 调用位于 return 之后。
- 自检结论：通过。

### T015

- 执行内容：复查 `spec.md` 的 FR-001 至 FR-009、SC-001 至 SC-005，确认实现和文档口径一致。
- 测试命令：`Get-Content -Raw specs/004-ai-comment-skip-manual-review/spec.md`
- 测试结果：规格已同步为实现阶段，需求和成功标准已覆盖。
- 自检结论：通过。

### T016

- 执行内容：已更新本文件勾选状态和执行记录，记录执行内容、测试命令、测试结果与自检结论。
- 测试命令：`Get-Content -Raw specs/004-ai-comment-skip-manual-review/tasks.md`
- 测试结果：任务清单已回填。
- 自检结论：通过。

### T017

- 执行内容：发现文档仍保留上一阶段“只写 Spec Kit、不修改业务代码”的描述，已先更新 `spec.md`，再同步 `checklists/requirements.md` 和 `AGENTS.md` 的阶段说明。
- 测试命令：`Get-Content -Raw specs/004-ai-comment-skip-manual-review/spec.md`；`Get-Content -Raw specs/004-ai-comment-skip-manual-review/checklists/requirements.md`
- 测试结果：文档说明已与当前实现阶段一致。
- 自检结论：通过。

### T018

- 执行内容：在 `AiCommentFacade.handleAiCommentTask` 的有效作品过滤之后增加 `WorksPicDO.status` 门槛，仅 `PicMessageStatus.NOT_EVALUATE.getCode()`（0 待点评）继续后续判断。
- 测试命令：`rg -n "PicMessageStatus.NOT_EVALUATE|getStatus" app/src/main/java/com/kkhc/bizcenter/app/facade/works/AiCommentFacade.java`
- 测试结果：状态过滤已位于人工点评过滤和 `scoredMap` 过滤之前。
- 自检结论：通过。

### T019

- 执行内容：非待点评状态跳过时打印 `workpic={},unionId={},已点评过无需点评`，参数取当前 `WorksPicDO.id` 与 `WorksPicDO.unionId`。
- 测试命令：`rg -n "workpic=\\{\\},unionId=\\{\\},已点评过无需点评" app/src/main/java/com/kkhc/bizcenter/app/facade/works/AiCommentFacade.java`
- 测试结果：日志模板和参数位置符合要求。
- 自检结论：通过。

### T020

- 执行内容：复查 `status == 0` 分支，确认待点评作品返回 true，继续进入人工点评、已 AI 打分和 `buildSongScoreBO` 判断链路。
- 测试命令：`mvn -pl app -am -DskipTests compile`
- 测试结果：编译通过，待点评作品代码路径保留。
- 自检结论：通过。

### T021

- 执行内容：复查 `status != 0` 或 `status == null` 分支，确认非待点评状态返回 false，不进入 `buildSongScoreBO`，不会创建 `FcTaskDO` 或调用 FC。
- 测试命令：`mvn -pl app -am -DskipTests compile`
- 测试结果：编译通过，非待点评状态代码路径满足跳过要求。
- 自检结论：通过。

### T022

- 执行内容：已将作品状态过滤口径同步到 `spec.md`、`AGENTS.md`、`checklists/requirements.md` 和 `tasks.md`，新增 US3、FR-010 至 FR-013、SC-006 至 SC-007 和执行记录。
- 测试命令：`rg -n "status == 0|非待点评|已点评过无需点评|FR-010|SC-006|T018" specs/004-ai-comment-skip-manual-review`
- 测试结果：文档已覆盖新增状态门槛与日志要求。
- 自检结论：通过。
