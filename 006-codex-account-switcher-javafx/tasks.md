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
