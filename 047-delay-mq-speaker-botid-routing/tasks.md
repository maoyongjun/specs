# 任务清单：delay-mq 按 speakerId 路由 Coze botId

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充 Coze `botID` 参数断言，避免只验证最终回复结果。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认本阶段只创建文档，不修改业务代码。
- [x] T002 用 `rg` 确认目标模块为 `C:\workspace\ju-chat\fc\delay-mq`，入口包含 `AppTask` 和 `AppTaskV2`。
- [x] T003 确认当前 Coze `botID` 来源为 `DayEnum.getBotId()`，使用位置包含 `CozeUtil` 和 `CozeUtilV2`。
- [x] T004 确认 `campDateId` 来源为 `EmpExternalDto.getCamp_date_id()`，参考获取 `speakerId` 的代码位于 `audio-tts/AppTask.resolveSpeaker()`。
- [x] T005 确认 `delay-mq` 当前 `CenterUtil` 没有 `getCampInfoByCampDateId()`，后续实现需补齐等价能力。
- [x] T006 确认 `EmpExternalDto.user_bot_id` 仍被 `LocalCacheUtil.getCorpId(...)` 使用，不能误改为 Coze `botID` 路由字段。

**检查点**：已完成 T001-T006。本次不进入业务代码实现。

## Phase 2：风险门禁

- [x] T007 检查空对象风险：`CampInfo`、`skuId`、`speakerId` 均可能为空，规格已要求固定 botId 兜底。
- [x] T008 检查调用后赋值风险：`resolvedBotId` 必须在 `CreateChatReq.builder().botID(...)` 前确定。
- [x] T009 检查下游读取字段：Coze 请求读取 `botID`，企微发送读取 `user_bot_id`，两者已在规格中分离。
- [x] T010 检查外部调用影响：后续实现会新增 Center 查询 `getCampInfoByCampDateId`，该外部调用为用户明确要求，需记录失败兜底。
- [x] T011 检查旧逻辑保持：消息过滤、Redis、OTS、conversation key、作业点评分支、敏感词重试和企微发送行为不变。
- [x] T012 建立测试映射：覆盖 `speakerId=106`、`speakerId=39`、其他值、null/查询失败、V1/V2 Coze 请求参数。

**检查点**：T007-T012 已完成，结论写入 `spec.md`。

## Phase 3：文档创建

- [x] T013 创建 `047-delay-mq-speaker-botid-routing` 目录。
- [x] T014 填写 `spec.md`，记录背景、用户故事、需求、边界、成功标准和假设。
- [x] T015 填写 `AGENTS.md`，记录目标项目、作用范围、执行原则和重点代码位置。
- [x] T016 填写 `tasks.md` 和 `checklists/requirements.md`，同步参数门禁和后续实现任务。
- [x] T017 完成模板占位符检查，确认无未替换模板标记残留。
- [x] T018 运行 `git status --short`，确认本次只新增本规格目录，未触碰业务代码。

## Phase 4：后续实现任务

- [x] T019 在 `delay-mq` 中补齐 `CenterUtil.getCampInfoByCampDateId(campDateId)` 和 `CampInfo` 解析能力，参考 `audio-tts` 现有实现。
- [x] T020 新增 `resolvedBotId` 解析逻辑，明确常量 `ZHAOMAN_SPEAKER_ID=106`、`ZHANGMAN_SPEAKER_ID=39`、`FIXED_BOT_ID=7638948127407636514`。
- [x] T021 将 `CozeUtil.sendMessage()`、`CozeUtilV2.sendMessage()`、`CozeUtilV2.sendMessageV2()` 的 `CreateChatReq.botID(...)` 改为使用 `resolvedBotId` 或等价封装。
- [x] T022 保持 `speakerId=39` 使用当前 `dayEnum.getBotId()` 默认逻辑，并保持 `dayEnum` 为空时的原早退行为。
- [x] T023 保持 `EmpExternalDto.user_bot_id`、MQ body、Redis key/TTL、OTS 查询和 conversation key 不变。
- [x] T024 增加路由日志，包含 `campDateId`、`skuId`、`speakerId`、`resolvedBotId` 和路由原因。
- [x] T025 同步更新本规格的 D002 实现记录。

## Phase 5：后续测试与验证

- [x] T026 新增或更新单元测试，断言 `speakerId=106` 的 Coze `botID` 为固定值。
- [x] T027 新增或更新单元测试，断言 `speakerId=39` 的 Coze `botID` 等于 `dayEnum.getBotId()`。
- [x] T028 新增或更新单元测试，断言其他 speakerId、null、Center 失败均走固定 botId。
- [x] T029 覆盖 V1 `CozeUtil.sendMessage()`、V2 `CozeUtilV2.sendMessage()` 和 `CozeUtilV2.sendMessageV2()` 的参数断言。
- [x] T030 运行 `fc/delay-mq` 编译或目标测试命令，并记录结果。
- [x] T031 静态搜索确认 Coze `CreateChatReq.botID(...)` 不再无条件直接读取 `dayEnum.getBotId()`。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `047-delay-mq-speaker-botid-routing`，并填充 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 验证方式：`rg` 静态搜索、模板文件对照、占位符检查和 `git status --short`。
- 自检结论：代码事实已确认；本阶段未修改 `fc/delay-mq` 业务代码。

### D002 - 实现记录

- 实现内容：新增 `CenterUtil.getCampInfoByCampDateId()` 和 `CampInfo` 解析；新增 `BotIdResolver`，按 `speakerId=106` 固定 botId、`speakerId=39` 走 `DayEnum.getBotId()`、其他或空值固定 botId；`CozeUtil` 和 `CozeUtilV2` 的 Coze 请求改用 `resolvedBotId`，V1 敏感词重试复用同一个 botId。
- 测试命令：`mvn -pl delay-mq -am test`。
- 测试结果：通过，`BUILD SUCCESS`；`common` 22 个测试通过，`delay-mq` 16 个测试通过，其中新增 `BotIdResolverTest` 8 个测试通过。
- 自检结论：`CreateChatReq.botID(...)` 不再无条件直接读取 `dayEnum.getBotId()`；`user_bot_id` 仍只服务原企微 corpId 查询；未修改 MQ body、Redis key/TTL、OTS 查询、conversation key、作业点评分支或企微发送链路。

### D003 - 纠正记录模板

- 触发原因：`说明为什么需要纠正`。
- 修正内容：`说明具体修正`。
- 文档同步：`说明同步了哪些文件`。
- 验证结果：`说明测试或静态验证`。

### D004 - 验证记录

- 模板占位符检查：通过，无未替换模板标记残留。
- `specs` 仓库状态：除既有 `043-homework-config-zhangkai-vocal` 未跟踪文件外，本次新增 `047-delay-mq-speaker-botid-routing/`。
- `fc` 仓库状态：文档创建阶段未显示 `delay-mq` 业务代码变更。
