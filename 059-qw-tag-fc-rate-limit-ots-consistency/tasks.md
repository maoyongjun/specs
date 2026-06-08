# 任务清单：企微打标签限流与 OTS 一致性

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：本阶段只创建文档；后续实现阶段必须补充 FC、MQ、接口、OTS 和三次 get 的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 确认规格目录为 `C:\workspace\ju-chat\specs\059-qw-tag-fc-rate-limit-ots-consistency`。
- [x] T002 确认 `fc/qw-tag/AppTask` 当前默认执行打标签并在函数内写 OTS。
- [x] T003 确认 `CompleteTagUtil.doResponseTag(...)` 通过 `invokeQwProxyFc(...)` 访问企微 `externalcontact/mark_tag`。
- [x] T004 确认 `EmpExternalTag` 来自 `C:\workspace\ju-chat\fc\common\src\main\java\com\drh\common\dto\EmpExternalTag.java`。
- [x] T005 确认 `kkhc-idc/ai` 已有 `QwTagController` 和 `DelayProducerBean` 等 MQ 基础设施。

**检查点**：文档已基于真实代码落点编写；本阶段不进入代码实现。

## Phase 2：风险门禁

- [x] T006 记录 `AppTask` 必须先按 `fc_action` 分流，再执行旧的标签列表非空校验。
- [x] T007 记录旧调用兼容规则：不传 `fc_action/ots_write_mode` 时保持原行为。
- [x] T008 记录 `GET_EXTERNAL_CONTACT` 不能直接 HTTP 调企微，必须通过同一个 `AppTask` 和企微代理函数。
- [x] T009 记录 `mark_tag errcode != 0` 时不触发 get，不写 OTS。
- [x] T010 记录三次 get 编排位置：`kkhc-idc/ai` 的任务服务与 MQ 消费者。
- [x] T011 建立后续测试映射：FC 双模式、限速、MQ、三次 get、OTS 更新、旧链路兼容。

**检查点**：强制门禁已写入 `spec.md` 和 `checklists/requirements.md`。

## Phase 3：文档创建

- [x] T012 创建 `spec.md`，记录背景、用户故事、FC 改造、idc-ai 调用方式、数据/MQ、边界和需求。
- [x] T013 创建 `tasks.md`，记录事实确认、风险门禁、后续实现任务和测试任务。
- [x] T014 创建 `AGENTS.md`，记录目标模块、固定实现口径和强制门禁。
- [x] T015 创建 `checklists/requirements.md`，记录文档质量和后续实施检查项。

## Phase 4：后续实现任务

- [ ] T016 在 `fc/common` 的 `EmpExternalTag` 增加 `fc_action` 和 `ots_write_mode`。
- [ ] T017 在 `CompleteTagUtil` 增加 `doGetExternalContact(Integer source, String externalUserId)`。
- [ ] T018 改造 `AppTask.handleRequest(...)`，支持 `MARK_TAG` 和 `GET_EXTERNAL_CONTACT` 双模式。
- [ ] T019 改造 `AppTask` 打标签返回值和 OTS 写入判断。
- [ ] T020 在 `kkhc-idc/ai` 新增 `POST /qwTag/markAsync`。
- [ ] T021 新增任务表、任务日志表对应 mapper/service。
- [ ] T022 新增 `QW_EXTERNAL_TAG_MARK` 消费者，限速调用打标签 FC。
- [ ] T023 新增 `QW_EXTERNAL_TAG_VERIFY` 延迟确认消费者。
- [ ] T024 实现 `QwExternalTagTaskService.verifyAndUpdateOts(taskId)`，通过 get FC 确认后写 OTS。
- [ ] T025 实现 `mark_tag` 失败不拉取、三次超时只打日志、重复 MQ 幂等。

## Phase 5：后续测试与验证

- [ ] T026 FC 测试：旧调用默认路径保持兼容。
- [ ] T027 FC 测试：`CALLER_VERIFY_WRITE` 路径不写 OTS。
- [ ] T028 FC 测试：`GET_EXTERNAL_CONTACT` 路径不校验标签列表，调用 get 代理。
- [ ] T029 Controller 测试：接口校验、落任务、发送 MQ、返回 `taskId`。
- [ ] T030 MQ 测试：`QW_EXTERNAL_TAG_MARK` 消费者按 `MessageType/tag` 过滤，重复消息幂等。
- [ ] T031 限速测试：断言打标签 FC 调用发生在 `rateLimiter` 内。
- [ ] T032 三次确认测试：第 1 次立即 get，第 2/3 次延迟 MQ get，三次失败置 `VERIFY_TIMEOUT`。
- [ ] T033 失败测试：`errcode=60111` 不触发 get，不写 OTS。
- [ ] T034 OTS 测试：只更新 `drh_external_user_info` 中目标 `external_user_id + userid` 的标签。
- [ ] T035 运行目标模块测试并记录结果。

## 执行记录

### D001 - 文档记录

- 执行内容：创建企微打标签限流与 OTS 一致性 Spec Kit 文档。
- 验证方式：静态检查文档结构、关键路径、参数、MQ tag、表名、三次 get 和旧链路兼容口径。
- 自检结论：满足文档阶段门禁；未修改业务代码。

### D002 - 实现记录

- 实现内容：待后续实现完成后补充。
- 测试命令：待后续实现完成后补充。
- 测试结果：待后续实现完成后补充。
- 自检结论：待后续实现完成后补充。

### D003 - 纠正记录模板

- 触发原因：说明为什么需要纠正。
- 修正内容：说明具体修正。
- 文档同步：说明同步了哪些文件。
- 验证结果：说明测试或静态验证。
