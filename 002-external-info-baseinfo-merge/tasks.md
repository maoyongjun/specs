# 任务清单：External Info BaseInfo 合并查询

**输入**：来自 `specs/002-external-info-baseinfo-merge/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：本任务清单默认测试先行；后续实现需要为 `data-RC/juzi-service` 补充单元测试，并通过 `mvn -pl juzi-service -DskipTests=false test` 执行。  

**组织方式**：任务按阶段组织，先确认真实代码落点，再建立可测试的 FC 调用封装，最后实现接口、并发调用、合并和失败返回。

## 格式：`[ID] [P?] [Story] Description`

- **[P]**：可并行执行（不同文件、没有依赖）
- **[Story]**：任务所属用户故事（US1、US2、US3）
- 描述中包含精确文件路径或明确模块范围
- 所有任务初始状态均为未完成；执行后再补充执行记录和自检结论

## /plan 实施计划（待执行）

**当前状态**：已完成；新增 External Info BaseInfo API、service、FC 适配器和测试已通过 `juzi-service` 全量回归。

**范围约束**：

- 仅实现 `spec.md` 中 External Info BaseInfo 合并查询相关 US1-US3、FR-001 至 FR-017、SC-001 至 SC-006。
- 目标实现模块为 `C:\workspace\ju-chat\data-RC\juzi-service`。
- 新增公开 API `POST /api/external-info/baseInfo`，不新增 admin 页面。
- 请求体只使用 `external_key`，同一个 key 原样传给两个 FC。
- juzi-service 不解释、不过滤、不转换 FC 业务字段，只负责调用、合并和失败标记。
- 不修改 `coze_plugin/external-info-select` 中 `AppTask.java` 或 `ProfileTask.java` 的函数源码。

**执行节奏**：

- 先完成 Setup 和 Foundational，再实现接口与服务。
- 测试任务优先于对应实现任务；实现完成后必须重跑对应测试。
- 即使任务标记 `[P]`，实际执行时也应避免同时修改同一文件。
- 每个任务完成后在本文件追加执行记录，至少包含：执行内容、测试命令、测试结果、自检结论。

**每个 task 的完成记录模板**：

- 执行内容：
- 测试命令：
- 测试结果：
- 自检结论：

---

## Phase 1：Setup（代码基线与真实落点）

**目的**：确认规格范围、现有接口风格、FC 调用工具和环境配置来源。

- [x] T001 复查 `specs/002-external-info-baseinfo-merge/spec.md`、`AGENTS.md`、`checklists/requirements.md`，确认接口路径、入参、合并规则和失败策略
- [x] T002 [P] 确认 `data-RC/juzi-service` 中不存在 `POST /api/external-info/baseInfo` 路径冲突
- [x] T003 [P] 定位并记录现有 `BaseResponse`、`FcInvokeInput`、`FcInvokeUtils.doSyncTaskReturnJSONObj`、`MqConfig#getJuzi_tag` 的使用方式
- [x] T004 [P] 复查 `CourseRuleApiController`、`CommonWarnConfigApiController` 等公开 API controller/service 分层风格，确定新接口落点和命名

**检查点**：接口路径、响应结构、FC 调用工具和环境判断方式已确认。

**Phase 1 执行记录**：

