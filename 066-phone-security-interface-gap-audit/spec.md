# 功能规格：手机号安全接口补遗与漏改审计

**功能目录**：`066-phone-security-interface-gap-audit`  
**创建日期**：`2026-06-09`  
**状态**：Draft（文档审计完成；待后续代码修复）  
**输入**：在 `C:\workspace\ju-chat\specs` 创建 spec-kit 文档，检查手机号加密修改相关 DDL、已整理的影响接口和当前代码，补充没有列出来的接口，并指出漏改接口。范围包括 `C:\workspace\ju-chat\kkhc` 和 `C:\workspace\drh`。

## 背景

- 当前问题：`050-phone-security-interface-db-mapping` 已覆盖主干接口和 3 个补充接口，但 `051/063/065/060` 之后仍有部分 HTTP/Feign/回调入口未进入统一测试矩阵，且当前代码中存在多处仍按明文 `phone` 查询或返回的残留。
- 当前行为：已有文档分散记录 DDL、导入地址、AppCollectOrder 返回、LiveCampGroup 掩码修复；部分 `kkhc-idc`、`kkhc-bizcenter`、`drh-kk-cms`、`drh-media-process` 的接口未列入主接口清单。
- 目标行为：形成一份可交给开发和测试执行的补遗文档，明确 DDL 来源、已覆盖接口、补充接口、确认漏改接口、非 HTTP 风险和修复建议。
- 非目标：本规格不新增 DDL、不改业务代码、不覆盖 `050/051/060/063/065`，不对历史 `phone` 明文字段做清空或迁移。

## DDL 来源

本规格不新增 DDL，只引用并汇总已有 DDL 范围。

| 来源规格 | 作用 | 本规格使用方式 |
|---|---|---|
| `051-phone-security-ddl-summary` | 汇总 P1/P2/P3 手机号安全字段和索引 DDL | 作为接口补遗和漏改判断的目标表依据 |
| `063-lms-import-address-phone-security` | 补充 `drh_import_address_record_detail` 安全字段和索引 | 将导入地址明细接口纳入补遗和漏改清单 |
| `065-app-collect-order-phone-security-return` | 明确 `/app/collect/order/pageQuery` 返回口径 | 标记为已覆盖接口，不重复作为漏改 |
| `060-livecamp-group-phone-security-empty-analysis` | 明确 LiveCampGroup 相关掩码修复 | 标记为已覆盖接口，不重复作为漏改 |

本次确认漏改涉及的主要 DDL 目标表：`drh_live_user`、`drh_applet_user`、`order_book_reissue_detail`、`drh_real_address_record`、`drh_sph_supplier_info`、`drh_user_service_record`、`drh_leads_noqw_send_msg_task_detail`、`drh_wechat_complaint_order`、`drh_import_address_record_detail`、`drh_mall_order`、`drh_voice_robot_task_user`、`drh_voice_robot_callback_details`、`drh_sms_trigger_user`。

## 已覆盖接口引用

| 来源规格 | 已覆盖内容 | 本规格处理 |
|---|---|---|
| `050-phone-security-interface-db-mapping` | drh-pay、drh-endpoint、drh-kk-cms、drh-callback、drh-media-process 主接口矩阵；补充 `/orderUser/user/list`、`/order/hand/list`、`/ad/pic/user/list` | 不重复列为漏改，只作为基线 |
| `060-livecamp-group-phone-security-empty-analysis` | `live/base/v3`、LiveCampGroup 学员手机号展示 | 不重复列为漏改 |
| `063-lms-import-address-phone-security` | `kkhc-idc/lms /collect/order/import/address*` 和 `import/address/detail` | `kkhc-idc/lms` 侧视为已覆盖；`drh-kk-cms` 侧 Feign/本地实现单独列风险 |
| `065-app-collect-order-phone-security-return` | `kkhc-idc/app`、`kkhc-idc/lms` 的 `/app/collect/order/pageQuery` | 不重复列为漏改，保留特殊返回口径 |

## 补充接口清单

### kkhc 补充接口

