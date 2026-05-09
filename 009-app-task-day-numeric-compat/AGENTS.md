# 规格执行说明

本目录记录 `009-app-task-day-numeric-compat`，作用范围包含：

- 规格文档：`C:\workspace\ju-chat\specs\009-app-task-day-numeric-compat`
- 目标代码：`C:\workspace\ju-chat\coze_plugin\external-task\src\main\java\com\drh\service\AppTask.java`
- 目标代码：`C:\workspace\ju-chat\coze_plugin\external-task\src\main\java\com\drh\service\DownTask.java`
- 目标代码：`C:\workspace\ju-chat\coze_plugin\external-task\src\main\java\com\drh\service\TaskDayNormalizer.java`
- 目标测试：`C:\workspace\ju-chat\coze_plugin\external-task\src\test\java\com\drh\service\AppTaskTest.java`

## 当前目标

- 兼容入参 `day` 为数字字符串 `0`、`1`、`2`、`3`、`4`、`5`、`6`。
- 数字入参必须在任务处理前归一化为 `d0`、`d1`、`d2`、`d3`、`d4`、`d5`、`d6`。
- 原有 `d0` 到 `d6` 入参行为保持不变。

## 实现约束

- 只修改 `external-task` 模块中与 `AppTask`、`DownTask` 的 `day` 解析相关的代码。
- 不调整任务配置 key 结构，不改 Redis、OTS、外部接口调用逻辑。
- 对非法 `day` 值不新增兜底任务，继续保持无候选任务的行为。
- 必须添加单元测试覆盖共享归一化逻辑和数字 `0` 到 `6` 的任务候选解析。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录实现步骤、验证命令和结果。
- `checklists/requirements.md` 用于验证规格质量和实施完整性。
