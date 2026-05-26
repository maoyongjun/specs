# 任务清单：Jumpserver 堡垒机安装确认与使用指引

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：本任务是纯运维确认，测试表现为现场证据核对、访问验证和文档自检，不涉及代码单测。

## Phase 1：环境事实确认

- [ ] T001 复查用户需求和本目录 `AGENTS.md`，确认本次任务仅做 Jumpserver 安装确认与使用指引，不扩展到安装、升级或权限改造。
- [ ] T002 确认目标环境、部署区、主机名、域名或 IP，以及当前已知的 Jumpserver 入口线索。
- [ ] T003 用现场证据确认 Jumpserver 的部署形态：systemd、Docker Compose、K8s 或其他。
- [ ] T004 确认服务状态、监听端口、健康检查页面或登录页是否存在，并记录证据来源。
- [ ] T005 确认认证方式、资产范围、权限边界和审计查看入口。

**检查点**：不得在未完成 T001-T005 前写死“已安装”结论。

## Phase 2：风险门禁

- [ ] T006 检查是否存在多个 Jumpserver 实例或多个部署区，避免混写成同一套环境。
- [ ] T007 检查是否存在只看到进程、只看到容器或只看到端口但没有完整证据链的情况。
- [ ] T008 检查安装确认是否误把“能访问登录页”当作“服务健康可用”，必须同时确认服务状态。
- [ ] T009 检查使用指引是否覆盖登录、选资产、发起会话、退出和常见失败处理。
- [ ] T010 检查文档中是否误写真实账号、密码、私钥、Token 或其他敏感信息。

**检查点**：T006-T010 必须有明确结论；发现风险时先更新 `spec.md` 的“历史问题防漏分析”。

## Phase 3：文档交付

- [ ] T011 按规格整理 `spec.md`，写清楚目标、范围、用户场景、边界、成功标准和假设。
- [ ] T012 按规格整理 `AGENTS.md`，写清楚作用范围、执行原则、关键参数和维护原则。
- [ ] T013 按规格整理 `checklists/requirements.md`，补齐内容质量、需求完整性、参数完整性和实施就绪度检查项。
- [ ] T014 按规格整理 `tasks.md`，确保阶段划分和执行记录可用于后续回填。
- [ ] T015 补充或整理使用指引，覆盖登录、资产、会话和异常处理步骤。

**检查点**：文档应能独立阅读并直接指导现场确认。

## Phase 4：验证与回填

- [ ] T016 用现场证据回填安装确认结果，明确“已安装 / 未安装 / 暂无法确认”。
- [ ] T017 用现场证据回填部署区/实例、访问入口和认证方式。
- [ ] T018 按一条标准使用路径自检文档可操作性，确认步骤顺序正确且不缺关键环节。
- [ ] T019 检查文档中没有敏感信息和无效占位符残留。
- [ ] T020 将现场确认结果记录到 `spec.md`、`tasks.md`、`AGENTS.md` 和 `checklists/requirements.md` 对应的执行记录中。

**检查点**：完成 T016-T020 后，才算安装确认文档闭环完成。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 Jumpserver 堡垒机安装确认与使用指引的 Spec Kit 文档骨架，覆盖规格、任务、执行原则和验收清单。
- 验证方式：静态检查文档结构、字段覆盖和占位符状态。
- 自检结论：当前仅完成文档创建，尚未写入现场确认结果。

### D002 - 实施记录

- 实施内容：已在当前主机 `DESKTOP-37KF3KE` 做初步核查，未发现 Jumpserver 相关服务、进程、容器或常见监听端口。
- 验证方式：`Get-Service`、`Get-Process`、`Get-NetTCPConnection -State Listen`、`docker ps`（本机无 docker 命令）。
- 自检结论：当前仅能确认本机未发现 Jumpserver 安装痕迹，若目标是其他服务器，需要补充目标主机或地址后继续核查。
- 实施内容：已远程核查 `60.205.247.168`（主机名 `cy-cicd`），确认存在 Jumpserver 安装目录、数据目录、安装器目录和 Jumpserver 镜像，但未发现运行中的 `jms_*` 容器或监听端口。
- 验证方式：`docker ps -a`、`docker images`、`ls -la /opt/jumpserver`、`ls -la /data/jumpserver`、`find /opt/jumpserver-installer-v4.0.1 ...`、`bash /opt/jumpserver-installer-v4.0.1/jmsctl.sh status`、`ss -lntp`。
- 自检结论：该服务器已确认存在 Jumpserver 安装痕迹，但当前不是可用的在线堡垒机服务；如需继续使用，需要进一步确认是否应启动/恢复该堆栈。
- 实施内容：已远程核查 `182.92.157.63`（主机名 `drh-test`），未发现 Jumpserver 安装目录、控制脚本、系统服务、运行进程、Docker 运行容器或 Jumpserver 相关 RPM 包。
- 验证方式：`systemctl`、`ss -lntp`、`rpm -qa`、`find /opt`、`find /etc`、`find /usr/local`、`find /`、`mysql` 数据库检查。
- 自检结论：该服务器当前没有 Jumpserver 安装证据，结论应记为“未安装/未发现安装痕迹”，而不是在线堡垒机。

### D003 - 纠正记录模板

- 触发原因：待补充确认失败、部署区变更、多实例混淆、认证方式补充或使用指引修订。
- 修正内容：写清楚旧口径和新口径。
- 文档同步：说明同步了哪些文件。
- 验证结果：说明证据或现场确认结果。

### D004 - 安装启动记录

- 触发原因：用户要求在 `60.205.247.168` 上安装并启动 Jumpserver。
- 实施内容：复用现有 `/opt/jumpserver-installer-v4.0.1` 安装器执行 `start`，创建 `jms_net` 网络并启动 `jms_web`、`jms_core`、`jms_celery`、`jms_koko`、`jms_lion`、`jms_chen`、`jms_mysql`、`jms_redis`。
- 验证方式：`bash /opt/jumpserver-installer-v4.0.1/jmsctl.sh start`、`bash /opt/jumpserver-installer-v4.0.1/jmsctl.sh status`、`docker ps`、`ss -lntp`、`curl http://127.0.0.1`。
- 自检结论：Jumpserver 已成功启动并提供 Web 入口，当前监听 `80` 和 `2222`，容器健康状态已转为 `healthy`。
