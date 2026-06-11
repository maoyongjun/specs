# 任务清单：OrderGoodReissueDetailOutput 手机号安全字段补齐

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充编译、静态验证或测试记录。

## Phase 1：代码事实确认

- [x] T001 确认本规格目录为 `078-phone-security-order-good-reissue-output`。
- [x] T002 确认目标 DTO 为 `kkhc-bizcenter/product-common/.../OrderGoodReissueDetailOutput.java`。
- [x] T003 确认目标 DTO 当前只有 `phone`，缺少 `phoneMask/phoneMd5/phoneAes`。
- [x] T004 确认上游 `kkhc-idc/lms-common` 和 `kkhc-idc/ai-common` 的 `LmsOrderGoodReissueDetailOutput` 已有安全字段。
- [x] T005 确认转换入口为 `OrderBookReissueConverter.convert(LmsOrderGoodReissueDetailOutput)`。
- [x] T006 确认返回路径包含 `pageDetailQuery` 和 `view/detailList`。
- [x] T007 确认 ERP 下单在 `OrderBookReissueErpServiceImpl.createOrderReq` 中读取 `getPhone()`，不得改为掩码。

**检查点**：实现范围限定为 bizcenter 输出 DTO 补字段。

## Phase 2：风险门禁

- [x] T008 检查参数来源：安全字段来自上游 `LmsOrderGoodReissueDetailOutput`。
- [x] T009 检查赋值时机：Feign 返回后经 converter 显式兼容映射。
- [x] T010 检查占位对象风险：本次不新增空 DTO、空 JSON 或空 Map。
- [x] T011 检查调用顺序风险：本次不改变调用顺序。
- [x] T012 检查接口契约风险：新增 JSON 字段为兼容扩展，保留原 `phone` 字段。
- [x] T013 检查旧逻辑保持：不改 DDL、查询条件、Feign 方法签名、ERP、MQ、Redis 或 FC。

**检查点**：风险门禁已完成，可进入实现。

## Phase 3：实现任务

- [x] T014 在 `OrderGoodReissueDetailOutput` 中新增 `phoneMask` 字段。
- [x] T015 在 `OrderGoodReissueDetailOutput` 中新增 `phoneMd5` 字段。
- [x] T016 在 `OrderGoodReissueDetailOutput` 中新增 `phoneAes` 字段。
- [x] T017 保持 `phone` 字段不删除、不改名、不改语义。
- [x] T018 创建并填写 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- [x] T019 在 `OrderBookReissueConverter.convert(LmsOrderGoodReissueDetailOutput)` 中增加 `phoneMask/phoneMd5/phoneAes` 显式兼容映射。

## Phase 4：测试与验证

- [x] T020 运行目标模块 Maven 编译，确认 Lombok 和 MapStruct 生成成功。
- [x] T021 静态验证 `OrderGoodReissueDetailOutput` 已包含三个安全字段。
- [x] T022 静态验证 `LmsOrderGoodReissueDetailOutput` 已包含同名字段。
- [x] T023 静态验证 `OrderBookReissueConverter.convert(LmsOrderGoodReissueDetailOutput)` 方法仍存在并显式映射安全字段。
- [x] T024 静态验证 `pageDetailQuery` 和 `view` 返回路径仍经 converter。
- [x] T025 静态验证 ERP 下单仍读取 `getPhone()`。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `078-phone-security-order-good-reissue-output` 规格目录，编写 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- 验证方式：静态搜索 DTO、converter、service 和 ERP 读取链路。
- 自检结论：文档已记录事实、目标、非目标、风险门禁和验证计划。

### D002 - 实现记录

- 实现内容：`OrderGoodReissueDetailOutput` 新增 `phoneMask`、`phoneMd5`、`phoneAes` 字段；`OrderBookReissueConverter` 增加安全字段显式兼容映射。
- 测试命令：`mvn -B -pl product -am -DskipTests clean compile`。
- 测试结果：`BUILD SUCCESS`；`product-common` 重新编译 54 个源码文件，`product` 重新编译 88 个源码文件；`OrderBookReissueConverter` 不再报告 `phoneMask/phoneMd5/phoneAes` 未映射，仅保留历史既有的 `goodsNo/goodsName` 等未映射警告。
- 自检结论：生成的 `OrderBookReissueConverterImpl` 已调用 `setPhoneMask/readStringProperty`、`setPhoneMd5/readStringProperty`、`setPhoneAes/readStringProperty`；ERP 下单仍使用 `getPhone()` 设置收件电话，旧发货链路未改。
