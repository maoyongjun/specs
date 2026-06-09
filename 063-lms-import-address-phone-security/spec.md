# 功能规格：lms 批量导入地址手机号安全补充

**功能目录**：`063-lms-import-address-phone-security`  
**创建日期**：`2026-06-09`  
**状态**：Implemented（待目标环境执行 DDL 与接口联调）  
**输入**：补充整改 `kkhc-idc/lms` 中 `CollectOrderController` 的 `importAddress`、`importAddressSure`、`importAddressDetail`、`downloadFailList`、`importAddressJob` 以及类内其他涉及手机号加密的接口。

## 背景

- 当前问题：历史 `051-phone-security-ddl-summary` 曾记录 `drh_import_address_record_detail` 未找到并暂不纳入 DDL，但当前 ju-chat lms 已存在实体、分页查询和导入确认链路，且分页仍按明文 `phone` 查询。
- 当前行为：导入明细保存只写 `phone`；失败列表和分页明细会返回明文；确认导入创建 `drh_real_address_record`、回填 `drh_live_user` 时未在 lms-common 侧补齐安全字段。
- 目标行为：导入明细、真实地址、学员回填均同步写 `phone_mask/phone_md5/phone_aes`；手机号搜索走 `phone_md5`；返回展示走掩码；ERP 明文推送保留但增加 `phone_aes` 解密兜底。
- 非目标：不新增 HTTP 路径；不改 `getValidCollectOrders`、`selectByCondition`；不清空原 `phone` 字段。

## 用户场景与测试

### 用户故事 1 - 导入明细保存安全字段（优先级：P1）

运营上传收货地址 Excel 后，系统保存每行导入明细时同步生成手机号安全字段。

**独立测试**：导入一行手机号格式正确的数据，检查 `drh_import_address_record_detail.phone_mask/phone_md5/phone_aes` 均有值。

**验收场景**：

1. **Given** Excel 行手机号为 `13812345678` 且订单校验通过，**When** 调用 `importAddress`，**Then** 导入明细保存明文 `phone` 和三类安全字段。
2. **Given** Excel 行手机号格式正确但地区或订单校验失败，**When** 调用 `importAddress`，**Then** 失败明细同样保存三类安全字段，失败列表可掩码展示。
3. **Given** Excel 行手机号为空或格式错误，**When** 调用 `importAddress`，**Then** 保持原校验失败口径，不强行生成安全字段。

### 用户故事 2 - 明细查询和失败列表不暴露明文（优先级：P1）

后台查看或导出导入结果时，手机号展示字段必须返回掩码值，手机号搜索必须走 MD5。

**独立测试**：分别用明文、前端 AES 密文、32 位 MD5 查询同一手机号，确认 SQL 条件为 `phone_md5`，返回 `phone` 为 `138****5678`。

**验收场景**：

1. **Given** 查询条件 `phone=13812345678`，**When** 调用 `importAddressDetail`，**Then** 后端计算 MD5 后使用 `phone_md5` 查询。
2. **Given** 查询条件为 32 位手机号 MD5，**When** 调用 `importAddressDetail`，**Then** 后端直通小写 MD5，不二次摘要。
3. **Given** 查询手机号非空但 MD5 计算失败，**When** 调用 `importAddressDetail`，**Then** 返回空页，不忽略手机号条件。
4. **Given** 调用 `downloadFailList`，**When** 返回失败列表，**Then** `phone` 字段为掩码值。

### 用户故事 3 - 确认导入和 ERP 推送不回归（优先级：P1）

确认导入后，真实地址表和学员手机号回填同步有安全字段，同时 ERP 仍拿到明文手机号。

**独立测试**：确认导入一条地址，检查 `drh_real_address_record` 安全字段；构造 `phone` 为空但 `phone_aes` 有值的地址记录，确认 ERP 请求手机号可从密文解出。

**验收场景**：

1. **Given** 导入明细确认成功且未存在真实地址，**When** 保存 `RealGoodsAddressRecordDO`，**Then** 保存前调用 `createAesInfo()`。
2. **Given** `LiveUser.phone` 为空，**When** 用真实地址回填手机号，**Then** 同步设置 `phoneMask/phoneMd5/phoneAes`。
3. **Given** 后续清空真实地址明文 `phone` 但保留 `phoneAes`，**When** 上传 ERP，**Then** 通过 `phoneAes` 解密得到明文手机号。

## 数据模型与接口

- `drh_import_address_record_detail.phone` 新增 `phone_mask`、`phone_md5`、`phone_aes` 和 `idx_import_address_detail_phone_md5`；DDL 见 `phone-security-import-address-detail-ddl.sql`。
- `ImportAddressRecordDetailOutput` 新增 `phoneMask/phoneMd5/phoneAes`，原 `phone` 字段返回掩码。
- `lms-common` 的 `ImportAddressRecordDetail`、`RealGoodsAddressRecordDO`、`LiveUserDO` 补齐 `phoneMask/phoneMd5/phoneAes` 和 `createAesInfo()`。
- `DataSecurityInvoke.computePhoneMd5()` 支持 32 位十六进制 MD5 直通并小写归一。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `ImportAddressRecordDetail.phone`：来源 Excel `收货手机号`；校验后、`saveBatch` 前生成安全字段。
  - `ImportAddressRecordDetail.phoneMd5`：来源 `createAesInfo()` 或历史回填；分页查询前由 `computePhoneMd5(search.phone)` 现算。
  - `RealGoodsAddressRecordDO.phone`：来源导入明细复制到 `BookEditAddressDto`；`realGoodsAddressRecordService.save` 前生成安全字段。
  - `LiveUserDO.phone`：来源真实地址记录；回填更新前补齐安全字段。
  - ERP `receiver_phone`：来源 `RealGoodsAddressRecordDO.phone`，为空时通过 `phoneAes` 解密兜底。
