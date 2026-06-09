# 功能规格：AppCollectOrderController 手机号安全返回补充

**功能目录**：`065-app-collect-order-phone-security-return`  
**创建日期**：`2026-06-09`  
**状态**：Implemented（局部验证通过；全量 Maven 受本机环境限制未完成）  
**输入**：在 `C:\workspace\ju-chat\specs` 创建 spec-kit 文档，补充手机号加密整改需求：`C:\workspace\ju-chat\kkhc\kkhc-idc\app\src\main\java\com\kkhc\idc\lms\controller\order\app\AppCollectOrderController.java` 返回的 `phone`，以及增加的加密字段、掩码需要返回。`AppCollectOrderController` 在 `lms` 目录也有，同步修改。

## 背景

- 当前问题：历史手机号安全整改已覆盖多处查询返回，但 `/app/collect/order/pageQuery` 仍在 `AppCollectOrderFacade.assembleAddressRecordOutputs` 中直接将 `RealGoodsAddressRecordDO.phone` 设置到返回对象，存在继续返回明文手机号的风险；`lms-common` 的 `AppCollectOrderOutput` 尚未声明 `phoneMask/phoneMd5/phoneAes`。
- 当前行为：
  - `kkhc-idc/app` 与 `kkhc-idc/lms` 下均存在 `AppCollectOrderController`，接口路径均为 `POST /app/collect/order/pageQuery`。
  - 两个 Controller 均只透传 `AppCollectOrderFacade.pageQuery(input)`。
  - 两个 Facade 均通过 `realGoodsAddressRecordService.getListByCollectOrders()` 获取 `RealGoodsAddressRecordDO`，再执行 `order.setPhone(addressRecord.getPhone())`。
  - `ai-common` 的 `AppCollectOrderOutput` 已有 `phoneMask/phoneMd5/phoneAes`；`lms-common` 的同名 Output 只有 `phone`。
- 目标行为：
  - `kkhc-idc/app` 的 `/app/collect/order/pageQuery` 返回的 `phone` 字段必须为 `phoneAes`。
  - `kkhc-idc/lms` 的 `/app/collect/order/pageQuery` 返回的 `phone` 字段继续按既有安全展示口径返回掩码值。
  - 两份返回对象必须同时包含 `phoneMask`、`phoneMd5`、`phoneAes`。
- 非目标：不新增接口路径；不修改分页入参、分页条件、订单筛选逻辑；不新增数据库字段、DDL、MQ、Redis 或外部调用；不清空历史 `phone` 字段。

## 用户场景与测试

### 用户故事 1 - idc-app 订单列表 phone 返回 phoneAes（优先级：P1）

用户在 idc-app 侧查询订单列表时，`phone` 字段按本接口特殊要求返回手机号 AES 密文。

**独立测试**：构造 `RealGoodsAddressRecordDO.phoneMask=138****5678`、`phoneAes=phone-aes`，调用 app 地址装配逻辑后断言 `AppCollectOrderOutput.phone=phone-aes`。

**验收场景**：

1. **Given** 地址记录存在 `phoneAes=phone-aes`，**When** 调用 idc-app 的 `/app/collect/order/pageQuery`，**Then** 返回记录中的 `phone` 为 `phone-aes`。
2. **Given** 地址记录存在 `phoneMask=138****5678` 和 `phoneAes=phone-aes`，**When** 调用 idc-app 接口，**Then** `phone` 仍返回 `phone-aes`，`phoneMask` 单独返回 `138****5678`。
3. **Given** 地址记录 `phoneAes` 为空，**When** 组装 idc-app 订单返回，**Then** `phone` 返回 `null`，不 fallback 到明文 `phone`。

### 用户故事 2 - lms 订单列表 phone 保持掩码（优先级：P1）

lms 侧同名接口仍按历史手机号安全整改口径返回掩码手机号，不能因 idc-app 特例回退为明文或密文。

**独立测试**：构造 `RealGoodsAddressRecordDO.phoneMask=138****5678`、`phoneAes=phone-aes`，调用 lms 地址装配逻辑后断言 `AppCollectOrderOutput.phone=138****5678`。

**验收场景**：

1. **Given** 地址记录存在 `phoneMask=138****5678`，**When** 调用 lms 的 `/app/collect/order/pageQuery`，**Then** 返回记录中的 `phone` 为 `138****5678`。
2. **Given** 地址记录 `phoneMask` 为空但 `phoneAes` 可解密，**When** 组装 lms 订单返回，**Then** `phone` 通过 `phoneAes` 现算掩码。
3. **Given** 地址记录 `phoneMask` 和 `phoneAes` 均为空，**When** 组装 lms 订单返回，**Then** `phone` 返回 `null`，不抛异常。

