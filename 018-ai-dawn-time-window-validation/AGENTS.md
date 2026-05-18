# 规格执行说明

本目录记录 `018-ai-dawn-time-window-validation`，作用范围包含：

- 规格文档：`C:\workspace\ju-chat\specs\018-ai-dawn-time-window-validation`
- 目标代码：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\controller\AiController.java`
- 参考逻辑：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\DelayMessageServiceImpl.java`

## 当前目标

- 在 `AiController` 的 `on`、`onV2`、`batchOn`、`batchOnV2` 四个入口上，新增“凌晨时段配置”校验。
- 当配置的凌晨时间段不满足规则时，直接返回报错提示，阻止继续上线。
- 报错文案需要明确指出配置不正确，并展示被判定为凌晨时段的区间，例如 `【1:00-6:00】是凌晨时段`。

## 参考约束

- 时间判断语义参考 `DelayMessageServiceImpl.sendDelayMessage(...)` 中对 `startHour` / `endHour` 和跨天区间的处理方式。
- 这里的校验只约束“凌晨时段”的配置合法性，不改动 `sendDelayMessage(...)` 的实现。
- 规范只描述需求和验收标准，不编写实现代码。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录后续实现步骤与验证项。
- `checklists/requirements.md` 用于验证规格质量和实施完整性。
