# 任务清单：MyBatis XML 手机号 MD5 查询兼容

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。  
**当前阶段**：仅编写文档，不修改业务代码。

## Phase 1：代码事实确认

- [ ] T001 复查用户需求和本目录 `AGENTS.md`，确认本需求当前只处理规格文档。
- [ ] T002 确认目标工程为 `C:\workspace\drh`，重点模块为 `drh-kk-cms`。
- [ ] T003 全量搜索 `drh` 和 `ju-chat/kkhc/kkhc-idc/ai` 的 Mapper XML，覆盖 `phone = #{...}`、`phone in (...)`、`phone like ...`、`phone is null/not null`、`xxx.phone = yyy.phone`、`select phone` 等形态。
- [ ] T004 确认典型入口：`BookQuestionRecordServiceImpl` 中构造 `CreateExternalBookQuestionRecordDto` 并调用 `queryHistoryExpressNoListCount` 的链路。
- [ ] T005 确认 `ExternalBookQuestionRecordMapper.xml` 中 `queryHistoryExpressNoListCount`、`queryHistoryExpressNoList`、`queryHistoryPage*` 的实际读取字段。
- [ ] T006 按文件输出其他 XML 命中清单，并分类为：可直接改 `phone_md5`、需业务确认、可排除。
- [ ] T007 对初始搜索已命中的候选文件逐一复查：`WorksShipMapper.xml`、`WorksAwardsRecordMapper.xml`、`UserQuestionMapper.xml`、`SpecailUserMapper.xml`、`RenewDataMapper.xml`、`OrderHandRecordMapper.xml`、`OrderHandRecordDelMapper.xml`、`LiveCampUserMapper.xml`、`HandoverPlusMapper.xml`、`DayUrgeClassMapper.xml`、`AppletUserPoolMapper.xml`、`AppletUserMapper.xml`、`AppletSalePoolMapper.xml`、`AppletPlayerMapper.xml`、`AdUserPicMapper.xml`、`HandoverMapper.xml`、`OrderBookReissueMapper.xml`。
- [ ] T008 确认现有 `DataSecurityInvoke.computePhoneMd5(...)` 已兼容明文手机号和前端加密手机号。
- [ ] T009 确认保存 / 更新接口的现有手机号保存链路，列出需要新增 MD5 拒绝校验的入口。

**检查点**：不得在未完成 T001-T009 前进入代码实现。

## Phase 2：风险门禁

- [ ] T010 检查是否存在 `new CreateExternalBookQuestionRecordDto()` 后只 set `phone`，未 set `phoneMd5` 就调用 Mapper 的场景。
- [ ] T011 检查是否存在多个 DTO 共用 `phone` 字段进入同一 XML 的场景，避免只补一个入口。
- [ ] T012 检查 `queryHistoryPageWhere`、`queryHistoryPageWhere2`、`queryHistoryPageWhere3` 三段 SQL 的手机号条件是否同时改为 `phone_md5`。
- [ ] T013 检查 `queryHistoryExpressNoList` 的两个 UNION 分支是否同时改为 `phone_md5`。
- [ ] T014 检查 `queryHistoryExpressNoListCount` 的两个 UNION 分支是否同时改为 `phone_md5`。
- [ ] T015 检查其他 XML 中的等值查询、IN 查询和手机号 join 是否可改为 `phone_md5`。
- [ ] T016 检查其他 XML 中的 `phone like` 是否需要业务确认，因为 MD5 不支持模糊匹配。
- [ ] T017 检查其他 XML 中的 `phone is null/not null` 和 `select phone` 是否会因明文字段清空而失真。
- [ ] T018 检查查询接口传 32 位 MD5 时是否会被错误地再次送入 `computePhoneMd5(...)`。
- [ ] T019 检查保存 / 更新接口传 32 位 MD5 时是否会被当作普通字符串生成安全字段。
- [ ] T020 确认错误提示文案固定为 `手机号加密格式不符`。
- [ ] T021 为每个关键行为建立测试映射：查询三种入参、清空 `phone` 后查询、保存 / 更新拒绝 MD5、XML SQL 字段检查、全量 XML 扫描无遗漏。

