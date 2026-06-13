# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\088-phone-security-region-refresh-days-filter`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 相关模块：手机号安全字段省市映射刷新（`com.drh.data.juzi.phonesecurity`、`com.drh.data.juzi.controller.admin`）

## 当前目标

- 在既有 `admin/phone-security-region-refresh/start` 接口上新增可选 `days` 参数。
- `days` 为空时保持当前全量扫描；`days > 0` 时仅对配置了创建时间列的大表追加最近 N 天过滤。
- 通过正式库只读元数据和行数确认哪些目标需要时间列；1 万行以下目标可不配置时间过滤。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、配置来源和测试落点。
- 不允许把空对象、占位 DTO 或未赋值字段当成有效输入继续传递。
- 对跨层可变 DTO、调用后赋值、字段来源不明、旧逻辑副作用，必须先标记风险。
- 发现关键参数依赖后续步骤补齐时，优先在当前层现算现用，或改为显式请求对象；如果会改变业务语义，先确认。
- 任何会改变调用顺序、接口契约、远程调用、MQ 字段、Redis key、数据库结构或外部行为的方案，实施前必须确认业务意图。
- 单元测试不能只验证最终结果；涉及外部调用、MQ、FC、Feign、OTS、Redis 时，必须做下游参数断言，确认关键参数内容。

## 强制门禁

- 参数来源：`dryRun`、`days` 来自 start 请求参数；`cutoffTime` 在任务启动时按服务 JVM 时间现算一次。
- 赋值时机：`cutoffTime` 在提交异步任务前计算并写入运行状态，任务内只读。
- 占位对象：不允许传递空 DTO、空 Map 或空 JSON。
- 下游读取：扫描 SQL、缺安全字段统计 SQL 读取 `days/cutoffTime/timeColumn`；所有 JDBC 参数必须在调用前生成。
- 旧逻辑保持：不改加密回填、明文退役、FC 解密、region 幂等写入、dryRun、互斥和 preflight 语义。
- 影响范围：仅新增 start 参数、响应字段、目标时间列配置和 region refresh 查询条件。
- 测试映射：必须覆盖 days 为空、days 有效且有时间列、days 有效但无时间列、非法 days、响应字段和旧构造函数兼容。

## 重点代码位置

- 入口：`com.drh.data.juzi.controller.admin.PhoneSecurityRegionRefreshAdminController`
- 核心实现：`com.drh.data.juzi.phonesecurity.PhoneSecurityRegionRefreshService`
- 目标配置：`com.drh.data.juzi.phonesecurity.BackfillTarget`、`PhoneSecurityTargets`
- 响应 DTO：`PhoneSecurityRegionRefreshStartResponse`、`PhoneSecurityRegionRefreshStatusResponse`
- 测试目录：`data-RC\juzi-service\src\test\java\com\drh\data\juzi\phonesecurity`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- `phone_security_region_refresh_target_stats.sql` 是正式库只读事实确认 SQL。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
