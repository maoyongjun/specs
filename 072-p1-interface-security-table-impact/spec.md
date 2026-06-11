# 功能规格：P1 接口安全整改清单影响表整理

**功能目录**：`072-p1-interface-security-table-impact`  
**创建日期**：`2026-06-10`  
**状态**：Draft（文档整理完成；未进入代码整改）  
**输入**：`C:\Users\EDY\OneDrive\Desktop\P1级接口安全整改清单.csv`，整理其中 13 条非空接口整改项，输出接口到影响数据库表的矩阵。历史依据参考 `050-phone-security-interface-db-mapping`、`051-phone-security-ddl-summary`、`066-phone-security-interface-gap-audit`。

## 背景与输入来源

- 当前问题：CSV 中列出一批手机号安全整改接口，但接口、影响表、字段方向和当前代码状态混在备注中，缺少一份可供开发和测试统一执行的接口影响表矩阵。
- 当前行为：部分接口仍按明文 `phone` 查询或返回；部分 `drh-kk-cms` 项当前代码已改为 `phoneMd5` 或 `phone_mask` 口径，不能继续按 CSV 原备注简单标记为未整改。
- 目标行为：按接口整理影响表、手机号字段方向、CSV 待修改点、当前代码证据、当前状态和验证要点。
- 非目标：本规格不修改业务代码、不新增 DDL、不执行历史回填、不覆盖 `066-phone-security-interface-gap-audit`。
- CSV 核对结果：通过 `Import-Csv` 统计，非空整改记录共 13 条。

## CSV 接口整改清单概览

| 分类 | 数量 | 说明 |
|---|---:|---|
| P1 HTTP / Feign 接口 | 11 | 订单、补发、线索、投诉、任务明细、服务记录、达人、CMS、导入地址、消息触达 |
| P2 接口或链路 | 2 | `mall/list|save`、`drh-media-process` 外呼 / 短信回调任务链路 |
| 当前静态状态为待改 | 8 | 当前仍能定位到明文 `phone` 查询、实体条件查询或响应明文赋值风险 |
| 当前静态状态为已部分整改 / 需复核 | 4 | 查询条件已出现 `phoneMd5` 或返回已出现 mask，但展示、保存或派生读取仍需复核 |
| 非 HTTP 风险 | 1 | 外呼、短信回调和任务处理链路，不按单一 HTTP 接口验收 |

## 接口 × 影响表矩阵

