# 功能规格：Codex 账号切换器 JavaFX EXE

**功能目录**: `006-codex-account-switcher-javafx`  
**创建日期**: 2026-05-08  
**状态**: Implemented  
**输入**: 用户要求将 `C:\Users\EDY\OneDrive\Desktop\switchCodex.cmd` 封装为类似 FinalShell 的可双击界面应用，源码放在 `C:\workspace\ju-chat`，使用 Java 与 JavaFX，最终生成 exe，并在现有切换账号功能外增加账号导出迁移恢复功能。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 图形界面切换 Codex 账号（优先级：P1）

用户打开 Windows exe 后，可以在 JavaFX 界面中看到固定 1-7 个账号槽位、每个账号的邮箱/过期时间/账号目录，并点击账号启动 Cursor/Codex。

**独立测试**：在存在或不存在账号文件的机器上启动应用，验证界面显示 1-7 个槽位，点击某个槽位会准备对应目录并以该槽位的 `CODEX_HOME` 启动 Cursor。

**验收场景**：

1. **Given** 应用启动，**When** 主界面加载完成，**Then** 左侧固定显示账号 1-7。
2. **Given** 某槽位存在 `auth.json` 或旧版 `auth_userN.json`，**When** 刷新状态，**Then** 显示解析出的邮箱和令牌过期时间。
3. **Given** 用户点击启动账号 N，**When** 应用执行启动流程，**Then** 准备 `%USERPROFILE%\.codex-accountN` 并设置 `CODEX_HOME`、`CODEX_ACCOUNT_SLOT` 启动 Cursor。
4. **Given** Cursor 不存在，**When** 用户启动账号，**Then** 应用显示明确错误并保留日志。

### 用户故事 2 - 一键准备与修复账号目录（优先级：P1）

用户可以通过界面准备全部账号目录，应用复刻原 PowerShell 脚本中的共享数据初始化、旧版 auth 导入、config 补齐和共享链接创建逻辑。

**独立测试**：在临时用户目录中执行准备全部账号，验证 7 个账号目录、共享目录、默认配置和共享链接均生成。

**验收场景**：

1. **Given** 旧版 `%USERPROFILE%\.codex\auth_userN.json` 存在，**When** 准备账号 N，**Then** 复制到 `%USERPROFILE%\.codex-accountN\auth.json`。
2. **Given** 账号 config 缺失，**When** 准备账号，**Then** 创建默认 `config.toml`。
3. **Given** 共享目录或文件缺失，**When** 准备账号，**Then** 创建 `%USERPROFILE%\.codex-shared` 并在账号目录下重建共享链接。

### 用户故事 3 - 导出全部账号用于迁移（优先级：P1）

用户可以在界面选择保存位置，导出所有账号槽位、共享聊天数据和旧版兼容文件到明文 zip 包。

**独立测试**：执行导出后检查 zip，验证存在 `manifest.properties`、`accounts/account1..7`、`shared` 和 `legacy` 目录，且账号目录中的共享链接不会重复跟随导出。

**验收场景**：

1. **Given** 用户点击导出全部账号，**When** 选择 zip 保存路径，**Then** 应用生成明文 zip。
2. **Given** 导出成功，**When** 打开 zip manifest，**Then** 包含固定字段：`schemaVersion=1`、`appVersion=1.0.0`、`createdAt`、`maxAccounts=7`、`exportSecurity=plainZip`、`includesShared=true`。
3. **Given** 账号目录下存在共享链接，**When** 导出账号目录，**Then** 不把链接目标作为账号子目录重复写入 zip。

### 用户故事 4 - 备份后替换恢复账号包（优先级：P1）

用户在另一台电脑选择导出的 zip 包后，应用先备份目标电脑现有 Codex 账号数据，再完整恢复导出包并重建共享链接。

**独立测试**：在临时用户目录中放入旧数据后执行恢复，验证旧数据进入 `.codex-switcher-restore-backup\<timestamp>`，导出包数据恢复到目标位置，账号共享链接可重新创建。

**验收场景**：

