# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\083-phone-security-region-refresh`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 相关模块：手机号安全字段省市映射刷新（`com.drh.data.juzi.phonesecurity`、`com.drh.data.juzi.controller.admin`）

## 当前目标

- 在 juzi-service 新增管理接口 `POST admin/phone-security-region-refresh/start`（支持 `dryRun`）和 `GET admin/phone-security-region-refresh/status`，对线上 `drh_phone_security_region` 表做数据刷新。
- 复用 `PhoneSecurityTargets.TARGETS` 的 45 张业务表清单，扫描已有 `phone_mask/phone_md5/phone_aes` 的行，按 `phone_md5` 幂等补齐 `drh_phone_security_region`（存在不处理，不存在写入，与 spec 079 语义一致）。
- 明文 `phone` 列已被退役为掩码（含 `*`）的行，调 FC DataSecurity（businessType=2）解密 `phone_aes` 还原手机号，再取前 7 位查 `phone_segment` 解析省市；明文有效的行直接用明文前 7 位。

## 实现约束

- 全部新增文件，不修改 `PhoneSecurityBackfillService`、`PhonePlaintextRetirementService`、`PhoneSecurityBackfillAdminController` 等任何现有类的行为。
- 不新增 Maven 依赖；Java 8 语法。
- `drh_phone_security_region` 只写 `phone_mask/phone_md5/phone_aes/province/city` 五列；MUST NOT 写 `segment` 字段、MUST NOT 写明文手机号。
- 不动 FC 加密契约（businessType=1）；解密走 businessType=2/dataType=1，取输出 `aesDecrypt` 字段（对齐 kkhc `DataSecurityInvoke.decryptPhoneAes`）。
- 不做本地 AES 解密回退（juzi-service 无本地密钥工具），FC 解密失败只计数跳过。
- 写入语义对齐 kkhc `PhoneSecurityRegionRecorder`：三个安全字段非空、province/city 非空才写；唯一键冲突视为已存在；异常只记日志不阻断。
- 与现有任务互斥：backfill 或 plaintext-retirement 运行中时拒绝启动本任务（单向互斥，不反向修改现有类）。
- `segment -> province/city` 用服务内 `ConcurrentHashMap` 缓存，不缓存负结果，不新增 Redis key 契约。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、配置来源和测试落点。
- 不允许把空对象、占位 DTO 或未赋值字段当成有效输入继续传递。
- 对跨层可变 DTO、调用后赋值、字段来源不明、旧逻辑副作用，必须先标记风险。
- 发现关键参数依赖后续步骤补齐时，优先在当前层现算现用，或改为显式请求对象；如果会改变业务语义，先确认。
- 任何会改变调用顺序、接口契约、远程调用、MQ 字段、Redis key、数据库结构或外部行为的方案，实施前必须确认业务意图。
- 单元测试不能只验证最终结果；涉及外部调用、MQ、FC、Feign、OTS、Redis 时，必须做下游参数断言，确认关键参数内容。

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：每个关键参数从哪里来，是否在调用前赋值。
- 赋值时机：是否存在调用后才 `set`，但下游已经读取的字段。
- 占位对象：是否存在 `new XxxDto()`、空 Map、空 JSON 作为占位参数。
- 下游读取：下游实际读取哪些字段，是否全部有来源。
- 旧逻辑保持：哪些旧分支、异常处理、日志、延迟、幂等、过滤条件必须不变。
- 影响范围：是否影响调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为。
- 测试映射：每个关键行为至少对应一条单元测试、集成测试或静态验证记录。

## 重点代码位置

- 入口（新增）：`com.drh.data.juzi.controller.admin.PhoneSecurityRegionRefreshAdminController`
- 核心实现（新增）：`com.drh.data.juzi.phonesecurity.PhoneSecurityRegionRefreshService`、`PhoneSecurityDecryptClient`、`DefaultPhoneSecurityDecryptClient`
- 模式母版（只读参照，不修改）：
  - `com.drh.data.juzi.phonesecurity.PhoneSecurityBackfillService`（异步单任务、分页扫描、fcExecutor 并发）
  - `com.drh.data.juzi.phonesecurity.PhonePlaintextRetirementService`（互斥守卫、SQL 构建可测性）
  - `com.drh.data.juzi.phonesecurity.DefaultPhoneSecurityEncryptClient`（FC 调用样板）
  - kkhc `com.kkhc.idc.lms.service.impl.PhoneSecurityRegionRecorder`（写入语义基准）
- 测试位置：`data-RC\juzi-service\src\test\java\com\drh\data\juzi\phonesecurity\PhoneSecurityRegionRefresh*Test`、`DefaultPhoneSecurityDecryptClientTest`

## 修改时检查

- 扫描 SQL 是否要求 `phone_mask/phone_md5/phone_aes` 三字段均非空，安全字段不全的行是否只计数不处理。
- 是否先做 region 表 `phone_md5 IN (...)` 预检，再对未命中的行做 FC 解密（已存在的号不得发 FC 请求）。
- INSERT 列清单是否精确为 `(phone_mask, phone_md5, phone_aes, province, city)`，SQL 与参数中是否绝无 `segment` 和明文手机号。
- `DuplicateKeyException` 是否计入已存在并继续，其他异常是否只记日志不中断任务。
- dryRun 模式是否完全不发 FC、不写库。
- start() 是否检查 backfill / retirement 运行状态，是否做两表 preflight 探活。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