| 优先级 | 模块 | 接口/入口 | 影响表 | 手机号字段/方向 | CSV 待修改点 | 当前代码证据 | 当前状态 | 验证要点 |
|---|---|---|---|---|---|---|---|---|
| P1 | `kkhc-idc app/lms/ai` | `POST /order/getOrderPage` | `drh_live_user` | 读 `phone/phone_mask`，写回订单分页响应 | 订单分页不应把学员明文手机号写回响应，应返回 `phoneMask` 或统一脱敏结果 | `OrderPageProcessorDataFacade` 在 app/lms/ai 均可搜到 `record.setPhone(liveUser.getPhone())` | 待改 / 需复核 | 用含真实手机号学员数据请求分页，确认响应 `phone` 不为明文；同时确认 `ai` 与 app/lms 版本口径一致 |
| P1 | `kkhc-idc app/lms/ai` | `POST /order/reissue/pageDetailQuery` | `order_book_reissue_detail` | 查询 `phone -> phone_md5` | 详情查询仍按明文手机号查询，应计算 `phoneMd5` 后查询 `phone_md5` | `OrderGoodReissueDetailServiceImpl`、`OrderBookReissueServiceImpl` 仍有 `OrderGoodReissueDetailDO::getPhone` 查询 | 待改 | 明文手机号入参应命中 `phone_md5` 条件；非法手机号不能忽略条件导致扩大结果 |
| P1 | `kkhc-idc app/lms`、`kkhc-bizcenter app` | `POST /applet/user/listByEntity`、`POST /applet/user/get/one/by/condition`、`POST /leads/select` | `drh_applet_user` | 实体条件 `phone -> phone_md5`；返回展示用 `phone_mask` | 通过实体条件传入 `phone` 会按 `drh_applet_user.phone` 明文查询；需补 `phoneMask/phoneMd5/phoneAes` 字段并改为 `phoneMd5` 查询 | `AppletUserController` 使用 `setEntity(appletUserDo)`；`AppletUserServiceImpl` 使用实体条件；`lms-common AppletUserDo` 未搜到安全字段 | 待改 | Feign 入参带手机号时，服务端应先计算 `phoneMd5` 并显式按 `phoneMd5` 查询；返回手机号按掩码口径 |
| P1 | `kkhc-idc app/lms` | `/wechat/saveComplaintOrder`、`/wechat/getWxComplaintOrderCount` | `drh_wechat_complaint_order` | 保存写 `phone_mask/phone_md5/phone_aes`；统计查 `phone_md5` | 投诉单保存和统计仍使用明文手机号 | `WxComplaintOrderServiceImpl` 仍有 `WechatComplaintOrderDO::getPhone` 查询 | 待改 | 保存后安全字段完整；手机号统计 SQL 条件落到 `phone_md5` |
| P1 | `kkhc-idc app/lms/ai` | `/leads-noqw-send-msg-task-detail/exportList`、`/listAll`、`/pageList` | `drh_leads_noqw_send_msg_task_detail` | 查询 `phone -> phone_md5`；列表 / 导出展示 `phone_mask` | 任务明细查询仍按明文手机号过滤 | `LeadsNoqwSendMsgTaskDetailServiceImpl` 仍有 `LeadsNoqwSendMsgTaskDetailDO::getPhone` 查询 | 待改 | 列表和导出都按 `phone_md5` 过滤；导出文件不含明文手机号 |
| P1 | `kkhc-idc app/lms/ai` | `/userServiceRecord/getRecords` | `drh_user_service_record` | 查询 `phone -> phone_md5`；创建链路写 `phone_*` 待复核 | 服务记录查询仍按明文手机号过滤；创建和批量创建需确认 converter 是否生成安全字段 | `UserServiceRecordServiceImpl` 仍有 `UserServiceRecordDO::getPhone` 查询 | 待改 | 查询按 `phone_md5`；新增 / 批量新增后 `phone_mask/phone_md5/phone_aes` 均有值 |
| P1 | `kkhc-idc lms` | `mcn/influencer/add`、`mcn/influencer/edit` | `drh_sph_supplier_info` | 重复校验 `phone -> phone_md5`；保存写 `phone_*` | 达人手机号重复校验仍使用明文手机号 | `InfluencerServiceImpl` 仍有 `InfluencerDO::getPhone` 校验 | 待改 | 新增和编辑时按 `phone_md5` 做唯一性校验；保存后安全字段完整 |
| P1 | `drh-kk-cms` | `frontWork/queryList`、`frontWork/queryListV2`、`frontWork/getAllInfo` | `drh_applet_user` | 查询条件已见 `phone_md5`；展示 / 派生读取 `phone` 需复核 | 原 CSV 记录为 `AppletUser.phone LIKE` 模糊查询风险 | 当前 `FrontWorkServiceImpl` 查询条件已为 `AppletUser::getPhoneMd5`；仍有多处 `queryListDto.setPhone(appletUser.getPhone())`、`getPhone()` 派生读取 | 已部分整改 / 需复核 | 完整手机号搜索是否命中；响应和派生数据中 `phone` 是否仍可能为明文；确认是否保留或取消模糊搜索 |
| P1 | `drh-kk-cms` | `front/myClass/user/list`、`front/myClass/user/pageList`、`live/summary/export` | `drh_applet_user` | 查询条件已见 `phone_md5`；输出读取需复核 | 原 CSV 记录为 `AppletUser.phone LIKE` 模糊查询风险 | 当前 `FrontMyClassBaseServiceImpl` 使用 `AppletUser::getPhoneMd5`；select 仍包含 `AppletUser::getPhone` | 已部分整改 / 需复核 | 搜索按完整手机号精确匹配；页面列表和导出列不得输出明文手机号 |
| P1 | `drh-kk-cms` | `collect/order/import/address/detail` | `drh_import_address_record_detail` | 查询 `phone -> phone_md5`；展示 `phone_mask` | 本地导入地址明细查询仍按明文手机号过滤 | `ImportAddressRecordDetailServiceImpl` 仍有 `ImportAddressRecordDetail::getPhone` 查询 | 待改 | 对齐 `063-lms-import-address-phone-security`，本地 service 按 `phone_md5` 查询并返回掩码 |
| P2 | `drh-kk-cms` | `mall/list`、`mall/save` | `drh_mall_order` | `reciver_phone -> reciver_phone_md5/reciver_phone_mask/reciver_phone_aes` | 商城订单查询存在收件手机号 LIKE，列表返回原始收件手机号；保存安全字段需确认 | 当前 `MallOrderMapper.xml` 已按 `reciver_phone_md5` 查询并 select `reciver_phone_mask reciverPhone`；保存链路未在本次矩阵中确认 | 已部分整改 / 需复核 | 列表按完整手机号命中且返回掩码；`mall/save` 写入 `reciver_phone_*`；确认是否不再支持模糊搜索 |
| P1 | `drh-kk-cms` | `messageTrigger/log/query` | `drh_voice_robot_task_user`、`drh_sms_trigger_user` | 手机号集合 `phones -> phone_md5 IN` | 消息触发日志查询应将输入手机号集合归一化为 `phoneMd5` 后查询 | 当前 `MessageTriggerLogServiceImpl` 已有 `VoiceRobotTaskUser::getPhoneMd5`、`SmsTriggerUser::getPhoneMd5` 查询 | 已部分整改 / 需复核 | 多手机号集合查询应按 `phone_md5 IN`；空集合不应放大查询；返回列表不含明文手机号 |
| P2 | `drh-media-process` | 外呼 / 短信回调任务链路 | `drh_voice_robot_task_user`、`drh_voice_robot_callback_details`、`drh_sms_trigger_user`；关联回写 `drh_sms_trigger_user_callback` | 任务匹配优先 `phone_md5`；外呼 / 短信请求可在受控内存中使用明文 | 非单一 HTTP 接口，但回调和任务处理仍存在明文手机号匹配风险 | 当前 `VoiceRobotTaskUserServiceImpl` 已按 `phoneMd5` 删除；`VoiceRobotCallbackDetailsServiceImpl` 仍有 `VoiceRobotCallbackDetails::getPhone` 分组和 `in` 查询；任务 handler 仍有明文 phone 集合处理 | 非 HTTP 风险 | 明确外部供应商请求使用明文的边界；库内匹配、去重、回调关联优先使用 `phone_md5` |

