# 任务清单：手机号安全字段保存与查询改造

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`、`032-phone-security-columns` DDL 已在测试库执行  
**测试**：实现阶段必须补充与关键行为一一对应的单元测试。

## Phase 1：代码事实确认

- [ ] T001 复查用户需求和本目录 `AGENTS.md`，确认范围仅限 `H5Order` / `H5OrderDO` 和 `BookQuestionRecord` / `BookQuestionRecordDO`，涉及两个工程：`C:\workspace\drh` 和 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai`。
- [ ] T002 确认 drh 工程中 `H5Order`（drh-common）和 `BookQuestionRecord`（drh-common）的字段结构，以及各模块（drh-pay / drh-endpoint / drh-kk-cms / drh-callback / drh-media-process）中所有涉及手机号写入的 Service 方法。
- [ ] T003 确认 ju-chat 工程 ai 模块中 `H5OrderDO`（ai-common）和 `BookQuestionRecordDO`（ai-common）的字段结构，以及 Service 中涉及手机号写入和查询的方法。
- [ ] T004 确认 ju-chat 工程 ai 模块是否能访问 drh-common 的 `DataSecurity*` 类（检查 Maven 依赖链）。如不可用，记录并确认替代方案。
- [ ] T005 确认 `DataSecurityUtil.aesDecrypt()` 对明文手机号输入的行为：抛异常、返回 null、还是返回乱码。决定 `createAesInfo()` 的兼容策略。
- [ ] T006 确认 `DataSecurityInvoke.doDsTask()` 远程 FC 调用的超时时间、失败行为和降级策略。
- [ ] T007 确认 MD5 大小写口径：`DataSecurityInvoke.doDsTask().getMd5()` 输出大写还是小写。
- [ ] T008 确认 drh-kk-cms 中批量 `in` 查询（`getPhoneResult()`、`getPhoneChannelSet()`）本次是否改造，还是标记 TODO。

**检查点**：不得在未完成 T001-T008 前进入实现。

## Phase 2：风险门禁

- [ ] T009 检查 `DataSecurityInput` 是否存在空 `data` 传入 `doDsTask()` 的风险，确认 `createAesInfo()` 内部做空值保护。
- [ ] T010 检查 `DataSecurityOutput` 返回值是否可能为 `null` 或字段缺失（远程 FC 调用可能超时），确认 `createAesInfo()` 做空值保护。
- [ ] T011 检查是否存在先 `save()` 后补安全字段的调用顺序风险。
- [ ] T012 检查 `H5Order.create()` 静态工厂方法的调用链，确认改造后不影响现有调用方。
- [ ] T013 检查前端兼容逻辑：明文手机号经过 `DataSecurityUtil.aesDecrypt()` 后的行为，确认 try-catch + 回退策略可行。
- [ ] T014 检查 drh-kk-cms `editAddressV2()` 中 Redis 锁 key 是否基于 phone，改造后是否受影响。
- [ ] T015 检查本次改造是否影响接口契约（返回 VO/DTO 字段名是否变化，前端是否需要配合修改）。
- [ ] T016 为每个关键行为建立测试映射：
  - 保存：明文输入正常路径、密文输入正常路径、空手机号路径、解密失败路径、FC 调用失败路径。
  - 查询：正常匹配路径、空查询路径、无匹配结果路径。
  - 展示：正常返回 mask 路径、历史 NULL fallback 路径。

**检查点**：T009-T016 必须有明确结论；发现高风险时先更新 `spec.md` 的"历史问题防漏分析"。

## Phase 3：实现

### 3.1 实体类改造

- [ ] T017 在 `H5Order`（drh-common）中增加 `phoneMask`、`phoneMd5`、`phoneAes` 持久化字段和 `createAesInfo()` 方法（含前端兼容逻辑）。
- [ ] T018 在 `BookQuestionRecord`（drh-common）中增加 `phoneMask`、`phoneMd5`、`phoneAes` 持久化字段和 `createAesInfo()` 方法。
- [ ] T019 在 `H5OrderDO`（ai-common）中增加 `phoneMask`、`phoneMd5`、`phoneAes` 持久化字段和 `createAesInfo()` 方法（如 ai 模块可访问 DataSecurity 类）。
- [ ] T020 在 `BookQuestionRecordDO`（ai-common）中增加 `phoneMask`、`phoneMd5`、`phoneAes` 持久化字段和 `createAesInfo()` 方法。

### 3.2 保存链路改造（drh 工程）

