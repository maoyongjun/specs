# 功能规格：手机号安全字段查询返回与掩码入参校验

**功能目录**：`048-phone-security-query-return-save-mask-validate`  
**创建日期**：`2026-06-03`  
**状态**：In Progress  
**输入**：在 032-phone-security-columns（数据库字段添加）、036-phone-security-save-query（保存/查询/展示链路改造）、041-mybatisplus-xml-phone-md5-query（XML phone_md5 查询兼容）的基础上，进一步完善手机号安全字段的前端返回和保存入参校验。具体要求：查询结果需要返回 `phone_aes`、`phone_md5`、`phone_mask` 给前端；原来返回的 `phone` 字段改为返回 `phone_mask` 的值（掩码格式）；保存/更新接口增加校验，如果检测到输入的手机号是掩码格式（如 `138****5678`），不是明文格式，进行报错提示。涉及两个工程：`C:\workspace\drh`（主业务微服务）和 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai`（AI 模块）。

## 背景

- 当前问题：036/041 改造后，数据库目标表已具备 `phone_mask`、`phone_md5`、`phone_aes` 三个安全字段，保存链路已同步写入，查询链路已改用 `phone_md5` 等值匹配。但前端查询接口返回的 JSON 中仍只有 `phone` 字段（部分接口返回明文，部分接口做了代码层掩码），没有直接返回数据库中的 `phone_mask`、`phone_md5`、`phone_aes` 安全字段。同时，保存/更新接口对掩码格式手机号（如 `138****5678`）的拒绝缺少明确的错误提示。
- 当前行为：
  - 查询结果中 `phone` 字段来源不统一：部分接口返回明文，部分通过 `phoneMaskForDisplay()` 或内联掩码返回掩码值，部分 Output/DTO 直接透传实体 `phone` 字段。
  - 查询结果中不包含 `phone_aes`、`phone_md5`、`phone_mask` 三个安全字段，前端无法独立使用这些值。
  - 保存/更新链路中，`isWritablePhoneInput()` 已能识别并拒绝 MD5 格式，但掩码格式手机号（如 `138****5678`）虽然也会被拒绝（不满足 `isPlainPhone` 且不是有效 AES 密文），错误提示仍为通用的 `手机号加密格式不符`，未针对掩码格式给出更具体的提示。
- 目标行为：
  - 所有涉及手机号的查询接口返回结果中，`phone` 字段统一返回 `phone_mask` 的值（如 `138****5678`），不再返回明文。
  - 查询结果同时包含 `phone_aes`、`phone_md5`、`phone_mask` 三个安全字段，供前端按需使用。
  - 保存/更新接口检测到手机号为掩码格式时，返回明确的报错提示：`手机号为掩码格式，请输入明文手机号`。
- 非目标：本阶段只编写规格文档，不修改 Java、XML、SQL、测试代码；不改变已有的 `phone_md5` 查询逻辑和保存链路安全字段计算逻辑；不处理 `app_phone` 相关字段。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 查询结果返回安全字段（优先级：P1）

当运营或后台通过列表、详情、导出等查询接口获取含手机号的记录时，返回的 JSON 中必须包含 `phone_aes`、`phone_md5`、`phone_mask` 三个安全字段。

**独立测试**：调用任一含手机号的查询接口，检查返回 JSON 中是否同时存在 `phone`、`phone_aes`、`phone_md5`、`phone_mask` 四个字段。

**验收场景**：

1. **Given** 运营后台请求图书登记信息列表，**When** 接口返回数据，**Then** 每条记录的 JSON 中包含 `phone_mask`（如 `138****5678`）、`phone_md5`（32 位十六进制）、`phone_aes`（AES 密文）三个字段。
2. **Given** 运营后台请求学员详情或线索详情，**When** 接口返回数据，**Then** JSON 中同样包含三个安全字段。
3. **Given** 某条记录的 `phone_mask`、`phone_md5`、`phone_aes` 均为 NULL（历史数据未回填），**When** 查询返回，**Then** 三个安全字段返回 `null`，不抛异常。

### 用户故事 2 - phone 字段统一返回掩码值（优先级：P1）

所有查询接口返回的 `phone` 字段统一改为 `phone_mask` 的值，不再返回明文手机号。

**独立测试**：调用各查询接口，检查返回的 `phone` 字段值是否为掩码格式（如 `138****5678`），而非明文手机号。

**验收场景**：

1. **Given** 运营后台请求图书订单列表，**When** 接口返回数据，**Then** `phone` 字段值为 `138****5678` 格式，非明文 `13812345678`。
2. **Given** 导出功能导出含手机号的记录，**When** 导出数据，**Then** `phone` 列为掩码值。
3. **Given** 某条记录 `phone_mask` 为 NULL 但 `phone_aes` 有值，**When** 查询返回，**Then** `phone` 字段通过 `phone_aes` 解密后现算掩码返回，不为空。
4. **Given** 某条记录 `phone_mask` 和 `phone_aes` 均为 NULL，**When** 查询返回，**Then** `phone` 字段返回 `null` 或空字符串，不暴露明文。

### 用户故事 3 - 保存/更新拒绝掩码格式手机号（优先级：P1）

保存和更新接口检测到输入的手机号是掩码格式（包含 `****`，如 `138****5678`）时，返回明确的报错提示，不写入数据。

**独立测试**：保存/更新接口传入掩码格式手机号，检查返回的错误提示。

**验收场景**：

1. **Given** 保存接口传入掩码格式手机号 `138****5678`，**When** 校验手机号入参，**Then** 返回参数错误并提示 `手机号为掩码格式，请输入明文手机号`，不写入数据。
2. **Given** 更新接口传入掩码格式手机号 `138****0000`，**When** 校验手机号入参，**Then** 同样返回参数错误并提示 `手机号为掩码格式，请输入明文手机号`。
3. **Given** 保存接口传入明文手机号 `13812345678`，**When** 校验手机号入参，**Then** 正常通过校验，继续保存流程。
4. **Given** 保存接口传入前端 AES 加密手机号，**When** 校验手机号入参，**Then** 正常通过校验（AES 密文不是掩码格式），继续保存流程。
5. **Given** 保存接口传入 32 位 MD5 手机号，**When** 校验手机号入参，**Then** 仍按 036/041 规则返回 `手机号加密格式不符`（不被掩码格式校验覆盖）。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `phoneMask`：来源于数据库 `phone_mask` 字段，通过实体类 getter 获取；赋值时机为查询结果映射到 Output/DTO 时。
  - `phoneMd5`：来源于数据库 `phone_md5` 字段，通过实体类 getter 获取；赋值时机为查询结果映射到 Output/DTO 时。
  - `phoneAes`：来源于数据库 `phone_aes` 字段，通过实体类 getter 获取；赋值时机为查询结果映射到 Output/DTO 时。
  - `phone`（返回值）：不再使用实体 `getPhone()` 明文，改为使用 `phoneMaskForDisplay(phoneMask, phoneAes)` 或直接从 `phoneMask` 获取。
  - 掩码格式校验入参：来源于前端请求 DTO 的 `phone` 字段；校验时机为保存/更新 Service 入口方法最前端，在 `createAesInfo()` 之前。
- 下游读取字段清单：
  - 前端列表页读取 `phone`（改为掩码值）和 `phone_mask`。
  - 前端详情页可能读取 `phone_aes` 用于授权解密。
  - 前端查询条件复用 `phone_md5`（不经过前端，后端计算）。
  - 保存/更新链路读取请求 DTO 的 `phone` 字段，必须先校验格式再进入 `createAesInfo()`。
- 空对象 / 占位对象风险：
  - 查询结果中实体 `phoneMask`、`phoneMd5`、`phoneAes` 可能均为 NULL（历史数据未回填），Output/DTO 映射时必须做空值安全处理，不得抛 NPE。
  - 部分查询链路使用 `new XxxDto()` 后手动 set 字段，必须确保三个安全字段也被 set。
- 调用顺序风险：
  - 保存/更新链路：必须先做掩码格式校验 → 再做原有 `isWritablePhoneInput()` 校验 → 再调用 `createAesInfo()` → 最后 `save()`。
  - 查询链路：必须先查数据库获取实体 → 再从实体取安全字段 → 映射到 Output/DTO → `phone` 字段赋掩码值。
  - 禁止在 `createAesInfo()` 内部做掩码格式校验，必须在 Service 入口方法最前端显式校验。
- 旧逻辑保持：
  - 已有的 `phone_md5` 查询逻辑不变。
  - 已有的 `createAesInfo()` 保存链路安全字段计算逻辑不变。
  - 已有的 `isWritablePhoneInput()` 对 MD5 的拒绝逻辑不变，错误提示 `手机号加密格式不符` 不变。
  - 不新增 MQ、Redis、Feign、FC 或外部 HTTP 调用。
  - 不新增数据库表、字段或索引。
  - 不改变原有事务边界、异常处理、日志输出和 fallback 行为。
- 需要用户确认的设计选择：
  - `phone` 字段统一返回掩码值后，是否有接口确实需要返回明文手机号（如 ERP 推送、物流回调等后端间调用），这些接口是否需要单独处理而非走 Output/DTO 统一口径。
  - `phone_aes` 返回给前端后的安全性评估：AES 密文返回给前端后，前端是否有解密能力，是否需要限制 `phone_aes` 只返回给有权限的角色或接口。
  - 掩码格式校验的错误提示文案是否固定为 `手机号为掩码格式，请输入明文手机号`。

## 边界情况

- 查询结果中 `phone_mask` 为 NULL 但 `phone_aes` 有值：`phone` 字段通过 `DataSecurityInvoke.phoneMaskForDisplay(phoneMask, phoneAes)` 现算掩码返回。
- 查询结果中 `phone_mask` 和 `phone_aes` 均为 NULL：`phone` 字段返回 `null`，`phone_mask` 返回 `null`，`phone_aes` 返回 `null`，`phone_md5` 返回 `null`，不抛异常。
- 保存接口传入掩码格式手机号 `138****5678`：掩码格式校验拦截，返回明确错误。
- 保存接口传入部分掩码格式（如 `138*2345678`）：由掩码格式检测正则判断，包含连续 4 个及以上 `*` 即视为掩码格式。
- 保存接口传入明文手机号 `13812345678`：掩码格式校验通过，继续原有 `isWritablePhoneInput()` 流程。
- 保存接口传入前端 AES 加密手机号：掩码格式校验通过（AES 密文不含 `****`），继续原有流程。
- 保存接口传入 32 位 MD5：掩码格式校验通过（MD5 不含 `****`），由后续 `isWritablePhoneInput()` 拒绝，错误提示为 `手机号加密格式不符`。
- 保存接口传入空手机号：掩码格式校验跳过（空值不触发掩码检测），由原有逻辑处理。
- 导出接口返回手机号：同样使用掩码值，不暴露明文。
- 后端间接口（ERP 回调、物流推送等）需要明文手机号：这些接口不走 Output/DTO 返回链路，而是通过 `decryptPhoneAes()` 解密获取明文，不受本次 `phone` 字段返回掩码的影响。
- ju-chat 工程的 Output 类中 `phone` 字段同样需要改为掩码值，但 ju-chat 工程是否使用 `DataSecurityInvoke` 需确认依赖关系。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在所有涉及手机号的目标表查询接口返回结果中，增加 `phone_mask`、`phone_md5`、`phone_aes` 三个字段。
- **FR-002**：系统 MUST 将所有查询接口返回结果中的 `phone` 字段值改为 `phone_mask` 的值（掩码格式），不再返回明文手机号。
- **FR-003**：当 `phone_mask` 为 NULL 但 `phone_aes` 有值时，系统 MUST 通过 `phoneMaskForDisplay()` 现算掩码作为 `phone` 字段的返回值。
- **FR-004**：当 `phone_mask` 和 `phone_aes` 均为 NULL 时，系统 MUST 将 `phone`、`phone_mask`、`phone_md5`、`phone_aes` 返回为 `null`，不抛异常。
- **FR-005**：系统 MUST 在保存/更新接口的手机号校验链路中增加掩码格式检测，检测到掩码格式时返回参数错误并提示 `手机号为掩码格式，请输入明文手机号`。
- **FR-006**：掩码格式检测 MUST 在 `isWritablePhoneInput()` 之前执行，不影响原有的 MD5 拒绝逻辑。
- **FR-007**：系统 MUST 保持原有的 `phone_md5` 查询逻辑、`createAesInfo()` 保存逻辑和 `isWritablePhoneInput()` MD5 拒绝逻辑不变。
- **FR-008**：掩码格式检测 MUST NOT 影响查询接口，查询接口仍可传入明文、前端加密或 MD5 手机号。
- **FR-009**：后端间接口（ERP 回调、物流推送等）需要明文手机号时 MUST 通过 `decryptPhoneAes()` 获取，不受 `phone` 字段返回掩码的影响。
- **FR-010**：本阶段 MUST 只创建规格文档，不修改业务代码。

## 涉及文件与接口分析

### DRH 工程 — 需修改的 Output/DTO 类

以下 Output/DTO 类包含 `phone` 字段并返回给前端，需要增加 `phoneMask`、`phoneMd5`、`phoneAes` 三个字段，并将 `phone` 字段赋值来源改为掩码值：

| 模块 | 文件路径 | 类名 | 当前 phone 赋值来源 |
|------|---------|------|-------------------|
| drh-kk-cms | `dto\AppletUserDetailDto.java` | `AppletUserDetailDto` | 实体透传 |
| drh-kk-cms | `dto\AppletCardDto.java` | `AppletCardDto` | 实体透传 |
| drh-kk-cms | `dto\AppletSalePoolDto.java` | `AppletSalePoolDto` | 实体透传 |
| drh-kk-cms | `dto\AdUserPicDto.java` | `AdUserPicDto` | 实体透传 |
| drh-kk-cms | `dto\AdUserPicExportDto.java` | `AdUserPicExportDto` | 实体透传 |
| drh-kk-cms | `dto\bookpath\BookDetailDto.java` | `BookDetailDto` | 实体透传 |
| drh-kk-cms | `dto\LiveOrderDto.java` | `LiveOrderDto` | 实体透传 |
| drh-kk-cms | `dto\LivePhoneDto.java` | `LivePhoneDto` | 实体透传 |
| drh-kk-cms | `dto\OrderUserDto.java` | `OrderUserDto` | 实体透传 |
| drh-kk-cms | `dto\output\FormDetailOutput.java` | `FormDetailOutput` | 内联掩码 |
| drh-kk-cms | `dto\output\LiveUserSearchOutput.java` | `LiveUserSearchOutput` | 内联掩码 |

### DRH 工程 — 需修改的 Service 类

以下 Service 类涉及查询结果映射或保存入参校验，需要修改：

| 模块 | 文件路径 | 改造内容 |
|------|---------|---------|
| drh-kk-cms | `service\impl\BookQuestionRecordServiceImpl.java` | 查询结果映射增加安全字段，`phone` 赋掩码值；保存入口增加掩码格式校验 |
| drh-kk-cms | `service\impl\ExternalBookQuestionRecordServiceImpl.java` | 同上 |
| drh-kk-cms | `service\impl\H5OrderServiceImpl.java` | 查询结果映射增加安全字段，`phone` 赋掩码值 |
| drh-kk-cms | `service\impl\LiveCampGroupServiceImpl.java` | 查询结果映射增加安全字段，`phone` 赋掩码值 |
| drh-kk-cms | `service\impl\CollectOrderServiceImp.java` | 保存入口增加掩码格式校验 |
| drh-kk-cms | `service\impl\AppletFupServiceImpl.java` | 查询结果映射增加安全字段 |
| drh-kk-cms | `service\impl\ChannelEmpServiceImpl.java` | 查询结果映射增加安全字段 |
| drh-common | `fc\datasec\DataSecurityInvoke.java` | 增加 `isMaskedPhone()` 掩码格式检测方法 |

### DRH 工程 — 需修改的 Controller 类

以下 Controller 类的接口涉及手机号返回，返回结构可能需要调整：

| 模块 | Controller | 涉及接口 |
|------|-----------|---------|
| drh-kk-cms | `UserController` | `GET /user/phone/user`、`POST /user/selectPhone`、`POST /user/checkCounts` |
| drh-kk-cms | `BookPathController` | `GET /bookPath/queryAdDetail`、`GET /bookPath/queryOrderDetail`、`GET /bookPath/queryCollectDetail` |
| drh-kk-cms | `AdUserPicController` | `GET /ad/pic`、`POST /ad/v2/pic`、`POST /ad/base/pic` |
| drh-kk-cms | `OrderController` | `POST /collect/order/list`、`GET /collect/order/detail`、导出接口 |
| drh-kk-cms | `ExternalBookQuestionRecordController` | `POST /external/bookQuestionRecord/queryHistoryPage` |
| drh-kk-cms | `LiveCampGroupController` | `GET /liveCampGroup/stu/search`、`GET /liveCampGroup/stu/logistics` |

### DRH 工程 — 受影响的接口汇总

| 模块 | 接口 | 影响类型 |
|------|------|---------|
| drh-kk-cms | `GET /user/phone/user` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-kk-cms | `POST /user/selectPhone` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-kk-cms | `POST /user/checkCounts` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-kk-cms | `GET /bookPath/queryAdDetail` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-kk-cms | `GET /bookPath/queryOrderDetail` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-kk-cms | `GET /bookPath/queryCollectDetail` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-kk-cms | `POST /bookPath/editAddress` | 保存入口增加掩码格式校验 |
| drh-kk-cms | `POST /bookPath/editAddressV2` | 保存入口增加掩码格式校验 |
| drh-kk-cms | `POST /external/bookQuestionRecord/create` | 保存入口增加掩码格式校验 |
| drh-kk-cms | `POST /external/bookQuestionRecord/queryHistoryPage` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-kk-cms | `POST /collect/order/list` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-kk-cms | `GET /collect/order/detail` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-kk-cms | `GET /collect/order/import/address` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-kk-cms | `GET /liveCampGroup/stu/search` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-kk-cms | `GET /liveCampGroup/stu/logistics` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-kk-cms | `GET /ad/pic` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-kk-cms | `POST /ad/v2/pic` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-pay | `GET /h5/order/query/phone` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-endpoint | `GET /bookPath/queryTrackNumOrder` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-endpoint | `POST /bookPath/editAddress` | 保存入口增加掩码格式校验 |
| drh-endpoint | `POST /bookPath/editAddressV2` | 保存入口增加掩码格式校验 |
| drh-endpoint | `GET /liveAuth/ad/applet/query` | 返回结果 phone → 掩码 + 增加安全字段 |
| drh-callback | `POST /ad/order` | 保存入口增加掩码格式校验 |
| drh-callback | `POST /third/external/importLeads` | 保存入口增加掩码格式校验 |
| drh-callback | `POST /third/external/importLeadsV2` | 保存入口增加掩码格式校验 |
| drh-media-process | `POST /erp/callback` | 保存入口增加掩码格式校验 |
| drh-media-process | `POST /fBook/callback` | 保存入口增加掩码格式校验 |

### ju-chat 工程 — 需修改的 Output 类

ju-chat 工程中以下 Output 类包含 `phone` 字段返回给前端，需要同样改造：

| 模块 | 文件路径 | 类名 |
|------|---------|------|
| ai-common | `output\userprofile\UserProfileUserInfoOutput.java` | `UserProfileUserInfoOutput` |
| ai-common | `output\userrecord\UserServiceRecordOutput.java` | `UserServiceRecordOutput` |
| ai-common | `output\order\OrderPageOutput.java` | `OrderPageOutput` |
| ai-common | `output\order\fulfillment\reissue\LmsQueryExportDataOutput.java` | `LmsQueryExportDataOutput` |
| ai-common | `output\order\fulfillment\reissue\LmsOrderGoodReissueDetailOutput.java` | `LmsOrderGoodReissueDetailOutput` |
| ai-common | `output\order\fulfillment\address\LmsRealGoodsAddressRecordOutput.java` | `LmsRealGoodsAddressRecordOutput` |
| ai-common | `output\order\app\AppCollectOrderOutput.java` | `AppCollectOrderOutput` |
| ai-common | `output\works\LeadsNoqwSendMsgTaskDetailOutput.java` | `LeadsNoqwSendMsgTaskDetailOutput` |

### ju-chat 工程 — 受影响的接口

| 模块 | 接口 | 影响类型 |
|------|------|---------|
| ai | `GET /getBookOrderByPhone` | 返回结果 phone → 掩码 + 增加安全字段 |
| ai | `/book/getBookQuestionRecordByAppletUserId` | 返回结果 phone → 掩码 + 增加安全字段 |
| ai | `/external/bookQuestionRecord/create` | 保存入口增加掩码格式校验 |
| ai | `/external/bookQuestionRecord/queryHistoryPage` | 返回结果 phone → 掩码 + 增加安全字段 |
| ai | `/book-edit-address-compensation/saveOne` | 保存入口增加掩码格式校验 |

### 核心工具方法 — 新增掩码格式检测

在 `DataSecurityInvoke.java` 中新增 `isMaskedPhone()` 方法：

```java
/**
 * 检测手机号是否为掩码格式（如 138****5678）
 * 判断规则：包含连续 4 个及以上 * 号
 */
