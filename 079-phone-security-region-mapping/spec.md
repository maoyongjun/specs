# 功能规格：手机号安全字段与地区映射

**功能目录**：`079-phone-security-region-mapping`  
**创建日期**：`2026-06-11`  
**状态**：Draft  
**输入**：在手机号加密之后，将加密的三个字段和地区做映射，统一处理。涉及 DRH 和 KKHC 两个项目。参考 `PhoneSegment userProvince = phoneSegmentService.getUserProvinceV2(appletUser); appletUser.setCity(userProvince.getCity());`，其中 `city` 是城市，`province` 是省。需要新建表格，包括索引；保存时存在的手机号不处理，不存在的写入。`Segment` 与 `city/province` 的对应关系需要缓存，避免每次查数据库。用户补充：`drh_phone_security_region` 数据库表不要存 `segment`。

## 背景

- 当前问题：手机号安全字段已在多张业务表中生成，但手机号安全字段与省市归属地没有统一映射表；现有 `PhoneSegmentServiceImpl` 仍按手机号前 7 位直接查询 `phone_segment`。
- 当前行为：
  - DRH `drh-endpoint`、`drh-callback` 中 `getUserProvinceV2(AppletUser)` 通过 `appletUser.getPhone().substring(0, 7)` 查询 `phone_segment.segment`，再把 `PhoneSegment.city/province` 写回 `AppletUser`。
  - KKHC `kkhc-idc\broadcast` 中 `getCity(String)` 同样按手机号前 7 位查询 `phone_segment.segment`。
  - 多次解析同一 `segment` 会重复查 `phone_segment`。
- 目标行为：
  - 手机号安全字段通过统一 `DataSecurityInvoke.buildPhoneSecurity()` 生成后，统一写入 `drh_phone_security_region`，保存 `phone_mask`、`phone_md5`、`phone_aes`、`province`、`city`。
  - 地区映射写入不放在 `PhoneSegmentServiceImpl` 中，避免只覆盖省市解析链路而遗漏其他手机号加密场景。
  - `phone_md5` 已存在时不重复处理；不存在时插入映射。
  - 手机号前 7 位只作为运行时查询 `phone_segment` 和缓存 key，不写入新表。
  - `segment -> province/city` 做服务内缓存，减少数据库查询。
- 非目标：
  - 不在 `drh_phone_security_region` 保存明文手机号。
  - 不在 `drh_phone_security_region` 保存 `segment`。
  - 不新增对外 HTTP API，不改变 Controller 入参和返回结构。
  - 不改变 `AppletUser.city`、`AppletUser.province` 的业务含义。
  - 不把缓存做成新的 Redis key 契约。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 首次解析手机号时写入省市映射（优先级：P1）

当系统通过统一手机号加密入口生成安全字段后，应将手机号安全字段与省市关系写入统一映射表，供后续治理和查询使用。

**独立测试**：构造一个未存在 `phone_md5` 的手机号，调用 `DataSecurityInvoke.buildPhoneSecurity()`，断言插入 `drh_phone_security_region` 的字段包含 `phone_mask/phone_md5/phone_aes/province/city`，且不包含 `segment`。

**验收场景**：

1. **Given** 手机号为可识别手机号且 `phone_segment` 存在对应前 7 位，**When** 调用统一 `buildPhoneSecurity()` 生成安全字段，**Then** 向 `drh_phone_security_region` 插入一条手机号安全字段与省市映射。
2. **Given** `drh_phone_security_region` 已存在相同 `phone_md5`，**When** 再次加密同一手机号，**Then** 不重复插入、不更新已有映射，且加密返回不受影响。

### 用户故事 2 - 号段省市关系走缓存（优先级：P1）

同一个手机号前 7 位对应的 `province/city` 应缓存，避免每次都查询 `phone_segment`。

**独立测试**：连续两次解析同一前 7 位的不同手机号，断言第一次查询 `phone_segment`，第二次从缓存返回，不再查询 `phone_segment`。

**验收场景**：

1. **Given** 缓存中没有某个 `segment`，**When** 首次解析该号段手机号，**Then** 查询 `phone_segment` 并把 `segment -> PhoneSegment` 放入服务内缓存。
2. **Given** 缓存中已有某个 `segment`，**When** 再次解析该号段手机号，**Then** 直接使用缓存中的 `province/city`，不查询 `phone_segment`。

### 用户故事 3 - 边界情况保持旧行为（优先级：P1）

