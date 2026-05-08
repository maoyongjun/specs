# 任务清单：Jenkins 源码分支配置保存报错修复

**输入**：来自 `specs/008-jenkins-scm-config-save-fix/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：通过 Jenkins 配置页保存验证、目标作业 `config.xml` 检查、Jenkins 日志检查和一次构建或 SCM 校验验证。  

## Phase 1：文档与访问准备

- [x] T001 创建 Spec Kit 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 记录目标 Jenkins Web 地址、SSH 端口、目标作业和错误堆栈摘要
- [x] T003 明确凭据处理要求：不在文档中保存明文密码、私钥或 Jenkins secret
- [x] T004 确认操作者已通过安全渠道持有 SSH/Jenkins 管理权限
- [x] T005 确认目标作业当前是否有构建运行或他人正在修改配置

## Phase 2：备份与现场采集

- [x] T006 登录服务器并定位 Jenkins home、目标作业目录和服务启动方式
- [x] T007 备份目标作业 `config.xml`，备份文件名带时间戳
- [x] T008 记录 Jenkins 版本、Java 版本、Git/SCM/Maven 相关插件版本
- [x] T009 导出或复制目标作业当前 `config.xml` 供本地比对
- [x] T010 采集保存失败同一时间窗口的 Jenkins 日志
- [x] T011 如可行，在 UI 上复现一次保存失败并记录失败时间点

## Phase 3：诊断 SCM 配置结构

- [x] T012 检查目标作业 XML 中 `<scm>` 节点的 class、plugin、仓库、凭据和分支配置
- [x] T013 检查是否存在空 SCM、多 SCM、重复 SCM、旧插件字段或异常嵌套
- [x] T014 对比同一 Jenkins 上可正常保存分支的同类型 Maven job SCM XML
- [x] T015 判断错误来源：作业 XML 结构异常、插件兼容问题、页面提交参数异常或浏览器表单状态异常
- [x] T016 在 `tasks.md` 执行记录中写入诊断结论和证据

## Phase 4：最小化修复

- [x] T017 制定修复方案，优先只修正目标作业 SCM 配置结构
- [x] T018 修复前再次确认当前 `config.xml` 与备份一致，避免覆盖并发修改
- [x] T019 按方案修正 SCM 节点或通过 Jenkins 受支持接口重写目标作业配置
- [x] T020 reload 目标作业配置；仅在必要且可接受时重启 Jenkins
- [x] T021 确认仓库地址、凭据引用、构建步骤、触发器、参数和通知配置未被误改

## Phase 5：验证与回滚记录

- [x] T022 打开 `drh-endpoint(dev)` 配置页，修改源码分支并保存成功
- [x] T023 重新打开配置页，确认源码分支显示为保存后的值
- [x] T024 检查目标作业 `config.xml`，确认 SCM 分支配置已正确写入
- [x] T025 检查 Jenkins 日志，确认验证窗口内无 `SCMS.parseSCM` 和 `JSONObject["scm"] is not a JSONObject`
- [x] T026 触发一次构建、参数校验或 SCM 轮询检查，确认 Jenkins 能读取源码配置
- [x] T027 在 `tasks.md` 中记录最终状态、修改摘要、验证命令、日志窗口和回滚步骤

## 当前问题摘要

- Jenkins Web：`http://60.205.247.168:10000/`
- 目标作业：`drh-endpoint(dev)`
- 配置页：`http://60.205.247.168:10000/job/drh-endpoint(dev)/configure`
- 现象：修改源码分支后保存失败
- 核心异常：`net.sf.json.JSONException: JSONObject["scm"] is not a JSONObject`
- 关键堆栈：
  - `hudson.scm.SCMS.parseSCM(SCMS.java:57)`
  - `hudson.model.AbstractProject.submit(AbstractProject.java:1827)`
  - `hudson.maven.MavenModuleSet.submit(MavenModuleSet.java:1209)`
- 初步判断：保存请求中的 `scm` 字段不是 Jenkins 期望的单个 JSON object，常见触发点包括 SCM 配置节点损坏、旧插件/多 SCM 残留、页面表单提交结构异常或插件兼容问题。最终原因必须以服务器现场配置和日志为准。

