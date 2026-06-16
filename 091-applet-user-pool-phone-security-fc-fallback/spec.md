# 功能规格：AppletUserPool 分页 phone 掩码补算（phone_mask 为空走函数计算）

**功能目录**：`091-applet-user-pool-phone-security-fc-fallback`  
**创建日期**：`2026-06-16`  
**状态**：Implemented（静态验证通过；全量 Maven 受外部父 POM/本机环境限制未完成）  
**输入**：在 `C:\workspace\ju-chat\specs` 创建 spec-kit 文档，完成如下改动：修改 `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\AppletUserPoolServiceImpl.java`，针对 Phone 的赋值如果 `phone_mask` 为空的使用 `phone`，并对 Phone 字段调用函数计算进行掩码和 `phone_aes` 的处理返回；这个返回的时候，不用像以前校验手机号的合理性，例如 `+61432563303` 和 `15781266352-1781` 可以进行正常加密处理。

## 背景

- 当前问题：`getPageList` 在 `records.forEach` 末尾固定执行 `e.setPhone(e.getPhoneMask());`。对于历史未回填 `phone_mask` 的行，掩码为空导致对外 `phone` 直接变成空值，前端拿不到可展示的掩码，也拿不到 `phone_aes` 发起受控解密。
- 当前行为：
  - `selectPoolPage` 已返回 `phone`（`au.phone`，可能为明文/历史值/空）、`phoneMask`（`au.phone_mask`）、`phoneMd5`（`au.phone_md5`）、`phoneAes`（`au.phone_aes`）。
  - `records.forEach` 在 `e.setPhone(e.getPhoneMask())` 之前用原始 `e.getPhone()` 作为 key 查询 `phoneChannelSet` 渠道价格。
  - 末尾 `e.setPhone(e.getPhoneMask())` 把 `phone` 覆盖为掩码；掩码为空时 `phone` 变为 `null`/空。
- 目标行为：
  - `phone_mask` 有值：`phone` 返回 `phone_mask`（保持现状）。
  - `phone_mask` 为空但 `phone` 有值：用 `phone` 调用函数计算（`DataSecurityInvoke.buildPhoneSecurity`）补算 `phoneMask/phoneMd5/phoneAes`，对外 `phone` 返回补算出的掩码，并同步回填三类安全字段。
  - 补算调用不校验手机号合理性，`+61432563303`（国际号）、`15781266352-1781`（带分机/后缀）等非标准格式必须能正常加密处理。
  - 函数计算返回为空或掩码为空时，`phone` 返回 `null`，不回退返回明文。
- 非目标：不新增接口路径；不改分页入参、分页条件、权限过滤、其他字段装配；不新增数据库表/字段/DDL/MQ/Redis；不改 `selectPoolPage` SQL；不回填或清洗历史 `drh_applet_user` 数据。

## 用户场景与测试 *(必填)*

### 用户故事 1 - phone_mask 有值时返回掩码（优先级：P1）

客服在公海分页列表中查看用户时，`phone_mask` 已回填的行按既有口径展示掩码手机号，不触发任何函数计算调用。

**独立测试**：构造记录 `phoneMask=138****5678`、`phone=13800005678`，执行 phone 赋值逻辑后断言 `phone=138****5678`，且未调用函数计算。

**验收场景**：

1. **Given** 记录 `phoneMask=138****5678`，**When** 执行 `getPageList` 的 phone 赋值，**Then** `phone` 返回 `138****5678`。
2. **Given** 记录 `phoneMask` 非空，**When** 装配该行，**Then** 不调用 `buildPhoneSecurity`（无新增函数计算远程调用）。

### 用户故事 2 - phone_mask 为空时走函数计算补算（优先级：P1）

`phone_mask` 历史为空但 `phone` 有值时，用 `phone` 调用函数计算补算掩码和 `phone_aes`，前端既能展示掩码，又能拿到 `phone_aes` 发起受控解密。

**独立测试**：构造记录 `phoneMask=null`、`phone=15781266352`，令函数计算返回 `mask=157****6352, md5=xxx, aes=enc`，执行 phone 赋值后断言 `phone=157****6352`、`phoneAes=enc`、`phoneMd5=xxx`、`phoneMask=157****6352`。

**验收场景**：

1. **Given** `phoneMask` 为空、`phone=15781266352`，**When** 执行 phone 赋值，**Then** 以原始 `phone=15781266352` 为入参调用函数计算。
2. **Given** 函数计算返回 `mask/md5/aes`，**When** 补算完成，**Then** `phone=mask`，且 `phoneMask/phoneMd5/phoneAes` 同步回填。

### 用户故事 3 - 非标准手机号不被校验拦截（优先级：P1）

非标准格式手机号（国际号、带后缀）在 `phone_mask` 为空时也要能调用函数计算补算，不被 Java 侧手机号格式校验拦截。

**独立测试**：分别构造 `phone=+61432563303` 和 `phone=15781266352-1781`，`phoneMask` 为空，断言两者都会原样作为入参调用函数计算（不被 `isPlainPhone` 等校验提前拦截或置空）。

