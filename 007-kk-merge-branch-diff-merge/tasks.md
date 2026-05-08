# 任务清单：kk-merge 内容手工合并到 kk-merge-2026

**输入**：来自 `specs/007-kk-merge-branch-diff-merge/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：使用 `git diff`、`git status` 和必要的构建/编译命令验证。  

## Phase 1：规格与差异确认

- [x] T001 创建 Spec Kit 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 确认 `C:\workspace\drh` 当前分支为 `kk-merge-2026`
- [x] T003 记录分支提交点：`kk-merge-2026` = `ef15b4f8c357e1793dc950cfc129e245ba5b8cab`，`kk-merge` = `0fb398f4d5a5e0c0007a02b253eb98a7f00ed629`
- [x] T004 统计提交层面对比：77 个新增、123 个修改、7 个删除
- [x] T005 识别当前工作区已部分合并，仍与 `kk-merge` 存在 116 个文件差异

## Phase 2：文件级合并

- [x] T006 补齐当前目标缺失的 `kk-merge` 新增文件
- [x] T007 对已新增到工作区的文件进行存在性校验
- [x] T008 对修改文件逐文件对比，吸收 `kk-merge` 的新增业务代码块
- [x] T009 保留 `kk-merge-2026` 中未要求删除的目标侧文件
- [x] T010 避免覆盖当前 staged、unstaged 和 untracked 的用户改动

## Phase 3：验证与记录

- [x] T011 执行 `git diff --name-status kk-merge --` 检查剩余差异
- [x] T012 执行 `git status --short --branch` 记录最终工作区状态
- [x] T013 如可行，执行 Maven 编译或相关模块测试
- [x] T014 更新本任务清单的执行记录和风险说明

## 当前差异摘要

- 仓库：`C:\workspace\drh`
- 当前分支：`kk-merge-2026`
- 源分支：`kk-merge`
- 禁止命令：`git merge`、`git rebase`、`git cherry-pick`
- 允许方式：`git diff`/`git show` 查看源内容，文件复制，逐文件补丁编辑
- 提交层面对比：207 个文件差异，包含 77 个新增、123 个修改、7 个删除
- 初始工作区与源分支对比：116 个文件差异，包含 7 个目标额外文件、2 个源分支缺失文件、107 个内容差异文件
- 合并后 `kk-merge-2026` 当前提交：`1e6686c62df642c8b10e9aa15d1def5329c18751`
- 合并后 `git diff --name-status kk-merge --` 仅剩以下 7 个目标额外文件，默认保留：
  - `drh-endpoint/src/main/java/com/drh/endpoint/constants/DtdTaskEnum.java`
  - `drh-endpoint/src/main/java/com/drh/endpoint/dto/qw/QwKsDto.java`
  - `drh-endpoint/src/main/java/com/drh/endpoint/service/QwKsRecordService.java`
  - `drh-endpoint/src/main/java/com/drh/endpoint/util/DtdUtil.java`
  - `drh-kk-cms/src/main/java/com/drh/kk/cms/service/CommonOrderSumQueryService.java`
  - `drh-kk-cms/src/main/java/com/drh/kk/cms/service/impl/CommonOrderSumQueryServiceImpl.java`
  - `drh-kk-cms/src/test/java/com/drh/kk/cms/plus/HandoverPlusTest.java`

## 执行记录

### D001

- 执行内容：创建本规格目录，记录分支、提交点、差异统计、合并约束和默认不执行删除性变更的原则。
- 测试命令：`Test-Path specs/007-kk-merge-branch-diff-merge`
- 测试结果：目录和四个目标文档均已创建。
- 自检结论：通过。

### B001

- 执行内容：创建临时 worktree 读取 `kk-merge-2026` 基线和 `kk-merge` 源分支内容；补齐缺失新增文件 `aa4dae86-f98b-40c0-b5af-2516c25d9ed1.jpg`；将本地已存在但被 `.git/info/exclude` 忽略的 `drh-kk-cms/src/test/java/spring_test/CodeGenerator.java` 强制纳入索引；对 123 个修改文件执行文件级三方对比合并。
- 备份目录：`C:\workspace\_codex_tmp\drh-manual-merge\backup-current-20260508-merge`
- 合并约束：未执行 `git merge`、`git rebase`、`git cherry-pick`；删除性变更未应用。
- 测试命令：`git diff --name-status kk-merge --`
- 测试结果：只剩 7 个目标额外文件，均为源分支删除项，按本规格保留。
- 自检结论：通过。

### V001

- 执行内容：扫描冲突标记。
- 测试命令：`rg -n "^<<<<<<<|^=======|^>>>>>>>" C:\workspace\drh`
- 测试结果：无匹配结果。
- 自检结论：通过。

### V002

- 执行内容：执行 Maven 编译验证。
- 测试命令：`mvn -DskipTests compile`
- 测试结果：失败在 `drh-server1`，原因是 Maven 使用 JDK17 运行，旧版 Lombok 访问 `com.sun.tools.javac.processing.JavacProcessingEnvironment` 被 JDK 模块限制拦截；后续业务模块未进入编译。
- 自检结论：编译未通过，属于当前 Maven/JDK17 与 Lombok 兼容问题，需要切换 Maven 运行 JDK 或升级 Lombok 后复验。

### V003

- 执行内容：记录最终状态。
- 测试命令：`git status --short --branch`
- 测试结果：`kk-merge-2026` 与 `origin/kk-merge-2026` 对齐；跟踪文件无未提交差异；仍存在任务开始前已有的未跟踪文件。
- 自检结论：通过。
