# 功能规格：员工密码重置管理页

**功能目录**：`093-juzi-service-emp-password-reset`  
**创建日期**：`2026-06-16`  
**状态**：Implementation  
**输入**：在 `data-RC/juzi-service` 增加管理页面，用于重置用户密码。`drh_kk_one_emp` 通过传入的 `id` 和 `user_name` 校验，如果找不到信息提示报错；校验通过后修改 `drh_kk_one_emp` 和 `drh_kk_emp`，其中 `drh_kk_emp` 通过 `emp_one_id` 查询传入的 `id`，把两表的 `password` 更新成 `715ae9db3eaa5a11e5095b63195b94be`。并且二次确认，提示「是否重置 name 为 xx 的密码为 123456789」。

## 背景

- 当前问题：缺少自助的员工密码重置入口，重置密码需要手工改库，风险高且无统一鉴权与确认流程。
- 当前行为：`juzi-service` 已有「配置中心首页」（`index.html`）+ 一组后台管理页（路由配置、作业点评配置、点评记录运维台等），统一由 `ConfigPageAuthInterceptor` 做密钥鉴权；`PhoneSecurityBackfillAdminController` + `PhoneSecurityBackfillService` 已用 `JdbcTemplate` 直接读写 `drh_kk_emp.password`、`drh_kk_one_emp.password`（见 057 规格），但没有「按单个员工重置密码」的页面或接口。
- 目标行为：新增「员工密码重置台」页面与一对后台接口。运维输入 `drh_kk_one_emp.id` 和 `user_name`，先校验员工存在，再二次确认，最后把两表 `password` 重置为固定加盐 MD5。
- 非目标：不修改登录校验逻辑、不调用 FC 计算 MD5、不处理 ERP 独立密码表、不批量重置、不新增数据库表、不改既有手机号安全字段回填与其它管理页。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 校验员工是否存在（优先级：P1）

运维打开「员工密码重置台」，输入 `id` 和 `user_name`，点击「校验」。系统按 `id` + `user_name` 查询 `drh_kk_one_emp`：命中则展示 `user_name` 与将受影响的 `drh_kk_emp` 行数，并放开「重置密码」按钮；查不到则提示「未找到员工信息」，不放开重置按钮，也不写库。

**独立测试**：mock `JdbcTemplate`，对 `validate(id, userName)` 断言只执行 `SELECT ... FROM drh_kk_one_emp WHERE id = ? AND user_name = ?`（命中/未命中两种），未命中时 `found=false` 且不触发任何 `update`。

**验收场景**：

1. **Given** `drh_kk_one_emp` 存在 `id=1001`、`user_name='zhangsan'` 的行，**When** 调用 `POST /admin/emp-password-reset/validate` 传 `{id:1001, userName:'zhangsan'}`，**Then** 返回 `found=true`、`userName='zhangsan'`、`kkEmpCount=`（`drh_kk_emp` 中 `emp_one_id=1001` 的行数），不更新任何数据。
2. **Given** `drh_kk_one_emp` 不存在该 `id`+`user_name` 组合，**When** 调用校验接口，**Then** 返回 `found=false`、`message` 提示未找到员工信息，不更新任何数据。
3. **Given** `id` 为空或非数字、或 `user_name` 为空，**When** 调用校验接口，**Then** 返回 `logicError`（参数校验失败），不查询、不更新。

### 用户故事 2 - 二次确认后重置密码（优先级：P1）

校验命中后，运维点击「重置密码」，前端弹出确认框「是否重置 name 为 xx 的密码为 123456789？」（xx 为校验返回的 `user_name`）。确认后调用重置接口；服务端重新校验员工存在后，把 `drh_kk_one_emp`（`id`+`user_name` 命中行）和 `drh_kk_emp`（`emp_one_id=id` 的所有行）的 `password` 更新为 `715ae9db3eaa5a11e5095b63195b94be`，返回两表更新行数。

**独立测试**：mock `JdbcTemplate`，对 `reset(id, userName)` 断言：先 `SELECT ... drh_kk_one_emp WHERE id=? AND user_name=?` 命中，再 `UPDATE drh_kk_one_emp SET password=? WHERE id=? AND user_name=?` 和 `UPDATE drh_kk_emp SET password=? WHERE emp_one_id=?`，且 `password` 绑定参数等于固定常量 `715ae9db3eaa5a11e5095b63195b94be`、`id`/`userName`/`emp_one_id` 绑定正确。

**验收场景**：

