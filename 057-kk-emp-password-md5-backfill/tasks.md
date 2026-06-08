# 任务清单：员工密码 MD5 回填接口

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充服务 SQL/FC 口径测试和控制器响应测试。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标项目为 `data-RC\juzi-service`。
- [x] T002 确认真实入口为 `PhoneSecurityBackfillAdminController`。
- [x] T003 确认现有回填服务使用 `JdbcTemplate`，适合新增固定 SQL 更新方法。
- [x] T004 确认 `/admin/phone-security-backfill/**` 已纳入后台鉴权拦截。
- [x] T005 确认现有手机号回填 `start/status` 必须保持不变。

## Phase 2：风险门禁

- [x] T006 确认无请求入参、无用户可控表名或字段名。
- [x] T007 确认接口同步执行，不依赖异步后续流程补齐结果。
- [x] T008 确认下游只读取固定 `id/password` 字段，使用 `PhoneSecurityEncryptClient.encryptPhone(password)` 返回的加盐 `md5` 写回。
- [x] T009 确认本次新增数据库写入，复用现有 FC 并发池，但不修改手机号回填 `start/status` 状态统计。
- [x] T010 确认无额外业务语义需要用户确认。
- [x] T011 测试映射：服务测试覆盖候选查询、FC 返回 md5 写入、失败统计和行数汇总，控制器测试覆盖响应包装。

## Phase 3：实现

- [x] T012 新增密码回填响应 DTO。
- [x] T013 在 `PhoneSecurityBackfillService` 增加固定白名单回填方法。
- [x] T014 在 `PhoneSecurityBackfillAdminController` 增加 POST 接口。
- [x] T015 保持原 `start/status` 行为不变。

## Phase 4：测试与验证

- [x] T016 新增 `PhoneSecurityBackfillServicePasswordMd5Test`。
- [x] T017 新增 `PhoneSecurityBackfillAdminControllerTest`。
- [x] T018 运行指定 Maven 测试命令。
- [x] T019 搜索确认没有新增密码明文日志、没有 `MD5(` SQL 或用户可控 SQL。

## 执行记录

### D001 - 文档记录

- 执行内容：创建规格文档、任务清单、执行说明和需求检查清单。
- 验证方式：静态检查文档字段和强制门禁。
- 自检结论：满足实现前门禁。

### D002 - 实现记录

- 实现内容：新增员工密码 MD5 回填响应 DTO、服务方法、控制器接口和两类单元测试。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=PhoneSecurityBackfillServicePasswordMd5Test,PhoneSecurityBackfillAdminControllerTest" test`
- 测试结果：`Tests run: 2, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：固定两张表和 `password` 字段；跳过 `NULL`、空白和 32 位十六进制 MD5；未新增密码值日志；原 `start/status` 不变。

### D003 - 测试库数据备份记录

- 执行内容：使用 `database-sql-skill` 连接测试库 profile `dev-mysql`，只读导出 `drh_kk_emp` 和 `drh_kk_one_emp` 数据。
- 分析命令：对 count SQL 和两份 JSON_OBJECT 导出 SQL 执行 `analyze`，风险均为 `readonly`。
- 导出结果：`drh_kk_emp` 309 行，`drh_kk_one_emp` 239 行，共 548 行。
- 输出文件：`test-drh-kk-emp-password-backup-20260608.sql`。
- 验证结果：备份 SQL 的 `analyze` 风险为 `dml`，仅用于恢复；未执行；破坏性语句静态搜索无命中；临时导出文件已清理。

### D004 - 纠正记录：FC 加盐 MD5

- 执行内容：按用户确认口径，将员工密码回填从 MySQL `MD5(password)` 改为逐行调用 `PhoneSecurityEncryptClient.encryptPhone(password)`，写回 FC 返回的加盐 `md5`。
- 实现细节：候选查询固定两张白名单表，过滤 `NULL`、空白和 32 位十六进制值；批量更新使用 `WHERE id = ? AND password = ?` 防止覆盖并发修改；FC 返回空 `md5` 或异常计入失败。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=PhoneSecurityBackfillServicePasswordMd5Test,PhoneSecurityBackfillAdminControllerTest" test`
- 测试结果：`Tests run: 2, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：新增链路无 `MD5(` SQL；日志不输出密码原值或 md5 结果；原 `start/status` 行为不变。

### D005 - 测试库密码恢复记录

- 执行内容：按用户要求，从前面备份 SQL 生成仅恢复 `password` 字段的恢复脚本，并使用 `database-sql-skill` 在测试库 profile `dev-mysql` 执行。
- 恢复脚本：`restore-kk-emp-password-from-backup-20260608.sql`。
- 风险分析：`risk=dml`，`statements=550`；用户已明确要求测试库还原密码，profile 允许写入。
- 执行结果：`affected_rows: 523`。
- 校验脚本：`verify-kk-emp-password-restored-20260608.sql`，风险 `readonly`。
- 校验结果：`drh_kk_emp` 309 行、缺失 0 行、密码不一致 0 行；`drh_kk_one_emp` 239 行、缺失 0 行、密码不一致 0 行。
- 自检结论：测试库密码已恢复到备份值；未触碰生产库；未更新其他字段。