**验收场景**：

1. **Given** `phoneMask` 为空、`phone=+61432563303`，**When** 执行 phone 赋值，**Then** 原始值 `+61432563303` 被传入函数计算，不抛异常、不被格式校验跳过。
2. **Given** `phoneMask` 为空、`phone=15781266352-1781`，**When** 执行 phone 赋值，**Then** 原始值 `15781266352-1781` 被传入函数计算正常补算。

### 用户故事 4 - 函数计算失败不泄露明文（优先级：P1）

`phone_mask` 为空走函数计算补算时，函数计算返回为空或掩码为空，则对外 `phone` 返回 `null`，不回退返回明文 `phone`。

**独立测试**：构造 `phoneMask=null`、`phone=13800001111`，令函数计算返回 `null`，断言 `phone=null`，明文不出现在输出中。

**验收场景**：

1. **Given** `phoneMask` 为空、`phone` 有值，**When** 函数计算返回 `null` 或 `mask` 为空，**Then** `phone` 返回 `null`。
2. **Given** `phoneMask` 与 `phone` 均为空，**When** 执行 phone 赋值，**Then** `phone` 返回 `null`，不调用函数计算。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `phone`：来源 `selectPoolPage` 的 `au.phone`；在 `records.forEach` 末尾覆盖前，先被 `phoneChannelSet.getOrDefault(e.getPhone(), ...)`（渠道价格）读取；覆盖发生在该读取之后。
  - `phoneMask`：来源 `au.phone_mask`；为空时由 `buildPhoneSecurity` 现算回填。
  - `phoneMd5`：来源 `au.phone_md5`；为空时由 `buildPhoneSecurity` 现算回填。
  - `phoneAes`：来源 `au.phone_aes`；为空时由 `buildPhoneSecurity` 现算回填。
  - 函数计算入参：原始 `e.getPhone()`，不做格式归一化/校验。
- 下游读取字段清单：
  - 前端读取 `phone` 展示掩码手机号。
  - 前端/受控链路读取 `phoneAes` 发起解密、读取 `phoneMd5` 做等值匹配。
- 空对象 / 占位对象风险：
  - 不构造占位手机号；`buildPhoneSecurity` 返回 `null` 或掩码为空时按 `null` 兜底。
  - `phoneChannelSet`、`defaultMap` 等既有兜底 Map 行为不变。
- 调用顺序风险：
  - phone 覆盖必须晚于渠道价格 key 读取（`phoneChannelSet.getOrDefault(e.getPhone(), ...)`），否则渠道价格会用掩码查不到价格 —— 本次改动保持在原 `e.setPhone(e.getPhoneMask())` 同一位置（forEach 末尾），不前移。
  - 不存在“先返回明文再被后续覆盖”的窗口：补算分支内一次性赋值 mask/aes/md5/phone。
- 旧逻辑保持：
  - `phone_mask` 非空的主路径行为完全不变。
  - `getPermissionList` 权限过滤、分页、`lastUnionId`/`liveUser`、`channelEmp`/教辅、`bookQuestionRecord`、`empName`/`campName`/`empChatId`/`supplierName`/`dataLabel` 等装配不变。
  - 渠道价格 `phoneChannelSet` 仍以原始 `phone` 为 key（第 182、208 行逻辑不变）。
  - 不新增 MQ、Redis、Feign、DB 写入；仅新增 `DataSecurityInvoke.buildPhoneSecurity` 函数计算调用（在兜底分支）。
- 需要用户确认的设计选择：
  - 函数计算失败时 `phone` 返回 `null`、不回退明文 —— 已确认（D003-Q1）。
  - `phone_mask` 为空时逐条内联调用函数计算（每条一次远程调用），不批量 —— 已确认（D003-Q2）。

## 边界情况

- `phone_mask` 非空：直接返回掩码，不调用函数计算。
- `phone_mask` 为空、`phone` 为空：`phone` 返回 `null`，不调用函数计算。
- `phone_mask` 为空、`phone` 有值、函数计算成功：`phone=掩码`，回填 `phoneMask/phoneMd5/phoneAes`。
- `phone_mask` 为空、`phone` 有值、函数计算返回 `null` 或掩码为空：`phone` 返回 `null`，不泄露明文。
- 非标准手机号（`+61432563303`、`15781266352-1781`）：原样入参，不被 Java 侧格式校验拦截，由函数计算端正常加密处理。
- 性能边界：函数计算只在 `phone_mask` 为空的兜底分支触发；绝大多数行已回填 `phone_mask`，单页最多触发与“空掩码行数”相等次数的函数计算调用（详见假设/剩余风险）。

## 需求 *(必填)*

### 功能需求

