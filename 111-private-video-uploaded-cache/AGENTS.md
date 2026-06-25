# 规格执行说明

本目录记录 `私聊视频上传标记缓存联动` 的规格、任务和验证结果。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\111-private-video-uploaded-cache`
- 目标项目：
  - `C:\workspace\ju-chat\data-RC\juzi-service`（写入端）
  - `C:\workspace\ju-chat\coze_plugin\external-info-select`（读取端）
- 相关模块：句子消息消费链路、Redis 缓存、`AppTask` 外部信息返回。

## 当前目标

- 用户在私聊中主动发送视频时，按 `externalUserId` 写入 5 分钟 Redis 缓存，标记「刚发过视频」。
- Redis key 必须包含 `externalUserId`，两端统一为 `ai:reply:video-uploaded:{externalUserId}`。
- `external-info-select` 的 `AppTask` 标准营期主路径返回前查缓存：命中 `video_uploaded="是"`，未命中/异常 `video_uploaded="否"`。

## 执行原则

- 先读代码，再定方案，后实现。
- 写入端只在 `MessageServiceImpl.doSendMessage` 旁路新增标记，不改动原有 return 流程、去重、延迟、路由、标签等逻辑。
- 读取端只加在标准营期主路径，不加在私域 `private_domain` 路径（已与用户确认）。
- 不扩散到 `ProfileTask/ProfileTaskV2`。
- Redis 读写异常只记录日志，不阻断主流程。
- 写入端必须使用 `stringRedisTemplate`（纯字符串序列化），禁止使用 `userRedisTemplate/defineRedisTemplate`（JDK/Jackson 序列化会导致 coze Jedis 读不出）。
- 不修改 MQ body、FC 调用参数、OTS 表结构、外部 HTTP 请求和现有标签/物流/敏感词/转账解析规则。
- 单元测试覆盖 key、TTL、value、触发条件分支与 `AppTask` 纯逻辑。

## 强制门禁

- 参数来源：写入端 `externalUserId` 来自 `MessageServiceImpl.doSendMessage` 中已补偿赋值的 `external_user_id`（来自 `otsDto`/imContactId 反查），使用前判空；读取端来自 `external_key` split 后的 `external_user_id`。
- 赋值时机：写入端标记在 `external_user_id` 补偿赋值之后调用；读取端在 `chat_name` 构建并补偿完成后、return 之前调用。
- 占位对象：写入端不引入任何新 DTO/空对象；读取端沿用现有 `RedisClient` 单连接读取模式。
- 下游读取：coze `AppTask` 返回 JSON 新增 `video_uploaded` 字段，下游 Coze 智能体读取该字段。
- 旧逻辑保持：消息去重、撤回标记、招呼语过滤、群聊分支、延迟下发、敏感词、转账、`if_register` 等全部不变。
- 影响范围：仅新增一个 Redis key/TTL 行为（写）与一个返回字段（读）。
- 测试映射：两个项目均有常量测试 + 纯逻辑/分支测试。

## 重点代码位置

- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\MessageServiceImpl.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\constants\RedisConstants.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\util\RedisSafeUtil.java`
- `C:\workspace\ju-chat\coze_plugin\external-info-select\src\main\java\com\drh\select\service\AppTask.java`
- `C:\workspace\ju-chat\coze_plugin\external-info-select\src\main\java\com\drh\select\constants\RedisContants.java`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
