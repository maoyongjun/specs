# 功能规格：juzi-service drh_phone_security_region 数据刷新接口

**功能目录**：`083-phone-security-region-refresh`  
**创建日期**：`2026-06-12`  
**状态**：Draft  
**输入**：在 `C:\workspace\ju-chat\specs` 创建 spec-kit 文档，在 juzi-service 里面增加更新线上数据的接口，对 `drh_phone_security_region` 表进行数据刷新。在 `DataSecurityInvoke` 里面有逻辑对 `drh_phone_security_region` 这个表数据进行存入的。用户已确认：数据来源为扫描 `PhoneSecurityTargets` 的 45 张业务表；region 表已存在相同 `phone_md5` 跳过不处理；明文已退役成掩码的行优先明文、掩码行走 FC 解密 `phone_aes`。

## 背景

- 当前问题：spec 079 在 kkhc/DRH 的统一加密入口 `DataSecurityInvoke.buildPhoneSecurity()` 接入了 `PhoneSecurityRegionRecorder` 旁路，只覆盖**新产生**的加密调用。juzi-service 的 `PhoneSecurityBackfillService` 对 45 张业务表的历史回填直接调 FC 加密（`DefaultPhoneSecurityEncryptClient`，businessType=1），不经过 Recorder，因此这批历史手机号从未写入 `drh_phone_security_region`，省市映射存在大量缺口。
- 当前行为：juzi-service 对 `drh_phone_security_region` 和 `phone_segment` 两表零引用；写表逻辑只存在于 kkhc（`com.kkhc.idc.lms.service.impl.PhoneSecurityRegionRecorder`），且 juzi-service 未注册任何 Recorder Bean，即使调 `buildPhoneSecurity()` 也不会落库。
- 目标行为：juzi-service 新增管理接口，扫描 45 张业务表中已具备 `phone_mask/phone_md5/phone_aes` 的行，解析省市后按 `phone_md5` 幂等补齐 `drh_phone_security_region`；明文已退役的行通过 FC 解密 `phone_aes` 还原手机号取号段。
- 非目标：
  - 不修改 kkhc 的 `DataSecurityInvoke` 和 `PhoneSecurityRegionRecorder`。
  - 不修改 juzi-service 现有 `PhoneSecurityBackfillService`、`PhonePlaintextRetirementService` 及其 Controller 的任何行为与契约。
  - 不更新 region 表已存在记录的 `province/city`（存在不处理，与 spec 079 一致）。
  - 不在 `drh_phone_security_region` 写 `segment`、不写明文手机号。
  - 不新增数据库表、不新增 Maven 依赖、不新增 Redis key 契约。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 全量刷新补齐历史省市映射（优先级：P1）

运维通过管理接口启动刷新任务，系统扫描 45 张业务表中已加密的手机号行，把 `drh_phone_security_region` 中缺失的安全字段与省市映射补齐。

**独立测试**：mock JdbcTemplate 构造某业务表两批数据，运行刷新任务，断言 INSERT 到 `drh_phone_security_region` 的列为 `(phone_mask, phone_md5, phone_aes, province, city)` 且参数值与来源行一致，SQL 不含 `segment`。

**验收场景**：

1. **Given** 业务表某行 `phone` 明文有效且 `phone_mask/phone_md5/phone_aes` 齐全、`phone_segment` 命中前 7 位且省市非空、region 表无该 `phone_md5`，**When** 运行刷新任务，**Then** 向 `drh_phone_security_region` 插入一条 `(phone_mask, phone_md5, phone_aes, province, city)`，`insertedCount` 加 1。
2. **Given** 某行 `phone_mask/phone_md5/phone_aes` 任一为空，**When** 运行刷新任务，**Then** 该行不进入处理流程，按表计入 `skippedNoSecurityCount`，日志提示应先执行 encrypt backfill。
3. **Given** 任务已在运行，**When** 再次调用 start，**Then** 返回 `accepted=false`，不重复启动。

### 用户故事 2 - 已存在的手机号跳过不处理（优先级：P1）

与 spec 079 幂等语义一致：region 表已存在相同 `phone_md5` 的记录不重复写、不更新。

**独立测试**：mock 预检查询返回已存在的 `phone_md5`，断言该行不触发 FC 解密、不执行 INSERT，`skippedExistsCount` 计数正确。

**验收场景**：

