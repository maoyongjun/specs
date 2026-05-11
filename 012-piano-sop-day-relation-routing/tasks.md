# 任务清单：钢琴视频 Prompt 与 SOP 天数关系路由

**输入**：来自 `specs/012-piano-sop-day-relation-routing/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：通过模块编译检查和关键逻辑走查验证。  

## Phase 1：规格与范围

- [x] T001 创建 Spec Kit 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 记录 `resolvePianoVideoPrompt` 中 `D%s -> D + logicalDay` 的已完成改动
- [x] T003 明确目标文件为 `PianoVideoHomeWorkHandleServiceImpl.java` 和 `SopReply.java`
- [x] T004 明确钢琴 SOP 特殊逻辑仅适用于 `sku=4`

## Phase 2：实现

- [x] T005 在 `SopReply` 中识别钢琴过去作业：`sku=4` 且 `recognizedDay < currentDay`
- [x] T006 钢琴过去作业发送时使用 `recognizedDay` 作为 SOP 路由天数
- [x] T007 钢琴过去作业路由参数强制使用 `homeworkDayRelation=CURRENT`
- [x] T008 钢琴过去作业分支打印包含关键上下文的日志
- [x] T009 在 `SopReply` 中识别钢琴未来作业：`sku=4` 且 `recognizedDay > currentDay`
- [x] T010 钢琴未来作业直接发送固定话术，不通过 `homeworkDayRelation=FUTURE` 路由
- [x] T011 钢琴未来作业分支打印包含关键上下文和固定话术的日志

## Phase 3：验证

- [x] T012 验证 `resolvePianoVideoPrompt` 的 `D%s` 替换结果
- [x] T013 验证钢琴过去作业路由天数和 `homeworkDayRelation=CURRENT`
- [x] T014 验证钢琴未来作业固定话术发送路径
- [x] T015 编译 `fc/sop-reply` 模块
- [x] T016 记录验证结果和剩余风险

## 执行记录

### D001 - 文档记录

- 已按用户要求先创建 Spec Kit 文档，未修改 `SopReply.java`。
- 已记录此前 `PianoVideoHomeWorkHandleServiceImpl#resolvePianoVideoPrompt` 的 `D%s -> D + logicalDay` 变更。
- 已把新增钢琴 SOP 过去/未来作业需求拆分为可实现、可验证的任务。

### D002 - 实现记录

- `SopReply` 新增 `sku=4` 且 `recognizedDay < currentDay` 的钢琴过去作业分支。
- 钢琴过去作业发送 SOP 时使用 `recognizedDay` 作为 `routeDay`，使用提交日点评序号作为 `routeCommentIndex`。
- 钢琴过去作业路由参数强制覆盖为 `homeworkDayRelation=CURRENT`，并同步覆盖 `isPastHomework=false`、`isFutureHomework=false`。
- `SopReply` 新增 `sku=4` 且 `recognizedDay > currentDay` 的钢琴未来作业分支。
- 钢琴未来作业不请求配置中心路由，直接发送固定话术：`预习的不错，上课跟着再好好学习指法，完善一下会更好`。
- 过去作业和未来作业分支均新增可检索日志。

### D003 - 验证记录

- 执行命令：`mvn -q -DskipTests compile`
- 执行目录：`C:\workspace\ju-chat\fc\sop-reply`
- 执行结果：编译通过。
- 静态检查确认 `PianoVideoHomeWorkHandleServiceImpl#resolvePianoVideoPrompt` 使用 `promptTemplate.replace("D%s", "D" + logicalDay)`。
- 静态检查确认 `SopReply` 包含 `sopReply_piano_past_homework_route_override` 与 `sopReply_piano_future_homework_fixed_reply` 日志。
- 剩余风险：未接入真实配置中心、Redis、OTS 和企微发送链路做端到端联调；当前验证覆盖编译和关键逻辑走查。