**检查点**：T010-T021 必须有明确结论；发现高风险时先更新 `spec.md` 的“历史问题防漏分析”。

## Phase 3：实现任务（后续执行，本阶段不做）

- [ ] T022 在查询 DTO 中新增或补齐 `phoneMd5` 字段，例如 `CreateExternalBookQuestionRecordDto` 及其他进入目标 XML 的输入对象。
- [ ] T023 在查询入口统一准备 `phoneMd5`：明文 / 前端加密手机号走 `computePhoneMd5(...)`，32 位 MD5 直接使用。
- [ ] T024 将 `ExternalBookQuestionRecordMapper.xml` 的 `queryHistoryPage*` 手机号条件改为 `phone_md5 = #{input.phoneMd5}`。
- [ ] T025 将 `queryHistoryExpressNoList` 两个 UNION 分支的手机号条件改为 `phone_md5 = #{input.phoneMd5}`。
- [ ] T026 将 `queryHistoryExpressNoListCount` 两个 UNION 分支的手机号条件改为 `phone_md5 = #{input.phoneMd5}`。
- [ ] T027 按 Phase 1 分类结果改造其他 XML：等值 / IN / join 改 `phone_md5`，LIKE / NULL / 展示类按确认后的口径处理。
- [ ] T028 对保存 / 更新入口增加手机号格式校验：明文或前端加密手机号允许，32 位 MD5 或无法识别 / 解密的值拒绝。
- [ ] T029 保存 / 更新接口拒绝非法手机号时返回参数错误，错误提示为 `手机号加密格式不符`。
- [ ] T030 保持原有 `goodsId`、`expressNoList`、`empId`、`systemEmpId`、`source` 等过滤条件不变。
- [ ] T031 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证（后续执行，本阶段不做）

- [ ] T032 查询接口传明文手机号，验证命中历史记录。
- [ ] T033 查询接口传前端加密手机号，验证命中同一条历史记录。
- [ ] T034 查询接口传 32 位 MD5 手机号，验证命中同一条历史记录，且不二次计算 MD5。
- [ ] T035 清空测试数据的 `phone` 字段，只保留 `phone_md5`，验证 `queryHistoryExpressNoListCount` 仍可返回正确计数。
- [ ] T036 保存接口传明文手机号，验证正常保存并生成安全字段。
- [ ] T037 保存接口传前端加密手机号，验证正常保存并生成安全字段。
- [ ] T038 保存接口传 32 位 MD5 字符串，验证返回参数错误和 `手机号加密格式不符`。
- [ ] T039 更新接口传 32 位 MD5 字符串，验证返回参数错误和 `手机号加密格式不符`。
- [ ] T040 SQL 日志或 Mapper 单测确认目标 XML 使用 `phone_md5 = ?`，不再使用 `phone = ?`。
- [ ] T041 重新执行全量 XML 扫描，确认所有命中点已改造、已排除或已记录需业务确认。
- [ ] T042 搜索确认必须改造的 XML 不再残留 `phone = #{input.phone}`。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 MyBatis XML 手机号 MD5 查询兼容规格文档。
- 验证方式：文档静态检查；已根据用户输入记录查询 / 保存更新接口的不同入参规则，并补充其他 Mapper XML 全量扫描要求。
- 自检结论：本阶段只新增文档，不修改业务代码。

### D002 - 实现记录

- 待后续实现阶段补充代码改动摘要、测试命令、测试结果和自检结论。
- 自检结论必须覆盖参数来源、调用顺序、旧逻辑保持和剩余风险。

### D003 - 纠正记录模板

- 后续如出现用户补充、测试失败、代码审查发现、参数遗漏或调用顺序问题，需要追加新的 Dxxx 纠正记录。
- 纠正记录必须说明触发原因、具体修正、同步文件和测试或静态验证结果。
