# AGENTS: 手机号安全字段上线与回填治理

## 范围

- 规格目录：`C:\workspace\ju-chat\specs\069-phone-security-backfill-governance`
- 代码目录：`C:\workspace\ju-chat\data-RC\juzi-service`
- 加密字段回填入口：`POST /admin/phone-security-backfill/start`
- 明文掩码覆盖入口：`POST /admin/phone-plaintext-retirement/start`
- 状态查询：分别使用各自 `GET /status`

## 维护口径

- 所有新增手机号安全表必须先补 `PhoneSecurityTargets.TARGETS`，再补本目录 SQL 和任务记录。
- 加密字段回填只写 `*_mask / *_md5 / *_aes`，不得覆盖原明文字段。
- 明文掩码覆盖只执行 `source = mask`，不得调用 FC，不得改 `md5/aes`。
- `drh_specail_user` 已废弃，不再进入 DDL、加密回填或明文掩码覆盖。
- `phone_md5` 和 `phone_aes` 均要求建索引；字段 DDL 和索引 DDL 分阶段执行。

## 上线门禁

- 先执行字段 DDL，再执行索引 DDL，再跑加密字段回填。
- 只有加密字段回填完成并抽样确认 `mask/md5/aes` 准确后，才能执行明文掩码覆盖。
- 执行明文掩码覆盖后，不得再跑加密字段回填，否则会基于掩码值重新生成错误的 `md5/aes`。
- 生产首次执行明文掩码覆盖必须先 `dryRun=true`。

## 重点文件

- `sql/final-phone-security-ddl-and-indexes.sql`：最终字段和索引 SQL。
- `spec.md`：背景、目标、风险和执行顺序。
- `tasks.md`：后续新增表和上线前检查任务。
- `checklists/requirements.md`：上线前检查清单。
