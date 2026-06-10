# 规格执行说明

本目录记录 `LiveCampGroup` 学员订单手机号安全字段补遗。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\068-livecamp-stu-order-phone-security-gap`
- 目标项目：`C:\workspace\drh`
- 相关模块：`drh-common`、`drh-kk-cms`

## 当前目标

- 补齐 `GET /liveCampGroup/stu/orderInfo` 响应中的 `phoneMask/phoneMd5/phoneAes`。
- 同步补齐订单列表、订单详情和收货人手机号安全字段。
- 修复 `POST /liveCampGroup/live/detail` 中 `GroupLiveDetailOutput.phone` 明文返回。

## 执行原则

- CMS 后台 `phone` 和 `receiverPhone` 字段返回脱敏展示值。
- `phoneMask/phoneMd5/phoneAes` 必须来自 `LiveUser`，`receiverPhone*` 必须来自 `RealGoodsAddressRecord`。
- 不新增数据库字段，不改查询条件，不改 MQ/Redis/Feign/FC 契约。
- `065` app 订单接口 `phone=phoneAes` 是特例，不套用到本规格。
- 剩余 `phone LIKE` 搜索候选只登记，不在本规格擅自改为 MD5 精确查询。

## 强制门禁

实现和验证必须确认：

- 返回前已设置所有新增安全字段。
- 不存在把 `LiveUser.phone` 明文直接写入 `GroupLiveDetailOutput.phone`。
- 收货人手机号展示仍使用 `DataSecurityInvoke.phoneMaskForDisplay()`。
- 单元测试避免真实访问 Redis、OTS、RocketMQ、FC 或外部 HTTP。

## 重点代码位置

- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\controller\LiveCampGroupController.java`
- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\CollectOrderServiceImp.java`
- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\LiveCampGroupServiceImpl.java`
- `C:\workspace\drh\drh-kk-cms\src\test\java\com\drh\kk\cms\service\impl`

## 文档维护

- `spec.md` 描述需求、边界、相似漏改检查和成功标准。
- `tasks.md` 记录事实确认、实现任务、测试验证和执行记录。
- `checklists/requirements.md` 用于验证规格质量和实施就绪度。
- 如测试发现新的同类漏点，先追加 Dxxx 记录，再调整实现范围。