- [ ] T021 改造 drh-pay `H5OrderServiceImpl`：`create()` / `insertH5Order()` / `insertOpenH5Order()` 在 `save()` 前调用 `createAesInfo()`。
- [ ] T022 改造 drh-endpoint `H5OrderServiceImpl`：`editAddress()` / `editAddressV2()` 中 `BookQuestionRecord` 保存前调用 `createAesInfo()`。
- [ ] T023 改造 drh-kk-cms `BookQuestionRecordServiceImpl`：`editAddress()` / `editAddressV2()` 中 `BookQuestionRecord` 保存前调用 `createAesInfo()`。
- [ ] T024 改造 drh-callback `H5OrderServiceImpl`：如涉及 H5Order 更新手机号，调用 `createAesInfo()`。
- [ ] T025 改造 drh-media-process：如涉及手机号写入，调用 `createAesInfo()`。
- [ ] T026 改造 `H5Order.create()` 静态工厂方法或调用方。

### 3.3 保存链路改造（ju-chat 工程）

- [ ] T027 改造 ai 模块 `BookQuestionRecordServiceImpl`：如涉及 `BookQuestionRecordDO` 保存，在 `save()` 前调用 `createAesInfo()`。

### 3.4 查询链路改造

- [ ] T028 改造 drh-pay `H5OrderServiceImpl.selectIsPay()` 和 `H5OrderController.queryPhone()`：phone → phoneMd5。
- [ ] T029 改造 drh-endpoint `H5OrderServiceImpl.queryLeads()`、`editAddress()`、`editAddressV2()` 中的 phone 查询：phone → phoneMd5。
- [ ] T030 改造 drh-kk-cms `BookQuestionRecordServiceImpl.editAddressV2()` 和 `selectCanEdit()` 中的 phone 查询：phone → phoneMd5。
- [ ] T031 改造 ju-chat ai `BookQuestionRecordServiceImpl.getBookQuestionRecordByAppletUserId()`：phone → phoneMd5。
- [ ] T032 确认 MD5 计算工具方法统一，保证口径一致。
- [ ] T033 对批量 `in` 查询（`getPhoneResult()`、`getPhoneChannelSet()`）标记 TODO，本次不改造。

### 3.5 展示链路改造

- [ ] T034 改造 drh 工程中 `H5Order` 和 `BookQuestionRecord` 相关的列表 / 导出接口，手机号返回 `phoneMask`。
- [ ] T035 改造 ju-chat 工程中 `BookQuestionRecordDO` 相关返回，手机号改为 `phoneMask`。
- [ ] T036 处理历史数据 `phoneMask` 为 NULL 的 fallback 逻辑。

### 3.6 文档同步

- [ ] T037 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：单元测试

- [ ] T038 编写 `H5Order.createAesInfo()` 单元测试（drh-common）：
  - 明文手机号输入 → `phoneMask`、`phoneMd5`、`phoneAes` 均正确。
  - 前端加密密文输入 → 解密后安全字段与明文输入结果一致。
  - 空手机号输入 → 三个安全字段均为 `NULL`，不抛异常。
  - 非法密文输入（解密失败）→ 不抛异常，安全字段为 `NULL` 或回退处理。
- [ ] T039 编写 `BookQuestionRecord.createAesInfo()` 单元测试（drh-common，同 T038 四种场景）。
- [ ] T040 编写前端兼容判断逻辑单元测试：验证同一手机号在明文和密文两种输入下，`phoneMd5` 结果一致。
- [ ] T041 编写 MD5 查询工具方法单元测试：验证输出与 `DataSecurityInvoke.doDsTask().getMd5()` 口径一致。
- [ ] T042 测试中断言 `DataSecurityInput.setData()` 参数内容（下游参数断言），不只断言最终结果。

## Phase 5：测试与验证

- [ ] T043 运行全部单元测试，确认通过。
- [ ] T044 验证保存后数据库中 `phone_mask`、`phone_md5`、`phone_aes` 均有值（集成测试或手动验证）。
- [ ] T045 验证查询改造后 SQL 使用 `phone_md5` 条件（SQL 日志或 mock 验证）。
- [ ] T046 搜索确认 drh 工程没有残留的 `.eq(H5Order::getPhone, ...)` 和 `.eq(BookQuestionRecord::getPhone, ...)` 旧查询（排除批量 in 查询和排除表）。
- [ ] T047 搜索确认 ju-chat 工程没有残留的 `.eq(H5OrderDO::getPhone, ...)` 和 `.eq(BookQuestionRecordDO::getPhone, ...)` 旧查询。
- [ ] T048 运行两个工程的编译命令，确认无编译错误。

## 执行记录

### D001 - 文档记录

- 执行内容：创建手机号安全字段保存与查询改造规格文档。
- 验证方式：代码搜索确认目标实体、Service、Mapper 和现有加密工具位置。
- 自检结论：保存、查询、展示三条链路改造范围明确。

