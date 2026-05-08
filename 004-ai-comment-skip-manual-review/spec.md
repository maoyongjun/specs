# 功能规格：AI 点评跳过人工已点评作品

**功能分支**：`004-ai-comment-skip-manual-review`  
**创建日期**：2026-05-07  
**状态**：Implemented  
**输入**：用户描述：“修改 `kkhc-bizcenter/app` 的 `AiCommentFacade.java` 中 `handleAiCommentTask` 方法，增加限制：如果 `drh_history_pic` 中同一个 `unionId`、同一个 `pic_id` 有记录，代表人工点评过，不再往下走 AI 点评。其中 `drh_history_pic` 已经在 `WorksInfo` 对象中查询出来了，`HistoryPicDO` 就是最后一次的人工点评。因人工点评过跳过 AI 点评的，需要打印日志，提示 `workPicId={},unionId={},已人工点评过跳过AI点评`。” 补充要求：“WorksPicDO 的 status 只有是 0 待点评的，才走点评。同样点评日志，提示，`workpic={},unionId={},已点评过无需点评`。”

## 用户场景与测试

### 用户故事 1 - 人工点评过的作品不再触发 AI 点评（优先级：P1）

运营或系统批量发起 AI 点评任务时，如果某个学员的某个作品已经有老师人工点评记录，系统应尊重人工点评结果，不再为该作品创建 AI 点评任务，也不再调用函数计算。

**优先级原因**：人工点评优先级高于 AI 点评。重复触发 AI 点评会造成点评冲突、任务浪费，也可能覆盖或干扰人工点评后的用户体验。

**独立测试**：构造 `WorksInfo`，其中 `worksPicDO.id`、`worksPicDO.unionId` 与 `historyPicDO.picId`、`historyPicDO.unionId` 一致，执行 `handleAiCommentTask` 任务筛选逻辑，验证该作品不进入 `tasksToCreate`，且输出指定日志。

**验收场景**：

1. **Given** `WorksInfo.historyPicDO` 不为空，且 `historyPicDO.picId == worksPicDO.id`、`historyPicDO.unionId == worksPicDO.unionId`，**When** 执行 `handleAiCommentTask`，**Then** 该作品跳过 AI 点评任务创建。
2. **Given** 人工点评命中，**When** 系统跳过该作品，**Then** 日志包含 `workPicId={},unionId={},已人工点评过跳过AI点评`，参数分别为当前作品 ID 和 unionId。
3. **Given** 课程下所有最新作品都已人工点评或已 AI 打分，**When** 执行任务筛选，**Then** 不批量插入 FC 任务，也不调用 FC。

---

### 用户故事 2 - 未人工点评的作品保持现有 AI 点评流程（优先级：P1）

当作品没有人工点评记录，且也没有现有 AI 打分记录时，系统继续按当前逻辑创建 AI 点评任务、批量插入 `FcTaskDO` 并调用函数计算。

**优先级原因**：新增人工点评限制不能影响正常的 AI 点评任务生成。

**独立测试**：构造 `WorksInfo.historyPicDO == null` 且当前 `unionId` 未出现在 `scoredMap` 中，验证该作品仍会通过 `buildSongScoreBO` 构建任务对象。

**验收场景**：

1. **Given** `historyPicDO == null` 且该学员课程维度未 AI 打分，**When** 执行 `handleAiCommentTask`，**Then** 该作品继续进入 AI 点评任务创建流程。
2. **Given** 作品已有 AI 打分记录，**When** 执行 `handleAiCommentTask`，**Then** 仍按现有 `scoredMap` 逻辑跳过。
3. **Given** 课程下同时存在人工点评作品和未点评作品，**When** 执行 `handleAiCommentTask`，**Then** 只为未人工点评且未 AI 打分的作品创建任务。

---

### 用户故事 3 - 非待点评状态作品不再触发点评（优先级：P1）

运营或系统批量发起 AI 点评任务时，只有 `WorksPicDO.status == 0`（待点评）的作品允许继续走点评流程。已点评、非作业、重复作业或空状态作品都应跳过，避免重复或错误点评。

**优先级原因**：作品状态是点评入口的基础门槛。非待点评作品继续进入 AI 点评会导致重复点评、错误处理或任务浪费。

**独立测试**：构造 `WorksInfo.worksPicDO.status != 0` 或 `status == null`，执行 `handleAiCommentTask` 任务筛选逻辑，验证该作品不进入 `tasksToCreate`，且输出指定日志。

**验收场景**：

