# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\085-phone-security-backfill-field-length-guard`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 相关模块：`juzi-service` 手机号安全字段回填

## 当前目标

- 修复 `admin/phone-security-backfill/start` 刷线上数据时 `phone_mask` 字段超长导致的 `DataIntegrityViolationException`。
- 在回填写库前校验源手机号和 FC 返回的 `mask/md5/aes` 字段，异常输出跳过，不截断、不扩表。
- 保持接口路径、响应结构、FC 调用契约、`PhoneSecurityTargets` 和数据库表结构不变。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据日志猜测落点；必须确认入口、调用链、字段来源和测试落点。
- 不允许把 FC 异常输出、明文手机号、空值或超长字段当成有效安全字段继续写库。
- 所有写入 `*_mask/*_md5/*_aes` 的值必须在写库前完成长度和格式校验。
- 单行写库失败必须隔离，不得终止整个表或整个任务的后续记录处理。
- 本需求明确不改表结构，不新增对外 API，不改 MQ/Redis/配置契约。

## 强制门禁

- 参数来源：源手机号来自 `PhoneSecurityBackfillService.queryBatch()` 扫描的业务表源列；`mask/md5/aes` 来自 `PhoneSecurityEncryptClient.encryptPhone()`。
- 赋值时机：`encryptRecord()` 构造 `SecurityUpdate` 前必须校验 FC 返回字段；`batchUpdate()` 写库前只接收已校验结果。
- 占位对象：不得构造空 `SecurityUpdate` 或字段不完整的更新对象。
- 下游读取：`batchUpdate()` 只读取 `SecurityUpdate.mask/md5/aes/id`，其中 `mask <= 32`、`md5` 为 32 位 hex、`aes <= 255`。
- 旧逻辑保持：`PhoneSecurityTargets` 清单、分页大小、FC 加密契约、管理接口、状态响应字段保持不变。
- 影响范围：只允许改 `PhoneSecurityBackfillService` 及其单元测试；如需动其他文件必须同步更新本规格。
- 测试映射：必须覆盖 FC 返回超长/非法字段跳过、合法字段继续更新、单行 DB 异常继续处理。

## 重点代码位置

- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\controller\admin\PhoneSecurityBackfillAdminController.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\phonesecurity\PhoneSecurityBackfillService.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\test\java\com\drh\data\juzi\phonesecurity\PhoneSecurityBackfillServiceSingleUpdateTest.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\test\java\com\drh\data\juzi\phonesecurity\PhoneSecurityBackfillServiceMaskGuardTest.java`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
