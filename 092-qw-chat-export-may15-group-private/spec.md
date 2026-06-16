# 功能规格：13 账号 5 月 15 日至 6 月 15 日私聊导出

**功能目录**：`092-qw-chat-export-may15-group-private`（历史编号；当前口径为仅私聊）
**创建日期**：`2026-06-16`
**状态**：Implemented（D003 后口径改为仅私聊）
**输入**：用户要求在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档，并导出 13 个企业微信员工账号在指定时间段内的聊天记录。已确认：标识对应 OTS `user_id` 字段；时间范围为 2026-05-15 至 2026-06-15；执行范围为文档 + 实现 + 验证。**最初口径为群聊+私聊都导出，用户随后（D003）纠正为只导出私聊、排除群聊。**

## 背景

- 当前问题：现有 `export`、`jun3-chat-export` 都只导出私聊，但固定账号与时间窗口都不满足本次诉求（13 个固定账号、2026-05-15 至 2026-06-15）。
- 当前行为：`export` 固定两账号近 15 天；`jun3-chat-export` 固定四账号从 2026-06-03 到运行时刻；两者都通过 `OtsMessageRepository.findExportMessages → buildExportRequest` 查询并应用私聊过滤（`buildPrivateMessageQuery` 排除 `is_group=true`）。
- 目标行为：新增 `--mode may15-chat-export`，固定导出 13 个指定 `user_id` 在 `2026-05-15 00:00:00` 到 `2026-06-15 23:59:59.999`（Asia/Shanghai，闭区间）内的**私聊**聊天记录，复用既有私聊查询，**排除群聊**。
- 非目标：不修改既有 `export`、`jun3-chat-export`、`open-rate`、`open-rate-all`、`activity-rate`、`interaction-rate`、`piano-daily-open-rate` 等模式行为；不新增 OTS 表/索引；不新增 CSV 列；不导出群聊；不导出原始 OTS JSON。

## 用户场景与测试

### 用户故事 1 - 固定 13 账号导出（优先级：P1）

运营或数据人员需要只导出列表中 13 个企业微信账号的聊天记录，用于核对和分析。

**独立测试**：使用 fake `OtsMessageRepository` 捕获查询参数，运行新模式，验证只查询这 13 个 `user_id`，且按固定顺序处理。

**验收场景**：

1. **Given** 运行 `--mode may15-chat-export`，**When** 系统开始查询，**Then** 按固定顺序处理 `15101530402`、`15711286796`、`15711287096`、`15711287178`、`17801336372`、`15810091597`、`15711307826`、`15711287256`、`15711369328`、`15711287069`、`ZhangLiang_2`、`XiaoLiWei_1`、`zhonganqi1`。
2. **Given** OTS 中存在其他 `user_id` 的记录，**When** 导出完成，**Then** 其他账号记录不进入输出文件。
3. **Given** 13 个账号中某个账号没有匹配记录，**When** 导出完成，**Then** 任务继续处理剩余账号并生成汇总。
4. **Given** 某个账号 OTS 查询抛异常，**When** 导出，**Then** 记录到 `errors.log` 并继续处理剩余账号，`failedUsers` 计数加一。

### 用户故事 2 - 固定时间窗口导出（优先级：P1）

数据人员只需要 2026 年 5 月 15 日至 6 月 15 日（含两端）的记录。

**独立测试**：捕获 OTS 查询时间戳，验证开始时间为 `2026-05-15 00:00:00 Asia/Shanghai`，结束时间为 `2026-06-15 23:59:59.999 Asia/Shanghai`，且不随运行时刻变化。

**验收场景**：

1. **Given** 记录时间等于 `2026-05-15 00:00:00 Asia/Shanghai`，**When** 查询，**Then** 该记录可进入结果。
2. **Given** 记录时间早于 `2026-05-15 00:00:00 Asia/Shanghai`，**When** 查询，**Then** 该记录不进入结果。
3. **Given** 记录时间等于 `2026-06-15 23:59:59.999 Asia/Shanghai`，**When** 查询，**Then** 该记录可进入结果。
4. **Given** 记录时间在 `2026-06-16 00:00:00 Asia/Shanghai` 及之后，**When** 查询，**Then** 该记录不进入结果。