## 执行记录

### D001

- 执行内容：创建本规格目录与四个 Spec Kit 文档，记录 Jenkins 作业、配置页、异常摘要、凭据不落盘要求、诊断和修复任务拆分。
- 测试命令：`Test-Path specs/008-jenkins-scm-config-save-fix`
- 测试结果：目录和目标文档已创建。
- 自检结论：通过。

### D002 - 访问确认与现场采集

- 执行时间：2026-05-08 18:34 +0800。
- 执行内容：使用安全渠道提供的 SSH 与 Jenkins 管理账号登录；未将密码写入文件。
- Jenkins 版本：`2.462.1`。
- Java 版本：`openjdk version "11.0.2"`。
- Git 版本：`git version 1.8.3.1`。
- Jenkins 启动方式：root 用户执行 `java -jar /home/soft/jenkins/jenkins.war --httpPort=10000`。
- Jenkins home：`/root/.jenkins`。
- 目标作业目录：`/root/.jenkins/jobs/drh-endpoint(dev)`。
- 作业状态：`buildable=true`，`inQueue=false`，最近构建 `#1086` 已完成且结果为 `SUCCESS`，未发现当前构建运行。
- `config.xml` 备份：`/root/.jenkins/jobs/drh-endpoint(dev)/config.xml.bak.20260508-183417`。
- 原始 `config.xml` 未落盘到本地，避免保存潜在 Jenkins secret；诊断通过 Jenkins API 读取结构摘要并在服务器端保留原始备份。

### D003 - SCM 结构诊断

- 目标作业根节点：`maven2-moduleset plugin="maven-plugin@3.22"`。
- 目标作业 SCM：单个 `<scm class="hudson.plugins.git.GitSCM">`，无空 SCM、Multi SCM 或重复 SCM XML 节点。
- 仓库地址：`http://182.92.157.63:20000/wangyu/drh.git`。
- SCM 分支：修复前为 `*/kk-merge`。
- 凭据：仅记录凭据 ID 引用，未记录 secret。
- SCM/相关插件：`git@5.5.2`、`git-client@5.0.3`、`scm-api@696.v778d637b_a_762`、`maven-plugin@3.22`、`build-timeout@1.24`、`github@1.34.5`。
- 同类 Maven job 对比：`drh-callback(dev)` 同为 `maven2-moduleset` + 单个 `hudson.plugins.git.GitSCM` + 单分支结构，未发现目标作业 XML 层面的多 SCM 异常。
- 复现结果：Playwright 打开配置页并提交后复现 `JSONObject["scm"] is not a JSONObject`，提交 URL 为 `/job/drh-endpoint(dev)/configSubmit`。
- 诊断结论：根因不是目标作业 `config.xml` 中存在重复 `<scm>`，而是旧插件前端脚本在 Jenkins 2.462.1 配置页上抛出 `$$ is not defined`，中断 Jenkins 表单行为，导致提交时 `json.scm` 不是 Jenkins 期望的单个 SCM object。

### D004 - 修复实施

- 修复策略：不修改仓库地址、凭据、构建步骤、触发器、参数或通知；只修补导致配置页 JavaScript 中断的旧插件静态脚本，并通过 UI 保存刷新目标作业配置。
- Build Timeout 插件补丁：
  - 备份：`/root/.jenkins/plugins/build-timeout/WEB-INF/lib/build-timeout.jar.bak.20260508-184023`
  - 备份：`/root/.jenkins/plugins/build-timeout.jpi.bak.20260508-184023`
  - 修改：`hudson/plugins/build_timeout/nestedHelp.js` 中 `$$(".build-timeout-nested-help")` 改为带 `document.querySelectorAll` fallback 的实现。
- Jenkins 重启：旧 PID `1554`，新 PID `10943`，HTTP 登录页约 7 秒恢复。
- GitHub 插件补丁：
  - 备份：`/root/.jenkins/plugins/github/js/warning.js.bak.20260508-185309`
  - 备份：`/root/.jenkins/plugins/github.jpi.bak.20260508-185309`
  - 修改：`plugin/github/js/warning.js` 中 `$$` 查询改为 `document.querySelector`。
