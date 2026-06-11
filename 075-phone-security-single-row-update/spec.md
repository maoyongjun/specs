# 功能规格：手机号安全回填逐条写库

**功能目录**：`075-phone-security-single-row-update`  
**创建日期**：`2026-06-11`  
**状态**：Implemented  
**输入**：用户提供 `phone_security_backfill_target_failed target=drh_applet_user.phone` 日志，异常为 `BadSqlGrammarException` / `BatchUpdateException`，SQL 报错位置在第二条 `UPDATE drh_applet_user SET phone_mask...` 附近；生产 JDBC URL 确认存在 `rewriteBatchedStatements=true`。用户要求“修改代码改成单条写。并在 C:\workspace\ju-chat\specs 创建 spec-kit 文档。”

## 背景

- 当前问题：`PhoneSecurityBackfillService` 使用 `JdbcTemplate.batchUpdate(sql, BatchPreparedStatementSetter)` 写入 `*_mask / *_md5 / *_aes`。在 `rewriteBatchedStatements=true` 环境下，MySQL Connector/J 可能将多条 `UPDATE` 重写为多语句执行，当前数据库连接不接受后续 `UPDATE`，导致 SQL 语法错误。
- 当前行为：一个目标表字段的某个批次失败时，当前 target 记入 `failedTargets`，任务继续处理后续 target；已成功写入的前序批次不会自动回滚。
- 目标行为：手机号安全回填和同服务内员工密码 MD5 回填写库均改为逐条 `jdbcTemplate.update(...)`，避免触发 JDBC batch rewrite。
- 非目标：不修改生产 JDBC URL；不新增 `allowMultiQueries=true`；不修改 FC 加密请求、候选查询条件、target 清单、接口路径或明文下线服务 `PhonePlaintextRetirementService`。

## 用户场景与测试

### 用户故事 1 - 回填任务不再触发批量 UPDATE 重写（优先级：P1）

运维或开发在生产开启 `rewriteBatchedStatements=true` 的数据源上执行手机号安全回填时，任务应逐条写库，不再因为批量 UPDATE 被驱动重写为多语句而报 SQL 语法错误。

**独立测试**：运行 `PhoneSecurityBackfillServiceSingleUpdateTest`，断言普通手机号安全字段写库调用 `jdbcTemplate.update` 两次，且没有调用 `batchUpdate`。

**验收场景**：

1. **Given** `drh_applet_user.phone` 有两条已加密待更新记录，**When** 执行写库逻辑，**Then** 系统发起两次单条 `UPDATE`，每次只更新一个 `id`。
2. **Given** 数据源配置包含 `rewriteBatchedStatements=true`，**When** 执行普通手机号安全字段回填写库，**Then** 代码路径不调用 `JdbcTemplate.batchUpdate`。

### 用户故事 2 - 密码 MD5 回填写库行为同步规避 batch rewrite（优先级：P2）

同一服务内员工密码 MD5 回填也使用相同 JDBC batch 写法，应同步改为逐条写，避免后续在相同数据源配置下出现同类问题。

**独立测试**：运行 `PhoneSecurityBackfillServicePasswordMd5Test`，断言三条成功加密的密码记录分别调用 `jdbcTemplate.update`，且不调用 `batchUpdate`。

**验收场景**：

1. **Given** `drh_kk_emp` 有两条可回填密码记录且 `drh_kk_one_emp` 有一条可回填密码记录，**When** 执行密码 MD5 回填，**Then** 系统逐条执行三次 `UPDATE` 并累加更新数。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `mask/md5/aes`：来源 `DefaultPhoneSecurityEncryptClient.encryptPhone` 的 FC 返回结果；赋值时机为写库前构造 `SecurityUpdate`；下游读取位置为 `PhoneSecurityBackfillService.batchUpdate`。
  - `id`：来源 `queryBatch` 查询目标表主键；赋值时机为查询结果映射 `PhoneRecord`；下游读取位置为单条 `UPDATE WHERE id = ?`。
  - `password md5/originalPassword/id`：来源 `encryptPasswordRecord` 和候选查询；赋值时机为写库前构造 `PasswordUpdate`；下游读取位置为 `batchUpdatePassword`。
