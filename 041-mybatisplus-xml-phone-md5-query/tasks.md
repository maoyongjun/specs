# 任务清单：MyBatis XML 手机号 MD5 查询兼容

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。  
**当前阶段**：已进入实现阶段；代码改动位于 `C:\workspace\drh`。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认本轮已从文档阶段进入实现阶段。
- [x] T002 确认目标工程为 `C:\workspace\drh`，重点模块为 `drh-kk-cms`。
- [x] T003 全量搜索 `drh` 和 `ju-chat/kkhc/kkhc-idc/ai` 的 Mapper XML，覆盖 `phone = #{...}`、`phone in (...)`、`phone like ...`、`phone is null/not null`、`xxx.phone = yyy.phone`、`select phone` 等形态。
- [x] T004 确认典型入口：`BookQuestionRecordServiceImpl` 中构造 `CreateExternalBookQuestionRecordDto` 并调用 `queryHistoryExpressNoListCount` 的链路。
- [x] T005 确认 `ExternalBookQuestionRecordMapper.xml` 中 `queryHistoryExpressNoListCount`、`queryHistoryExpressNoList`、`queryHistoryPage*` 的实际读取字段。
- [x] T006 按文件输出其他 XML 命中清单，并分类为：可直接改 `phone_md5`、需业务确认、可排除。
- [x] T007 对初始搜索已命中的候选文件逐一复查：`WorksShipMapper.xml`、`WorksAwardsRecordMapper.xml`、`UserQuestionMapper.xml`、`SpecailUserMapper.xml`、`RenewDataMapper.xml`、`OrderHandRecordMapper.xml`、`OrderHandRecordDelMapper.xml`、`LiveCampUserMapper.xml`、`HandoverPlusMapper.xml`、`DayUrgeClassMapper.xml`、`AppletUserPoolMapper.xml`、`AppletUserMapper.xml`、`AppletSalePoolMapper.xml`、`AppletPlayerMapper.xml`、`AdUserPicMapper.xml`、`HandoverMapper.xml`、`OrderBookReissueMapper.xml`。
- [x] T008 确认现有 `DataSecurityInvoke.computePhoneMd5(...)` 已兼容明文手机号、前端加密手机号和 32 位 MD5 透传。
- [x] T009 确认保存 / 更新接口的现有手机号保存链路，列出需要新增 MD5 拒绝校验的入口。

**检查点**：不得在未完成 T001-T009 前进入代码实现。

## Phase 2：风险门禁

- [x] T010 检查是否存在 `new CreateExternalBookQuestionRecordDto()` 后只 set `phone`，未 set `phoneMd5` 就调用 Mapper 的场景。
- [x] T011 检查是否存在多个 DTO 共用 `phone` 字段进入同一 XML 的场景，避免只补一个入口。
- [x] T012 检查 `queryHistoryPageWhere`、`queryHistoryPageWhere2`、`queryHistoryPageWhere3` 三段 SQL 的手机号条件是否同时改为 `phone_md5`。
- [x] T013 检查 `queryHistoryExpressNoList` 的两个 UNION 分支是否同时改为 `phone_md5`。
- [x] T014 检查 `queryHistoryExpressNoListCount` 的两个 UNION 分支是否同时改为 `phone_md5`。
- [x] T015 检查其他 XML 中的等值查询、IN 查询和手机号 join 是否可改为 `phone_md5`。
- [x] T016 检查其他 XML 中的 `phone like` 是否需要业务确认，因为 MD5 不支持模糊匹配。
- [x] T017 检查其他 XML 中的 `phone is null/not null` 和 `select phone` 是否会因明文字段清空而失真。
- [x] T018 检查查询接口传 32 位 MD5 时是否会被错误地再次送入 `computePhoneMd5(...)`。
- [x] T019 检查保存 / 更新接口传 32 位 MD5 时是否会被当作普通字符串生成安全字段。
- [x] T020 确认错误提示文案固定为 `手机号加密格式不符`。
- [x] T021 为每个关键行为建立测试映射：查询三种入参、清空 `phone` 后查询、保存 / 更新拒绝 MD5、XML SQL 字段检查、全量 XML 扫描无遗漏。

