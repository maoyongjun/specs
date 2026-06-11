# 功能规格：OrderGoodReissueDetailOutput 手机号安全字段补齐

**功能目录**：`078-phone-security-order-good-reissue-output`  
**创建日期**：`2026-06-11`  
**状态**：Implemented  
**输入**：之前手机号加密改造中，`OrderGoodReissueDetailOutput` 缺少改动，需要检查并补齐 Spec Kit 文档和最小代码修复。

## 背景

- 当前问题：`kkhc-bizcenter/product-common` 的 `OrderGoodReissueDetailOutput` 仍只有 `phone`，缺少 `phoneMask`、`phoneMd5`、`phoneAes`。
- 当前行为：上游 `LmsOrderGoodReissueDetailOutput` 在 `lms-common` 和 `ai-common` 已有安全字段，但 bizcenter 输出 DTO 无同名字段，MapStruct 无法把字段透传给 `pageDetailQuery` 和 `view/detailList` 调用方。
- 目标行为：`OrderGoodReissueDetailOutput` 补齐安全字段，converter 通过显式兼容映射透传字段，调用方可优先展示 `phoneMask`。
- 非目标：不删除或改写现有 `phone` 字段；不修改 DDL、查询逻辑、Feign 契约、ERP 发货链路、MQ、Redis 或 FC 行为。

## 用户场景与测试

### 用户故事 1 - 补发详情返回安全手机号字段（优先级：P1）

运营或后端调用补发详情分页和详情接口时，bizcenter 输出对象应包含掩码、摘要和密文字段，避免只能依赖明文 `phone`。

**独立测试**：编译 `product-common` 和 `product` 模块，静态确认 DTO 字段存在，并确认 MapStruct 转换链路可生成且包含安全字段映射。

**验收场景**：

1. **Given** 上游 `LmsOrderGoodReissueDetailOutput` 带有 `phoneMask/phoneMd5/phoneAes`，**When** bizcenter 执行 `pageDetailQuery`，**Then** 返回 `OrderGoodReissueDetailOutput` 记录包含同名字段。
2. **Given** 上游 `LmsOrderBookReissueOutput.detailList` 中的明细带有安全字段，**When** bizcenter 执行 `view(id)`，**Then** 返回的 `detailList` 明细包含同名字段。

### 用户故事 2 - 发货链路保持兼容（优先级：P1）

ERP 发货仍需要收件人手机号，补齐展示字段不能把内部发货链路改成掩码手机号。

**独立测试**：静态确认 `OrderBookReissueErpServiceImpl.createOrderReq(...)` 仍读取 `OrderGoodReissueDetailOutput.getPhone()`。

**验收场景**：

1. **Given** 补发单进入 ERP 上传，**When** 创建 `OrderReq`，**Then** `receiver_phone` 和 `receiver_mobile` 仍来自原 `phone` 字段。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `phoneMask`：来源 `LmsOrderGoodReissueDetailOutput.phoneMask`；赋值时机为 Feign 返回后经 converter 显式兼容映射；下游读取位置为 `pageDetailQuery` 返回记录和 `view/detailList`。
  - `phoneMd5`：来源 `LmsOrderGoodReissueDetailOutput.phoneMd5`；赋值时机为 Feign 返回后经 converter 显式兼容映射；用于调用方安全识别，不改变本次查询逻辑。
  - `phoneAes`：来源 `LmsOrderGoodReissueDetailOutput.phoneAes`；赋值时机为 Feign 返回后经 converter 显式兼容映射；用于后续解密或权限链路，本次不新增解密接口。
- 下游读取字段清单：
  - `OrderBookReissueServiceImpl.pageDetailQuery` 返回 `Page<OrderGoodReissueDetailOutput>.records`。
  - `OrderBookReissueServiceImpl.view` 返回 `OrderBookReissueOutput.detailList`。
  - `OrderBookReissueErpServiceImpl.createOrderReq` 读取 `phone`，必须保持不变。
- 空对象 / 占位对象风险：
  - 未发现新增空 DTO、空 JSON、空 Map 或只 set 部分字段后继续下传的需求；本次只增加 DTO 字段。
- 调用顺序风险：
  - 无调用后才赋值风险；字段来自上游 Feign 响应，并在转换时同步赋值。
- 旧逻辑保持：
  - 分页、详情、商品信息补充、地址解析、ERP 上传、异常处理、日志、Feign 调用和接口路径保持不变。
- 需要用户确认的设计选择：
  - 无。本次采用最小兼容补字段方案，不改变业务语义。

## 边界情况

- 上游安全字段为空时，bizcenter 输出同名字段为空，不在本层补算或调用解密服务。
- `phone` 字段继续保留，避免 ERP 下单、地址处理或历史调用方出现兼容问题。
- MapStruct 编译已确认未自动映射同名字段，converter 使用显式兼容映射读取 getter 或同名字段。
- 不处理前端展示切换；调用方应优先使用 `phoneMask` 的要求在本规格中记录。

## 需求

### 功能需求

- **FR-001**：系统 MUST 在 `OrderGoodReissueDetailOutput` 增加 `phoneMask`、`phoneMd5`、`phoneAes` 字段。
- **FR-002**：系统 MUST 保证 `LmsOrderGoodReissueDetailOutput` 到 `OrderGoodReissueDetailOutput` 的转换可编译，安全字段可通过显式兼容映射透传。
- **FR-003**：系统 MUST NOT 删除、改名或将现有 `phone` 字段改为掩码值。
- **FR-004**：系统 MUST NOT 修改 DDL、查询条件、Feign 方法签名、ERP 下单手机号读取、MQ、Redis 或 FC 行为。
- **FR-005**：验证 MUST 覆盖字段存在、转换链路编译、分页/详情返回路径和 ERP `getPhone()` 不回归。

## 成功标准

- **SC-001**：`OrderGoodReissueDetailOutput.java` 中存在 `phoneMask`、`phoneMd5`、`phoneAes` 三个字段。
- **SC-002**：目标 Maven 编译能确认 Lombok/MapStruct 不因新增字段失败，且不再报告 `phoneMask/phoneMd5/phoneAes` 未映射。
- **SC-003**：静态搜索确认 ERP 下单仍使用 `lmsDetailInput.getPhone()` 设置 `receiver_phone` 和 `receiver_mobile`。

## 假设

- `phoneMask/phoneMd5/phoneAes` 的生成和落库已由前序手机号安全改造在上游完成。
- 当前 bizcenter 依赖的 `lms-common` 编译产物未让 MapStruct 自动识别安全字段，因此 converter 使用显式兼容映射。
- 对外隐藏或清空 `phone` 属于更大接口契约变更，不纳入本次。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已记录 `OrderGoodReissueDetailOutput` 相比上游 `LmsOrderGoodReissueDetailOutput` 缺少安全字段的事实。
- 已明确本次不修改 DDL、Feign、查询逻辑或 ERP 发货链路。

### D002 - 实现记录

- 实现内容：为 `OrderGoodReissueDetailOutput` 补齐 `phoneMask`、`phoneMd5`、`phoneAes` 字段；为 `OrderBookReissueConverter.convert(LmsOrderGoodReissueDetailOutput)` 增加显式兼容映射。
- 测试命令：见 `tasks.md` D002。
- 测试结果：见 `tasks.md` D002。
- 自检结论：字段补齐为最小兼容修复，`phone` 仍保留给历史和发货链路。
