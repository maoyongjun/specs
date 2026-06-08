# 任务清单：企微打标签限流与 OTS 一致性

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：当前已进入实现阶段；必须保留编译验证记录，发布前建议补齐代理函数入参、MQ、接口、OTS 和三次 get 的自动化测试。

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
- [x] T008 记录新链路不能直接 HTTP 调企微，也不能通过 `AppTask` 中转，必须直接调用企微代理函数。
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

- [x] T016 在 `fc/common` 的 `EmpExternalTag` 增加 `fc_action` 和 `ots_write_mode`。
- [x] T017 在 `CompleteTagUtil` 增加 `doGetExternalContact(Integer source, String externalUserId)`。
- [x] T018 改造 `AppTask.handleRequest(...)`，支持 `MARK_TAG` 和 `GET_EXTERNAL_CONTACT` 双模式。
- [x] T019 改造 `AppTask` 打标签返回值和 OTS 写入判断。
- [x] T020 在 `kkhc-idc/ai` 新增 `POST /qwTag/markAsync`。
- [x] T021 新增任务表、任务日志表对应 mapper/service。
- [x] T021A 补充 `drh_qw_external_tag_task` 和 `drh_qw_external_tag_task_log` 建表 SQL。
- [x] T022 新增 `QW_EXTERNAL_TAG_MARK` 消费者，限速调用企微代理函数执行 `mark_tag`。
- [x] T023 新增 `QW_EXTERNAL_TAG_VERIFY` 延迟确认消费者。
- [x] T024 实现 `QwExternalTagTaskService.verifyAndUpdateOts(taskId)`，通过企微代理 get 确认后写 OTS。
- [x] T025 实现 `mark_tag` 失败不拉取、三次超时只打日志、重复 MQ 幂等。
- [x] T025A 将 `kkhc-idc/ai` 新链路 MARK/GET 从 `AppTask` 中转改为直接调用 `qw-api-proxy/qw-api-proxy-test`。
- [x] T025B 同步文档，明确新链路废止 `async-util/sync-external-tag` 和 `async-util/cpv-qw-tag-util-test` 调用。

## Phase 5：后续测试与验证

- [ ] T026 FC 测试：旧调用默认路径保持兼容。
- [ ] T027 FC 测试：`CALLER_VERIFY_WRITE` 路径不写 OTS。
- [ ] T028 FC 测试：`GET_EXTERNAL_CONTACT` 路径不校验标签列表，调用 get 代理。
- [ ] T029 Controller 测试：接口校验、落任务、发送 MQ、返回 `taskId`。
- [ ] T030 MQ 测试：`QW_EXTERNAL_TAG_MARK` 消费者按 `MessageType/tag` 过滤，重复消息幂等。
- [ ] T031 限速测试：断言企微代理函数调用发生在 `rateLimiter` 内。
- [ ] T032 三次确认测试：第 1 次立即调用企微代理 get，第 2/3 次延迟 MQ 调用企微代理 get，三次失败置 `VERIFY_TIMEOUT`。
- [ ] T033 失败测试：`errcode=60111` 不触发 get，不写 OTS。
- [ ] T034 OTS 测试：只更新 `drh_external_user_info` 中目标 `external_user_id + userid` 的标签。
- [x] T035 运行目标模块编译验证并记录结果。
- [x] T036 静态验证新链路不再调用 `async-util/sync-external-tag`、`async-util/cpv-qw-tag-util-test`、`AppTask`。
- [x] T037 静态验证 MARK 代理入参包含 `source/reqType=2/actionType=1/url/body`，GET 代理入参包含 `source/reqType=1/actionType=1/url`。

## 执行记录

### D001 - 文档记录

- 执行内容：创建企微打标签限流与 OTS 一致性 Spec Kit 文档。
- 验证方式：静态检查文档结构、关键路径、参数、MQ tag、表名、三次 get 和旧链路兼容口径。
- 自检结论：满足文档阶段门禁；未修改业务代码。

### D002 - 实现记录

- 实现内容：已完成 FC 双模式、idc-ai 异步入口、任务表模型、MQ 生产消费、限速调用、三次 get 确认、OTS 确认写入和文档 SQL。
- 测试命令：
  - `C:\workspace\ju-chat\fc`：`mvn -pl common,qw-tag -am -DskipTests compile`
  - `C:\workspace\ju-chat\kkhc\kkhc-idc`：`mvn -pl ai -am -DskipTests compile`
- 测试结果：两个命令均 `BUILD SUCCESS`。
- 自检结论：实现项已落地并通过目标模块编译；未新增自动化单测，测试门禁项仍需后续补齐。

### D003 - MQ 口径纠正记录

- 触发原因：用户补充 MQ 发送必须使用 `delayProducerBean.sendTagMessage`，初始延迟 `10ms`。
- 修正内容：MARK MQ 使用 `System.currentTimeMillis() + 10L`；VERIFY MQ 保持 10s/20s；新增独立 consumer group。
- 文档同步：已同步 `spec.md`、`tasks.md`、`checklists/requirements.md`。
- 验证结果：目标模块编译通过。

### D004 - 新链路直连企微代理函数纠正记录

- 触发原因：用户明确要求 MARK 和 GET 不再通过 `fc/qw-tag/AppTask` 中转，改为直接调用 `invokeQwProxyFc` 对应的企微代理函数。
- 修正内容：`QwExternalTagTaskServiceImpl` 的 MARK/GET 调用改为直接构造 `qw-api-proxy/qw-api-proxy-test` 入参；`test_delay` 走 `service_sys/qw-api-proxy-test`，其他 topic 走 `ai-service/qw-api-proxy`。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 的新链路口径。
- 验证结果：
  - `C:\workspace\ju-chat\kkhc\kkhc-idc`：`mvn -pl ai -am -DskipTests compile`，结果 `BUILD SUCCESS`。
  - 静态验证：`QwExternalTagTaskServiceImpl` 不再出现 `async-util`、`sync-external-tag`、`cpv-qw-tag-util-test` 或 `AppTask` 引用。
  - 静态验证：MARK/GET 代理入参构造包含 `source`、`reqType`、`actionType`、URL 和 MARK body。