| 模块 | 接口 | 影响表 | 当前结论 |
|---|---|---|---|
| `kkhc-idc app/lms` | `POST /order/getOrderPage` | `drh_live_user` | 补充接口，且 app/lms 有确认漏改 |
| `kkhc-idc app/lms` | `POST /realGoodsAddressRecord/getLatestRecordsByCollectOrderNo` | `drh_real_address_record` | 补充接口，返回对象包含 `phone/phoneMask/phoneMd5/phoneAes`，需纳入回归 |
| `kkhc-idc app/lms` | `/order/reissue/create|pageQuery|pageDetailQuery|view|del|delByErpOrderNos|getBookIdAndNameDropdown|erpCallback|updateReissueStatus|updateReissueDetailAddressInfo|updateReissueDetailErpStatus|getReissueDetail|getExportDataList` | `order_book_reissue_detail` | 补充完整接口列表，`pageDetailQuery` 有确认漏改 |
| `kkhc-idc app/lms` | `/wechat/saveComplaintOrder|getComplaintOrderList|getWxComplaintOrderCount|getWxComplaintOrderCountByTime` | `drh_wechat_complaint_order` | 补充接口，保存和按手机号统计有确认漏改 |
| `kkhc-idc app/lms` | `/leads-noqw-send-msg-task-detail/exportList|listAll|pageList|{id}|create|update` | `drh_leads_noqw_send_msg_task_detail` | 补充接口，列表和导出有确认漏改 |
| `kkhc-idc app/lms` | `/userServiceRecord/batchCreateUploadRecord|getRecords|createRecord|createRecordDetails|delRecordDetail|updateRecordByField|createOperation|getOperationPage|getLastOperationPage` | `drh_user_service_record` | 补充接口，`getRecords` 有确认漏改；创建链路需确认安全字段生成 |
| `kkhc-idc app/lms` | `/userProfile/getUserDataOverview|getSelectCourseStatusInfo|getUserProfileUserTimeLine|getUserProfileSummary|getLearningBehaviorAnalysis|getOrderStatistics|getOrderPage|getCommonOrderStatistics|getCommonOrderPage|getCommonOrderCampSelect|getCategorySelect|getCampSelect|getRiskWarning|saveUserLiveRemarks|getUserLiveRemarks` | `drh_live_user`、`drh_user_service_record`、订单相关表 | 补充接口，需回归 phone 展示和安全字段透传 |
| `kkhc-idc app/lms` | `liveWelfareReceive/getAllCampName|getAllGroupName|getLiveByCampGroupId|getLiveByCampId|queryPage|setReceiveStatus|setUseStatus` | `drh_live_welfare_receive` 关联学员手机号 | 补充接口，`048` 已记录 Mapper 安全字段补充，需纳入回归 |
| `kkhc-idc app/lms` | `POST /applet/user/listByEntity`、`POST /applet/user/get/one/by/condition` | `drh_applet_user` | 补充接口，实体 `phone` 入参会触发明文字段查询 |
| `kkhc-bizcenter/app` | `POST /leads/select` | `drh_applet_user` | 补充 Feign 入口，调用 `kkhc-idc/app /applet/user/get/one/by/condition` |
| `kkhc-idc lms` | `mcn/influencer/page|listBox|add|edit|del|controlCooperation|outsideAccountDetail|outsideAccountEdit|addAgentAccount|agentAccountDetail|queryDataIndex` | `drh_sph_supplier_info` | 补充接口，`add/edit` 有确认漏改 |
| `kkhc-idc ai` | `/book/getBookQuestionRecordByAppletUserId` | `drh_book_question_record`、`drh_external_book_question_record` | 补充接口，当前已按 `phoneMd5` 查询，纳入回归即可 |

### drh 补充接口