public static boolean isMaskedPhone(String phoneInput) {
    if (StringUtils.isEmpty(phoneInput)) {
        return false;
    }
    return phoneInput.contains("****");
}
```

### 校验链路改造 — 保存/更新入口

每个保存/更新入口在调用 `createAesInfo()` 或 `isWritablePhoneInput()` 之前，增加掩码格式校验：

```java
// 掩码格式校验（新增）
if (DataSecurityInvoke.isMaskedPhone(phone)) {
    throw new BusinessException("手机号为掩码格式，请输入明文手机号");
}
// 原有校验（保持不变）
if (!DataSecurityInvoke.isWritablePhoneInput(phone)) {
    throw new BusinessException("手机号加密格式不符");
}
```

## 成功标准 *(必填)*

- **SC-001**：所有涉及手机号的目标表查询接口返回结果中包含 `phone`、`phone_mask`、`phone_md5`、`phone_aes` 四个字段。
- **SC-002**：查询接口返回的 `phone` 字段值为掩码格式，不再包含明文手机号。
- **SC-003**：保存/更新接口传入掩码格式手机号时，返回明确的错误提示 `手机号为掩码格式，请输入明文手机号`。
- **SC-004**：保存/更新接口传入明文手机号和前端 AES 加密手机号时，正常保存不受影响。
- **SC-005**：保存/更新接口传入 MD5 手机号时，仍返回原有错误提示 `手机号加密格式不符`。
- **SC-006**：原有查询逻辑（`phone_md5` 等值匹配）、保存逻辑（`createAesInfo()` 安全字段计算）不回归。
- **SC-007**：后端间接口（ERP 回调、物流推送等）获取明文手机号不受影响。

## 假设

- 目标表数据库已具备 `phone_mask`、`phone_md5`、`phone_aes` 字段（032 需求已完成 DDL）。
- 实体类已具备 `phoneMask`、`phoneMd5`、`phoneAes` 持久化字段（036 需求已完成）。
- `DataSecurityInvoke.phoneMaskForDisplay()` 可正确从 `phoneMask` 或 `phoneAes` 获取掩码值。
- `DataSecurityInvoke.isWritablePhoneInput()` 已能拒绝 MD5 格式，本次只需在其之前增加掩码格式检测。
- 掩码格式检测规则简单可靠：包含 `****`（连续 4 个星号）即视为掩码格式，不会误判明文手机号或 AES 密文。
- 前端不需要对 `phone_aes` 做特殊处理，仅作为数据字段传递；需要解密时通过有权限的详情接口获取。
- ju-chat 工程 ai 模块可访问 `DataSecurityInvoke` 类（通过 drh-common 依赖或 ai-common 中的等价实现）。
- Output/DTO 类增加字段不会破坏前端现有的 JSON 解析（前端忽略未知字段）。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成代码搜索，确认目标实体、Output/DTO、Service、Controller 和现有工具方法。
- 已完成历史问题防漏分析和强制门禁检查。
- 已同步记录三个前置需求（032/036/041）的关系和依赖。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 触发原因：用户要求按文档执行编码改造。
- 实现内容：
  - **DataSecurityInvoke 新增 `isMaskedPhone()` 方法**：检测输入是否包含 `****`（连续4个星号），用于掩码格式校验。位于 `C:\workspace\drh\drh-common\src\main\java\com\drh\common\fc\datasec\DataSecurityInvoke.java`。
  - **drh-kk-cms Output/DTO 增加安全字段**：`AppletUserDetailDto`、`AppletCardDto`、`AppletSalePoolDto`、`AdUserPicDto`、`BookDetailDto`、`LiveOrderDto`、`LivePhoneDto`、`OrderUserDto` 均增加 `phoneMask`、`phoneMd5`、`phoneAes` 字段。`FormDetailOutput`、`LiveUserSearchOutput` 增加安全字段并优先使用 `phoneMask` 返回。
  - **drh-kk-cms Service 查询映射改造**：
    - `BookQuestionRecordServiceImpl`：`getBookDetailDto` 方法增加 `phoneMask`、`phoneMd5`、`phoneAes` 参数，3 个调用点同步更新。
    - `LiveCampGroupServiceImpl`：4 处 `LiveUserSearchOutput` 构建逻辑增加安全字段赋值。
    - `CollectOrderServiceImp`：3 处 `output.setPhone(liveUser.getPhone())` / `output.setPhone(one.getPhone())` 改为 `DataSecurityInvoke.phoneMaskForDisplay()`；`addressDetailDto.setReceiverPhone()` 同样改为掩码。新增 `DataSecurityInvoke` import。
    - `LiveOrderDto.dealLiveOrderDtoAndLiveUser`：`setPhone()` 改为 `phoneMaskForDisplay()`，并增加安全字段赋值。
  - **drh-kk-cms 保存入口掩码格式校验**：
    - `BookQuestionRecordServiceImpl.checkWritablePhone()`：在 `isWritablePhoneInput()` 之前增加 `isMaskedPhone()` 校验，掩码格式错误提示为 `手机号为掩码格式，请输入明文手机号`。
    - `ExternalBookQuestionRecordServiceImpl.checkWritablePhone()`：同上。
    - 两个 Service 均新增 `PHONE_MASKED_FORMAT_ERROR` 常量。
  - **ju-chat ai-common Output 类增加安全字段**：`UserProfileUserInfoOutput`、`UserServiceRecordOutput`、`OrderPageOutput`、`LmsQueryExportDataOutput`、`LmsOrderGoodReissueDetailOutput`、`LmsRealGoodsAddressRecordOutput`、`AppCollectOrderOutput`、`LeadsNoqwSendMsgTaskDetailOutput` 均增加 `phoneMask`、`phoneMd5`、`phoneAes` 字段。
  - **单元测试**：`DataSecurityUtilTest` 新增 8 个 `isMaskedPhone` 测试用例，覆盖掩码格式检测、明文拒绝、null/空拒绝、MD5 拒绝、AES 密文拒绝、单星号拒绝。
- 影响范围：
  - drh 工程：`drh-common`（工具类）、`drh-kk-cms`（8 个 DTO + 4 个 Service + 1 个 Test）
  - ju-chat 工程：`ai-common`（8 个 Output 类）
- 排除项：ju-chat ai 模块无 `DataSecurityInvoke` 依赖，保存入口掩码校验由 drh-endpoint 的 `editAddressV2` Feign 调用链覆盖。
- 验证结果：代码已修改，待编译和接口验证。
- 自检结论：所有 Output/DTO 安全字段已增加；Service 层查询映射已改为掩码值 + 安全字段赋值；保存入口掩码校验已在 `isWritablePhoneInput` 之前执行，不影响原有 MD5 拒绝逻辑。

### D003 - XML Mapper 查询字段遗漏纠正

- 触发原因：代码审查发现 XML Mapper 中 SELECT 语句未包含 `phone_mask`、`phone_md5`、`phone_aes` 列，导致 Java Service 层从 XML 查询结果映射到 Output/DTO 时安全字段为 null。D002 只改了 Java 层 set 逻辑，但 XML 数据源未同步。
- 修正内容：
  - **drh-kk-cms XML Mapper 改造**（7 个文件，15 个 SELECT）：
    - `AdUserPicMapper.xml`：6 个 SELECT（getPageList、getExportList、getGxPage、getFlowGxPage、getFlowPageList、getPageListV2）补充 `au.phone_mask phoneMask`、`au.phone_md5 phoneMd5`、`au.phone_aes phoneAes`；getExportList 的 phone 改为 `COALESCE(au.phone_mask, au.phone) phone`。
    - `AppletUserPoolMapper.xml`：2 个 SELECT（selectPoolPage、selectPoolPageClick）补充安全字段。
    - `AppletSalePoolMapper.xml`：1 个 SELECT（selectPoolPage）补充安全字段。
    - `AppletUserMapper.xml`：cardCountV4 补充安全字段。
    - `ExternalBookQuestionRecordMapper.xml`：queryHistoryPage 的 resultMap 增加 phoneMask/phoneMd5/phoneAes 映射；3 个 UNION 子查询增加 `phone_mask`、`phone_md5`、`phone_aes` 列。
    - `AdPicMapper.xml`：2 个导出 SELECT（selectExportOutput、selectGxExportOutput）phone 改为 `COALESCE(auser.phone_mask, auser.phone)`，补充安全字段。
  - **drh-kk-cms DTO/Output 补充**（5 个文件）：
    - `AdUserPicFlowDto`：增加 phoneMask、phoneMd5、phoneAes。
    - `PoolAdListOutput`：增加 phoneMask、phoneMd5、phoneAes。
    - `AdExportOutput`：增加 phoneMask、phoneMd5、phoneAes（@CsvField(ignore=true)）。
    - `AdUserPicExportDto`：增加 phoneMask、phoneMd5、phoneAes（@CsvField(ignore=true)）。
    - `BookQuestionRecordHistoryOutput`：增加 phoneMask、phoneMd5、phoneAes。
  - **ju-chat XML Mapper 改造**（6 个文件）：
    - `OrderBookReissueMapper.xml`（ai、app、lms 三个模块各一份）：resultMap 增加 phone_mask/phone_md5/phone_aes 映射；SELECT 增加 `obrd.phone_mask`、`obrd.phone_md5`、`obrd.phone_aes`。
    - `LiveWelfareReceiveMapper.xml`（ai、app、lms 三个模块各一份）：SELECT 增加 `lu.phone_mask as userPhoneMask`、`lu.phone_md5 as userPhoneMd5`、`lu.phone_aes as userPhoneAes`。
  - **ju-chat DTO/BO 补充**（6 个文件）：
    - `LmsExportDataResultDto`（lms-common、ai-common 各一份）：增加 phoneMask、phoneMd5、phoneAes。
    - `LiveWelfareReceiveBo`（lms-common、ai-common 各一份）：增加 userPhoneMask、userPhoneMd5、userPhoneAes。
    - `LmsOrderGoodReissueDetailOutput`（lms-common）：增加 phoneMask、phoneMd5、phoneAes。
    - `LmsQueryExportDataOutput`（lms-common）：增加 phoneMask、phoneMd5、phoneAes。
- 文档同步：spec.md（本记录）、tasks.md。
- 验证结果：待编译和接口验证。

### D004 - XML Mapper 查询字段第二轮补遗

- 触发原因：D003 验证环节对 drh-kk-cms 全量 XML Mapper 做第二轮扫描，发现 14+ 个 XML Mapper 文件（30+ 个 SELECT）仍未包含安全字段查询列。这些文件涉及 Handover 系列（交接/转交/特殊学员管理）、直播学习统计、营期学员、作品关系链、分享拉新等核心业务模块。同时发现 19 个 DTO/Output 类缺少安全字段定义。
- 修正内容：
  - **drh-kk-cms XML Mapper 改造**（14 个文件，30+ 个 SELECT）：
    - `LivingStudyInfoMapper.xml`：4 个 SELECT（getEmpPageByInput、getMergeClassEmpPageByInput、getRolePageByInput、getMergeClassRolePageByInput），三层嵌套子查询传播 `phone_mask`/`phone_md5`/`phone_aes`（内层 `luser.phone_mask` → 中层 `s.phone_mask` → 外层 `t.phone_mask phoneMask`）。
    - `LiveCampUserMapper.xml`：selectUser 共享 SQL 片段，t3 子查询从 `drh_live_user` 取 `u.phone_mask/u.phone_md5/u.phone_aes` 并传播到外层。
    - `HandoverPlusDelMapper.xml`：getStuPageList 补充安全字段。
    - `SpecailHandoverMapper.xml`：getStuPageList + stuListByGroupInput 补充安全字段。
    - `SpecialUserCampMapper.xml`：getStuPageList + getStuPageListV3 补充安全字段。
    - `HandoverPlusMapper.xml`：eduStudentList + groupStudentNmList 补充安全字段（groupStudentList/specailStudentList 的 SELECT 中无 phone 列，跳过）。
    - `HandoverMapper.xml`：8 个 SELECT（selectOrderUsersSQL、selectChangeGoodsList、selectOrderUserList、selectOrderUserPageV2、selectOrderUserListV2 hand_user CTE、selectOrderUserListNew、selectOrderUsersNewSQL 等）补充 `luser.phone_mask phoneMask` 等。
    - `SpecailUserMapper.xml`：specailListPage 补充安全字段。
    - `OrderHandRecordMapper.xml`：getOrderPageList 补充安全字段。
    - `OrderHandRecordDelMapper.xml`：getOrderPageList 补充安全字段。
    - `AppletUserMapper.xml`：queryAllLeads、queryAllLeadsNoClass、getMergeClassAppletUserByInput、getMergeClassAppletUserPageByInput 补充安全字段。
    - `FrontMyClassOrderBoardMapper.xml`：queryOrderList（from drh_applet_user）补充安全字段。
    - `WorksShipMapper.xml`：5 个 SELECT 补充安全字段，含非标准字段名映射（`lwu1.phone_mask oPhoneMask`、`lwu2.phone_mask superPhoneMask`、`lwu.phone_mask tPhoneMask`）。已验证 `drh_live_works_user` 表有 phone_mask/phone_md5/phone_aes 列。
    - `WorksAwardsRecordMapper.xml`：selectAwards 补充安全字段。
    - `ShareIntroductionMapper.xml`：getShareIntroductionData 补充安全字段。
  - **drh-kk-cms DTO/Output 补充**（20 个文件）：
    - DataPageOutput、LiveCampUserDto、GroupLiveBaseOutput、GroupStudentOutput、SpecailUserDto、OrderHandUserGroupDto、HandoverOutput、OrderUser、OrderUserDto、EduOrderUser、InviteShipOutput、ClassShipOutput、OrderShipOutput、WorksAwardsOutput、QueryOrderPo、ShareIntroductionDataOutput：增加 phoneMask、phoneMd5、phoneAes。
    - LeadsExportDto：增加 phoneMask、phoneMd5、phoneAes（@CsvField(ignore=true)）。
    - AppletShipOutput：增加 oPhoneMask/oPhoneMd5/oPhoneAes + superPhoneMask/superPhoneMd5/superPhoneAes（非标准字段名映射）。
    - AppletShipExportDto：增加 tPhoneMask/tPhoneMd5/tPhoneAes + oPhoneMask/oPhoneMd5/oPhoneAes（@CsvField(ignore=true)）。
    - OrderHandRecordDel（drh-common 实体类）：增加 phoneMask、phoneMd5、phoneAes（@TableField(exist=false)）。
- 文档同步：spec.md（本记录）、tasks.md（Phase 6 + D004）。
- 验证结果：待编译和接口验证。
