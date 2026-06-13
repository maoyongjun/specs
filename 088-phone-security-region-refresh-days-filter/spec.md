# 功能规格：phone-security-region-refresh 增量天数过滤

**功能目录**：`088-phone-security-region-refresh-days-filter`  
**创建日期**：`2026-06-13`  
**状态**：Implemented  
**输入**：在 `C:\workspace\ju-chat\specs` 创建 spec-kit 文档，修改 `C:\workspace\ju-chat\data-RC\juzi-service` 中 `phone-security-region-refresh` 接口，增加天数参数；参数为空不限制时间，设置天数时处理距离当前时间 N 天内的数据。正式库中 1 万行以下目标可不加时间筛选，1 万行以上目标需确认正确创建时间字段，例如 `create_time`。

## 背景

- 当前问题：`phone-security-region-refresh` 会扫描 `PhoneSecurityTargets` 中全部目标，线上数据量较大时一次刷新范围过宽。
- 当前行为：`POST admin/phone-security-region-refresh/start` 仅支持 `dryRun`；`queryBatch()` 和 `countMissingSecurity()` 不带时间窗口。
- 目标行为：start 接口支持可选 `days`，为空保持全量；大于 0 时对已配置创建时间列的目标追加 `>= cutoffTime` 过滤；小表或无可靠创建时间列的目标保持全量。
- 非目标：
  - 不新增数据库表、不改 DDL、不写业务表。
  - 不改变 `drh_phone_security_region` 的幂等插入语义。
  - 不改变 `PhoneSecurityBackfillService` 和 `PhonePlaintextRetirementService` 的行为。
  - 不使用更新时间字段作为创建时间筛选依据。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 按最近 N 天刷新大表（优先级：P1）

运维执行手机号地区映射刷新时，可只处理最近 N 天新增的数据，降低大表扫描成本和 FC 解密压力。

**独立测试**：构造带 `timeColumn` 的 `BackfillTarget`，调用查询构建/扫描方法，断言 SQL 包含时间列条件且 JDBC 参数包含固定 `cutoffTime`。

**验收场景**：

1. **Given** start 请求传入 `days=7` 且目标配置了 `create_time`，**When** 任务扫描该目标，**Then** candidate SQL 与 missing-security count SQL 均追加 `AND create_time >= ?`，参数为任务启动时计算的 `cutoffTime`。
2. **Given** start 请求传入 `days=7` 但目标未配置时间列，**When** 任务扫描该目标，**Then** 该目标保持现有全量扫描 SQL。
3. **Given** start 请求未传 `days`，**When** 任务运行，**Then** 所有目标保持现有全量扫描 SQL。

### 用户故事 2 - 响应暴露运行窗口（优先级：P1）

运维可以从 start/status 响应确认本次任务是全量还是按最近 N 天执行。

**独立测试**：启动 dryRun，断言 start/status 响应包含 `days` 和 `cutoffTime`；全量时两者为空。

**验收场景**：

1. **Given** `days=3`，**When** start 接受任务，**Then** start 响应返回 `days=3` 和非空 `cutoffTime`。
2. **Given** 任务运行中或结束后，**When** 查询 status，**Then** status 返回同一组 `days/cutoffTime`。
3. **Given** 未传 `days`，**When** start/status 返回，**Then** `days/cutoffTime` 均为空。

### 用户故事 3 - 非法天数拒绝启动（优先级：P1）

非法时间窗口不应进入异步任务，避免产生含糊的线上扫描范围。

**独立测试**：传入 `days=0` 或负数，断言返回 `accepted=false`，且 jobExecutor 不提交任务。

**验收场景**：