| 模块 | 接口 | 影响表 | 当前结论 |
|---|---|---|---|
| `drh-kk-cms` | `frontWork/queryList|queryListV2|getAllInfo|queryUserDetail` | `drh_applet_user` | 补充接口，手机号模糊搜索有确认漏改 |
| `drh-kk-cms` | `front/myClass/user/list|user/pageList|dataBoard/orderPage|dataBoard/exportOrder|live/summary/export` | `drh_applet_user`、订单相关表 | 补充接口，用户基础信息分页按手机号 LIKE 有确认漏改 |
| `drh-kk-cms` | `collect/order/import/address/detail` | `drh_import_address_record_detail` | 补充接口，本地 service 仍按明文 `phone` 查询；同路径 Feign 到 lms 已由 `063` 覆盖 |
| `drh-kk-cms` | `mall/list|save` | `drh_mall_order` | 补充接口，`list` 使用 `reciver_phone LIKE`，`save` 需确认安全字段生成 |
| `drh-kk-cms` | `messageTrigger/log/query` | `drh_voice_robot_task_user`、`drh_sms_trigger_user` | 补充接口，按手机号集合查询仍落明文字段 |
| `drh-media-process` | 外呼、短信回调和任务处理服务入口 | `drh_voice_robot_task_user`、`drh_voice_robot_callback_details`、`drh_sms_trigger_user` | 作为回调风险记录，不放入主 HTTP 矩阵必改接口 |

## 确认漏改接口

| 优先级 | 接口或入口 | 代码证据 | 问题 | 修复建议 |
|---|---|---|---|---|
| P1 | `kkhc-idc app/lms POST /order/getOrderPage` | app/lms `OrderPageProcessorDataFacade` 仍 `record.setPhone(liveUser.getPhone())`；ai 版本已用 `DataSecurityInvoke.phoneMaskForDisplay` | 订单分页仍可能返回 `drh_live_user.phone` 明文 | app/lms 对齐 ai，`phone` 使用掩码，必要时同步 `phoneMask/phoneMd5/phoneAes` |
| P1 | `kkhc-idc app/lms/ai POST /order/reissue/pageDetailQuery` | `OrderGoodReissueDetailServiceImpl` 仍 `OrderGoodReissueDetailDO::getPhone` | 补发明细分页按明文手机号查询 | 计算 `phoneMd5` 后查 `OrderGoodReissueDetailDO::getPhoneMd5`；非法手机号返回空页 |
| P1 | `kkhc-idc app/lms POST /applet/user/listByEntity|get/one/by/condition`，`kkhc-bizcenter/app POST /leads/select` | `AppletUserController.listByEntity`、`getOneByCondition` 均使用或触发 `new LambdaQueryWrapper<AppletUserDo>().setEntity(appletUserDo)`；`LeadsController.select` 设置 `AppletUserDo.phone` 后 Feign 调用 | `phone` 入参会落到 `drh_applet_user.phone` 明文查询；`lms-common AppletUserDo` 缺 `phoneMask/phoneMd5/phoneAes`，`ai-common` 已有 | 入参有 `phone` 时计算 `phoneMd5` 并显式查询；`lms-common AppletUserDo` 补齐安全字段；返回 `phone` 掩码 |
| P1 | `kkhc-idc app/lms /wechat/saveComplaintOrder|getWxComplaintOrderCount` | `WxComplaintOrderServiceImpl` 保存未生成安全字段，统计仍 `WechatComplaintOrderDO::getPhone` | 投诉订单保存和手机号统计未走安全字段 | 保存前生成 `phoneMask/phoneMd5/phoneAes`；统计按 `phoneMd5` |
| P1 | `kkhc-idc app/lms/ai /leads-noqw-send-msg-task-detail/exportList|listAll|pageList` | `LeadsNoqwSendMsgTaskDetailServiceImpl` 仍 `LeadsNoqwSendMsgTaskDetailDO::getPhone` | 无企微任务明细按明文手机号查询 | 计算 `phoneMd5` 并查 `phoneMd5`；导出和列表返回掩码 |
| P1 | `kkhc-idc app/lms/ai /userServiceRecord/getRecords` | `UserServiceRecordServiceImpl` 仍 `UserServiceRecordDO::getPhone` | 用户服务记录按明文手机号查询 | 计算 `phoneMd5` 并查 `phoneMd5`；创建和批量创建确认 converter 生成安全字段 |
| P1 | `kkhc-idc lms mcn/influencer/add|edit` | `InfluencerServiceImpl` 使用 `InfluencerDO::getPhone` 做重复校验 | 供应商手机号校验仍查明文 | `phoneMd5` 唯一性校验；保存时生成安全字段 |
| P1 | `drh-kk-cms frontWork/queryList|queryListV2|getAllInfo` | `FrontWorkServiceImpl` 仍 `AppletUser::getPhone LIKE` | 大前端工作台手机号模糊搜索无法使用已加密字段 | 若只支持完整手机号，改 `phoneMd5` 精确查询；若必须模糊搜索，需产品确认新增可搜索索引方案 |
| P1 | `drh-kk-cms front/myClass/user/list|user/pageList` | `FrontMyClassBaseServiceImpl` 仍 `AppletUser::getPhone LIKE` | 我的班级手机号模糊搜索无法使用已加密字段 | 同上，先确认是否取消模糊搜索 |
| P1 | `drh-kk-cms collect/order/import/address/detail` | `ImportAddressRecordDetailServiceImpl` 仍 `ImportAddressRecordDetail::getPhone` | 导入地址明细按明文手机号查询 | 对齐 `063`，计算 `phoneMd5` 后查 `phoneMd5` |
| P2 | `drh-kk-cms mall/list` | `MallOrderMapper.xml` 仍 `mo.reciver_phone like concat('%',#{input.reciverPhone},'%')` 且 select `mo.reciver_phone` | 商城订单收件手机号模糊查询和返回明文风险 | 先确认是否支持模糊；返回改用 `reciver_phone_mask`，保存补齐 `reciver_phone_*` |
| P1 | `drh-kk-cms messageTrigger/log/query` | `MessageTriggerLogServiceImpl` 仍 `VoiceRobotTaskUser::getPhone`、`SmsTriggerUser::getPhone` | 消息触达日志按手机号集合查询仍落明文字段 | 将输入 phones 归一为 md5 集合，查询对应 `phoneMd5` 字段；集合条件应使用 `in` |