1. **Given** region 表已存在某 `phone_md5`，**When** 扫描到含该 `phone_md5` 的业务行，**Then** 批量预检命中后直接跳过，不发 FC 解密请求，不执行 INSERT。
2. **Given** 预检未命中但并发场景下 INSERT 触发 `uk_phone_md5` 唯一键冲突，**When** 捕获 `DuplicateKeyException`，**Then** 计入 `skippedExistsCount`，记录 info 日志，任务继续。
3. **Given** 同一批内两行 `phone_md5` 相同，**When** 处理该批，**Then** 只处理第一行，第二行计入 `skippedExistsCount`。

### 用户故事 3 - 明文已退役的行走 FC 解密（优先级：P1）

`PhonePlaintextRetirementService` 已把部分业务表明文 `phone` 列覆盖为掩码（`UPDATE t SET phone = phone_mask`），掩码无法还原前 7 位号段；这些行必须用 FC DataSecurity 解密 `phone_aes` 还原手机号。

**独立测试**：构造 `phone` 含 `*` 的行，断言对 `decryptPhone` 的入参为该行 `phone_aes`；构造明文有效行，断言不调解密。

**验收场景**：

1. **Given** 某行 `phone` 含 `*`（已退役）且预检未命中，**When** 处理该行，**Then** 调 FC DataSecurity（businessType=2, dataType=1, data=phone_aes）解密，用 `aesDecrypt` 结果取前 7 位查 `phone_segment`。
2. **Given** 某行 `phone` 明文有效（非空且不含 `*`），**When** 处理该行，**Then** 直接取明文前 7 位，不发 FC 解密请求。
3. **Given** FC 解密失败或返回空，**When** 处理该行，**Then** 计入 `decryptFailedCount`，跳过该行，任务继续。

### 用户故事 4 - dryRun 预估（优先级：P2）

上线前先以 dryRun 模式运行，估算 FC 解密调用量与扫描规模，不产生任何外部请求和写入。

**独立测试**：dryRun=true 运行，verify 解密客户端与 INSERT 均从未被调用，计数器正常累计。

**验收场景**：

1. **Given** dryRun=true，**When** 运行刷新任务，**Then** 只执行扫描、预检与分类计数，不调 FC 解密、不执行 INSERT。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `phoneMask/phoneMd5/phoneAes`：来源业务表当前行的 `maskColumn/md5Column/aesColumn` 列值（`PhoneSecurityTargets.TARGETS` 定义列名）；赋值时机为扫描 SQL 返回即有值（WHERE 条件保证三者均非空）；下游读取位置为 region 预检 SQL 参数和 INSERT 参数。
  - `rawPhone`：来源两条路径——明文路径取业务行 `sourceColumn`（trim 后非空且不含 `*`），解密路径取 FC DataSecurity 输出 `aesDecrypt`；赋值时机为当前层现算，解密在预检过滤之后；下游读取位置为 `segment` 推导。
  - `segment`：来源 `rawPhone.trim().substring(0, 7)`（长度≥7 才推导）；赋值时机为当前层现算；下游读取位置为 `phone_segment` 查询与内存缓存 key；禁止写入 `drh_phone_security_region`。
  - `province/city`：来源 `phone_segment` 表查询结果或内存缓存；赋值时机为 INSERT 前；下游读取位置仅为 INSERT 参数；任一为空则不写。
- 下游读取字段清单：
  - region 预检 SQL 读取批内去重后的 `phone_md5` 列表。
  - `decryptPhone(phoneAes)` 读取该行 `phone_aes`。
  - `phone_segment` 查询读取 `segment`，返回 `province/city`。
  - INSERT 读取 `phone_mask, phone_md5, phone_aes, province, city` 五个参数，全部在执行前已赋值，不读取 `segment`、不读取明文。
- 空对象 / 占位对象风险：
  - 否。不构造占位 DTO；候选行用不可变私有静态类 `RegionCandidate(id, source, mask, md5, aes)` 在扫描行映射时一次性赋值；`SegmentRegion(province, city)` 由查询结果构造，province/city 为空时整行跳过，不把空省市当有效映射写入。
- 调用顺序风险：
  - 固定顺序：扫描 → 批内 md5 去重 → region 表 `phone_md5 IN` 预检 → 行分类（明文/需解密）→ FC 解密 → segment 解析（缓存优先）→ 逐行 INSERT。必须先预检后解密，已存在的 `phone_md5` 不得发 FC 请求。
  - 不存在调用后赋值：所有 INSERT 参数在执行前于当前层现算完毕。
  - 不允许先插入空省市再补齐（与 spec 079 一致）。
