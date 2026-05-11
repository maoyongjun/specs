# 规格执行说明

本目录记录 `010-database-sql-skill` 功能规格，作用范围为数据库 SQL 操作技能的设计文档和后续实现指引。

## 当前目标

- 设计一个可被 Codex、Trae、Claude Code 等 AI 工具复用的数据库 SQL 操作技能。
- 技能需要支持通过堡垒机访问内网数据库，也支持直接数据库连接。
- 技能需要通过预配置 profile 快速执行 SQL 脚本。
- 技能必须默认只读，写操作必须显式授权。
- 本目录额外提供 `usage.md`，用于指导用户安装、配置和使用技能。

## 建议目标实现位置

- 技能包目录：`C:\workspace\ju-chat\database-sql-skill`
- 通用技能说明：`C:\workspace\ju-chat\database-sql-skill\SKILL.md`
- 脚本入口：`C:\workspace\ju-chat\database-sql-skill\scripts\db_skill.py`
- 配置说明：`C:\workspace\ju-chat\database-sql-skill\references\configuration.md`
- 安全说明：`C:\workspace\ju-chat\database-sql-skill\references\sql-safety.md`
- 示例配置：`C:\workspace\ju-chat\database-sql-skill\assets\config.example.yaml`

## 实现约束

- 不得把真实堡垒机地址、账号、密码、数据库连接串、token 或私钥提交到仓库。
- 真实配置默认放在用户本机私有目录，例如 `%USERPROFILE%\.database-sql-skill\config.yaml`。
- 配置示例只能使用 `example.com`、`127.0.0.1`、`demo` 等假值。
- 默认执行策略必须是只读。任何写操作都必须经过 profile 允许、命令参数允许和用户确认。
- SQL 执行前必须先做语句分类和风险摘要。
- 日志和错误输出必须脱敏。
- 离线测试不得依赖真实堡垒机或真实数据库。
- 实现时优先复用标准库和成熟驱动，避免在 AI 提示词中拼接明文密码命令。

## 跨工具兼容约束

- 核心工作流必须写在通用 `SKILL.md` 中。
- Codex 可额外使用 `agents/openai.yaml` 作为展示元数据。
- Trae、Claude Code 或其他工具即使不读取 `agents/openai.yaml`，也必须能通过 `SKILL.md` 和 `scripts/db_skill.py` 完成任务。
- 如果某工具没有原生 skill 目录，使用说明应指导用户把 `SKILL.md` 作为项目规则、上下文文件或自定义指令引用。

## 文档维护

- `spec.md` 描述用户场景、功能需求、边界情况、成功标准和假设。
- `tasks.md` 记录实现任务拆分、验收任务和执行记录。
- `usage.md` 面向技能使用者，说明安装、配置、命令和安全策略。
- `checklists/requirements.md` 用于验证规格质量和实施准备度。
- 如果后续实现命令或目录结构变化，必须同步更新 `usage.md` 和 `tasks.md`。
