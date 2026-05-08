# 规格执行说明

本目录记录 `008-jenkins-scm-config-save-fix`，作用范围包含：

- 规格文档：`C:\workspace\ju-chat\specs\008-jenkins-scm-config-save-fix`
- 目标 Jenkins：`http://60.205.247.168:10000/`
- 目标作业：`drh-endpoint(dev)`

## 当前阶段

- Spec Kit 文档阶段已完成。
- 远程诊断和修复阶段尚未执行。
- 当前目标是修复配置页修改源码分支后保存失败的问题。

## 实现约束

- 不得把明文密码、私钥、Jenkins secret 或凭据内容写入仓库文档。
- 远程操作前必须备份目标作业 `config.xml`。
- 只处理 `drh-endpoint(dev)` 单个作业，避免影响其他 Jenkins job。
- 默认不升级 Jenkins、不批量升级插件、不重建作业。
- 修复必须保留原有仓库地址、凭据引用、构建步骤、参数、触发器和通知配置。
- 作业名包含括号，命令、URL 和路径中必须正确转义。
- 如果直接编辑 Jenkins 文件，必须记录 reload 或重启方式和影响窗口。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录诊断步骤、修复拆分、执行记录、验证结果和回滚原则。
- `checklists/requirements.md` 用于验证规格质量、凭据安全和实施就绪度。
- 执行远程修复后，必须更新 `tasks.md` 中未完成任务和执行记录。
