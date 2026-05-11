# 数据库 SQL 操作技能使用说明

本文档说明已实现的 `database-sql-skill` 使用方式。技能包位置为 `C:\workspace\ju-chat\database-sql-skill`。

## 1. 技能能做什么

- 让 Codex、Trae、Claude Code 等 AI 工具按统一流程分析和执行 SQL 脚本。
- 通过预配置 profile 连接数据库，避免每次在对话里输入连接信息。
- 支持直连数据库，也支持先连堡垒机再访问内网数据库。
- 默认只允许查询类 SQL，写操作需要显式授权。
- 输出查询结果、执行摘要和脱敏审计日志。

## 2. 推荐目录结构

```text
database-sql-skill/
├── SKILL.md
├── agents/
│   └── openai.yaml
├── scripts/
│   └── db_skill.py
├── references/
│   ├── configuration.md
│   └── sql-safety.md
├── assets/
│   └── config.example.yaml
├── tests/
│   └── test_db_skill.py
└── requirements.txt
```

真实连接配置不要放进技能包目录，建议放到：

```text
%USERPROFILE%\.database-sql-skill\config.yaml
```

## 3. 安装到不同 AI 工具

### Codex

1. 将 `database-sql-skill` 目录复制到 Codex 可发现的 skills 目录，例如 `$CODEX_HOME\skills`。
2. 如果未设置 `CODEX_HOME`，使用当前 Codex 环境约定的用户级 skills 目录。
3. 确认 `SKILL.md` 位于 `database-sql-skill\SKILL.md`。
4. 在对话中要求 Codex 使用该技能，例如：`使用 database-sql-skill，分析并执行 sql\query_order.sql`。

### Trae

1. 如果当前 Trae 版本支持 skill 或规则目录，将整个 `database-sql-skill` 目录导入。
2. 如果不支持原生 skill 目录，把 `SKILL.md` 作为项目规则或上下文文档引用。
3. 确保 Trae 可以访问 `scripts\db_skill.py` 和本机配置文件。

### Claude Code

1. 如果当前 Claude Code 版本支持 skills，将整个 `database-sql-skill` 目录放入其用户级或项目级 skills 目录。
2. 如果不支持原生 skill 目录，把 `SKILL.md` 加入项目上下文或自定义指令。
3. 要求 Claude Code 按 `SKILL.md` 调用 `scripts\db_skill.py`，不要在提示词里暴露数据库密码。

不同工具的安装目录可能随版本变化。核心原则是：让 AI 能读到 `SKILL.md`，并能在本机执行 `scripts\db_skill.py`。

## 4. 配置 profile

首次使用前安装依赖：

```powershell
cd C:\workspace\ju-chat\database-sql-skill
python -m pip install -r requirements.txt
```

复制示例配置：

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.database-sql-skill"
Copy-Item .\assets\config.example.yaml "$env:USERPROFILE\.database-sql-skill\config.yaml"
```

配置文件示例：

```yaml
profiles:
  dev-mysql:
    mode: bastion
    environment: dev
    bastion:
      host: bastion.example.com
      port: 22
      username: ${env:BASTION_USER}
      password: ${env:BASTION_PASSWORD}
      private_key: null
      local_port: auto
    database:
      type: mysql
      host: mysql.internal.example.com
      port: 3306
      name: app_db
      username: ${env:DB_USER}
      password: ${env:DB_PASSWORD}
    policy:
      default_read_only: true
      allow_write: false
      require_confirmation: true
      max_rows: 1000
      log_dir: "%USERPROFILE%\\.database-sql-skill\\logs"

  local-postgres:
    mode: direct
    environment: local
    database:
      type: postgresql
      host: 127.0.0.1
      port: 5432
      name: demo
      username: ${env:PGUSER}
      password: ${env:PGPASSWORD}
    policy:
      default_read_only: true
      allow_write: false
      require_confirmation: true
      max_rows: 500
