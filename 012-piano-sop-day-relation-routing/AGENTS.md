# 规格执行说明

本目录记录 `012-piano-sop-day-relation-routing`，作用范围包含：

- 规格文档：`C:\workspace\ju-chat\specs\012-piano-sop-day-relation-routing`
- 目标代码：`C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\service\homeworkhandle\PianoVideoHomeWorkHandleServiceImpl.java`
- 目标代码：`C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\service\SopReply.java`

## 当前目标

- 记录钢琴视频 prompt 中 `D%s` 替换为 `D + logicalDay` 的业务规则。
- 定义 `sku=4` 钢琴过去作业的 SOP 路由规则：使用 `recognizedDay` 取配置，并以 `homeworkDayRelation=CURRENT` 匹配。
- 定义 `sku=4` 钢琴未来作业的发送规则：不走 `FUTURE` 配置分支，直接发送固定预习话术。

## 实现约束

- 钢琴特殊逻辑必须限定在 `sku=4`。
- 非钢琴作业、钢琴当前作业和识别未通过流程必须保持现有行为。
- 未来作业固定话术必须遵守现有 `wxsend=false` 预览模式。
- 过去作业和未来作业分支都必须打印可检索日志。

## 当前实现状态

- `PianoVideoHomeWorkHandleServiceImpl#resolvePianoVideoPrompt` 已实现 `D%s -> D + logicalDay`。
- `SopReply` 已实现钢琴过去作业 `recognizedDay` 路由与 `homeworkDayRelation=CURRENT` 覆写。
- `SopReply` 已实现钢琴未来作业固定话术发送。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录实现步骤、验证命令和结果。
- `checklists/requirements.md` 用于验证规格质量和实施完整性。
