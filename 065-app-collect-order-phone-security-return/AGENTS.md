# 规格执行说明

本目录记录 `AppCollectOrderController` 订单分页返回手机号安全字段的补充整改。

## 作用范围

- 规格目录：`C:\workspace\ju-chat\specs\065-app-collect-order-phone-security-return`
- 目标模块：
  - `C:\workspace\ju-chat\kkhc\kkhc-idc\base-common`
  - `C:\workspace\ju-chat\kkhc\kkhc-idc\lms-common`
  - `C:\workspace\ju-chat\kkhc\kkhc-idc\app`
  - `C:\workspace\ju-chat\kkhc\kkhc-idc\lms`

## 目标接口

- `POST /app/collect/order/pageQuery`

## 重点代码位置

- `kkhc-idc\app\src\main\java\com\kkhc\idc\lms\controller\order\app\AppCollectOrderController.java`
- `kkhc-idc\lms\src\main\java\com\kkhc\idc\lms\controller\order\app\AppCollectOrderController.java`
- `kkhc-idc\app\src\main\java\com\kkhc\idc\lms\facade\order\app\AppCollectOrderFacade.java`
- `kkhc-idc\lms\src\main\java\com\kkhc\idc\lms\facade\order\app\AppCollectOrderFacade.java`
- `kkhc-idc\lms-common\src\main\java\com\kkhc\idc\lms\common\module\output\order\app\AppCollectOrderOutput.java`
- `kkhc-idc\lms-common\src\main\java\com\kkhc\idc\lms\common\module\dao\order\fulfillment\address\RealGoodsAddressRecordDO.java`

## 执行原则

- `kkhc-idc/app` 的 `phone` 对外返回必须是 `RealGoodsAddressRecordDO.phoneAes`，这是本接口特例。
- `kkhc-idc/lms` 的 `phone` 对外返回必须是掩码值，不能直接返回 `RealGoodsAddressRecordDO.phone`。
- `phoneMask/phoneMd5/phoneAes` 必须来源于 `RealGoodsAddressRecordDO` 查询结果。
- lms 中 `phoneMask` 有值时优先返回；`phoneMask` 为空但 `phoneAes` 有值时使用既有 `DataSecurityInvoke.phoneMaskForDisplay`。
- app 与 lms 两份 Facade 必须都返回三类安全字段，但 `phone` 字段返回口径不同。
- 不改变 Controller 路径、分页入参、主订单查询条件、商品组装、物流单号返回、异常容错和数据库结构。

## 文档维护

- 补充需求或纠正需求时，同步更新 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 实现后必须记录测试命令、测试结果和剩余风险。
