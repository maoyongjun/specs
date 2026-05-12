# 任务清单：Codex 账号切换器 JavaFX EXE

**输入**：来自 `specs/006-codex-account-switcher-javafx/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：实现完成后运行 Maven 测试与 jpackage 打包验证。  

## Phase 1：文档与项目骨架

- [x] T001 创建 Spec Kit 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 新建独立 Maven 项目 `codex-account-switcher`
- [x] T003 配置 Java 17、JavaFX 21.0.6、JUnit 5 与打包入口

## Phase 2：账号与共享数据服务

- [x] T004 实现用户目录定位，支持测试覆盖 `codex.switcher.userHome`
- [x] T005 实现 JWT `id_token` 邮箱和过期时间解析
- [x] T006 实现账号状态读取与固定 1-7 槽位列表
- [x] T007 实现账号目录准备、旧版 auth 导入和默认 config 创建
- [x] T008 实现共享目录初始化、junction/符号链接/硬链接创建和已有文件备份

## Phase 3：启动与迁移

- [x] T009 实现 Cursor 路径查找、进程停止与按槽位启动
- [x] T010 实现明文 zip 导出，包含账号、共享、旧版兼容文件和 manifest
- [x] T011 实现 zip manifest 校验、zip slip 防护、备份后替换恢复和共享链接重建
- [x] T011a 分析并实现 Codex 软件启动复用槽位 `CODEX_HOME`
- [x] T011b 修正 Codex 桌面 MSIX 不继承 `CODEX_HOME` 时的默认 `.codex` 激活逻辑
- [x] T011c 排查并修正 Codex Desktop 左侧最近对话按 workspace 过滤导致不展示的问题
- [x] T011d 回填 Codex Desktop `.codex-global-state.json` 侧栏索引，修正搜索可见但左侧对话为空的问题

## Phase 4：JavaFX UI 与打包

- [x] T012 实现 JavaFX 主界面、账号列表、详情区、操作按钮和日志区
- [x] T013 实现后台任务封装，避免 UI 线程被账号准备/导出/恢复/启动阻塞
- [x] T014 实现 `scripts/package-app.ps1`，调用 JDK17 `jpackage` 生成 app image

## Phase 5：验证

- [x] T015 添加单元测试覆盖 JWT、账号准备、导出、恢复和 manifest
- [x] T016 运行 `mvn -f codex-account-switcher\pom.xml clean test package`
- [x] T017 运行 `codex-account-switcher\scripts\package-app.ps1`
- [x] T018 确认 `target\dist\CodexAccountSwitcher\CodexAccountSwitcher.exe` 存在

## 执行记录

### D001

- 执行内容：创建本规格目录与四个 Spec Kit 文档，记录 JavaFX EXE、账号切换、明文导出和备份后替换恢复要求。
- 测试命令：`Test-Path specs/006-codex-account-switcher-javafx`
- 测试结果：目录和四个目标文档均已创建。
- 自检结论：通过。

### B001

- 执行内容：新增 `codex-account-switcher` Maven JavaFX 项目，完成账号读取/准备、共享链接、Cursor 启动、明文 zip 导出、备份后替换恢复、JavaFX 主界面和 jpackage 打包脚本。
- 测试命令：`mvn -f codex-account-switcher\pom.xml clean test package`
- 测试结果：BUILD SUCCESS；6 个 JUnit 测试通过。
- 自检结论：通过。测试覆盖 JWT 解析、固定 7 槽位、默认 config、旧版 auth 导入、导出 manifest、跳过账号共享目录和恢复备份替换。

### B002

- 执行内容：运行 `scripts/package-app.ps1`，调用 `C:\workspace\tools\jdk17\jdk-17.0.18+8\bin\jpackage.exe` 生成 Windows app image。
- 测试命令：`powershell -NoProfile -ExecutionPolicy Bypass -File codex-account-switcher\scripts\package-app.ps1`；`Test-Path codex-account-switcher\target\dist\CodexAccountSwitcher\CodexAccountSwitcher.exe`
- 测试结果：脚本成功，目标 exe 存在。
- 自检结论：通过。产物路径为 `C:\workspace\ju-chat\codex-account-switcher\target\dist\CodexAccountSwitcher\CodexAccountSwitcher.exe`。

### B003

- 执行内容：确认 `codex` 会读取 `CODEX_HOME`，并新增“启动 Codex”入口；启动时准备所选槽位目录，设置进程级 `CODEX_HOME` 与 `CODEX_ACCOUNT_SLOT`，优先查找显式 `codex.switcher.codexExe`、PATH 和 Cursor 扩展目录中的 `codex.exe`，对 CLI 使用 `codex app` 启动桌面 Codex。
- 测试命令：`codex --help`；`$env:CODEX_HOME='C:\workspace\_codex_home_probe'; codex debug config`；`mvn -f codex-account-switcher\pom.xml test`
- 测试结果：`codex --help` 显示 `app` 子命令；探测命令报错中引用了设置的 `CODEX_HOME`，证明启动链路读取该变量；Maven 测试通过。
- 自检结论：通过。该登录态复用只保证通过本工具启动的 Cursor/Codex 子进程生效，不保证外部快捷方式启动的进程继承槽位环境。

### B004

- 执行内容：根据手动验证反馈修正 Codex 桌面启动逻辑。确认 `codex app` 打开 MSIX 桌面端后，桌面端会自行启动 `C:\Program Files\WindowsApps\OpenAI.Codex_...\app\resources\codex.exe`，不会继承工具传给 Cursor 扩展 `codex.exe` 的 `CODEX_HOME`；因此启动 Codex 桌面端前先将所选槽位的 `auth.json` 与 `config.toml` 同步到默认 `%USERPROFILE%\.codex`，并写入 `active_account_slot.txt`。
- 测试命令：`mvn -f codex-account-switcher\pom.xml test`
- 测试结果：BUILD SUCCESS；9 个 JUnit 测试通过。
- 自检结论：通过。Cursor 仍使用进程级 `CODEX_HOME`；Codex 桌面端使用默认 `.codex` 激活文件兼容 MSIX 后台服务。

### B005

- 执行内容：排查 Codex Desktop “搜索/归档能看到，但左侧对话列表看不到最近记录”的原因。确认共享历史的 `session_index.jsonl` 中存在最近会话，且会话文件 `session_meta.cwd` 指向 `c:\workspace`；而未传 workspace 启动 Desktop 时会进入 `%USERPROFILE%\Documents\Codex\...` 的 projectless/generated workspace，左侧主列表按当前 workspace/UI 状态过滤，导致最近记录不显示。
- 修正策略：启动 Codex Desktop 时传入 workspace path。优先使用系统属性 `codex.switcher.codexWorkspace`；未配置时从所选账号最近会话文件的 `session_meta.cwd` 推断；失败时才回退用户目录。
- 测试命令：`mvn -f codex-account-switcher\pom.xml test`
- 测试结果：BUILD SUCCESS；11 个 JUnit 测试通过。
- 自检结论：通过。Codex Desktop 启动参数会携带推断出的 workspace path，以便左侧主对话列表命中最近会话所属工作区。

### B006

- 执行内容：根据手动验证反馈继续排查，确认搜索可见但左侧“对话”仍为空时，默认 `.codex\.codex-global-state.json` 只包含 Desktop 自建 projectless 会话 ID，未包含 Cursor/插件生成的最近会话 ID。实现启动前回填：从所选账号 `session_index.jsonl` 倒序读取最近会话，读取对应会话文件第一行 `session_meta.cwd`，写入默认 `.codex-global-state.json` 的 `projectless-thread-ids` 与 `thread-workspace-root-hints`。同时从共享文件列表移除 `.codex-global-state.json` 和 `.bak`，避免 Desktop 原子重写打断硬链接并覆盖 UI 状态；Codex 启动顺序调整为先停止旧进程，再激活默认 `.codex` 并回填状态，最后启动新 Codex，避免退出写盘覆盖回填结果。
- 测试命令：`mvn -f codex-account-switcher\pom.xml test`
- 测试结果：BUILD SUCCESS；12 个 JUnit 测试通过。
- 自检结论：通过。新测试覆盖默认 Codex home 激活时回填 Desktop 侧栏状态。
