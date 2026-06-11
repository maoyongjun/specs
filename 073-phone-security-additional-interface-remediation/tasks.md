# 任务清单：手机号安全补充接口整改

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试、编译或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 确认本规格目录为 `073-phone-security-additional-interface-remediation`，当前只创建文档，不修改业务代码。
- [x] T002 确认 `drh_leads_noqw_send_msg_task_detail` 的入口为 `kkhc-idc app/lms/ai /leads-noqw-send-msg-task-detail/*` 和 `kkhc-bizcenter lms` 页面/导出入口。
- [x] T003 确认 `LeadsNoqwSendMsgTaskDetailServiceImpl` 三份副本仍存在 `LeadsNoqwSendMsgTaskDetailDO::getPhone` 查询。
- [x] T004 确认 `LeadsNoqwSendMsgTaskDetailDO` 在 `lms-common` / `ai-common` 只有 `phone`，未见 `phoneMask/phoneMd5/phoneAes`。
- [x] T005 确认 `drh_applet_player` 的入口为 `drh-kk-cms /applet/activity/detail/page|detail/export|preNext|player/detail`。
- [x] T006 确认 `AppletPlayerServiceImpl` 已计算 `phoneMd5`，`AppletPlayerMapper.xml` 已按 `ap.phone_md5` 查询。
- [x] T007 确认 `AppletPlayerMapper.xml` 仍 `select ap.*`，`AppletPlayOutput` 仍有 `@CsvField("手机号") private String phone` 输出风险。
- [x] T008 确认 `drh_sms_deal` 的入口为 `drh-media-process /smsDeal/DTask|MTask` 和 XXL Job `DTaskV2`。
- [x] T009 确认 `HandoverPlusMapper.xml saveSmsDtosBatch` 只插入 `phone`，4 个 SELECT 只取 `lu.phone`。
- [x] T010 确认 `DealSmsDto` 只有 `phone`，未见 `phoneMask/phoneMd5/phoneAes`。
- [x] T011 对比 `048/051/069`，确认 `drh_sms_deal` 的 `phone_*` DDL 和索引已纳入历史规格。

**检查点**：实现前必须基于 T001-T011 的事实，不得重新引入明文字段查询或明文导出。

## Phase 2：风险门禁

- [ ] T012 检查 `LeadsNoqwSendMsgTaskDetailCondition.phone` 的 `phoneMd5` 计算位置，确保在构造 Wrapper 前完成。
- [ ] T013 检查任务明细创建、更新和 `LeadsNoqwSendMsgTaskServiceImpl` 任务生成链路，确保保存前生成安全字段。
- [ ] T014 检查 `LeadsNoqwMsgConvert` 对 Output 和 Excel DTO 的映射，确保 `phone` 输出值为掩码。
- [ ] T015 检查 `AppletPlayerMapper.xml` 的 SELECT 列，避免 `select ap.*` 继续把明文 `phone` 映射到输出。
- [ ] T016 检查 `AppletPlayerServiceImpl`、`AppletActivityController.playerDetail` 的单条返回路径，确保 `phone` 覆盖为掩码。
- [ ] T017 检查 `DealSmsDto` 从 XML SELECT 和 `processInBatches` 后补手机号两条路径的安全字段赋值时机。
- [ ] T018 检查 `HandoverPlusMapper.xml saveSmsDtosBatch` 是否存在列和值数量不一致、字段别名不匹配或空安全字段落库风险。
- [ ] T019 检查外部短信发送仍使用明文手机号的边界，确保本次改造不影响供应商请求。
- [ ] T020 检查本次方案是否修改接口契约、短信模板、Redis key、MQ body、调度方式或 DDL；发现变化必须先记录并确认。

**检查点**：T012-T020 必须有明确结论；发现高风险时先更新 `spec.md` 的“历史问题防漏分析”。

## Phase 3：实现任务

