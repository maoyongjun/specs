# 功能规格：批量更新企微投诉链接

**功能分支**: `005-batch-update-wecom-user`  
**创建日期**: 2026-05-07  
**状态**: Implemented  
**输入**: 用户描述：“增加一个 job，调用接口。编写 job 的例子：`C:\workspace\ju-chat\kkhc\kkhc-bizcenter\schedule\src\main\java\com\kkhc\bizcenter\schedule\task\increase\IncreaseAbPlanStatusChangeJob.java`。调用接口使用异步执行。被调用的接口，在 `C:\workspace\ju-chat\kkhc\kkhc-bizcenter\scrm\src\main\java\com\drh\kkhc\bizcenter\scrm\controller\complaint\ComplaintController.java` 新增，接口名是 `batchUpdateWecomUser`。接口内部先调用 `complaintFeign::configPage`，分页数量是 100，获取 company，然后调用 `complaintFeign::updateWecomUser`，原始间隔 5 分钟，再调用，因为这个方法内部是异步的。需要有日志：`更新伪投诉连接地址,company={}`，`更新进度{}/{}`。进度前面是当前正在执行的 Index，后面是列表的总数量。” 补充确认：“job 异步调用接口；`configPage` 每页 100 条并处理全部分页。” 本次补充确认：“相邻 company 调用间隔由原 5 分钟调整为 2 分钟。”

## 用户场景与测试 *(必填)*

### 用户故事 1 - 定时任务异步触发批量更新（优先级：P1）

运营或系统管理员配置 SchedulerX 任务后，任务按计划触发批量更新企微投诉链接。job 不等待所有 company 更新完成，只负责异步触发 SCRM 批处理接口并记录任务提交结果。

**优先级原因**：每个 company 更新可能耗时较长且存在 2 分钟间隔，job 同步等待会占用 SchedulerX 执行线程并增加超时风险。

**独立测试**：执行新增 job，模拟 SCRM Feign 调用可用，验证 `process` 提交异步调用后返回 `ProcessResult(true)`，且异步线程会调用 `batchUpdateWecomUser`。

**验收场景**：

1. **Given** SchedulerX 触发新增 job，**When** job 开始执行，**Then** job 记录开始日志并提交异步调用。
2. **Given** 异步调用提交成功，**When** job `process` 返回，**Then** 返回 `ProcessResult(true)`，不等待完整批处理完成。
3. **Given** 异步调用提交前发生异常，**When** job 捕获异常，**Then** 返回 `ProcessResult(false)` 并记录失败日志。
4. **Given** 异步线程内调用 SCRM 接口失败，**When** job 主流程已返回，**Then** 异步线程记录错误日志，不反向改变本次 job 返回值。

---

### 用户故事 2 - SCRM 接口批量处理全部投诉配置（优先级：P1）

SCRM 提供 `batchUpdateWecomUser` 接口，接口分页查询投诉配置，获取所有配置中的 company，并逐个触发企微用户投诉链接更新。

**优先级原因**：投诉链接配置分布在多个企微主体上，需要一次性补偿或刷新全部主体的企微名片扩展属性。

**独立测试**：模拟 `complaintFeign.configPage` 返回多页 `ComplaintConfigOutput`，验证接口使用 `pageSize=100` 从第 1 页开始翻页，收集全部非空 company 并逐个调用 `updateWecomUser`。

**验收场景**：

1. **Given** 投诉配置总数超过 100 条，**When** 调用 `batchUpdateWecomUser`，**Then** 接口按 `current/pageSize` 翻页处理全部分页。
2. **Given** 某条配置存在有效 `company`，**When** 批处理执行到该配置，**Then** 构造 `WecomUserUpdateInput.company` 并调用 `complaintFeign::updateWecomUser`。
3. **Given** 某条配置的 `company` 为空，**When** 批处理执行到该配置，**Then** 跳过该配置且不调用 `updateWecomUser`。
4. **Given** 当前页 `records` 为空或分页结果为空，**When** 接口处理分页结果，**Then** 不抛异常并结束或继续按分页元数据判断。

---

### 用户故事 3 - 批量更新过程可通过日志追踪（优先级：P1）

批处理执行过程中，日志必须清楚记录当前正在更新的 company 和整体进度，便于排查长时间任务的执行位置和失败主体。

**优先级原因**：相邻 company 间隔 2 分钟，完整任务可能持续很久。没有进度日志时，很难判断任务是否仍在执行、卡在哪个主体、是否已经处理完。

**独立测试**：构造 3 个有效 company，验证每次调用 `updateWecomUser` 前输出 `更新伪投诉连接地址,company={}` 和 `更新进度{}/{}`，进度分别为 `1/3`、`2/3`、`3/3`。

**验收场景**：

1. **Given** 有效 company 列表总数为 N，**When** 执行第 i 个 company，**Then** 日志包含 `更新进度{i}/{N}`。
2. **Given** 批处理准备更新某个 company，**When** 调用 `updateWecomUser` 前，**Then** 日志包含 `更新伪投诉连接地址,company={}`，参数为当前 company。
3. **Given** 某个 company 更新失败，**When** 捕获异常，**Then** 错误日志包含 company 和当前进度，便于继续定位。
4. **Given** 存在多个有效 company，**When** 相邻两个 company 都需要调用 `updateWecomUser`，**Then** 两次调用之间间隔 2 分钟。

## 边界情况

