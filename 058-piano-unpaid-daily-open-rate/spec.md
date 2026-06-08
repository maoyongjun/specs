# 功能规格：钢琴未付费批次每日开口率统计

**功能目录**：`058-piano-unpaid-daily-open-rate`  
**创建日期**：`2026-06-08`  
**状态**：Implemented  
**输入**：用户要求在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档，并计算两个企微账号下 2026-05-27、2026-06-06 添加批次从添加日起到 2026-06-08 的每日开口率；通过好友关系获取实际数量，与提供数量比对差异。

## 背景

- 当前问题：现有 `interaction-rate` 只统计 2026-05-28 单日，分母来自当天私聊消息；本次需要按好友添加批次作为分母，并逐日输出趋势。
- 当前行为：`qw-user-message-export` 已有 `export`、`open-rate`、`open-rate-all`、`activity-rate`、`interaction-rate` 模式。
- 目标行为：新增独立 `piano-daily-open-rate` 模式，固定统计四个钢琴未付费批次的好友关系人数、数量差异、当日新增开口率和累计开口率。
- 非目标：不新增数据库表，不新增对外 API，不引入 MySQL/JDBC，不修改旧模式输出和口径。

## 用户场景与测试

### 用户故事 1 - 通过好友关系核对批次人数（优先级：P1）

运营人员需要确认指定账号在 2026-05-27 或 2026-06-06 当天真实添加了多少好友，并与人工提供数量比对。

**独立测试**：构造 OTS 好友关系返回包含目标账号、非目标账号、日期内、日期外和重复 external_user_id 的数据，验证只保留目标批次并去重。

**验收场景**：

1. **Given** `follow_user.userid=15311073569` 且 `createtime` 在 2026-05-27 当天，**When** 获取 5.27 批次，**Then** 该 external_user_id 进入分母。
2. **Given** 同一 external_user_id 被重复返回，**When** 汇总批次人数，**Then** 只计 1 人。
3. **Given** 实际好友关系数量与提供数量不同，**When** 生成报告，**Then** 输出 `数量差异=实际-提供`。

### 用户故事 2 - 按天计算开口率（优先级：P1）

运营人员需要从批次添加日起到 2026-06-08，查看每天有多少批次学员首次真实回复，以及累计开口进度。

**独立测试**：构造同一学员多天多条回复、默认建联文案、非批次学员回复和回撤消息，验证首次真实回复日期、当日新增人数和累计人数正确。

**验收场景**：

1. **Given** 批次学员在 2026-05-29 首次发送真实文本，**When** 统计每日开口率，**Then** 2026-05-29 的当日新增开口人数加 1，之后累计开口人数持续包含该学员。
2. **Given** 学员只发送“我已经添加了你，现在我们可以开始聊天了。”，**When** 分析开口，**Then** 不计为开口。
3. **Given** 非批次学员在窗口内回复，**When** 分析开口，**Then** 不进入任何批次分子。

### 用户故事 3 - 输出汇总和明细（优先级：P1）

运营人员需要可导入表格的汇总文件和可核对样本消息的明细文件。

**独立测试**：使用四个批次 fake 数据运行 app，验证 3 个输出文件、CSV 表头、百分比格式、文本摘要和明细样本。

**验收场景**：

1. **Given** 四个批次都统计成功，**When** 查看 `piano_daily_open_rate_report.csv`，**Then** 每账号、每批次、每天一行。
2. **Given** 某学员已开口，**When** 查看 `piano_daily_open_rate_detail.csv`，**Then** 该行包含首次开口日期、消息 id、文本和 payload。
3. **Given** 某批次查询失败，**When** 生成 TXT，**Then** 其他批次继续输出，失败原因可见。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - 批次定义：`MessageExportApp.PIANO_DAILY_OPEN_RATE_BATCHES`，调用 OTS 前已固定。
  - 好友关系时间窗：批次日期在当前层按 `Asia/Shanghai` 转为秒级 `[start, nextDayStart)`。
  - 消息时间窗：批次日期到 2026-06-08 23:59:59.999，在当前层转为毫秒。
  - 统计结束日期：固定 `2026-06-08`。
- 下游读取字段清单：
  - `OtsFriendRelationRepository` 读取 `external_user_id`、`name`、`follow_user`。
  - `OtsMessageRepository` 读取私聊回复的 `payload`、`timestamp`、`recall`、`contact_name`、`external_user_id`。
  - `PianoDailyOpenRateAnalyzer` 读取批次 external_user_id 集合、回复文本、回复时间和样本消息。
- 空对象 / 占位对象风险：无空 DTO、空 JSON、空 Map 作为下游参数；空集合表示某批次无好友关系或无回复。
- 调用顺序风险：先查询好友关系形成分母，再查询消息并分析；不存在调用后补字段。
- 旧逻辑保持：既有五个模式的入口、文件名、时间窗口、查询条件和统计口径保持不变。
- 需要用户确认的设计选择：已确认每日同时输出当日和累计开口率；已确认主分母用企微添加时间 `follow_user.createtime`。

## 边界情况

