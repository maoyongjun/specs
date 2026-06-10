# 任务清单：LiveCampGroup 学员订单手机号安全补遗

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 确认入口：`LiveCampGroupController#stuOrderInfo` 返回 `CollectOrderOutput`，实际由 `LiveCampGroupServiceImpl#stuOrderInfo` 调 `CollectOrderServiceImp#collectOrderList`。
- [x] T002 确认 `CollectOrderOutput`、`CollectOrderDetailOutput`、`AddressDetailDto`、`GroupLiveDetailOutput` 当前缺少安全字段。
- [x] T003 确认关键字段来源：`LiveUser.phoneMask/phoneMd5/phoneAes` 和 `RealGoodsAddressRecord.phoneMask/phoneMd5/phoneAes`。
- [x] T004 确认本次不影响配置、Redis、MQ、Feign、FC 或数据库写入。
- [x] T005 确认旧逻辑保持：分页、权限、OTS、订单状态、金额、收货地址和课程筛选逻辑不变。

## Phase 2：风险门禁

- [x] T006 检查占位对象：`new LiveUser()` 安全字段为空时不得回退明文。
- [x] T007 检查调用顺序：所有安全字段在返回对象写出前赋值。
- [x] T008 检查下游读取字段：前端读取展示字段和安全三字段均有来源。
- [x] T009 检查接口契约：只新增响应字段，不改路径、请求、查询、MQ、Redis 或 DB。
- [x] T010 记录搜索语义风险：`DayUrgeClassMapper`、`HandoverMapper` 等 `phone LIKE` 候选本次只登记不改。
- [x] T011 建立测试映射：DTO 字段、订单手机号、收货人手机号、课程详情手机号、静态搜索和编译验证。

## Phase 3：实现

- [ ] T012 `CollectOrderOutput` 新增 `phoneMask/phoneMd5/phoneAes`。
- [ ] T013 `CollectOrderDetailOutput` 新增 `phoneMask/phoneMd5/phoneAes`。
- [ ] T014 `AddressDetailDto` 新增 `receiverPhoneMask/receiverPhoneMd5/receiverPhoneAes`。
- [ ] T015 `GroupLiveDetailOutput` 新增 `phoneMask/phoneMd5/phoneAes`。
- [ ] T016 `CollectOrderServiceImp.collectOrderList()` 填充订单用户手机号安全字段。
- [ ] T017 `CollectOrderServiceImp.collectOrderDetail()` 填充订单用户手机号安全字段。
- [ ] T018 `CollectOrderServiceImp.getAddressDetailDtos()` 填充收货人手机号安全字段。
- [ ] T019 `LiveCampGroupServiceImpl.liveStudentDetailV2()` 将课程详情手机号改为掩码并填充安全字段。
- [ ] T020 同步更新文档实现记录。

## Phase 4：测试与验证

- [ ] T021 新增或扩展 `CollectOrderServiceImpTest`，覆盖订单用户和收货人手机号安全字段装配。
- [ ] T022 扩展 `LiveCampGroupServiceImplTest`，覆盖 `GroupLiveDetailOutput` 手机号安全字段装配。
- [ ] T023 静态搜索确认四个 DTO 均包含安全字段。
- [ ] T024 静态搜索确认 `LiveCampGroupServiceImpl` 不再存在 `output.setPhone(liveUser.getPhone())`。
- [ ] T025 运行 `mvn -f C:\workspace\drh\pom.xml -pl drh-common,drh-kk-cms -am -DskipTests compile`。
- [ ] T026 运行 `mvn -f C:\workspace\drh\pom.xml -pl drh-kk-cms -am -Dtest=LiveCampGroupServiceImplTest,CollectOrderServiceImpTest test`。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `068-livecamp-stu-order-phone-security-gap`，记录 `stu/orderInfo` 和相似漏点。
- 验证方式：代码搜索和 DTO/Service 静态确认。
- 自检结论：实现范围清晰，不涉及数据库、MQ、Redis、Feign、FC 或搜索语义变更。

### D002 - 实现记录

- 实现内容：`待实现后填写。`
- 测试命令：`待实现后填写。`
- 测试结果：`待实现后填写。`
- 自检结论：`待实现后填写。`

### D003 - 纠正记录模板

- 触发原因：`说明为什么需要纠正。`
- 修正内容：`说明具体修正。`
- 文档同步：`说明同步了哪些文件。`
- 验证结果：`说明测试或静态验证。`
