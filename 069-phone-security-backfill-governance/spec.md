# 功能规格：手机号安全字段上线与回填治理

**功能目录**：`069-phone-security-backfill-governance`

**输入**：汇总 `032/036/048/051/063/067` 中手机号安全字段 DDL、历史数据加密字段回填范围、上线前数据准确性风险，以及新增 `juzi-service` 明文下线接口，将原手机号列批量覆盖为已回填的掩码列。

## 背景

现有 `juzi-service` 已提供 `POST /admin/phone-security-backfill/start`，按目标表读取明文手机号，调用数据安全能力回填 `*_mask / *_md5 / *_aes`。本次补齐 P3 缺失表，并移除已废弃的 `drh_specail_user`。

后续治理需要继续降低数据库明文手机号留存风险。在 `mask/md5/aes` 已准确回填后，新增明文掩码覆盖接口，把原明文字段更新为对应掩码字段，例如 `phone = phone_mask`、`receiver_phone = receiver_phone_mask`、`reciver_phone = reciver_phone_mask`。

## 目标行为

- 最终 DDL 存放在 `sql/final-phone-security-ddl-and-indexes.sql`。
- DDL 分两段执行：先加字段，再加索引。
- `phone_md5` 和 `phone_aes` 均建索引。
- `PhoneSecurityTargets.TARGETS` 作为唯一目标清单，被加密字段回填和明文掩码覆盖复用。
- `POST /admin/phone-security-backfill/start` 覆盖所有当前 45 个目标字段。
- `POST /admin/phone-plaintext-retirement/start?dryRun=true|false` 对同一目标清单执行明文掩码覆盖。
- 明文掩码覆盖只执行列拷贝 SQL，不调用 FC，不改 `md5/aes`。

## 非目标

- 不删除原手机号列。
- 不清空 `phone_aes`。
- 不修改业务查询逻辑。
- 不支持基于掩码值重新生成 `md5/aes`。
- 不纳入废弃表 `drh_specail_user`。

## 历史问题防漏分析

- `051` P3 表已确认纳入回填：`drh_register_works`、`drh_sms_deal`、`drh_temp_phone`、`drh_mall_order`。
- `drh_mall_order` 使用历史拼写 `reciver_phone`，安全字段沿用 `reciver_phone_*`。
- `drh_specail_user` 已废弃，应从 DDL、字段检查 SQL、回填接口和后续新增任务中排除。
- 明文掩码覆盖执行后，不得再次跑加密字段回填；否则会把 `138****5678` 这类掩码值当成手机号重新生成错误的 `md5/aes`。
- 加密字段回填增加兜底门禁：源字段已经包含 `*` 时不进入候选查询，Java 加密前也会再次跳过，防止明文下线后误触回填生成错误的 `md5/aes`。
- 生产执行必须先跑 `dryRun=true`，核对候选量，再执行真实覆盖。

## 执行顺序

1. 执行字段 DDL。
2. 执行索引 DDL。
3. 调用 `POST /admin/phone-security-backfill/start`。
4. 轮询 `GET /admin/phone-security-backfill/status` 至 `COMPLETED`。
5. 抽样核对 `source/mask/md5/aes` 的准确性。
6. 调用 `POST /admin/phone-plaintext-retirement/start?dryRun=true`。
7. 核对候选量和风险窗口。
8. 调用 `POST /admin/phone-plaintext-retirement/start?dryRun=false`。
9. 轮询 `GET /admin/phone-plaintext-retirement/status` 至完成。

## 边界情况

- 源手机号为空：跳过。
- 掩码为空：跳过。
- AES 为空：跳过，保留明文，等待加密字段回填补齐。
- 源字段已经等于掩码：跳过，保证幂等。
- 单表 SQL 异常：当前表标记失败，继续处理后续表。
- 加密字段回填正在运行：明文掩码覆盖接口拒绝启动。

## 需求

- **FR-001**：系统 MUST 使用一份共享目标清单维护所有手机号安全回填目标。
- **FR-002**：系统 MUST 从加密字段回填中排除 `drh_specail_user`。
- **FR-003**：系统 MUST 将 P3 四张表纳入加密字段回填。
- **FR-004**：系统 MUST 提供明文掩码覆盖启动和状态查询接口。
- **FR-005**：明文掩码覆盖 MUST 只在 `mask` 和 `aes` 非空且 `source != mask` 时执行。
- **FR-006**：明文掩码覆盖 MUST NOT 调用 FC，MUST NOT 改动 `md5/aes`。
- **FR-007**：最终 DDL MUST 将字段添加和索引添加拆开，且 `md5/aes` 均建索引。
- **FR-008**：加密字段回填 MUST 跳过已经是掩码格式的源字段。

## 成功标准

- **SC-001**：最终 DDL 目标和 `PhoneSecurityTargets.TARGETS` 一致，均为 45 组。
- **SC-002**：`POST /admin/phone-security-backfill/start` 覆盖 P3 表，不再包含废弃表。
- **SC-003**：明文掩码覆盖后，满足门禁的行 `source == mask`，且 `md5/aes` 不变。
- **SC-004**：二次执行明文掩码覆盖时候选量收敛为 0 或只剩不满足门禁的数据。
- **SC-005**：`dryRun=true` 不执行 UPDATE。

## 执行记录

### D001 - 本次 DDL 与回填目标汇总

- 从回填目标中移除废弃表 `drh_specail_user`。
- 补齐 P3：`drh_register_works`、`drh_sms_deal`、`drh_temp_phone`、`drh_mall_order`。
- 新增最终 DDL：字段和索引分段；所有 `*_md5` 和 `*_aes` 均有索引。
- 加密字段回填目标与最终 DDL 静态对照为 45 组。

### D002 - 明文掩码覆盖接口

- 新增 `POST /admin/phone-plaintext-retirement/start` 和 `GET /admin/phone-plaintext-retirement/status`。
- 支持 `dryRun`。
- 运行时和加密字段回填互斥。
- 只做 `source = mask` 的列拷贝。

### D003 - 加密字段回填掩码源保护

- `POST /admin/phone-security-backfill/start` 的候选 SQL 增加 `source NOT LIKE '%*%'`。
- 加密前再次判断源字段是否包含 `*`，包含则跳过，不调用 FC。
- 目的：明文字段已经覆盖为掩码后，即使误触加密字段回填，也不会用掩码值重新生成错误的 `mask/md5/aes`。