- 下游读取字段清单：
  - 前端/导出读取 `ImportAddressRecordDetailOutput.phone`、`phoneMask`、`phoneMd5`、`phoneAes`。
  - MyBatis-Plus 分页查询读取 `ImportAddressRecordDetail.phoneMd5`。
  - ERP 请求读取 `receiver_phone` 明文。
- 空对象 / 占位对象风险：
  - `realGoodsAddressRecord` 为空时不会进入 ERP 上传和学员回填。
  - `phoneAes` 为空或解密失败时 ERP 兜底返回空，保留原异常处理。
- 调用顺序风险：
  - 必须先 Excel 行校验，再生成导入明细安全字段，再 `saveBatch`。
  - 必须先生成真实地址安全字段，再保存真实地址，再上传 ERP。
  - 必须先构造学员手机号安全字段，再执行 `LambdaUpdateWrapper`。
- 旧逻辑保持：
  - 原 URL、Feign、分页、Redis 锁、导入状态、ERP 上传流程、异步阈值和重试次数不变。
  - 不新增 MQ、Redis key 或外部 HTTP 调用；安全字段生成沿用既有 FC 工具。
- 需要用户确认的设计选择：无。

## 边界情况

- 导入文件为空：沿用 `导入文件数据为空`。
- 手机号为空/格式错误：沿用原校验错误，不调用安全字段生成。
- 手机号查询输入无法归一为 MD5：返回空页，不抛异常、不返回全量。
- 历史记录 `phoneMask` 为空但 `phoneAes` 有值：返回展示通过 `phoneAes` 现算掩码。
- FC 调用失败：安全字段保持空并记录错误；主流程沿用原异常/状态处理。
- ERP 需要明文手机号：后端内部读取 `phone` 或解密 `phoneAes`，不受前端掩码展示影响。

## 需求

- **FR-001**：系统 MUST 为 `drh_import_address_record_detail.phone` 增加三类安全字段和 MD5 索引 DDL。
- **FR-002**：系统 MUST 在导入明细保存前为格式正确的手机号生成 `phoneMask/phoneMd5/phoneAes`。
- **FR-003**：系统 MUST 将 `importAddressDetail` 手机号查询从 `phone` 改为 `phoneMd5`。
- **FR-004**：系统 MUST 让失败列表和分页明细返回 `phone` 掩码值。
- **FR-005**：系统 MUST 在真实地址保存前生成安全字段。
- **FR-006**：系统 MUST 在回填 `LiveUser.phone` 时同步回填安全字段。
- **FR-007**：系统 MUST 在 ERP 上传手机号读取时支持 `phoneAes` 解密兜底。
- **FR-008**：系统 MUST NOT 修改不含手机号的 `getValidCollectOrders`、`selectByCondition`。
- **FR-009**：历史回填目标 MUST 包含 `drh_import_address_record_detail`。

## 成功标准

- **SC-001**：搜索确认 `ImportAddressRecordDetailServiceImpl` 不再按 `ImportAddressRecordDetail::getPhone` 查询。
- **SC-002**：导入明细、真实地址、学员回填实体均包含安全字段。
- **SC-003**：失败列表和分页明细不返回明文手机号。
- **SC-004**：32 位 MD5 查询输入不触发 FC，直接用于 `phone_md5` 查询。
- **SC-005**：目标模块编译通过。

## 假设

- `drh_real_address_record` 与 `drh_live_user` 的数据库安全字段已由既有 DDL 覆盖。
- `drh_import_address_record_detail` 需要在目标环境执行本规格 DDL 后再上线代码。
- 原 `phone` 字段过渡期保留，但新增逻辑不依赖它作为唯一明文来源。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档、任务清单、检查清单、执行说明和 DDL。
- 已记录历史 `051` 中 `drh_import_address_record_detail` 未纳入 DDL 的纠正点。

### D002 - 实现记录

- 实现内容：
  - `base-common DataSecurityInvoke.computePhoneMd5()` 增加 32 位 MD5 直通。
  - `lms-common` 三个实体补齐 `phoneMask/phoneMd5/phoneAes` 和 `createAesInfo()`。
  - `ImportAddressRecordDetailOutput` 增加三类安全字段，`ImportAddressRecordConverter` 映射后将 `phone` 改为掩码。
  - `ImportAddressRecordDetailServiceImpl` 手机号查询改为 `phoneMd5`，MD5 计算失败返回空页。
  - `CollectOrderServiceImpl` 导入明细保存、真实地址保存、LiveUser 回填、ERP 手机号读取和导入日志均按安全字段口径处理。
  - `PhoneSecurityBackfillService` 增加 `drh_import_address_record_detail` 回填目标。
  - 新增 `DataSecurityInvokeTest` 和 `ImportAddressRecordConverterTest`。
- 验证结果：见 `tasks.md` D002。
