# 功能规格：手机号安全漏改整改执行

**功能目录**：`067-phone-security-gap-remediation`  
**创建日期**：`2026-06-09`  
**状态**：Draft（待实现）  
**输入**：基于 `066-phone-security-interface-gap-audit` 的漏改清单，落实用户确认的整改口径，修复 `C:\workspace\ju-chat\kkhc` 和 `C:\workspace\drh` 中仍按明文 `phone` 查询、返回或保存的接口，并补齐缺失安全字段的实体。

## 背景

- 当前问题：`066` 审计确认 kkhc 与 drh 仍存在多处明文手机号查询/返回/保存；且原审计把 `ai` 模块当干净基线，实际 `ai` 自身也有漏改（补发明细查询、无企微任务明细查询）。
- 当前行为：部分接口仍用 `::getPhone`、`phone LIKE`、`reciver_phone LIKE` 查询，或返回明文 `phone`；`lms-common AppletUserDo`、`drh MallOrder`、`drh-kk-cms ImportAddressRecordDetail` 缺安全字段。
- 目标行为：精确查询统一走 `phoneMd5`，集合查询走 `phoneMd5 in`，默认响应展示掩码并保留安全字段，保存链路生成安全字段；缺失安全字段的实体补齐。
- 非目标：不合并三套加解密工具；不在本规格做历史数据回填（由 `juzi-service` 负责）；不扩展到 `048b/051` 的 P2/P3 扩展表（除本清单已列接口涉及的表）；不删除或清空原始明文 `phone` 字段。

## 用户确认的整改口径

1. 三套 `DataSecurityInvoke` 副本（kkhc `ai-common`、kkhc `base-common`、drh `drh-common`）保留现状，不合并。
2. 历史数据由 `juzi-service` 已编写方法回填，本规格不做回填。
3. `ai` 模块未改全的接口一并修复。
4. 修正 `OrderBookReissueServiceImpl` 的 `phoneMd5` 计算逻辑 bug。
5. `frontWork`、`front/myClass`、`mall/list` 的模糊搜索改为基于 `phoneMd5` 的精确搜索。
6. 保留明文 `phone` 字段，展示用掩码赋值；缺失安全字段的实体补齐 `phoneMask/phoneMd5/phoneAes`。

## 用户场景与测试

### 用户故事 1 - 精确手机号查询使用 MD5（优先级：P1）

按手机号查记录的接口，应先现算 `phoneMd5` 再查 `*_md5` 字段；手机号为空走原非手机号条件，手机号非法返回空结果。

**独立测试**：用明文手机号请求各精确查询接口，确认 SQL 条件落到 `*_md5`，不再出现 `::getPhone` / `phone LIKE`。

### 用户故事 2 - 默认响应展示掩码（优先级：P1）

列表与详情默认返回掩码手机号，并保留 `phoneMask/phoneMd5/phoneAes`；`065` 的 app `/app/collect/order/pageQuery` 返回 `phoneAes` 例外保持不变。

**独立测试**：抓取各接口响应，确认 `phone` 不再是明文。

### 用户故事 3 - 保存链路生成安全字段（优先级：P1）

新增/修改记录时，保存前生成 `phoneMask/phoneMd5/phoneAes`；查重按 `phoneMd5` 唯一性判定。

**独立测试**：保存一条带手机号记录，确认三个安全字段非空且 `phoneMd5` 与明文归一化一致。

### 用户故事 4 - 缺失安全字段的实体补齐（优先级：P1）

`lms-common AppletUserDo`、`drh MallOrder`、`drh-kk-cms ImportAddressRecordDetail` 补齐安全字段，使其查询/返回口径可与已改造模块对齐。

**独立测试**：实体字段与对应表列一一映射，编译通过。

## 修复清单（kkhc）