- 作业配置差异：目标作业 `config.xml` 与原始备份相比，仅 `<scm>` 的插件标记从 `git@4.12.1` 刷新为当前已安装的 `git@5.5.2`；仓库地址、凭据 ID、构建包装器、发布器、触发器和分支值保持不变。

### D005 - 验证结果

- 配置页脚本验证：重新打开 `drh-endpoint(dev)` 配置页后，无插件 `$$ is not defined` 页面错误；只剩浏览器对非 HTTPS `Cross-Origin-Opener-Policy` 的提示。
- SCM JSON 验证：提交 payload 中 `json.scm` 类型为 `object`，`stapler-class` 为 `hudson.plugins.git.GitSCM`，不再是异常数组/非对象。
- UI 保存验证：通过配置页将 SCM 分支探针值写入并保存成功，页面返回作业首页；随后通过配置页恢复为 `*/kk-merge`。
- XML 验证：探针保存后 `config.xml` 中 SCM 分支可写入探针值；恢复后确认 SCM 分支为 `*/kk-merge`。
- 日志验证窗口：2026-05-08 18:53-18:56 +0800；未出现 `SCMS.parseSCM`、`JSONObject["scm"] is not a JSONObject` 或 `net.sf.json.JSONException`。
- SCM 读取校验：在 Jenkins 服务器执行 `git ls-remote --heads http://182.92.157.63:20000/wangyu/drh.git refs/heads/kk-merge`，返回 `48e34493552dc23789bfc8902e281819058337e7 refs/heads/kk-merge`。
- 最终 Jenkins 进程：`10943 java -jar /home/soft/jenkins/jenkins.war --httpPort=10000`。
- 最终目标分支：`*/kk-merge`。

### D006 - 剩余风险

- 目标 Jenkins 仍存在多个旧插件可更新，且部分插件更新中心显示最新版本与当前 Jenkins core 版本不兼容；本次未做批量升级。
- Maven job 配置页会动态渲染多份 Git SCM 表单片段。修复后表单提交已恢复为单个 `json.scm` object；如后续用户发现普通可见分支输入未写入，应优先使用 Jenkins `config.xml` API 或同步所有重复分支输入后保存，再安排插件/Jenkins core 兼容性升级窗口。

## 回滚原则

- 修复前必须备份原始 `config.xml`。
- 回滚时优先停止或暂停目标作业配置变更，将备份 `config.xml` 还原到目标作业目录，再执行 Jenkins reload 或安全重启。
- 回滚后必须重新打开目标配置页并检查 Jenkins 日志，确认恢复到修复前行为或恢复到可编辑状态。

## 本次回滚步骤

- 作业配置回滚：将 `/root/.jenkins/jobs/drh-endpoint(dev)/config.xml.bak.20260508-183417` 复制回 `/root/.jenkins/jobs/drh-endpoint(dev)/config.xml`，再重启 Jenkins 或通过 Jenkins 受支持接口 reload 作业。
- Build Timeout 插件回滚：将 `/root/.jenkins/plugins/build-timeout/WEB-INF/lib/build-timeout.jar.bak.20260508-184023` 复制回 `/root/.jenkins/plugins/build-timeout/WEB-INF/lib/build-timeout.jar`，将 `/root/.jenkins/plugins/build-timeout.jpi.bak.20260508-184023` 复制回 `/root/.jenkins/plugins/build-timeout.jpi`，然后重启 Jenkins。
- GitHub 插件回滚：将 `/root/.jenkins/plugins/github/js/warning.js.bak.20260508-185309` 复制回 `/root/.jenkins/plugins/github/js/warning.js`，将 `/root/.jenkins/plugins/github.jpi.bak.20260508-185309` 复制回 `/root/.jenkins/plugins/github.jpi`，然后重启 Jenkins。
- 回滚验证：重新打开目标配置页，检查 `config.xml` 分支、Jenkins 日志和配置页保存行为。