- 旧逻辑保持：
  - `PhoneSecurityBackfillService`、`PhonePlaintextRetirementService`、`PhoneSecurityBackfillAdminController`、`DefaultPhoneSecurityEncryptClient`、`PhoneSecurityTargets` 的代码与行为零修改。
  - kkhc Recorder 的线上写入旁路不受影响（本任务幂等插入与其互不冲突，唯一键兜底）。
  - FC 加密契约（businessType=1）不变；解密为新增调用路径，契约对齐 kkhc 已有的 `decryptPhoneAes`（businessType=2），不发明新契约。
- 需要用户确认的设计选择：
  - 已确认（2026-06-12）：数据来源 = 扫描 `PhoneSecurityTargets` 45 张业务表。
  - 已确认（2026-06-12）：region 已存在相同 `phone_md5` 跳过不处理。
  - 已确认（2026-06-12）：明文优先，掩码行走 FC 解密 `phone_aes`（接受 FC 解密调用量）。
  - 默认采用（如需推翻请追加 Dxxx）：新增 `admin/phone-security-region-refresh` 管理接口属于本需求"增加更新线上数据的接口"的直接要求；互斥为单向（不反向修改现有任务类）；start() 做两表 preflight 探活。

## 边界情况

- 业务行三个安全字段任一为空：不进扫描结果，按表 COUNT 计入 `skippedNoSecurityCount`，日志提示先跑 encrypt backfill。
- 明文为空或含 `*`：走 FC 解密路径；解密失败/返回空：`decryptFailedCount`，跳过。
- 手机号（明文或解密结果）trim 后不足 7 位：`invalidPhoneCount`，跳过。
- `phone_segment` 未命中前 7 位，或命中但 `province/city` 为空：`skippedNoSegmentCount`，跳过，不缓存负结果（与 kkhc Recorder 一致）。
- region 表已存在 `phone_md5`（预检命中 / 批内重复 / 唯一键冲突）：`skippedExistsCount`，跳过。
- INSERT 或查询非重复键异常：`failedCount`，warn 日志（不含明文手机号），继续处理后续行。
- 单表处理异常：记录该表失败，继续下一张表，最终状态 `COMPLETED_WITH_ERRORS`。
- backfill 或 retirement 任务运行中：start 返回 `accepted=false`。
- preflight 探活失败（数据源缺 `drh_phone_security_region` 或 `phone_segment` 表）：start 返回 `accepted=false` 并附明确消息，不进入 RUNNING。
- 重复 start / 进程重启：自身 AtomicBoolean 互斥；无断点续跑，幂等重跑即可（重跑时已存在记录走预检跳过，FC 流量趋零）。

## 需求 *(必填)*

### 功能需求

- **FR-001**：juzi-service MUST 新增 `POST admin/phone-security-region-refresh/start`（参数 `dryRun`，默认 false）与 `GET admin/phone-security-region-refresh/status` 两个管理接口，返回 `BaseResponse` 封装。
- **FR-002**：刷新任务 MUST 复用 `PhoneSecurityTargets.TARGETS` 的 45 张表清单，按 `id > lastId ORDER BY id ASC LIMIT 300` 分页扫描，扫描条件 MUST 要求 `maskColumn/md5Column/aesColumn` 三列均非空。
- **FR-003**：刷新任务 MUST 在处理前对每批做 region 表 `phone_md5 IN (...)` 批量预检，命中者跳过；MUST 先预检后解密，已存在的 `phone_md5` 不得触发 FC 解密。
- **FR-004**：明文 `sourceColumn` trim 后非空且不含 `*` 时 MUST 直接使用明文；否则 MUST 调 FC DataSecurity（businessType=2, dataType=1, data=phoneAes）解密，取输出 `aesDecrypt`。
- **FR-005**：省市 MUST 来源于 `phone_segment` 表按手机号前 7 位查询，`segment -> province/city` MUST 使用服务内 `ConcurrentHashMap` 缓存，不缓存负结果。
- **FR-006**：INSERT MUST 且仅写 `drh_phone_security_region(phone_mask, phone_md5, phone_aes, province, city)` 五列；`created_at/updated_at` 由 DB 默认值生成。
- **FR-007**：系统 MUST NOT 在 `drh_phone_security_region` 写入 `segment` 或明文手机号；MUST NOT 在 province/city 任一为空时写入。
- **FR-008**：`DuplicateKeyException` MUST 计入已存在并继续；其他异常 MUST 只记日志（不含明文）不中断任务。
- **FR-009**：系统 MUST NOT 更新 region 表已存在记录（存在不处理，与 spec 079 语义一致）。
- **FR-010**：start() MUST 在 backfill 或 plaintext-retirement 任务运行中时拒绝启动；MUST 对 `drh_phone_security_region` 与 `phone_segment` 两表做 preflight 探活，失败则拒绝。
- **FR-011**：dryRun=true 时 MUST 只做扫描、预检与分类计数，MUST NOT 发 FC 解密请求、MUST NOT 执行 INSERT。
- **FR-012**：status 接口 MUST 返回 running/runId/state/currentTarget/dryRun/startedAt/endedAt 与全部计数器（selected/skippedNoSecurity/skippedExists/decrypted/decryptFailed/invalidPhone/skippedNoSegment/inserted/failed）。
- **FR-013**：系统 MUST NOT 修改任何现有类的代码与行为（全部新增文件），MUST NOT 新增 Maven 依赖。
- **FR-014**：单元测试 MUST 断言下游参数内容：INSERT 的精确列清单与参数值、SQL 不含 `segment` 子串、FC 解密入参 businessType=2/dataType=1/data=phoneAes、预检 SQL 含 `phone_md5 IN`；MUST 覆盖正常、边界与不回归路径；MUST NOT 真实访问数据库或 FC。

