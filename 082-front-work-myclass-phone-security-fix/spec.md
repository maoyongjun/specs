# 功能规格：FrontWork/FrontMyClass 手机号安全补遗

**功能目录**：`082-front-work-myclass-phone-security-fix`  
**创建日期**：`2026-06-12`  
**状态**：Draft  
**输入**：用户要求在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档：之前做过手机号加密的整改，`C:\workspace\drh\drh-kk-cms` 的 `com.drh.kk.cms.controller.FrontWorkController#queryList` 没有改全，返回的有 `phone` 字段，需要返回加密字段，并且 `phone` 改回返回掩码；并检查其他类似的没有改全的地方进行修改。

## 背景

- 当前问题：历史手机号安全整改（032/036/048/066/067/073/080 系列）的统一口径是对外接口不返回明文 `phone`，改为返回 `phoneMask/phoneMd5/phoneAes` 三字段，`phone` 放掩码展示值。`FrontWorkController#queryList` 漏改：`FrontWorkServiceImpl:337` 仍 `queryListDto.setPhone(appletUser.getPhone())` 返回明文，且 `QueryListDto`（drh-common）只有 `phone` 字段。排查发现同文件与 `FrontMyClassController` 共 7 处同类漏改。
- 当前行为：
  - `front/work/queryList`（`FrontWorkServiceImpl:337`）、`front/work/queryListV2`（L649）向 `QueryListDto.phone` 写明文；
  - `front/work/queryUserDetail`（L736）向 `AppletUserDetailDto.phone` 写明文（该 DTO 已有三件套字段但未赋值）；
  - `front/myClass/user/list`、`/user/pageList`（`FrontMyClassUserServiceImpl:295` builder）向 `FrontMyClassUserVo.phone` 写明文；
  - `front/myClass/live/single/list`（`FrontMyClassLiveSingleServiceImpl:842` `BeanUtil.copyProperties(user, vo)`）向 `FrontMyClassLiveSingleListVo.phone` 拷明文；
  - `front/myClass/dataBoard/orderPage`（realtime 策略活实现为 `FrontMyClassOrderBoardServiceImplV2:344` builder）向 `FrontMyClassBoardOrderVo.phone` 写明文；`/dataBoard/exportOrder` 的 CSV（`FrontMyClassPayBoardCsv:42`/`FrontMyClassRefundBoardCsv:42`）从该 Vo 拷贝，导出文件含明文。
  - 查询入参链路已整改（`FrontWorkServiceImpl:107`、`FrontMyClassBaseServiceImpl:172` 用 `phoneMd5` 等值查询），不在本次问题内。
- 目标行为：上述接口返回记录 `phone` 为掩码展示值（`DataSecurityInvoke.phoneMaskForDisplay(phoneMask, phoneAes)`，mask/aes 均空且实体 `phone` 为 11 位明文时本地 `DataSecurityUtil.maskPhone` 兜底），同时透传 `phoneMask/phoneMd5/phoneAes`。`/live/single/list` 在 controller 边界掩码，service 内部返回保持明文，短信/外呼复用链路不变。
- 非目标：
  - 不修改查询 SQL、接口路径、HTTP 方法、分页语义、DDL、宽表生成链路、`phone` 字段名称。
  - 不改变服务端内部需要明文的旧行为：`FrontWorkServiceImpl#sendShortMsg`（L1231-1244 发短信）、`#queryUserDetail` L716-717 明文前 7 位查归属地、`SmsTriggerSingleLiveUserServiceImpl`/`SmsTriggerFollowLiveUserServiceImpl`/`OutboundFollowLiveUserServiceImpl` 内部调 `liveList()` 读明文。
  - task 策略 `orderPage`（`FrontEmpClassOrderServiceImpl:81`，宽表 `drh_front_emp_class_order` 实体只有明文 `phone` 无安全字段）排除出本次范围，记录为已知缺口，后续独立规格处理（用户已确认）。线上默认 `front.class.strategy=realtime`。
  - 死代码不动：V1 `FrontMyClassOrderBoardServiceImpl`（`@Service` 已注释）、`FrontMyClassPayBoardVo`/`FrontMyClassRefundBoardVo`（全工程无引用）。
  - `/live/summary/*` 不涉及（`FrontMyClassLiveSummaryListVo` 无 phone 字段）。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 工作台列表/详情不返回明文手机号（优先级：P1）

