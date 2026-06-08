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

## SQL / FC 口径

- [x] 固定回填 `drh_kk_emp.password`。
- [x] 固定回填 `drh_kk_one_emp.password`。
- [x] 不接收调用方表名、字段名或过滤条件。
- [x] 仅查询 `password IS NOT NULL` 的候选记录。
- [x] 仅查询 `TRIM(password) <> ''` 的候选记录。
- [x] 已匹配 `^[0-9a-fA-F]{32}$` 的记录不更新。
- [x] 使用数据库原始 `password` 调用 `PhoneSecurityEncryptClient.encryptPhone(password)`。
- [x] 仅写回 FC 返回的非空 `md5`，忽略 `mask/aes`。
- [x] 更新 SQL 使用 `WHERE id = ? AND password = ?` 防止覆盖并发修改。
- [x] 新增链路不使用 MySQL `MD5(` SQL。

## 安全与验证

- [x] 日志不输出密码值。
- [x] 响应不输出密码值。
- [x] 服务单元测试断言两张固定表 SQL、FC md5 写入、失败统计和更新数汇总。
- [x] 控制器单元测试断言响应包装。
- [x] 指定 Maven 测试通过。

## 测试库备份

- [x] 使用 `database-sql-skill` 测试库 profile `dev-mysql`。
- [x] 备份前执行只读 count SQL。
- [x] `drh_kk_emp` 导出 309 行。
- [x] `drh_kk_one_emp` 导出 239 行。
- [x] 备份 SQL 已放入本规格目录。
- [x] 未执行备份 SQL。
- [x] 临时导出文件已清理。

## 测试库恢复

- [x] 从备份 SQL 生成仅更新 `password` 字段的恢复脚本。
- [x] 恢复脚本只作用于 `drh_kk_emp.password` 和 `drh_kk_one_emp.password`。
- [x] 恢复前执行 SQL 风险分析，结果为 `dml`。
- [x] 使用 `database-sql-skill` 测试库 profile `dev-mysql` 执行恢复。
- [x] 恢复执行结果 `affected_rows: 523`。
- [x] 执行只读校验 SQL。
- [x] `drh_kk_emp` 309 行备份密码全部匹配，缺失 0 行，不一致 0 行。
- [x] `drh_kk_one_emp` 239 行备份密码全部匹配，缺失 0 行，不一致 0 行。
- [x] 未触碰生产库。