1. **Given** 员工存在且 `drh_kk_emp` 有 2 条 `emp_one_id=1001`，**When** 调用 `POST /admin/emp-password-reset/reset` 传 `{id:1001, userName:'zhangsan'}`，**Then** `drh_kk_one_emp` 更新 1 行、`drh_kk_emp` 更新 2 行，两表新 `password` 均为固定常量。
2. **Given** 员工不存在（`id`+`user_name` 未命中），**When** 调用重置接口，**Then** 返回 `logicError`「未找到员工信息」，两表均不更新。
3. **Given** 前端确认框被取消，**When** 运维点「取消」，**Then** 不发起重置请求。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `id`：来源 请求体 `EmpPasswordResetRequest.id`（`Long`）；在 `validate`/`reset` 入口校验非空且 > 0；下游用于 `drh_kk_one_emp` 的 `id = ?` 和 `drh_kk_emp` 的 `emp_one_id = ?`。
  - `userName`：来源 请求体 `EmpPasswordResetRequest.userName`（`String`）；入口校验非空（trim 后非空）；下游用于 `drh_kk_one_emp` 的 `user_name = ?`。
  - `password`（新值）：服务内固定常量 `RESET_PASSWORD_MD5 = "715ae9db3eaa5a11e5095b63195b94be"`；在执行 UPDATE 前已确定；不来自请求、不调用 FC。
  - 表名/列名：服务内固定常量（`drh_kk_one_emp`、`drh_kk_emp`、`password`、`user_name`、`emp_one_id`、`id`）；执行 SQL 前固定生成；不来自请求。
- 下游读取字段清单：
  - `validate`：`SELECT id, user_name FROM drh_kk_one_emp WHERE id=? AND user_name=?`，读取 `id`、`user_name`；`SELECT COUNT(*) FROM drh_kk_emp WHERE emp_one_id=?` 读取计数。
  - `reset`：复用校验查询；`UPDATE drh_kk_one_emp SET password=? WHERE id=? AND user_name=?`；`UPDATE drh_kk_emp SET password=? WHERE emp_one_id=?`。
- 空对象 / 占位对象风险：
  - 无空 DTO / 空 JSON / 空 Map 下传；响应 DTO（`EmpPasswordResetValidateResponse`、`EmpPasswordResetResponse`）由服务方法按执行结果逐字段构建。
- 调用顺序风险：
  - `reset` 必须「先校验存在，再更新」；校验未命中直接返回 `logicError`，不进入更新。两条 UPDATE 顺序为先 `drh_kk_one_emp` 后 `drh_kk_emp`；非事务，依赖固定值的幂等性（见「边界情况」）。
- 旧逻辑保持：
  - 既有 `/admin/route-config/**`、`/admin/song-score-ops/**`、`/admin/phone-security-backfill/**` 等页面与接口、`ConfigPageAuthInterceptor` 既有规则、`PhoneSecurityBackfillService` 不变。
  - 新页面沿用既有专项密钥鉴权（`drh2026`）与首页密钥本地存储约定（`config_access_key_ops`）。
- 需要用户确认的设计选择：
  - 数据库写入两表 `password`：已由用户原始需求明确授权（指定表、列、定位字段与固定新值）。
  - 页面安全等级：因属敏感操作，登记为「专项页面」，使用专项密钥；前端二次 `confirm` 确认。属合理默认，已在文档说明。
  - 非事务实现：依赖固定值幂等，部分失败可重跑修复（见假设）；若后续要求强一致再评估引入事务。

## 边界情况

- `id` 为空 / 非数字 / `<= 0`：入口返回 `logicError`，不查询、不更新。
- `user_name` 为空或纯空白：入口返回 `logicError`，不查询、不更新。
- `drh_kk_one_emp` 未命中：`validate` 返回 `found=false`；`reset` 返回 `logicError`「未找到员工信息」，两表不更新。
- `drh_kk_emp` 无 `emp_one_id=id` 的行：`drh_kk_one_emp` 仍更新，`drh_kk_emp` 更新 0 行，接口正常返回（`kkEmpUpdatedCount=0`）。
- 同一 `emp_one_id` 对应多条 `drh_kk_emp`：全部更新，返回真实行数。
- 重复触发：固定密码值幂等，重复重置结果一致；`drh_kk_one_emp` 第二次更新行数仍为 1（值未变也按 `WHERE id=? AND user_name=?` 命中）。
- 部分失败（`drh_kk_one_emp` 成功、`drh_kk_emp` 抛 SQL 异常）：异常按 Spring/JDBC 向上抛出，接口返回错误；由于新值固定且幂等，运维重跑即可恢复一致。
- 并发修改：`drh_kk_one_emp` 更新带 `user_name` 条件，若期间 `user_name` 被改则更新 0 行并可被操作员从行数中察觉。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 新增管理页面 `static/reset-emp-password.html`，并在配置中心首页 `index.html` 增加入口卡片。
- **FR-002**：系统 MUST 新增 `POST /admin/emp-password-reset/validate`，按 `id` + `user_name` 校验 `drh_kk_one_emp`，命中返回 `found=true`、`userName`、关联 `drh_kk_emp` 行数；未命中返回 `found=false` 且不更新数据。
- **FR-003**：系统 MUST 新增 `POST /admin/emp-password-reset/reset`，服务端先按 `id` + `user_name` 重新校验存在，未命中返回 `logicError` 且不更新。
- **FR-004**：系统 MUST 在校验通过后，把 `drh_kk_one_emp.password`（`WHERE id=? AND user_name=?`）和 `drh_kk_emp.password`（`WHERE emp_one_id=?`）更新为固定常量 `715ae9db3eaa5a11e5095b63195b94be`，并返回两表更新行数。
- **FR-005**：系统 MUST NOT 从请求读取表名、列名、SQL 条件或新密码值；新密码为服务内固定常量。
- **FR-006**：系统 MUST 在前端执行重置前进行二次确认，提示文案包含「是否重置 name 为 xx 的密码为 123456789」，xx 为校验返回的 `user_name`；未确认不得发起重置请求。
- **FR-007**：新页面与接口 MUST 沿用既有后台鉴权（`ConfigPageAuthInterceptor` 专项密钥），并登记到 `WebConfig` 鉴权路径。
- **FR-008**：系统 MUST NOT 修改既有页面、接口、鉴权规则与 `PhoneSecurityBackfillService` 等无关逻辑。
- **FR-009**：日志 MUST NOT 输出密码值（含固定常量），只记录表名、列名、`id`、`userName` 与更新行数。
- **FR-010**：单元测试 MUST 覆盖校验命中/未命中、重置更新行数、下游 SQL 文本与绑定参数断言（含固定密码常量、`emp_one_id` 条件）、控制器响应包装。

