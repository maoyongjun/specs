# 任务清单：员工密码重置管理页

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的单元测试，并断言下游 SQL 与参数。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认处于 `data-RC/juzi-service`、配置中心后台管理页链路。
- [x] T002 用代码搜索确认页面/接口落点：`static/*.html` + `controller/admin/*AdminController` + `JdbcTemplate` 服务，鉴权由 `ConfigPageAuthInterceptor` + `WebConfig` 提供；`index.html` 维护入口卡片与专项页面列表。
- [x] T003 确认关键参数：`id`、`userName` 来自请求体；新密码为固定常量；表名/列名固定；`drh_kk_emp` 通过 `emp_one_id` 关联 `drh_kk_one_emp.id`（参见 `KkEmpDto.emp_one_id`、057 规格）。
- [x] T004 确认配置/数据源：仅单一自动配置 `DataSource`，注入的 `JdbcTemplate` 指向含两表的主库（057 已验证）；不涉及 Redis/MQ/FC/Feign。
- [x] T005 确认必须保持不变的旧逻辑：既有 `/admin/**` 页面与接口、`ConfigPageAuthInterceptor` 现有规则、`PhoneSecurityBackfillService`、首页其它卡片。

**检查点**：T001-T005 已完成，进入实现。

## Phase 2：风险门禁

- [x] T006 占位传参检查：无 `new XxxDto()`/空 Map/空 JSON 占位；请求 DTO 字段在入口即校验，响应 DTO 按结果构建。
- [x] T007 调用后赋值检查：无「调用后才 set 但下游已读」字段；`reset` 严格「先校验后更新」。
- [x] T008 下游字段来源检查：UPDATE/SELECT 读取的 `password`（常量）、`id`、`user_name`、`emp_one_id` 均在调用前确定。
- [x] T009 影响范围检查：新增一个后台鉴权下的接口+页面；DB 写入仅限两表 `password`；改动 `WebConfig`/`ConfigPageAuthInterceptor`/`index.html` 仅为新增注册项，不动既有项。数据库写入已获用户授权。
- [x] T010 业务语义变化记录：数据库写入两表 `password` + 专项密钥 + 二次确认，均已在 `spec.md` 记录并获授权。
- [x] T011 测试映射：校验命中/未命中、重置更新行数、下游 SQL+参数断言、控制器响应包装，逐条建立测试。

**检查点**：T006-T011 均有结论，高风险点（DB 写入）已在 spec「历史问题防漏分析」记录。

## Phase 3：实现

- [x] T012 新增 DTO：`EmpPasswordResetRequest(id, userName)`、`EmpPasswordResetValidateResponse(found, id, userName, kkEmpCount, message)`、`EmpPasswordResetResponse(id, userName, oneEmpUpdatedCount, kkEmpUpdatedCount)`。
- [x] T013 新增 `EmpPasswordResetService`（注入 `JdbcTemplate`）：`validate(id, userName)` 只读校验 + 统计 `drh_kk_emp` 行数；`reset(id, userName)` 先校验后更新两表，新值用固定常量 `RESET_PASSWORD_MD5`；未命中抛 `EmpNotFoundException`。
- [x] T014 新增 `EmpPasswordResetAdminController`（`@RequestMapping("admin/emp-password-reset")`）：`POST validate`、`POST reset`，用 `BaseResponse.success/ logicError` 包装；入口做参数校验；捕获 `EmpNotFoundException` → logicError。
- [x] T015 新增页面 `static/reset-emp-password.html`：输入 `id`+`user_name`，「校验」→展示结果→「重置密码」二次 `confirm`「是否重置 name 为 xx 的密码为 123456789？」→调用 reset；沿用专项密钥（`config_access_key_ops`、`X-Config-Key`、`key` 参数）；编辑输入后失效重置按钮，强制重新校验。
- [x] T016 注册鉴权：`WebConfig` 增加 `/admin/emp-password-reset/**` 与 `/reset-emp-password.html`；`ConfigPageAuthInterceptor.isSpecialPage` 增加对应判断（专项密钥 `drh2026`）。
- [x] T017 首页接入：`index.html` 增加「员工密码重置台」卡片，并把 `reset-emp-password.html` 加入 `SPECIAL_PAGES`。
- [x] T018 同步规格文档：实现产生的口径变化回填到 `spec.md`/`tasks.md`/`AGENTS.md`/checklist。

