# 任务清单：手机号安全字段与地区映射

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`、`phone-security-region-mapping-ddl.sql`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 确认规格目录为 `079-phone-security-region-mapping`，目标为创建手机号安全字段与省市映射规格。
- [x] T002 确认 DRH 项目路径为 `C:\workspace\drh`。
- [x] T003 确认 KKHC 项目路径为 `C:\workspace\ju-chat\kkhc`。
- [x] T004 确认 DRH 重点入口为 `drh-endpoint`、`drh-callback` 的 `PhoneSegmentServiceImpl#getUserProvinceV2(AppletUser)` 和 `getCity(String)`。
- [x] T005 确认 KKHC 重点入口为 `kkhc-idc\broadcast` 的 `PhoneSegmentServiceImpl#getCity(String)` 和 `getCity(LiveUser)`。
- [x] T006 确认现有 `PhoneSegment` 实体映射表为 `phone_segment`，字段包含 `segment/province/city`。
- [x] T007 确认现有手机号安全工具包含 `DataSecurityInvoke.buildPhoneSecurity()` 和 `computePhoneMd5()`。
- [x] T008 确认用户补充约束：`drh_phone_security_region` 不保存 `segment`。

**检查点**：代码事实已确认；本阶段只创建规格文档，不修改业务代码。

## Phase 2：风险门禁

- [x] T009 检查关键参数来源：手机号来自现有入参或实体；`segment` 来自手机号前 7 位；省市来自 `phone_segment`；安全字段来自 `DataSecurityInvoke`。
- [x] T010 检查下游读取字段：现有业务读取 `PhoneSegment.city/province`，新增映射只读取 `phoneMask/phoneMd5/phoneAes/province/city`。
- [x] T011 检查占位对象风险：空手机号、短手机号、号段未命中继续返回空 `PhoneSegment`，不得写空映射。
- [x] T012 检查调用顺序风险：必须先解析省市，再按 `phone_md5` 幂等写映射。
- [x] T013 检查数据库风险：新增表和索引，且 DDL 明确不包含 `segment` 字段。
- [x] T014 检查缓存风险：默认服务内缓存 `segment -> PhoneSegment`，不新增 Redis key 契约。
- [x] T015 检查旧逻辑保持：不修改 Controller、MQ、Redis、Feign、原省市字段语义和异常返回口径。

**检查点**：风险门禁已写入规格；实现前必须再次确认目标分支代码未漂移。

## Phase 3：实现任务

- [x] T016 在 DRH common 新增共享 `PhoneSecurityRegion` 实体，并在运行模块新增 Mapper/Recorder，字段不得包含 `segment`。
- [x] T017 在 KKHC base-common 新增共享 `PhoneSecurityRegion` 实体，并在运行模块新增 Mapper/Recorder，字段不得包含 `segment`。
- [x] T018 提交 `phone-security-region-mapping-ddl.sql`，执行前检查表是否已存在；本次未执行 DDL。
- [x] T019 恢复 DRH `PhoneSegmentService` 原职责，不在其中触发映射写入。
- [x] T020 恢复 KKHC `PhoneSegmentService` 原职责，不在其中触发映射写入。
- [x] T021 在 recorder 中增加服务内缓存 `segment -> PhoneSegment`，缓存 key 不落库。
- [x] T022 在 `DataSecurityInvoke.buildPhoneSecurity()` 成功生成安全字段后触发 recorder，recorder 再按缓存/`phone_segment` 解析省市并幂等写映射。
- [x] T023 按 `phone_md5` 查询 `drh_phone_security_region`，存在则跳过，不存在则插入。
- [x] T024 处理唯一键冲突：`uk_phone_md5` 冲突按已存在处理，不抛业务异常。
- [x] T025 映射查询或插入失败时记录日志，不阻断原加密返回和业务主流程。
- [x] T026 保持现有 `getUserProvinceV2`、`getCity(String)`、`getCity(LiveUser)` 外部行为不变。
- [x] T027 静态确认所有实体、Mapper、SQL、insert 参数不含 `segment` 字段。

## Phase 4：测试与验证

