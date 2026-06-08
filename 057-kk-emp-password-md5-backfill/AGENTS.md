# 规格执行说明

本目录是员工表密码 MD5 回填接口的 Spec Kit 文档。实现必须按 `spec.md`、`tasks.md` 和 `checklists/requirements.md` 执行。

## 作用范围

- 规格目录：`C:\workspace\ju-chat\specs\057-kk-emp-password-md5-backfill`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 目标控制器：`data-RC\juzi-service\src\main\java\com\drh\data\juzi\controller\admin\PhoneSecurityBackfillAdminController.java`
- 目标服务：`data-RC\juzi-service\src\main\java\com\drh\data\juzi\phonesecurity\PhoneSecurityBackfillService.java`

## 固定实现口径

- 新增后台接口 `POST /admin/phone-security-backfill/emp-password-md5`。
- 接口无请求体，不允许调用方传入表名、字段名或过滤条件。
- 回填目标固定为 `drh_kk_emp.password` 和 `drh_kk_one_emp.password`。
- 已完整匹配 `^[0-9a-fA-F]{32}$` 的密码视为已是 MD5，不再更新。
- `NULL`、空字符串和纯空白密码不更新。
- 非 MD5 密码逐行调用 `PhoneSecurityEncryptClient.encryptPhone(password)`，运行时由 `DefaultPhoneSecurityEncryptClient` 调用 FC，取返回 `md5` 回填。
- 使用数据库原始 `password` 字符串计算，不先 `trim` 后再加密。
- 日志只允许记录表名、字段名、行数和失败类型，不允许记录密码原值或 md5 结果。

## 验证门禁

- 新接口必须沿用 `/admin/phone-security-backfill/**` 现有后台鉴权。
- 新接口必须同步返回两张表的更新行数和汇总更新行数。
- 新接口不得影响原有 `POST /admin/phone-security-backfill/start` 和 `GET /admin/phone-security-backfill/status`。
- 单元测试必须断言查询 SQL 使用固定白名单表名，且包含非空、非空白和非 MD5 判断。
- 单元测试必须断言更新 SQL 不包含 `MD5(`，并使用 `WHERE id = ? AND password = ?` 避免覆盖并发修改。