- 下游读取字段清单：
  - `batchUpdate` 读取 `SecurityUpdate.mask`、`SecurityUpdate.md5`、`SecurityUpdate.aes`、`SecurityUpdate.id`。
  - `batchUpdatePassword` 读取 `PasswordUpdate.md5`、`PasswordUpdate.id`、`PasswordUpdate.originalPassword`。
- 空对象 / 占位对象风险：
  - 无。只有 `isComplete(encryptResult)` 通过后才构造 `SecurityUpdate`；密码 MD5 只有 FC 返回非空 `md5` 时才构造 `PasswordUpdate`。
- 调用顺序风险：
  - 无调用后赋值风险；加密完成后先组装 update 对象，再执行写库。
- 旧逻辑保持：
  - 保持候选查询条件、掩码源值跳过、FC 并发、target 级异常捕获、日志 key、状态流转和更新数累加口径。
  - 密码 MD5 回填仍带 `AND password = ?` 乐观保护。
- 需要用户确认的设计选择：
  - 已确认：用户明确要求“改成单条写”。

## 边界情况

- `updates` 为空：返回 0，不执行 SQL。
- 单条 `UPDATE` 返回 0：该条不计入 updated，后续行为由当前循环继续处理。
- 单条 `UPDATE` 抛异常：保持旧行为，异常向上抛出，由 target 层捕获并记录失败 target。
- `rewriteBatchedStatements=true`：不再触发 `JdbcTemplate.batchUpdate`，规避批量 UPDATE 重写。

## 需求

- **FR-001**：系统 MUST 将普通手机号安全字段回填写库从 JDBC batch 改为逐条 `jdbcTemplate.update`。
- **FR-002**：系统 MUST 将同服务内密码 MD5 回填写库从 JDBC batch 改为逐条 `jdbcTemplate.update`。
- **FR-003**：系统 MUST NOT 新增 `allowMultiQueries=true` 依赖。
- **FR-004**：系统 MUST 保持原有 SQL 参数顺序和更新数累加语义。
- **FR-005**：单元测试 MUST 断言普通手机号安全字段和密码 MD5 回填不再调用 `JdbcTemplate.batchUpdate`。

## 成功标准

- **SC-001**：普通手机号安全字段回填写库路径对 N 条记录调用 N 次 `jdbcTemplate.update`。
- **SC-002**：密码 MD5 回填写库路径对 N 条记录调用 N 次 `jdbcTemplate.update`。
- **SC-003**：相关单元测试通过，且测试中覆盖 SQL 模板和参数顺序。
- **SC-004**：代码中 `PhoneSecurityBackfillService` 不再引用 `BatchPreparedStatementSetter`。

## 假设

- 生产报错由 MySQL Connector/J 在 `rewriteBatchedStatements=true` 下对批量 `UPDATE` 的重写行为触发。
- 单条写会降低数据库写入吞吐，但本次优先保证一次性回填任务稳定完成。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成历史问题防漏分析和强制门禁检查。

### D002 - 实现记录

- 普通手机号安全字段回填 `batchUpdate` 改为循环调用 `jdbcTemplate.update(sql, mask, md5, aes, id)`。
- 密码 MD5 回填 `batchUpdatePassword` 改为循环调用 `jdbcTemplate.update(sql, md5, id, originalPassword)`。
- 新增/更新测试：`PhoneSecurityBackfillServiceSingleUpdateTest`、`PhoneSecurityBackfillServicePasswordMd5Test`。
- 测试命令和结果见 D003。

### D003 - 验证记录

- 测试命令：`mvn '-Dtest=PhoneSecurityBackfillServiceSingleUpdateTest,PhoneSecurityBackfillServicePasswordMd5Test' -DskipTests=false test`
- 测试结果：`Tests run: 2, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 静态检查：`PhoneSecurityBackfillService.java` 中已无 `BatchPreparedStatementSetter`、`jdbcTemplate.batchUpdate`、`Statement.SUCCESS_NO_INFO` 残留。
