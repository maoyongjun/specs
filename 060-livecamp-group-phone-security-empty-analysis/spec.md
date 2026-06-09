# 功能规格：LiveCampGroup 手机号安全字段为空原因分析

**功能目录**：`060-livecamp-group-phone-security-empty-analysis`  
**创建日期**：`2026-06-09`  
**状态**：Analysis  
**输入**：分析 `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\controller\LiveCampGroupController.java` 的返回值，说明截图中 `phoneAes`、`phoneMask`、`phoneMd5` 为空的原因；在 `C:\workspace\ju-chat\specs` 创建 spec-kit 文档。

## 背景

- 当前问题：接口返回里 `phone` 作为手机号展示字段，需要返回 `phoneMask` 脱敏值，同时 `phoneAes`、`phoneMask`、`phoneMd5` 不能为空。
- 当前行为：截图字段同时包含 `preCampId`、`qyvxUserId`、`qyvxUserName`，与 `GroupLiveBaseOutput` 返回结构一致，入口对应 `POST /liveCampGroup/live/base/v3`。
- 直接原因：`liveStudentBaseV3` 普通用户分支从 `HandoverPlus` 分页结果手动转换为 `GroupLiveBaseOutput`，历史实现只处理展示手机号，遗漏 `setPhoneMask`、`setPhoneMd5`、`setPhoneAes`；新要求下展示字段 `phone` 使用 `LiveUser.phoneMask`。
- 非目标：本阶段不修改 `drh-kk-cms` 业务代码、不改数据库、不新增接口、不调整手机号加密算法。

## 用户场景与测试

### 用户故事 1 - 定位空字段原因（优先级：P1）

研发需要知道 `LiveCampGroupController` 返回中手机号安全字段为空是数据库无值、SQL 未查出，还是 DTO 组装漏字段。

**独立测试**：静态检查 controller、service、DTO、mapper 字段链路，确认普通用户 V3 分支的赋值行为。

**验收场景**：

1. **Given** 请求 `POST /liveCampGroup/live/base/v3` 且 `StudentBaseInputV3#getIsSpecail() == YesNoEnum.NO.getCode()`（普通用户分支），**When** 返回 `GroupLiveBaseOutput`，**Then** `phone` 来自 `LiveUser.phoneMask` 脱敏值，且 `phoneMask/phoneMd5/phoneAes` 均被赋值。
2. **Given** 请求 V2 普通用户或 V3 特殊用户分支，**When** mapper 直出 `GroupLiveBaseOutput`，**Then** SQL 中已 select `phone_mask phoneMask`、`phone_md5 phoneMd5`、`phone_aes phoneAes`。

### 用户故事 2 - 后续修复边界（优先级：P2）

研发后续修复时只补齐返回 DTO 的安全字段，不扩大接口和查询行为。

**独立测试**：对 `transRecordsToOutPuts` 增加断言或静态检查，确认 `LiveUser` 的三个安全字段被复制到 `GroupLiveBaseOutput`。

**验收场景**：

1. **Given** `LiveUser` 中 `phoneMask/phoneMd5/phoneAes` 有值，**When** 经过 V3 普通用户分支组装，**Then** 返回 DTO 中 `phone` 等于 `phoneMask`，且对应安全字段有值。
2. **Given** `LiveUser` 不存在或数据库字段本身为空，**When** 使用空对象 fallback，**Then** 返回安全字段仍为空且不抛异常。

## 代码事实