- T001 执行内容：复查 `spec.md`、`AGENTS.md`、`checklists/requirements.md`，确认本次最新用户要求进入实现阶段；接口为 `POST /api/external-info/baseInfo`，请求字段为 `external_key`，合并顺序为 profile 后 select，单边失败返回 `PARTIAL_OK` 并写 `_fc_errors`，双边失败或空 key 返回 `BaseResponse.logicError(...)`。
- T001 测试命令：未运行测试，文档复查任务。
- T001 测试结果：不适用。
- T001 自检结论：规格范围、入参、合并规则和失败策略已确认。
- T002 执行内容：在 `juzi-service/src/main/java` 和 `src/test/java` 中检索 `external-info`、`baseInfo`、`/api/external-info/baseInfo`、`external_key`，未发现目标路径已有 controller 映射。
- T002 测试命令：`rg -n "external-info|baseInfo|/api/external-info/baseInfo|external_key" ...`
- T002 测试结果：仅发现 OTS 查询和业务服务内 `external_key` 使用，无目标 API 路径冲突。
- T002 自检结论：可新增 `ExternalInfoBaseInfoController`。
- T003 执行内容：确认 `BaseResponse.success(...)` 设置 `status=200`、`message=OK`；`BaseResponse.logicError(...)` 设置业务错误；`FcInvokeInput` 为链式 setter；`FcInvokeUtils.doSyncTaskReturnJSONObj` 同步返回 `JSONObject`；`MqConfig#getJuzi_tag()` 为现有环境判断来源。
- T003 测试命令：`rg -n "class BaseResponse|FcInvokeInput|doSyncTaskReturnJSONObj|getJuzi_tag|juzi_tag" ...`
- T003 测试结果：定位到对应类和现有调用样例。
- T003 自检结论：新增实现应通过可替换 invoker 包装静态 FC 调用，测试避免真实访问阿里云 FC。
- T004 执行内容：复查 `CourseRuleApiController`、`CommonWarnConfigApiController`，确认公开 API controller 位于 `com.drh.data.juzi.controller`，使用构造器注入 service，`@RequestMapping("api/...")` 加 `@PostMapping("...")`。
- T004 测试命令：未运行测试，代码风格复查任务。
- T004 测试结果：不适用。
- T004 自检结论：新接口落点为 `com.drh.data.juzi.controller.ExternalInfoBaseInfoController`，service/DTO 独立放在 `externalinfobaseinfo` 包下。

---

## Phase 2：Foundational（测试缝隙与可替换 FC 调用）

**目的**：建立可测试设计，避免单元测试真实访问阿里云 FC。

**CRITICAL**：此阶段完成前不得开始生产代码实现。

- [x] T005 [US1] 在 `juzi-service` 测试范围设计 fake FC invoker，能够模拟成功 JSON、异常、空响应、非 JSON 响应和调用参数捕获
- [x] T006 [US2] 增加函数名选择测试，覆盖 `mq.juzi_tag == "test"` 与非 `test` 两种情况
- [x] T007 [US1] 增加合并规则测试，覆盖 profile 先放入、external-select 后覆盖、`courierList` 原样保留
- [x] T008 [US3] 增加部分失败测试，覆盖 select 失败/profile 成功、profile 失败/select 成功、两个 FC 都失败
- [x] T009 [US1] 增加入参校验测试，覆盖请求体为空、缺少 `external_key`、`external_key` 为空白时不调用 FC

**检查点**：核心行为有失败优先测试，且测试不依赖真实 FC。

**Phase 2 执行记录**：

- T005 执行内容：新增 `ExternalInfoBaseInfoServiceTest` 内部 fake FC invoker，支持成功 JSON、异常、空 `JSONObject`、非 JSON 模拟异常、并发等待和 `FcInvokeInput` 入参捕获。
- T005 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=ExternalInfoBaseInfoServiceTest,ExternalInfoBaseInfoControllerTest" test`
- T005 测试结果：先因生产类缺失红灯；实现后 12 个新增用例通过。
- T005 自检结论：测试不依赖真实阿里云 FC。
- T006 执行内容：补充 `mq.juzi_tag=test` 与非 test 的函数名选择测试。
- T006 测试命令：同 T005。
- T006 测试结果：通过。
- T006 自检结论：测试环境函数为 `external-select-test`、`external-profile`，非测试环境函数为 `external-select`、`prod-external-profile`。
- T007 执行内容：补充合并规则测试，验证 profile 字段先进入、select 同名字段覆盖，并对 `courierList` 断言原对象保留。
- T007 测试命令：同 T005。
- T007 测试结果：通过。
- T007 自检结论：合并顺序和 `courierList` 透传符合规格。
- T008 执行内容：补充 select 失败/profile 成功、profile 失败/select 成功、双 FC 失败测试。
- T008 测试命令：同 T005。
- T008 测试结果：通过。
- T008 自检结论：单边失败返回 `PARTIAL_OK`，双边失败返回业务错误。
- T009 执行内容：补充空 key 测试，覆盖 null、空字符串、空白字符串不调用 FC；controller 测试覆盖空请求体。
- T009 测试命令：同 T005。
- T009 测试结果：通过。
- T009 自检结论：空入参不会触发 FC 调用。