**检查点**：T010-T021 必须有明确结论；发现高风险时先更新 `spec.md` 的“历史问题防漏分析”。

## Phase 3：实现任务（后续执行，本阶段不做）

- [x] T022 在查询 DTO 中新增或补齐 `phoneMd5` 字段，例如 `CreateExternalBookQuestionRecordDto`、`BookQuestionRecordHistoryInput`、`BookQueryHistoryExpressNoInput`。
- [x] T023 在查询入口统一准备 `phoneMd5`：明文 / 前端加密手机号走 `computePhoneMd5(...)`，32 位 MD5 直接使用。
- [x] T024 将 `ExternalBookQuestionRecordMapper.xml` 的 `queryHistoryPage*` 手机号条件改为 `phone_md5 = #{input.phoneMd5}`。
- [x] T025 将 `queryHistoryExpressNoList` 两个 UNION 分支的手机号条件改为 `phone_md5 = #{input.phoneMd5}`。
- [x] T026 将 `queryHistoryExpressNoListCount` 两个 UNION 分支的手机号条件改为 `phone_md5 = #{input.phoneMd5}`。
- [x] T027 按 Phase 1 分类结果改造其他 XML：可确定的等值 / join 已改为 `phone_md5`；LIKE、展示、无 `phone_md5` 表已记录为需业务确认或可排除。
- [x] T028 对保存 / 更新入口增加手机号格式校验：明文或前端加密手机号允许，32 位 MD5 或无法识别 / 解密的值拒绝。
- [x] T029 保存 / 更新接口拒绝非法手机号时返回参数错误，错误提示为 `手机号加密格式不符`。
- [x] T030 保持原有 `goodsId`、`expressNoList`、`empId`、`systemEmpId`、`source` 等过滤条件不变。
- [x] T031 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证（本轮执行静态/编译，接口验证待环境）

- [ ] T032 查询接口传明文手机号，验证命中历史记录。
- [ ] T033 查询接口传前端加密手机号，验证命中同一条历史记录。
- [ ] T034 查询接口传 32 位 MD5 手机号，验证命中同一条历史记录，且不二次计算 MD5。
- [ ] T035 清空测试数据的 `phone` 字段，只保留 `phone_md5`，验证 `queryHistoryExpressNoListCount` 仍可返回正确计数。
- [ ] T036 保存接口传明文手机号，验证正常保存并生成安全字段。
- [ ] T037 保存接口传前端加密手机号，验证正常保存并生成安全字段。
- [ ] T038 保存接口传 32 位 MD5 字符串，验证返回参数错误和 `手机号加密格式不符`。
- [ ] T039 更新接口传 32 位 MD5 字符串，验证返回参数错误和 `手机号加密格式不符`。
- [x] T040 静态扫描确认目标 XML 使用 `phone_md5 = #{input.phoneMd5}`，不再使用 `phone = #{input.phone}`。
- [x] T041 重新执行全量 XML 扫描，确认所有命中点已改造、已排除或已记录需业务确认。
- [x] T042 搜索确认必须改造的 XML 不再残留 `phone = #{input.phone}`。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 MyBatis XML 手机号 MD5 查询兼容规格文档。
- 验证方式：文档静态检查；已根据用户输入记录查询 / 保存更新接口的不同入参规则，并补充其他 Mapper XML 全量扫描要求。
- 自检结论：本阶段只新增文档，不修改业务代码。

### D002 - 实现记录

