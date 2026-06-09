# 规格执行说明

本目录记录 `kkhc-idc/lms` 批量导入收货地址链路的手机号安全字段补充整改。

## 作用范围

- 规格目录：`C:\workspace\ju-chat\specs\063-lms-import-address-phone-security`
- 目标模块：
  - `C:\workspace\ju-chat\kkhc\kkhc-idc\base-common`
  - `C:\workspace\ju-chat\kkhc\kkhc-idc\lms-common`
  - `C:\workspace\ju-chat\kkhc\kkhc-idc\lms`
  - `C:\workspace\ju-chat\data-RC\juzi-service`

## 目标接口

- `GET /collect/order/import/address`
- `GET /collect/order/download/address/failList`
- `GET /collect/order/import/address/sure`
- `POST /collect/order/import/address/detail`
- `GET /collect/order/import/address/job`

## 非目标

- `POST /collect/order/getValidCollectOrders` 不含手机号，不改。
- `POST /collect/order/selectByCondition` 不含手机号，不改。
- 不新增 HTTP 路径，不改变 Feign 契约。
- 不清空原 `phone` 字段。

## 执行原则

- 导入明细、真实地址、学员手机号写入链路必须同步写 `phoneMask/phoneMd5/phoneAes`。
- 查询手机号必须使用 `phoneMd5` 精确匹配，支持明文、前端 AES 密文、32 位 MD5。
- 返回给前端和导出失败列表的 `phone` 必须是掩码值。
- ERP 上传是后端外部推送场景，仍允许使用明文手机号；读取时必须 `phone` 优先、`phoneAes` 解密兜底。
- 不在日志中打印整批导入明细或完整手机号。

## 重点代码位置

- `kkhc-idc\base-common\src\main\java\com\kkhc\common\utils\fc\datasec\DataSecurityInvoke.java`
- `kkhc-idc\lms-common\src\main\java\com\kkhc\idc\lms\common\module\dao\order\ImportAddressRecordDetail.java`
- `kkhc-idc\lms-common\src\main\java\com\kkhc\idc\lms\common\module\dao\order\fulfillment\address\RealGoodsAddressRecordDO.java`
- `kkhc-idc\lms-common\src\main\java\com\kkhc\idc\lms\common\module\dao\base\LiveUserDO.java`
- `kkhc-idc\lms\src\main\java\com\kkhc\idc\lms\service\order\impl\CollectOrderServiceImpl.java`
- `kkhc-idc\lms\src\main\java\com\kkhc\idc\lms\service\order\impl\ImportAddressRecordDetailServiceImpl.java`
- `data-RC\juzi-service\src\main\java\com\drh\data\juzi\phonesecurity\PhoneSecurityBackfillService.java`

## 文档维护

- 补充需求或纠正需求时，同步更新 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 实现后必须记录测试命令、测试结果和剩余风险。
