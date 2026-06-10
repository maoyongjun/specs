# 功能规格：LiveCampGroup 学员订单手机号安全补遗

**功能目录**：`068-livecamp-stu-order-phone-security-gap`  
**创建日期**：`2026-06-10`  
**状态**：Draft  
**输入**：修复 `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\controller\LiveCampGroupController.java` 的 `stuOrderInfo` 接口中手机号密文漏改问题，并检查是否有类似漏改。

## 背景

- 当前问题：`GET /liveCampGroup/stu/orderInfo` 返回 `CollectOrderOutput`，`phone` 已按掩码展示，但 DTO 没有返回 `phoneMask/phoneMd5/phoneAes`；同一订单链路的详情和收货信息也只有展示值。
- 当前行为：`CollectOrderServiceImp.collectOrderList()` 和 `collectOrderDetail()` 使用 `phoneMaskForDisplay()` 设置 `phone`，但未同步安全三字段；`AddressDetailDto.receiverPhone` 只有掩码展示；`POST /liveCampGroup/live/detail` 的 `GroupLiveDetailOutput` 仍直接使用 `LiveUser.phone` 明文。
- 目标行为：CMS 后台响应中 `phone`/`receiverPhone` 返回脱敏展示值，同时返回对应安全字段；相同 controller 内确认的明文响应同步修复。
- 非目标：不新增接口、不改数据库、不改 MQ/Redis/Feign/FC 契约；不改 `065` app 订单接口 `phone=phoneAes` 特例；不擅自把剩余 `phone LIKE` 搜索改为 MD5 精确查询。

## 用户场景与测试

### 用户故事 1 - 学员订单返回手机号安全字段（优先级：P1）

运营在学员详情查看订单信息时，接口应返回脱敏手机号和 `phoneMask/phoneMd5/phoneAes`，供前端展示和受控解密链路使用。

**独立测试**：构造 `LiveUser` 含安全字段，调用订单输出装配逻辑后断言 `phone` 为掩码，三类安全字段均返回。

**验收场景**：

1. **Given** `LiveUser.phoneMask/phoneMd5/phoneAes` 均有值，**When** 请求 `GET /liveCampGroup/stu/orderInfo`，**Then** 每条 `CollectOrderOutput.phone` 为脱敏值，且 `phoneMask/phoneMd5/phoneAes` 均有值。
2. **Given** 订单存在收货地址 `RealGoodsAddressRecord.phoneMask/phoneMd5/phoneAes`，**When** 返回 `addressDetailDtos`，**Then** `receiverPhone` 为脱敏值，且 `receiverPhoneMask/receiverPhoneMd5/receiverPhoneAes` 均有值。

### 用户故事 2 - 同链路详情和课程详情不再漏字段（优先级：P1）

同一订单输出链路和同一 controller 的学生详情响应不应继续返回明文或漏掉安全字段。

**独立测试**：构造 `CollectOrderDetailOutput` 和 `GroupLiveDetailOutput` 装配逻辑，断言手机号展示和安全字段一致。

**验收场景**：

1. **Given** 请求 `GET /collect/order/detail`，**When** 返回 `CollectOrderDetailOutput`，**Then** 用户手机号 `phone` 为掩码，且安全三字段完整。
2. **Given** 请求 `POST /liveCampGroup/live/detail`，**When** 返回 `GroupLiveDetailOutput`，**Then** 不再使用 `LiveUser.phone` 明文，返回 `phoneMask/phoneMd5/phoneAes`。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `CollectOrderOutput.phone*`：来源 `LiveUser.phoneMask/phoneMd5/phoneAes`；在 `collectOrderList()` 循环内已有 `LiveUser` 后立即赋值。
  - `CollectOrderDetailOutput.phone*`：来源 `liveUserService.getById(collectOrder.userId)`；在 `collectOrderDetail()` 返回前赋值。
  - `AddressDetailDto.receiverPhone*`：来源 `RealGoodsAddressRecord.phoneMask/phoneMd5/phoneAes`；在 `getAddressDetailDtos()` 当前层赋值。
  - `GroupLiveDetailOutput.phone*`：来源 `LiveUser.phoneMask/phoneMd5/phoneAes`；在 `liveStudentDetailV2()` 手动组装 DTO 时赋值。
- 下游读取字段清单：
  - `stu/orderInfo` 和 `collect/order/list` 读取 `CollectOrderOutput.phone/phoneMask/phoneMd5/phoneAes/addressDetailDtos`。
  - `collect/order/detail` 读取 `CollectOrderDetailOutput.phone/phoneMask/phoneMd5/phoneAes/addressDetailDtos`。
  - `liveCampGroup/live/detail` 读取 `GroupLiveDetailOutput.phone/phoneMask/phoneMd5/phoneAes`。
