# 任务清单：跨 AI 工具数据库 SQL 操作技能

**输入**：来自 `specs/010-database-sql-skill/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`、`usage.md`  
**测试**：文档阶段验证文件完整性；实现阶段使用离线单元测试验证安全策略和命令行为。

## Phase 1：Spec Kit 文档

- [x] T001 创建 Spec Kit 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`usage.md`、`checklists/requirements.md`
- [x] T002 明确技能目标为跨 Codex、Trae、Claude Code 复用的数据库 SQL 操作技能
- [x] T003 明确支持直连数据库和堡垒机隧道两种访问模式
- [x] T004 明确默认只读、写操作显式授权、敏感信息脱敏和离线测试要求

## Phase 2：技能包骨架

- [x] T005 在 `C:\workspace\ju-chat` 下创建 `database-sql-skill` 技能包目录
- [x] T006 编写通用 `SKILL.md`，包含触发条件、执行流程、安全约束和资源导航
- [x] T007 添加 `agents/openai.yaml`，用于 Codex 技能列表展示
- [x] T008 添加 `references/configuration.md`，说明 profile 字段、环境变量引用和配置位置
- [x] T009 添加 `references/sql-safety.md`，说明 SQL 风险分类、确认流程和回滚建议
- [x] T010 添加 `assets/config.example.yaml` 或等价配置模板，且只包含示例值

## Phase 3：命令行脚本

- [x] T011 实现 `scripts/db_skill.py profiles`，列出 profile 并隐藏敏感字段
- [x] T012 实现 `scripts/db_skill.py validate-config`，校验配置文件结构和必填字段
- [x] T013 实现 `scripts/db_skill.py analyze --file <sql>`，输出 SQL 语句分类和风险摘要
- [x] T014 实现 `scripts/db_skill.py test --profile <name>`，验证直连或堡垒机链路
- [x] T015 实现 `scripts/db_skill.py run --profile <name> --file <sql>`，执行只读 SQL 并输出结果
- [x] T016 实现写操作保护参数，例如 `--allow-write` 和 `--confirm <text>`
- [x] T017 实现结果输出格式 `table`、`json`、`csv`
- [x] T018 实现审计日志与敏感信息脱敏

## Phase 4：数据库和堡垒机适配

- [x] T019 实现 `direct` 数据库连接模式
- [x] T020 实现 `bastion` SSH 隧道模式，支持密码和私钥
- [x] T021 实现 MySQL 查询执行适配
- [x] T022 实现 PostgreSQL 查询执行适配
- [x] T023 预留 SQL Server 和 Oracle 适配接口
- [x] T024 处理端口冲突、连接超时、认证失败和驱动缺失错误

## Phase 5：测试与验证

- [x] T025 添加配置解析单元测试
- [x] T026 添加环境变量引用和敏感信息脱敏测试
- [x] T027 添加 SQL 风险分类测试，覆盖 SELECT、WITH、INSERT、UPDATE、DELETE、DDL、CALL 和未知语句
- [x] T028 添加默认拒绝写操作测试
- [x] T029 添加无真实数据库的 fake runner 或 mock 连接测试
- [x] T030 运行技能验证脚本和项目测试
- [x] T031 记录验证命令、结果和剩余风险

## Phase 6：使用说明完善

- [x] T032 根据最终实现命令同步更新 `specs/010-database-sql-skill/usage.md`
- [x] T033 在使用说明中补充 Codex、Trae、Claude Code 的实际安装路径或引用方式
- [x] T034 在使用说明中补充常见错误和排障示例

## 执行记录

### D001 - 文档创建

- 执行内容：创建 `010-database-sql-skill` 规格目录，完成需求规格、任务清单、执行说明、使用说明和规格检查清单。
- 验证方式：检查目标文件是否存在，并确认文档覆盖堡垒机、数据库 profile、SQL 脚本执行、跨 AI 工具使用和安全约束。
- 当前状态：文档阶段完成，技能实现阶段待执行。

### D002 - 技能实现

- 执行内容：在 `C:\workspace\ju-chat\database-sql-skill` 创建独立技能包，包含 `SKILL.md`、`agents/openai.yaml`、`requirements.txt`、`scripts/db_skill.py`、配置模板、参考文档和离线 pytest 测试。
- CLI 能力：实现 `profiles`、`validate-config`、`analyze`、`test`、`run`；支持 `--config`、`--allow-write`、`--confirm`、`--format table|json|csv`、`--output`。
- 安全能力：默认拒绝非只读 SQL；写操作必须同时满足 profile 允许、命令允许和确认文本；配置通过 `${env:NAME}` 读取环境变量；stdout、stderr 和审计日志执行敏感信息脱敏。
- 连接能力：实现 direct 模式、bastion SSH 本地端口转发、MySQL 适配、PostgreSQL 适配；SQL Server 与 Oracle 作为明确的保留扩展点。
- 测试命令：`python -m pytest database-sql-skill`
- 测试结果：`10 passed`。
- 验证命令：`python C:\Users\EDY\.codex-account7\skills\.system\skill-creator\scripts\quick_validate.py C:\workspace\ju-chat\database-sql-skill`
- 验证结果：`Skill is valid!`
- CLI 抽样验证：`python .\database-sql-skill\scripts\db_skill.py analyze --file <temp-sql>` 返回 `Risk: readonly`。
- 剩余风险：未连接真实堡垒机或真实数据库做集成测试；真实 MySQL/PostgreSQL 使用前需要按 `database-sql-skill\requirements.txt` 安装对应驱动并配置本机 profile。
