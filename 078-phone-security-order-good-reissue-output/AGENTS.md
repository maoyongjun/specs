# 规格执行说明

本目录记录 `kkhc-bizcenter` 商品补发/增发详情输出 DTO 的手机号安全字段补齐。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\078-phone-security-order-good-reissue-output`
- 目标项目：`C:\workspace\ju-chat\kkhc\kkhc-bizcenter`
- 目标模块：
  - `product-common`
  - `product`
- 核心实现：
  - `com.kkhc.bizcenter.product.common.dto.output.order.fulfillment.reissue.OrderGoodReissueDetailOutput`
  - `com.drh.bizcenter.product.mapstruct.order.fulfillment.reissue.OrderBookReissueConverter`
  - `com.drh.bizcenter.product.service.order.fulfillment.reissue.impl.OrderBookReissueServiceImpl`

## 当前目标

- 补齐 `OrderGoodReissueDetailOutput` 缺失的 `phoneMask`、`phoneMd5`、`phoneAes` 字段。
- 保证 `LmsOrderGoodReissueDetailOutput` 经 MapStruct 转换后，安全字段能在 `pageDetailQuery` 和 `view/detailList` 返回路径中透传。
- 保持现有 `phone` 字段兼容，不改变 ERP 发货、地址解析、Feign、数据库、MQ、Redis 或 FC 行为。

## 执行原则

- 本次只补 bizcenter 输出 DTO 字段和对应文档，不扩大到上游 LMS/AI common，它们已具备同名安全字段。
- `phone` 字段不得删除、改名或改成掩码字段；内部 ERP 下单仍依赖 `getPhone()` 设置收件电话。
- 页面和调用方展示手机号时应优先使用 `phoneMask`，但本次不改前端和不新增解密接口。
- 不新增数据库表、字段、索引，不修改接口路径、Feign 方法签名或外部调用契约。
- 编译发现 MapStruct 未自动映射同名字段时，使用兼容显式映射补齐，不改变现有 converter 方法签名。

## 强制门禁

- 参数来源：`phoneMask/phoneMd5/phoneAes` 来自上游 `LmsOrderGoodReissueDetailOutput`。
- 赋值时机：bizcenter 调用 Feign 获取 LMS 输出后，通过 `OrderBookReissueConverter.convert(...)` 的显式兼容映射赋值。
- 下游读取：页面查询读取 `Page<OrderGoodReissueDetailOutput>.records`；查看详情读取 `OrderBookReissueOutput.detailList`；ERP 下单读取原 `phone`。
- 旧逻辑保持：分页、详情、地址解析、ERP 上传、商品信息补充、异常处理和日志行为保持不变。
- 测试映射：实现后必须做字段静态检查、MapStruct 编译验证和 ERP `getPhone()` 不回归确认。

## 文档维护

- `spec.md` 描述需求、边界、成功标准、假设和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 验证规格质量、参数完整性和实施就绪度。
- 后续若改为对外隐藏 `phone` 或新增解密接口，必须另建规格或追加纠正记录。