```

环境变量示例：

```powershell
$env:BASTION_USER="your-bastion-user"
$env:BASTION_PASSWORD="your-bastion-password"
$env:DB_USER="your-db-user"
$env:DB_PASSWORD="your-db-password"
```

不要把真实 `config.yaml`、密码、私钥或连接串提交到 git。

## 5. 常用命令

以下命令默认在 `C:\workspace\ju-chat\database-sql-skill` 目录执行。如果在 `C:\workspace\ju-chat` 执行，请把脚本路径改成 `.\database-sql-skill\scripts\db_skill.py`。

列出 profile：

```powershell
python .\scripts\db_skill.py profiles
```

校验配置：

```powershell
python .\scripts\db_skill.py validate-config
```

测试连接：

```powershell
python .\scripts\db_skill.py test --profile dev-mysql
```

分析 SQL 风险：

```powershell
python .\scripts\db_skill.py analyze --file .\sql\query_order.sql
```

执行只读 SQL：

```powershell
python .\scripts\db_skill.py run --profile dev-mysql --file .\sql\query_order.sql --format table
```

导出结果：

```powershell
python .\scripts\db_skill.py run --profile dev-mysql --file .\sql\query_order.sql --format csv --output .\out\query_order.csv
```

写操作示例。只有在确认备份、窗口期和回滚方案后才允许使用：

```powershell
python .\scripts\db_skill.py run --profile dev-mysql --file .\sql\fix_order.sql --allow-write --confirm "I understand this will modify database rows"
```

使用非默认配置文件：

```powershell
python .\scripts\db_skill.py --config C:\path\to\config.yaml profiles
```

## 6. 推荐 AI 提示词

只分析不执行：

```text
使用 database-sql-skill，profile=dev-mysql，分析 sql\fix_order.sql 的 SQL 类型、影响范围和风险，不要执行。
```

执行只读查询：

```text
使用 database-sql-skill，profile=dev-mysql，先分析 sql\query_order.sql。确认只有 SELECT 后执行，并把结果保存为 out\query_order.csv。
```

写操作前置检查：

```text
使用 database-sql-skill，profile=dev-mysql，检查 sql\fix_order.sql。请先说明会修改哪些表、预计影响行数、是否需要事务和回滚 SQL，未经我确认不要执行。
```

## 7. 安全策略

- 默认只读。`INSERT`、`UPDATE`、`DELETE`、`TRUNCATE`、`DROP`、`ALTER`、`CREATE`、`CALL`、`EXEC` 等语句默认拒绝。
- 写操作必须同时满足 profile 中 `allow_write=true`、命令中带 `--allow-write`、并提供确认文本。
- 生产环境 profile 建议始终保留 `require_confirmation=true`。
- AI 回复中不得展示明文密码、token、完整连接串或私钥内容。
- 大结果集必须限制行数，必要时导出到文件。
- 执行修复 SQL 前，应先准备备份、事务策略和回滚脚本。

## 8. 常见问题

### 找不到 profile

检查 `config.yaml` 是否存在，profile 名称是否与命令中的 `--profile` 完全一致。

### 环境变量未设置

如果配置中使用 `${env:DB_PASSWORD}`，需要先在当前终端设置对应环境变量，再启动 AI 工具或命令。

### 堡垒机连接失败

检查堡垒机地址、端口、账号、密码或私钥路径。还要确认本机网络可以访问堡垒机。

### SQL 被拒绝执行

先运行 `analyze` 查看语句分类。如果包含写操作，需要确认 profile 和命令参数都允许写，并由用户明确授权。

### 输出结果太大

调整 SQL 增加 `LIMIT` 条件，或在 profile 中降低 `max_rows`，再使用 `--output` 导出结果。

### PostgreSQL 驱动缺失

执行 `python -m pip install -r requirements.txt`，确保安装 `psycopg[binary]`。

## 9. 本地验证

离线测试不连接真实堡垒机或数据库：

```powershell
cd C:\workspace\ju-chat
python -m pytest database-sql-skill
python C:\Users\EDY\.codex-account7\skills\.system\skill-creator\scripts\quick_validate.py C:\workspace\ju-chat\database-sql-skill
```
