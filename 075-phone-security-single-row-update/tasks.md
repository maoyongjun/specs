# 任务清单：手机号安全回填逐条写库

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于 `data-RC/juzi-service` 的手机号安全回填链路。
- [x] T002 用代码搜索确认入口、调用链、核心实现类和测试落点：`PhoneSecurityBackfillService`、`PhoneSecurityBackfillServicePasswordMd5Test`。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型：`SecurityUpdate` 与 `PasswordUpdate` 均在写库前构造完成。
- [x] T004 确认配置来源：生产 JDBC URL 来源于 Nacos `juzi-service-config`，用户确认存在 `rewriteBatchedStatements=true`。
- [x] T005 确认已有旧逻辑中必须保持不变的过滤、幂等、异常处理、日志、延迟和 fallback。

**检查点**：T001-T005 已完成。

## Phase 2：风险门禁

- [x] T006 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参：无。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段：无。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用：已确认。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为：仅改变数据库写入方式，从 JDBC batch 改为逐条写。
- [x] T010 对需要用户确认的业务语义变化做记录：用户已明确要求改为单条写；无接口语义变化。
- [x] T011 为每个关键行为建立测试映射：普通手机号字段和密码 MD5 回填均有测试断言。

**检查点**：T006-T011 已完成。

## Phase 3：实现

- [x] T012 按规格实现最小范围改动。
- [x] T013 保持未声明的旧行为不变。
- [x] T014 对数据库写入参数增加可测试断言点。
- [x] T015 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 和 checklist。

## Phase 4：测试与验证

- [x] T016 新增或更新单元测试，覆盖关键行为。
- [x] T017 测试中断言关键下游参数内容，不只断言最终结果。
- [x] T018 验证边界情况和旧逻辑不回归：空 updates 逻辑保持；target 级异常处理保持。
- [x] T019 运行目标模块测试或编译命令，并记录结果。
- [x] T020 搜索确认没有残留旧调用、旧字段、旧日志或旧口径。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `075-phone-security-single-row-update` 规格文档。
- 验证方式：对照 `_template` 补齐 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 自检结论：需求、边界、风险门禁和测试映射已覆盖。

### D002 - 实现记录

- 实现内容：`PhoneSecurityBackfillService` 两处 JDBC batch 写库改为逐条 `jdbcTemplate.update`。
- 测试命令：`mvn '-Dtest=PhoneSecurityBackfillServiceSingleUpdateTest,PhoneSecurityBackfillServicePasswordMd5Test' -DskipTests=false test`。
- 测试结果：`Tests run: 2, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：参数来源、调用顺序和旧逻辑保持已确认。

### D003 - 验证记录

- 静态搜索确认 `PhoneSecurityBackfillService.java` 不再包含 `BatchPreparedStatementSetter`、`jdbcTemplate.batchUpdate`、`Statement.SUCCESS_NO_INFO`。
- `batchUpdate` 字样仅在测试中作为 `never()` 断言保留。
