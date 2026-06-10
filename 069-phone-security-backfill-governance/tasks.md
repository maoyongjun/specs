# 任务清单：手机号安全字段上线与回填治理

## Phase 1：事实确认

- [x] T001 确认 `068-livecamp-stu-order-phone-security-gap` 已存在，本规格使用 `069-phone-security-backfill-governance`。
- [x] T002 确认 `drh_specail_user` 已废弃，不进入 DDL 和回填接口。
- [x] T003 确认 P3 需要补入加密字段回填：`drh_register_works`、`drh_sms_deal`、`drh_temp_phone`、`drh_mall_order`。
- [x] T004 确认 `drh_mall_order` 字段拼写沿用 `reciver_phone`。
- [x] T005 确认最终 DDL 要求字段和索引分开执行，`md5/aes` 均建索引。

## Phase 2：DDL 与加密字段回填

- [x] T006 新增最终 DDL SQL 到本规格目录。
- [x] T007 从旧 P1 DDL 和字段状态检查 SQL 中移除 `drh_specail_user`。
- [x] T008 将回填目标抽取为 `PhoneSecurityTargets.TARGETS`。
- [x] T009 将 P3 四张表补入 `PhoneSecurityTargets.TARGETS`。
- [x] T010 增加目标清单单测，防止废弃表回归和 P3 漏表。

## Phase 3：明文掩码覆盖接口

- [x] T011 新增 `BackfillTarget` 顶层类。
- [x] T012 新增 `PhonePlaintextRetirementService`。
- [x] T013 新增 `PhonePlaintextRetirementStartResponse` 和 `PhonePlaintextRetirementStatusResponse`。
- [x] T014 新增 `PhonePlaintextRetirementAdminController`。
- [x] T015 将 `/admin/phone-plaintext-retirement/**` 纳入后台鉴权。
- [x] T016 支持 `dryRun`，上线前先统计候选量。
- [x] T017 启动时检查加密字段回填是否正在运行，运行中则拒绝启动。
- [x] T018 加密字段回填增加掩码源字段保护，源字段包含 `*` 时不更新 `mask/md5/aes`。

## Phase 4：风险门禁

- [x] T019 文档记录硬顺序：字段 DDL -> 索引 DDL -> 加密字段回填 -> 抽样核对 -> dry-run -> 明文掩码覆盖。
- [x] T020 文档记录明文掩码覆盖后不得重跑加密字段回填。
- [x] T021 明文掩码覆盖 SQL 只在 `mask/aes` 非空且 `source != mask` 时更新。
- [x] T022 明文掩码覆盖不调用 FC，不改 `md5/aes`。

## Phase 5：验证

- [x] T023 新增服务层单测，覆盖 SQL 门禁、dry-run、互斥和失败目标继续处理。
- [x] T024 新增控制器单测，覆盖受理、拒绝和状态查询。
- [x] T025 新增加密字段回填掩码保护单测。
- [x] T026 执行 `juzi-service` 相关单测。
- [ ] T027 在测试库执行最终 DDL 和 dry-run。
- [ ] T028 在生产上线窗口前抽样核对 `mask/md5/aes` 准确性。

## 后续新增表维护步骤

1. 在 `sql/final-phone-security-ddl-and-indexes.sql` 增加字段 DDL 和 `md5/aes` 索引 DDL。
2. 在 `PhoneSecurityTargets.TARGETS` 增加 `BackfillTarget`。
3. 更新目标清单单测数量和表字段断言。
4. 更新本文件 Phase 1/2 的事实记录。
5. 上线前先跑加密字段回填，再决定是否纳入明文掩码覆盖。
