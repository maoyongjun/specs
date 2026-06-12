# 功能规格：商品订单分页手机号安全补遗

**功能目录**：`080-phone-security-order-page-product`  
**创建日期**：`2026-06-12`  
**状态**：Implemented  
**输入**：用户要求在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档，并修复 `C:\workspace\ju-chat\kkhc\kkhc-bizcenter\product` 的 `com.drh.bizcenter.product.controller.order.OrderController#getOrderPage` 手机号加密改造遗漏，同时检查是否有类似未修改项。

## 背景

- 当前问题：`kkhc-bizcenter/product` 的 `OrderController#getOrderPage` 仍直接透传 `kkhc-idc-lms /order/getOrderPage` 返回值；`lms-common` 的 `OrderPageOutput` 相比 `ai-common` 缺少 `phoneMask/phoneMd5/phoneAes`，product 侧无法透传安全字段或基于安全字段兜底展示。
- 当前行为：上游 `app/lms/ai` 的 `OrderPageProcessorDataFacade` 已把 `phone` 设为掩码展示，但未同步给返回对象设置安全三字段；product 层没有二次兜底。相似检查发现 `LmsRealGoodsAddressRecordOutput` 在 `lms-common` 也比 `ai-common` 少安全三字段。
- 目标行为：`/order/getOrderPage` 返回记录中的 `phone` 以掩码展示为准，并透传 `phoneMask/phoneMd5/phoneAes`；product 层在 Feign 返回后优先使用 `phoneMask`，旧依赖无安全字段但 `phone` 是 11 位明文时本地掩码兜底。相似 DTO 缺口补齐安全字段。
- 非目标：不修改接口路径、HTTP 方法、分页参数、订单查询 SQL、发货/ERP 明文手机号使用、DDL、历史回填或 `phone` 字段名称；不把地址记录接口的 `phone` 旧语义改成掩码。

## 用户场景与测试

### 用户故事 1 - product 订单分页不返回明文手机号（优先级：P1）

运营调用 `kkhc-bizcenter/product /order/getOrderPage` 时，手机号展示字段必须为掩码，且可获得安全字段用于后续受控处理。

**独立测试**：构造上游返回 `OrderPageOutput.phoneMask` 的记录，调用 `OrderServiceImpl#getOrderPage` 后确认 `phone` 被覆盖为掩码；构造旧依赖只返回 11 位明文 `phone` 时确认本地掩码。

**验收场景**：

1. **Given** 上游返回记录包含 `phoneMask=138****5678`，**When** product 执行 `getOrderPage`，**Then** 响应记录 `phone=138****5678`。
2. **Given** 上游返回记录没有安全字段但 `phone=13812345678`，**When** product 执行 `getOrderPage`，**Then** 响应记录 `phone=138****5678`。
3. **Given** 上游返回记录没有安全字段且 `phone` 不是 11 位明文，**When** product 执行 `getOrderPage`，**Then** 不抛异常，保持上游 `phone` 原值，兼容旧 `lms-common` 依赖。

### 用户故事 2 - 上游订单分页透传安全字段（优先级：P1）

`kkhc-idc app/lms/ai` 三套订单分页组装应在处理 `LiveUserDO` 时同步设置 `phoneMask/phoneMd5/phoneAes`，避免只返回展示值。

**独立测试**：静态确认三套 `OrderPageProcessorDataFacade#processLiveUser` 均调用 `record.setPhoneMask/PhoneMd5/PhoneAes`，并用 `phoneMaskForDisplay` 设置 `phone`。

**验收场景**：

1. **Given** `LiveUserDO` 有安全字段，**When** 上游组装 `OrderPageOutput`，**Then** 输出包含同名安全字段。
2. **Given** `phoneMask` 为空但 `phoneAes` 有值，**When** 上游组装 `OrderPageOutput`，**Then** `phone` 仍按既有 `phoneMaskForDisplay` 兜底生成掩码。

### 用户故事 3 - 相似 DTO 字段缺口补齐（优先级：P2）

与 `OrderPageOutput` 同样存在 ai-common 已改、lms-common 未改的订单输出 DTO，应补齐安全字段，避免后续 Feign 调用丢字段。

**独立测试**：扫描 `lms-common ... output/order`，确认不存在有 `private String phone;` 但没有 `phoneMask` 的输出类。

**验收场景**：

1. **Given** `LmsRealGoodsAddressRecordOutput` 从 `RealGoodsAddressRecordDO` 转换，**When** DO 含安全字段，**Then** 输出可透传 `phoneMask/phoneMd5/phoneAes`。
2. **Given** product 补发链路仍使用地址记录 `phone` 创建补发明细，**When** 本次补字段完成，**Then** 不改变该 `phone` 的旧语义，避免影响发货。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `OrderPageOutput.phoneMask/phoneMd5/phoneAes`：来源 `LiveUserDO.phoneMask/phoneMd5/phoneAes`；在 `OrderPageProcessorDataFacade#processLiveUser` 处理单条记录时赋值；下游 product Feign 返回后读取。
  - `OrderPageOutput.phone`：来源安全字段展示值；上游处理记录时赋值，product `OrderServiceImpl#maskOrderPagePhone` 返回前按 `phoneMask` 或 11 位明文本地掩码再次兜底。
  - `LmsRealGoodsAddressRecordOutput.phone*`：来源 `RealGoodsAddressRecordDO` 同名字段；由 MapStruct 同名映射透传。
