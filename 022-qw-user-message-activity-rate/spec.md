# 功能规格：企微用户近 30 天活跃度统计

**功能目录**: `022-qw-user-message-activity-rate`  
**创建日期**: 2026-05-19  
**状态**: Implemented  
**输入**: 用户要求在 `C:\workspace\ju-chat\specs` 增加 Spec Kit 文档，并在 `qw-user-message-export` 中新增 `activity-rate` 模式。该模式读取项目目录下的 `userIds.txt` 销售名单，按最近 30 天统计客户活跃度，私聊和群聊都纳入，输出 CSV 汇总和 TXT 明细；同时不改变既有 `export`、`open-rate`、`open-rate-all` 的开口率计算口径。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 从 `userIds.txt` 读取销售名单（优先级：P1）

运营或数据整理人员将销售 `qwUserId` 放入项目目录下的 `userIds.txt`。运行 `activity-rate` 模式后，系统应按文件顺序读取所有有效销售 id，并逐个生成统计结果。

**独立测试**：准备包含空行、前后空格和重复 id 的 `userIds.txt`，运行 `activity-rate`，验证系统跳过空行、裁剪空白并按明确策略去重。

**验收场景**：

1. **Given** `userIds.txt` 存在且每行一个有效销售 id，**When** 启动 `activity-rate`，**Then** 系统按文件顺序处理每个销售 id。
2. **Given** `userIds.txt` 中存在空行或只有空白字符的行，**When** 启动 `activity-rate`，**Then** 系统跳过这些行。
3. **Given** `userIds.txt` 不存在或没有有效销售 id，**When** 启动 `activity-rate`，**Then** 系统应给出明确失败原因且不创建空结果文件。
4. **Given** `userIds.txt` 中存在重复销售 id，**When** 启动 `activity-rate`，**Then** 系统应去重后处理，避免重复销售输出重复行。

### 用户故事 2 - 统计最近 30 天客户活跃度（优先级：P1）

运营或数据整理人员需要按销售查看最近 30 天内的客户活跃情况。统计工具应按销售查询 OTS 中最近 30 天的聊天消息，私聊和群聊都纳入，凡是出现过至少一条 `isSelf=false` 用户侧消息的客户都视为活跃。

**独立测试**：准备同一销售下包含私聊、群聊、仅销售发言、仅客户发言、双向消息和回撤消息的测试数据，运行 `activity-rate`，验证总用户数、活跃人数、未活跃人数和活跃率正确。

**验收场景**：

1. **Given** 某客户在最近 30 天内出现过至少一条 `isSelf=false` 的私聊或群聊消息，**When** 统计活跃度，**Then** 该客户记为活跃。
2. **Given** 某客户在最近 30 天内只有销售侧消息，即 `isSelf=true`，**When** 统计活跃度，**Then** 该客户记为未活跃。
3. **Given** 某客户在最近 30 天内既有私聊消息又有群聊消息，**When** 统计活跃度，**Then** 私聊和群聊都计入该客户的活跃判定。
4. **Given** 某条消息被回撤，**When** 统计活跃度，**Then** 后续实现应沿用现有口径跳过该消息。

### 用户故事 3 - 输出每个销售的 CSV 汇总（优先级：P1）

后续数据核对需要机器可读的汇总文件。`activity-rate` 模式应输出 CSV，每个销售一行，并在末尾追加 `TOTAL` 汇总行，方便直接导入表格工具。

**独立测试**：准备两个销售的样例数据，运行 `activity-rate`，检查 CSV 是否包含表头、每个销售一行，以及末尾 `TOTAL` 行。

**验收场景**：

1. **Given** 一个销售有 3 个客户，其中 2 个活跃、1 个未活跃，**When** 生成 CSV，**Then** 该行应输出 `total_users=3`、`active_users=2`、`inactive_users=1` 和对应活跃率。
2. **Given** 另一个销售只有 2 个客户，其中 1 个活跃、1 个未活跃，**When** 生成 CSV，**Then** 该行应输出对应统计值。
3. **Given** 所有销售的统计完成，**When** 查看 CSV 末尾，**Then** 系统应输出 `TOTAL` 行，包含总活跃人数、总活跃率和总用户数。
4. **Given** 总活跃人数和总活跃率，**When** 生成 CSV，**Then** `activity_rate` 应保留 2 位小数并带 `%`。

### 用户故事 4 - 输出 TXT 明细，保留样本消息（优先级：P1）

人工核对时需要可读的明细文件。`activity-rate` 模式应输出 TXT，先给出总体摘要，再按销售输出活跃名单和未活跃名单；活跃名单应保留一条样本消息，优先输出可读的 `text`，并保留原始 `payload` 便于追溯。

**独立测试**：准备活跃和未活跃客户混合数据，运行 `activity-rate`，检查 TXT 是否包含总体摘要、按销售分段、活跃 / 未活跃名单和样本消息。

**验收场景**：

1. **Given** 某客户已活跃，**When** 生成 TXT，**Then** 系统应输出该客户的 `chat_name` 和一条样本消息。
2. **Given** 某客户未活跃，**When** 生成 TXT，**Then** 系统至少应输出该客户的 `chat_name`。
3. **Given** 某客户有多条活跃消息，**When** 生成 TXT，**Then** 默认输出窗口内最早的一条有效样本消息。
4. **Given** 某条活跃消息的 `payload` 不能解析出 `text`，**When** 生成 TXT，**Then** 系统应继续输出 `payload`，且不影响活跃统计。

