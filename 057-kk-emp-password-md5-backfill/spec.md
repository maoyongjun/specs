# 功能规格：员工密码 MD5 回填接口

**功能目录**：`057-kk-emp-password-md5-backfill`  
**创建日期**：`2026-06-08`  
**状态**：Implementation  
**输入**：在 `PhoneSecurityBackfillAdminController` 增加接口，更新 `drh_kk_emp` 和 `drh_kk_one_emp` 的 `password` 字段；如果不是 MD5 值就更新成 MD5。

## 背景

- 当前问题：两张员工表的 `password` 字段存在历史明文或非 MD5 值，需要后台接口统一回填。
- 当前行为：`PhoneSecurityBackfillAdminController` 只提供手机号安全字段历史回填的 `start/status` 接口。
- 目标行为：新增一个同步后台接口，只处理 `drh_kk_emp.password` 和 `drh_kk_one_emp.password`，将非 MD5 密码更新为 `MD5(password)`。
- 非目标：不修改登录校验、密码重置、ERP 独立密码表、手机号安全字段回填流程或其他表。

## 用户场景与测试

### 用户故事 1 - 后台触发员工密码 MD5 回填（优先级：P1）

后台运维通过受保护接口触发一次回填，系统更新两张员工表中尚非 MD5 的密码，并返回每张表的更新行数。

**独立测试**：mock `JdbcTemplate` 调用服务方法，断言两张固定表均执行更新 SQL，且响应汇总更新行数正确。

**验收场景**：

1. **Given** `drh_kk_emp.password` 存在非空且非 32 位十六进制值，**When** 调用 `POST /admin/phone-security-backfill/emp-password-md5`，**Then** 该字段更新为 MySQL `MD5(password)` 结果。
2. **Given** `drh_kk_one_emp.password` 已是 32 位十六进制 MD5，**When** 调用接口，**Then** 该行不更新。
3. **Given** 密码为 `NULL`、空字符串或纯空白，**When** 调用接口，**Then** 该行不更新。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - 表名：服务内固定白名单 `drh_kk_emp`、`drh_kk_one_emp`；执行 SQL 前固定生成；不来自请求。
  - 字段名：服务内固定 `password`；执行 SQL 前固定生成；不来自请求。
  - MD5 判断：SQL 正则 `^[0-9a-fA-F]{32}$`；执行更新时由数据库判断。
- 下游读取字段清单：
  - `PhoneSecurityBackfillService.backfillEmpPasswordMd5()` 只读取固定目标的 `password` 字段并在数据库内执行 `MD5(password)`。
- 空对象 / 占位对象风险：
  - 无空 DTO、空 JSON 或空 Map 下传；响应 DTO 由服务方法按执行结果构建。
- 调用顺序风险：
  - 无异步调用；接口同步执行两张表更新后再返回。
- 旧逻辑保持：
  - 原手机号安全字段回填的 `start/status`、线程池、FC 加密客户端和状态统计不变。
- 需要用户确认的设计选择：
  - 无。用户已确认目标控制器和实现计划。

## 边界情况

- `password IS NULL`：跳过。
- `TRIM(password) = ''`：跳过。
- `password REGEXP '^[0-9a-fA-F]{32}$'`：视为已是 MD5，跳过。
- 大写 MD5：视为已是 MD5，跳过。
- SQL 执行异常：按 Spring/JDBC 异常向上抛出，接口返回由现有框架处理。

## 需求

### 功能需求

- **FR-001**：系统 MUST 新增 `POST /admin/phone-security-backfill/emp-password-md5`。
- **FR-002**：系统 MUST 固定回填 `drh_kk_emp.password` 和 `drh_kk_one_emp.password`。
- **FR-003**：系统 MUST 仅更新非空、非空白且不匹配 32 位十六进制 MD5 的密码。
- **FR-004**：系统 MUST 返回每张表的更新行数和汇总更新行数。
- **FR-005**：系统 MUST NOT 从请求读取表名、字段名或 SQL 条件。
- **FR-006**：系统 MUST NOT 在日志或响应中输出任何密码值。
- **FR-007**：单元测试 MUST 覆盖服务 SQL 口径和控制器响应包装。

## 成功标准

- **SC-001**：接口调用后，目标表非 MD5 密码被更新为数据库 `MD5(password)`。
- **SC-002**：已是 32 位十六进制 MD5、`NULL`、空字符串和纯空白密码不更新。
- **SC-003**：原 `start/status` 接口行为不变。
- **SC-004**：指定单元测试通过。

## 假设

- “MD5 值”定义为完整匹配 `^[0-9a-fA-F]{32}$` 的字符串。
- `juzi-service` 运行时数据库连接指向需要回填的目标库。
- 目标数据库为 MySQL，支持内置 `MD5()` 和 `REGEXP`。

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