- 空对象 / 占位对象风险：
  - `liveUserMap.getOrDefault(..., new LiveUser())` 会产生空安全字段，按现有行为返回空展示值，不抛异常。
  - `collectOrderDetail()` 中 `LiveUser` 为空时不新增明文兜底。
- 调用顺序风险：
  - 安全字段必须在返回对象写出前赋值；不依赖前端、异步任务或历史回填补齐。
- 旧逻辑保持：
  - 保持原分页、权限、OTS 查询、订单状态、金额、商品、收货地址、企微标签和筛选逻辑不变。
  - `phoneMask` 为空但 `phoneAes` 有值时沿用 `DataSecurityInvoke.phoneMaskForDisplay()` 的既有兜底。
- 需要用户确认的设计选择：
  - 无。本轮只补字段和明文展示修正，不改搜索语义。

## 相似漏改检查

- 已确认并纳入本次修复：
  - `CollectOrderOutput`：`/liveCampGroup/stu/orderInfo` 与 `/collect/order/list` 共用，补三字段。
  - `CollectOrderDetailOutput`：`/collect/order/detail` 只有 `phone`，补三字段。
  - `AddressDetailDto`：订单列表/详情收货人手机号只有 `receiverPhone`，补 `receiverPhone*`。
  - `GroupLiveDetailOutput`：`/liveCampGroup/live/detail` 仍 `setPhone(liveUser.getPhone())`，改为掩码并补三字段。
- 登记但本次不改：
  - `DayUrgeClassMapper.xml`、`HandoverMapper.xml` 等仍存在 `phone LIKE` 搜索候选；这些会改变搜索语义，需单独规格确认后处理。

## 边界情况

- 安全字段为空：返回空或 `phoneMaskForDisplay()` 的既有结果，不回退明文。
- `phoneMask` 非空：直接返回 `phoneMask`，不访问 FC。
- `phoneMask` 空但 `phoneAes` 有值：沿用既有 `phoneMaskForDisplay()` 兜底。
- 收货地址不存在：`addressDetailDtos` 返回空列表。
- `LiveUser` 不存在：不构造明文手机号，不影响订单其他字段返回。

## 需求

### 功能需求

- **FR-001**：系统 MUST 为 `CollectOrderOutput` 增加并填充 `phoneMask/phoneMd5/phoneAes`。
- **FR-002**：系统 MUST 为 `CollectOrderDetailOutput` 增加并填充 `phoneMask/phoneMd5/phoneAes`。
- **FR-003**：系统 MUST 为 `AddressDetailDto` 增加并填充 `receiverPhoneMask/receiverPhoneMd5/receiverPhoneAes`。
- **FR-004**：系统 MUST 为 `GroupLiveDetailOutput` 增加并填充 `phoneMask/phoneMd5/phoneAes`，且 `phone` 不再来自明文 `LiveUser.phone`。
- **FR-005**：系统 MUST 保持 `phone` 和 `receiverPhone` 为 CMS 后台脱敏展示值。
- **FR-006**：系统 MUST NOT 新增数据库字段、修改查询条件、修改 Redis/MQ/Feign/FC 契约。
- **FR-007**：测试或静态验证 MUST 覆盖字段存在、字段赋值和明文赋值消除。

## 成功标准

- **SC-001**：`CollectOrderOutput`、`CollectOrderDetailOutput`、`AddressDetailDto`、`GroupLiveDetailOutput` 均包含计划列出的安全字段。
- **SC-002**：订单列表、学员订单、订单详情和课程详情响应装配时，手机号展示字段为掩码，安全字段来自对应实体。
- **SC-003**：静态搜索确认 `LiveCampGroupServiceImpl` 不再存在 `output.setPhone(liveUser.getPhone())` 响应赋值。
- **SC-004**：目标模块编译通过，新增或扩展单元测试通过；若环境阻塞，记录具体原因。

## 假设

- 用户所说“手机号密码”指手机号密文，即 `phoneAes`，并按既有口径同步补 `phoneMask/phoneMd5`。
- `drh_live_user` 与 `drh_real_address_record` 已具备安全字段，本次不做历史回填。
- `stu/orderInfo` 属于 CMS 后台接口，`phone` 字段返回脱敏手机号。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成历史问题防漏分析和相似漏改静态检查。
- 本阶段同步进入代码实现。

### D002 - 实现记录

- 实现内容：`待实现后填写。`
- 测试命令：`待实现后填写。`
- 测试结果：`待实现后填写。`
- 自检结论：`待实现后填写。`

### D003 - 纠正记录模板

- 触发原因：`用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题。`
- 修正内容：`写清楚旧口径和新口径。`
- 文档同步：`说明同步了哪些文件。`
- 验证结果：`说明测试或静态验证。`
