# 需求检查清单

- [x] 规格目录已创建于 `C:\workspace\ju-chat\specs`
- [x] 已明确目标代码文件 `AppTask.java`
- [x] 已明确固定飞书接收人 `6d9e5ee3`
- [x] 已明确消息必须包含 `unionId`、`songName`、`nickName`、`picId`、`classId`
- [x] 已明确使用 `FeiShuUtil.send(...)` 风格发送
- [x] 已明确飞书失败不能掩盖原始任务失败
- [x] 已明确 `retry(...)` 常规延迟重试仍为 60 秒
- [x] 已明确 `retry(...)` 超时或异常退出时也需要飞书告警，并触发 3300 秒兜底延迟重试
- [x] 已明确 `retry(...)` 正常提交成功时不应发送飞书告警或触发兜底延迟重试
