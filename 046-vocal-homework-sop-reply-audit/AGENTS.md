# 规格执行说明

本目录记录声乐作业点评从 `homework-review` 迁移到 `sop-reply` 相关代码的核查结论。本次需求是文档化核查分析，不修改业务代码。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\046-vocal-homework-sop-reply-audit`
- 目标项目：`C:\workspace\ju-chat\fc`
- 相关模块：`delay-mq`、`sop-reply`、`homework-review`

## 当前目标

- 确认声乐作业点评迁移到 `sop-reply` 的代码位置。
- 确认 2026-04-16 至 2026-04-18 附近的迁移提交和后续匹配逻辑提交。
- 记录当前是否仍可能走 `homework-review`，并区分代码事实与运行时配置未知点。

## 核查结论摘要

- `delay-mq` 的作业点评入口在 `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\service\AppTask.java`。
- `sop-reply` 的 FC 调用封装在 `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\service\VoiceService.java`。
- `sop-reply` 新 handler 在 `C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\service\SopReply.java`。
- `homework-review` 旧 handler 仍在 `C:\workspace\ju-chat\fc\homework-review\src\main\java\com\drh\homework\service\AppTask.java`。
- 当前仓库代码不是无条件切到 `sop-reply`：`homeWorkSopReplyPercent` 灰度命中才先调用 `sop-reply`；未命中或异常时仍调用 `homework-review`。
- `sopReply time window config is empty` 表示 `sop-reply` 没拿到 `ai:configTime:{campDateId}:{dayNum}` 缓存，也没能从 `/endpoint/ai/user/info` 的 `jsonObject.live_end_time` 推导出时间窗口；该分支会直接返回 false，阻断后续识别和点评。
- 与旧 `homework-review` 不同，当前 `SopReply.checkTimeIsOpen()` 没有 fallback 到旧 `enableTime` 配置或特殊企微账号时间窗口。
- 现场排查时先确认三件事：作业点评开关已开启，课程时间仍在允许窗口，链路实际由 `Delay-mq -> sop-reply` 进入。

## 执行原则

- 本目录仅做核查文档，不执行代码改动。
- 不把仓库默认值等同为线上配置值；线上是否 100% 走 `sop-reply` 必须另查运行时配置。
- 不触碰 `fc` 仓库已有未提交变更。
- 后续如要修改业务代码，必须另起实现规格并先完成参数来源、调用顺序、fallback 和测试门禁。

## 强制门禁

后续任何实现前必须完成以下检查：

- 确认 `homeWorkSopReplyPercent` 线上配置值。
- 确认 FC 环境变量 `sopReplyServiceName`、`sopReplyFunctionName`、`sopReplyFunctionNameProd`、`sopReplyFunctionNameTest`。
- 确认线上 `sop-reply` 函数 handler 是否绑定到 `com.drh.homework.service.SopReply::handleRequest`。
- 确认支持消息类型、异常 fallback、群聊分支、识别-only 分支不被误改。
- 排查 `sopReply time window config is empty` 时必须同时确认 Redis key `ai:configTime:{campDateId}:{dayNum}`、`CenterUtil.selectUserJson()` 请求参数、接口返回 `jsonObject.live_end_time` 和 `sys_domain`。
- 若要解释“为什么这次没点评”，优先按开关、时间窗口、调用链三步核对，而不是先看识别结果。
- 如修改灰度比例、函数名或兜底策略，必须记录业务确认和回滚策略。

## 重点代码位置

- `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\service\AppTask.java`
- `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\service\VoiceService.java`
- `C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\service\SopReply.java`
- `C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\sop\SopConfigSender.java`
- `C:\workspace\ju-chat\fc\homework-review\src\main\java\com\drh\homework\service\AppTask.java`

## 文档维护

- `spec.md` 记录核查背景、代码事实、边界和成功标准。
- `tasks.md` 记录已执行的只读核查任务和后续运行时配置核验任务。
- `checklists/requirements.md` 记录本次文档质量与实施就绪度。
- 每次用户补充或纠正口径时，追加 Dxxx 执行记录，并同步更新相关文档。