- Controller 入口：`LiveCampGroupController` 中 `@PostMapping("live/base/v3")` 直接返回 `liveCampGroupService.liveStudentBaseV3(input)`。
- 返回 DTO：`GroupLiveBaseOutput` 定义了 `phone`、`phoneMask`、`phoneMd5`、`phoneAes`。
- 字段来源：`LiveUser` 实体定义了同名手机号字段，映射表为 `drh_live_user`。
- 普通用户 V3 分支：
  - `liveStudentBaseV3` 在 `StudentBaseInputV3#getIsSpecail() == YesNoEnum.NO.getCode()` 时调用 `handoverPlusService.getPlusPageListByStuHandoverTypeAndCampId(...)` 获取 `HandoverPlus` 分页。
  - 随后调用 `transRecordsToOutPuts(plusPage.getRecords(), stopPlusIds)` 手动组装 `GroupLiveBaseOutput`。
  - `transRecordsToOutPuts` 通过 `liveUserService.getMapByIds(liveUserIdSet)` 获取 `LiveUser`，当前应复制 `phoneMask/phoneMd5/phoneAes`，并将 `phone` 设置为 `phoneMask` 脱敏展示值。
- 对照旧逻辑：
  - `HandoverPlusDelMapper.xml#getStuPageList` 的 V2 普通用户 SQL 已 select `lu.phone_mask phoneMask`、`lu.phone_md5 phoneMd5`、`lu.phone_aes phoneAes`。
  - `SpecialUserCampMapper.xml#getStuPageListV3` 的 V3 特殊用户 SQL 也已 select `lu.phone_mask phoneMask`、`lu.phone_md5 phoneMd5`、`lu.phone_aes phoneAes`。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `phone`：来源 `LiveUser.phoneMask`；赋值时机 `transRecordsToOutPuts` 和旧版 `liveStudentBase` 当前层手动赋值；返回位置 `GroupLiveBaseOutput.phone`，用于脱敏展示。
  - `phoneMask`：来源 `LiveUser.phoneMask`；已在普通用户 V3 分支和旧版 `liveStudentBase` 手动组装时赋值；返回位置 `GroupLiveBaseOutput.phoneMask`。
  - `phoneMd5`：来源 `LiveUser.phoneMd5`；已在普通用户 V3 分支和旧版 `liveStudentBase` 手动组装时赋值；返回位置 `GroupLiveBaseOutput.phoneMd5`。
  - `phoneAes`：来源 `LiveUser.phoneAes`；已在普通用户 V3 分支和旧版 `liveStudentBase` 手动组装时赋值；返回位置 `GroupLiveBaseOutput.phoneAes`。
- 下游读取字段清单：
  - 前端或调用方读取 `phone` 作为脱敏展示值，读取 `phoneMask`、`phoneMd5`、`phoneAes` 作为展示、解密或安全查询依据。
  - `processEmpQwInfo` 后续补充 `qyvxUserId`、`qyvxUserName`，与手机号安全字段无关。
- 空对象 / 占位对象风险：
  - `userMap.getOrDefault(rd.getLiveUserId(), new LiveUser())` 会在找不到用户时返回空 `LiveUser`，导致所有手机号字段为空。这是容错行为，但后续修复不能把它误判成正常数据。
- 调用顺序风险：
  - `processEmpQwInfo`、`getUnionIdSendDegreeMap`、`processStuStage`、`handleAppPassport` 均不会补齐手机号安全字段；必须在 `transRecordsToOutPuts` 组装 DTO 时显式赋值。
- 旧逻辑保持：
  - 不改变 `stuStage`、`campId`、`isSpecail`、`empFriend`、`unionId`、`studentCalculateClassFlag` 等过滤条件。
  - 不改变长期班分支、特殊用户分支、V2 接口、分页总数、多企微账号补充、群发次数补充、App 注册状态补充。
- 需要用户确认的设计选择：
  - 已确认新要求：`GroupLiveBaseOutput.phone` 返回 `LiveUser.phoneMask`，不再返回明文手机号。

## 边界情况

- `LiveUser` 数据库记录存在但 `phone_mask/phone_md5/phone_aes` 本身为空：返回仍为空，需要数据补偿或写入链路处理，不属于当前 DTO 漏赋值问题。
- `liveUserIdSet` 为空：`liveUserService.getMapByIds` 返回空 map，DTO 不应抛错。
- `userMap` 未命中某个 `liveUserId`：当前空对象 fallback 保持不抛错，但手机号及安全字段为空。
- 特殊用户、长期班、V2 普通用户：目前从 mapper 直出，SQL 已包含安全字段，不是截图所示问题的主因。

