# 功能规格：员工密码 MD5 回填接口

**功能目录**：`057-kk-emp-password-md5-backfill`  
**创建日期**：`2026-06-08`  
**状态**：Implementation  
**输入**：在 `PhoneSecurityBackfillAdminController` 增加接口，更新 `drh_kk_emp` 和 `drh_kk_one_emp` 的 `password` 字段；如果不是 MD5 值就更新成 MD5。

## 背景

- 当前问题：两张员工表的 `password` 字段存在历史明文或非 MD5 值，需要后台接口统一回填。
- 当前行为：`PhoneSecurityBackfillAdminController` 只提供手机号安全字段历史回填的 `start/status` 接口。
- 目标行为：新增一个同步后台接口，只处理 `drh_kk_emp.password` 和 `drh_kk_one_emp.password`，将非 MD5 密码更新为 `DefaultPhoneSecurityEncryptClient` 调用 FC 后返回的加盐 `md5`。
- 非目标：不修改登录校验、密码重置、ERP 独立密码表、手机号安全字段回填流程或其他表。

## 用户场景与测试

### 用户故事 1 - 后台触发员工密码 MD5 回填（优先级：P1）

后台运维通过受保护接口触发一次回填，系统更新两张员工表中尚非 MD5 的密码，并返回每张表的选中、FC 加密、失败和更新行数。

**独立测试**：mock `JdbcTemplate` 和 `PhoneSecurityEncryptClient` 调用服务方法，断言两张固定表均执行候选查询和并发保护更新 SQL，且响应汇总统计正确。

**验收场景**：

1. **Given** `drh_kk_emp.password` 存在非空且非 32 位十六进制值，**When** 调用 `POST /admin/phone-security-backfill/emp-password-md5`，**Then** 使用数据库原始 `password` 调用 `PhoneSecurityEncryptClient.encryptPhone(password)`，并将返回结果中的 `md5` 写回该字段。
2. **Given** `drh_kk_one_emp.password` 已是 32 位十六进制 MD5，**When** 调用接口，**Then** 该行不更新。
3. **Given** 密码为 `NULL`、空字符串或纯空白，**When** 调用接口，**Then** 该行不更新。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - 表名：服务内固定白名单 `drh_kk_emp`、`drh_kk_one_emp`；执行 SQL 前固定生成；不来自请求。
  - 字段名：服务内固定 `password`；执行 SQL 前固定生成；不来自请求。
  - MD5 判断：SQL 正则 `^[0-9a-fA-F]{32}$`；候选查询时由数据库判断。
  - MD5 来源：服务逐行调用 `PhoneSecurityEncryptClient.encryptPhone(password)`；运行时实现为 `DefaultPhoneSecurityEncryptClient` 调用 FC `DataSecurity/DataSecurity-test`，只取返回的 `md5`。
- 下游读取字段清单：
  - `PhoneSecurityBackfillService.backfillEmpPasswordMd5()` 只读取固定目标的 `id` 和 `password` 字段；FC 返回的 `mask/aes` 忽略。
- 空对象 / 占位对象风险：
  - 无空 DTO、空 JSON 或空 Map 下传；响应 DTO 由服务方法按执行结果构建。
- 调用顺序风险：
  - 接口同步执行两张表回填后再返回；批内复用现有 `MAX_FC_CONCURRENCY=4` 的 FC 并发池等待结果完成。
- 旧逻辑保持：
  - 原手机号安全字段回填的 `start/status`、线程池、FC 加密客户端和状态统计不变。
- 需要用户确认的设计选择：
  - 无。用户已确认目标控制器和实现计划。

## 边界情况

- `password IS NULL`：跳过。
- `TRIM(password) = ''`：跳过。
- `password REGEXP '^[0-9a-fA-F]{32}$'`：视为已是 MD5，跳过。
- 大写 MD5：视为已是 MD5，跳过。
- FC 返回空 `md5` 或抛异常：跳过该行并计入失败，不输出密码原值或 md5 结果。
- SQL 执行异常：按 Spring/JDBC 异常向上抛出，接口返回由现有框架处理。

## 需求

### 功能需求

- **FR-001**：系统 MUST 新增 `POST /admin/phone-security-backfill/emp-password-md5`。
- **FR-002**：系统 MUST 固定回填 `drh_kk_emp.password` 和 `drh_kk_one_emp.password`。
- **FR-003**：系统 MUST 仅更新非空、非空白且不匹配 32 位十六进制 MD5 的密码。
- **FR-004**：系统 MUST 返回每张表的选中、成功加密、失败、更新行数和汇总统计。
- **FR-005**：系统 MUST NOT 从请求读取表名、字段名或 SQL 条件。
- **FR-006**：系统 MUST NOT 在日志或响应中输出任何密码值。
- **FR-007**：系统 MUST 使用 `UPDATE <table> SET password = ? WHERE id = ? AND password = ?`，避免查询后密码被并发修改时覆盖新值。
- **FR-008**：单元测试 MUST 覆盖服务查询 SQL、FC 返回 md5 写入、失败统计和控制器响应包装。

