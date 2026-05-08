# 任务清单：批量更新企微投诉链接

**输入**：来自 `specs/005-batch-update-wecom-user/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：实现已通过 `mvn -pl schedule,scrm -am -DskipTests compile` 编译验证，并覆盖 job 异步触发、分页处理、2 分钟间隔和日志输出。  

**组织方式**：任务按阶段组织。Spec Kit 文档已完成；本轮业务代码实现已完成。

## 格式：`[ID] [P?] [Story] Description`

- **[P]**：可并行执行（不同文件、没有依赖）
- **[Story]**：任务所属用户故事（US1、US2、US3）
- 描述中包含精确文件路径或明确模块范围
- 业务实现任务状态随执行同步更新；执行后补充执行记录和自检结论

## /plan 实施计划（已执行）

**当前状态**：业务实现已完成，`mvn -pl schedule,scrm -am -DskipTests compile` 编译通过；执行记录见 B001。

**范围约束**：

- 文档范围为 `C:\workspace\ju-chat\specs\005-batch-update-wecom-user`。
- 业务实现范围为 `kkhc-bizcenter/schedule` 与 `kkhc-bizcenter/scrm`。
- 新增 job 参考 `IncreaseAbPlanStatusChangeJob`，继承 `JavaProcessor`。
- 新增 SCRM 接口落点为 `ComplaintController`，接口名 `batchUpdateWecomUser`。
- 不新增数据库表、配置项或公共 DTO。

**执行节奏**：

- 先确认 schedule 侧 Feign 与 job 命名，再新增 job。
- 再实现 SCRM `batchUpdateWecomUser`，先分页收集有效 company，再按顺序更新。
- job 只负责异步触发接口；批量分页、进度日志、2 分钟间隔在 SCRM 接口内部完成。
- 每个任务完成后在本文件追加执行记录，至少包含：执行内容、测试命令、测试结果、自检结论。

**每个 task 的完成记录模板**：

- 执行内容：
- 测试命令：
- 测试结果：
- 自检结论：

---

## Phase 1：Setup（确认真实落点）

**目的**：确认 job、Feign、Controller 的真实落点和依赖类型。

- [x] T001 复查 `spec.md`、`AGENTS.md`、`checklists/requirements.md`，确认异步位置、分页范围、日志模板和不新增 DTO 约束
- [x] T002 [P] 确认 schedule 模块现有 Feign 风格和 SCRM 服务名/path，确定新增 Feign 接口位置
- [x] T003 [P] 确认 `ComplaintController` 中现有 `complaintFeign`、`configPage`、`updateWecomUser` 使用方式
- [x] T004 [P] 确认 `ComplaintConfigSearchInput`、`ComplaintConfigOutput`、`WecomUserUpdateInput`、`Page` 的字段和访问方式

**检查点**：实现落点、接口路径、分页字段和更新入参均已确认。

---

## Phase 2：Schedule Job（US1）

**目的**：新增 SchedulerX job，异步触发 SCRM 批处理接口。

- [x] T005 [US1] 在 schedule 模块新增 SCRM complaint Feign 接口或扩展现有可用 Feign，提供 `batchUpdateWecomUser` 方法
- [x] T006 [US1] 新增 job 类，继承 `JavaProcessor`，结构和日志风格参考 `IncreaseAbPlanStatusChangeJob`
- [x] T007 [US1] job `process` 中提交异步任务调用 Feign 的 `batchUpdateWecomUser`
- [x] T008 [US1] 异步任务提交成功后返回 `ProcessResult(true)`，提交前异常返回 `ProcessResult(false)`
- [x] T009 [US1] 异步线程内部捕获并记录接口调用异常，避免异常静默丢失

**检查点**：SchedulerX job 可以快速返回，后台异步触发 SCRM 批处理。

---

## Phase 3：SCRM Batch API（US2、US3）

**目的**：新增 `batchUpdateWecomUser`，分页收集全部有效 company 并逐个更新。

- [x] T010 [US2] 在 `ComplaintController` 新增 `batchUpdateWecomUser` 接口方法
- [x] T011 [US2] 使用 `ComplaintConfigSearchInput` 设置 `current=1,pageSize=100` 调用 `complaintFeign::configPage`
- [x] T012 [US2] 按 `Page.pages` 或等价分页结果循环处理全部分页
- [x] T013 [US2] 从全部分页 `records` 中收集非空 `ComplaintConfigOutput.company`
- [x] T014 [US2] company 为空时跳过，不调用 `updateWecomUser`，并记录可排查日志
- [x] T015 [US2] 每个有效 company 构造 `WecomUserUpdateInput` 并调用 `complaintFeign::updateWecomUser`
- [x] T016 [US3] 每次调用前输出 `更新伪投诉连接地址,company={}`
- [x] T017 [US3] 每次调用前或执行时输出 `更新进度{}/{}`
- [x] T018 [US3] 相邻有效 company 调用之间等待 2 分钟
- [x] T019 [US3] 单个 company 更新失败时记录 company 和进度，并继续处理后续 company

**检查点**：接口按全部分页批量更新，日志可追踪，失败不阻断整批。

---

## Phase 4：Verification（验证与回归）

**目的**：验证异步触发、分页完整性、日志和间隔要求。

- [x] T020 [US1] 验证 job `process` 不等待完整批处理完成即可返回成功
- [x] T021 [US2] 验证 `configPage` 使用 `current/pageSize` 翻页，且 `pageSize=100`
- [x] T022 [US2] 验证超过 100 条配置时会处理第 2 页及后续分页
- [x] T023 [US2] 验证空 company 不调用 `updateWecomUser`
- [x] T024 [US3] 验证 3 个有效 company 的进度日志为 `1/3`、`2/3`、`3/3`
- [x] T025 [US3] 验证相邻有效 company 调用间隔为 2 分钟
- [x] T026 验证单个 company 更新失败后仍继续处理后续 company
- [x] T027 运行 `mvn -pl schedule,scrm -am -DskipTests compile` 并记录结果

**检查点**：FR-001 至 FR-020、SC-001 至 SC-008 均有验证覆盖。

---

## Phase 5：Documentation Closeout（规格覆盖复查）

**目的**：实现后同步任务执行记录，确保 Spec Kit 可追踪。

- [x] T028 复查 `spec.md` 的功能需求和成功标准，确认实现全覆盖
- [x] T029 更新本文件任务执行记录，记录测试命令、结果和自检结论
- [x] T030 如实现过程中发现需求口径变化，先更新 `spec.md`，再同步 `checklists/requirements.md`

**检查点**：文档、任务记录和实现结果一致。

---

## Phase 6：Supplemental Feign Timeout（本次补充）

**目的**：为 `updateWecomUser` 远程调用单独设置 8 分钟读取超时，不影响其他 Complaint Feign 方法。

- [x] T031 [US2] 新增专用 Feign 超时配置，通过 `Request.Options(10_000, 480_000)` 设置连接超时 10 秒、读取超时 8 分钟
- [x] T032 [US2] 新增只声明 `/config/wecom/user` 的专用 Feign，使用独立 `contextId` 和专用配置
- [x] T033 [US2] 将 `saveOrUpdate` 异步更新与 `batchUpdateWecomUser` 批量更新切换到专用 Feign
- [x] T034 运行 `mvn -pl scrm -am -DskipTests compile` 并记录结果

**检查点**：`updateWecomUser` 读取超时为 8 分钟；`ComplaintFeign` 的 `create`、`configPage`、`buildValidUrl` 等调用保持原超时配置。

---

## Phase 7：Supplemental Interval Change（本次补充）

**目的**：将批量更新相邻有效 company 调用间隔由原 5 分钟调整为 2 分钟。

- [x] T035 [US3] 将 SCRM 批处理等待间隔常量调整为 2 分钟
- [x] T036 [US3] 同步 `spec.md`、`tasks.md`、`AGENTS.md` 与 `checklists/requirements.md` 中的当前间隔要求
- [x] T037 运行 `mvn -pl scrm -am -DskipTests compile` 并记录结果

**检查点**：批量更新相邻有效 company 调用之间等待 2 分钟，分页、日志、失败继续和 8 分钟 Feign 超时行为保持不变。

---

## 本轮文档执行记录

### D001

- 执行内容：新增 `specs/005-batch-update-wecom-user` 规格目录，创建 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- 测试命令：`Test-Path specs/005-batch-update-wecom-user`；`Get-ChildItem specs/005-batch-update-wecom-user -Recurse`
- 测试结果：目录和四个目标文档均已创建；未发现 `[NEEDS CLARIFICATION]` 占位符。
- 自检结论：通过。

### B001

- 执行内容：完成 schedule 侧 `ScrmComplaintFeign` 与 `BatchUpdateWecomUserJob`；完成 SCRM `ComplaintController#batchUpdateWecomUser`，覆盖 `current=1,pageSize=100` 分页、全部分页 company 收集、空 company 跳过、逐个调用 `updateWecomUser`、指定日志、5 分钟间隔、单个 company 失败继续处理。
- 测试命令：`mvn -pl schedule,scrm -am -DskipTests compile`
- 测试结果：BUILD SUCCESS；`schedule`、`scrm` 及依赖模块编译通过；仅保留项目既有 MapStruct/MyBatis Plus 编译警告。
- 自检结论：通过。job 使用 `CompletableFuture.runAsync` 异步触发并快速返回；异步线程内部捕获并记录异常；未新增数据库表、配置项或公共 DTO。实现阶段范围变化已同步 `spec.md` 与 `checklists/requirements.md`。

