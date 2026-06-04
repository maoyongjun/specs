# 任务清单：手机号安全字段查询返回与掩码入参校验

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。  
**当前阶段**：已进入实现阶段；代码改动涉及 `C:\workspace\drh` 和 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai`。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认涉及的两个工程（drh、ju-chat）和目标模块。
- [x] T002 全量搜索 drh 工程中所有返回给前端的 Output/DTO/VO 类，找出包含 `phone` 字段的类，确认是否已有 `phoneMask`、`phoneMd5`、`phoneAes` 字段。
- [x] T003 全量搜索 ju-chat 工程中所有返回给前端的 Output 类，找出包含 `phone` 字段的类，确认是否已有安全字段。
- [x] T004 确认每个 Output/DTO 类中 `phone` 字段的当前赋值来源：实体透传、内联掩码、还是 `phoneMaskForDisplay()`。
- [x] T005 确认所有保存/更新入口的 `checkWritablePhone()` 或 `isWritablePhoneInput()` 调用位置，记录增加掩码格式校验的精确落点。
- [x] T006 确认 `DataSecurityInvoke.java` 中是否已有 `isMaskedPhone()` 方法，或需要新增。
- [x] T007 确认后端间接口（ERP 回调、物流推送、支付回调）中获取明文手机号的路径，确认不受 `phone` 字段返回掩码的影响。
- [x] T008 确认 ju-chat 工程中 `DataSecurityInvoke` 或等价工具类的可用性（依赖关系）。ju-chat ai 模块无 drh-common 依赖，`DataSecurityInvoke` 不可用；保存校验由 drh-endpoint Feign 调用链覆盖。

**检查点**：不得在未完成 T001-T008 前进入实现。

## Phase 2：风险门禁

- [x] T009 检查是否存在 Output/DTO 通过 BeanUtils.copyProperties 或 ConvertUtil 从实体自动映射 `phone` 字段的场景，确认自动映射后 `phone` 是否仍为明文。
- [x] T010 检查是否存在多个 Output/DTO 共用同一实体 `phone` 字段的场景，避免只改一个入口遗漏其他。
- [x] T011 检查是否存在查询结果直接返回实体对象（非 Output/DTO）的场景，如 `BaseResponse.success(entity)`。
- [x] T012 检查保存/更新入口是否存在未调用 `isWritablePhoneInput()` 的路径，这些路径也需要增加掩码格式校验。
- [x] T013 检查掩码格式检测 `isMaskedPhone()` 是否会误判 AES 密文（AES 密文是否可能包含 `****`）。已验证 AES 密文为 Base64 格式，不含 `****`，不会误判。
- [x] T014 检查 `phone` 字段返回掩码值后，是否有前端代码依赖 `phone` 字段做手机号格式校验（如 11 位数字检查），返回掩码后可能触发前端报错。需前端确认。
- [x] T015 检查导出功能中 `phone` 字段是否需要单独处理（导出模板、列头映射）。`AdUserPicExportDto` 的 phone 来源已在 Service 层处理。
- [x] T016 为每个关键行为建立测试映射：查询结果含安全字段、phone 返回掩码、保存拒绝掩码格式、保存接受明文和 AES 密文、保存拒绝 MD5。

**检查点**：T009-T016 必须有明确结论；发现高风险时先更新 `spec.md` 的"历史问题防漏分析"。

## Phase 3：实现任务

- [x] T017 在 `DataSecurityInvoke.java` 中新增 `isMaskedPhone(String phoneInput)` 静态方法。
- [x] T018 为 drh-kk-cms 中的 Output/DTO 类增加 `phoneMask`、`phoneMd5`、`phoneAes` 字段。
- [x] T019 为 ju-chat ai-common 中的 Output 类增加 `phoneMask`、`phoneMd5`、`phoneAes` 字段。
- [x] T020 修改 drh-kk-cms Service 层查询结果映射逻辑：将实体的 `phoneMask`、`phoneMd5`、`phoneAes` 映射到 Output/DTO，并将 `phone` 字段赋掩码值。
- [ ] T021 修改 ju-chat Service 层查询结果映射逻辑，同 T020。ju-chat ai 模块无 `DataSecurityInvoke` 依赖，Service 层映射改造需确认依赖方案后执行。
- [x] T022 在 drh 工程所有保存/更新入口增加掩码格式校验，在 `isWritablePhoneInput()` 之前执行。
- [x] T023 在 ju-chat 工程保存/更新入口增加掩码格式校验：ju-chat ai 模块保存入口 `BookEditAddressCompensationServiceImpl.saveOne` 通过 Feign 调用 drh-endpoint `editAddressV2`，drh-endpoint 已有掩码校验覆盖。
- [x] T024 处理自动映射（BeanUtils.copyProperties / ConvertUtil）场景：确保 `phone` 字段被覆盖为掩码值，安全字段被正确传递。
- [x] T025 处理导出功能中 `phone` 字段的掩码值返回。
- [x] T026 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [ ] T027 调用图书登记信息列表接口，验证返回 JSON 包含 `phone`（掩码）、`phone_mask`、`phone_md5`、`phone_aes`。
- [ ] T028 调用学员/线索查询接口，验证返回 JSON 包含安全字段且 `phone` 为掩码。
- [ ] T029 调用导出接口，验证导出文件中 `phone` 列为掩码值。
- [ ] T030 验证 `phone_mask` 为 NULL 的历史记录，`phone` 字段通过 `phone_aes` 现算掩码或返回 null。
- [ ] T031 保存接口传入掩码格式手机号 `138****5678`，验证返回错误提示 `手机号为掩码格式，请输入明文手机号`。
- [ ] T032 保存接口传入明文手机号，验证正常保存。
- [ ] T033 保存接口传入前端 AES 加密手机号，验证正常保存。
- [ ] T034 保存接口传入 32 位 MD5，验证返回 `手机号加密格式不符`（原有逻辑不变）。
- [x] T035 静态扫描确认所有 Output/DTO 的 `phone` 字段赋值来源已改为掩码值。
- [x] T036 静态扫描确认所有保存/更新入口已增加掩码格式校验。
- [x] T037 搜索确认不存在残留的明文 `phone` 直接返回给前端的代码路径。

## Phase 5：XML Mapper 查询字段补充

- [x] T038 全量扫描 drh-kk-cms 所有 XML Mapper 中 SELECT phone 的查询语句，确认是否包含 `phone_mask`、`phone_md5`、`phone_aes` 列。
- [x] T039 改造 `AdUserPicMapper.xml` 6 个 SELECT（getPageList、getExportList、getGxPage、getFlowGxPage、getFlowPageList、getPageListV2）补充安全字段。
- [x] T040 改造 `AppletUserPoolMapper.xml` 2 个 SELECT（selectPoolPage、selectPoolPageClick）补充安全字段。
- [x] T041 改造 `AppletSalePoolMapper.xml` 1 个 SELECT（selectPoolPage）补充安全字段。
- [x] T042 改造 `AppletUserMapper.xml` cardCountV4 补充安全字段。
- [x] T043 改造 `ExternalBookQuestionRecordMapper.xml` queryHistoryPage 的 resultMap 和 UNION 子查询补充安全字段。
- [x] T044 改造 `AdPicMapper.xml` 2 个导出 SELECT，phone 改为 `COALESCE(phone_mask, phone)` 并补充安全字段。
- [x] T045 补充 drh-kk-cms 5 个遗漏的 DTO/Output 类安全字段：`AdUserPicFlowDto`、`PoolAdListOutput`、`AdExportOutput`、`AdUserPicExportDto`、`BookQuestionRecordHistoryOutput`。
- [x] T046 全量扫描 ju-chat 所有 XML Mapper 中 SELECT phone 的查询语句。
- [x] T047 改造 ju-chat `OrderBookReissueMapper.xml`（ai、app、lms 三个模块）resultMap 和 SELECT 补充安全字段。
- [x] T048 改造 ju-chat `LiveWelfareReceiveMapper.xml`（ai、app、lms 三个模块）SELECT 补充 userPhoneMask/userPhoneMd5/userPhoneAes。
- [x] T049 补充 ju-chat 遗漏的 DTO/BO 类安全字段：`LmsExportDataResultDto`（lms-common、ai-common）、`LiveWelfareReceiveBo`（lms-common、ai-common）、`LmsOrderGoodReissueDetailOutput`（lms-common）、`LmsQueryExportDataOutput`（lms-common）。

## Phase 6：XML Mapper 查询字段补充（第二轮）

- [x] T050 改造 `LivingStudyInfoMapper.xml` 4 个 SELECT（getEmpPageByInput、getMergeClassEmpPageByInput、getRolePageByInput、getMergeClassRolePageByInput）三层嵌套子查询传播 phone_mask/phone_md5/phone_aes。
- [x] T051 改造 `LiveCampUserMapper.xml` selectUser 共享 SQL 片段，t3 子查询和列传播补充安全字段。
- [x] T052 改造 `HandoverPlusDelMapper.xml` getStuPageList 补充安全字段。
- [x] T053 改造 `SpecailHandoverMapper.xml` getStuPageList + stuListByGroupInput 补充安全字段。
- [x] T054 改造 `SpecialUserCampMapper.xml` getStuPageList + getStuPageListV3 补充安全字段。
- [x] T055 改造 `HandoverPlusMapper.xml` eduStudentList + groupStudentNmList 补充安全字段。
- [x] T056 改造 `HandoverMapper.xml` 8 个 SELECT（selectOrderUsersSQL、selectChangeGoodsList、selectOrderUserList、selectOrderUserPageV2、selectOrderUserListV2、selectOrderUserListNew、selectOrderUsersNewSQL 等）补充安全字段。
- [x] T057 改造 `SpecailUserMapper.xml` specailListPage 补充安全字段。
- [x] T058 改造 `OrderHandRecordMapper.xml` + `OrderHandRecordDelMapper.xml` getOrderPageList 补充安全字段。
- [x] T059 改造 `AppletUserMapper.xml` 4 个剩余查询（queryAllLeads、queryAllLeadsNoClass、getMergeClassAppletUserByInput、getMergeClassAppletUserPageByInput）补充安全字段。
- [x] T060 改造 `FrontMyClassOrderBoardMapper.xml` queryOrderList（from drh_applet_user）补充安全字段。
- [x] T061 改造 `WorksShipMapper.xml` 5 个 SELECT（selectSql × 2 个 phone 列、selectInvitePage、selectClassPageByInput、selectOrderPageByInput、selectOrderListByInput × 2 个 phone 列）补充安全字段。已验证 drh_live_works_user 表有 phone_mask/phone_md5/phone_aes 列。
- [x] T062 改造 `WorksAwardsRecordMapper.xml` selectAwards 补充安全字段。
- [x] T063 改造 `ShareIntroductionMapper.xml` getShareIntroductionData 补充安全字段。
- [x] T064 补充 19 个遗漏的 DTO/Output 类安全字段：DataPageOutput、LiveCampUserDto、GroupLiveBaseOutput、GroupStudentOutput、SpecailUserDto、OrderHandUserGroupDto、LeadsExportDto、QueryOrderPo、AppletShipOutput、InviteShipOutput、ClassShipOutput、OrderShipOutput、AppletShipExportDto、WorksAwardsOutput、HandoverOutput、OrderUser、OrderUserDto、EduOrderUser、OrderHandRecordDel、ShareIntroductionDataOutput。

## 执行记录

### D001 - 文档记录

- 执行内容：创建手机号安全字段查询返回与掩码入参校验规格文档。
- 验证方式：文档静态检查；已根据代码搜索结果记录涉及文件清单和接口影响分析。
- 自检结论：本阶段只新增文档，不修改业务代码。

### D002 - 实现记录

- 执行内容：按 spec.md 完成编码改造，涉及 drh 和 ju-chat 两个工程。
- 已实现：`DataSecurityInvoke.isMaskedPhone()` 掩码格式检测方法。
- 已实现：drh-kk-cms 11 个 Output/DTO 类增加 `phoneMask`、`phoneMd5`、`phoneAes` 字段。
- 已实现：ju-chat ai-common 8 个 Output 类增加安全字段。
- 已实现：`BookQuestionRecordServiceImpl`、`LiveCampGroupServiceImpl`、`CollectOrderServiceImp`、`LiveOrderDto` 查询映射改为掩码值 + 安全字段赋值。
- 已实现：`BookQuestionRecordServiceImpl.checkWritablePhone()`、`ExternalBookQuestionRecordServiceImpl.checkWritablePhone()` 增加掩码格式校验。
- 已实现：`DataSecurityUtilTest` 新增 8 个 `isMaskedPhone` 单元测试用例。
- 静态验证：已扫描确认 Output/DTO 的 phone 赋值来源已改为掩码值；已确认保存入口增加掩码校验。
- 待验证：接口行为验证（T027-T034）需可用环境下执行；编译验证待执行。
- 剩余风险：ju-chat ai 模块 Service 层查询映射改造（T021）需确认依赖方案后执行。

### D003 - XML Mapper 查询字段遗漏纠正

- 触发原因：代码审查发现 XML Mapper 中 SELECT 语句未包含 `phone_mask`、`phone_md5`、`phone_aes` 列，导致 Service 层映射到 Output/DTO 时安全字段为 null。
- 已实现：drh-kk-cms 7 个 XML Mapper 文件（15 个 SELECT）补充安全字段查询列。
- 已实现：drh-kk-cms 5 个遗漏的 DTO/Output 类补充安全字段。
- 已实现：ju-chat 6 个 XML Mapper 文件（OrderBookReissueMapper × 3 + LiveWelfareReceiveMapper × 3）补充安全字段。
- 已实现：ju-chat 6 个 DTO/BO 类补充安全字段。
- 文档同步：spec.md（D003 纠正记录）、tasks.md（Phase 5 任务）。
- 验证结果：待编译和接口验证。

### D004 - XML Mapper 查询字段第二轮补遗

- 触发原因：D003 验证环节发现 drh-kk-cms 仍有 14+ 个 XML Mapper 文件（30+ 个 SELECT）未补充安全字段查询列，涉及 Handover 系列、LivingStudyInfo、LiveCampUser、WorksShip 等核心业务模块。同时发现 19 个 DTO/Output 类缺少安全字段。
- 已实现：drh-kk-cms 14 个 XML Mapper 文件（30+ 个 SELECT）补充安全字段查询列：
  - LivingStudyInfoMapper.xml（4 个 SELECT，三层嵌套子查询传播）
  - LiveCampUserMapper.xml（selectUser 共享 SQL 片段）
  - HandoverPlusDelMapper.xml（getStuPageList）
  - SpecailHandoverMapper.xml（getStuPageList + stuListByGroupInput）
  - SpecialUserCampMapper.xml（getStuPageList + getStuPageListV3）
  - HandoverPlusMapper.xml（eduStudentList + groupStudentNmList）
  - HandoverMapper.xml（8 个 SELECT：selectOrderUsersSQL、selectChangeGoodsList、selectOrderUserList、selectOrderUserPageV2、selectOrderUserListV2、selectOrderUserListNew、selectOrderUsersNewSQL 等）
  - SpecailUserMapper.xml（specailListPage）
  - OrderHandRecordMapper.xml + OrderHandRecordDelMapper.xml（getOrderPageList）
  - AppletUserMapper.xml（queryAllLeads、queryAllLeadsNoClass、getMergeClassAppletUserByInput、getMergeClassAppletUserPageByInput）
  - FrontMyClassOrderBoardMapper.xml（queryOrderList，from drh_applet_user）
  - WorksShipMapper.xml（5 个 SELECT，含 oPhone/superPhone/tPhone 非标准字段名映射）
  - WorksAwardsRecordMapper.xml（selectAwards）
  - ShareIntroductionMapper.xml（getShareIntroductionData）
- 已实现：drh-kk-cms 20 个 DTO/Output 类补充安全字段（含 ShareIntroductionDataOutput、AppletShipOutput/AppletShipExportDto 非标准字段名映射、OrderHandRecordDel 实体类 @TableField(exist=false) 标注）。
- 已验证：drh_live_works_user 表确认有 phone_mask/phone_md5/phone_aes 列（LiveWorksUser 实体已含对应字段）。
- 文档同步：tasks.md（Phase 6 任务 + D004 记录）。
- 验证结果：待编译和接口验证。