## Phase 4：测试与验证

- [x] T019 新增 `EmpPasswordResetServiceTest`：断言 `validate` 命中/未命中 SQL 与参数、`drh_kk_emp` 计数 SQL；断言 `reset` 先校验后更新、两条 UPDATE 的 SQL 文本与绑定参数（固定常量、`id`/`userName`/`emp_one_id`）、未命中抛异常且不更新。
- [x] T020 新增 `EmpPasswordResetAdminControllerTest`：断言响应包装（命中 200、未命中 `logicError` 1000、参数非法 `logicError` 1000），并 `verify` 调用服务方法的入参；参数非法时不调用服务。
- [x] T021 不回归校验：`WebConfig`/`ConfigPageAuthInterceptor`/`index.html` 仅新增注册项，未改既有项；新密码常量仅出现在常量定义，日志语句不打印密码值。
- [x] T022 运行目标模块测试与编译：`mvn -pl juzi-service -am -DskipTests=false "-Dtest=EmpPasswordResetServiceTest,EmpPasswordResetAdminControllerTest" test`，结果 `Tests run: 4`（Service）+ `Tests run: 5`（Controller），Failures/Errors 均为 0，编译通过。
- [ ] T023 （运维阶段，未执行）通过 `database-sql-skill` 只读核对真实列名 `drh_kk_one_emp.user_name`、`drh_kk_emp.emp_one_id`；真实写库前在测试库备份两表 `password`（参考 057 备份/恢复记录）。本次仅完成功能与单元测试，未对真实库执行任何写入。

## 执行记录

### D001 - 文档记录

- 执行内容：创建并填写 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- 验证方式：代码搜索 + 阅读既有控制器/服务/页面/鉴权确认事实；Phase 1/2 门禁逐项确认。
- 自检结论：满足强制门禁；DB 写入已获用户授权并记录；进入实现阶段。

### D002 - 实现记录

- 实现内容：
  - 新增 `emppasswordreset` 包：`EmpPasswordResetRequest`、`EmpPasswordResetValidateResponse`、`EmpPasswordResetResponse`、`EmpNotFoundException`、`EmpPasswordResetService`。
  - 新增控制器 `controller/admin/EmpPasswordResetAdminController`（`POST validate`、`POST reset`）。
  - 新增页面 `static/reset-emp-password.html`（专项密钥页面，两步：校验 → 二次 confirm → 重置）。
  - 改 `config/WebConfig`（注册 `/admin/emp-password-reset/**`、`/reset-emp-password.html`）、`config/ConfigPageAuthInterceptor`（登记为专项页面）、`static/index.html`（卡片入口 + `SPECIAL_PAGES`）。
  - 新增测试 `EmpPasswordResetServiceTest`、`EmpPasswordResetAdminControllerTest`。
- 测试命令：`mvn -pl juzi-service -am -DskipTests=false "-Dtest=EmpPasswordResetServiceTest,EmpPasswordResetAdminControllerTest" test`。
- 测试结果：`EmpPasswordResetServiceTest` Tests run: 4，`EmpPasswordResetAdminControllerTest` Tests run: 5，Failures: 0，Errors: 0，Skipped: 0；模块编译通过。
- 自检结论：
  - 参数来源：`id`/`userName` 来自请求体并在控制器入口校验（id 正整数、userName 非空）；`password` 为服务内固定常量 `715ae9db3eaa5a11e5095b63195b94be`；表名/列名为固定常量。
  - 调用顺序：`reset` 严格「先 SELECT 校验，命中后才两条 UPDATE」；未命中抛 `EmpNotFoundException`，控制器转 logicError，不写库。
  - 下游断言：测试断言两条 UPDATE 的 SQL 文本（`drh_kk_one_emp`/`drh_kk_emp`、`SET password=?`、`WHERE id=? AND user_name=?` / `WHERE emp_one_id=?`）与绑定参数（固定常量、`id`、`userName`、`emp_one_id`），并断言无 `MD5(` SQL。
  - 旧逻辑保持：既有页面/接口/鉴权仅新增注册项；`PhoneSecurityBackfillService` 等未改动。
  - 剩余风险：真实库列名与写入未在本环境核对/执行（见 T023）；非事务实现，部分失败依赖固定值幂等重跑恢复。
- 自检结论：满足强制门禁。

### D003 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