- 执行内容：接续 `C:\workspace\drh` 中未提交改动，完成核心图书链路 `phone_md5` 查询兼容。
- 已实现：`DataSecurityInvoke.computePhoneMd5(...)` 支持 32 位 MD5 透传并归一化小写；新增 `isWritablePhoneInput(...)` 用于保存 / 更新拒绝 MD5 或非法手机号。
- 已实现：`CreateExternalBookQuestionRecordDto`、`BookQuestionRecordHistoryInput`、`BookQueryHistoryExpressNoInput` 补齐 `phoneMd5` 字段。
- 已实现：`ExternalBookQuestionRecordServiceImpl` 在 `queryHistoryPage`、`count`、`queryHistoryExpressNo` 调用 Mapper 前准备 `phoneMd5`；`create` 入口拒绝 MD5/非法手机号。
- 已实现：`BookQuestionRecordServiceImpl` 的图书地址保存 / 更新、订单地址、集单地址、导入地址链路拒绝 MD5/非法手机号；临时构造 `CreateExternalBookQuestionRecordDto` 时同步设置 `phoneMd5`；导入地址回填 `LiveUser` 时同步写入 `phoneMask`、`phoneMd5`、`phoneAes`。
- 已实现：`ExternalBookQuestionRecordMapper.xml` 的 `queryHistoryPage*`、`queryHistoryExpressNoList`、`queryHistoryExpressNoListCount` 均改为 `phone_md5 = #{input.phoneMd5}`，保留 `goodsId`、`expressNoList`、`empId`、`systemEmpId`、`source` 等原条件。
- 已实现：可确定具备 `phone_md5` 的其他 XML 等值 / join 补齐，包括 `AdUserPicMapper.xml`、`AppletSalePoolMapper.xml`、`AppletUserMapper.xml`、`AppletUserPoolMapper.xml`、`DayUrgeClassMapper.xml`、`HandoverPlusMapper.xml`、`LiveCampUserMapper.xml`、`OrderHandRecordMapper.xml`、`OrderHandRecordDelMapper.xml`、`SpecailUserMapper.xml`、`drh-media-process/AppletUserMapper.xml`、`drh-my-sync/AppletUserMapper.xml`、`drh-my-sync/CreativePlanMapper.xml`。
- 扫描分类：`WorksShipMapper.xml`、`AppletPlayerMapper.xml`、`WorksAwardsRecordMapper.xml`、`UserQuestionMapper.xml`、`RenewDataMapper.xml`、`OrderBookReissueMapper.xml`、`AppStudyInfoMapper.xml` 等目标表或实体未确认存在 `phone_md5`，暂不改；`HandoverMapper.xml`、`RegisterWorksMapper.xml`、`DayUrgeClassMapper.xml` 中的 `phone like` 需业务确认；`select phone` / `phone is null/not null` 展示或完整性判断类保留为剩余风险。
- 静态验证：已运行全量 XML 扫描；核心 `ExternalBookQuestionRecordMapper.xml` 不再残留 `phone = #{input.phone}`，目标查询均使用 `phone_md5 = #{input.phoneMd5}`；全局仍有直接手机号条件命中，已按上条分类记录。
- 测试补充：`DataSecurityUtilTest` 增加 `isWritablePhoneInput` 明文、前端 AES 密文、MD5 拒绝、非法字符串拒绝的离线单元测试。
- 验证结果：Maven 默认 JDK 17 编译会因旧 Lombok 访问 `jdk.compiler` 模块失败；切到 JDK 8 后 `mvn -pl drh-common -DskipTests compile` 通过；`DataSecurityUtilTest` 方法级 Surefire 命令返回 `Tests run: 0`，未形成有效单测通过记录；`mvn -pl drh-kk-cms -am -DskipTests compile` 5 分钟超时，已停止残留 Maven/JDK8 子进程。
- 待验证：仍需可用环境下的接口/Mapper 行为验证，以及完整 `drh-kk-cms` 编译链路验证。

### D003 - 纠正记录模板

- 后续如出现用户补充、测试失败、代码审查发现、参数遗漏或调用顺序问题，需要追加新的 Dxxx 纠正记录。
- 纠正记录必须说明触发原因、具体修正、同步文件和测试或静态验证结果。
