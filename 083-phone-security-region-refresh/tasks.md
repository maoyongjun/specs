# 任务清单：juzi-service drh_phone_security_region 数据刷新接口

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于哪个项目、模块和业务链路。
  - 结论：目标项目 `data-RC\juzi-service`（Spring Boot, Java 8, JdbcTemplate + MyBatis Plus，数据源经 Nacos `juzi-service-config`）；业务链路为手机号安全字段省市映射（spec 079 建立的 `drh_phone_security_region` 体系）。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和测试落点。
  - 结论：juzi-service 对 `drh_phone_security_region`/`phone_segment` 零引用（grep 验证）。写表逻辑仅在 kkhc `com.kkhc.idc.lms.service.impl.PhoneSecurityRegionRecorder`（经 `DataSecurityInvoke.buildPhoneSecurity()` 异步旁路触发）；juzi-service 仅依赖 `com.drh.idc:lms-common:1.3.224`（实体可见），无 Recorder Bean 注册，调 `buildPhoneSecurity()` 也不会落库。现有模式母版：`PhoneSecurityBackfillService`（异步单任务+分页+fcExecutor）、`PhonePlaintextRetirementService`（互斥守卫）、`DefaultPhoneSecurityEncryptClient`（FC 调用样板）。测试落点 `src\test\java\com\drh\data\juzi\phonesecurity\`。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
  - 结论：见 `spec.md` 历史问题防漏分析。`phone_mask`(VARCHAR32)/`phone_md5`(CHAR32)/`phone_aes`(VARCHAR255) 来自业务行三列；`province/city`(VARCHAR64) 来自 `phone_segment` 查询；`segment` 仅为运行时局部变量与缓存 key。
- [x] T004 确认配置来源、环境变量、Redis key、MQ topic/tag、Feign/FC/HTTP 调用或数据库表是否受影响。
  - 结论：新增 FC DataSecurity 解密调用（businessType=2/dataType=1，函数名按 `mqConfig.getJuzi_tag()` 切换 DataSecurity-test/pro，契约对齐 kkhc `decryptPhoneAes`，非新发明）；新增对 `drh_phone_security_region` 的 INSERT 与对 `phone_segment` 的 SELECT；不涉及 Redis、MQ、Feign；不改任何现有契约。两表存在性为运行时假设，由 start() preflight 兜底。
- [x] T005 确认已有旧逻辑中必须保持不变的过滤、幂等、异常处理、日志、延迟和 fallback。
  - 结论：backfill/retirement 全部现有行为零修改；kkhc Recorder 幂等语义作为写入基准（三字段非空校验、province/city 非空、`phone_md5` 查重、`DuplicateKeyException` 视为已存在、异常只记日志）；明文退役语义（`phone = phone_mask`，掩码含 `*`）决定行分类规则。

**检查点**：T001-T005 已完成，允许进入实现。

## Phase 2：风险门禁

- [x] T006 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参。
  - 结论：无。候选行/省市结果用不可变私有静态类一次性构造；省市为空整行跳过，不下传占位对象。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段。
  - 结论：无。INSERT 五个参数全部在执行前当前层现算；FC 解密结果仅用于 segment 推导，不回写业务表。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用。
  - 结论：是。预检参数=扫描行 md5；解密参数=扫描行 aes；segment 查询参数=明文或解密结果前 7 位；INSERT 参数=扫描行三列+segment 查询结果，全部有确定来源。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为。
  - 结论：新增管理接口（本需求直接要求）、新增 FC 解密外部请求（用户已确认）、新增 `drh_phone_security_region` 幂等 INSERT（本需求直接要求）；不改变任何现有调用顺序与契约。
- [x] T010 对需要用户确认的业务语义变化做记录；未确认前不得实现该变化。
  - 结论：三项设计选择已于 2026-06-12 经用户确认（数据来源=45 表扫描；已存在跳过；掩码行 FC 解密），记录在 `spec.md`。
- [x] T011 为每个关键行为建立测试映射，至少覆盖正常路径、边界路径和不回归路径。
  - 测试映射：
    - FR-002/FR-006/FR-007（扫描条件、INSERT 列与参数、无 segment）→ `PhoneSecurityRegionRefreshServiceTest`
    - FR-003/FR-009（预检跳过、批内去重、DuplicateKey 幂等）→ `PhoneSecurityRegionRefreshServiceTest`
    - FR-004（明文/掩码分类、解密入参、解密失败跳过）→ `PhoneSecurityRegionRefreshServiceDecryptTest`、`DefaultPhoneSecurityDecryptClientTest`（businessType=2/dataType=1/data）
    - FR-005（segment 缓存命中、负结果不缓存）→ `PhoneSecurityRegionRefreshSegmentCacheTest`
    - FR-010（互斥守卫、重复 start 拒绝）→ `PhoneSecurityRegionRefreshServiceGuardTest`
    - FR-011（dryRun 不发 FC 不写库）→ `PhoneSecurityRegionRefreshServiceTest` dryRun 用例
    - FR-013（不改现有文件）→ 静态检查（git status / 文件清单比对）

**检查点**：T006-T011 已有明确结论，高风险项已写入 `spec.md` 历史问题防漏分析。

## Phase 3：实现

- [ ] T012 按规格实现最小范围改动：新增 `PhoneSecurityDecryptClient`、`DefaultPhoneSecurityDecryptClient`、`PhoneSecurityRegionRefreshService`、`PhoneSecurityRegionRefreshStartResponse`、`PhoneSecurityRegionRefreshStatusResponse`、`PhoneSecurityRegionRefreshAdminController`。
- [ ] T013 保持未声明的旧行为不变：不触碰任何现有文件。
- [ ] T014 对外部调用参数、数据库写入增加可测试断言点：SQL 构建方法包级可见；`buildDecryptInput`/`parseAesDecrypt` 包级静态。
- [ ] T015 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [ ] T016 新增或更新单元测试，覆盖关键行为（5 个测试类，见 T011 测试映射）。
- [ ] T017 测试中断言关键下游参数内容：INSERT 精确列清单与参数值、SQL 无 `segment`、FC 解密入参 businessType=2、预检 SQL 含 `phone_md5 IN`。
- [ ] T018 验证边界情况和旧逻辑不回归：安全字段不全、解密失败、号段未命中、省市为空、唯一键冲突、dryRun、互斥拒绝。
- [ ] T019 运行目标模块测试或编译命令，并记录结果。
- [ ] T020 搜索确认没有残留旧调用、旧字段、旧日志或旧口径；确认新代码无 `segment` 落库、无明文落库。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 082 规格文档（AGENTS.md/spec.md/tasks.md/checklist），完成 Phase 1 代码事实确认与 Phase 2 风险门禁。
- 验证方式：grep 验证 juzi-service 对两表零引用；通读 `PhoneSecurityBackfillService`/`PhonePlaintextRetirementService`/`DefaultPhoneSecurityEncryptClient`/kkhc `PhoneSecurityRegionRecorder`/`DataSecurityInvoke.decryptPhoneAes`/spec 079 DDL。
- 自检结论：满足强制门禁；三项业务语义选择已经用户确认。

### D002 - 实现记录

- 实现内容：`<实现后填写>`。
- 测试命令：`<命令>`。
- 测试结果：`<Tests run / BUILD SUCCESS / 静态检查结果>`。
- 自检结论：`<参数来源、调用顺序、旧逻辑保持、剩余风险>`。

### D003 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
