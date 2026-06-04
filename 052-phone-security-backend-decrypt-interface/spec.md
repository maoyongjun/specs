# 功能规格：手机号安全字段后台解密接口

**功能目录**：`052-phone-security-backend-decrypt-interface`  
**创建日期**：`2026-06-04`  
**状态**：Implemented（局部验证通过；全量 Maven 受本机环境限制未完成）  
**输入**：在 `C:\workspace\ju-chat\specs` 创建文档，并在 `C:\workspace\drh\drh-kk-cms` 增加解密接口，调用函数计算，完成后端解密。

## 背景

- 当前问题：手机号安全改造后，CMS 多处只返回 `phone_mask`，但后台在受控场景下需要根据 `phone_aes` 获取明文手机号。
- 当前行为：`drh-common` 已提供 `DataSecurityInvoke.decryptPhoneAes(String)`，内部使用 `businessType=2`、`dataType=1` 调用 `DataSecurity` 函数计算，失败时再尝试本地 AES 兜底；`drh-kk-cms` 尚未暴露统一后端解密接口。
- 目标行为：CMS 提供登录态保护下的解密接口，接收 `phoneAes`，由后端调用函数计算解密，返回明文 `phone`。
- 非目标：不新增数据库字段，不修改已有查询/保存/掩码展示逻辑，不在日志中输出明文手机号，不实现前端页面。

## 用户场景与测试

### 用户故事 1 - 后台按密文字段解密手机号（优先级：P1）

后台页面或联调人员拿到数据库返回的 `phoneAes` 后，可以调用 CMS 后端接口获取明文手机号。

**独立测试**：构造 `PhoneDecryptInput.phoneAes`，验证 Service 将原始密文传递给 FC client，并返回 client 解密结果。

**验收场景**：

1. **Given** 请求体包含有效 `phoneAes`，**When** 调用 `POST /phone/security/decrypt`，**Then** 后端调用 `DataSecurityInvoke.decryptPhoneAes(phoneAes)` 并返回 `{"phone":"明文手机号"}`。
2. **Given** 请求体为空或 `phoneAes` 为空，**When** 调用解密接口，**Then** 返回业务异常，不调用 FC。
3. **Given** FC 和本地兜底均未解出手机号，**When** 调用解密接口，**Then** 返回业务异常，不返回空字符串。

### 用户故事 2 - 不回归现有手机号安全链路（优先级：P1）

新增解密接口不能影响现有 `phone_md5` 查询、`phone_mask` 展示和安全字段写入链路。

**独立测试**：静态验证本次仅新增 Controller、Service、DTO、FC client 和测试文件，不改动 Mapper、实体、数据库脚本或旧接口。

**验收场景**：

1. **Given** 现有 `/user/phone/user`、`/user/selectPhone` 等接口，**When** 新增解密接口后重新编译，**Then** 原有接口代码和 SQL 不发生变更。

## 接口契约

- 请求路径：`POST /phone/security/decrypt`
- 请求体：

```json
{
  "phoneAes": "手机号AES密文"
}
```

- 响应体：

```json
{
  "phone": "13812345678"
}
```

- 权限边界：接口不加入拦截器白名单，沿用现有 `TokenInterceptor` 登录态校验。
- 日志边界：接口和 Service 不记录明文手机号。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `phoneAes`：来源 `PhoneDecryptInput.phoneAes`；赋值时机为请求反序列化完成后；下游读取位置为 `PhoneSecurityServiceImpl.decrypt`。
  - `phone`：来源 `PhoneSecurityFcClient.decryptPhoneAes(phoneAes)`；赋值时机为 FC client 返回后；下游读取位置为 `PhoneDecryptOutput.phone`。
- 下游读取字段清单：
  - `PhoneSecurityServiceImpl.decrypt` 读取 `input.phoneAes`。
  - `DataSecurityPhoneSecurityFcClient.decryptPhoneAes` 读取 `phoneAes` 并传入 `DataSecurityInvoke.decryptPhoneAes`。