销售在大前端工作台调用 `front/work/queryList`、`queryListV2`、`queryUserDetail` 时，`phone` 必须为掩码展示值，并可获得 `phoneMask/phoneMd5/phoneAes` 用于后续受控处理。

**独立测试**：静态确认 `FrontWorkServiceImpl` 三处赋值改为 `phoneMaskForDisplay` + 三件套；`QueryListDto` 含三件套字段。

**验收场景**：

1. **Given** `AppletUser.phoneMask=138****5678`，**When** 调用 `queryList`，**Then** 返回记录 `phone=138****5678` 且 `phoneMask/phoneMd5/phoneAes` 与实体一致。
2. **Given** `phoneMask` 为空、`phoneAes` 有值，**When** 调用 `queryListV2`，**Then** `phone` 由 `phoneMaskForDisplay` 解密后掩码生成。
3. **Given** `phoneMask/phoneAes` 均空、实体 `phone` 为 11 位明文（历史未回填数据），**When** 调用 `queryUserDetail`，**Then** `phone` 为本地 `maskPhone` 掩码，不透出明文。
4. **Given** 入参带手机号查询条件，**When** 调用 `queryList`，**Then** 仍按 `phoneMd5` 等值查询（L107 旧逻辑不变）。

### 用户故事 2 - 我的班级系列不返回明文手机号（优先级：P1）

销售在"我的班级"调用 `/user/list`、`/user/pageList`、`/live/single/list`、`/dataBoard/orderPage`、`/dataBoard/exportOrder` 时，`phone` 必须为掩码展示值并携带三件套；CSV 导出文件中 `phone` 列同样为掩码。

**独立测试**：静态确认 `FrontMyClassUserVo/LiveSingleListVo/BoardOrderVo` 含三件套；`FrontMyClassUserServiceImpl`、`FrontMyClassOrderBoardServiceImplV2` 组装时掩码；`FrontMyClassController#liveSingleList` 返回前边界掩码。

**验收场景**：

1. **Given** 班级学员有安全字段，**When** 调用 `/user/list` 或 `/user/pageList`，**Then** 每条记录 `phone` 为掩码且三件套透传（PageVo 包同一 Vo）。
2. **Given** 学员有安全字段，**When** 调用 `/live/single/list`，**Then** controller 返回的每条 `phone` 为掩码、三件套透传。
3. **Given** 订单看板数据（realtime 策略 V2），**When** 调用 `/dataBoard/orderPage`，**Then** `phone` 为掩码、三件套透传。
4. **Given** 同上，**When** 调用 `/dataBoard/exportOrder` 导出 CSV，**Then** CSV `phone` 列为掩码（CSV 由掩码后的 Vo 拷贝）。

### 用户故事 3 - 短信/外呼等内部明文链路不回归（优先级：P1）

短信触达与外呼服务内部复用 `liveList()` 获取明文手机号发送短信/拨打电话；工作台 `sendShortMsg` 用明文发短信；`queryUserDetail` 用明文前 7 位查归属地。本次修复后这些链路必须保持拿到明文，行为不变。

**独立测试**：静态确认 `FrontMyClassLiveSingleServiceImpl#getLiveSingleListVos` 仍写明文 `phone`（不在 service 层掩码）；`SmsTrigger*`/`Outbound*`、`sendShortMsg`、归属地代码零改动。

**验收场景**：

1. **Given** 短信触达任务调用 `getStrategy().liveList(singleDto)`，**When** 读取 `vo.getPhone()`，**Then** 仍为明文，可通过手机号格式校验并发送短信。
2. **Given** 工作台发短信 `sendShortMsg`，**When** 组装 `LivePhoneDto` 和 `phones`，**Then** 仍用明文（L1231-1244 不变）。
3. **Given** `queryUserDetail` 查归属地，**When** 取明文前 7 位查 `PhoneSegment`，**Then** 城市/城市级别输出不变（L716-724 不变）。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `QueryListDto.phoneMask/phoneMd5/phoneAes`：来源 `AppletUser.phoneMask/phoneMd5/phoneAes`（实体已有字段，`drh_applet_user` 已在历史回填 7 表之列）；赋值时机 `FrontWorkServiceImpl#queryList/#queryListV2` 逐条组装记录时；下游读取位置为前端展示。
  - `QueryListDto.phone`：来源 `phoneMaskForDisplay(phoneMask, phoneAes)` 现算展示值；组装记录时赋值。
  - `AppletUserDetailDto.phone*`：同上，`#queryUserDetail` 组装时赋值（DTO 字段已存在，仅补赋值）。
  - `FrontMyClassUserVo.phone*`：来源 `AppletUser` 同名字段；`FrontMyClassUserServiceImpl#getMyClassUserVos` builder 时赋值；`userList` 与 `pageList` 共用。
  - `FrontMyClassLiveSingleListVo.phoneMask/phoneMd5/phoneAes`：Vo 加字段后由 `BeanUtil.copyProperties(user, vo)`（hutool 同名拷贝）自动携带；`phone` 掩码在 `FrontMyClassController#liveSingleList` 返回前边界赋值（service 内部保持明文）。
  - `FrontMyClassBoardOrderVo.phone*`：来源 `AppletUser`（V2 `initOrderVo` 从 `context.userIdUserMap` 取实体）；builder 时赋值。