当手机号为空、长度不足、号段不存在或安全字段生成失败时，系统不得影响原业务主流程。

**独立测试**：分别传入空手机号、长度不足 7 位手机号、无法命中号段手机号、加密工具返回空，断言方法返回空 `PhoneSegment` 或旧结果，不写新表，不抛异常。

**验收场景**：

1. **Given** 手机号为空或长度不足 7 位，**When** 调用省市解析，**Then** 返回空 `PhoneSegment`，不写 `drh_phone_security_region`。
2. **Given** `phone_segment` 查不到前 7 位，**When** 调用省市解析，**Then** 返回空 `PhoneSegment`，不写 `drh_phone_security_region`。
3. **Given** 安全字段生成失败，**When** 已解析出省市，**Then** 记录日志且不写映射表，原省市返回不受影响。

## 数据模型与 DDL

### 新增表

表名：`drh_phone_security_region`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `BIGINT UNSIGNED` | 主键 |
| `phone_mask` | `VARCHAR(32)` | 手机号掩码展示值 |
| `phone_md5` | `CHAR(32)` | 手机号 MD5，唯一幂等键 |
| `phone_aes` | `VARCHAR(255)` | 手机号 AES 密文 |
| `province` | `VARCHAR(64)` | 省 |
| `city` | `VARCHAR(64)` | 城市 |
| `created_at` | `DATETIME` | 创建时间 |
| `updated_at` | `DATETIME` | 更新时间 |

明确禁止字段：

- 不得包含 `phone` 明文字段。
- 不得包含 `segment` 字段。

完整 DDL 见 [phone-security-region-mapping-ddl.sql](./phone-security-region-mapping-ddl.sql)。

### 索引

- `PRIMARY KEY (id)`
- `UNIQUE KEY uk_phone_md5 (phone_md5)`
- `KEY idx_province_city (province, city)`

## 统一处理口径

- `segment` 计算：从归一化后的手机号取前 7 位，仅保存在方法局部变量或服务内缓存 key。
- 省市来源：优先从本地缓存 `segment -> PhoneSegment` 读取；缓存未命中时查询 `phone_segment.segment`。
- 手机号安全字段来源：
  - DRH 使用 `com.drh.common.fc.datasec.DataSecurityInvoke.buildPhoneSecurity()` 或同等现有工具。
  - KKHC 使用 `com.kkhc.common.utils.fc.datasec.DataSecurityInvoke.buildPhoneSecurity()` 或模块内同等现有工具。
- 统一入口：
  - `buildPhoneSecurity()` 成功生成 `phone_mask/phone_md5/phone_aes` 后通过 `PhoneSecurityRegionRecorder` 旁路触发映射保存。
  - `computePhoneMd5()` 作为查询/归一化路径，调用不触发映射保存的内部加密路径，避免读查询写库。
- 映射写入：仅当 `phone_md5` 非空、`phone_mask` 非空、`phone_aes` 非空，且已解析出 `province/city` 时，按 `phone_md5` 幂等插入。
- 幂等策略：先按 `phone_md5` 查 `drh_phone_security_region`；存在则不处理，不存在则插入。并发下允许依赖 `uk_phone_md5` 防重复，唯一键冲突按已存在处理。
- 失败策略：映射表查询或插入失败只记录日志，不阻断原 `PhoneSegment` 返回和上游业务保存。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `phoneInput`：来源所有调用统一手机号加密方法的业务对象或入参；赋值时机为调用 `DataSecurityInvoke.buildPhoneSecurity()` 前；下游读取位置为 recorder 旁路记录。
  - `segment`：来源归一化手机号前 7 位；赋值时机为当前层现算；下游读取位置为 `phone_segment` 查询和服务内缓存；禁止写入 `drh_phone_security_region`。
  - `phoneMask/phoneMd5/phoneAes`：来源 `DataSecurityInvoke.buildPhoneSecurity(phoneInput)`；赋值时机为映射插入前；下游读取位置为 `PhoneSecurityRegionRecorder` 插入参数。
  - `province/city`：来源 `PhoneSegment.province/city`；赋值时机为 recorder 查询 `phone_segment` 或命中缓存后；下游读取位置为原 `AppletUser.setProvince/setCity` 和映射插入参数。