1. **Given** start 请求传入 `days=0`，**When** 调用接口，**Then** 返回逻辑错误，不启动刷新任务。
2. **Given** start 请求传入 `days=-1`，**When** 调用接口，**Then** 返回逻辑错误，不启动刷新任务。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `days`：来源 Controller `@RequestParam(required=false)`；进入 service 前为 `Integer`；启动校验时判断空、正数或非法。
  - `cutoffTime`：来源 `LocalDateTime.now().minusDays(days)`；仅在 `days > 0` 且任务 accepted 前计算一次；下游读取位置为 `queryBatch()` 和 `countMissingSecurity()`。
  - `timeColumn`：来源 `PhoneSecurityTargets` 中每个 `BackfillTarget` 的可选属性；来源依据为正式库只读查询结果；下游读取位置为 region refresh SQL 构建。
  - `phoneMask/phoneMd5/phoneAes/rawPhone/province/city`：沿用 spec 083，不改变来源、赋值时机和下游读取位置。
- 下游读取字段清单：
  - `PhoneSecurityRegionRefreshAdminController.start()` 读取 `dryRun/days`。
  - `PhoneSecurityRegionRefreshService.start()` 读取 `days` 并生成 `cutoffTime`。
  - `queryBatch()` 读取目标安全字段、`lastId`、可选 `timeColumn/cutoffTime`。
  - `countMissingSecurity()` 读取目标安全字段、可选 `timeColumn/cutoffTime`。
- 空对象 / 占位对象风险：
  - 否。`days` 和 `cutoffTime` 使用显式字段，不通过空 DTO 或 Map 透传。
- 调用顺序风险：
  - 先校验 `days`，再执行原有互斥和 preflight，再计算并记录运行窗口，最后提交异步任务。
  - `cutoffTime` 不在异步任务中重新计算，避免同一次任务内不同目标窗口漂移。
- 旧逻辑保持：
  - `days` 为空时 SQL 字符串和参数形态保持原行为。
  - 不修改 FC 解密、segment 查询、region 插入、dryRun、不重复启动、backfill/retirement 互斥。
  - `BackfillTarget` 旧 6 参数构造函数继续可用。
- 需要用户确认的设计选择：
  - 已由用户计划确认：参数名为 `days`；`days` 为空不限制；`days > 0` 按当前时间减天数；`days <= 0` 拒绝。

## 边界情况

- `days=null`：全量扫描，`cutoffTime=null`。
- `days<=0`：拒绝启动，返回明确错误。
- `days>0` 且目标无 `timeColumn`：该目标全量扫描，并在文档中说明小表或无可靠创建时间列原因。
- 大表无可靠创建时间列：不猜测，不用 update 字段，保持全量并记录风险。
- 表重复目标（如 `drh_live_user.phone` 与 `drh_live_user.app_phone`）：同一表的时间列配置可复用。
- 任务运行中重复 start：沿用既有 `accepted=false`，响应带当前任务窗口。

## 需求 *(必填)*

### 功能需求

- **FR-001**：`POST admin/phone-security-region-refresh/start` MUST 新增可选参数 `days`，`dryRun` 行为保持不变。
- **FR-002**：`days` 为空时 MUST 不限制时间，保持现有全量扫描行为。
- **FR-003**：`days > 0` 时 MUST 在任务启动时计算一次 `cutoffTime = now - days`，并在整次任务中复用。
- **FR-004**：`days <= 0` MUST 拒绝启动并返回逻辑错误。
- **FR-005**：`PhoneSecurityRegionRefreshStartResponse` 和 `PhoneSecurityRegionRefreshStatusResponse` MUST 返回 `days/cutoffTime`。
- **FR-006**：`BackfillTarget` MUST 支持可选 `timeColumn`，并保留旧 6 参数构造函数兼容现有代码和测试。
- **FR-007**：region refresh 的 candidate scan SQL 和 missing-security count SQL MUST 使用相同的时间过滤规则。
- **FR-008**：只有 `days` 非空且目标配置了 `timeColumn` 时，SQL 才能追加时间条件。
- **FR-009**：1 万行以下目标 MAY 不配置时间列；1 万行以上目标 MUST 基于正式库元数据选择创建时间字段，禁止使用更新时间字段替代。
- **FR-010**：本改动 MUST NOT 改变加密回填、明文退役、FC 解密、region 幂等插入和 dryRun 语义。
- **FR-011**：单元测试 MUST 覆盖 days 为空、有时间列、无时间列、非法 days、响应字段和旧构造函数兼容。

