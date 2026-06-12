# 功能规格：juzi-service 手机号安全字段回填超长保护

**功能目录**：`085-phone-security-backfill-field-length-guard`  
**创建日期**：`2026-06-12`  
**状态**：Draft  
**输入**：在 `C:\workspace\ju-chat\specs` 创建 spec-kit 文档，解决 juzi-service 刷线上数据接口更新 `drh_applet_user.phone_mask/phone_md5/phone_aes` 时 `phone_mask` 字段超长报错；不要动表结构。日志：`DataIntegrityViolationException; SQL [UPDATE drh_applet_user SET phone_mask=?, phone_md5=?, phone_aes=? WHERE id=?]; Data too long for column 'phone_mask'`。

## 背景

- 当前问题：`admin/phone-security-backfill/start` 回填任务把 FC 返回的 `mask/md5/aes` 直接写入业务表安全字段；当 FC 返回异常内容、明文或其他超长值到 `mask` 时，会触发 `phone_mask VARCHAR(32)` 超长并中断处理。
- 当前行为：`PhoneSecurityBackfillService.encryptRecord()` 只判断三字段非空，`batchUpdate()` 直接逐行执行 UPDATE，未按目标列长度和字段语义做校验，也未隔离单行 DB 写入异常。
- 目标行为：写库前校验源手机号和 FC 返回字段；非法输出跳过并计入失败；单行 DB 异常只影响当前行，后续行继续处理。
- 非目标：不修改表结构，不截断字段，不新增接口，不改 `PhoneSecurityTargets`、FC 调用契约、分页策略或状态响应结构。

## 用户场景与测试 *(必填)*

### 用户故事 1 - FC 异常输出不写库（优先级：P1）

运维执行手机号安全字段回填时，如果 FC 返回的 `phone_mask` 超过数据库列长度或格式不符合掩码语义，系统跳过该行而不是把异常值写入数据库。

**独立测试**：mock `PhoneSecurityEncryptClient` 返回超长 `mask`、无星号 `mask`、非法 `md5`、超长 `aes`，断言不调用 `JdbcTemplate.update()`。

**验收场景**：

1. **Given** FC 返回 `mask` 长度超过 32，**When** 回填处理该记录，**Then** 不执行 UPDATE，记录 warn 日志，失败计数加 1。
2. **Given** FC 返回 `mask` 不含 `*` 或 `md5` 非 32 位 hex，**When** 回填处理该记录，**Then** 不执行 UPDATE。
3. **Given** FC 返回合法 `mask/md5/aes`，**When** 回填处理该记录，**Then** 按原 SQL 更新三列。

### 用户故事 2 - 单行数据库异常不阻塞后续（优先级：P1）

某一行因为线上脏数据或数据库约束异常更新失败时，回填任务继续处理同批或后续记录。

**独立测试**：mock 第一条 `JdbcTemplate.update()` 抛 `DataIntegrityViolationException`，第二条返回 1，断言方法返回成功更新数为 1 且第二条被调用。

**验收场景**：

1. **Given** 第一条 UPDATE 抛字段超长异常，**When** 同批还有第二条合法更新，**Then** 第一条计失败，第二条继续写入。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `sourcePhone`：来源 `queryBatch()` 扫描的目标表源列；进入 FC 前 trim，并要求非空、非掩码、合法 11 位手机号。
  - `mask`：来源 FC 返回 `PhoneSecurityEncryptResult.mask`；构造 `SecurityUpdate` 前要求非空、长度 `<=32`、包含 `*`。
  - `md5`：来源 FC 返回 `PhoneSecurityEncryptResult.md5`；构造 `SecurityUpdate` 前要求 32 位十六进制，写入前转小写。
  - `aes`：来源 FC 返回 `PhoneSecurityEncryptResult.aes`；构造 `SecurityUpdate` 前要求非空且长度 `<=255`。
- 下游读取字段清单：
  - `batchUpdate()` 读取 `SecurityUpdate.mask/md5/aes/id`，下游 SQL 为 `UPDATE <table> SET <maskColumn>=?, <md5Column>=?, <aesColumn>=? WHERE <idColumn>=?`。
