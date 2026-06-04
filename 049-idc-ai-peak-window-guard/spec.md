# 功能规格：自发消息跳过 AiFeign 与高峰期轻量化处理

**功能目录**：`049-idc-ai-peak-window-guard`  
**创建日期**：2026-06-04  
**状态**：Implemented  
**输入**：分析并修复 `C:\workspace\ju-chat\data-RC\juzi-service` 中高峰期和自发消息仍触发 `idc-ai/AiFeign` 相关链路的问题。最新口径为：自发消息不走任何 `AiFeign`；高峰期不执行 `syncTagService.syncTag(...)`，也不执行 `delayMessageService.sendExtendBaseInfoGenerate(...)`。

## 背景

- 线上现象：`07:00-08:00` 特别是 `07:30` 出现大量 `idc-ai` 请求，导致 `idc-ai` 在 `k8s` 中因请求量过大触发 `OOMKilled`。
- 旧问题 1：`WorkTimeUtil.isMorningHighTime()` 原先只覆盖 `06:45-07:15`，`07:30` 未命中高峰期。
- 旧问题 2：自发消息旧流程在 `isSelf` 判断前已经可能执行 `crmService.selectManagerIdAndSaleIdAndCampDateId(...)`、`userCheckService.selectUserPermission(...)` 等链路，其中可能间接或直接触发 `AiFeign`。
- 最新目标：把自发消息路径前移，保证所有自发消息不走 `AiFeign`；同时高峰期降低学生消息链路压力，跳过标签同步和等级更新触发点。
- 非目标：本次不改 MQ 结构、不改数据库结构、不改 `CenterUtil` 实现、不改 `chatFrequencyLevelClassifierService.addAndRemoveTag(...)`，也不把所有服务调用统一改成限流架构。

## 最终方案

| 事项 | 决策 |
|---|---|
| 自发消息 | 在 `crmService.selectManagerIdAndSaleIdAndCampDateId(...)` 前判断 `messageDto.getIsSelf()`；自发消息使用空 `IdSetDto` 继续消息源、群聊保存、撤回、OTS 落库和媒体去重，随后在权限校验前 return。 |
| 自发手动消息 | 保留 `source=0` 时 `delayMessageService.removeCache(externalUserId, userId)`，这是销售手动发送后的缓存清理逻辑，不能破坏。 |
| 自发消息补充字段 | 保留 `juziChatUserService.supplementCampAndEmpIfMissing(otsDto, userInfoDto)` 调用；由于自发消息不查权限，传入 `null`，该方法已有空值保护。 |
| 高峰期等级更新 | `delayMessageService.sendExtendBaseInfoGenerate(...)` 外层增加 `!highWorkTime` 判断；高峰期只记录跳过日志。 |
| 高峰期标签同步 | 两处 `syncTagService.syncTag(...)` 共用同一个 `highWorkTime` 判断；高峰期不调用，也不把 `syncTag` 标记为 `true`。 |
| 权限兜底 | `UserCheckServiceImpl` 不新增“高峰期主动 Center 兜底”。新权限链路中，`CenterUtil.selectUserInfo(...)` 只在 `aiFeign.getPermission(...)` 异常失败时作为 fallback；现有 `newPermissionPercent` 未命中新链路时的旧逻辑保持不变。 |
| 高峰窗口 | `WorkTimeUtil.isMorningHighTime(...)` 扩大到 `06:45-08:00` 的严格开区间判断，确保 `07:30` 命中。 |

## 用户场景与测试

### 用户故事 1 - 自发消息不触发 AiFeign（P1）

当 `messageDto.getIsSelf()` 为 `true` 时，系统必须避免进入可能触发 `AiFeign` 的链路，包括 `crmService.selectManagerIdAndSaleIdAndCampDateId(...)`、`userCheckService.selectUserPermission(...)`、`syncTagService.syncTag(...)` 和 `delayMessageService.sendExtendBaseInfoGenerate(...)`。

**验收场景**：

1. **Given** 自发消息，**When** 执行 `MessageServiceImpl.doSendMessage(...)`，**Then** 不调用 `crmService.selectManagerIdAndSaleIdAndCampDateId(...)`。
2. **Given** 自发消息，**When** 执行到权限校验前，**Then** 不调用 `userCheckService.selectUserPermission(...)`。
3. **Given** 自发消息，**When** 消息处理完成，**Then** 不调用 `sendExtendBaseInfoGenerate(...)` 和 `syncTagService.syncTag(...)`。
4. **Given** 自发手动消息且 `source=0`，**When** 处理自发消息分支，**Then** 仍调用 `delayMessageService.removeCache(externalUserId, userId)`。
5. **Given** 自发消息，**When** 保存群聊关系，**Then** `juziChatUserService.saveChatGroup(...)` 接收空 `IdSetDto`，不依赖 CRM 补齐。