- [ ] T021 为 `LeadsNoqwSendMsgTaskDetailDO` 两份 common 副本补齐 `phoneMask/phoneMd5/phoneAes`。
- [ ] T022 为 `LeadsNoqwSendMsgTaskDetailCondition`、Output、Excel DTO 按兼容口径补齐必要安全字段。
- [ ] T023 将 `LeadsNoqwSendMsgTaskDetailServiceImpl` 的 `phone` 查询改为 `phoneMd5` 查询，空手机号保持原逻辑，非法手机号不扩大结果。
- [ ] T024 修改任务明细保存/更新/任务生成链路，保存前生成 `phone_mask/phone_md5/phone_aes`。
- [ ] T025 修改 `LeadsNoqwMsgConvert` 或 Service 返回处理，保证列表、详情和导出 `phone` 为掩码。
- [ ] T026 修改 `AppletPlayerMapper.xml`，显式选择 `phone_mask/phone_md5/phone_aes`，避免 `select ap.*` 暴露明文 `phone`。
- [ ] T027 修改 `AppletPlayerServiceImpl` 或输出转换，保证分页、导出、上一条/下一条输出 `phone` 为掩码。
- [ ] T028 修改 `AppletActivityController.playerDetail` 或下游 Service，保证作品详情不直接返回明文 `AppletPlayer.phone`。
- [ ] T029 为 `DealSmsDto` 补齐 `phoneMask/phoneMd5/phoneAes`。
- [ ] T030 修改 `HandoverPlusMapper.xml` 四个短信 SELECT，读取 `lu.phone_mask phoneMask`、`lu.phone_md5 phoneMd5`、`lu.phone_aes phoneAes`。
- [ ] T031 修改 `HandoverPlusMapper.xml saveSmsDtosBatch`，INSERT 列和值增加 `phone_mask/phone_md5/phone_aes`。
- [ ] T032 修改 `SendSmsTaskServiceImpl.processInBatches` 后补手机号路径，补明文时同步生成或填充安全字段。

## Phase 4：测试与验证

- [ ] T033 新增或更新任务明细查询测试，断言手机号入参转为 `phoneMd5` 条件。
- [ ] T034 新增或更新任务明细保存测试，断言 `phoneMask/phoneMd5/phoneAes` 非空。
- [ ] T035 新增或更新任务明细导出测试，断言导出手机号列不含明文。
- [ ] T036 新增或更新 `AppletPlayer` 分页/导出/上一条/详情测试，断言输出掩码且查询仍使用 `phone_md5`。
- [ ] T037 新增或更新 `HandoverPlusMapper.xml` 相关测试或静态断言，确认 SELECT/INSERT 均包含 `phone_*` 字段。
- [ ] T038 运行目标模块编译或单测；无法运行时记录环境阻塞。
- [ ] T039 执行残留搜索：`LeadsNoqwSendMsgTaskDetailDO::getPhone` 查询、`select ap.*`、`drh_sms_deal (... phone, ... )` 是否仍存在风险。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `073-phone-security-additional-interface-remediation` 规格目录，编写 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- 验证方式：静态搜索 `drh_leads_noqw_send_msg_task_detail`、`drh_applet_player`、`drh_sms_deal` 的接口、Service、DTO 和 XML 证据；对比 `048/051/069/072` 历史规格。
- 自检结论：本阶段仅新增文档，未修改业务代码、DDL、SQL 或历史规格目录；`drh_sms_deal` 和 `HandoverPlusMapper.xml` 已纳入规格。

### D002 - 实现记录模板

- 实现内容：`记录字段补齐、查询改造、掩码输出、XML SELECT/INSERT 改造。`
- 测试命令：`记录 Maven/JUnit/静态搜索命令。`
- 测试结果：`记录通过、失败和环境阻塞。`
- 自检结论：`确认 phoneMd5 查询、掩码输出、保存生成安全字段、XML 写入安全字段均满足规格。`

### D003 - 纠正记录模板

- 触发原因：`用户补充/测试失败/代码审查发现/当前代码状态变化。`
- 修正内容：`说明旧口径和新口径。`
- 文档同步：`说明同步了哪些文件。`
- 验证结果：`说明静态搜索、接口测试或编译结果。`
