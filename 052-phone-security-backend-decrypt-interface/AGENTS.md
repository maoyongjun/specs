# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\052-phone-security-backend-decrypt-interface`
- 目标项目：`C:\workspace\drh\drh-kk-cms`
- 相关模块：CMS 后台手机号安全字段解密接口

## 当前目标

- 新增后台解密接口，输入 `phoneAes`，输出解密后的明文手机号。
- 解密必须通过 `DataSecurityInvoke.decryptPhoneAes` 调用函数计算链路完成，保留其本地 AES 兜底逻辑。
- 接口不得记录明文手机号，不修改数据库，不影响现有查询和展示脱敏逻辑。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许绕过 `DataSecurityInvoke` 直接复制 AES 密钥或自写解密逻辑。
- 新接口必须走现有 `TokenInterceptor` 登录校验；不新增白名单。
- 输入校验失败、解密失败必须返回业务异常，不返回空手机号给前端。
- 单元测试只验证服务层参数传递和异常路径，不真实访问 FC。

## 强制门禁

- 参数来源：`phoneAes` 来自接口请求体 `PhoneDecryptInput.phoneAes`。
- 赋值时机：Controller 接收请求后立即传入 Service；Service 校验后同步传给 FC client。
- 占位对象：不存在空 JSON、空 Map 或部分字段 DTO 继续下传。
- 下游读取：下游仅读取 `phoneAes` 字符串。
- 旧逻辑保持：不修改原有 `DataSecurityInvoke`、不修改旧接口、不修改数据库字段。
- 影响范围：新增 REST API、Service、FC client、DTO 和单元测试。

## 重点代码位置

- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\controller\PhoneSecurityController.java`
- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\PhoneSecurityServiceImpl.java`
- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\DataSecurityPhoneSecurityFcClient.java`
- `C:\workspace\drh\drh-kk-cms\src\test\java\com\drh\kk\cms\service\impl\PhoneSecurityServiceImplTest.java`

## 文档维护

- `spec.md` 描述接口契约、用户场景、边界和验收标准。
- `tasks.md` 记录事实确认、风险门禁、实现任务和验证结果。
- `checklists/requirements.md` 验证规格质量和实施就绪度。
