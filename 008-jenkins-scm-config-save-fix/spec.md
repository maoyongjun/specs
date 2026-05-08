# 功能规格：Jenkins 源码分支配置保存报错修复

**功能目录**: `008-jenkins-scm-config-save-fix`  
**创建日期**: 2026-05-08  
**状态**: Ready for Implementation  
**输入**: 用户反馈 Jenkins 作业 `drh-endpoint(dev)` 在配置页面修改源码分支并保存时失败，配置页为 `http://60.205.247.168:10000/job/drh-endpoint(dev)/configure`，错误为 `net.sf.json.JSONException: JSONObject["scm"] is not a JSONObject`，堆栈入口包含 `hudson.scm.SCMS.parseSCM`、`hudson.model.AbstractProject.submit` 和 `hudson.maven.MavenModuleSet.submit`。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 安全定位 Jenkins 作业配置问题（优先级：P1）

维护者需要在不破坏当前 Jenkins 作业和历史配置的前提下，确认 `drh-endpoint(dev)` 保存失败的原因，判断是作业 `config.xml` 中 SCM 配置异常、页面提交参数异常、插件兼容问题，还是多 SCM/旧插件残留导致 `scm` 字段结构不符合 Jenkins 预期。

**独立测试**：进入服务器后先备份 Jenkins home 与目标作业 `config.xml`，读取目标作业 XML、Jenkins 版本、SCM 相关插件版本和最近 Jenkins 日志，形成诊断结论。

**验收场景**：

1. **Given** 已获得授权访问 Jenkins 服务器，**When** 开始诊断，**Then** 必须先备份 `drh-endpoint(dev)` 的 `config.xml`。
2. **Given** 作业保存失败，**When** 查看 Jenkins 日志，**Then** 能定位与 `JSONObject["scm"] is not a JSONObject` 同一时间窗口的异常记录。
3. **Given** 目标作业是 Maven job，**When** 检查 XML 和插件，**Then** 能说明 `scm` 字段期望结构、实际结构和疑似触发点。

### 用户故事 2 - 让源码分支修改可以保存（优先级：P1）

维护者需要修复 `drh-endpoint(dev)` 的 SCM 配置，使用户在配置页修改源码分支后点击保存不再抛出 `JSONObject["scm"] is not a JSONObject`，且原有仓库地址、凭据、构建步骤和触发器保持不变。

**独立测试**：将源码分支修改为一个测试分支值并保存，再恢复或保留目标分支值，验证配置页面保存成功、`config.xml` 中分支配置正确、作业能够进入一次构建或 SCM 轮询检查。

**验收场景**：

1. **Given** 已备份原始配置，**When** 修复 SCM 配置，**Then** 只修改与 SCM 保存失败相关的最小配置范围。
2. **Given** 用户在配置页修改分支，**When** 点击保存，**Then** 页面不再返回 JSON 异常堆栈。
3. **Given** 保存成功，**When** 重新打开配置页，**Then** 源码管理区域显示的分支值与保存值一致。
4. **Given** 保存后的作业配置，**When** 触发构建或执行配置校验，**Then** Jenkins 能识别 SCM 配置且不出现 `SCMS.parseSCM` 异常。

### 用户故事 3 - 留下可回滚和可复查记录（优先级：P2）

维护者需要记录修复前后的配置差异、备份路径、执行命令、验证结果和回滚方式，便于后续排查同类 Jenkins 作业或在修复产生副作用时恢复。

**独立测试**：打开 `tasks.md`，验证包含备份路径、诊断结论、修改摘要、验证命令、最终状态和回滚步骤。

**验收场景**：

1. **Given** 修复开始，**When** 生成备份，**Then** 备份路径写入 `tasks.md`。
2. **Given** 修改了 Jenkins 作业配置，**When** 完成验证，**Then** 文档记录修改前后关键差异。
3. **Given** 后续需要回滚，**When** 按文档执行，**Then** 可从备份 `config.xml` 恢复目标作业。

## 边界情况

- 文档不得保存明文服务器密码、Jenkins 登录密码、SSH 私钥或 Jenkins 凭据 ID 对应的密钥内容。
- 目标 Jenkins 对外地址为 `60.205.247.168`，Web 端口为 `10000`，SSH 端口为 `22`；访问凭据由操作者通过安全渠道使用，不写入仓库。
- 作业名包含括号：`drh-endpoint(dev)`，脚本访问 Jenkins URL 或文件路径时必须正确处理 URL 编码和 shell 转义。
- 目标作业是 Maven job，堆栈显示 `hudson.maven.MavenModuleSet.submit`，不能按 Pipeline job 的 `Jenkinsfile` 配置方式处理。
- Jenkins 版本、Git/Subversion/Multi SCM 插件版本未知，必须先确认再决定修复方式。
- 如果 `config.xml` 已存在多 SCM、空 SCM、旧插件残留或重复 SCM 节点，必须先备份并最小化修正。
- 如果 Web UI 保存仍失败，可以通过 Jenkins CLI、Script Console 或直接修正 `config.xml` 后 reload job，但必须记录原因和验证结果。
- 如果目标 Jenkins 上存在并发配置修改或正在运行的构建，必须先记录并避免覆盖他人改动。
- 不允许升级 Jenkins 或批量升级插件作为第一选择；只有确认是插件缺陷且有回滚方案时才纳入后续任务。

## 需求 *(必填)*

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下创建本 Spec Kit 目录。
- **FR-002**：系统 MUST 记录目标 Jenkins 地址、目标作业和错误堆栈摘要，但 MUST NOT 记录明文密码。
- **FR-003**：修复前 MUST 备份目标作业 `config.xml`，并记录备份路径。
- **FR-004**：诊断 MUST 检查目标作业 XML 中的 `<scm>` 配置、Jenkins 版本、SCM 相关插件版本和异常日志。
- **FR-005**：修复 MUST 保留原有仓库地址、凭据引用、构建步骤、构建参数、触发器和通知配置。
- **FR-006**：修复 MUST 使配置页修改源码分支后保存成功，不再抛出 `JSONObject["scm"] is not a JSONObject`。
- **FR-007**：修复 MUST 确认保存后的源码分支值已写入目标作业配置。
- **FR-008**：修复 MUST 具备回滚路径，可恢复到修复前的目标作业配置。
- **FR-009**：如果需要直接编辑 Jenkins 文件，MUST 在编辑后执行安全 reload 或重启策略，并记录影响。
- **FR-010**：tasks.md MUST 记录诊断结论、执行命令、配置差异、验证结果和剩余风险。

## 成功标准 *(必填)*

- **SC-001**：本目录包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：`tasks.md` 明确记录已备份目标作业配置，且未写入明文密码。
- **SC-003**：重新打开 `drh-endpoint(dev)` 配置页，修改源码分支并保存成功。
- **SC-004**：保存后目标作业 `config.xml` 中 SCM 分支配置与页面显示一致。
- **SC-005**：Jenkins 日志在验证窗口内不再出现 `SCMS.parseSCM` 或 `JSONObject["scm"] is not a JSONObject` 相关异常。
- **SC-006**：保留回滚说明，可从备份配置恢复。

## 假设

- 本任务的目标是修复单个 Jenkins 作业 `drh-endpoint(dev)`，不是全局 Jenkins 改造。
- 操作者拥有 SSH 和 Jenkins 管理权限，可以读取 Jenkins home、作业配置和系统日志。
- 用户期望变更的是源码管理中的分支配置，不涉及修改仓库地址或 Jenkins 凭据。
- 如需使用用户提供的服务器凭据，凭据只在运行时使用，不落盘到 Spec Kit 文档。