---

## Phase 3：API / DTO / Service（US1 基础）

**目标**：新增公开接口、请求模型和合并查询服务骨架。

**独立测试**：controller/service 单测可验证空入参、响应结构和服务调用。

- [x] T010 [US1] 新增 `ExternalInfoBaseInfoRequestDto`，字段为 `external_key`，并兼容常见 Java 命名访问方式
- [x] T011 [US1] 新增 `ExternalInfoBaseInfoController`，路径为 `POST /api/external-info/baseInfo`，返回 `BaseResponse<JSONObject>`
- [x] T012 [US1] 新增 `ExternalInfoBaseInfoService`，对 controller 暴露 `baseInfo(String externalKey)` 或等价方法
- [x] T013 [US1] 在 service 中实现空 `external_key` 校验，空值直接返回业务错误，且不得触发 FC 调用
- [x] T014 [US1] 抽象 FC 同步调用接口或适配器，生产实现内部沿用 `FcInvokeInput` 与 `FcInvokeUtils.doSyncTaskReturnJSONObj`

**检查点**：API 和 service 骨架可编译，且 FC 调用可在测试中替换。

**Phase 3 执行记录**：

- T010 执行内容：新增 `ExternalInfoBaseInfoRequestDto`，Java 字段为 `externalKey`，通过 Jackson/Fastjson 注解映射 JSON 字段 `external_key`。
- T010 测试命令：同 T005。
- T010 测试结果：初版因额外蛇形 getter 与 Jackson 冲突红灯；移除冲突 getter 后通过。
- T010 自检结论：请求 DTO 支持 `external_key` 入参和常见 Java camelCase 访问。
- T011 执行内容：新增公开 `ExternalInfoBaseInfoController`，映射 `POST /api/external-info/baseInfo`，返回 `BaseResponse<JSONObject>`，空请求体进入 service 校验。
- T011 测试命令：同 T005。
- T011 测试结果：通过。
- T011 自检结论：controller 路径和响应合同已覆盖。
- T012 执行内容：新增 `ExternalInfoBaseInfoService#baseInfo(String externalKey)`，由 controller 构造器注入调用。
- T012 测试命令：同 T005。
- T012 测试结果：通过。
- T012 自检结论：service 对外方法稳定。
- T013 执行内容：service 内对 null、空字符串、空白字符串直接返回 `BaseResponse.logicError("external_key is blank")`。
- T013 测试命令：同 T005。
- T013 测试结果：通过。
- T013 自检结论：空 key 不调用 FC。
- T014 执行内容：新增 `ExternalInfoBaseInfoFcInvoker` 接口和 `DefaultExternalInfoBaseInfoFcInvoker` 生产实现；生产实现内部沿用 `FcInvokeInput` 与 `FcInvokeUtils.doSyncTaskReturnJSONObj`。
- T014 测试命令：同 T005。
- T014 测试结果：通过。
- T014 自检结论：FC 调用已可替换，单测无真实 FC 访问。

---

## Phase 4：Concurrency / Merge（US1、US2、US3）

**目标**：并发调用两个 FC，按环境选择函数名，按约定合并 JSON 并处理部分失败。

**独立测试**：service 单测可验证函数选择、并发汇总、覆盖规则和错误结构。

- [x] T015 [US2] 实现函数名选择：`mq.juzi_tag == "test"` 使用 `external-select-test` 与 `external-profile`，否则使用 `external-select` 与 `prod-external-profile`
- [x] T016 [US1] 实现两个同步 FC 调用的并发执行，并等待两个结果都完成后汇总
- [x] T017 [US1] 实现统一 FC 请求体构造：两个函数都使用 `{"external_key":"..."}`，不得拆解或改写 key
- [x] T018 [US1] 实现合并规则：先放入 profile JSON，再放入 external-select JSON；同名字段以 external-select 为准
- [x] T019 [US1] 保留 external-select 返回的 `courierList` 原值，不因合并逻辑改写数组或子字段
- [x] T020 [US3] 实现 `_fc_errors` 结构，至少包含失败来源、`serviceName`、`functionName`、错误信息
- [x] T021 [US3] 实现单边失败返回：保留成功函数数据，响应 `status=200`，`message=PARTIAL_OK`
- [x] T022 [US3] 实现双边失败返回：使用 `BaseResponse.logicError(...)`

