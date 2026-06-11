# 规格执行说明

本目录记录 `juzi-service` 手机号安全回填写库从 JDBC batch 改为逐条写的修复。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\075-phone-security-single-row-update`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 相关模块：`com.drh.data.juzi.phonesecurity`

## 当前目标

- 规避生产 `rewriteBatchedStatements=true` 下批量 `UPDATE` 被重写成多语句后报 SQL 语法错误。
- 普通手机号安全字段回填逐条写 `mask/md5/aes`。
- 员工密码 MD5 回填同步逐条写，避免同类 JDBC batch rewrite 风险。

## 执行原则

- 不修改 JDBC URL，不通过 `allowMultiQueries=true` 解决该问题。
- 不改变 FC 加密调用、候选查询条件、target 清单、回填接口和状态流转。
- 数据库写入参数必须使用 `PreparedStatement` 参数绑定，不拼接字段值。
- 单元测试必须断言 `JdbcTemplate.update` 调用次数、SQL 模板和参数顺序，并断言不调用 `batchUpdate`。

## 强制门禁

- 参数来源：`mask/md5/aes/id` 和 `md5/id/originalPassword` 必须在写库前构造完成。
- 赋值时机：不得依赖写库后补齐字段。
- 占位对象：不得把空加密结果或只赋值部分字段的对象写入数据库。
- 下游读取：写库方法读取的字段必须全部有来源。
- 旧逻辑保持：候选查询、掩码源跳过、FC 并发、target 级异常捕获、日志和更新数口径保持。
- 影响范围：仅改变 `PhoneSecurityBackfillService` 的数据库写入方式。
- 测试映射：普通手机号字段回填和密码 MD5 回填各有单元测试覆盖。

## 重点代码位置

- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\phonesecurity\PhoneSecurityBackfillService.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\test\java\com\drh\data\juzi\phonesecurity\PhoneSecurityBackfillServiceSingleUpdateTest.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\test\java\com\drh\data\juzi\phonesecurity\PhoneSecurityBackfillServicePasswordMd5Test.java`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 验证规格质量、参数完整性和实施就绪度。
- 若后续决定改 JDBC URL、恢复 batch、或扩展到 `PhonePlaintextRetirementService`，必须追加纠正记录。