- SchedulerX job 重复触发，上一轮异步批处理尚未完成。
- SCRM Feign 调用提交前失败。
- SCRM Feign 调用已提交，但异步线程内部失败。
- `complaintFeign.configPage` 返回 `null`、返回失败响应、返回空分页、`records` 为空。
- `Page.pages`、`Page.total` 与实际 `records` 不一致。
- 某页存在 `ComplaintConfigOutput` 为空或 `company` 为空。
- 多页数据中存在重复 company。
- `complaintFeign.updateWecomUser` 单个 company 调用失败。
- 批处理过程中线程被中断或服务停止。
- company 总数为 0。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `kkhc-bizcenter/schedule` 新增 SchedulerX job，继承 `JavaProcessor`。
- **FR-002**：新增 job MUST 参考 `IncreaseAbPlanStatusChangeJob` 的结构，记录开始、成功、失败日志并返回 `ProcessResult`。
- **FR-003**：新增 job MUST 通过异步线程调用 SCRM `batchUpdateWecomUser` 接口。
- **FR-004**：异步任务提交成功后，job MUST 返回 `ProcessResult(true)`，不得等待完整批处理完成。
- **FR-005**：异步任务提交前发生异常时，job MUST 返回 `ProcessResult(false)` 并记录异常。
- **FR-006**：异步线程内部调用失败时，系统 MUST 记录错误日志，日志包含接口名或 job 名。
- **FR-007**：系统 MUST 在 schedule 侧新增 Feign 接口方法，用于调用 SCRM 的 `batchUpdateWecomUser`。
- **FR-008**：系统 MUST 在 `ComplaintController` 新增接口方法 `batchUpdateWecomUser`。
- **FR-009**：`batchUpdateWecomUser` MUST 使用 `complaintFeign::configPage` 查询投诉配置分页数据。
- **FR-010**：分页查询 MUST 使用 `pageSize=100`，从 `current=1` 开始。
- **FR-011**：接口 MUST 按分页结果处理全部分页，不得只处理第一页。
- **FR-012**：接口 MUST 从 `ComplaintConfigOutput.company` 获取要更新的 company。
- **FR-013**：当 company 为空时，接口 MUST 跳过该记录，不得调用 `updateWecomUser`。
- **FR-014**：每个有效 company MUST 构造 `WecomUserUpdateInput`，设置 `company` 后调用 `complaintFeign::updateWecomUser`。
- **FR-015**：相邻两个有效 company 的 `updateWecomUser` 调用之间 MUST 间隔 2 分钟。
- **FR-016**：每次调用 `updateWecomUser` 前，系统 MUST 打印日志：`更新伪投诉连接地址,company={}`。
- **FR-017**：每次调用 `updateWecomUser` 前或执行时，系统 MUST 打印日志：`更新进度{}/{}`，前者为当前正在执行的 1-based index，后者为有效 company 总数。
- **FR-018**：单个 company 更新失败时，接口 SHOULD 记录错误并继续处理后续 company，避免一个主体失败阻断整批任务。
- **FR-019**：实现阶段 MUST 不新增数据库表、配置项或公共 DTO。
- **FR-020**：实现阶段 MUST 复用现有 `ComplaintConfigSearchInput`、`ComplaintConfigOutput`、`WecomUserUpdateInput` 和 `Page`。
- **FR-021**：Spec Kit 文档阶段 MUST 不修改 Java 业务代码；实现阶段 MUST 将业务代码变更限制在 `schedule` 与 `scrm` 范围内。

## 成功标准 *(必填)*

### 可衡量结果

- **SC-001**：SchedulerX job 执行时 100% 通过异步线程触发 SCRM `batchUpdateWecomUser`。
- **SC-002**：异步任务提交成功时，job 不等待批处理完成即可返回成功。
- **SC-003**：`batchUpdateWecomUser` 使用 `current=1,pageSize=100` 开始分页，并处理全部分页中的有效 company。
- **SC-004**：有效 company 100% 调用 `complaintFeign::updateWecomUser`，空 company 100% 跳过。
- **SC-005**：多 company 场景下，相邻有效 company 调用间隔为 2 分钟。
- **SC-006**：每个有效 company 调用前均输出 company 日志和 `index/total` 进度日志。
- **SC-007**：单个 company 更新失败时，日志包含失败 company 与进度，后续 company 仍可继续处理。
- **SC-008**：实现完成后可通过 `mvn -pl schedule,scrm -am -DskipTests compile` 编译验证。
- **SC-009**：实现阶段不得新增数据库表、配置项或公共 DTO，代码变更范围限定在 `schedule` 与 `scrm`。

## 假设

- schedule 服务已启用异步能力，并可使用现有线程池或 `CompletableFuture` 提交异步调用。
- SCRM Controller 的基础路径为 `complaint`，新增接口路径按现有 Controller 风格定义。
- schedule 侧 Feign 能访问 SCRM 服务对应接口。
- `ComplaintConfigSearchInput.current` 表示页码，`pageSize` 表示每页数量。
- `Page<ComplaintConfigOutput>.records` 是当前页配置列表，`pages` 可用于判断总页数。
- `ComplaintConfigOutput.company` 是 `updateWecomUser` 唯一必需入参。
- `complaintFeign.updateWecomUser` 已能完成单个 company 的企微用户投诉链接更新。
- Spec Kit 文档阶段已完成；本轮实现阶段修改范围限定为 `schedule` 与 `scrm` 代码。