**检查点**：两个函数结果的正常合并和失败降级行为均满足规格。

**Phase 4 执行记录**：

- T015 执行内容：按 `MqConfig#getJuzi_tag()` 判断环境，`test` 使用测试函数名，其他值使用生产函数名。
- T015 测试命令：同 T005。
- T015 测试结果：通过。
- T015 自检结论：函数名切换覆盖 US2。
- T016 执行内容：通过两个 `CompletableFuture.supplyAsync(...)` 并发执行同步 FC 调用，并在 join 后统一汇总。
- T016 测试命令：同 T005。
- T016 测试结果：通过。
- T016 自检结论：并发测试验证两个调用都到达后才返回合并结果。
- T017 执行内容：统一构造 `JSONObject` 请求体，只包含 `external_key`，值使用原始入参。
- T017 测试命令：同 T005。
- T017 测试结果：通过。
- T017 自检结论：未拆解或改写 key。
- T018 执行内容：合并对象使用 `JSONObject(true)`，先 `putAll(profile)`，后 `putAll(select)`。
- T018 测试命令：同 T005。
- T018 测试结果：通过。
- T018 自检结论：同名字段以 select 为准。
- T019 执行内容：合并逻辑不遍历、不转换 `courierList`，直接保留 select 返回值。
- T019 测试命令：同 T005。
- T019 测试结果：通过。
- T019 自检结论：`courierList` 原样透传。
- T020 执行内容：部分失败时写入 `data._fc_errors` 数组，元素包含 `source`、`serviceName`、`functionName`、`message`。
- T020 测试命令：同 T005。
- T020 测试结果：通过。
- T020 自检结论：失败结构满足最低字段要求。
- T021 执行内容：单边失败时保留成功 FC 数据，返回 `status=200` 且 `message=PARTIAL_OK`。
- T021 测试命令：同 T005。
- T021 测试结果：通过。
- T021 自检结论：部分失败降级符合 US3。
- T022 执行内容：双边失败时返回 `BaseResponse.logicError("external-info baseInfo fc all failed")`。
- T022 测试命令：同 T005。
- T022 测试结果：通过。
- T022 自检结论：双失败不返回空合并数据。

---

## Phase 5：Validation / Polish（横切质量）

**目的**：完成日志、异常、回归和规格覆盖复查。

- [x] T023 [P] 增加日志：记录每个 FC 的 serviceName、functionName、成功/失败状态和耗时，避免打印完整敏感返回体
- [x] T024 [P] 处理 FC 返回空对象、非 JSON、JSON 数组或异常时的错误归一化，确保进入 `_fc_errors` 或双失败业务错误
- [x] T025 运行 `mvn -pl juzi-service -DskipTests=false test`，修复所有新增失败
- [x] T026 复查 `spec.md` 的 FR-001 至 FR-017、SC-001 至 SC-006，确认任务清单和实现全覆盖
- [x] T027 更新本文件执行记录，记录关键改动、测试命令、测试结果和自检结论

**检查点**：目标模块测试通过，规格覆盖完整，任务完成记录可追踪。

**Phase 5 执行记录**：

