# 规格执行说明

本目录记录 `006-codex-account-switcher-javafx` 功能规格，作用范围仅限当前规格目录及 `C:\workspace\ju-chat\codex-account-switcher` 独立 JavaFX 项目。

## 当前阶段

- Spec Kit 文档阶段已完成。
- 实现阶段新增独立 Maven 项目，不改现有 `kkhc`、`fc`、`coze_plugin` 等业务模块。
- 当前目录应包含 `AGENTS.md`、`spec.md`、`tasks.md` 和 `checklists/requirements.md`。

## 实现约束

- 应用使用 Java 17 与 JavaFX，源码落在 `C:\workspace\ju-chat\codex-account-switcher`。
- 主类为 `com.juchat.codexswitcher.CodexAccountSwitcherApp`，另提供非 JavaFX `Launcher` 作为打包入口。
- 账号槽位固定为 1-15，账号目录为 `%USERPROFILE%\.codex-accountN`。
- 共享数据目录为 `%USERPROFILE%\.codex-shared`，共享 `sessions`、`archived_sessions`、`session_index.jsonl`。
- 启动账号时必须准备目录、停止现有 Cursor/Codex 进程，并以 `CODEX_HOME` 与 `CODEX_ACCOUNT_SLOT` 启动 Cursor。
- 导出包为明文 zip，包含所有账号目录、共享数据、旧版 `.codex` 兼容文件和固定 manifest 字段。
- 恢复策略为备份后替换：先备份目标机现有数据，再恢复导出包并重建共享链接。
- 不生成安装器；最终产物是 `target\dist\CodexAccountSwitcher\CodexAccountSwitcher.exe` 及同目录运行时文件。

## 文档维护

- `spec.md` 描述用户场景、功能需求、边界情况、成功标准和假设。
- `tasks.md` 记录实现任务拆分、验收任务和执行记录。
- `checklists/requirements.md` 用于实现前后验证规格质量。
- 如果需求变化，先更新 `spec.md`，再同步 `tasks.md` 与检查清单。
