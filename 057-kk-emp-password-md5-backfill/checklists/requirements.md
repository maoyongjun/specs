# 需求检查清单：员工密码 MD5 回填接口

## 文档完整性

- [x] 已创建规格目录 `057-kk-emp-password-md5-backfill`。
- [x] 已包含 `AGENTS.md`、`spec.md`、`tasks.md`。
- [x] 已包含 `checklists/requirements.md`。

## 接口

- [x] 新增 `POST /admin/phone-security-backfill/emp-password-md5`。
- [x] 接口无请求体。
- [x] 接口返回 `BaseResponse<PhoneSecurityPasswordBackfillResponse>`。
- [x] 原 `start/status` 接口不变。
- [x] 接口继承 `/admin/phone-security-backfill/**` 鉴权。

## SQL 口径

- [x] 固定更新 `drh_kk_emp.password`。
- [x] 固定更新 `drh_kk_one_emp.password`。
- [x] 不接收调用方表名、字段名或过滤条件。
- [x] 仅更新 `password IS NOT NULL` 的记录。
- [x] 仅更新 `TRIM(password) <> ''` 的记录。
- [x] 已匹配 `^[0-9a-fA-F]{32}$` 的记录不更新。
- [x] 使用 MySQL 内置 `MD5(password)`。

## 安全与验证

- [x] 日志不输出密码值。
- [x] 响应不输出密码值。
- [x] 服务单元测试断言两张固定表 SQL 和更新数汇总。
- [x] 控制器单元测试断言响应包装。
- [x] 指定 Maven 测试通过。