### 用户故事 5 - 旧开口率模式保持不变（优先级：P1）

既有 `export`、`open-rate`、`open-rate-all` 模式已经在生产使用。新增 `activity-rate` 不应修改旧模式的开口率算法、分组口径或输出文件名。

**独立测试**：保留现有开口率测试数据，分别运行 `open-rate` 和 `open-rate-all`，验证输出仍然与新增模式之前一致。

**验收场景**：

1. **Given** 运行 `--mode open-rate`，**When** 查看结果，**Then** 旧的新增学员开口率逻辑保持不变。
2. **Given** 运行 `--mode open-rate-all`，**When** 查看结果，**Then** 旧的全量学员开口率逻辑保持不变。
3. **Given** 运行 `--mode export`，**When** 查看结果，**Then** 旧的私聊导出逻辑保持不变。

## 边界情况

- `userIds.txt` 不存在、为空或全部为空白。
- 同一销售在统计窗口内没有任何消息。
- 同一销售的客户只有销售侧消息，没有客户侧消息。
- 同一客户在多个销售名下出现，汇总时需要去重。
- 客户消息在私聊和群聊中同时出现。
- `payload` 非法 JSON、`text` 为空或仅空白。
- 回撤消息出现在统计窗口内。
- 输出目录不存在时应自动创建。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下维护本 Spec Kit 目录。
- **FR-002**：`qw-user-message-export` MUST 新增 `activity-rate` 模式。
- **FR-003**：`activity-rate` 模式 MUST 从项目目录下的 `userIds.txt` 读取销售 id。
- **FR-004**：`userIds.txt` MUST 支持每行一个 `qwUserId`，空行和空白行必须跳过。
- **FR-005**：系统 SHOULD 默认对重复销售 id 去重，避免重复输出。
- **FR-006**：`activity-rate` 模式 MUST 统计最近 30 天的聊天消息。
- **FR-007**：统计窗口 MUST 按 `Asia/Shanghai` 计算。
- **FR-008**：`activity-rate` 模式 MUST 将私聊和群聊都纳入统计。
- **FR-009**：`activity-rate` 模式 MUST 以 `external_user_id` 作为客户统计键。
- **FR-010**：`activity-rate` 模式 MUST 将出现过至少一条 `isSelf=false` 消息的客户视为活跃。
- **FR-011**：`activity-rate` 模式 MUST 将只出现销售侧消息的客户视为未活跃。
- **FR-012**：`activity-rate` 模式 MUST 输出 CSV 汇总文件。
- **FR-013**：CSV MUST 包含 `user_id,total_users,active_users,inactive_users,activity_rate` 表头。
- **FR-014**：CSV MUST 为每个销售输出一行。
- **FR-015**：CSV MUST 在末尾输出 `TOTAL` 汇总行。
- **FR-016**：`TOTAL` 行 MUST 输出总活跃人数、总活跃率、总用户数和总未活跃人数。
- **FR-017**：`activity_rate` 值 MUST 保留 2 位小数并带 `%`。
- **FR-018**：`activity-rate` 模式 MUST 输出 TXT 明细文件。
- **FR-019**：TXT MUST 输出总体摘要、每个销售的活跃 / 未活跃名单，以及样本消息。
- **FR-020**：活跃名单 MUST 优先输出可读的 `text`，并保留原始 `payload`。
- **FR-021**：未活跃名单 MUST 至少输出 `chat_name`。
- **FR-022**：`activity-rate` 模式 MUST 支持单个销售统计失败后继续处理其他销售，失败信息应体现在 TXT 中。
- **FR-023**：`activity-rate` 模式 MUST 跳过回撤消息，沿用现有 `recall=1` 口径。
- **FR-024**：新增模式 MUST 不修改 `export`、`open-rate`、`open-rate-all` 的既有口径与输出文件名。

## 成功标准 *(必填)*

- **SC-001**：`activity-rate` 模式可以从 `userIds.txt` 正常读取销售名单。
- **SC-002**：`activity-rate` 模式按最近 30 天输出每个销售的活跃度统计。
- **SC-003**：CSV 中每个销售的 `total_users`、`active_users`、`inactive_users` 和 `activity_rate` 可被正确核对。
- **SC-004**：CSV 末尾的 `TOTAL` 行输出总活跃人数和总活跃率。
- **SC-005**：TXT 中可清晰看到活跃名单、未活跃名单和样本消息。
- **SC-006**：私聊和群聊都能计入活跃度统计。
- **SC-007**：新增模式上线后，现有开口率模式的结果不发生回归。

## 假设

- “最近 30 天”按执行时刻向前回溯 30 天计算。
- 总活跃人数和总活跃率按全量销售去重后的 `external_user_id` 汇总，不按销售简单相加。
- 活跃度以客户是否发送过消息为主，不要求客户必须是新增联系人。
- `userIds.txt` 中存放的是销售 `qwUserId`。
- `activity-rate` 模式输出的 CSV 和 TXT 会在同一次运行中同时生成。

## 执行记录

### D001 - 实现记录

- `qw-user-message-export` 已新增 `--mode activity-rate`。
- 已实现按 `userIds.txt` 读取销售列表、最近 30 天滚动窗口、私聊和群聊活跃度统计。
- 已实现 `activity_rate_report.csv` 和 `activity_rate_report.txt` 输出。
- 已实现 CSV 末尾 `TOTAL` 汇总行，以及 TXT 中的总体摘要和样本消息输出。
- 现有 `export`、`open-rate`、`open-rate-all` 逻辑保持不变。