- 下游读取字段清单：
  - `getUserProvinceV2(AppletUser)` 返回 `PhoneSegment.city`、`PhoneSegment.province`。
  - `AppletUserServiceImpl` 和 `LiveAuthServiceImpl` 读取返回对象后调用 `setCity()`、`setProvince()`。
  - `PhoneSecurityRegionRecorder` 插入读取 `phoneMask`、`phoneMd5`、`phoneAes`、`province`、`city`，不得读取 `segment` 作为落库字段。
- 空对象 / 占位对象风险：
  - 现有方法在空手机号或未命中时返回 `new PhoneSegment()`；该旧行为保留。
  - 新增映射插入前必须检查安全字段和省市来源，不允许把空安全字段或空省市当作有效映射写入。
- 调用顺序风险：
  - 必须在统一加密入口先生成安全字段，再由 recorder 使用归一化手机号计算 `segment`、解析省市，最后按 `phone_md5` 幂等写入。
  - 不允许先插入空省市映射，再依赖后续流程补齐。
  - 不允许在 `appletUser.setCity/setProvince` 后才发现省市为空仍写表。
- 旧逻辑保持：
  - 空手机号、长度不足 7 位、号段未命中仍返回空 `PhoneSegment`。
  - `AreaUtil.firstCity(one.getCity())` 分支和原 OTS/IP 处理逻辑不得因映射表写入被删除。
  - 原 Controller、MQ、Redis、Feign、FC 调用契约不变。
- 需要用户确认的设计选择：
  - 已确认：`drh_phone_security_region` 不保存 `segment`。
  - 默认：缓存使用服务内内存缓存，不新增 Redis key 契约。

## 边界情况

- 手机号为空：返回空 `PhoneSegment`，不查 `phone_segment`，不写映射。
- 手机号长度不足 7 位：返回空 `PhoneSegment`，不写映射。
- 前端 AES 密文或明文手机号：沿用现有手机号安全工具的归一化能力；无法归一化时不写映射。
- `phone_segment` 未命中：返回空 `PhoneSegment`，不写映射。
- `phone_segment` 命中但 `province/city` 为空：不写映射，保留原返回。
- 安全字段生成失败：不写映射，记录日志，不阻断原流程。
- 映射表查询失败或插入失败：记录日志，不阻断原流程。
- 并发重复插入：`uk_phone_md5` 冲突视为已存在，不抛出业务异常。
- 缓存失效或服务重启：重新按 `phone_segment` 查询并回填本地缓存。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 新增 `drh_phone_security_region` 表，保存 `phone_mask`、`phone_md5`、`phone_aes`、`province`、`city` 和审计时间字段。
- **FR-002**：系统 MUST 为 `drh_phone_security_region.phone_md5` 建立唯一索引，用于判断“存在的手机号不处理，不存在的写入”。
- **FR-003**：系统 MUST 为 `drh_phone_security_region(province, city)` 建立普通索引。
- **FR-004**：系统 MUST NOT 在 `drh_phone_security_region` 中新增或写入 `segment` 字段。
- **FR-005**：系统 MUST NOT 在 `drh_phone_security_region` 中保存明文手机号字段。
- **FR-006**：系统 MUST 在 DRH `DataSecurityInvoke.buildPhoneSecurity()` 统一手机号加密入口接入映射保存，覆盖实际调用该入口的运行模块。
- **FR-007**：系统 MUST 在 KKHC `base-common` 和 `ai-common` 的 `DataSecurityInvoke.buildPhoneSecurity()` 统一手机号加密入口接入映射保存，覆盖实际调用该入口的运行模块。
- **FR-008**：系统 MUST 缓存 `segment -> PhoneSegment` 关系，缓存 key 不落库。
- **FR-009**：系统 MUST 在映射写入前按 `phone_md5` 查询是否已存在，存在则不处理。
- **FR-010**：系统 MUST 在空手机号、长度不足 7 位、号段未命中、安全字段生成失败时不写映射，并保持旧返回行为。
- **FR-011**：系统 MUST 在映射表写入失败时记录日志，不阻断原业务主流程。
- **FR-012**：单元测试 MUST 覆盖首次写入、重复手机号不写、缓存命中、缓存未命中、新表参数不含 `segment`、边界不写入。

## 成功标准 *(必填)*