- 下游读取字段清单：
  - `OrderController#getOrderPage` 读取 `OrderService#getOrderPage` 返回的 `Page<OrderPageOutput>`。
  - `OrderServiceImpl#maskOrderPagePhone` 读取 `phoneMask`，必要时读取旧 `phone` 明文并本地掩码，只覆盖 `phone`。
  - `OrderBookReissueServiceImpl#addNoChangedDetailList` 读取 `LmsRealGoodsAddressRecordOutput.phone` 创建补发明细，本次保持旧语义。
- 空对象 / 占位对象风险：
  - `Page` 或 `records` 为空时直接返回，不创建占位对象。
  - product 侧通过反射读取安全字段，兼容旧依赖缺字段，不把空字段当有效值覆盖。
- 调用顺序风险：
  - `phone` 兜底发生在 Feign 返回后、Controller 响应前；不依赖前端、异步或历史回填。
  - 上游 `processLiveUser` 在返回对象写出前同步赋值安全字段。
- 旧逻辑保持：
  - 保持原分页校验、查询条件、金额转换、订单状态、地址状态、商品和交接数据组装逻辑不变。
  - 保持 `getOneByOrderNo/getOrderList` 不变；其 `OrderOutput` 不含手机号字段。
  - 保持地址记录 `phone` 字段旧语义，不在本次改成掩码。
- 需要用户确认的设计选择：
  - 无。本次是最小补遗：补字段、掩码展示兜底和静态漏项检查。

## 边界情况

- `phoneMask` 非空：优先作为展示手机号。
- `phoneMask` 空、`phoneAes` 有值：沿用既有 `phoneMaskForDisplay()` 解密后掩码。
- `phoneMask` 为空、`phone` 为 11 位明文：product 本地掩码后覆盖。
- `phoneMask` 为空、`phone` 不是 11 位明文：product 不覆盖上游 `phone`，避免把旧依赖结果误清空。
- 旧 `lms-common` 运行时没有安全字段：product 反射读取失败后返回 null，不抛异常。
- `records` 为空：直接返回空页，不额外处理。
- 相似扫描只覆盖订单输出 DTO；查询条件、保存链路、ERP 明文使用按既有独立规格处理。

## 需求

### 功能需求

- **FR-001**：系统 MUST 为 `lms-common OrderPageOutput` 增加 `phoneMask/phoneMd5/phoneAes` 字段。
- **FR-002**：系统 MUST 在 `kkhc-idc app/lms/ai` 的 `OrderPageProcessorDataFacade#processLiveUser` 中同步设置安全三字段。
- **FR-003**：系统 MUST 保证 `OrderPageOutput.phone` 使用 `DataSecurityInvoke.phoneMaskForDisplay()` 的展示值。
- **FR-004**：系统 MUST 在 `kkhc-bizcenter/product OrderServiceImpl#getOrderPage` Feign 返回后基于 `phoneMask` 或 11 位明文手机号本地掩码兜底覆盖 `phone`。
- **FR-005**：product 兜底 MUST 兼容旧 `lms-common`，不能因缺少安全字段 getter 导致编译或运行失败。
- **FR-006**：系统 MUST 为 `lms-common LmsRealGoodsAddressRecordOutput` 补齐 `phoneMask/phoneMd5/phoneAes`。
- **FR-007**：系统 MUST NOT 修改订单分页查询 SQL、接口契约路径、分页语义、发货/ERP 所需明文手机号使用或地址记录 `phone` 旧语义。

## 成功标准

- **SC-001**：`lms-common OrderPageOutput` 和 `LmsRealGoodsAddressRecordOutput` 均包含 `phoneMask/phoneMd5/phoneAes` 字段。
- **SC-002**：三套 `OrderPageProcessorDataFacade#processLiveUser` 均设置 `phoneMask/phoneMd5/phoneAes`，并用 `phoneMaskForDisplay` 设置 `phone`。
- **SC-003**：`kkhc-bizcenter/product OrderServiceImpl#getOrderPage` 返回前调用手机号展示兜底逻辑。
- **SC-004**：扫描 `lms-common ... output/order` 不存在“有 `phone` 但无 `phoneMask`”的输出类。
- **SC-005**：目标模块编译或静态验证通过；若编译受本地 Maven 依赖阻塞，记录原因。

## 假设

- `drh_live_user` 和 `drh_real_address_record` 已有安全字段，历史回填由既有手机号安全治理规格负责。
- `product` 当前 Maven 依赖的 `lms-common` 发布版本可能滞后，因此 product 兜底使用反射兼容新旧 DTO。
- `phoneMd5/phoneAes` 的对外暴露口径沿用前序手机号安全接口整改规格。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已记录目标接口、上游字段来源、product 兜底和相似 DTO 检查结果。

### D002 - 实现记录

- 实现内容：补齐 `lms-common OrderPageOutput` 安全三字段；三套 `OrderPageProcessorDataFacade` 设置安全三字段；`product OrderServiceImpl#getOrderPage` 返回前反射读取 `phoneMask` 并对旧 11 位明文 `phone` 本地掩码兜底；补齐 `lms-common LmsRealGoodsAddressRecordOutput` 安全三字段。
- 测试命令：见 `tasks.md` D002。
- 测试结果：见 `tasks.md` D002。
- 自检结论：`getOrderPage` 已改造；相似字段缺口已补；地址记录 `phone` 旧语义保持不变。

### D003 - 纠正记录模板

- 触发原因：`用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题`。
- 修正内容：`说明旧口径和新口径`。
- 文档同步：`说明同步了哪些文件`。
- 验证结果：`说明测试或静态验证结果`。