- [ ] T028 单元测试：首次解析明文手机号时插入 `phone_mask/phone_md5/phone_aes/province/city`。
- [ ] T029 单元测试：相同 `phone_md5` 已存在时不重复插入。
- [ ] T030 单元测试：缓存未命中时查询 `phone_segment` 并回填缓存。
- [ ] T031 单元测试：缓存命中时不查询 `phone_segment`。
- [ ] T032 单元测试：新表插入对象和 SQL 参数不包含 `segment`。
- [ ] T033 单元测试：空手机号、短手机号、号段未命中均不写映射且保持旧返回。
- [ ] T034 单元测试：安全字段生成失败时不写映射，省市返回不受影响。
- [ ] T035 单元测试：映射表插入失败只记录日志，不阻断原流程。
- [x] T036 DDL 验证：`drh_phone_security_region` 不存在 `segment` 字段。
- [x] T037 DDL 验证：`uk_phone_md5` 和 `idx_province_city` 存在。
- [x] T038 运行 DRH 目标模块测试或编译命令，并记录结果；当前失败为既有公共实体/安全字段不一致，非本次新增代码报错。
- [x] T039 运行 KKHC 目标模块测试或编译命令，并记录结果。
- [x] T040 搜索确认没有 `drh_phone_security_region.segment`、`setSegment` 写入或 `segment` insert 参数残留。
- [ ] T041 kk-cms 运行时核查：确认当前数据源存在 `drh_phone_security_region` 表和 `uk_phone_md5` 唯一索引。
- [ ] T042 kk-cms 运行时核查：用实际手机号前 7 位查询 `phone_segment.segment`，确认 `province/city` 非空。
- [ ] T043 kk-cms 运行时核查：用实际手机号生成或查询 `phone_md5`，确认映射表是否已存在相同记录。
- [ ] T044 kk-cms 运行时核查：检查日志关键字 `保存手机号省市映射失败`、`手机号省市映射已存在`。
- [ ] T045 kk-cms 运行时核查：调用 `editAddress` 后等待异步 recorder 执行，再查询 `drh_phone_security_region`。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `079-phone-security-region-mapping` 规格目录，编写 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md` 和 DDL 文件。
- 验证方式：静态搜索现有 DRH、KKHC `PhoneSegmentServiceImpl` 和 `DataSecurityInvoke` 工具；检查 DDL 不含 `segment` 字段。
- 自检结论：文档已记录目标、非目标、字段、索引、参数来源、调用顺序、缓存口径和测试映射。

### D002 - 实现记录

- 状态：已废弃，保留为历史记录。用户后续明确要求改为在统一加密工具 `DataSecurityInvoke` 中处理所有手机号加密场景。
- 实现内容：DRH endpoint/callback 与 KKHC broadcast 均新增 `PhoneSecurityRegion` 实体、Mapper、Service；`PhoneSegmentServiceImpl` 增加本地 `segment -> PhoneSegment` 缓存和按 `phone_md5` 幂等写入省市映射。
- 测试命令：`mvn -pl broadcast -am -DskipTests clean compile`；`mvn -pl drh-endpoint,drh-callback -DskipTests compile`；`mvn -pl drh-callback -DskipTests compile`。
- 测试结果：KKHC 编译通过；DRH 编译失败在当前工程既有公共实体/安全字段不一致问题，未指向本次新增代码。
- 自检结论：新表实体和保存参数不含 `segment`；缓存 key 仅为运行时局部使用；映射写入异常不阻断原流程。

### D003 - 纠正实现记录

- 触发原因：用户指出上一版放在 `PhoneSegmentServiceImpl` 不正确，需要在 DRH 和 KKHC 的统一加密工具 `DataSecurityInvoke` 中处理所有手机号加密场景。
- 修正内容：
  - 恢复 DRH endpoint/callback 与 KKHC broadcast 的 `PhoneSegmentService` 原逻辑。
  - DRH common、KKHC base-common、KKHC ai-common 的 `DataSecurityInvoke.buildPhoneSecurity()` 增加 recorder hook；`computePhoneMd5()` 不触发写表。
  - DRH endpoint/callback/kk-cms/media-process/pay 与 KKHC broadcast/ai/lms/app 注册 `PhoneSecurityRegionRecorder`，内部缓存 `segment -> PhoneSegment` 并按 `phone_md5` 幂等插入。
  - `PhoneSecurityRegion` 共享实体和 DDL 均不包含 `segment`。
- 文档同步：已同步 `spec.md`、`tasks.md`；DDL 不需要调整。
- 验证结果：后续补充本轮编译和静态检查结果。

### D004 - kk-cms editAddress 专项排查记录

- 排查对象：`BookQuestionRecordServiceImpl#editAddress` 中 `bookQuestionRecord.createAesInfo();` 未写入 `drh_phone_security_region` 的原因。
- 静态结论：`createAesInfo()` 只通过 `DataSecurityInvoke.buildPhoneSecurity()` 生成安全字段并异步触发 `PhoneSecurityRegionRecorder`，实际写表发生在 recorder 的 `record()` 方法。
- 未落库优先排查：当前数据源是否执行 DDL、`phone_segment` 是否命中且省市非空、`phone_md5` 是否已存在、异步 recorder 是否尚未执行完成、日志是否记录插入失败。
- 本次新增 T041-T045 作为运行时核查任务；本轮只更新规格文档，不执行 DDL，不修改业务代码。