- 空对象 / 占位对象风险：
  - 请求体可能为空，Service 必须在下传 FC 前拦截。
  - `phoneAes` 可能为空字符串，Service 必须在下传 FC 前拦截。
- 调用顺序风险：
  - 必须先校验入参，再调用 FC client，再构造输出 DTO。
  - 不存在调用后才赋值或异步后才赋值。
- 旧逻辑保持：
  - 保持 `DataSecurityInvoke.decryptPhoneAes` 的 FC + 本地 AES 兜底逻辑。
  - 不修改现有 Controller、Service、Mapper、实体和数据库字段。
  - 不新增 MQ、Redis 或外部 HTTP 调用。
- 需要用户确认的设计选择：
  - 本次按用户明确要求新增统一后台 API；未额外增加按钮级权限和审计表。若生产需要可追补。

## 边界情况

- 请求体为空：抛出 `BaseException(ApiStatus.HAND_FAILE, "手机号密文不能为空")`。
- `phoneAes` 为空：同上。
- FC 调用失败但本地 AES 兜底成功：返回兜底解密结果，沿用 `DataSecurityInvoke` 现有行为。
- FC 和本地 AES 均失败：抛出 `BaseException(ApiStatus.HAND_FAILE, "手机号解密失败")`。
- 明文日志：禁止输出。
- 并发：接口无共享可变状态，不涉及数据库写入。

## 需求

### 功能需求

- **FR-001**：系统 MUST 新增 `POST /phone/security/decrypt` 接口。
- **FR-002**：系统 MUST 从请求体读取 `phoneAes`，不得从 URL query 中读取密文。
- **FR-003**：系统 MUST 通过 `DataSecurityInvoke.decryptPhoneAes` 调用函数计算链路完成解密。
- **FR-004**：系统 MUST 在空入参或解密失败时抛业务异常。
- **FR-005**：系统 MUST NOT 输出明文手机号日志。
- **FR-006**：单元测试 MUST 覆盖正常路径、空入参、解密失败，并断言 FC client 接收的密文参数。

## 成功标准

- **SC-001**：`PhoneSecurityServiceImplTest` 覆盖正常、空入参、解密失败三类路径。
- **SC-002**：新增主类通过 JDK 8 `javac` 局部编译，新增单元测试通过 JUnitCore 运行。
- **SC-003**：代码搜索确认未修改旧查询、旧保存、旧掩码展示链路；全量 Maven 编译需在可用 Java 8 / Lombok 环境补跑。

## 假设

- `phoneAes` 是手机号 AES 密文，解密数据类型沿用 `DataSecurityInvoke.decryptPhoneAes` 的 `dataType=1`。
- 登录态校验由现有 `TokenInterceptor` 统一处理。
- 前端会通过请求体 POST 调用该接口。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成接口契约、参数来源、调用顺序、旧逻辑保持和测试映射记录。

### D002 - 实现记录

- 实现内容：新增 `PhoneSecurityController`、`PhoneSecurityService`、`PhoneSecurityServiceImpl`、`PhoneSecurityFcClient`、`DataSecurityPhoneSecurityFcClient`、`PhoneDecryptInput`、`PhoneDecryptOutput`。
- FC 口径：`DataSecurityPhoneSecurityFcClient` 直接调用 `DataSecurityInvoke.decryptPhoneAes(phoneAes)`。
- 测试内容：新增 `PhoneSecurityServiceImplTest`，用 fake FC client 断言密文参数传递，覆盖空入参和解密失败。
- 验证结果：JDK 8 局部 `javac` 编译新增主类通过；`JUnitCore PhoneSecurityServiceImplTest` 通过 3 个测试。全量 Maven 在 JDK 17 下因旧版 Lombok 模块访问失败，在 JDK 8 下超过 5 分钟未返回，需在常规 CI/IDE 编译环境补跑。

### D003 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态验证结果>`。