| 编号 | 接口/类 | 证据 | 整改 |
|---|---|---|---|
| K1 | `OrderPageProcessorDataFacade`（app、lms） | `app|lms .../facade/order/OrderPageProcessorDataFacade.java:309` `record.setPhone(liveUser.getPhone())` | 对齐 ai：`setPhone(DataSecurityInvoke.phoneMaskForDisplay(liveUser.getPhoneMask(), liveUser.getPhoneAes()))` |
| K2 | `OrderGoodReissueDetailServiceImpl`（lms、**ai**） | `lms|ai .../reissue/impl/OrderGoodReissueDetailServiceImpl.java:169` `.eq(...::getPhone, ...)` | 现算 `phoneMd5` 查 `getPhoneMd5`；手机号非法返回空页 |
| K3 | `AppletUserController.getOneByCondition`/`listByEntity`（app）+ `LeadsController.select`（kkhc-bizcenter） | `app .../controller/leads/AppletUserController.java:73` `.setEntity(appletUserDo)`；`kkhc-bizcenter .../controller/leads/LeadsController.java` 设置 `AppletUserDo.phone` 后 Feign | 入参有 `phone` 时现算 `phoneMd5` 显式查询；返回 `phone` 掩码 |
| K4 | `WxComplaintOrderServiceImpl`（lms） | `lms .../order/wechat/impl/WxComplaintOrderServiceImpl.java:52` `getWxComplaintOrderCount` `::getPhone` | 保存生成安全字段；统计按 `phoneMd5` |
| K5 | `LeadsNoqwSendMsgTaskDetailServiceImpl`（lms、**ai**） | `lms|ai .../works/impl/LeadsNoqwSendMsgTaskDetailServiceImpl.java:121` `::getPhone` | 查 `phoneMd5`；列表/导出返回掩码 |
| K6 | `UserServiceRecordServiceImpl.getRecords`（lms） | `lms .../userrecord/impl/UserServiceRecordServiceImpl.java:99` `::getPhone` | 查 `phoneMd5`；创建/批量创建确认 converter 生成安全字段 |
| K7 | `InfluencerServiceImpl` add/edit（lms） | `lms .../ad/service/mcn/impl/InfluencerServiceImpl.java:90`(add)/`:163`(edit) `::getPhone` | 重复校验按 `phoneMd5`；保存生成安全字段 |
| K8 | `lms-common AppletUserDo` 缺安全字段 | `lms-common .../AppletUserDo.java:40-43` 仅 `phone`；`ai-common` 版含字段+`createAesInfo()` | 补齐 `phoneMask/phoneMd5/phoneAes` 及 `createAesInfo()`，与 ai-common 对齐 |
| K9 | `OrderBookReissueServiceImpl` 逻辑 bug（ai） | `ai .../reissue/impl/OrderBookReissueServiceImpl.java:145` `if (StringUtils.isEmpty(input.getPhone()))` 内才算 md5 且用裸 `DigestUtils.md5DigestAsHex` | 条件改为非空时计算，统一用 `DataSecurityInvoke.computePhoneMd5` |

## 修复清单（drh）