## 需求

### 功能需求

- **FR-001**：文档 MUST 明确截图对应的高概率入口为 `POST /liveCampGroup/live/base/v3` 与 `GroupLiveBaseOutput`。
- **FR-002**：文档 MUST 说明普通用户 V3 分支中 `transRecordsToOutPuts` 漏拷贝 `phoneMask/phoneMd5/phoneAes` 是安全字段为空的直接原因。
- **FR-003**：文档 MUST 区分 DTO 漏赋值与数据库字段本身为空两类问题。
- **FR-004**：后续实现 SHOULD 在 `transRecordsToOutPuts` 中从 `LiveUser` 复制 `phoneMask`、`phoneMd5`、`phoneAes` 到 `GroupLiveBaseOutput`，并保留旧过滤和分页逻辑。
- **FR-005**：系统 MUST 让 `GroupLiveBaseOutput.phone` 返回 `LiveUser.phoneMask` 脱敏展示值。

## 成功标准

- **SC-001**：可以用代码链路解释为什么 `phone` 应返回脱敏值，以及 `phoneAes/phoneMask/phoneMd5` 的来源。
- **SC-002**：后续修复点限定在 `GroupLiveBaseOutput` 手动 DTO 组装，避免误改 mapper、数据库或加密组件。
- **SC-003**：文档包含后续实现和验证任务，且无模板占位残留。

## 假设

- 截图来自 `POST /liveCampGroup/live/base/v3` 的普通用户分支，因为截图字段同时出现 `preCampId`、`qyvxUserId`、`qyvxUserName`，与 `GroupLiveBaseOutput` 更匹配。
- `StudentBaseInputV3#getIsSpecail()` 根据 `stuStage` 派生普通用户或特殊用户分支，当前结论针对 `YesNoEnum.NO` 的普通用户分支。
- 未连接数据库确认具体用户记录的 `drh_live_user.phone_*` 是否有值；若数据库字段本身为空，需要追加数据补偿分析。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成 `LiveCampGroupController`、`LiveCampGroupServiceImpl`、`GroupLiveBaseOutput`、`LiveUser`、V2 普通用户 mapper、V3 特殊用户 mapper 的静态分析。
- 结论：截图中的安全字段为空，直接原因是 `liveStudentBaseV3` 普通用户分支手动组装 DTO 时只设置展示字段，漏设置 `phoneMask`、`phoneMd5`、`phoneAes`；新要求下 `phone` 展示字段应使用 `phoneMask`。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：在 `LiveCampGroupServiceImpl#transRecordsToOutPuts` 让 `phone` 来源为 `LiveUser.phoneMask`，并返回 `phoneMask`、`phoneMd5`、`phoneAes`；同时确认旧版 `liveStudentBase` 手动组装 `GroupLiveBaseOutput` 时 `phone` 也使用 `phoneMask`，三类安全字段均已返回。
- 补充检查：确认 `GroupLiveDetailOutput` 本身没有 `phoneMask/phoneMd5/phoneAes` 字段，不属于同类漏点；确认 `GroupLiveBaseOutput` 仅有两个手动 `new` 点，均已覆盖；mapper 直出路径已包含 `phone_*` 别名。
- 测试命令：`git -C C:\workspace\drh diff --check -- drh-kk-cms/src/main/java/com/drh/kk/cms/service/impl/LiveCampGroupServiceImpl.java`
- 测试结果：通过；仅有 Git 换行提示 `LF will be replaced by CRLF`，无空白错误。
- 自检结论：本次未改变接口契约和 DTO 字段定义；数据库字段本身为空的数据仍需另行补偿。