- 下游读取字段清单：
  - `FrontWorkController#queryList/#queryListV2/#queryUserDetail` 读取 service 返回对象直接响应前端。
  - `FrontWorkServiceImpl#getAllInfo`（L691）内部调 `queryListV2`，只读 `unionId/appletUserId`——掩码化无影响。
  - `SmsTriggerSingleLiveUserServiceImpl:426/431/440`、`SmsTriggerFollowLiveUserServiceImpl:~456`、`OutboundFollowLiveUserServiceImpl:~474` 内部调 service 层 `liveList()` 读 `vo.getPhone()` 明文——边界掩码方案下不变。
  - `FrontMyClassOrderBoardServiceImplV2` 导出链路从 `FrontMyClassBoardOrderVo` `BeanUtils.copyProperties` 到 `FrontMyClassPayBoardCsv/RefundBoardCsv`——Vo 掩码后 CSV 自动得掩码。
- 空对象 / 占位对象风险：
  - 否。空列表/空页直接返回；不构造占位记录；不把空安全字段当有效值（mask/aes 均空时本地兜底或保持 null）。
- 调用顺序风险：
  - 否。所有赋值在组装记录时同步完成；`/live/single/list` 边界掩码发生在 service 返回后、controller 响应前，无异步补齐。
- 旧逻辑保持：
  - 查询入参 `phoneMd5` 等值查询（`FrontWorkServiceImpl:107`、`FrontMyClassBaseServiceImpl:172`）；
  - 等级筛选/在线出勤/支付录单/标签/群发次数/沟通次数等组装逻辑；分页与内存分页逻辑；
  - `sendShortMsg` 明文发短信；归属地明文前 7 位查询；SmsTrigger/Outbound 明文复用；
  - `getAllInfo` 的 unionId/appletUserId 提取；CSV 导出列结构（仅 `phone` 值变为掩码）。
- 需要用户确认的设计选择：
  - 已确认（2026-06-12）：① 范围 = FrontWork 三方法 + FrontMyClass 系列全部修复；② `/live/single/list` 用 controller 边界掩码，短信/外呼零改动；③ task 策略宽表路径排除出本次范围。

## 边界情况