### 用户故事 3 - 订单列表返回安全字段（优先级：P1）

前端需要拿到手机号安全字段，以便后续按既有手机号安全链路展示或发起受控解密。

**独立测试**：构造地址记录包含 `phoneMask/phoneMd5/phoneAes`，断言 `AppCollectOrderOutput` 三个字段均被同步设置。

**验收场景**：

1. **Given** 地址记录包含 `phoneMask`、`phoneMd5`、`phoneAes`，**When** 调用订单分页接口，**Then** 返回 JSON 包含 `phoneMask`、`phoneMd5`、`phoneAes`。
2. **Given** 安全字段均为 `null` 的历史地址记录，**When** 调用订单分页接口，**Then** 三个安全字段返回 `null`，不影响其他订单字段返回。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `phoneMask`：来源 `RealGoodsAddressRecordDO.phoneMask`；赋值时机为 `assembleAddressRecordOutputs` 设置物流信息时。
  - `phoneMd5`：来源 `RealGoodsAddressRecordDO.phoneMd5`；赋值时机同上。
  - `phoneAes`：来源 `RealGoodsAddressRecordDO.phoneAes`；赋值时机同上。
  - `phone`（idc-app）：来源 `RealGoodsAddressRecordDO.phoneAes`；赋值时机同上。
  - `phone`（lms）：来源 `DataSecurityInvoke.phoneMaskForDisplay(addressRecord.getPhoneMask(), addressRecord.getPhoneAes())`；赋值时机同上。
- 下游读取字段清单：
  - idc-app 前端读取 `phone` 获取 `phoneAes`。
  - lms 前端读取 `phone` 展示掩码手机号。
  - 前端或后续受控链路可读取 `phoneMask/phoneMd5/phoneAes`。
- 空对象 / 占位对象风险：
  - `addressRecordMap` 为空或未命中当前订单时保持原行为，不设置物流手机号。
  - `phoneMask/phoneMd5/phoneAes` 为空时按空值返回，不构造占位字符串。
- 调用顺序风险：
  - 必须在地址记录查询完成后、返回页面数据前同步设置安全字段。
  - 不允许先返回明文 `phone` 再依赖后续流程覆盖。
- 旧逻辑保持：
  - Controller 路径、入参、分页条件、商品组装、物流单号 `lIds`、异常处理与容错逻辑保持不变。
  - 不新增数据库查询；沿用 MyBatis-Plus 查询实体字段。
  - 不新增 MQ、Redis、Feign、FC 或 HTTP 调用；lms 继续使用既有 `phoneMaskForDisplay` 工具方法。
- 需要用户确认的设计选择：无。用户已明确要求 idc-app 的 `phone` 字段单独返回 `phoneAes`。

## 边界情况

- 地址记录不存在：保持原行为，仅不设置 `lIds/phone/phoneMask/phoneMd5/phoneAes`。
- idc-app：`phoneAes` 有值时 `phone` 返回 `phoneAes`；`phoneAes` 为空时 `phone` 返回 `null`。
- lms：`phoneMask` 有值时 `phone` 直接使用 `phoneMask`，不触发解密。
- lms：`phoneMask` 为空、`phoneAes` 有值时，通过既有 `phoneMaskForDisplay` 现算掩码。
- lms：`phoneMask` 和 `phoneAes` 均为空时，`phone` 为 `null`。
- `phoneMd5` 为空：按空值返回，不影响展示。
- 同一 `collectOrderNo + goodsId` 有多条地址记录：保持现有 Map 覆盖行为，本次不改变选取规则。

## 需求

- **FR-001**：系统 MUST 在 `lms-common AppCollectOrderOutput` 增加 `phoneMask`、`phoneMd5`、`phoneAes` 字段。
- **FR-002**：系统 MUST 在 `kkhc-idc/app` 的 `AppCollectOrderFacade` 中让 `phone` 返回 `phoneAes`，并同步设置三类安全字段。
- **FR-003**：系统 MUST 在 `kkhc-idc/lms` 的 `AppCollectOrderFacade` 中让 `phone` 返回掩码值，并同步设置三类安全字段。
- **FR-004**：系统 MUST NOT 在 `AppCollectOrderFacade` 中继续使用 `addressRecord.getPhone()` 作为对外 `phone` 返回值。
- **FR-005**：系统 MUST 保持 `/app/collect/order/pageQuery` 的路径、入参、分页条件和其他订单字段不变。
- **FR-006**：实现后 MUST 通过静态检查或单元测试验证 app 的 `phone` 返回 `phoneAes`、lms 的 `phone` 返回掩码且安全字段被设置。

