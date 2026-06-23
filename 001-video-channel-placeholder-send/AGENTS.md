# 规格执行说明

本目录记录 `001-video-channel-placeholder-send` 功能规格，作用范围仅限当前规格目录及其子目录。

## 当前阶段

- `tasks.md` 已生成并执行。
- 功能实现已覆盖 `fc/common`、`fc/ai-reply`、`fc/delay-mq`。
- 2026-06-23 增量已纳入 D004：作业点评配置台新增视频号编码配置，`sop-reply` 与 `HomeWorkCommentService` 支持按编码发送视频号。
- 后续如继续修改，应先对照 `spec.md` 与 `tasks.md` 的执行记录确认范围。

## 后续实现约束

- 原始目标改动模块为 `C:\workspace\ju-chat\fc\ai-reply`、`C:\workspace\ju-chat\fc\delay-mq`，共享逻辑优先放入 `C:\workspace\ju-chat\fc\common`。
- D004 增量目标模块扩展为 `C:\workspace\ju-chat\data-RC\juzi-service` 与 `C:\workspace\ju-chat\fc\sop-reply`，并继续复用 `C:\workspace\ju-chat\fc\common` 中的视频号工具。
- `sendJuzi` 链路需要保持文本、图片、视频号消息的原始顺序，避免文字编号和视频号卡片错位。
- 复用已有 `sendJuziTextOrImage` 的文本和图片行为，不改变现有消息格式，改写这个方法支持发送视频号的功能，修改成合适的方法名。
- 视频号发送通过函数计算 `SEND_MESSAGE` 请求体完成；函数计算内部自动带 token，本仓库只拼装业务请求体。
- `video-channel-batch-config.json` 指向的 OSS地址 原始 JSON 需要 30 分钟 Redis 缓存。
- 同一 `external_user_id + user_id + 视频号编码` 7 天内只发送一次视频号卡片；重复命中只跳过卡片，文本和图片继续发送。
- `##{text:...}` 是条件文本，只绑定紧邻后一个视频号；绑定视频号不会发送时，条件文本也不发送。
- 作业点评配置台新增 `VIDEO_CHANNEL` 动作时，只允许运营配置 `V15` 这类视频号编码；配置台不得要求或保存真实视频号 payload。
- D004 不新增数据库字段；视频号编码复用 `drh_ai_config_homework_action.text_content` 存储，对外 DTO/JSON 使用 `videoChannelCode` 表达语义。
- `sop-reply` 读取配置台 JSON 时应支持 `VIDEO_CHANNEL` 动作，优先读取 `videoChannelCode`，并兼容 `textContent` 中的编码。
- `HomeWorkCommentService` 旧发送链路只补充“按编码发送视频号”的基础能力；`PianoVideoHomeWorkHandleServiceImpl` 保持识别职责，不在识别类内拼装真实视频号 payload。
- 未知编码、OSS 失败、JSON 缺字段、7 天限发命中时，只跳过当前视频号动作并记录原因，不影响同一策略中的其他动作。

## 文档维护

- `spec.md` 描述用户场景、功能需求、边界情况和成功标准。
- `checklists/requirements.md` 用于进入计划或实现前的规格质量检查。
- `tasks.md` 记录任务拆分、执行记录和回归结果。
- 如果需求变化，先更新 `spec.md`，再同步检查清单状态。
