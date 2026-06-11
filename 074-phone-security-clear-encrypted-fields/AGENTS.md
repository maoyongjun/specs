# 规格执行说明

本目录记录生产库手机号安全字段清空任务，作用范围仅限当前规格目录及其子目录。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\074-phone-security-clear-encrypted-fields`
- 目标数据库：`prod-mysql` profile 指向的生产 `drh` 库
- 目标清单来源：`C:\workspace\ju-chat\specs\069-phone-security-backfill-governance\sql\final-phone-security-ddl-and-indexes.sql`

## 当前目标

- 将目标表中的 `*_mask`、`*_md5`、`*_aes` 安全字段置为 `NULL`。
- 候选行只按同一字段组的 `*_md5 IS NOT NULL AND *_md5 <> ''` 核对，不按 `mask/aes` 单独有值核对。
- 覆盖标准 `phone_*`、`app_phone_*`、`receiver_phone_*`、`reciver_phone_*` 共 45 组字段。
- 以每批 500 行的主键小批量方式执行，避免单条大范围更新长时间持锁。

## 执行原则

- 必须先执行 dry-run 和 SQL 风险分析，再执行生产写入。
- 生产写入前必须确认 RDS 备份/PITR 可用，并暂停会重新写入这些字段的回填或业务任务。
- 禁止执行单条整表 `UPDATE`。
- 禁止修改源手机号列，例如 `phone`、`app_phone`、`receiver_phone`、`reciver_phone`。
- 禁止导出、记录或打印 `phone_aes`、`phone_md5`、`phone_mask` 的真实值。
- 所有生产写入必须通过 `scripts/phone_security_clear_runner.py --execute`，并提供包含日期、profile、备份确认、写入暂停和批大小的 `--confirm`。

## 重点文件

- `scripts/phone_security_clear_runner.py`：生产 dry-run、verify、execute 执行器。
- `sql/phone-security-clear-targets.json`：从 069 DDL 生成并校验过的目标字段清单。
- `sql/phone-security-clear-dml-template.sql`：用于 `database-sql-skill analyze` 的 DML 风险分析模板，不作为实际执行脚本直接运行。
- `out/`：dry-run、execute、verify 的脱敏 JSON 报告目录。

## 文档维护

- 每次执行 dry-run、execute 或 verify 后，必须把输出报告路径、总候选量、总更新量和结论追加到 `tasks.md` 的执行记录。
- 如用户调整批大小、字段范围或执行 profile，必须同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 和 checklist。
