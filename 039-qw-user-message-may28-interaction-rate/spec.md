# 功能规格：5月28日私聊互动人数统计

**功能目录**：`039-qw-user-message-may28-interaction-rate`  
**创建日期**：`2026-05-29`  
**状态**：Implemented  
**输入**：用户要求在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档，并修改 `C:\workspace\ju-chat\qw-user-message-export`。以前这里计算过开口率；现在互动人数计算和开口率含义相同，但只统计 5 月 28 一天。需要统计 `15311073569` 和 `15313302127` 两个 `user_id` 下，老师给多少个学员发送了消息、多少个学员进行了回复；通过 `juzi_private_message.user_id` 查询 `is_group` 为空或 `false` 的私聊记录，按 `external_user_id` 去重统计；再统计 `isSelf=false` 且回复内容不是“已添加好友”默认回复的学员，记录任意一句回复内容，并输出比值、发送学员总数、回复学员总数和详情数据。

## 背景

- 当前问题：现有 `activity-rate` 是最近 30 天、从 `userIds.txt` 读取销售、私聊和群聊都纳入，不满足本次固定日期和固定用户的私聊统计口径。
- 当前行为：`qw-user-message-export` 已有 `export`、`open-rate`、`open-rate-all`、`activity-rate` 模式。
- 目标行为：新增独立 `interaction-rate` 模式，固定统计 2026-05-28 当天两个 `user_id` 的私聊互动人数和明细。
- 非目标：不修改旧模式，不做历史学员剔除，不新增数据库表或对外接口。

## 用户场景与测试

### 用户故事 1 - 统计发送学员总数（优先级：P1）

运营人员需要知道 2026-05-28 当天每个老师账号涉及多少个私聊学员。

**独立测试**：构造同一 `user_id` 下包含老师消息、学员消息、重复学员、群聊和空 `external_user_id` 的数据，验证分母只按当天私聊 `external_user_id` 去重。

**验收场景**：

1. **Given** 2026-05-28 当天某 `external_user_id` 有多条私聊记录，**When** 统计分母，**Then** 该学员只计 1 次。
2. **Given** 记录的 `is_group=true`，**When** 统计分母，**Then** 不纳入统计。
3. **Given** 记录的 `isSelf=false`，**When** 统计分母，**Then** 仍可进入分母，因为分母不按 `isSelf` 过滤。

### 用户故事 2 - 统计回复学员和样本内容（优先级：P1）

运营人员需要知道哪些学员在当天进行了真实回复，并看到任意一句可核对的回复内容。

**独立测试**：构造默认建联文案、默认文案后真实回复、仅老师消息、空文本和非法 JSON 等数据，验证只有非默认文案的 `isSelf=false` 文本计为回复。

**验收场景**：

1. **Given** 某学员只有默认建联文案，**When** 统计回复人数，**Then** 不计为已回复。
2. **Given** 某学员先出现默认文案后出现真实回复，**When** 统计回复人数，**Then** 计为已回复并记录真实回复。
3. **Given** 某学员有多条真实回复，**When** 生成明细，**Then** 默认记录当天最早一条有效回复。

### 用户故事 3 - 输出汇总和明细（优先级：P1）

运营人员需要在运行后直接获得可读报告和可导入表格工具的明细。

**独立测试**：准备两个 `user_id` 的样例数据，运行 `interaction-rate`，检查 TXT、汇总 CSV、明细 CSV 的文件名、表头、统计值、比值和 TOTAL 去重。

**验收场景**：

1. **Given** 每个 `user_id` 都统计成功，**When** 查看 `interaction_rate_report.csv`，**Then** 每个 `user_id` 一行，末尾有 `TOTAL`。
2. **Given** 学员已回复，**When** 查看 `interaction_rate_detail.csv`，**Then** 该行包含 `reply_message_id`、`reply_text`、`reply_payload`。
3. **Given** 同一个 `external_user_id` 出现在两个 `user_id` 下，**When** 查看 TOTAL，**Then** 总数按 `external_user_id` 跨账号去重。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - 固定日期：`MessageExportApp.interactionRate` 当前层现算为 `2026-05-28`，调用 OTS 前转成毫秒时间戳。
  - 固定 `user_id`：`MessageExportApp.INTERACTION_RATE_USER_IDS`，调用 OTS 前已确定。
  - OTS 表/索引：`OtsMessageRepository` 固定 `juzi_private_message` / `juzi_private_message_index`。
  - 私聊过滤：`OtsMessageRepository.buildPrivateMessageQuery()`，查询层限定 `is_group` 不存在或为 `false`。
  - 默认文案：复用 `OpenRateAnalyzer.isGreetingText` 的两条建联文案。
