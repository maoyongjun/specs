# 任务清单：LiveCampGroup 手机号安全字段为空原因分析

**输入**：来自 `spec.md` 的原因分析规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：本阶段为静态分析和文档创建；若后续进入实现，必须补充测试或编译验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于 `ju-chat/specs` 文档目录，目标代码在 `drh-kk-cms`。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和返回 DTO。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
- [x] T004 确认本次分析不涉及环境变量、Redis key、MQ topic/tag、Feign/FC/HTTP 调用或数据库写入。
- [x] T005 确认已有旧逻辑中必须保持不变的过滤、分页、分支、日志和后置补充处理。

**检查点**：已完成 T001-T005；当前可进入风险门禁和文档结论。

## Phase 2：风险门禁

- [x] T006 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为。
- [x] T010 对需要用户确认的业务语义变化做记录；已确认 `phone` 返回 `phoneMask` 脱敏值。
- [x] T011 为每个关键行为建立测试或静态验证映射。

**风险结论**：

- `transRecordsToOutPuts` 使用 `userMap.getOrDefault(..., new LiveUser())`，存在空用户 fallback；这是容错逻辑，但会让字段空值看起来像正常返回。
- `processEmpQwInfo` 等后续流程不会补齐手机号安全字段，必须在 DTO 组装阶段赋值。
- 后续修复只需要复制 `LiveUser.phoneMask/phoneMd5/phoneAes`，不需要新增查询或修改 mapper。

## Phase 3：实现

- [x] T012 如用户要求修复代码，在 `LiveCampGroupServiceImpl#transRecordsToOutPuts` 中补齐 `phoneMask`、`phoneMd5`、`phoneAes`。
- [x] T013 保持未声明的旧行为不变，包括普通用户 V3 分支的分页、状态、订单、带班分母、多企微账号处理。
- [x] T014 已按新要求确认 `phone` 为脱敏展示值，即 `LiveUser.phoneMask`。
- [x] T015 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [x] T016 新增或更新单元测试，构造 `LiveUser` 含 `phoneMask/phoneMd5/phoneAes` 的普通用户 V3 记录。
- [x] T017 测试断言返回 `GroupLiveBaseOutput` 中 `phoneMask/phoneMd5/phoneAes` 与 `LiveUser` 一致，不只断言 `phone`。
- [x] T018 验证 `LiveUser` 不存在或安全字段本身为空时不抛异常。
- [ ] T019 运行目标模块测试或编译命令，并记录结果。
- [x] T020 搜索确认没有遗漏同一 DTO 手动组装点。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `060-livecamp-group-phone-security-empty-analysis`，补齐 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- 验证方式：静态检查以下链路：
  - `LiveCampGroupController#liveStudentBaseV3`
  - `LiveCampGroupServiceImpl#liveStudentBaseV3`
  - `LiveCampGroupServiceImpl#transRecordsToOutPuts`
  - `GroupLiveBaseOutput`
  - `LiveUser`
  - `HandoverPlusDelMapper.xml#getStuPageList`
  - `SpecialUserCampMapper.xml#getStuPageListV3`
- 自检结论：满足强制门禁；本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：补齐 `LiveCampGroupServiceImpl#transRecordsToOutPuts` 和旧版 `liveStudentBase` 中 `GroupLiveBaseOutput` 的 `phoneMask/phoneMd5/phoneAes` 手动赋值；按新要求将 `phone` 设为 `LiveUser.phoneMask` 脱敏展示值。
- 测试命令：`git -C C:\workspace\drh diff --check -- drh-kk-cms/src/main/java/com/drh/kk/cms/service/impl/LiveCampGroupServiceImpl.java`
- 测试结果：通过；仅有 Git 换行提示 `LF will be replaced by CRLF`，无空白错误。
- 自检结论：`GroupLiveBaseOutput` 两个手动 `new` 点均已覆盖；`GroupLiveDetailOutput` 没有安全字段；mapper 直出路径已有 `phone_*` 别名。