1. **Given** `WorksPicDO.status == 0` 且未人工点评、未 AI 打分，**When** 执行 `handleAiCommentTask`，**Then** 该作品继续进入 AI 点评任务创建流程。
2. **Given** `WorksPicDO.status != 0`，**When** 执行 `handleAiCommentTask`，**Then** 该作品跳过 AI 点评任务创建，并输出 `workpic={},unionId={},已点评过无需点评`。
3. **Given** `WorksPicDO.status == null`，**When** 执行 `handleAiCommentTask`，**Then** 该作品不进入 AI 点评任务创建流程。

## 边界情况

- `WorksInfo` 为空。
- `WorksInfo.worksPicDO` 为空。
- `WorksInfo.worksPicDO.status` 为空。
- `WorksInfo.worksPicDO.status` 不等于 0（已点评、不是作业、重复作业等）。
- `WorksInfo.historyPicDO` 为空。
- `historyPicDO.picId` 为空或与 `worksPicDO.id` 不一致。
- `historyPicDO.unionId` 为空或与 `worksPicDO.unionId` 不一致。
- 同一课程下部分作品人工点评、部分作品未点评。
- 作品已人工点评且也已存在 AI 打分记录。
- `worksService.getLatestWorksByLiveIdPerUnionId(classId)` 返回空列表。

## 需求

### 功能需求

- **FR-001**：系统 MUST 在 `AiCommentFacade.handleAiCommentTask` 创建 AI 点评任务前检查当前 `WorksInfo` 是否已有人工点评记录。
- **FR-002**：系统 MUST 复用 `WorksInfo.getHistoryPicDO()`，不得为了本需求新增 `drh_history_pic` 查询。
- **FR-003**：当 `historyPicDO` 不为空，且 `historyPicDO.picId` 等于当前 `worksPicDO.id`、`historyPicDO.unionId` 等于当前 `worksPicDO.unionId` 时，系统 MUST 判定当前作品已人工点评。
- **FR-004**：已人工点评的作品 MUST 跳过 AI 点评，不得进入 `buildSongScoreBO`，不得创建 `FcTaskDO`，不得调用函数计算。
- **FR-005**：因人工点评跳过 AI 点评时，系统 MUST 打印日志：`workPicId={},unionId={},已人工点评过跳过AI点评`。
- **FR-006**：没有人工点评记录的作品 MUST 保留现有 AI 点评流程。
- **FR-007**：已有 AI 打分记录的作品 MUST 继续按现有 `scoredMap` 逻辑跳过。
- **FR-008**：系统 MUST 保留现有空值保护，不因空 `WorksInfo` 或空 `worksPicDO` 抛出异常。
- **FR-009**：实现阶段 MUST 将业务代码改动限定在 `kkhc-bizcenter/app` 的 `AiCommentFacade.java`，不修改查询、数据模型或表结构。
- **FR-010**：系统 MUST 在创建 AI 点评任务前检查 `WorksPicDO.status`，只有 `status == 0`（待点评）时才允许继续点评流程。
- **FR-011**：当 `WorksPicDO.status != 0` 或 `status == null` 时，系统 MUST 跳过 AI 点评，不得进入 `buildSongScoreBO`，不得创建 `FcTaskDO`，不得调用函数计算。
- **FR-012**：因非待点评状态跳过点评时，系统 MUST 打印日志：`workpic={},unionId={},已点评过无需点评`，参数分别为当前作品 ID 和 unionId。
- **FR-013**：`WorksPicDO.status` 门槛 MUST 位于有效作品过滤之后、人工点评过滤和 `scoredMap` 过滤之前，确保只有待点评作品才继续后续判断。

## 成功标准

### 可衡量结果

- **SC-001**：人工点评命中的作品 100% 不会创建 AI 点评任务。
- **SC-002**：人工点评命中的作品 100% 输出指定跳过日志，日志参数包含当前 `workPicId` 与 `unionId`。
- **SC-003**：未人工点评且未 AI 打分的作品仍按现有流程进入 AI 点评任务创建。
- **SC-004**：已有 AI 打分记录的作品仍按现有逻辑跳过。
- **SC-005**：实现完成后，业务代码改动仅限 `AiCommentFacade.java`，Spec Kit 文档同步记录执行结果。
- **SC-006**：非待点评状态作品 100% 不会创建 AI 点评任务。
- **SC-007**：非待点评状态作品 100% 输出指定跳过日志，日志参数包含当前 `workpic` 与 `unionId`。

## 假设

- `WorksInfo.historyPicDO` 已由 `worksFeign.pageQueryWorks` 相关查询填充。
- `HistoryPicDO` 表示 `drh_history_pic` 中当前作品最后一次人工点评记录。
- `WorksPicDO.status == 0` 表示待点评，其他状态或空状态均不进入本次 AI 点评。
- 当前 AI 点评任务筛选在 `AiCommentFacade.handleAiCommentTask` 的 `allWorks.stream()` 链路中完成。
- 当前实现阶段修改 `AiCommentFacade.java`，并同步维护 Spec Kit 执行记录。