| 编号 | 接口/类 | 证据 | 整改 |
|---|---|---|---|
| D1 | `FrontWorkServiceImpl.queryList`（drh-kk-cms） | `.../service/impl/FrontWorkServiceImpl.java:106` `.like(...AppletUser::getPhone...)` | 模糊改精确：现算 `phoneMd5` 查 `getPhoneMd5` |
| D2 | `FrontMyClassBaseServiceImpl`（drh-kk-cms） | `.../service/workServe/front/impl/FrontMyClassBaseServiceImpl.java:171` `.like(...AppletUser::getPhone...)` | 模糊改精确：查 `getPhoneMd5` |
| D3 | `ImportAddressRecordDetailServiceImpl`（drh-kk-cms） | `.../service/impl/ImportAddressRecordDetailServiceImpl.java:32` `.eq(...ImportAddressRecordDetail::getPhone...)` | 实体补安全字段；现算 `phoneMd5` 查 `getPhoneMd5`，对齐 `063` |
| D4 | `MallOrderMapper.xml`（drh-kk-cms） | `.../mapper/MallOrderMapper.xml:41` `reciver_phone like`；`:68` select `mo.reciver_phone` | 实体 `MallOrder` 补 `reciverPhoneMask/Md5/Aes`；查询改 `reciver_phone_md5` 精确；select 改 `reciver_phone_mask`；`save` 生成安全字段 |
| D5 | `MessageTriggerLogServiceImpl`（drh-kk-cms） | `.../messaging/trigger/impl/MessageTriggerLogServiceImpl.java:402,412` `VoiceRobotTaskUser/SmsTriggerUser::getPhone` 集合查询 | 入参 phones 归一为 md5 集合，`in` 查 `phoneMd5`（两实体已含安全字段） |
| D6 | `VoiceRobotTaskUserServiceImpl`（drh-media-process） | `.../service/voiceRobot/impl/VoiceRobotTaskUserServiceImpl.java:80` `.in(...::getPhone, phones)` | 集合归一为 md5，`in` 查 `phoneMd5` |
| D7 | `VoiceRobotCallbackDetailsServiceImpl`（drh-media-process） | `.../service/voiceRobot/impl/VoiceRobotCallbackDetailsServiceImpl.java:140-141,229,238,285,294,298` 明文分组/集合 | 保存回调生成安全字段；分组/集合查询走 `phoneMd5` |
| D8 | `VoiceRobotServiceImpl`（drh-kk-cms） | `.../service/voiceRobot/impl/VoiceRobotServiceImpl.java:551,554,583,590` 明文 Map key/groupBy/in | 关联键归一为 `phoneMd5` |
| D9 | `UserTriggerSetServiceImpl`（drh-kk-cms） | `.../messaging/trigger/impl/UserTriggerSetServiceImpl.java:436,443,450,460,462,473,489` 明文 Set/contains | 集合比较归一为 `phoneMd5` |
| D10 | `OutboundTriggerTaskHandle`、`SmsTriggerBaiWuUserCallBackHandler`（drh-media-process） | `OutboundTriggerTaskHandle.java:224-225,273,301` 明文做 Redis key；`SmsTriggerBaiWuUserCallBackHandler.java:119-120,127` 明文集合比较 | 库内匹配/Redis key 用 `phoneMd5`；向外部外呼/短信发送时才用解密明文 |

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - 查询入参 `phone`：来自 HTTP body / query / Feign DTO；进入 Mapper/Wrapper 前现算 `phoneMd5`。
  - 返回字段：来自实体 `phone/phoneMask/phoneAes`；返回前覆盖 `phone` 为掩码。
  - 保存链路：来自用户输入/Excel/回调/第三方；`save/update` 前调用 `createAesInfo()` 或等价方法。
- 下游读取字段清单：Wrapper 读 `getPhoneMd5`；XML 读 `phone_md5`、`reciver_phone_md5`、`*_mask`；前端读 `phone`、`phoneMask`、`phoneMd5`、`phoneAes`。
- 空对象 / 占位对象风险：
  - `AppletUserController.getOneByCondition` 不得继续用 `setEntity` 传入带明文 `phone` 的实体作为查询模板。
  - `UserServiceRecord`、`LeadsNoqw...` 创建链路需确认 converter 是否只复制 `phone` 而漏生成安全字段。
- 调用顺序风险：不允许先按明文查询再返回阶段掩码；不允许保存后异步补齐作为唯一保障。
- 旧逻辑保持：不改接口路径、HTTP 方法、分页、权限、导出结构；外呼/ERP/短信向外部发送的明文使用保留。
- 模块边界：每个模块使用本地 `DataSecurityInvoke`，三套副本保留现状，注意 import 路径不要跨模块误引用。

## 边界情况

- 手机号为空：保留原非手机号条件，不构造 MD5 条件。
- 手机号非法：精确查询返回空结果，不忽略条件导致全量返回。
- 输入为 32 位 MD5：沿用既有 `computePhoneMd5` 直通口径，小写归一。
- 模糊搜索改精确后：仅完整手机号可命中，部分匹配不再返回（已由用户确认接受）。
- 历史记录安全字段为空：返回优先 `phoneMask`，缺失时可用 `phoneAes` 现算掩码；两者均空返回空。`*_md5` 为空的旧数据查不到，依赖 `juzi-service` 回填进度。
- 导出接口：列名可保持，手机号值按掩码或受控明文输出。