- `phoneMask` 非空：直接作为 `phone` 展示值。
- `phoneMask` 空、`phoneAes` 有值：`phoneMaskForDisplay` 解密后掩码（既有逻辑，含 FC 失败时本地 AES 解密兜底）。
- `phoneMask/phoneAes` 均空、实体 `phone` 为 11 位明文：本地 `DataSecurityUtil.maskPhone` 兜底，不透出明文。
- `phoneMask/phoneAes` 均空、实体 `phone` 为空或非 11 位明文：`phone` 返回 null/原掩码值，不抛异常（与既有已整改接口口径一致）。
- 返回列表为空：直接返回，不额外处理。
- `FrontMyClassUserVo/LiveSingleListVo/BoardOrderVo` 带 `@Builder+@AllArgsConstructor`，加字段会改全参构造器签名：已确认改前需 grep 无直接全参 `new XxxVo(...)` 调用（Lombok 生成，源码中仅 builder 使用）。
- task 策略宽表路径：本次不动，`front.class.strategy=task` 时 `orderPage` 仍返回明文——已知缺口，记录于假设，后续独立规格。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 为 `drh-common QueryListDto` 增加 `phoneMask/phoneMd5/phoneAes` 字段。
- **FR-002**：系统 MUST 在 `FrontWorkServiceImpl#queryList`（L337）、`#queryListV2`（L649）、`#queryUserDetail`（L736）将 `phone` 改为 `phoneMaskForDisplay` 展示值并同步赋值三件套。
- **FR-003**：系统 MUST 为 `FrontMyClassUserVo`、`FrontMyClassLiveSingleListVo`、`FrontMyClassBoardOrderVo` 增加 `phoneMask/phoneMd5/phoneAes` 字段。
- **FR-004**：系统 MUST 在 `FrontMyClassUserServiceImpl#getMyClassUserVos`、`FrontMyClassOrderBoardServiceImplV2#initOrderVo` 组装时将 `phone` 掩码并赋值三件套。
- **FR-005**：系统 MUST 在 `FrontMyClassController#liveSingleList` 返回前对每条记录边界掩码 `phone`（三件套由 copyProperties 自动携带）；`FrontMyClassLiveSingleServiceImpl` service 层 MUST 保持 `phone` 明文。
- **FR-006**：掩码展示 MUST 使用 `DataSecurityInvoke.phoneMaskForDisplay(phoneMask, phoneAes)`；mask/aes 均空且实体 `phone` 为 11 位明文时 MUST 本地 `DataSecurityUtil.maskPhone` 兜底；任何分支 MUST NOT 向前台返回对象写入明文手机号。
- **FR-007**：系统 MUST NOT 修改：查询 SQL 与 `phoneMd5` 查询链路、接口路径、分页语义、`sendShortMsg` 明文发短信、归属地明文查询、SmsTrigger/Outbound 明文复用、task 策略宽表路径、DDL。
- **FR-008**：验证 MUST 包含编译与静态扫描：范围内无残留明文 `setPhone(xxx.getPhone())` / `.phone(xxx.getPhone())` 流向前台返回对象；四处内部明文旧行为未被误改。

## 成功标准 *(必填)*

- **SC-001**：`QueryListDto`、`FrontMyClassUserVo`、`FrontMyClassLiveSingleListVo`、`FrontMyClassBoardOrderVo` 均含 `phoneMask/phoneMd5/phoneAes` 字段。
- **SC-002**：`FrontWorkServiceImpl` L337/L649/L736 三处、`FrontMyClassUserServiceImpl` L295、`FrontMyClassOrderBoardServiceImplV2` L344 组装处均改为掩码+三件套；`FrontMyClassController#liveSingleList` 有边界掩码。
- **SC-003**：静态扫描确认 `FrontMyClassLiveSingleServiceImpl#getLiveSingleListVos` 仍输出明文 `phone`；`SmsTrigger*`/`Outbound*`/`sendShortMsg`/归属地代码零改动。
- **SC-004**：`drh-common`、`drh-kk-cms` 编译通过；若本地 Maven 依赖阻塞，记录原因与替代静态验证结果。
- **SC-005**：范围内 grep 无"有 `phone` 返回但组装明文"的残留（task 宽表路径除外，已记录为已知缺口）。

## 假设

- `drh_applet_user` 安全三字段已由历史回填规格（036/069 系列）治理；本规格不负责数据回填。
- 线上 `front.class.strategy` 默认 `realtime`；task 策略宽表 `drh_front_emp_class_order` 无安全字段，该路径明文返回为已知缺口，后续独立规格处理宽表加列+生成链路。
- `specs/081-ad-user-pic-list-phone-security-fix` 为空壳目录（无文件），本规格使用编号 082。
- hutool `BeanUtil.copyProperties` 按同名属性拷贝，Vo 增加三件套后自动从 `AppletUser` 携带；实现时以编译+静态确认。
- `phoneMd5/phoneAes` 对外暴露口径沿用前序手机号安全接口整改规格（048/052/065/080）。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档（2026-06-12）。
- 已完成历史问题防漏分析和强制门禁检查：8 处漏改点（A1-A3、B1-B5）及行号已逐一亲自核对；短信/外呼/发短信/归属地四处内部明文链路已识别并锁定不变；task 宽表缺口已确认排除。
- 用户已确认三项设计决策：A+B 全范围、controller 边界掩码、task 路径排除。
- 本阶段未修改业务代码。

### D002 - 实现记录

- `<实现后填写：实现内容、影响范围、测试命令、测试结果、自检结论。>`

### D003 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