## 数据库表聚合视图

| 数据库表 | 涉及接口/入口 | 字段口径 | 当前状态 |
|---|---|---|---|
| `drh_live_user` | `/order/getOrderPage` | `phone` 响应展示应改为 `phone_mask` 或统一脱敏 | 待改 / 需复核 |
| `order_book_reissue_detail` | `/order/reissue/pageDetailQuery` | `phone` 查询改为 `phone_md5` | 待改 |
| `drh_applet_user` | `/applet/user/*`、`/leads/select`、`frontWork/*`、`front/myClass/*` | `phone` 查询改为 `phone_md5`；展示用 `phone_mask` | 待改 + 已部分整改并存 |
| `drh_wechat_complaint_order` | `/wechat/saveComplaintOrder`、`/wechat/getWxComplaintOrderCount` | 保存 `phone_*`，统计查 `phone_md5` | 待改 |
| `drh_leads_noqw_send_msg_task_detail` | `/leads-noqw-send-msg-task-detail/*` | 查询 `phone_md5`，导出展示 `phone_mask` | 待改 |
| `drh_user_service_record` | `/userServiceRecord/getRecords` | 查询 `phone_md5`，创建写 `phone_*` | 待改 |
| `drh_sph_supplier_info` | `mcn/influencer/add|edit` | 重复校验 `phone_md5`，保存写 `phone_*` | 待改 |
| `drh_import_address_record_detail` | `collect/order/import/address/detail` | 查询 `phone_md5`，展示 `phone_mask` | 待改 |
| `drh_mall_order` | `mall/list|save` | `reciver_phone_md5` 查询，`reciver_phone_mask` 展示，保存写 `reciver_phone_*` | 已部分整改 / 需复核 |
| `drh_voice_robot_task_user` | `messageTrigger/log/query`、外呼任务 | `phone_md5` 查询 / 匹配，外呼请求可受控使用明文 | 已部分整改 / 非 HTTP 风险 |
| `drh_voice_robot_callback_details` | 外呼回调明细链路 | 回调匹配应优先 `phone_md5` | 非 HTTP 风险 |
| `drh_sms_trigger_user` | `messageTrigger/log/query`、短信回调任务 | `phone_md5` 查询 / 匹配 | 已部分整改 / 非 HTTP 风险 |
| `drh_sms_trigger_user_callback` | 短信回调关联回写 | 保存回调时补齐 `phone_md5` | 关联风险 |

