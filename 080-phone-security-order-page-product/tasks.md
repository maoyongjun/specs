# 任务清单：商品订单分页手机号安全补遗

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充字段存在、赋值位置、product 兜底和相似遗漏扫描记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求，确认目标入口为 `kkhc-bizcenter/product OrderController#getOrderPage`。
- [x] T002 确认 product 调用链：Controller -> `OrderServiceImpl#getOrderPage` -> `OrderFeign#getOrderPage` -> `kkhc-idc-lms /order/getOrderPage`。
- [x] T003 确认 `lms-common OrderPageOutput` 缺 `phoneMask/phoneMd5/phoneAes`，`ai-common` 同名 DTO 已有字段。
- [x] T004 确认上游 `app/lms/ai OrderPageProcessorDataFacade#processLiveUser` 的手机号来源为 `LiveUserDO`。
- [x] T005 确认 `OrderOutput/getOrderList/getOneByOrderNo` 不含手机号字段，不属于同类漏改。

**检查点**：T001-T005 已完成，可以进入实现。

## Phase 2：风险门禁

- [x] T006 检查空页风险：`Page` 或 `records` 为空时直接返回，不构造占位数据。
- [x] T007 检查 product 编译兼容：product 依赖的 `lms-common` 可能滞后，兜底读取安全字段使用反射。
- [x] T008 检查下游读取：product 只覆盖 `phone` 展示值，优先用 `phoneMask`，旧明文 `phone` 本地掩码；不改分页、查询或 Feign 入参。
- [x] T009 检查相似 DTO：`lms-common output/order` 中有 `phone` 但无 `phoneMask` 的输出类需补齐。
- [x] T010 检查地址记录旧语义：`LmsRealGoodsAddressRecordOutput.phone` 被 product 补发链路用于创建明细，本次不改为掩码。
- [x] T011 测试映射：字段扫描、赋值扫描、product 兜底扫描和编译验证。

**检查点**：T006-T011 已有明确结论。

## Phase 3：实现

- [x] T012 在 `lms-common OrderPageOutput` 增加 `phoneMask/phoneMd5/phoneAes`。
- [x] T013 在 `kkhc-idc app/lms/ai OrderPageProcessorDataFacade#processLiveUser` 设置安全三字段。
- [x] T014 在 `kkhc-bizcenter/product OrderServiceImpl#getOrderPage` 增加返回前展示兜底。
- [x] T015 在 `lms-common LmsRealGoodsAddressRecordOutput` 增加 `phoneMask/phoneMd5/phoneAes`。
- [x] T016 保持订单分页查询、地址记录 `phone` 旧语义和发货链路不变。

## Phase 4：测试与验证

- [ ] T017 扫描 `OrderPageOutput` 和 `LmsRealGoodsAddressRecordOutput` 字段存在。
- [ ] T018 扫描三套 `OrderPageProcessorDataFacade` 均设置安全字段。
- [ ] T019 扫描 `lms-common output/order` 无有 `phone` 但无 `phoneMask` 的输出类。
- [ ] T020 运行目标 Maven 编译或记录环境阻塞。
- [ ] T021 检查 git diff，确认无无关改动。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `080-phone-security-order-page-product` 规格目录，记录 getOrderPage 漏改、调用链和相似 DTO 检查。
- 验证方式：静态读取 `OrderController`、`OrderServiceImpl`、`OrderFeign`、`OrderPageOutput`、三套 `OrderPageProcessorDataFacade`。
- 自检结论：实现前已确认参数来源、赋值时机、空对象风险、下游读取和旧逻辑保持要求。

### D002 - 实现记录

- 实现内容：`待验证后填写。`
- 测试命令：`待验证后填写。`
- 测试结果：`待验证后填写。`
- 自检结论：`待验证后填写。`

### D003 - 纠正记录模板

- 触发原因：`用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题`。
- 修正内容：`说明具体修正`。
- 文档同步：`说明同步了哪些文件`。
- 验证结果：`说明测试或静态验证`。
