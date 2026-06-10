# 任务清单：手机号安全漏改整改执行

**输入**：来自 `spec.md` 的功能规格与 `066` 漏改清单  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`；目标表 `*_md5/*_mask/*_aes` 列已由 `032/051/063` 提供；历史回填由 `juzi-service` 负责  
**测试**：每个修复点必须补充与关键行为一一对应的静态搜索、编译或单测记录。

## Phase 0：前置确认

- [ ] T001 确认三套 `DataSecurityInvoke` 所在模块与方法签名（kkhc `ai-common`、kkhc `base-common`、drh `drh-common`），各修复点只引用本模块工具。
- [ ] T002 确认目标表 `*_md5`（含索引）、`*_mask`、`*_aes` 列已存在；缺列的表（重点 `drh_mall_order`）登记到风险并对齐 `051` DDL。
- [ ] T003 确认 `juzi-service` 回填范围覆盖本规格涉及表，记录上线与回填的对齐策略（避免 `*_md5` 为空导致旧数据查不到）。
- [ ] T004 确认 `065` app `/app/collect/order/pageQuery` 返回 `phoneAes` 例外不在本规格回退范围。

## Phase 1：实体字段补齐（决策 6）

- [x] T005 `lms-common AppletUserDo` 补齐 `phoneMask/phoneMd5/phoneAes` 字段与 `createAesInfo()`，对齐 `ai-common` 版本（保留明文 `phone`）。 [K8]
- [x] T006 `drh MallOrder` 补齐 `reciverPhoneMask/reciverPhoneMd5/reciverPhoneAes` 与 `createAesInfo()`（保留明文 `reciver_phone`）。 [D4]
- [~] T007 `drh-kk-cms ImportAddressRecordDetail` —— **N/A**：drh-kk-cms 无该本地实体/Service，`collect/order/import/address/detail` 为 Feign 透传到 lms（已由 `063` 覆盖）。无需在 drh 侧补。 [D3]
- [x] T008 kkhc 模块编译通过（JDK8，exit 0）；drh-common/drh-kk-cms/drh-media-process 编译进行中。

## Phase 2：kkhc 漏改修复

- [x] T009 [K1] `OrderPageProcessorDataFacade`（app、lms）`:309`：`setPhone` 改为 `DataSecurityInvoke.phoneMaskForDisplay(liveUser.getPhoneMask(), liveUser.getPhoneAes())`，对齐 ai。
- [x] T010 [K2] `OrderGoodReissueDetailServiceImpl`（lms、ai）`:169`：现算 `phoneMd5` 查 `getPhoneMd5`；手机号为空走原条件，非法返回空页。
- [x] T011 [K3] `AppletUserController.getOneByCondition`（app、lms）+ `getListByEntity`（app、lms、ai）：入参有 `phone` 时现算 `phoneMd5` 改查 `getPhoneMd5`，非法返回空；**返回值不掩码**——`LarkServiceImpl.complaint` 等内部消费方需要真实 `phone`（保留明文列读取口径，安全风险点已在查询侧消除）。
- [x] T012 [K3] `LeadsController.select`（kkhc-bizcenter/app）：由 idc 侧 `getOneByCondition` 统一把明文 `phone` 转 `phoneMd5` 查询；bizcenter 不引入 FC 依赖，DB 查询已落 `phone_md5`。
- [x] T013 [K4] `WxComplaintOrderServiceImpl`（lms）：`saveComplaintOrder` 保存前生成安全字段；`getWxComplaintOrderCount` `:52` 统计改 `phoneMd5`。
- [x] T014 [K5] `LeadsNoqwSendMsgTaskDetailServiceImpl`（lms、ai）`:121`：查 `phoneMd5`；`exportList/listAll/pageList` 返回掩码。
- [x] T015 [K6] `UserServiceRecordServiceImpl`（lms）：`getRecords:99` 改查 `phoneMd5`；`createRecord`/`batchCreateUploadRecord` 调 `createAesInfo()`（新增 `UserServiceRecordDO.createAesInfo()`）。
- [x] T016 [K7] `InfluencerServiceImpl` add `:90` / edit `:163`（lms）：重复校验改 `phoneMd5` 唯一性；保存生成安全字段。
- [x] T017 [K9] `OrderBookReissueServiceImpl`（ai）`:145`：用 `DataSecurityInvoke.computePhoneMd5` 替换裸 `DigestUtils.md5DigestAsHex`，统一归一化口径。**勘误**：审计所称"`isEmpty` 写反"不成立（实为 `!isEmpty`），真实问题是 MD5 口径不一致，已修。

## Phase 3：drh 漏改修复

- [x] T018 [D1] `FrontWorkServiceImpl.queryList`（drh-kk-cms）`:106`：`LIKE` 改 `eq getPhoneMd5`（决策 5，drh-common `DataSecurityInvoke`）。
- [x] T019 [D2] `FrontMyClassBaseServiceImpl`（drh-kk-cms）`:171`：`LIKE` 改 `eq getPhoneMd5`（决策 5）。
- [~] T020 [D3] —— **N/A**：drh-kk-cms 无 `ImportAddressRecordDetail` 实体/Service（Feign 透传到 lms，已由 `063` 覆盖）。
- [x] T021 [D4] `MallOrderMapper.xml`（drh-kk-cms）：`list` 改 `reciver_phone_md5` 精确（bind `computePhoneMd5`），select 改 `reciver_phone_mask reciverPhone` 返回掩码；`mall/save`（`MallOrderServiceImpl.doSaveOrder`）保存前调 `input.createAesInfo()`（`MallOrderSaveInput extends MallOrder`，继承 T006 方法）。**依赖 DDL**：`drh_mall_order` 须已有 `reciver_phone_md5/_mask/_aes` 列，否则查询/保存报错——须先于上线建列。
- [x] T022 [D5] `MessageTriggerLogServiceImpl`（drh-kk-cms）`:402/412`：入参 phones 归一为 md5 集合，`in` 查 `phoneMd5`（新增 `toPhoneMd5List` 私有方法）。
- [x] T023 [D6] `VoiceRobotTaskUserServiceImpl`（drh-media-process）`:80`：`updateIsCallBack` 集合归一为 md5，`in` 查 `phoneMd5`。
- [x] T024 [D7] `VoiceRobotCallbackDetailsServiceImpl`（drh-media-process）：**保存侧**——`batchSaveOrUpdate` 对新回调记录调 `createAesInfo()`（新增 `VoiceRobotCallbackDetails.createAesInfo()`），确保 `phoneMd5/mask/aes` 落库供 D5/D6 的 md5 查询命中。**存在性查询 `getExistingRecordsMap` 仍按明文 `phone` 查**：明文列保留（决策 6）查询正确；若改 md5 会漏掉未回填记录→重复插入，故按保留口径处理。
- [~] T025 [D8] `VoiceRobotServiceImpl`（drh-kk-cms）`getCallPhone/getPhoneCallbackDetailMap`：**按保留口径不改**。该处为外呼**限频计数**，读取的是保留明文列（`LiveUser.phone`、`VoiceRobotCallbackDetails.phone`）做内存匹配，无对客户端的新增明文暴露；改 md5 会（1）漏未回填记录→突破限频重复外呼，（2）`LiveUser` 无 md5 字段须 per-phone 走 FC→外呼批量场景 FC 风暴。回调记录的 md5 已由 D7 保存侧补齐。
- [~] T026 [D9] `UserTriggerSetServiceImpl`（drh-kk-cms）触达报表：**按保留口径不改**。`callbackPhones/notCallbackPhones` 等为两实体已加载列表的**内存 Set 匹配**，明文列保留即正确；改 `getPhoneMd5()` 在未回填期会因 null 导致报表数错。返回的 `phone` 与 K3/Lark 同理，运营需真实号码跟进，保留明文（决策 6）。
- [x] T027 [D10] `OutboundTriggerTaskHandle`：外呼限频 Redis key/value 改用 `user.getPhoneMd5()`（已加载字段，**不走 FC**；未回填记录回退明文，迁移安全），并去掉日志中的明文手机号；外部 `executeCall` 仍用明文（必要明文）。`SmsTriggerBaiWuUserCallBackHandler` 保存侧**已自带**安全字段生成（`:138-144`），其余为内存明文匹配按保留口径不改。

## Phase 4：静态验证

- [ ] T028 `rg` 确认修复点不再出现旧的 `::getPhone` 精确/集合查询、`phone LIKE`、`reciver_phone LIKE`（白名单：外部请求所需明文）。
- [ ] T029 抽查各精确查询接口，确认 SQL 条件落到 `*_md5`。
- [ ] T030 抽查各列表/详情响应，确认 `phone` 不返回明文；`065` 特例保持 `phoneAes`。
- [ ] T031 确认保存链路均调用 `createAesInfo()` 或等价方法，无"保存后异步补齐"作为唯一保障。

## Phase 5：编译与单测

- [x] T032 编译 kkhc 相关模块通过（JDK8 `jdk1.8.0_481`，exit 0）：`mvn -f .../kkhc-idc/pom.xml -pl base-common,ai-common,lms-common,app,lms,ai -am -DskipTests compile`。
- [ ] T033 编译 kkhc-bizcenter 相关模块。
- [ ] T034 编译 drh：`drh-common`、`drh-kk-cms`、`drh-media-process` 相关模块。
- [ ] T035 为 `computePhoneMd5` 直通与 `OrderBookReissueServiceImpl` 修正补单测；为新增/补齐实体的 converter 掩码输出补单测（避免真实访问 Redis/OTS/MQ/FC）。
- [ ] T036 运行目标单测并记录结果。

## Phase 6：回归与收尾

- [ ] T037 按 `050/066` 接口矩阵回归 kkhc app/lms/ai 与 drh-kk-cms、drh-media-process 受影响接口。
- [ ] T038 保留 `C:\workspace\drh` 现有未提交改动，不回滚用户改动。
- [ ] T039 同步 `spec.md` D002 实现记录、`tasks.md` 勾选状态与 `066` 后续修复任务的对应关系。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `067-phone-security-gap-remediation` 规格目录，按 `066` 漏改清单和用户六项决策拆分 K1–K9、D1–D10 修复任务。
- 验证方式：复用 `066` 审计证据，并经 kkhc/drh 代码静态确认每个 `file:line`。
- 自检结论：任务覆盖精确查询、掩码返回、保存生成安全字段、模糊改精确、逻辑 bug 修正、实体补齐六类；工具合并与历史回填明确排除。

### D002 - 实现记录（第一批）

- 实现内容：
  - kkhc 全部完成（K1–K9）：`OrderPageProcessorDataFacade`(app/lms) 掩码展示；`OrderGoodReissueDetailServiceImpl`(lms/ai) 改 `phoneMd5` 查询；`AppletUserController.getOneByCondition`(app/lms)+`getListByEntity`(app/lms/ai) 明文 `phone` 入参转 `phoneMd5` 查询；`WxComplaintOrderServiceImpl` 保存生成安全字段+统计走 `phoneMd5`；`LeadsNoqwSendMsgTaskDetailServiceImpl`(lms/ai) 改 `phoneMd5`；`UserServiceRecordServiceImpl` 查询+创建链路；`InfluencerServiceImpl` add/edit 查重+保存；`OrderBookReissueServiceImpl` 统一 `computePhoneMd5`。
  - 新增实体安全方法：`lms-common AppletUserDo`(补字段+`createAesInfo`)、`WechatComplaintOrderDO`、`UserServiceRecordDO`、`InfluencerDO`（后三者新增 `createAesInfo()`）。
  - drh 完成：`MallOrder` 补 `reciverPhone*` 字段+`createAesInfo`；`FrontWorkServiceImpl`/`FrontMyClassBaseServiceImpl` 模糊改 `phoneMd5` 精确；`MallOrderMapper.xml` 查询改 `reciver_phone_md5`、select 返回 `reciver_phone_mask`；`MessageTriggerLogServiceImpl` 集合归一 md5+`in`；`VoiceRobotTaskUserServiceImpl`(media-process) `updateIsCallBack` 集合 md5。
  - 模块工具引用：kkhc app/lms 用 `base-common DataSecurityInvoke`，ai 用 `ai-common`；drh 用 `drh-common`（三套副本保留现状，决策 1）。
- 测试命令：
  - `JAVA_HOME=jdk1.8.0_481 mvn -f .../kkhc-idc/pom.xml -pl base-common,ai-common,lms-common,app,lms,ai -am -DskipTests compile` → **通过（exit 0）**。
  - `JAVA_HOME=jdk1.8.0_481 mvn -f C:\workspace\drh\pom.xml -pl drh-common,drh-kk-cms,drh-media-process -am -DskipTests compile` → 进行中。
- 测试结果：kkhc 编译通过；drh 编译结果待补。
- 待办（第二批）：D7（`VoiceRobotCallbackDetailsServiceImpl` groupBy/集合）、D8（`VoiceRobotServiceImpl` Map key/groupBy）、D9（`UserTriggerSetServiceImpl` Set/contains）、D10（`OutboundTriggerTaskHandle`/`SmsTriggerBaiWuUserCallBackHandler` Redis key + 外部明文边界）；`mall/save` 创建链路定位并补 `createAesInfo()`；T035/T036 单测；T037 接口回归。
- 关键依赖：`drh_mall_order` 等表 `*_md5/_mask` 列须先于上线由 DDL（`051`）建好，历史数据由 `juzi-service` 回填后再切查询，避免旧数据查空。
- 自检结论：精确查询统一 `phoneMd5`；保存链路生成安全字段；模糊改精确（决策 5）；明文 `phone` 列保留（决策 6）；工具未合并（决策 1）；回填不在本规格（决策 2）。`AppletUser*` 等内部 Feign 返回值保留真实 `phone`（Lark 投诉通知依赖），仅消除查询侧明文。

### D003 - 纠正记录（漏改的并行副本）

- 触发原因：静态验证（`rg`）发现 `kkhc-idc` 的 **app/lms/ai 三套并行副本**中，第一批只改了审计点名的 lms/ai，遗漏了大量 **app** 副本及部分 ai 副本；且 `lms-common`/`ai-common` 双份 DO 也需各自补 `createAesInfo`。
- 修正内容（补齐至全部副本）：
  - `OrderGoodReissueDetailServiceImpl`：补 **app** 副本（K2，lms/ai 已改）。
  - `LeadsNoqwSendMsgTaskDetailServiceImpl`：补 **app** 副本（K5）。
  - `UserServiceRecordServiceImpl`：补 **app + ai** 副本（K6），并给 **ai-common** `UserServiceRecordDO` 补 `createAesInfo()`（lms-common 已补）。
  - `WxComplaintOrderServiceImpl`：补 **app** 副本（K4，保存生成 + 统计 `phoneMd5`）。
  - `OrderBookReissueServiceImpl`（K9）：除 ai `:145` 外，补 **app/lms/ai 三套**的「分页 md5 计算块」与「`getExportDataList` 导出 md5 计算」两处，统一 `DigestUtils.md5DigestAsHex` → `DataSecurityInvoke.computePhoneMd5`。
  - `lms AppletUserController.getEasyOneByCondition`：第二个 `setEntity(appletUserDo)` 入口（首轮只改了 `getOneByCondition`），补 phone→`phoneMd5` 转换。
- 文档同步：本 `tasks.md`（D002/D003）已更新；`spec.md` 修复清单口径不变（K2/K4/K5/K6/K9 范围扩展为"全部 app/lms/ai 副本"）。
- 验证结果：`rg` 复扫确认 `::getPhone,` 精确查询、`setPhone(liveUser.getPhone())`、`DigestUtils.md5DigestAsHex(input.getPhone` 已全部消除；kkhc 全模块 JDK8 重新编译验证中。
