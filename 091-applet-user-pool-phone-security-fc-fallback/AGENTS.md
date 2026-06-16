# 规格执行说明

本目录记录 `AppletUserPoolServiceImpl.getPageList` 客服公海分页返回手机号掩码的补充整改：`phone_mask` 为空时用 `phone` 调用函数计算补算掩码和 `phone_aes`，且不再校验手机号合理性。

## 作用范围

- 规格目录：`C:\workspace\ju-chat\specs\091-applet-user-pool-phone-security-fc-fallback`
- 目标项目：`C:\workspace\drh\drh-kk-cms`
- 相关模块/服务：`com.drh.kk.cms.service.impl.AppletUserPoolServiceImpl`
- 函数计算依赖：`com.drh.common.fc.datasec.DataSecurityInvoke`（服务 `DataSecurity` / 函数 `DataSecurity-pro`）

## 目标接口

- 客服公海广告用户分页列表（`AppletUserPoolService.getPageList`，返回 `Page<PoolAdListOutput>`）。

## 当前目标

- `phone_mask` 有值时，`phone` 仍直接返回掩码值（保持现状）。
- `phone_mask` 为空但 `phone` 有值时，用 `phone` 调用函数计算补算掩码、`phone_md5`、`phone_aes`，对外 `phone` 返回函数计算补算出的掩码。
- 调用函数计算补算时不校验手机号合理性，`+61432563303`、`15781266352-1781` 等非标准格式必须能正常加密处理。

## 重点代码位置

- 入口/核心：`C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\AppletUserPoolServiceImpl.java`（`getPageList` 中 `records.forEach` 末尾原 `e.setPhone(e.getPhoneMask());`）
- 数据来源：`C:\workspace\drh\drh-kk-cms\src\main\resources\mapper\AppletUserPoolMapper.xml`（`selectPoolPage` 返回 `phone/phoneMask/phoneMd5/phoneAes`）
- 输出对象：`C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\dto\output\PoolAdListOutput.java`
- 函数计算工具：`C:\workspace\drh\drh-common\src\main\java\com\drh\common\fc\datasec\DataSecurityInvoke.java`（`buildPhoneSecurity(String)`）
- 同类既有写法参考：`C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\OrderRefundRecordServiceImpl.java`（`buildPhoneSecurity` → set mask/md5/aes）、`AdUserPicServiceImpl.java`（phone 统一返回掩码）

## 执行原则

- 先读代码，再定方案，后实现；本次仅替换 `getPageList` 中 `e.setPhone(e.getPhoneMask());` 这一行的赋值逻辑，不改动其他装配。
- `phone/phoneMask/phoneMd5/phoneAes` 均来自 `selectPoolPage` 查询结果，必须沿用，不新增数据库查询、不改 SQL。
- 函数计算补算调用 `DataSecurityInvoke.buildPhoneSecurity(phone)`，不在 Java 侧增加 `isPlainPhone`/`isWritablePhoneInput` 等手机号格式校验。
- 函数计算返回为空或掩码为空时，对外 `phone` 返回 `null`，禁止回退返回明文 `phone`（保持手机号安全整改不泄露明文的不变量）。
- 不改变接口路径、分页入参、权限过滤（`getPermissionList`）、`phoneChannelSet` 渠道价格 key（仍用原始 `phone`）、其他字段装配顺序与异常行为。

## 强制门禁（实现前必须完成并记录在 tasks.md / checklists）

- 参数来源：`phone/phoneMask/phoneMd5/phoneAes` 来自 `selectPoolPage`；函数计算补算结果来自 `buildPhoneSecurity`。
- 赋值时机：补算与赋值发生在 `records.forEach` 末尾、`phoneChannelSet` 渠道价格 key 已用原始 `phone` 取值之后，不影响渠道价格。
- 占位对象：不引入空 DTO；函数计算返回为空按 `null` 兜底，不构造占位手机号。
- 下游读取：前端读取 `phone` 展示掩码，读取 `phoneAes` 发起受控解密；三类安全字段在补算分支同步赋值。
- 旧逻辑保持：`phone_mask` 有值的主路径行为不变；权限、分页、其他字段、异常处理保持不变。
- 影响范围：本次新增一次函数计算（FC）远程调用，仅在 `phone_mask` 为空的兜底分支触发；已与用户确认采用逐条内联调用。
- 测试映射：以静态验证 + 目标模块编译为主，断言函数计算入参为原始 `phone`、补算后 `phone=掩码`、补算失败 `phone=null`。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正或补充需求，追加 Dxxx 执行记录并同步 `spec.md`、`tasks.md`、`AGENTS.md`、checklist。
