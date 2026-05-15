# 任务清单：Gemini 任务重试超限飞书告警

**输入**：来自 `specs/017-gemini-app-task-retry-feishu-alert/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：通过代码检查或目标模块构建验证飞书通知分支接入。

## Phase 1：规格与范围

- [x] T001 创建 Spec Kit 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确目标文件为 `AppTask.java`
- [x] T003 明确告警固定接收人为 `6d9e5ee3`，并列出必含字段

## Phase 2：实现

- [x] T004 在重试超限失败分支组装飞书通知文案
- [x] T005 使用 `FeiShuUtil.send(...)` 发送给固定飞书 ID
- [x] T006 用独立异常处理保护飞书发送失败，不影响原始任务失败
- [x] T007 保持成功分支和未超限重试分支行为不变

## Phase 3：验证

- [ ] T008 复查代码确保告警文案包含 `unionId`、`songName`、`nickName`、`picId`、`classId`
- [ ] T009 复查飞书调用签名与参考实现一致
- [ ] T010 记录验证结果和剩余风险