### 用户故事 2 - 高峰期学生消息跳过标签和等级更新（P1）

当消息不是自发消息且当前时间处于高峰期时，系统仍允许必要的消息保存和权限逻辑继续，但必须跳过 `syncTagService.syncTag(...)` 和 `delayMessageService.sendExtendBaseInfoGenerate(...)`，避免高峰期扩大异步生成、等级更新和标签同步压力。

**验收场景**：

1. **Given** 高峰期学生消息，**When** 执行 `doSendMessage(...)`，**Then** 不调用 `delayMessageService.sendExtendBaseInfoGenerate(...)`。
2. **Given** 高峰期学生消息，**When** `IdSetDto.empId` 不为空，**Then** 第一处 `syncTagService.syncTag(...)` 不调用，`syncTag` 不置为 `true`。
3. **Given** 高峰期学生消息，**When** 权限校验返回 `UserInfoDto.empId`，**Then** 第二处 `syncTagService.syncTag(...)` 不调用。
4. **Given** 非高峰期学生消息，**When** 原有条件满足，**Then** `sendExtendBaseInfoGenerate(...)` 和 `syncTagService.syncTag(...)` 保持原有调用行为。

### 用户故事 3 - 权限兜底策略保持旧逻辑（P1）

当非自发消息进入权限校验时，系统继续按 `newPermissionPercent` 决定新旧权限链路。新权限链路里 `aiFeign.getPermission(...)` 成功时不得调用 Center fallback；只有 `aiFeign.getPermission(...)` 抛异常时才调用 `CenterUtil.selectUserInfo(...)` 兜底。

**验收场景**：

1. **Given** `aiFeign.getPermission(...)` 成功，**When** 调用 `selectUserPermission(...)`，**Then** 不调用 Center fallback。
2. **Given** `aiFeign.getPermission(...)` 抛异常，**When** 调用 `selectUserPermission(...)`，**Then** 调用 Center fallback 并返回可用 `UserInfoDto`。
3. **Given** `newPermissionPercent=0`，**When** 进入旧权限路径，**Then** 保持历史行为，不在本次改动中强制切到新链路。

## 历史问题防漏分析

- 自发消息调用顺序风险：
  - 原流程中 `isSelf` 处理位于部分外部链路之后，不能保证自发消息不触发 `AiFeign`。
  - 新流程在 `crmService.selectManagerIdAndSaleIdAndCampDateId(...)` 前计算 `selfMessage`，自发消息直接使用空 `IdSetDto`，从入口上规避 CRM 链路。
  - 自发消息在 `userCheckService.selectUserPermission(...)` 前执行 `handleSelfMessage(...)` 并 return，规避权限链路里的 `AiFeign`。
- 自发手动发送旧逻辑：
  - `source=0` 的 `delayMessageService.removeCache(externalUserId, userId)` 是销售手动发送后的清缓存逻辑，必须保留。
  - 高峰期自发消息仍打印 `self_message_in_high_work_time_ignore`，用于观测。
  - `messageDto.setExternalUserId(externalUserId)` 仍保留，避免下游或日志丢失外部联系人 ID。
- 高峰期学生消息风险：
  - `sendExtendBaseInfoGenerate(...)` 会触发扩展基础信息生成，按本次口径归为“等级更新”触发点，高峰期跳过。
  - 两处 `syncTagService.syncTag(...)` 都可能增加同步压力，必须由同一个 `highWorkTime` 变量控制，避免一个分支漏拦。
  - `chatFrequencyLevelClassifierService.addAndRemoveTag(...)` 不属于本次明确禁用范围，保持原逻辑。
- 权限兜底风险：
  - 本次不引入高峰期主动 `CenterUtil` 查询，避免把压力从 `idc-ai` 转移到 Center。
  - 为便于测试，把 Center 调用封装为 `selectUserInfoFromCenter(...)`，但业务语义不变。
- 时间窗口风险：
  - 早高峰窗口已覆盖 `07:30`；边界使用当前代码的严格判断，`07:00` 命中，`08:00` 不命中。
  - 当前仍是硬编码时间窗，后续如需运行时可配置，需要单独补配置规格和回归测试。

## 功能需求