## 成功标准

- **SC-001**：`lms-common AppCollectOrderOutput` 编译后具备 `getPhoneMask/getPhoneMd5/getPhoneAes`。
- **SC-002**：两份 `AppCollectOrderFacade` 中不存在 `order.setPhone(addressRecord.getPhone())`。
- **SC-003**：idc-app 地址记录包含安全字段时，输出对象返回 `phone=phoneAes` 且三类安全字段完整。
- **SC-004**：lms 地址记录包含安全字段时，输出对象返回 `phone=phoneMask` 且三类安全字段完整。
- **SC-005**：目标模块 `base-common,lms-common,app,lms` 编译通过，或记录明确的环境阻塞原因。

## 假设

- `drh_real_address_record` 的 `phone_mask`、`phone_md5`、`phone_aes` 字段已存在。
- `RealGoodsAddressRecordDO` 两份 common 模块已包含 `phoneMask/phoneMd5/phoneAes`。
- JSON 字段名按现有 Jackson 配置输出；Java 字段采用驼峰命名。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已确认两个 Controller、两个 Facade、`lms-common AppCollectOrderOutput` 和 `RealGoodsAddressRecordDO` 的当前状态。
- 本阶段开始前未修改业务代码。

### D002 - 实现记录

- 实现内容：
  - `lms-common AppCollectOrderOutput` 增加 `phoneMask/phoneMd5/phoneAes`。
  - `kkhc-idc/app AppCollectOrderFacade` 设置 `phoneMask/phoneMd5/phoneAes`，并按用户补充口径让 `phone` 返回 `phoneAes`。
  - `kkhc-idc/lms AppCollectOrderFacade` 设置 `phoneMask/phoneMd5/phoneAes`，并让 `phone` 继续返回掩码值。
  - app/lms 分别新增 `AppCollectOrderFacadeTest` 覆盖对应 `phone` 返回口径和安全字段透传。
- 测试命令：
  - `mvn -f C:\workspace\ju-chat\kkhc\kkhc-idc\pom.xml -pl base-common,lms-common,app,lms -am "-DskipTests" compile`
  - 手动 JDK 8 `javac` 编译 app/lms 两份 `AppCollectOrderFacade` 和对应测试到临时目录。
  - 手动 JDK 8 `JUnitCore com.kkhc.idc.lms.facade.order.app.AppCollectOrderFacadeTest`（app、lms 各一次）。
- 测试结果：
  - 静态检查通过：app Facade 返回 `addressRecord.getPhoneAes()`，lms Facade 返回 `DataSecurityInvoke.phoneMaskForDisplay(...)`，两份 Facade 均未直接返回 `addressRecord.getPhone()`。
  - app 轻量 JUnit：2 tests OK。
  - lms 轻量 JUnit：2 tests OK。
  - Maven JDK 17 全量目标编译失败于既有 `lms-common` 风险类引用 `jdk.nashorn.internal.objects.annotations.Property`。
  - Maven JDK 8 全量目标编译超过工具超时时间，未取得完整 reactor 成功结果。
- 自检结论：本次改动的目标类和测试已通过局部编译与单元验证；全量 Maven 需在项目常规 JDK/CI 环境补跑。

### D003 - idc-app phone 返回 phoneAes 纠正

- 触发原因：用户补充要求 `idc-app` 的 `AppCollectOrderController` 这个接口单独处理，`phone` 字段返回 `phoneAes`；以往其他接口返回 `phoneMask`。
- 修正内容：旧口径为 app/lms 两份 Facade 都返回掩码；新口径为 `kkhc-idc/app` 返回 `phoneAes`，`kkhc-idc/lms` 继续返回掩码。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 验证结果：静态搜索确认 app 不再调用 `phoneMaskForDisplay`，lms 仍调用；app/lms 轻量 JUnit 均通过 2 个测试。

### D004 - 纠正记录模板

- 触发原因：`用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题`
- 修正内容：`说明具体修正`
- 文档同步：`说明同步了哪些文件`
- 验证结果：`说明测试或静态验证`