## 当前代码状态口径

| 状态 | 判定口径 | 本规格涉及项 |
|---|---|---|
| 待改 | 当前静态搜索仍能定位到 `::getPhone`、`setEntity` 带手机号、或明文 `phone` 响应赋值风险 | 订单分页、补发详情、AppletUser 实体条件、投诉单、无企微任务明细、服务记录、达人、导入地址明细 |
| 已部分整改 | 查询条件或返回字段已出现 `phoneMd5` / `phone_mask`，但保存、展示或派生读取尚未完整验证 | `frontWork`、`front/myClass`、`mall`、`messageTrigger/log` |
| 需复核 | 静态证据无法单独判断最终接口响应、导出文件或保存链路是否完全安全 | 所有已部分整改项，以及 `/order/getOrderPage` 的 app/lms/ai 版本差异 |
| 非 HTTP 风险 | 不是单一 HTTP 接口，但任务、回调、批处理仍可能用明文手机号做库内匹配 | `drh-media-process` 外呼 / 短信回调任务链路 |

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - 查询入参 `phone` 来自 HTTP body、query param 或 Feign DTO，必须在构造 Wrapper / Mapper 参数前现算 `phoneMd5`。
  - 响应字段 `phone` 来自实体 `phone`、`phoneMask` 或 `phoneAes`，默认必须以掩码展示，不允许先返回明文再由前端处理。
  - 保存链路手机号来自用户输入、Excel、回调或第三方请求，必须在 insert/update 前生成 `phone_mask/phone_md5/phone_aes`。
- 下游读取字段清单：
  - MyBatis-Plus 查询读取 `getPhone`、`getPhoneMd5`。
  - XML Mapper 读取 `reciver_phone_md5`、`reciver_phone_mask`。
  - 接口 DTO / 导出读取 `phone`、`phoneMask`、`phoneMd5`、`phoneAes`。
- 空对象 / 占位对象风险：
  - `AppletUserController` 和 `AppletUserServiceImpl` 使用 `setEntity(appletUserDo)`，后续修复不能继续让带明文 `phone` 的实体作为查询模板。
  - 创建链路不能只 set `phone` 后直接保存，必须同步安全字段。
- 调用顺序风险：
  - 不允许先按明文字段查询，再在返回阶段做掩码。
  - 不允许保存后再依赖异步补齐安全字段作为唯一保障。
