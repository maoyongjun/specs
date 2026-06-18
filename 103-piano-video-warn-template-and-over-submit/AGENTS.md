# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\103-piano-video-warn-template-and-over-submit`
- 目标项目：`C:\workspace\ju-chat\fc\sop-reply`
- 相关模块：钢琴视频识别告警、SOP 回复作业计数提醒

## 当前目标

- 将钢琴视频 `id=-1` 未识别天数告警模板调整为 `WX_005`。
- 保持超时、异常、标题未知等旧钢琴视频识别告警继续使用 `WX003`。
- 对钢琴同一自然日提交超过两次新增 `WX_006` 提醒。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、配置来源和测试落点。
- 不允许把空对象、占位 DTO 或未赋值字段当成有效输入继续传递。
- 对跨层可变 DTO、调用后赋值、字段来源不明、旧逻辑副作用，必须先标记风险。
- 任何会改变调用顺序、接口契约、远程调用、MQ 字段、Redis key、数据库结构或外部行为的方案，实施前必须确认业务意图。
- 单元测试不能只验证最终结果；涉及外部调用、MQ、FC、Feign、OTS、Redis 时，必须做下游参数断言，确认关键参数内容。

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：每个关键参数从哪里来，是否在调用前赋值。
- 赋值时机：是否存在调用后才 `set`，但下游已经读取的字段。
- 占位对象：是否存在 `new XxxDto()`、空 Map、空 JSON 作为占位参数。
- 下游读取：下游实际读取哪些字段，是否全部有来源。
- 旧逻辑保持：哪些旧分支、异常处理、日志、延迟、幂等、过滤条件必须不变。
- 影响范围：是否影响调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为。
- 测试映射：每个关键行为至少对应一条单元测试、集成测试或静态验证记录。

## 重点代码位置

- `C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\service\homeworkhandle\PianoVideoHomeWorkHandleServiceImpl.java`
- `C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\service\SopReply.java`
- `C:\workspace\ju-chat\fc\sop-reply\src\test\java`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