## 成功标准 *(必填)*

- **SC-001**：刷新任务运行后，45 张业务表中安全字段齐全、号段可解析且 region 表缺失的手机号均被补齐为一条省市映射记录。
- **SC-002**：region 表已存在的 `phone_md5` 不产生第二条记录、不被更新，重跑任务 `insertedCount` 趋零且不产生 FC 解密流量。
- **SC-003**：明文已退役的行通过 FC 解密成功补齐映射；明文有效的行零 FC 解密调用。
- **SC-004**：静态检查确认新代码不存在 `segment` 落库字段、不存在明文手机号落库。
- **SC-005**：现有 backfill / retirement 接口与服务行为零回归（不修改其任何文件）。
- **SC-006**：`mvn -pl juzi-service test` 目标测试全部通过，编译通过。

## 假设

- juzi-service 生产数据源（Nacos `juzi-service-config`）所连接的 MySQL 库中存在 `drh_phone_security_region` 与 `phone_segment` 两表（代码静态不可证，由 start() preflight 兜底；如假设被推翻需追加 Dxxx）。
- 线上 `drh_phone_security_region` 建表与 spec 079 DDL 一致：`uk_phone_md5` 唯一索引存在，`created_at/updated_at` 有 `DEFAULT CURRENT_TIMESTAMP`（运维核查 `SHOW CREATE TABLE`）。
- 业务行内 `phone_md5` 与 `phone_aes` 配对一致（历史脏数据不做交叉校验，与 kkhc Recorder 同等限制）。
- `phone_segment` 表字段为 `segment/province/city`（与 kkhc `PhoneSegment` 实体 `@TableName("phone_segment")` 一致）。
- FC DataSecurity 解密契约为 businessType=2/dataType=1，输出取 `aesDecrypt`（与 kkhc `DataSecurityInvoke.decryptPhoneAes` 一致）；函数名按 `mqConfig.getJuzi_tag()` 切换 `DataSecurity-test` / `DataSecurity-pro`。
- 45 张表全量扫描为小时级一次性管理任务，FC 解密 4 并发为可接受流量（上线前 dryRun 预估）。
- 单向互斥可接受：本任务运行期间需运维纪律保证不手动启动 backfill / retirement（不反向修改现有类）。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档（2026-06-12）。
- 已完成代码事实确认：juzi-service 对 `drh_phone_security_region`/`phone_segment` 零引用；写表逻辑仅在 kkhc `PhoneSecurityRegionRecorder`；juzi-service backfill 绕过 Recorder 造成历史缺口；明文退役会把 `phone` 列覆盖为掩码。
- 已完成用户确认：数据来源为 45 张业务表扫描；已存在 `phone_md5` 跳过；掩码行走 FC 解密。
- 本阶段未修改业务代码、未执行 DDL。

### D002 - 实现记录

- 待实现后填写：实现内容、影响范围、测试命令、测试结果、自检结论。

### D003 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