- 旧逻辑保持：
  - 不改变接口路径、HTTP 方法、分页参数、权限过滤、导出文件结构、外呼 / 短信供应商请求必要明文使用。
  - 不新增 DDL，除非后续另行确认模糊搜索或可搜索索引方案。
- 需要用户确认的设计选择：
  - `frontWork`、`front/myClass`、`mall/list` 是否彻底取消手机号模糊搜索，仅保留完整手机号精确搜索。
  - 外呼、短信等下游需要明文时，是否统一限定为内存中临时解密 / 使用，不再用于库内匹配。

## 边界情况

- 手机号为空：保持原非手机号条件，不额外构造 `phoneMd5` 条件。
- 手机号非法：建议返回空结果，不能忽略手机号条件导致结果扩大。
- 输入已是 32 位 MD5：沿用既有 `computePhoneMd5` 兼容口径，小写归一。
- 模糊手机号：MD5 不能等价支持模糊搜索，必须按产品确认结果处理。
- 历史数据安全字段为空：展示优先 `phoneMask`，缺失时可按既有统一工具从 `phoneAes` 生成掩码；两者均空时返回空或按旧兼容口径记录风险。
- 导出接口：导出列名可保持原名称，但手机号值必须为掩码或明确受控口径。
- 非 HTTP 任务：外部请求需要明文手机号时，库内查询、去重和关联仍优先使用 `phoneMd5`。

## 需求

- **FR-001**：系统 MUST 新建 `072-p1-interface-security-table-impact` 规格目录，并包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **FR-002**：`spec.md` MUST 记录 CSV 输入路径和非空记录数 13。
- **FR-003**：`spec.md` MUST 使用固定列整理接口矩阵：优先级、模块、接口/入口、影响表、手机号字段/方向、CSV 待修改点、当前代码证据、当前状态、验证要点。
- **FR-004**：`spec.md` MUST 按数据库表聚合受影响接口，便于测试按表回归。
- **FR-005**：`spec.md` MUST 区分 CSV 原问题和当前代码状态，不得把已出现 `phoneMd5` / `phone_mask` 的项继续简单标为未整改。
- **FR-006**：本规格 MUST NOT 修改业务代码、SQL、DDL、回填脚本或既有规格目录。

## 成功标准

- **SC-001**：13 条 CSV 非空整改项均能在接口矩阵或非 HTTP 风险中找到。
- **SC-002**：每个矩阵项均有影响表、字段方向、当前状态和验证要点。
- **SC-003**：当前状态与静态搜索结果一致，已部分整改项单独标记为需复核。
- **SC-004**：`tasks.md` 记录 CSV 统计、静态搜索、历史规格对比和占位符检查结果。
- **SC-005**：本次交付只新增 `072-p1-interface-security-table-impact` 目录，不修改业务代码。

## 假设

- “影响表”默认指手机号安全整改直接涉及的业务表；辅助表只在备注或关联回写表中记录。
- 当前代码状态优先于 CSV 备注；若后续代码继续变化，需要追加 D002 纠正记录。
- `drh_mall_order` 字段名沿用当前代码拼写 `reciver_phone_*`。
- 本次不处理代码修复、DDL、回填或接口测试执行。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已用 `Import-Csv` 复核 CSV 非空记录数为 13。
- 已用 `rg` 静态核对关键类、Mapper、实体注解和表名。
- 已对比 `050/051/066`，确认表名、字段名和已覆盖接口不冲突。
- 已将当前代码状态分为 `待改`、`已部分整改 / 需复核`、`非 HTTP 风险`。
- 本阶段未修改业务代码、DDL、SQL 或历史规格目录。

### D002 - 后续纠正记录模板

- 触发原因：`用户补充/测试失败/代码审查发现/当前代码状态变化`
- 修正内容：`说明旧口径和新口径`
- 文档同步：`说明同步了哪些文件`
- 验证结果：`说明静态搜索、接口测试或编译结果`
