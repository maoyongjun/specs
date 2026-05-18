# 需求检查清单

- [x] 规格目录已创建于 `C:\workspace\ju-chat\specs`
- [x] 已明确目标代码文件 `AiController.java`
- [x] 已明确四个受影响接口：`on`、`onV2`、`batchOn`、`batchOnV2`
- [x] 已明确凌晨时段校验失败时需要返回配置错误
- [x] 已明确错误提示应包含 `配置时间不正确` 和具体凌晨时段示例
- [x] 已明确工作时间段为 `7:00-23:00`
- [x] 已明确 `50%` 占比门槛
- [x] 已引用 `DelayMessageServiceImpl.sendDelayMessage(...)` 作为时间区间语义参考
