# 任务清单：P1 接口安全整改清单影响表整理

**输入**：来自 `spec.md` 的功能规格和 `P1级接口安全整改清单.csv`  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：本规格阶段只做文档和静态验证，不运行业务编译或接口测试。

## Phase 1：代码事实确认

- [x] T001 读取 CSV 并确认非空整改记录数为 13。
- [x] T002 读取 `specs/_template`，确认新规格目录应包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- [x] T003 对比 `050-phone-security-interface-db-mapping`、`051-phone-security-ddl-summary`、`066-phone-security-interface-gap-audit`，确认历史接口、表名和字段口径。
- [x] T004 用 `rg` 静态确认 kkhc 侧仍存在的 `getPhone` 查询和响应赋值证据。
- [x] T005 用 `rg` 静态确认 drh-kk-cms 侧已部分整改项和仍待改项。
- [x] T006 用 `rg` 静态确认 drh-media-process 外呼 / 短信回调任务链路作为非 HTTP 风险记录。

## Phase 2：风险门禁

- [x] T007 确认本规格只新增文档，不修改业务代码、DDL、SQL 或历史规格目录。
- [x] T008 将 CSV 原始待修改点和当前代码状态分开记录。
- [x] T009 将已出现 `phoneMd5` / `phone_mask` 的接口标记为已部分整改或需复核。
- [x] T010 将外呼 / 短信回调任务链路标记为非 HTTP 风险，不作为单一 HTTP 接口验收。
- [x] T011 对每个矩阵项记录影响表、字段方向、当前状态和验证要点。

## Phase 3：文档创建

- [x] T012 创建 `072-p1-interface-security-table-impact/AGENTS.md`。
- [x] T013 创建 `072-p1-interface-security-table-impact/spec.md`。
- [x] T014 创建 `072-p1-interface-security-table-impact/tasks.md`。
- [x] T015 创建 `072-p1-interface-security-table-impact/checklists/requirements.md`。
- [x] T016 在 `spec.md` 记录 D001 文档执行记录。

## Phase 4：静态验证

- [x] T017 确认 `spec.md` 的接口矩阵覆盖 13 条 CSV 非空记录。
- [x] T018 确认 `spec.md` 包含数据库表聚合视图。
- [x] T019 确认 `spec.md` 区分 `待改`、`已部分整改 / 需复核`、`非 HTTP 风险`。
- [x] T020 确认新文档无模板占位符残留。
- [x] T021 确认 `requirements.md` 已勾选文档质量、需求完整性和实施就绪度。

## 静态搜索记录

- CSV 统计：`Import-Csv ... | Where-Object { $_.'接口 / 入口' -or $_.'待修改点' -or $_.'代码证据 / 备注' } | Measure-Object`，结果为 `13`。
- kkhc 待改证据：
  - `OrderPageProcessorDataFacade`：app/lms/ai 均存在 `record.setPhone(liveUser.getPhone())`。
  - `OrderGoodReissueDetailServiceImpl`、`OrderBookReissueServiceImpl`：存在 `OrderGoodReissueDetailDO::getPhone`。
  - `AppletUserController`、`AppletUserServiceImpl`：存在 `setEntity(appletUserDo)`。
  - `WxComplaintOrderServiceImpl`：存在 `WechatComplaintOrderDO::getPhone`。
  - `LeadsNoqwSendMsgTaskDetailServiceImpl`：存在 `LeadsNoqwSendMsgTaskDetailDO::getPhone`。
  - `UserServiceRecordServiceImpl`：存在 `UserServiceRecordDO::getPhone`。
  - `InfluencerServiceImpl`：存在 `InfluencerDO::getPhone`。
- drh-kk-cms 状态证据：
  - `FrontWorkServiceImpl`：查询条件已见 `AppletUser::getPhoneMd5`，但仍有 `appletUser.getPhone()` 展示或派生读取。
  - `FrontMyClassBaseServiceImpl`：查询条件已见 `AppletUser::getPhoneMd5`，select 仍包含 `AppletUser::getPhone`。
  - `ImportAddressRecordDetailServiceImpl`：仍有 `ImportAddressRecordDetail::getPhone`。
  - `MallOrderMapper.xml`：已见 `reciver_phone_md5` 查询和 `reciver_phone_mask reciverPhone` 返回。
  - `MessageTriggerLogServiceImpl`：已见 `VoiceRobotTaskUser::getPhoneMd5`、`SmsTriggerUser::getPhoneMd5`。
- drh-media-process 风险证据：
  - `VoiceRobotCallbackDetailsServiceImpl`：仍有 `VoiceRobotCallbackDetails::getPhone` 分组和 `in` 查询。
  - `VoiceRobotTaskUserServiceImpl`：已见 `DataSecurityInvoke::computePhoneMd5` 和 `VoiceRobotTaskUser::getPhoneMd5`。
  - `OutboundTriggerTaskHandle`、`SmsTriggerBaiWuUserCallBackHandler`：仍有明文 phone 集合或回调处理。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `072-p1-interface-security-table-impact` 规格目录，整理 CSV 13 条接口整改项的接口矩阵和影响表聚合视图。
- 验证方式：读取 CSV、模板和历史手机号安全规格；用 `rg` 静态确认关键代码证据；检查模板占位符。
- 自检结论：本次只新增文档目录，未修改业务代码、DDL、SQL 或历史规格。

### D002 - 后续纠正记录模板

- 触发原因：`用户补充/测试失败/代码审查发现/当前代码状态变化`
- 修正内容：`说明具体修正`
- 文档同步：`说明同步了哪些文件`
- 验证结果：`说明静态搜索、接口测试或编译结果`