### 用户故事 3 - 只导出私聊双方文本（优先级：P1）

导出结果必须包含私聊中老师和学员双方文本，便于完整复盘一对一沟通上下文；群聊消息不进入结果。

**独立测试**：复用私聊 `buildExportRequest` 的私聊过滤（`OtsMessageRepositoryTest.exportRequestFiltersPrivateChatsAndKeepsTimestampSort` 已断言排除群聊）；在 App 层用 fake repository 验证私聊老师/学员消息进入结果，撤回、空文本与无法解析的记录被剔除。

**验收场景**：

1. **Given** 某条记录 `is_group=true`，**When** 导出，**Then** 该群聊记录**不进入**结果（与 `export`/`jun3-chat-export` 一致）。
2. **Given** 某条记录 `is_group=false` 或 `is_group` 不存在，**When** 导出，**Then** 该私聊记录进入结果。
3. **Given** 某条私聊记录 `isSelf=true`，**When** 导出，**Then** 该消息进入结果并标记 `老师发送`。
4. **Given** 某条私聊记录 `isSelf=false`，**When** 导出，**Then** 该消息进入结果并标记 `学员发送`。
5. **Given** 某条记录 `recall=1`，**When** 导出，**Then** 该撤回消息跳过。
6. **Given** `payload.text` 为空、缺失或只有空白，**When** 导出，**Then** 该行不写入主 CSV，计入 `skippedMessages`。

### 用户故事 4 - 输出稳定 CSV（优先级：P1）

数据人员需要可导入表格工具的稳定格式，沿用现有七列 CSV，并保留 `union_id` 和格式化时间。

**独立测试**：准备含逗号、引号和换行的文本，验证 CSV 表头、列顺序、转义、单行化和 10MB 文件切分行为。

**验收场景**：

1. **Given** 有效私聊文本记录，**When** 写入输出，**Then** CSV 表头为 `message_source,isSelf,chat_name,contact_name,union_id,timestamp,text`。
2. **Given** 私聊消息，**When** 写入，**Then** `chat_name` 与 `contact_name` 同为对方名。
3. **Given** 文本包含换行、逗号或引号，**When** 写入 CSV，**Then** 换行被单行化，逗号和引号按 CSV 规则转义。
4. **Given** 下一行写入会超过单文件大小限制，**When** 写入，**Then** 系统切换到新的 `messages_NNN.csv` 文件且不截断单行。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - 固定账号列表：新增常量 `MAY15_CHAT_EXPORT_USER_IDS`，13 个 `user_id`，调用 OTS 前已确定。
  - 固定开始时间：`LocalDate.of(2026, 5, 15).atStartOfDay(Asia/Shanghai)` 转毫秒，调用 OTS 前确定。
  - 固定结束时间：`LocalDate.of(2026, 6, 15).plusDays(1).atStartOfDay(Asia/Shanghai).minus(1ms)` 转毫秒（即 2026-06-15 23:59:59.999），调用 OTS 前确定，不依赖运行时刻。
  - OTS 查询字段：固定使用 `user_id`，不随 `--field` 切换。
  - OTS 表/索引：`OtsMessageRepository` 固定 `juzi_private_message` / `juzi_private_message_index`。
- 下游读取字段清单：
  - 本模式复用私聊 `buildExportRequest`：查询条件含 `term(user_id)` + `timestamp` 闭区间 + 私聊 should 子句（`is_group` 不存在或 `is_group=false`），按 `timestamp ASC` 排序。
  - 返回列沿用 `EXPORT_COLUMNS`：`payload`、`timestamp`、`message_source`、`isSelf`、`type`、`recall`、`is_group`、`chat_name`、`contact_name`、`external_user_id`、`user_id`。
  - `MessageExportApp.exportUser` 读取 `payload`、`recall`、`external_user_id`、`message_source`、`isSelf`、`chat_name`、`contact_name`、`timestamp`。
  - `OtsUnionIdResolver` 读取 `drh_emp_external_user.external_userid` 并返回 `union_id`；群聊消息 `external_user_id` 可能为空，对应 `union_id` 写空值，不阻断导出。
