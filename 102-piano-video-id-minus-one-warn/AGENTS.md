# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\102-piano-video-id-minus-one-warn`
- 目标项目：`C:\workspace\ju-chat\fc\sop-reply`
- 相关模块：钢琴视频作业识别、识别结果解析后告警、`common_warn_sender` 告警触发。

## 当前目标

- 在 `PianoVideoHomeWorkHandleServiceImpl` 中识别 `HomeWorkResultDto.id == -1`。
- 复用现有 `WX003` + `common_warn_sender` 告警链路，发出人工介入提醒。
- 不改变原有缓存、等待、异常、标题未知告警和返回结果逻辑。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、配置来源和测试落点。
- 不允许把空对象、占位 DTO 或未赋值字段当成有效输入继续传递。
- 对跨层可变 DTO、调用后赋值、字段来源不明、旧逻辑副作用，必须先标记风险。
- 任何会改变调用顺序、接口契约、远程调用、MQ 字段、Redis key、数据库结构或外部行为的方案，实施前必须确认业务意图。
- 单元测试不能只验证最终结果；涉及外部调用、MQ、FC、Redis 时，必须做下游参数或判断结果断言。
- 实现时避免真实访问 Redis、OTS、FC 或外部 HTTP；需要测试时提取最小可测判断方法。

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：`HomeWorkResultDto.id` 从哪里来，是否在判断前完成解析。
- 赋值时机：是否存在返回后才判断或下游已读取但未赋值的字段。
- 占位对象：`new HomeWorkResultDto()` 的 `id=null` 不得误触发告警。
- 下游读取：告警链路读取 `externalKey`、`messageId`、`cacheKey`、`warnReason`、`warnStage`。
- 旧逻辑保持：超时、异常、标题未知、缓存、等待、返回结果必须保持。
- 影响范围：仅新增现有 FC 告警调用的原因分支，不新增模板、MQ、DB 或环境变量。
- 测试映射：`id=-1`、`id=null`、`id=1`、`title=未知` 均需有测试或静态验证记录。

## 重点代码位置

- `C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\service\homeworkhandle\PianoVideoHomeWorkHandleServiceImpl.java`
- `C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\dto\HomeWorkResultDto.java`
- `C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\dto\HomeWorkMessageDto.java`
- `C:\workspace\ju-chat\fc\sop-reply\src\test\java`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加执行记录，并同步更新相关文档。