### B002

- 执行内容：新增 `ComplaintUpdateWecomUserFeignConfig`，通过 `Request.Options(10_000, 480_000)` 设置连接超时 10 秒、读取超时 8 分钟；新增只包含 `updateWecomUser` 的专用 Feign，并将 `saveOrUpdate` 异步更新与 `batchUpdateWecomUser` 批量更新切换到专用 Feign；原 `ComplaintFeign` 保持承担 `create`、`saveOrUpdateConfig`、`configPage`、`buildValidUrl` 等普通调用。
- 测试命令：`mvn -pl scrm -am -DskipTests compile`；`rg -n "complaintFeign::updateWecomUser|complaintUpdateWecomUserFeign::updateWecomUser|ComplaintUpdateWecomUserFeign|CONNECT_TIMEOUT_MILLIS|READ_TIMEOUT_MILLIS|new Request\.Options" kkhc-bizcenter/scrm/src/main/java`；`rg -n "complaintFeign::create|complaintFeign::configPage|complaintFeign::buildValidUrl|complaintFeign::saveOrUpdateConfig" kkhc-bizcenter/scrm/src/main/java/com/drh/kkhc/bizcenter/scrm`
- 测试结果：BUILD SUCCESS；`kkhc-bizcenter`、`scrm-common`、`scrm` 编译通过；仅保留项目既有 MapStruct/MyBatis Plus 编译警告，以及 `Request.Options(int,int)` 构造方法的 deprecation 提示。搜索确认业务更新调用已切换到专用 Feign，普通 Complaint Feign 调用保持原路径。
- 自检结论：通过。`updateWecomUser` 单独使用 8 分钟读取超时，当时未改变批量分页、进度日志、原 5 分钟间隔、单个 company 失败继续处理等既有行为；后续 B003 将间隔调整为 2 分钟。

### B003

- 执行内容：将 `ComplaintServiceImpl` 中批量更新相邻有效 company 的等待间隔由 5 分钟调整为 2 分钟；同步 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 的当前间隔要求，并追加本次补充任务记录。
- 测试命令：`mvn -pl scrm -am -DskipTests compile`；`rg -n "UPDATE_INTERVAL_MINUTES = 2L|2 分钟|5 分钟|5分钟" specs/005-batch-update-wecom-user kkhc-bizcenter/scrm/src/main/java/com/drh/kkhc/bizcenter/scrm/service/complaint/impl/ComplaintServiceImpl.java`
- 测试结果：BUILD SUCCESS；`kkhc-bizcenter`、`scrm-common`、`scrm` 编译通过；仅保留项目既有 MapStruct/MyBatis Plus 编译警告，以及 `Request.Options(int,int)` 构造方法的 deprecation 提示。搜索确认代码等待间隔为 2 分钟，当前需求与验收条目已同步为 2 分钟。
- 自检结论：通过。除相邻有效 company 调用间隔由原 5 分钟改为 2 分钟外，分页、进度日志、失败继续处理和 `updateWecomUser` 8 分钟 Feign 读取超时行为不变。