- **FR-001**：`getPageList` 中，当 `phoneMask` 非空时，系统 MUST 让 `phone` 返回 `phoneMask`（保持现状）。
- **FR-002**：当 `phoneMask` 为空但 `phone` 非空时，系统 MUST 以原始 `phone` 为入参调用 `DataSecurityInvoke.buildPhoneSecurity` 进行掩码和 `phone_aes` 补算。
- **FR-003**：补算成功（返回非空且掩码非空）时，系统 MUST 同步设置 `phoneMask/phoneMd5/phoneAes`，并让 `phone` 返回补算出的掩码。
- **FR-004**：系统 MUST NOT 在调用函数计算前对手机号做合理性/格式校验（如 `isPlainPhone`、`isWritablePhoneInput`、长度/前缀判断）；`+61432563303`、`15781266352-1781` 等 MUST 原样进入函数计算。
- **FR-005**：补算返回为空或掩码为空时，系统 MUST 让 `phone` 返回 `null`，MUST NOT 回退返回明文 `phone`。
- **FR-006**：系统 MUST NOT 改变接口路径、分页入参、权限过滤、`phoneChannelSet` 渠道价格 key（仍用原始 `phone`）、其他字段装配顺序与异常处理。
- **FR-007**：实现后 MUST 通过静态检查或单元测试验证：函数计算入参为原始 `phone`、补算后 `phone=掩码`、补算失败 `phone=null`、`phoneMask` 主路径不调用函数计算。

## 成功标准 *(必填)*

- **SC-001**：`AppletUserPoolServiceImpl` 中原 `e.setPhone(e.getPhoneMask());` 已替换为“掩码优先 + 空掩码走函数计算补算 + 失败兜底 null”的分支。
- **SC-002**：补算分支调用 `DataSecurityInvoke.buildPhoneSecurity(e.getPhone())`，入参为原始 `phone`，且代码中不含针对该入参的格式校验。
- **SC-003**：补算成功时输出对象 `phone=掩码` 且 `phoneMask/phoneMd5/phoneAes` 完整；补算失败时 `phone=null`。
- **SC-004**：`phone_mask` 非空主路径与其他字段装配、权限、分页行为无回归。
- **SC-005**：目标文件通过静态验证；目标模块编译通过，或记录明确的环境阻塞原因。

## 假设

- `drh_applet_user` 的 `phone`、`phone_mask`、`phone_md5`、`phone_aes` 字段已存在且被 `selectPoolPage` 选出（已确认）。
- `DataSecurityInvoke.buildPhoneSecurity` 内部不做手机号合理性校验，国际号/带后缀号会原样提交函数计算（已核对：仅 `normalizePhoneInput` 对疑似 AES 密文做解密，长度 < 20 的输入原样透传）。
- 函数计算端（`DataSecurity-pro`）能对非标准手机号正常返回掩码/MD5/AES（用户口径）。
- 生产数据中绝大多数行已回填 `phone_mask`，`phone_mask` 为空的兜底分支为少量历史残留，逐条函数计算调用量可接受（用户已确认逐条内联）。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档（AGENTS.md、spec.md、tasks.md、checklists/requirements.md）。
- 已完成代码事实确认：入口 `AppletUserPoolServiceImpl.getPageList`；数据来源 `AppletUserPoolMapper.xml#selectPoolPage`（返回 `phone/phoneMask/phoneMd5/phoneAes`）；函数计算工具 `DataSecurityInvoke.buildPhoneSecurity`；同类既有写法 `OrderRefundRecordServiceImpl`。
- 已完成历史问题防漏分析与强制门禁检查（参数来源、赋值时机、调用顺序、明文不泄露不变量）。

### D002 - 实现记录

- 实现内容：将 `AppletUserPoolServiceImpl.getPageList` 中 `records.forEach` 末尾的 `e.setPhone(e.getPhoneMask());` 替换为：
  - `phoneMask` 非空 → `phone = phoneMask`；
  - `phoneMask` 为空且 `phone` 非空 → `DataSecurityInvoke.buildPhoneSecurity(e.getPhone())` 补算，成功则回填 `phoneMask/phoneMd5/phoneAes` 并 `phone = 掩码`，失败则 `phone = null`；
  - 其余情况 → `phone = null`。
  - 新增 `import com.drh.common.fc.datasec.DataSecurityInvoke;`。
- 测试命令：见 `tasks.md` D002。
- 测试结果：见 `tasks.md` D002。
- 自检结论：入参为原始 `phone`、无格式校验；明文不泄露不变量保持；`phoneMask` 主路径与其他装配无回归；渠道价格 key 仍用原始 `phone`。

### D003 - 设计确认记录

- 触发原因：实现前对“函数计算失败时 phone 兜底”与“是否逐条调用函数计算”两处设计点向用户确认。
- 修正内容：
  - Q1：函数计算失败（返回 `null` 或掩码为空）时，`phone` 返回 `null`，不回退明文（确认采用）。
  - Q2：`phone_mask` 为空时逐条内联调用函数计算、保持最小改动（确认采用），不改批量。
- 文档同步：已写入 `spec.md`（FR-005、历史问题防漏分析、假设）、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 验证结果：实现按确认口径落地，见 D002。