- 好友关系缺少 `external_user_id`：跳过。
- `follow_user` 非法 JSON：记录错误，该行不进入分母。
- 同一批次 external_user_id 重复：去重保留最早添加时间和可用名称。
- 回复 payload 非法 JSON、text 为空、默认建联文案、回撤消息：不计开口。
- 某批次实际数量为 0：开口率输出 `0.00%`，不抛除零异常。
- 单个批次 OTS 查询失败：该批次标记失败，其他批次继续处理。
- 当前本机若缺少 OTS 环境变量，真实跑数无法执行，但单元测试不依赖真实 OTS。

## 需求

### 功能需求

- **FR-001**：系统 MUST 新增 `--mode piano-daily-open-rate`，并支持别名 `piano_daily_open_rate`。
- **FR-002**：系统 MUST 固定统计 2026-05-27 和 2026-06-06 两个批次日期，结束日期固定为 2026-06-08。
- **FR-003**：系统 MUST 固定统计 `15311073569`、`15313302127` 两个账号，并输出账号标签。
- **FR-004**：系统 MUST 通过 `drh_external_user_info.follow_user.userid` 和 `follow_user.createtime` 获取批次好友关系分母。
- **FR-005**：系统 MUST 输出提供数量、实际好友关系数量和数量差异。
- **FR-006**：系统 MUST 仅将批次学员的私聊真实回复计为开口。
- **FR-007**：系统 MUST 排除回撤消息、空文本、解析失败文本和默认建联文案。
- **FR-008**：系统 MUST 输出 `piano_daily_open_rate_report.csv`、`piano_daily_open_rate_detail.csv`、`piano_daily_open_rate_report.txt`。
- **FR-009**：汇总 CSV MUST 同时包含当日新增开口人数/开口率和累计开口人数/开口率。
- **FR-010**：新增模式 MUST NOT 修改既有模式行为。

## 成功标准

- **SC-001**：运行 `--mode piano-daily-open-rate` 可生成 3 个输出文件。
- **SC-002**：每个批次的提供数量、实际数量、数量差异可在 CSV 和 TXT 中核对。
- **SC-003**：每天的当日新增开口率和累计开口率可被逐行核对。
- **SC-004**：默认建联文案不会被误计为开口。
- **SC-005**：目标单元测试覆盖新增模式且通过。

## 假设

- `5.27` 和 `6.6` 均指 2026 年，时区为 `Asia/Shanghai`。
- 开口率分母使用好友关系实际数量，用户提供数量只用于差异核对。
- “接入AI/未接入AI”只作为账号标签，不额外参与数据过滤。
- OTS `follow_user.createtime` 为秒级 Unix 时间戳。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成代码事实确认：目标落点为 `qw-user-message-export` CLI 模式、OTS repository、分析器和 formatter。
- 已记录好友关系主口径、每日开口率口径和旧逻辑保持要求。

### D002 - 实现记录

- 已在 `qw-user-message-export` 新增 `--mode piano-daily-open-rate`，并支持别名 `piano_daily_open_rate`。
- 已新增好友关系 OTS repository，查询 `drh_external_user_info` / `drh_external_user_info_index`，使用 nested 查询约束同一个 `follow_user` 元素内的 `userid` 和秒级 `createtime` 时间窗。
- 已新增批次模型、每日分析器、汇总 CSV formatter、明细 CSV formatter 和 TXT formatter；四个固定批次均由 `MessageExportApp` 串联处理。
- 已输出三个文件：`piano_daily_open_rate_report.csv`、`piano_daily_open_rate_detail.csv`、`piano_daily_open_rate_report.txt`。
- 已更新 `README.md`，记录新增模式、运行命令和输出字段。
- 已运行目标测试：`mvn "-Dtest=ExportConfigTest,OtsFriendRelationRepositoryTest,PianoDailyOpenRateAnalyzerTest,PianoDailyOpenRateFormatterTest,MessageExportAppPianoDailyOpenRateTest" test`，结果通过。
- 已运行模块全量测试：`mvn test`，结果 `Tests run: 61, Failures: 0, Errors: 0, Skipped: 1`。

### D003 - 真实跑数记录

- 执行命令：`java -jar target\qw-user-message-export-1.0.0.jar --mode piano-daily-open-rate --output output\piano-daily-open-rate-20260608-1627-prod-public`。
- 输出目录：`C:\workspace\ju-chat\qw-user-message-export\output\piano-daily-open-rate-20260608-1627-prod-public`。
- 执行结果：成功批次数 `4`，失败批次数 `0`。
- 汇总 CSV：`33` 行，包含表头和 `32` 条每日统计数据。
- 明细 CSV：`10130` 行，包含表头和 `10129` 个批次学员。
- 数量比对：四个批次好友关系数量均与提供数量一致，数量差异均为 `0`。
- 最终累计开口：
  - `2026-05-27 / 15311073569 / 钢琴未付费4（接入AI）`：好友关系 `2810`，累计开口 `94`，累计开口率 `3.35%`。
  - `2026-05-27 / 15313302127 / 钢琴未付费3（未接入AI）`：好友关系 `2774`，累计开口 `74`，累计开口率 `2.67%`。
  - `2026-06-06 / 15311073569 / 钢琴未付费4（接入AI）`：好友关系 `2292`，累计开口 `14`，累计开口率 `0.61%`。
  - `2026-06-06 / 15313302127 / 钢琴未付费3（未接入AI）`：好友关系 `2253`，累计开口 `14`，累计开口率 `0.62%`。