## 成功标准 *(必填)*

- **SC-001**：输入存在的 `id`+`user_name`，校验返回命中并展示受影响 `drh_kk_emp` 行数；二次确认后两表 `password` 被更新为固定常量。
- **SC-002**：输入不存在的 `id`+`user_name`，校验提示未找到、重置被拒绝，两表均不更新。
- **SC-003**：`drh_kk_emp` 通过 `emp_one_id = 传入 id` 定位并可更新多行。
- **SC-004**：既有管理页、接口与鉴权行为不回归。
- **SC-005**：指定单元测试全部通过，且断言到下游 SQL 与参数内容。

## 假设

- DB 列命名为 snake_case：`drh_kk_one_emp(id, user_name, password)`、`drh_kk_emp(id, emp_one_id, password)`；与 057 规格、`KkEmpDto(emp_one_id)` 及 schema 文档一致。实现前在 Phase 1 通过 `database-sql-skill` 只读核对真实列名。
- `715ae9db3eaa5a11e5095b63195b94be` 为明文 `123456789` 经系统加盐方案得到的 MD5（非 MySQL 原生 `MD5('123456789')=25f9e794...`）；按需求作为固定字面量写入，不再二次计算。
- 注入的 `JdbcTemplate` 指向包含上述两表的主数据源（与 057 规格一致；项目仅有单一自动配置数据源）。
- 重置为固定值的操作是幂等的；非事务实现下部分失败可通过重跑恢复一致。
- 若上述任一假设被推翻，需要追加 Dxxx 纠正记录。

## 执行记录

### D001 - 文档记录

- 已基于 `_template` 创建本 Spec Kit 文档（AGENTS/spec/tasks/checklist）。
- 已完成历史问题防漏分析和强制门禁检查（参数来源、占位对象、调用顺序、下游字段、旧逻辑保持、影响范围、测试映射）。
- 本阶段已确认事实：管理页/鉴权链路（`ConfigPageAuthInterceptor`+`WebConfig`+`index.html`）、`BaseResponse` 约定、`JdbcTemplate` 单数据源、两表字段命名来源、`123456789` 非原生 MD5。

### D002 - 实现记录

- 实现内容：新增 `emppasswordreset` 包（请求/校验响应/重置响应 DTO、`EmpNotFoundException`、`EmpPasswordResetService`）、`EmpPasswordResetAdminController`（`POST /admin/emp-password-reset/validate`、`/reset`）、管理页 `static/reset-emp-password.html`；改 `WebConfig`、`ConfigPageAuthInterceptor`、`index.html` 接入鉴权与入口；新增两个单元测试类。
- 影响范围：新增一个后台鉴权下的接口与页面；数据库写入仅 `drh_kk_one_emp.password`（`WHERE id=? AND user_name=?`）与 `drh_kk_emp.password`（`WHERE emp_one_id=?`），新值为固定常量；既有页面/接口/鉴权仅新增注册项，未改既有逻辑。
- 测试命令：`mvn -pl juzi-service -am -DskipTests=false "-Dtest=EmpPasswordResetServiceTest,EmpPasswordResetAdminControllerTest" test`。
- 测试结果：Service `Tests run: 4`、Controller `Tests run: 5`，Failures/Errors/Skipped 全 0，模块编译通过。
- 自检结论：参数来源固定且调用前确定；`reset` 先校验后更新；下游 UPDATE 的 SQL 与绑定参数（固定密码常量、`id`/`userName`/`emp_one_id`）均有断言；日志不输出密码值；旧逻辑无回归。剩余风险：真实库列名/写入未在本环境核对与执行（运维阶段处理，见 tasks T023），非事务实现依赖固定值幂等。
- 状态更新：本规格状态从 Draft 推进为 Implementation（功能与单测完成；真实库写入属后续运维步骤）。

### D003 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