- 空对象 / 占位对象风险：
  - 不新增 DTO；fake repository 返回空集合表示无数据，不把空查询参数下传到真实 OTS。
- 调用顺序风险：
  - 账号列表、开始时间、结束时间必须先算好，再调用查询；`union_id` 查询在拿到 `external_user_id` 后逐条执行或缓存。
- 旧逻辑保持：
  - 既有 `export`（固定两账号、15 天、私聊）、`jun3-chat-export`（固定四账号、6-03 起、私聊）入口和结果不变；私聊 `findExportMessages`/`buildExportRequest` 不变。
  - `RollingCsvWriter` 的表头、CSV 转义、10MB 切分和超大单行异常处理不变。
  - `MessageTextExtractor` 的 `payload.text` 解析、撤回跳过、空文本跳过、换行单行化不变。
  - `OtsMessageRepository` 的分页、token、时间窗切片和 timestamp 升序口径不变。
- 需要用户确认的设计选择（已确认）：
  - 标识为企业微信员工 `user_id`，查 OTS `user_id` 字段。
  - 时间窗口为 2026-05-15 至 2026-06-15（含两端）。
  - 只导出私聊，排除群聊（D003 纠正，最初为群聊+私聊）。
  - 沿用既有七列 CSV。

## 边界情况

- 任一账号无记录：不视为失败，汇总中成功账号仍可为 0 条导出。
- 单个账号 OTS 查询失败：记录 `errors.log`，继续处理其他账号。
- 单条消息 payload 非法 JSON：记录 `MESSAGE_PARSE` 错误并继续处理后续消息。
- 私聊消息 `external_user_id` 为空：`union_id` 写空值，不阻断导出。
- `union_id` 查询不到或查询失败：沿用现有逻辑写空值。
- 群聊判定：`is_group=true` 排除；`is_group=false` 或 `is_group` 不存在视为私聊导出。
- 老师和学员双方消息：不按 `isSelf` 过滤，输出中转换为 `老师发送` / `学员发送`。
- 时间边界：`timestamp >= startTimestamp` 且 `timestamp <= endTimestamp`，闭区间。
- 时区：自然日起点和终点按 `Asia/Shanghai` 计算。
- 单文件大小：沿用 `--max-file-mb`，默认 10MB；不得截断单条 CSV 行。
- 真实跑数需配置 OTS 环境变量 `endpoint`、`accessKey`、`accessSecret`、`instance`。

## 需求

