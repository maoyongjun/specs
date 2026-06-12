# 规格执行说明

本目录记录 `080-phone-security-order-page-product`，作用范围包含：

- 规格文档：`C:\workspace\ju-chat\specs\080-phone-security-order-page-product`
- 目标项目：`C:\workspace\ju-chat\kkhc`
- 相关模块：`kkhc-bizcenter/product`、`kkhc-idc/lms-common`、`kkhc-idc/app`、`kkhc-idc/lms`、`kkhc-idc/ai`

## 当前目标

- 修复 `com.drh.bizcenter.product.controller.order.OrderController#getOrderPage` 手机号安全改造遗漏。
- 补齐 `OrderPageOutput` 在 `lms-common` 的安全字段，并让上游 app/lms/ai 同步赋值。
- 检查同类 DTO 字段遗漏，补齐 `LmsRealGoodsAddressRecordOutput` 安全字段。

## 执行原则

- 先确认 DTO 所属 common 模块，避免只改 ai-common 或只改 lms-common。
- product 侧需要兼容已发布的旧 `lms-common`，不要直接依赖新 getter 或 `kkhc-idc` 的数据安全工具才能编译。
- `phone` 默认展示要来自 `phoneMask/phoneAes`，但发货、ERP、补发明细创建链路需要明文的旧行为不得在本规格中改变。
- 不修改查询 SQL、分页条件、接口路径、Feign 路径、DDL 或历史回填。

## 强制门禁

- 参数来源：`OrderPageOutput.phone*` 来自 `LiveUserDO.phone*`。
- 赋值时机：上游组装记录时赋值，product 返回前兜底。
- 占位对象：空页不构造占位记录。
- 下游读取：product 优先读 `phoneMask` 并覆盖展示 `phone`，旧依赖只返回 11 位明文时本地掩码；地址记录 `phone` 仍可能被补发链路读取。
- 旧逻辑保持：订单分页校验、查询、状态和金额处理不变；地址记录 `phone` 旧语义不变。
- 测试映射：字段存在、赋值语句、无相似 DTO 漏项、编译或静态检查。

## 重点代码位置

- `C:\workspace\ju-chat\kkhc\kkhc-bizcenter\product\src\main\java\com\drh\bizcenter\product\controller\order\OrderController.java`
- `C:\workspace\ju-chat\kkhc\kkhc-bizcenter\product\src\main\java\com\drh\bizcenter\product\service\order\impl\OrderServiceImpl.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\lms-common\src\main\java\com\kkhc\idc\lms\common\module\output\order\OrderPageOutput.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\lms-common\src\main\java\com\kkhc\idc\lms\common\module\output\order\fulfillment\address\LmsRealGoodsAddressRecordOutput.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\app\src\main\java\com\kkhc\idc\lms\facade\order\OrderPageProcessorDataFacade.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\lms\src\main\java\com\kkhc\idc\lms\facade\order\OrderPageProcessorDataFacade.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\lms\facade\order\OrderPageProcessorDataFacade.java`

## 文档维护

- `spec.md` 描述需求、边界、成功标准和执行记录。
- `tasks.md` 记录事实确认、实现任务、验证结果和后续纠正。
- `checklists/requirements.md` 验证规格质量和实施就绪度。