## 成功标准 *(必填)*

- **SC-001**：传入 `days` 时，配置时间列的大表只扫描 `cutoffTime` 之后的数据。
- **SC-002**：未传 `days` 时，刷新行为与 spec 083 实现保持一致。
- **SC-003**：1 万行以上目标的时间列配置有正式库只读查询依据；没有可靠创建时间字段的目标被显式记录。
- **SC-004**：定向单元测试和兼容测试通过。

## 假设

- 正式库 profile 为 `prod-mysql`，只读查询通过 `database-sql-skill` 执行。
- 创建时间字段优先级为 `create_time`、`createTime`、`created_at` 等创建语义字段。
- 如果正式库 metadata 显示小表不足 1 万行，即使存在创建时间字段，也可以不配置 `timeColumn`。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已记录计划中的 DB Fact Gate、接口契约、参数来源、调用顺序和测试映射。

### D002 - 正式库事实确认

- SQL 文件：`phone_security_region_refresh_target_stats.sql`。
- analyze 结果：`database-sql-skill` 判定为 `readonly`。
- 执行命令：`db_skill.py run --profile prod-mysql --file ... --format csv --output prod_target_stats.csv`。
- 查询结果：正式库返回 45 个 target 统计；`prod_target_stats.csv` 已保存到本目录。
- 目标分类：1 万行以上 target 共 22 个，均存在创建时间字段 `create_time`，已按 `create_time` 配置时间过滤；1 万行以下 target 保持无时间过滤。
- 大表 target：`drh_applet_user.phone`、`drh_submit_time.phone`、`drh_short_message_operation.phone`、`drh_live_works_user.phone`、`drh_h5_order.phone`、`drh_live_user.phone`、`drh_live_user.app_phone`、`drh_voice_robot_task_user.phone`、`drh_xe_order.phone`、`drh_sms_trigger_user.phone`、`drh_book_question_record.phone`、`drh_sms_trigger_user_callback.phone`、`drh_real_address_record.phone`、`drh_leads_noqw_send_msg_task_detail.phone`、`drh_user_form.phone`、`order_book_reissue_detail.phone`、`drh_external_book_question_record.phone`、`drh_voice_robot_callback_details.phone`、`drh_sms_deal.phone`、`drh_qwb_phone_info.phone`、`drh_order_refund_record.phone`、`drh_gx_channel.phone`。
- 静态检查：未配置 `update_time/updated_at/updateTime/updatedAt` 作为筛选字段。

### D003 - 实现记录

- 实现内容：新增 start 参数 `days`；start/status 响应增加 `days/cutoffTime`；`BackfillTarget` 增加可选 `timeColumn` 且保留旧构造函数；大表 target 配置 `create_time`；region refresh 的 candidate scan 和 missing-security count SQL 在 `days` 有效且 target 有 `timeColumn` 时追加时间条件。
- 影响范围：仅 `phone-security-region-refresh` 接口、region refresh 服务、target 配置和响应 DTO；不修改加密回填、明文退役、FC 解密或 region INSERT 语义。
- 测试命令：`mvn -pl juzi-service -DskipTests=false "-Dtest=PhoneSecurityRegionRefresh*Test,PhoneSecurityBackfillService*Test" test`。
- 测试结果：`Tests run: 16, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：`days=null` 保持全量；`days>0` 固定一次 `cutoffTime`；非法 `days<=0` 拒绝；大表使用正式库确认的 `create_time`；小表不筛选；旧 6 参数构造函数兼容。

### D004 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
