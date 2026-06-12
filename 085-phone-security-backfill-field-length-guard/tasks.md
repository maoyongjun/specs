# 任务清单：juzi-service 手机号安全字段回填超长保护

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于 `data-RC\juzi-service` 手机号安全字段回填链路。
  - 结论：用户日志 SQL 与 `PhoneSecurityBackfillService.batchUpdate()` 生成的单行 UPDATE 一致。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和测试落点。
  - 结论：入口为 `PhoneSecurityBackfillAdminController.start()` -> `PhoneSecurityBackfillService.start()` -> `runTarget()` -> `encryptRecord()` -> `batchUpdate()`；测试落点为 `src\test\java\com\drh\data\juzi\phonesecurity\`。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
  - 结论：源手机号来自目标业务表源列；`mask/md5/aes` 来自 FC；字段类型按既有规格为 `VARCHAR(32)/CHAR(32)/VARCHAR(255)`。
- [x] T004 确认配置来源、环境变量、Redis key、MQ topic/tag、Feign/FC/HTTP 调用或数据库表是否受影响。
  - 结论：不新增配置、Redis、MQ、Feign；FC 加密契约保持 `businessType=1,dataType=1`；数据库只保留原 UPDATE。
- [x] T005 确认已有旧逻辑中必须保持不变的过滤、幂等、异常处理、日志、延迟和 fallback。
  - 结论：保持 `PhoneSecurityTargets`、分页、线程池、接口和状态响应不变；保留源字段 `NOT LIKE '%*%'` 过滤。

**检查点**：T001-T005 已完成，允许进入实现。

## Phase 2：风险门禁

- [x] T006 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参。
  - 结论：无；风险点是 `SecurityUpdate` 目前只依赖非空判断，需增强语义校验。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段。
  - 结论：无。字段在 `encryptRecord()` 当前层生成后传给 `batchUpdate()`。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用。
  - 结论：需在构造 `SecurityUpdate` 前保证 `mask/md5/aes` 合法。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为。
  - 结论：只增加本地校验和单行 DB 异常隔离，不改变外部契约。
- [x] T010 对需要用户确认的业务语义变化做记录；未确认前不得实现该变化。
  - 结论：无待确认项；用户已明确不改表结构。
- [x] T011 为每个关键行为建立测试映射，至少覆盖正常路径、边界路径和不回归路径。
  - 映射：非法 FC 输出跳过 -> `PhoneSecurityBackfillServiceMaskGuardTest`；合法写入与单行异常隔离 -> `PhoneSecurityBackfillServiceSingleUpdateTest`。

**检查点**：T006-T011 已有明确结论。

## Phase 3：实现

- [x] T012 在 `PhoneSecurityBackfillService` 增加手机号、mask、md5、aes 校验方法。
- [x] T013 在 `encryptRecord()` 中使用校验结果构造 `SecurityUpdate`，非法输出返回 failure 并写 warn 日志。
- [x] T014 在 `batchUpdate()` 中按单行捕获 `DataAccessException`，当前行失败后继续。
- [x] T015 保持未声明的旧行为不变，不修改 `PhoneSecurityTargets`、Controller、响应 DTO、DDL。

## Phase 4：测试与验证

- [x] T016 新增或更新单元测试，覆盖关键行为。
- [x] T017 测试中断言非法 FC 输出不调用 UPDATE，合法输出 SQL 和参数不变。
- [x] T018 验证单行 DB 异常不阻断后续更新。
- [x] T019 运行目标测试命令并记录结果。
- [x] T020 搜索确认无 DDL 修改、无字段截断逻辑。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 085 规格文档，完成 Phase 1 代码事实确认与 Phase 2 风险门禁。
- 验证方式：搜索并阅读 `PhoneSecurityBackfillAdminController`、`PhoneSecurityBackfillService`、现有 phone-security 测试。
- 自检结论：满足强制门禁；本阶段未修改数据库结构。

### D002 - 实现记录

- 实现内容：`PhoneSecurityBackfillService` 增加源手机号 11 位数字校验、FC 输出 `mask/md5/aes` 长度与格式校验、MD5 小写归一；`batchUpdate()` 捕获单行 `DataAccessException` 并继续后续行。补充单元测试覆盖非法 FC 输出跳过、合法输出写入、单行 DB 异常继续处理。
- 测试命令：`mvn -pl juzi-service "-Dtest=PhoneSecurityBackfillServiceSingleUpdateTest,PhoneSecurityBackfillServiceMaskGuardTest" "-DskipTests=false" "-Dmaven.test.skip=false" test`
- 测试结果：`Tests run: 7, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：参数来源和赋值顺序已在构造 `SecurityUpdate` 前完成校验；旧接口、目标表清单、FC 契约和 DDL 均未修改；剩余风险为线上若存在其他独立入口生成相同 SQL，需要复用本校验策略。

### D003 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
