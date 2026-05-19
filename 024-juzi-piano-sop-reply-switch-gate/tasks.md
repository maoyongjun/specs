# 任务清单：juzi-service SOP 点评开关门禁

**输入**：来自 `specs/024-juzi-piano-sop-reply-switch-gate/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：实现阶段需要验证所有命中 SOP 点评的 SKU 在 AI 开关关闭、作业点评开关关闭、群 ID 未命中、配置缺失和开关全开等场景下的 `sop-reply` 调用行为；必须补充单元测试覆盖 `skuId=4`、`skuId=5` 和非 SOP 链路。

## Phase 1：规格与范围

- [x] T001 创建 `specs/024-juzi-piano-sop-reply-switch-gate` 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确目标模块为 `data-RC/juzi-service`
- [x] T003 明确参考逻辑为 `fc/delay-mq/.../AppTask.java` 的 `isAiOpen`、`isHomeworkReviewOpen` 和 `isGroupOpen`
- [x] T004 明确门禁适用于所有命中 SOP 点评的 SKU，不限制为 `skuId=4`
- [x] T005 明确 `aiStatus == 1` 且 `aiAutoReview == 1` 才允许单聊调用 `sop-reply`
- [x] T006 明确关闭、空配置、异常配置均不调用 `sop-reply`
- [x] T007 明确异步 SOP 调用和同步 SOP 评估都要受门禁控制
- [x] T008 明确非 SOP 点评链路保持不变
- [x] T009 明确群聊 SOP 点评需要仿照 `AppTask.java#isGroupOpen` 校验 `roomWecomChatId`
- [x] T010 明确后续实现必须补充单元测试覆盖 `skuId=4`、`skuId=5`、开关门禁和群 ID 门禁

## Phase 2：实现

- [ ] T011 在 `juzi-service` 中补齐 AI 自动作业点评配置查询能力，复用或等价实现 `getAiReviewConfig(campDateId, empId)`
- [ ] T012 在 `juzi-service` 中补齐配置 DTO，至少包含 `aiStatus`、`aiAutoReview`、`chatList`、`qwUserId`
- [ ] T013 新增或复用 `isAiOpen(config)`，仅 `aiStatus == 1` 返回 true
- [ ] T014 新增或复用 `isHomeworkReviewOpen(config)`，仅 `aiAutoReview == 1` 返回 true
- [ ] T015 新增或复用 `isGroupOpen(config, campDateId, empId, roomWecomChatId)`，仅 `isHomeworkReviewOpen(config)` 且 `chatList.contains(roomWecomChatId)` 返回 true
- [ ] T016 新增统一 SOP 点评门禁判断，所有 SKU 调用 `sop-reply` 前都必须经过该判断
- [ ] T017 统一门禁判断规则：单聊校验 AI 开关和作业点评开关；群聊额外校验 `roomWecomChatId` 是否命中 `chatList`
- [ ] T018 在 `MessageServiceImpl#tryInvokeSopRouteAsyncWhenNoopFallback` 调用 `sop-reply` 前增加门禁
- [ ] T019 在 `DefaultSopRouteEvaluator#evaluate` 调用 `sop-reply` 前增加门禁
- [ ] T020 确保门禁关闭时不调用 `FcInvokeUtils.doTask`、`doSyncTaskReturnJSONObj` 等 `sop-reply` 调用点
- [ ] T021 门禁关闭时返回现有路由可识别的非 SOP 结果，让既有 fallback 规则继续决定 `GENERAL_CHAT` 或 `NOOP`
- [ ] T022 增加拦截日志，包含 `campDateId`、`empId`、`externalUserId`、`skuId`、`roomWecomChatId` 和配置内容或失败原因
- [ ] T023 保持非 SOP 点评链路、通用聊天和声乐默认链路不变

## Phase 3：验证与单元测试

- [ ] T024 单元测试：`skuId=4` 单聊且 `aiStatus=1`、`aiAutoReview=1` 时仍会调用 `sop-reply`
- [ ] T025 单元测试：`skuId=5` 单聊且 `aiStatus=1`、`aiAutoReview=1` 时仍会调用 `sop-reply`
- [ ] T026 单元测试：`skuId=4` 和 `skuId=5` 在 `aiStatus=0` 时不会调用 `sop-reply`
- [ ] T027 单元测试：`skuId=4` 和 `skuId=5` 在 `aiStatus=1`、`aiAutoReview=0` 时不会调用 `sop-reply`
- [ ] T028 单元测试：配置为空、字段缺失、查询异常时不会调用 `sop-reply`
- [ ] T029 单元测试：`skuId=5` 群聊且 `chatList` 包含当前 `roomWecomChatId` 时允许调用 `sop-reply`
- [ ] T030 单元测试：`skuId=5` 群聊且 `chatList` 不包含当前 `roomWecomChatId` 时不会调用 `sop-reply`
- [ ] T031 单元测试：任意 SKU 群聊且 `chatList` 为空、配置为空或 `roomWecomChatId` 为空时不会调用 `sop-reply`
- [ ] T032 单元测试：任意 SKU 单聊且开关全开时，不因缺少 `roomWecomChatId` 被拦截
- [ ] T033 单元测试：异步 SOP 调用路径被开关门禁和群 ID 门禁拦截
- [ ] T034 单元测试：同步 SOP 评估路径被开关门禁和群 ID 门禁拦截
- [ ] T035 单元测试：门禁关闭且规则配置通用聊天 fallback 时仍按现有 `GENERAL_CHAT` 规则处理
- [ ] T036 单元测试：非 SOP 点评链路不受新增开关门禁和群 ID 门禁影响
- [ ] T037 验证 `data-RC/juzi-service` 编译通过

## 执行记录

### D001 - 文档记录

- 已完成规格、任务清单、执行说明和需求检查清单。
- 本轮按要求仅修改文档，未进行代码实现。

### D002 - 群 ID 与单元测试补充

- 已补充群聊 SOP 点评需要校验 `roomWecomChatId` 命中 `chatList` 的任务。
- 已补充后续实现必须增加单元测试，覆盖开关门禁、群 ID 门禁、单聊和非 SOP 链路场景。

### D003 - 全 SKU 范围补充

- 已将门禁范围从 `skuId=4` 扩展为所有命中 SOP 点评的 SKU。
- 已补充 `skuId=5` 的实现和单元测试要求。