- 下游读取字段清单：
  - 分母读取 `timestamp`、`chat_name`、`contact_name`、`external_user_id`。
  - 分子读取 `payload`、`timestamp`、`recall`、`chat_name`、`contact_name`、`external_user_id`。
  - 输出读取 `user_id`、`external_user_id`、`contact_name`、回复状态、样本消息 id/text/payload。
- 空对象 / 占位对象风险：无空 DTO、空 JSON、空 Map 作为下游参数；测试 fake repository 返回空集合表示无数据。
- 调用顺序风险：时间窗口和 user_id 在查询前确定；回复明细先查询后分析，不依赖后续流程补字段。
- 旧逻辑保持：既有四个模式的入口、文件名、时间窗口和统计口径保持不变。
- 需要用户确认的设计选择：分母是否要求 `isSelf=true` 已确认选择“不加 isSelf 过滤”。

## 边界情况

- `external_user_id` 为空：跳过，不进入分母和明细。
- `is_group` 存在且为 `true`：查询层跳过。
- 同一学员重复出现：按 `external_user_id` 去重。
- 回复 payload 非法 JSON：记录错误，不计为已回复。
- 回复 text 为空或仅空白：不计为已回复。
- 默认建联文案：不计为已回复。
- 单个 `user_id` 查询失败：该 `user_id` 标记失败，其他 `user_id` 继续处理。
- OTS 环境变量缺失：真实跑数无法执行；当前实现和测试不依赖真实 OTS。

## 需求

### 功能需求

- **FR-001**：系统 MUST 新增 `--mode interaction-rate`。
- **FR-002**：系统 MUST 固定统计 `2026-05-28` 全天，时区 `Asia/Shanghai`。
- **FR-003**：系统 MUST 固定统计 `15311073569`、`15313302127`。
- **FR-004**：分母 MUST 查询私聊记录并按 `external_user_id` 去重，不额外按 `isSelf=true` 过滤。
- **FR-005**：分子 MUST 仅统计 `isSelf=false` 且非默认建联文案的有效回复文本。
- **FR-006**：系统 MUST 输出 `interaction_rate_report.txt`、`interaction_rate_report.csv`、`interaction_rate_detail.csv`。
- **FR-007**：汇总 CSV MUST 包含表头 `user_id,sent_students,replied_students,not_replied_students,reply_rate`。
- **FR-008**：明细 CSV MUST 包含表头 `user_id,external_user_id,contact_name,replied,reply_message_id,reply_text,reply_payload`。
- **FR-009**：TOTAL MUST 按 `external_user_id` 跨 `user_id` 去重统计。
- **FR-010**：新增模式 MUST NOT 修改既有模式的行为。

## 成功标准

- **SC-001**：运行 `--mode interaction-rate` 可生成 3 个输出文件。
- **SC-002**：每个目标 `user_id` 的发送学员总数、回复学员总数和比值可在 TXT 与 CSV 中核对。
- **SC-003**：每个分母学员可在明细 CSV 中看到回复状态和样本回复内容。
- **SC-004**：默认建联文案不会被误计为回复。
- **SC-005**：目标单元测试覆盖新增模式且通过。

## 假设

- “5月28号”指 `2026-05-28`。
- “已添加好友那种默认回复”复用现有开口率的两条默认建联文案。
- 不做历史学员剔除，不要求学员必须是新增联系人。
- 当前本机未配置 `endpoint`、`accessKey`、`accessSecret`、`instance`，真实 OTS 跑数需配置后执行。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成代码事实确认：目标落点为 `qw-user-message-export` 的 CLI 模式、OTS repository、分析器和 formatter。
- 已记录分母口径：私聊 `external_user_id` 去重，不按 `isSelf=true` 过滤。
- 已记录当前真实 OTS 跑数风险：缺少 OTS 环境变量。

### D002 - 实现记录

- 已新增 `interaction-rate` 模式、独立统计模型、分析器、TXT/CSV 输出和 OTS 查询。
- 已新增/更新单元测试覆盖 CLI 解析、分派、时间窗口、查询条件、默认文案排除、输出结果和 TOTAL 去重。
- 测试命令：`mvn -Dtest=ExportConfigTest,MessageExportAppModeTest,OtsMessageRepositoryTest,InteractionRateAnalyzerTest,MessageExportAppInteractionRateTest test`。
- 实际验证命令：`mvn "-Dtest=ExportConfigTest,MessageExportAppModeTest,OtsMessageRepositoryTest,InteractionRateAnalyzerTest,MessageExportAppInteractionRateTest,ActivityRateAnalyzerTest,MessageExportAppActivityRateTest" test`。
- 测试结果：BUILD SUCCESS，Tests run: 29, Failures: 0, Errors: 0, Skipped: 0。
- 真实 OTS 跑数：当前本机未配置 `endpoint`、`accessKey`、`accessSecret`、`instance`，未执行生产数据统计。
