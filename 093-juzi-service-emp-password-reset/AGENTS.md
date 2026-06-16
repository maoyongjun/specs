# 规格执行说明

本目录是「员工密码重置管理页」的 Spec Kit 文档。实现必须按 `spec.md`、`tasks.md` 和 `checklists/requirements.md` 执行。

## 作用范围

- 规格目录：`C:\workspace\ju-chat\specs\093-juzi-service-emp-password-reset`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 新增页面：`data-RC\juzi-service\src\main\resources\static\reset-emp-password.html`
- 新增控制器：`data-RC\juzi-service\src\main\java\com\drh\data\juzi\controller\admin\EmpPasswordResetAdminController.java`
- 新增服务：`data-RC\juzi-service\src\main\java\com\drh\data\juzi\emppasswordreset\EmpPasswordResetService.java`
- 新增 DTO：`...\emppasswordreset\EmpPasswordResetRequest.java`、`EmpPasswordResetValidateResponse.java`、`EmpPasswordResetResponse.java`
- 需要改动的既有文件：
  - `...\config\WebConfig.java`（注册新页面与接口的鉴权路径）
  - `...\config\ConfigPageAuthInterceptor.java`（把新页面登记为「专项页面」，使用专项密钥）
  - `...\resources\static\index.html`（配置中心首页新增入口卡片，并把新页面登记为专项页面）

## 当前目标

- 在配置中心新增一个「员工密码重置台」管理页面，运维通过 `drh_kk_one_emp.id` 和 `user_name` 定位员工。
- 校验：按 `id` + `user_name` 查询 `drh_kk_one_emp`，查不到时返回明确报错，不执行任何更新。
- 校验通过后，把 `drh_kk_one_emp.password` 和 `drh_kk_emp.password` 重置为固定加盐 MD5 `715ae9db3eaa5a11e5095b63195b94be`（明文 `123456789` 对应的加盐 MD5）。其中 `drh_kk_emp` 通过 `emp_one_id = 传入的 id` 定位（一个主员工可对应多条 `drh_kk_emp`）。
- 二次确认：前端在执行重置前弹出确认框，提示「是否重置 name 为 xx 的密码为 123456789」，xx 为校验返回的 `user_name`；操作员确认后才调用重置接口。

## 固定实现口径

- 新增后台接口前缀固定为 `admin/emp-password-reset`：
  - `POST /admin/emp-password-reset/validate`：入参 `{ id, userName }`，只读校验，返回是否命中、`userName`、关联 `drh_kk_emp` 行数；不更新任何数据。
  - `POST /admin/emp-password-reset/reset`：入参 `{ id, userName }`，服务端先重新校验，命中后更新两表 `password`，返回两表更新行数。
- 重置目标固定为 `drh_kk_one_emp.password` 和 `drh_kk_emp.password`，表名、列名、过滤字段均为服务内固定常量，不允许调用方传入。
- 新密码值固定为常量 `715ae9db3eaa5a11e5095b63195b94be`，不调用 FC、不做任何动态计算、不读取请求体。
- `drh_kk_one_emp` 查询与更新都使用 `id = ?` AND `user_name = ?`；`drh_kk_emp` 更新使用 `WHERE emp_one_id = ?`。
- 校验查不到（`drh_kk_one_emp` 无匹配行）时，`validate` 返回 `found=false` 且 `reset` 返回 `logicError`，均不执行更新。
- 日志只允许记录表名、列名、`id`、`userName`、更新行数；按既有手机号/密码回填口径，不把密码值当作可打印明文，统一以「reset」描述，不记录密码原值或新值。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前已确认页面落点、鉴权链路、`JdbcTemplate` 数据源、表字段命名（snake_case）。
- 不允许把空对象、占位 DTO 或未赋值字段当成有效输入继续传递。
- 任何会改变调用顺序、接口契约、远程调用、MQ 字段、Redis key、数据库结构或外部行为的方案，实施前必须确认业务意图。本需求的数据库写入已由用户在原始需求中明确授权。
- 单元测试不能只验证最终结果；数据库写入必须断言下游 SQL 文本与绑定参数（表名、列名、`id`、`userName`、`emp_one_id`、固定密码常量）。

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：`id`、`userName` 来自请求体并在调用前校验；`password` 为服务内固定常量；表名/列名为固定常量。
- 赋值时机：无调用后才 set 的字段；UPDATE 读取的 `password`/`id`/`userName`/`emp_one_id` 均在调用前确定。
- 占位对象：无 `new XxxDto()`、空 Map、空 JSON 作为占位参数下传；响应 DTO 按执行结果构建。
- 下游读取：UPDATE/SELECT 读取字段全部有来源。
- 旧逻辑保持：既有 `/admin/**` 页面、鉴权、`PhoneSecurityBackfillService` 等不受影响；不复用、不修改它们的逻辑。
- 影响范围：新增一个只在后台鉴权下访问的接口与页面；数据库写入仅限两表 `password` 字段；不新增表、不改 MQ/Redis/对外 API 契约。
- 测试映射：校验命中/未命中、重置更新行数、下游 SQL 与参数断言、控制器响应包装，均有对应测试。

## 重点代码位置

- 入口（页面）：`static/reset-emp-password.html`
- 入口（接口）：`EmpPasswordResetAdminController#validate`、`#reset`
- 核心实现：`EmpPasswordResetService#validate`、`#reset`
- 鉴权：`ConfigPageAuthInterceptor`（专项密钥 `drh2026`）、`WebConfig#addInterceptors`
- 测试：`src/test/java/com/drh/data/juzi/emppasswordreset/EmpPasswordResetServiceTest.java`、`src/test/java/com/drh/data/juzi/controller/admin/EmpPasswordResetAdminControllerTest.java`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
