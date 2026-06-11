# 任务清单：LivingStudyInfoRecordServiceImpl 完课标签缺失原因分析

**输入**：来自 `spec.md` 的分析规格  
**前置条件**：用户提供 `2026-06-09 21:39:08` 请求日志、目标方法 `LivingStudyInfoRecordServiceImpl#doSave`  
**测试**：本阶段为静态分析和日志分支复核，不修改业务代码。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前目标是创建排查文档。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和标签发送位置。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
- [x] T004 确认 Redis、MQ、数据库表和配置项影响范围。
- [x] T005 确认旧逻辑中必须保持不变的过滤、幂等、异常处理、日志和 fallback。

**检查点**：已完成 T001-T005；本阶段不进入业务代码实现。

## Phase 2：风险门禁

- [x] T006 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用。
- [x] T009 检查本次分析是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为。
- [x] T010 对需要用户确认的业务语义变化做记录；本阶段没有实施变化。
- [x] T011 为关键行为建立验证映射，覆盖普通完课、已完课防重、`length` 缺失分支。

**检查点**：T006-T011 已有明确结论；高风险点已记录到 `spec.md` 的“历史问题防漏分析”。

## Phase 3：实现

- [ ] T012 按规格实现最小范围改动。
- [ ] T013 保持未声明的旧行为不变。
- [ ] T014 对外部调用参数、MQ body、Redis key、数据库写入增加可测试断言点。
- [x] T015 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 和 checklist。

**说明**：本阶段只创建分析文档，不执行 T012-T014。

## Phase 4：测试与验证

- [ ] T016 新增或更新单元测试，覆盖关键行为。
- [ ] T017 测试中断言关键下游参数内容，不只断言最终结果。
- [x] T018 验证边界情况和旧逻辑不回归。
- [x] T019 运行静态搜索和文档检查命令，并记录结果。
- [x] T020 搜索确认没有残留模板占位。

## 验证映射

- 正常完课路径：`length` 有值且 `status` 计算为 2，SQL 应包含 `status=?`，并调用 `doSendQwTag(..., MqDayEnum.finish)`。
- 已完课防重路径：旧 `status=2` 时只更新 `seconds/degree/sliceId`，不重复发送完课标签。
- `length` 缺失路径：`length` 为空/0 时进入兼容分支；旧 `status=1` 时也不会发送完课标签。
- 华彩豆路径：`drh_live_camp_date` 查询为空只影响 `isDisplayHuacaiCoinInfo=false`，不影响 `finish` 标签调用条件。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `070-living-finish-tag-missing-analysis` Spec Kit 文档。
- 验证方式：静态读取日志、入口 controller、`doSave`、标签 MQ producer、`LiveCampDateServiceImpl`。
- 自检结论：已满足参数来源、调用顺序、下游读取、旧逻辑保持和剩余风险记录要求。

### D002 - 用户补充后的复核项

- 复核项 1：查询 `drh_living_study_info.id=39994622` 的 `status`。
- 复核项 2：`drh_live.id=1143726` 的 `length` 已由用户确认不是 0。
- 复核项 3：查询 `drh_live_camp.id=16905` 的 `is_class`。
- 复核后记录口径：若 `status=2`，按前序请求已完课和完课标签链路继续排查；若 `status=1`，需回到状态计算分支排查为什么未更新为完课。

### D003 - 完课标签链路排查项

- 当前状态：未执行实现；等待按日志和数据库确认首次 `status` 变成 2 的请求。
- 排查项 1：在 endpoint/broadcast 日志按 `userId=189338`、`liveId=1143726`、`完课-打标签完成`、`MessageType=QW_TAG`、`MqDayEnum.finish` 搜索首次完课请求。
- 排查项 2：如果 producer 有 `QW_TAG` 发送日志，继续查 works topic 消费端或 FC `qw-tag/AppTask` 的 `开始打标签`、`企微打标签请求`、`invokeQwProxyFc result`、`保存标签成功`、`添加标签成功` 日志。
- 排查项 3：如果 producer 没有 `QW_TAG` 发送日志，回查第一次 SQL 是否真的更新了 `status=2`，以及是否落在已完课兼容分支或异常提前返回。
- 文档同步：当前已同步 `spec.md`、`tasks.md`、`AGENTS.md` 和 `checklists/requirements.md`。
- 验证结果：当前完成静态分析；未运行单元测试或联调测试。
