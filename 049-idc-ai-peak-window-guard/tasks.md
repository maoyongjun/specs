# 任务清单：自发消息跳过 AiFeign 与高峰期轻量化处理

**输入**：来自 `spec.md` 的最终功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于哪个项目、模块和业务链路。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和测试落点。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
- [x] T004 确认配置来源、环境变量、Redis key、MQ topic/tag、Feign/FC/HTTP 调用或数据库表是否受影响。
- [x] T005 确认已有旧逻辑中必须保持不变的过滤、幂等、异常处理、日志、延迟和 fallback。

## Phase 2：风险门禁

- [x] T006 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参；自发消息使用空 `IdSetDto` 是明确设计，用于避免 CRM/AiFeign 链路，且测试断言只传给 `saveChatGroup(...)`。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段；自发消息保留 `messageDto.setExternalUserId(...)` 后 return。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为。
- [x] T010 对需要用户确认的业务语义变化做记录；已按用户最新口径修正为“自发消息绕开 AiFeign，高峰期跳过标签和等级更新”。
- [x] T011 为每个关键行为建立测试映射，至少覆盖正常路径、边界路径和不回归路径。

## Phase 3：实现

- [x] T012 按规格实现最小范围改动。
- [x] T013 保持未声明的旧行为不变。
- [x] T014 对外部调用参数、MQ body、Redis key、数据库写入或 FC/Feign 参数增加可测试断言点。
- [x] T015 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 和 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [x] T016 新增或更新单元测试，覆盖关键行为。
- [x] T017 测试中断言关键下游参数内容，不只断言最终结果。
- [x] T018 验证边界情况和旧逻辑不回归。
- [x] T019 运行目标模块定向测试命令，并记录结果。
- [x] T020 搜索确认没有残留旧调用、旧字段、旧日志或旧口径。
- [x] T021 运行 `juzi-service` 模块全量回归测试，并记录结果。

## 测试映射

| 测试类 | 覆盖点 |
|---|---|
| `MessageServiceImplSelfMessageAiFeignTest` | 自发消息不调用 CRM、权限校验、等级更新、标签同步；自发手动消息保留 `removeCache(...)`；`saveChatGroup(...)` 接收空 `IdSetDto`。 |
| `MessageServiceImplHighWorkTimeTest` | 高峰期学生消息跳过 `sendExtendBaseInfoGenerate(...)` 和两处 `syncTag(...)`；非高峰期学生消息保持调用。 |
| `UserCheckServiceImplTest` | `aiFeign.getPermission(...)` 成功不走 Center fallback；异常才走 Center fallback；旧百分比分支保持历史行为。 |
| `WorkTimeUtilTest` | `07:30` 命中高峰期，`08:00` 不命中。 |

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `049-idc-ai-peak-window-guard` Spec Kit 文档，完成 `juzi-service` 中高峰期调用链、时间窗和门禁位置分析。
- 验证方式：代码搜索、调用链阅读、时间窗对比、风险门禁分析。
- 自检结论：已确认 `07:30` 漏窗与自发消息调用顺序是核心问题。

### D002 - 口径纠正记录

- 触发原因：用户补充自发消息必须完全不走 `AiFeign`，且保留销售手动发送的 `removeCache` 逻辑；高峰期还要跳过标签同步和等级更新。
- 修正内容：放弃“高峰期主动 Center 兜底”作为主方案，改为自发消息前置 return；高峰期学生消息跳过 `syncTagService.syncTag(...)` 和 `delayMessageService.sendExtendBaseInfoGenerate(...)`。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。

### D003 - 实现记录

- 实现内容：修改 `MessageServiceImpl`、`WorkTimeUtil`、`UserCheckServiceImpl`，新增 4 个测试类。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=MessageServiceImplSelfMessageAiFeignTest,MessageServiceImplHighWorkTimeTest,UserCheckServiceImplTest,WorkTimeUtilTest" test`
- 测试结果：`Tests run: 8, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 模块回归：`mvn -pl juzi-service -DskipTests=false test`，`Tests run: 98, Failures: 0, Errors: 0, Skipped: 1`，`BUILD SUCCESS`。
- 自检结论：自发消息绕开 `AiFeign` 入口链路；高峰期跳过标签同步与等级更新；权限 fallback 策略未扩大。