## 需求

### 功能需求

- **FR-001**：系统 MUST 将 K1–K9、D1–D10 各精确手机号查询改为 `phoneMd5` 查询。
- **FR-002**：系统 MUST 将默认响应 `phone` 改为掩码展示并保留安全字段；`065` 特例除外。
- **FR-003**：系统 MUST 在保存/修改链路生成 `phoneMask/phoneMd5/phoneAes`，查重按 `phoneMd5`。
- **FR-004**：系统 MUST 将 `frontWork`、`front/myClass`、`mall/list` 的模糊搜索改为 `phoneMd5` 精确搜索。
- **FR-005**：系统 MUST 修正 `OrderBookReissueServiceImpl` 的 `phoneMd5` 计算逻辑，统一用 `computePhoneMd5`。
- **FR-006**：系统 MUST 为 `lms-common AppletUserDo`、`drh MallOrder`、`drh-kk-cms ImportAddressRecordDetail` 补齐安全字段。
- **FR-007**：系统 MUST 将集合手机号查询归一为 MD5 集合并用 `in` 查 `*_md5`。
- **FR-008**：系统 MUST 在外呼/短信等下游用 `phoneMd5` 做库内匹配，仅外部请求使用解密明文。
- **FR-009**：系统 MUST NOT 删除或清空原始明文 `phone` 字段。
- **FR-010**：系统 MUST NOT 合并三套加解密工具，各模块继续调用本地 `DataSecurityInvoke`。
- **FR-011**：系统 MUST NOT 在本规格做历史数据回填。

## 成功标准

- **SC-001**：K1–K9、D1–D10 每项均能通过 `rg` 确认旧的 `::getPhone`/`phone LIKE`/`reciver_phone LIKE` 已消除或替换为 `phoneMd5`。
- **SC-002**：精确查询接口用明文请求时，SQL 条件落到 `*_md5`。
- **SC-003**：默认响应 `phone` 不返回明文；`065` 特例保持 `phoneAes`。
- **SC-004**：保存一条带手机号记录后，三个安全字段非空且 `phoneMd5` 与归一化明文一致。
- **SC-005**：缺失安全字段的三个实体补齐后相关模块编译通过。
- **SC-006**：kkhc app/lms/ai 与 drh-kk-cms、drh-media-process 相关模块编译/单测通过。

## 假设

- 目标表 `*_md5`（含索引）、`*_mask`、`*_aes` 列由 `032/051/063` 提供，进入查询切换前列已存在。
- 历史回填由 `juzi-service` 完成，上线节奏与回填对齐。
- `drh_mall_order` 字段拼写按现有代码为 `reciver_phone`。
- 模糊搜索降级为精确搜索已获产品/用户确认。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `067-phone-security-gap-remediation` 规格目录，基于 `066` 漏改清单和用户确认口径编写修复清单与任务。
- 验证方式：复用 `066` 审计证据，并经 kkhc/drh 代码静态确认每个 `file:line`。
- 自检结论：范围限定为 `066` 已确认漏改 + 用户六项决策；未合并工具、未回填、未删明文字段。

### D002 - 实现记录模板

- 实现内容：`逐项记录修复的接口、类和行为变化。`
- 测试命令：`记录 Maven/JUnit/静态搜索命令。`
- 测试结果：`记录通过、失败和环境阻塞。`
- 自检结论：`确认 phoneMd5 查询、掩码返回、保存生成安全字段、模糊改精确、逻辑 bug 已修。`

### D003 - 纠正记录模板

- 触发原因：`说明为什么需要纠正。`
- 修正内容：`说明旧口径和新口径。`
- 文档同步：`说明同步了哪些文件。`
- 验证结果：`说明测试或静态验证。`