### 功能需求

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs\092-qw-chat-export-may15-group-private` 维护本 Spec Kit 文档。
- **FR-002**：后续实现 MUST 在 `C:\workspace\ju-chat\qw-user-message-export` 新增 `--mode may15-chat-export`（含下划线别名 `may15_chat_export`）。
- **FR-003**：新模式 MUST 保持既有 CLI 模式行为不变。
- **FR-004**：新模式 MUST 固定处理列表中的 13 个 `user_id`，并按规定顺序处理。
- **FR-005**：新模式 MUST 使用 OTS 查询字段 `user_id`，即使传入 `--field external_user_id` 也不切换。
- **FR-006**：新模式 MUST 固定开始时间为 `2026-05-15 00:00:00 Asia/Shanghai`。
- **FR-007**：新模式 MUST 固定结束时间为 `2026-06-15 23:59:59.999 Asia/Shanghai`，不依赖运行时刻。
- **FR-008**：新模式 MUST 使用 `timestamp` 毫秒字段做闭区间过滤。
- **FR-009**：新模式 MUST **只导出私聊**记录，复用私聊 `buildExportRequest` 过滤，排除 `is_group=true`（D003 纠正，最初为群聊+私聊）。
- **FR-010**：新模式 MUST 复用既有 `findExportMessages` 私聊查询路径，不新增群聊专用查询。
- **FR-011**：新模式 MUST 保留 `isSelf=true` 和 `isSelf=false` 双方消息，不按 `isSelf` 过滤。
- **FR-012**：新模式 MUST 只输出可从 `payload.text` 解析出的非空文本。
- **FR-013**：新模式 MUST 跳过 `recall=1` 的撤回消息。
- **FR-014**：新模式 MUST 输出 CSV 表头 `message_source,isSelf,chat_name,contact_name,union_id,timestamp,text`。
- **FR-015**：新模式 MUST 按现有口径将 `isSelf=true` 输出为 `老师发送`，`isSelf=false` 输出为 `学员发送`。
- **FR-016**：新模式 MUST 按 `yyyy-MM-dd HH:mm:ss` 和 `Asia/Shanghai` 输出 `timestamp`。
- **FR-017**：新模式 MUST 通过 `drh_emp_external_user` 按 `external_userid` 查询并输出 `union_id`；查不到或为空时写空值。
- **FR-018**：新模式 MUST 支持 OTS 分页、token 和时间窗切片，避免单页限制漏数。
- **FR-019**：新模式 MUST 按 `timestamp ASC` 输出，便于人工阅读。
- **FR-020**：新模式 MUST 沿用 `RollingCsvWriter` 的文件切分和 CSV 转义逻辑。
- **FR-021**：单个账号失败 MUST 记录到 `errors.log` 并继续处理剩余账号，不中断整体导出。
- **FR-022**：单元测试 MUST 覆盖 mode 解析、分派、固定 13 账号、固定时间窗口、`user_id` 字段、群聊不排除、CSV 输出和单账号失败不中断。

## 成功标准

- **SC-001**：本目录包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：文档中没有模板占位符或未澄清标记残留。
- **SC-003**：规格明确目标项目、目标模式、固定 13 账号、OTS 表/索引和查询字段。
- **SC-004**：规格明确时间窗口为 `2026-05-15 00:00:00` 到 `2026-06-15 23:59:59.999`（Asia/Shanghai，闭区间）。
- **SC-005**：规格明确导出口径为只导出私聊，排除 `is_group=true`（D003 纠正后口径）。
- **SC-006**：规格明确输出 CSV 七列和文本解析规则。
- **SC-007**：实现完成后，新模式不改变现有模式测试结果。
- **SC-008**：实现完成后，新增或更新的 JUnit 测试能断言关键 OTS 查询参数（含群聊不排除）和输出内容。

## 假设

- 用户口中的“手机号”和句柄 `ZhangLiang_2`/`XiaoLiWei_1`/`zhonganqi1` 都对应 OTS 字段 `user_id`（企业微信员工账号），与既有 `export`/`jun3-chat-export` 账号一致。
- `timestamp` 单位为毫秒，与现有 `OtsMessageRepository` 口径一致。
- `payload` 为 JSON 字符串，目标文本位于顶层 `text` 字段。
- `recall=1` 表示撤回消息，应跳过。
- “5 月 15 到 6 月 15”指 2026 年，且含 6 月 15 日全天（结束取当日 23:59:59.999）。
- 群聊/私聊由 `is_group` 字段区分，群聊与私聊消息存在于同一张 `juzi_private_message` 表；本模式只取私聊（`is_group` 不存在或为 `false`）。
- 沿用既有七列 CSV。
- 真实 OTS 跑数前由执行环境提供 `endpoint`、`accessKey`、`accessSecret`、`instance`。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档（AGENTS.md、spec.md、tasks.md、checklists/requirements.md）。
- 已完成代码事实确认：目标落点为 `qw-user-message-export` 的 CLI mode 分派、OTS repository、文本解析器、CSV writer 和相关 JUnit 测试。
- 已记录后续实现口径：新增 `--mode may15-chat-export`，固定 13 账号，固定 2026-05-15 至 2026-06-15 窗口，群聊+私聊都导出。
- 已通过 AskUserQuestion 确认：标识为 `user_id`、时间范围 5-15 至 6-15、执行范围为文档+实现+验证。

### D002 - 实现记录

- 实现内容：
  - `ExportConfig`：新增枚举 `MAY15_CHAT_EXPORT`，`parseMode` 支持 `may15-chat-export` 与下划线别名 `may15_chat_export`，更新 usage。
  - `MessageExportApp`：新增常量 `MAY15_CHAT_EXPORT_START_DATE=2026-05-15`、`MAY15_CHAT_EXPORT_END_DATE=2026-06-15`、`MAY15_CHAT_EXPORT_USER_IDS`（13 账号）；`run` 新增分派；新增 `may15ChatExport(config)`；`exportMessages`/`exportUser` 增加 `includeGroupMessages` 开关，新模式传 `true`。
  - `OtsMessageRepository`：新增 `findAllChatMessages`（时间切片 + range-split + 分页/token），新增 `buildAllChatExportRequest`（不含私聊 should 子句、不含 `external_user_id` exists、固定 `user_id`、timestamp 闭区间、timestamp ASC、`EXPORT_COLUMNS`）。
  - `README.md`：补充 `may15-chat-export` 模式说明。
- 接口口径：新模式固定使用 OTS 字段 `user_id`，`--field` 不影响；时间窗口固定，`--days` 不影响；`--output` 和 `--max-file-mb` 继续生效，`--input` 不生效。
- 既有私聊 `findExportMessages`/`buildExportRequest` 未改动，`export`/`jun3-chat-export` 仍只导出私聊。
- 测试结果：目标用例 `mvn ... test` BUILD SUCCESS，Tests run: 35, Failures: 0；完整 `mvn test` BUILD SUCCESS，Tests run: 70, Failures: 0, Skipped: 1（既有真实 OTS 集成测试条件跳过）。详见 `tasks.md` D002。
- 自检结论：固定 13 账号、固定时间窗口、默认 `user_id` 字段、群聊不排除、CSV 输出、双方消息保留、单账号失败不中断均有测试覆盖；当前未真实访问 OTS。

### D003 - 纠正：群聊+私聊改为仅私聊

- 触发原因：D002 实现并真实跑数（导出 1,627,495 条、71 个 CSV、约 705 MB）后，用户纠正“不导出群聊，只导出私聊的”。
- 旧口径：`may15-chat-export` 同时导出群聊和私聊，使用新增的 `findAllChatMessages`/`buildAllChatExportRequest`（不应用私聊过滤、不强制 `external_user_id` exists）。
- 新口径：`may15-chat-export` 只导出私聊，复用既有 `findExportMessages`/`buildExportRequest`（私聊 should 子句排除 `is_group=true`），口径与 `export`/`jun3-chat-export` 一致；固定 13 账号和 2026-05-15～2026-06-15 窗口不变。
- 代码修改：
  - `MessageExportApp.may15ChatExport` 改为调用私聊 `exportMessages`（不带群聊开关）；移除 `includeGroupMessages` 开关及 6 参重载，`exportUser` 恢复仅调用 `findExportMessages`。
  - `OtsMessageRepository` 移除 `findAllChatMessages`、`findAllChatMessagesByTimeSlices`、`findAllChatMessagesWithRangeSplit`、`fetchAllChatMessages`、`buildAllChatExportRequest`（避免残留未使用口径）。
  - 测试：移除 `OtsMessageRepositoryTest.allChatExportRequestIncludesGroupChatsAndKeepsTimestampSort` 及其 `hasExists` 辅助；`MessageExportAppMay15ChatExportTest` 改为私聊语义（覆写 `findExportMessages`，断言私聊导出、撤回/空文本跳过、单账号失败不中断）。
  - `README.md` 改为“只导出私聊（排除 `is_group=true`）”。
- 文档同步：`spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 已同步为仅私聊口径。
- 验证结果：见 `tasks.md` D003（目标用例与完整 `mvn test`、真实重跑结果）。