- 空对象 / 占位对象风险：
  - 不允许构造字段不完整或字段非法的 `SecurityUpdate`；非法 FC 输出直接返回失败结果。
- 调用顺序风险：
  - 固定顺序为扫描源手机号 -> 源手机号校验 -> FC 加密 -> FC 输出校验 -> 构造 `SecurityUpdate` -> 单行 UPDATE；不存在调用后赋值。
- 旧逻辑保持：
  - 保持接口、目标表清单、分页、线程池、FC businessType/dataType、状态响应字段不变。
- 需要用户确认的设计选择：
  - 无。用户已明确“不动表结构”，因此采用跳过异常输出而非扩字段或截断。

## 边界情况

- 源手机号为空、含 `*`、不是 11 位数字：跳过，计失败，不调用 FC。
- FC 返回任一安全字段为空：跳过，计失败。
- FC 返回 `mask` 超 32、无 `*`、`md5` 非 32 位 hex、`aes` 超 255：跳过，计失败。
- `JdbcTemplate.update()` 单行抛 `DataAccessException`：记录 warn 日志，当前行失败，继续下一行。
- 其他非 DB 异常：沿用现有任务级异常处理。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在构造 `SecurityUpdate` 前校验源手机号是 11 位数字且不含 `*`。
- **FR-002**：系统 MUST 在构造 `SecurityUpdate` 前校验 `mask` 非空、长度 `<=32` 且包含 `*`。
- **FR-003**：系统 MUST 在构造 `SecurityUpdate` 前校验 `md5` 为 32 位 hex，并写入小写值。
- **FR-004**：系统 MUST 在构造 `SecurityUpdate` 前校验 `aes` 非空且长度 `<=255`。
- **FR-005**：系统 MUST NOT 截断 FC 返回字段，非法输出必须跳过。
- **FR-006**：`batchUpdate()` MUST 捕获单行 `DataAccessException`，继续处理后续行。
- **FR-007**：系统 MUST NOT 修改表结构、接口路径、响应结构、FC 调用契约和 `PhoneSecurityTargets`。
- **FR-008**：单元测试 MUST 覆盖非法 FC 输出跳过、合法输出写入、单行 DB 异常继续处理。

## 成功标准 *(必填)*

- **SC-001**：超长 `phone_mask` 不再进入 UPDATE 参数，线上不会再因同类 FC 异常输出触发 `phone_mask` 超长。
- **SC-002**：合法手机号安全字段仍能正常更新。
- **SC-003**：单行 UPDATE 失败不会阻断同批后续记录。
- **SC-004**：目标测试通过，静态检查确认无 DDL 变更。

## 假设

- `*_mask` 字段为 `VARCHAR(32)`，`*_md5` 为 `CHAR(32)`，`*_aes` 为 `VARCHAR(255)`，来自既有 phone-security 字段规格。
- 回填失败计数复用现有 `failedCount`，不新增状态字段。
- 真实触发接口为 `admin/phone-security-backfill/start`；如后续发现其他写同一 SQL 的入口，也应复用本规格的校验策略。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成代码事实确认和强制门禁分析。
- 本阶段未修改数据库结构。

### D002 - 实现记录

- 已实现 `PhoneSecurityBackfillService` 写库前字段保护：源手机号必须为 11 位数字且非掩码；FC 返回 `mask` 必须非空、长度 `<=32` 且包含 `*`；`md5` 必须为 32 位 hex 并写入小写；`aes` 必须非空且长度 `<=255`。
- 已实现 `batchUpdate()` 单行 DB 异常隔离：捕获 `DataAccessException` 后记录不含明文的 warn 日志，失败计入现有 `failedCount`，继续处理后续行。
- 已补充测试：非法 FC 输出不执行 UPDATE；合法 FC 输出继续写库且 MD5 小写归一；单行 `DataIntegrityViolationException` 后继续下一行。
- 验证命令：`mvn -pl juzi-service "-Dtest=PhoneSecurityBackfillServiceSingleUpdateTest,PhoneSecurityBackfillServiceMaskGuardTest" "-DskipTests=false" "-Dmaven.test.skip=false" test`
- 验证结果：`Tests run: 7, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。

### D003 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