1. **Given** 目标电脑已有账号数据，**When** 用户恢复 zip，**Then** 现有 `.codex-account1..7`、`.codex-shared` 和相关 `.codex` 文件先被备份。
2. **Given** zip manifest 合法，**When** 恢复执行，**Then** 解压账号、共享和旧版兼容数据到目标用户目录。
3. **Given** 恢复完成，**When** 应用刷新状态，**Then** 展示恢复后的账号邮箱和目录状态。

## 边界情况

- 默认 `java/javac` 为 Java 8，但 Maven 和打包需要使用 JDK17。
- `jpackage.exe` 不在 PATH，但存在于 `C:\workspace\tools\jdk17\jdk-17.0.18+8\bin\jpackage.exe`。
- `Cursor.exe` 不在常见安装目录，也不在 PATH。
- Windows 符号链接创建失败，需要回退到硬链接。
- 账号目录中已有普通 `sessions`、`archived_sessions` 或 `session_index.jsonl`，准备账号时需要备份后替换为共享链接。
- 导出包是明文 zip，拿到文件的人可以读取登录令牌。
- 恢复 zip 可能缺失 manifest、版本不兼容或包含 zip slip 路径。
- 恢复时目标电脑已有 Codex/Cursor 进程。

## 需求 *(必填)*

- **FR-001**：系统 MUST 新增独立 Maven JavaFX 项目 `codex-account-switcher`。
- **FR-002**：系统 MUST 使用 Java 17 编译，JavaFX 依赖版本为 `21.0.6`。
- **FR-003**：主界面 MUST 固定展示账号 1-7。
- **FR-004**：界面 MUST 提供 `启动账号`、`准备全部账号`、`导出全部账号`、`恢复账号包`、`刷新状态` 操作。
- **FR-005**：账号启动 MUST 设置进程级 `CODEX_HOME` 与 `CODEX_ACCOUNT_SLOT`，不得写入用户级系统环境变量。
- **FR-006**：账号启动 MUST 先停止现有 `codex` 与 `Cursor` 进程。
- **FR-007**：账号准备 MUST 创建账号目录、共享目录、默认 config，并导入旧版 auth。
- **FR-008**：共享目录 MUST 包含 `sessions`、`archived_sessions`、`session_index.jsonl`。
- **FR-009**：账号目录中的共享目录 MUST 使用 Windows junction，共享文件 MUST 优先符号链接、失败后硬链接。
- **FR-010**：导出 MUST 生成明文 zip，并写入固定 manifest 字段。
- **FR-011**：导出 MUST 包含所有账号目录、共享数据和旧版 `.codex` 兼容文件。
- **FR-012**：导出 MUST 跳过账号目录中的共享链接，避免重复导出共享数据。
- **FR-013**：恢复 MUST 使用备份后替换策略。
- **FR-014**：恢复 MUST 校验 manifest 和 zip slip 路径。
- **FR-015**：恢复完成后 MUST 重建共享链接并刷新界面状态。
- **FR-016**：最终 MUST 可生成 `target\dist\CodexAccountSwitcher\CodexAccountSwitcher.exe`。

## 成功标准 *(必填)*

- **SC-001**：`mvn -f codex-account-switcher\pom.xml clean test package` 成功。
- **SC-002**：单元测试覆盖 JWT 解析、账号准备、默认 config、旧版 auth 导入、导出 manifest、备份后替换恢复。
- **SC-003**：打包脚本成功调用 JDK17 `jpackage` 并生成目标 exe。
- **SC-004**：应用启动后可刷新并展示 7 个账号状态。
- **SC-005**：导出 zip 包包含指定 manifest，且共享数据只在 `shared` 下出现。
- **SC-006**：恢复已有数据时会先生成备份目录，再恢复导出包内容。

## 假设

- 用户已确认导出包使用明文 zip，不加密。
- 用户已确认点击账号默认启动 Cursor。
- 用户已确认账号槽位固定为 1-7。
- 用户已确认恢复策略为备份后替换。
- 不做安装器 exe/MSI，只做可双击 app image。