## 成功标准

- **SC-001**：接口调用后，目标表非 MD5 密码被更新为 FC 返回的加盐 `md5`。
- **SC-002**：已是 32 位十六进制 MD5、`NULL`、空字符串和纯空白密码不更新。
- **SC-003**：原 `start/status` 接口行为不变。
- **SC-004**：指定单元测试通过。

## 假设

- “MD5 值”定义为完整匹配 `^[0-9a-fA-F]{32}$` 的字符串。
- `juzi-service` 运行时数据库连接指向需要回填的目标库。
- 目标数据库为 MySQL，支持 `REGEXP`。
- `DefaultPhoneSecurityEncryptClient.encryptPhone(...)` 入参本质为字符串数据，本次复用该方法计算 password 的加盐 `md5`。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成历史问题防漏分析和强制门禁检查。

### D002 - 实现记录

- 实现内容：新增 `PhoneSecurityPasswordBackfillResponse`；`PhoneSecurityBackfillService` 新增固定白名单密码 MD5 回填方法；`PhoneSecurityBackfillAdminController` 新增 `POST /admin/phone-security-backfill/emp-password-md5`；新增服务和控制器单元测试。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=PhoneSecurityBackfillServicePasswordMd5Test,PhoneSecurityBackfillAdminControllerTest" test`
- 测试结果：`Tests run: 2, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：表名和字段名均为服务内固定白名单；SQL 覆盖非空、非空白、非 MD5 判断；日志和响应不输出密码值；原手机号回填 `start/status` 未改动。

### D003 - 测试库数据备份记录

- 执行内容：使用 `database-sql-skill` 的测试库 profile `dev-mysql` 备份 `drh_kk_emp` 和 `drh_kk_one_emp` 数据。
- 只读查询：`kk-emp-password-backup-count.sql`、`kk-emp-backup-export-drh_kk_emp-json.sql`、`kk-emp-backup-export-drh_kk_one_emp-json.sql` 均已通过 `readonly` 分析后执行。
- 备份结果：`drh_kk_emp` 309 行，`drh_kk_one_emp` 239 行，共 548 行。
- 备份文件：`test-drh-kk-emp-password-backup-20260608.sql`。
- 自检结论：备份 SQL 只包含 `SET NAMES` 和 `INSERT`；未执行备份 SQL；临时 CSV/JSON 导出文件已清理。

### D004 - 纠正记录：FC 加盐 MD5

- 触发原因：用户确认 `password` 的 MD5 必须使用 `DefaultPhoneSecurityEncryptClient` 返回的加盐 `md5`，不能使用 MySQL `MD5(password)`。
- 修正内容：服务实现改为批量查询候选行，每批按 `id ASC LIMIT 300` 拉取；逐行调用 `PhoneSecurityEncryptClient.encryptPhone(password)`；仅当返回 `md5` 非空时使用 `UPDATE <table> SET password = ? WHERE id = ? AND password = ?` 写回；FC 空返回或异常计入失败。
- 兼容口径：已完整匹配 `^[0-9a-fA-F]{32}$` 的 `password` 继续跳过，避免二次处理。
- 响应统计：保留 `targetCount`、`totalUpdatedCount`、`startedAt`、`endedAt`、`tableResults`，新增总计和单表的 selected/encrypted/failed 统计。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=PhoneSecurityBackfillServicePasswordMd5Test,PhoneSecurityBackfillAdminControllerTest" test`
- 测试结果：`Tests run: 2, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：`emp-password-md5` 链路不使用 `MD5(` SQL；无用户可控表名或字段名；新增日志不输出密码原值或 md5 结果；原手机号回填 `start/status` 未改动。

### D005 - 测试库密码恢复记录

- 执行原因：用户要求代码完成后，使用前面备份的 SQL 将测试库两张员工表原密码还原，后续再通过新接口更新数据。
- 恢复范围：仅测试库 profile `dev-mysql`；仅更新 `drh_kk_emp.password` 和 `drh_kk_one_emp.password`。
- 恢复脚本：从 `test-drh-kk-emp-password-backup-20260608.sql` 解析生成 `restore-kk-emp-password-from-backup-20260608.sql`，只包含按 `id` 更新 `password` 的语句。
- 写入分析：`risk=dml`，`statements=550`，包含事务语句和 548 条密码更新语句。
- 执行命令：通过 `database-sql-skill` 使用 `dev-mysql` 执行恢复脚本，并显式携带 `--allow-write` 和用户确认说明。
- 执行结果：`affected_rows: 523`；少于 548 表示部分行执行前已与备份密码一致。
- 校验脚本：`verify-kk-emp-password-restored-20260608.sql`，只读风险 `risk=readonly`。
- 校验结果：`drh_kk_emp` 备份 309 行、缺失 0 行、密码不一致 0 行；`drh_kk_one_emp` 备份 239 行、缺失 0 行、密码不一致 0 行。
- 自检结论：测试库两张表密码已恢复到备份值；未触碰生产库；未还原或覆盖除 `password` 外的其他字段。
