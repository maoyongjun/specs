# 规格执行说明

本目录是 `juzi-service` 中“自发消息跳过 AiFeign 与高峰期轻量化处理”的 Spec Kit 文档。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\049-idc-ai-peak-window-guard`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 相关模块：
  - `com.drh.data.juzi.service.impl.MessageServiceImpl`
  - `com.drh.data.juzi.service.impl.UserCheckServiceImpl`
  - `com.drh.data.juzi.util.WorkTimeUtil`
  - `com.drh.data.juzi.service.DelayMessageService`
  - `com.drh.data.juzi.service.SyncTagService`

## 当前目标

- 所有自发消息不走任何 `AiFeign` 相关链路。
- 自发手动消息 `source=0` 继续执行 `delayMessageService.removeCache(externalUserId, userId)`。
- 高峰期不执行 `syncTagService.syncTag(...)`。
- 高峰期不执行 `delayMessageService.sendExtendBaseInfoGenerate(...)`。
- `UserCheckServiceImpl` 不新增高峰期主动 Center 兜底；新权限链路中只有 `aiFeign.getPermission(...)` 异常时才 fallback。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、配置来源和测试落点。
- 自发消息可以使用空 `IdSetDto`，但用途必须限定在保留 `saveChatGroup(...)` 等非 AiFeign 链路，不得再把它传入权限或标签同步链路。
- 对跨层可变 DTO、调用后赋值、字段来源不明、旧逻辑副作用，必须先标记风险。
- 任何会改变调用顺序、接口契约、远程调用、MQ 字段、Redis key、数据库结构或外部行为的方案，实施前必须确认业务意图。
- 单元测试不能只验证最终结果；涉及外部调用、Feign、OTS、Redis 时，必须做下游参数断言，确认关键参数内容。

## 强制门禁

实现或继续修改前必须检查：

- 自发消息是否仍可能进入 `crmService.selectManagerIdAndSaleIdAndCampDateId(...)`。
- 自发消息是否仍可能进入 `userCheckService.selectUserPermission(...)`。
- 自发消息是否仍可能进入 `delayMessageService.sendExtendBaseInfoGenerate(...)` 或 `syncTagService.syncTag(...)`。
- 自发手动消息 `source=0` 是否仍执行 `delayMessageService.removeCache(...)`。
- 高峰期学生消息是否跳过两处 `syncTagService.syncTag(...)`。
- 高峰期学生消息是否跳过 `delayMessageService.sendExtendBaseInfoGenerate(...)`。
- `aiFeign.getPermission(...)` 成功路径是否没有调用 Center fallback。
- `aiFeign.getPermission(...)` 异常路径是否仍调用 Center fallback。

## 重点代码位置

- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\MessageServiceImpl.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\UserCheckServiceImpl.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\util\WorkTimeUtil.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\test\java\com\drh\data\juzi\service\impl\MessageServiceImplSelfMessageAiFeignTest.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\test\java\com\drh\data\juzi\service\impl\MessageServiceImplHighWorkTimeTest.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\test\java\com\drh\data\juzi\service\impl\UserCheckServiceImplTest.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\test\java\com\drh\data\juzi\util\WorkTimeUtilTest.java`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加执行记录，并同步更新相关文档。