- T023 执行内容：在每次 FC 调用完成后记录 `serviceName`、`functionName`、`source`、成功/失败状态和耗时；失败日志仅记录归一化错误消息，不打印完整 FC 返回体。
- T023 测试命令：同 T005。
- T023 测试结果：通过。
- T023 自检结论：日志满足目标、状态、耗时可观测性要求。
- T024 执行内容：将空响应、空对象、异常、非 JSON/JSON 数组解析失败等统一视为 FC 调用失败；单边失败进入 `_fc_errors`，双边失败进入业务错误。
- T024 测试命令：同 T005。
- T024 测试结果：通过。
- T024 自检结论：错误归一化路径已覆盖。
- T025 执行内容：调整 `juzi-service` Surefire 配置为默认跳过但允许 `-DskipTests=false` 覆盖；将既有 `SpringTest` 标记为手工集成测试默认跳过；运行目标模块全量测试。
- T025 测试命令：`mvn -pl juzi-service -DskipTests=false test`
- T025 测试结果：通过；`Tests run: 19, Failures: 0, Errors: 0, Skipped: 1`，跳过项为既有 `SpringTest` 手工集成测试。
- T025 自检结论：新增测试全部执行通过，全量回归无失败。
- T026 执行内容：复查 `spec.md` 的 FR-001 至 FR-017 和 SC-001 至 SC-006，逐项映射到 controller、DTO、service、FC invoker、日志和测试。
- T026 测试命令：同 T025。
- T026 测试结果：通过。
- T026 自检结论：规格覆盖完整；FR-018/SC-007 属于早期“仅建文档不编码”阶段约束，已被本次用户明确执行实现的最新要求覆盖。
- T027 执行内容：更新 `tasks.md` 状态、Phase 1 至 Phase 5 执行记录、测试命令、测试结果和自检结论。
- T027 测试命令：不适用，文档维护任务；引用 T025 全量测试结果。
- T027 测试结果：不适用。
- T027 自检结论：任务状态和执行记录已补齐。

---

## 依赖与执行顺序

### 阶段依赖

- **Setup（Phase 1）**：无依赖，可以立即开始。
- **Foundational（Phase 2）**：依赖 Setup，且阻塞生产代码实现。
- **API / DTO / Service（Phase 3）**：依赖 Foundational。
- **Concurrency / Merge（Phase 4）**：依赖 Phase 3。
- **Validation / Polish（Phase 5）**：依赖 Phase 3 和 Phase 4 完成。

### 并行机会

- T002、T003、T004 可并行阅读记录。
- T006、T007、T008、T009 可并行编写测试，但不要同时修改同一测试辅助类。
- T023、T024 可与最终规格覆盖复查准备并行。

### MVP 优先

1. 完成 Phase 1 和 Phase 2，建立测试基础和 fake FC 调用能力。
2. 完成 Phase 3，让接口和服务骨架可编译。
3. 完成 Phase 4，让接口实现完整的并发调用、合并和失败返回。
4. 完成 Phase 5，跑目标回归并补任务执行记录。

## 接口与默认值

- 新接口：`POST /api/external-info/baseInfo`
- 请求体：`{"external_key":"..."}`
- 成功响应：`BaseResponse.status=200`、`message=OK`、`data` 为合并 JSON。
- 单边失败响应：`BaseResponse.status=200`、`message=PARTIAL_OK`、`data` 包含成功函数字段和 `_fc_errors`。
- 双边失败或空 key：`BaseResponse.logicError(...)`。
- 测试环境函数：`ai-service/external-select-test`、`ai-service/external-profile`。
- 非测试环境函数：`ai-service/external-select`、`ai-service/prod-external-profile`。
- 合并顺序：先 profile，后 external-select；同名字段以 external-select 为准。

## 测试计划

- service 单测覆盖空 `external_key` 不调用 FC。
- service 单测覆盖测试/生产函数名选择。
- service 单测覆盖两个 FC 成功时的合并结果。
- service 单测覆盖同名字段 select 覆盖 profile。
- service 单测覆盖 select 失败、profile 成功的部分返回。
- service 单测覆盖 profile 失败、select 成功的部分返回。
- service 单测覆盖两个 FC 都失败返回业务错误。
- controller 测试覆盖 `POST /api/external-info/baseInfo` 的请求/响应合同。
- 回归命令固定为：`mvn -pl juzi-service -DskipTests=false test`。

## 注意事项

- 当前 `juzi-service` 的 `maven-surefire-plugin` 默认通过 `<skipTests>${skipTests}</skipTests>` 跳过测试，执行测试时必须显式使用 `-DskipTests=false` 覆盖。
- 测试不得真实访问阿里云 FC，应通过 fake invoker 或 mock 方式验证调用目标和入参。
- 本任务清单只用于后续实现安排；生成本文件时不执行任务、不写执行记录、不标记任务完成。