### D002 - 需求补充纠正

- 触发原因：用户补充——`app_phone` 不由本次处理；前端整改前会传明文手机号，需兼容；需编写单元测试。
- 修正内容：范围缩小为 2 张表；新增前端兼容要求和单测要求。
- 文档同步：已同步更新四个文件。

### D003 - 项目路径补充纠正

- 触发原因：用户补充——修改代码涉及 `C:\workspace\drh` 和 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai` 两个工程。
- 修正内容：
  - 确认 `DataSecurity*` 存在于 drh-common 的 `com.drh.common.fc.datasec` 包中。
  - 确认 `DataSecurityInvoke` 调用远程 FC 函数 `DataSecurity-test`。
  - drh 工程涉及 6 个模块：drh-common / drh-pay / drh-endpoint / drh-kk-cms / drh-callback / drh-media-process。
  - 实体名在 drh 中为 `H5Order` / `BookQuestionRecord`，在 ju-chat 中为 `H5OrderDO` / `BookQuestionRecordDO`。
  - 补全所有保存和查询落点（10+ 处 Service 方法）。
  - 新增 ju-chat ai 模块 DataSecurity 依赖可用性为待确认项。
  - 批量 `in` 查询标记为暂不改造。
- 文档同步：`spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 已同步更新。
- 验证结果：文档静态检查通过。

### D004 - 实现记录

- 已被 D006 替代：本轮范围由 2 张表扩展为 7 张表，并按 `phone` 后续可清空的口径补全。

### D006 - 手机号安全字段补全与真实地址记录追加

- 触发原因：用户补充目标表为 `drh_h5_order`、`drh_live_user`、`drh_applet_user`、`drh_book_question_record`、`drh_external_book_question_record`、`drh_book_edit_address_compensation`，并追加 `drh_real_address_record`；`app_phone` 明确不处理。
- 实现内容：
  - **统一工具**：DRH 与 IDC AI 侧 `DataSecurityInvoke` 增加 `buildPhoneSecurity`、`computePhoneMd5`、`decryptPhoneAes`、`phoneMaskForDisplay`。
  - **实体补齐**：DRH 补齐 `H5Order`、`BookQuestionRecord`、`AppletUser`、`LiveUser`、`ExternalBookQuestionRecord`、`RealGoodsAddressRecord`；IDC AI 补齐 `H5OrderDO`、`BookQuestionRecordDO`、`AppletUserDo`、`LiveUserDO`、`ExternalBookQuestionRecordDO`、`BookEditAddressCompensationDO`、`RealGoodsAddressRecordDO`。
  - **保存/更新链路**：H5Order 创建、支付回调线索更新、图书登记、非留资、真实地址记录、补偿记录、学员/线索手机号更新均同步写 `phone_mask/phone_md5/phone_aes`。
  - **查询/读取链路**：目标表手机号等值/批量匹配改用 `phone_md5`；需要明文时从方法入参或 `phone_aes` 解密；展示/列表/订单查询返回 `phone_mask` 或本地掩码。
  - **真实地址记录**：`RealGoodsAddressRecord` 保存前调用 `createAesInfo()`，ERP 下发手机号通过 `phone_aes` 解密兜底，AI 订单地址展示返回掩码手机号。
- 接口影响：
  - 支付/订单：`/h5/order/pay`、`/h5/order/open/pay`、`/h5/order/wx/notify`、`/h5/order/query/phone`、`/ali/pay/*`。
  - 图书登记：DRH `editAddress`、`editAddressV2`、`queryLeads`，AI `/book/getBookQuestionRecordByAppletUserId`。
  - 非留资/补偿：`/external/bookQuestionRecord/create`、`/count`、`/queryHistoryPage`、`/queryHistoryExpressNo`，AI `/book-edit-address-compensation/saveOne`、`/compensationRun`。
  - 真实地址/物流：`/realGoodsAddressRecord/*`、`/bookPath/queryTrackNumOrder` 及订单物流展示链路。
- 测试建议：
  - 7 张表新增/更新后校验 `phone_mask`、`phone_md5`、`phone_aes`。
  - 手动清空目标表 `phone` 后验证支付回调、订单手机号查询、图书登记查询、物流/ERP 推送、补偿任务仍可用。
  - SQL 日志确认目标表手机号匹配不再依赖 `phone = ?`。
  - 展示/导出返回掩码，不返回明文；`app_phone` 相关接口不纳入本次验证。
- 非目标表静态提示：广告分配、客服记录、外呼/短信任务、订单售后/补发等非目标表仍存在 `phone` 查询或展示，本次未改业务逻辑。

### D005 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