- **SC-001**：规格目录中存在完整 DDL 文件，且 `drh_phone_security_region` DDL 不包含 `segment` 字段。
- **SC-002**：DDL 包含 `uk_phone_md5` 唯一索引和 `idx_province_city` 普通索引。
- **SC-003**：实现后 DRH 和 KKHC 的目标解析链路均能在首次解析手机号时写入安全字段与省市映射。
- **SC-004**：实现后相同手机号重复解析不会新增第二条映射记录。
- **SC-005**：实现后相同 `segment` 的连续解析可命中缓存，减少 `phone_segment` 查询。
- **SC-006**：空手机号、短手机号、号段未命中、加密失败和映射写入失败均不影响原业务主流程。
- **SC-007**：静态检查确认实体、DDL、Mapper XML 和 insert 参数均不存在 `segment` 字段写入。

## 假设

- “加密的三个字段”统一解释为 `phone_mask`、`phone_md5`、`phone_aes`。
- “存在的手机号”以 `phone_md5` 判断。
- 手机号前 7 位只用于查询和缓存 `phone_segment`，不写入 `drh_phone_security_region`。
- `province` 保存省，`city` 保存城市。
- 缓存默认使用服务内内存缓存，缓存 `segment -> PhoneSegment`，不新增 Redis key 契约。
- 新表不保存明文手机号，也不保存 `segment`。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成代码事实确认：DRH 存在 `getUserProvinceV2(AppletUser)`，KKHC 存在 `getCity(String)`，两侧均按手机号前 7 位查询 `phone_segment`。
- 已按用户补充明确：`drh_phone_security_region` 不保存 `segment`。
- 本阶段未修改业务代码、未执行 DDL。

### D002 - 实现记录

- 状态：已废弃，保留为历史记录。用户后续明确要求改为在统一加密方法 `DataSecurityInvoke` 中处理所有手机号加密场景。
- 实现内容：
  - DRH `drh-endpoint`、`drh-callback` 新增 `PhoneSecurityRegion` 实体、Mapper、Service，并在 `PhoneSegmentServiceImpl` 中接入 `segment -> PhoneSegment` 服务内缓存和 `phone_md5` 幂等映射写入。
  - KKHC `kkhc-idc\broadcast-common`、`kkhc-idc\broadcast` 新增同等实体、Mapper、Service，并在 `PhoneSegmentServiceImpl` 中接入同样的缓存和映射写入。
  - 新增实体均不包含 `segment` 字段；`segment` 只作为运行时局部变量和缓存 key 使用。
- 影响范围：
  - DRH：`getUserProvince()`、`getUserProvinceV2()`、`getCity(String)`、`getCity(LiveUser)` 的旧返回语义保持不变，新增省市映射旁路写入。
  - KKHC：`getCity(String)`、`getCity(LiveUser)` 的旧返回语义保持不变，新增省市映射旁路写入。
- 测试命令：
  - `mvn -pl broadcast -am -DskipTests clean compile`
  - `mvn -pl drh-endpoint,drh-callback -DskipTests compile`
  - `mvn -pl drh-callback -DskipTests compile`
- 测试结果：
  - KKHC `broadcast` 目标链路 `clean compile` 通过。
  - DRH 编译进入目标模块后失败在既有公共实体/安全字段不一致问题，例如 `SubmitTime`、`AppletBlackPhone`、`UserAddress` 等缺少历史 phone-security 字段或方法；失败未指向本次新增的 `PhoneSecurityRegion` 和 `PhoneSegmentService` 改动。
- 自检结论：
  - 静态检查确认 `PhoneSecurityRegion` 实体、Mapper、Service 不包含 `segment` 字段写入。
  - DDL 仍明确不包含 `segment` 字段。
  - 映射写入失败会被捕获并记录日志，不阻断原省市解析结果返回。

### D003 - 纠正记录模板

- 触发原因：用户明确指出上一版只在 `PhoneSegmentServiceImpl` 中处理不正确，需要在统一加密方法 `DataSecurityInvoke` 中处理所有手机号加密场景。
- 修正内容：
  - 恢复 DRH endpoint/callback 与 KKHC broadcast 的 `PhoneSegmentService` 原职责，不再在其中生成安全字段或写映射。
  - DRH common、KKHC base-common、KKHC ai-common 的 `DataSecurityInvoke.buildPhoneSecurity()` 成功生成安全字段后触发 `PhoneSecurityRegionRecorder`。
  - `computePhoneMd5()` 改为调用不触发写库的内部加密路径，避免查询侧写库。
  - 各运行模块提供 recorder Bean，内部缓存 `segment -> PhoneSegment`，按 `phone_md5` 幂等写入 `drh_phone_security_region`。
- 文档同步：已同步 `spec.md`、`tasks.md`、DDL 仍不包含 `segment`。
- 验证结果：后续记录编译与静态检查结果。