- **FR-001**：系统 MUST 在 `crmService.selectManagerIdAndSaleIdAndCampDateId(...)` 前识别自发消息。
- **FR-002**：自发消息 MUST NOT 调用 `crmService.selectManagerIdAndSaleIdAndCampDateId(...)`、`userCheckService.selectUserPermission(...)`、`syncTagService.syncTag(...)`、`delayMessageService.sendExtendBaseInfoGenerate(...)`。
- **FR-003**：自发消息 MUST 继续执行 `createMessageSource(...)`、`juziChatUserService.saveChatGroup(...)`、撤回处理、OTS 落库和媒体去重。
- **FR-004**：自发手动消息 `source=0` MUST 继续调用 `delayMessageService.removeCache(externalUserId, userId)`。
- **FR-005**：自发消息 MUST 保留 `juziChatUserService.supplementCampAndEmpIfMissing(otsDto, userInfoDto)` 和 `messageDto.setExternalUserId(externalUserId)`。
- **FR-006**：高峰期 MUST NOT 调用 `delayMessageService.sendExtendBaseInfoGenerate(...)`。
- **FR-007**：高峰期 MUST NOT 调用任何一处 `syncTagService.syncTag(...)`，且不得把 `syncTag` 设置成已同步。
- **FR-008**：非高峰期学生消息 MUST 保持原有 `sendExtendBaseInfoGenerate(...)` 和 `syncTagService.syncTag(...)` 行为。
- **FR-009**：`UserCheckServiceImpl` MUST 保持原有权限选择策略；新权限链路中 `aiFeign.getPermission(...)` 成功时不调用 Center fallback，异常时才 fallback。
- **FR-010**：早高峰窗口 MUST 覆盖 `07:30`。

## 成功标准

- **SC-001**：自发消息路径中 `crmService`、`userCheckService`、`sendExtendBaseInfoGenerate`、`syncTagService.syncTag` 调用次数均为 `0`。
- **SC-002**：自发手动消息 `source=0` 仍调用 `delayMessageService.removeCache(externalUserId, userId)`。
- **SC-003**：高峰期学生消息不调用 `sendExtendBaseInfoGenerate(...)`，也不调用两处 `syncTagService.syncTag(...)`。
- **SC-004**：非高峰期学生消息仍调用 `sendExtendBaseInfoGenerate(...)` 和符合条件的 `syncTagService.syncTag(...)`。
- **SC-005**：`aiFeign.getPermission(...)` 成功时 Center fallback 调用次数为 `0`；`aiFeign.getPermission(...)` 异常时 Center fallback 调用次数为 `1`。
- **SC-006**：`WorkTimeUtil.isHighWorkTime(LocalTime.of(7, 30))` 返回 `true`。

## 假设

- “等级更新”指 `delayMessageService.sendExtendBaseInfoGenerate(...)` 内触发的 `userLevelGenerate(...)` 和 `orderCloseAdviceGenerate(...)`。
- “高峰期不执行标签同步”只指 `syncTagService.syncTag(...)`，不包含聊天频率分级 `chatFrequencyLevelClassifierService.addAndRemoveTag(...)`。
- 自发消息不补齐 `campDateId/empId/skuId`，因为补齐链路可能触发 `AiFeign`；手动发送清缓存逻辑优先保留。
- `CenterUtil.selectUserInfo(...)` 的历史旧链路分支保留；本次只保证新权限链路中成功不兜底、异常才兜底。

## 执行记录

### D001 - 初始分析记录

- 已创建本 Spec Kit 文档。
- 已完成 `juzi-service` 高峰期调用链事实确认。
- 已确认当前 `07:30` 漏窗不是单纯“有没有高峰时间”问题，而是“自发消息门禁位置过晚、时间窗过窄、且高峰期仍执行标签与等级相关链路”叠加。

### D002 - 口径纠正记录

- 触发原因：用户补充“高峰期时，自己发的消息不调用 `aiFeign`；`CenterUtil.selectUserInfo` 只有在异常失败时才兜底；自己发的消息是销售手动发送处理，不能破坏 `removeCache` 逻辑”。
- 修正内容：不再采用“高峰期主动走 Center 兜底”的方案，改为“自发消息在权限校验前 return，学生消息权限逻辑保持原策略”。
- 文档同步：`spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 均需同步。

### D003 - 实现记录

- 实现内容：自发消息在 CRM 查询前识别并使用空 `IdSetDto`；自发消息在权限校验前执行手动清缓存、补充字段和 return；高峰期跳过 `sendExtendBaseInfoGenerate(...)` 与两处 `syncTagService.syncTag(...)`；`WorkTimeUtil` 早高峰扩展到覆盖 `07:30`；`UserCheckServiceImpl` 增加可测试 Center fallback 包装方法但保持业务语义。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=MessageServiceImplSelfMessageAiFeignTest,MessageServiceImplHighWorkTimeTest,UserCheckServiceImplTest,WorkTimeUtilTest" test`
- 测试结果：`Tests run: 8, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 模块回归：`mvn -pl juzi-service -DskipTests=false test`，`Tests run: 98, Failures: 0, Errors: 0, Skipped: 1`，`BUILD SUCCESS`。
- 自检结论：关键外部链路已用单元测试断言不调用；自发手动清缓存逻辑保留；非高峰学生消息保留原调用；`CenterUtil` 未新增高峰主动兜底。
