# 任务清单：phone-security-region-refresh 增量天数过滤

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于哪个项目、模块和业务链路。
  - 结论：目标项目为 `data-RC\juzi-service`；业务链路为 `phone-security-region-refresh` 对 `drh_phone_security_region` 的历史手机号地区映射刷新。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和测试落点。
  - 结论：入口 `PhoneSecurityRegionRefreshAdminController.start()` 目前只接收 `dryRun`；核心扫描在 `PhoneSecurityRegionRefreshService.queryBatch()` 和 `countMissingSecurity()`；目标清单来自 `PhoneSecurityTargets.TARGETS`；测试落点为 `src\test\java\com\drh\data\juzi\phonesecurity`。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
  - 结论：`days` 为请求参数 `Integer`；`cutoffTime` 为任务启动时 `LocalDateTime`；`timeColumn` 为目标配置 `String`；JDBC 参数需按是否加时间条件动态构建。
- [x] T004 确认配置来源、环境变量、Redis key、MQ topic/tag、Feign/FC/HTTP 调用或数据库表是否受影响。
  - 结论：不新增配置、Redis、MQ、Feign 或 FC 契约；仅增加管理接口请求参数与两类 SELECT SQL 的可选时间条件。
- [x] T005 确认已有旧逻辑中必须保持不变的过滤、幂等、异常处理、日志、延迟和 fallback。
  - 结论：spec 083 的安全字段非空、region 预检、FC 解密、segment 查询、INSERT 幂等、dryRun、互斥、preflight 均保持不变。
- [x] T006 使用 `database-sql-skill` 对 `phone_security_region_refresh_target_stats.sql` 做 analyze 并在 `prod-mysql` 上只读查询目标行数和候选时间字段。
  - 结论：analyze 为 `readonly`；正式库查询结果保存到 `prod_target_stats.csv`；1 万行以上 22 个 target 均存在 `create_time`。

**检查点**：T001-T005 已完成；T006 执行后更新 D002。

## Phase 2：风险门禁

- [x] T007 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参。
  - 结论：无；新增字段为显式方法参数和响应 DTO 字段。
- [x] T008 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段。
  - 结论：`cutoffTime` 必须在 job 提交前计算并传入异步任务，不能在每个 target 内重新计算。
- [x] T009 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用。
  - 结论：`days` 来源请求；`cutoffTime` 当前层现算；`timeColumn` 来源目标配置；SQL 参数列表在调用 JDBC 前构建完成。
- [x] T010 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为。
  - 结论：接口契约新增可选参数和响应字段；数据库写入不变；异步模型不变；无 MQ/Redis/FC 新变化。
- [x] T011 对需要用户确认的业务语义变化做记录；未确认前不得实现该变化。
  - 结论：用户已在实施计划中确认参数名、空值语义、正数语义、非法值拒绝和小表可不筛选。
- [x] T012 为每个关键行为建立测试映射，至少覆盖正常路径、边界路径和不回归路径。
  - 测试映射：days 空值全量、days 正数有时间列、days 正数无时间列、missing-security 同步过滤、非法 days 拒绝、start/status 响应字段、旧 `BackfillTarget` 构造函数兼容。

**检查点**：T007-T012 已有明确结论。

## Phase 3：实现

- [x] T013 新增 `BackfillTarget.timeColumn` 可选字段和 7 参数构造函数，保留 6 参数构造函数。
- [x] T014 按正式库事实确认结果更新 `PhoneSecurityTargets` 中大表的时间列配置，小表保持空。
- [x] T015 修改 Controller、Service、StartResponse、StatusResponse，支持 `days/cutoffTime`。
- [x] T016 修改 region refresh 的 candidate scan 和 missing-security count SQL，统一时间过滤规则。
- [x] T017 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [x] T018 新增或更新单元测试，覆盖 days 过滤和兼容行为。
- [x] T019 测试中断言 SQL 字符串和 JDBC 参数内容，不只断言最终结果。
- [x] T020 运行 `mvn -pl juzi-service -DskipTests=false -Dtest=PhoneSecurityRegionRefresh*Test,PhoneSecurityBackfillService*Test test` 并记录结果。
- [x] T021 搜索确认未修改 backfill/retirement 行为，未引入 update-time 字段作为时间筛选。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 088 规格文档、任务清单、执行说明和只读统计 SQL。
- 验证方式：复查 083 baseline、Controller、Service、Target 和 DTO。
- 自检结论：文档已覆盖参数来源、调用顺序、旧逻辑保持和测试映射。

### D002 - 正式库事实确认

- SQL 分析：`Risk: readonly`。
- 正式库查询：`prod-mysql` 执行成功，结果输出到 `prod_target_stats.csv`。
- 分类结论：45 个 target 中 22 个 row_count >= 10000，候选时间字段均为 `create_time`；其余小表未配置时间过滤。

### D003 - 实现记录

- 实现内容：新增 `days/cutoffTime` 接口和状态字段；`BackfillTarget` 支持可选 `timeColumn`；大表 target 配置 `create_time`；region refresh 查询按有效 `days` 追加时间过滤。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=PhoneSecurityRegionRefresh*Test,PhoneSecurityBackfillService*Test" test`。
- 测试结果：`Tests run: 16, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：参数来源清晰，`cutoffTime` 在异步任务提交前固定，旧构造函数兼容，未引入更新时间字段作为筛选字段。

### D004 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