## 非 HTTP 风险

| 模块 | 位置 | 风险 | 建议 |
|---|---|---|---|
| `drh-media-process` | `VoiceRobotTaskUserServiceImpl` | `VoiceRobotTaskUser::getPhone` 集合查询 | 对齐 `phoneMd5` 批量查询 |
| `drh-media-process` | `VoiceRobotCallbackDetailsServiceImpl` | `VoiceRobotCallbackDetails::getPhone` 分组和集合查询 | 保存回调时补齐安全字段，查询走 `phoneMd5` |
| `drh-media-process` | `OutboundTriggerTaskHandle`、`SmsTriggerBaiWuUserCallBackHandler` | 任务处理中继续以明文手机号做集合 key | 保留外呼所需明文只用于外部请求，库内匹配使用 `phoneMd5` |
| `drh-kk-cms` | `VoiceRobotServiceImpl`、`UserTriggerSetServiceImpl` | 回调明细和任务用户以明文手机号关联 | 统一归一为 `phoneMd5` 后关联 |

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `phone` 查询入参：来自 HTTP body、query param 或 Feign DTO；后续修复必须在进入 Mapper/Wrapper 前现算 `phoneMd5`。
  - `phone` 返回字段：来自实体 `phone`、`phoneMask` 或 `phoneAes`；后续修复必须在返回前明确覆盖为掩码，`065` 特例除外。
  - 保存链路手机号：来自用户输入、Excel、回调或第三方请求；后续修复必须在 `save/update` 前调用 `createAesInfo()` 或等价工具。
- 下游读取字段清单：
  - MyBatis-Plus Wrapper 读取 `getPhone`、`getPhoneMd5`。
  - XML Mapper 读取 `phone`、`reciver_phone`、`phone_md5`、`phone_mask`。
  - 前端读取 `phone`、`phoneMask`、`phoneMd5`、`phoneAes`。
- 空对象 / 占位对象风险：
  - `AppletUserController.getOneByCondition` 使用 setEntity，不能在后续修复中继续传入带明文 `phone` 的实体作为查询模板。
  - `UserServiceRecord`、`LeadsNoqw...` 创建链路需要确认 converter 是否只复制 `phone` 而未生成安全字段。
- 调用顺序风险：
  - 不允许先按明文字段查询，再在返回阶段掩码。
  - 不允许保存后再异步补齐安全字段作为唯一保障。
- 旧逻辑保持：
  - 不改变接口路径、HTTP 方法、分页参数、权限过滤、导出文件结构、ERP/外呼外部请求的必要明文使用。
  - 不新增 DDL，除非后续产品确认模糊搜索需要可搜索索引方案。
- 需要用户确认的设计选择：
  - drh `frontWork`、`front/myClass`、`mall/list` 的手机号模糊搜索是否降级为完整手机号精确搜索。
  - 外呼、ERP、短信等需要明文的下游是否允许在内存中通过 `phoneAes` 解密后使用。

## 边界情况

- 手机号为空：保持原非手机号条件查询逻辑，不额外构造 MD5 条件。
- 手机号非法：精确查询接口建议返回空结果，不忽略手机号条件导致全量返回。
- 输入为 32 位 MD5：沿用既有 `computePhoneMd5` 直通口径，小写归一。
- 模糊手机号：不自动转换为 MD5，必须由产品确认搜索能力。
- 历史记录安全字段为空：返回优先 `phoneMask`，缺失时可用 `phoneAes` 现算掩码；两者均空时返回空。
- 导出接口：导出列名可保持原名称，但手机号值必须按掩码或受控明文口径输出。

## 需求

- **FR-001**：系统 MUST 在本规格中列出 DDL 来源、已覆盖接口、补充接口、确认漏改接口、非 HTTP 风险五个小节。
- **FR-002**：系统 MUST 将 `kkhc` 和 `drh` 中未列入主清单的 HTTP/Feign/回调接口补充到接口矩阵。
- **FR-003**：系统 MUST 为每个确认漏改点记录接口、代码证据、问题和修复建议。
- **FR-004**：系统 MUST NOT 在本规格内修改业务代码、DDL 或已有规格目录。
- **FR-005**：后续修复 MUST 将精确手机号查询统一改为 `phoneMd5` 查询。
- **FR-006**：后续修复 MUST 将默认响应 `phone` 改为掩码展示，并保留安全字段；`065` 已确认特例除外。
- **FR-007**：后续修复 MUST 对模糊手机号搜索单独记录产品确认，不得直接用 MD5 等价替换。

## 成功标准

- **SC-001**：`spec.md` 包含 DDL 来源、已覆盖接口、补充接口、确认漏改接口、非 HTTP 风险五个小节。
- **SC-002**：每个 P1 漏改项均能通过 `rg` 定位到代码证据。
- **SC-003**：每个补充接口均能反查到 Controller、Feign 或回调入口。
- **SC-004**：`tasks.md` 包含精确查询、响应展示、模糊搜索和回归测试的后续修复任务。
- **SC-005**：本次交付只新增 `066-phone-security-interface-gap-audit` 目录，不修改业务代码。

## 假设

- 本次只创建文档，不进入业务代码修复。
- 主接口矩阵只覆盖 HTTP、Feign、回调入口；定时任务、批处理、纯 service 放入风险小节。
- 新目录使用 `066-phone-security-interface-gap-audit`，不覆盖 `050/051/060/063/065`。
- `drh_mall_order` 使用字段名 `reciver_phone`，按当前代码拼写记录。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已汇总 `051/063` DDL 来源和 `050/060/063/065` 已覆盖接口。
- 已补充 kkhc、drh 未列接口，并记录确认漏改接口和非 HTTP 风险。
- 本阶段未修改业务代码、DDL 或历史规格。

### D002 - 后续修复记录模板

- 实现内容：`按确认漏改清单逐项修复，并同步更新本规格状态。`
- 测试命令：`记录 kkhc app/lms/ai、drh-kk-cms、drh-media-process 的编译、单测或静态检查命令。`
- 测试结果：`记录通过项、失败项和环境阻塞。`
- 自检结论：`确认精确查询使用 phoneMd5、响应不返回明文、模糊搜索口径已确认。`

### D003 - 纠正记录模板

- 触发原因：`用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题`
- 修正内容：`说明旧口径和新口径`
- 文档同步：`说明同步了哪些文件`
- 验证结果：`说明测试或静态验证结果`
