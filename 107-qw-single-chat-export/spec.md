# 功能规格：单账号 5 月 23 日至 6 月 23 日私聊导出

**功能目录**：`107-qw-single-chat-export`  
**创建日期**：`2026-06-23`  
**状态**：Implemented  
**输入**：用户要求在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档，并使用 `C:\workspace\ju-chat\qw-user-message-export` 导出 `15110230427` 这个账号的私聊记录。时间窗口为 2026-05-23 至 2026-06-23（近 1 个月）。执行范围为文档 + 实现 + 验证。

## 背景

- 当前问题：现有 `export`、`jun3-chat-export`、`may15-chat-export` 模式的固定账号列表和时间窗口都不满足本次诉求（单账号 `15110230427`、2026-05-23 至 2026-06-23）。
- 当前行为：`export` 固定两账号近 15 天；`jun3-chat-export` 固定四账号从 2026-06-03 到运行时刻；`may15-chat-export` 固定 13 账号 2026-05-15 至 2026-06-15；三者都通过 `OtsMessageRepository.findExportMessages → buildExportRequest` 查询并应用私聊过滤（排除 `is_group=true`）。
- 目标行为：新增 `--mode single-chat-export`，固定导出 `15110230427` 在 `2026-05-23 00:00:00` 到 `2026-06-23 23:59:59.999`（Asia/Shanghai，闭区间）内的**私聊**聊天记录，复用既有私聊查询，**排除群聊**。
- 非目标：不修改既有 `export`、`jun3-chat-export`、`may15-chat-export`、`open-rate`、`open-rate-all`、`activity-rate`、`interaction-rate`、`piano-daily-open-rate` 等模式行为；不新增 OTS 表/索引；不新增 CSV 列；不导出群聊；不导出原始 OTS JSON。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 固定单账号导出（优先级：P1）

运营或数据人员需要导出单个企业微信账号 `15110230427` 的私聊聊天记录，用于核对和分析。

**独立测试**：使用 fake `OtsMessageRepository` 捕获查询参数，运行新模式，验证只查询 `15110230427` 这一个 `user_id`。

**验收场景**：

1. **Given** 运行 `--mode single-chat-export`，**When** 系统开始查询，**Then** 处理 `15110230427`。
2. **Given** OTS 中存在其他 `user_id` 的记录，**When** 导出完成，**Then** 其他账号记录不进入输出文件。
3. **Given** 该账号没有匹配记录，**When** 导出完成，**Then** 任务正常完成并生成汇总（导出 0 条）。
4. **Given** 该账号 OTS 查询抛异常，**When** 导出，**Then** 记录到 `errors.log`，`failedUsers` 计数加一。

### 用户故事 2 - 固定时间窗口导出（优先级：P1）

数据人员只需要 2026 年 5 月 23 日至 6 月 23 日（含两端）的记录。

**独立测试**：捕获 OTS 查询时间戳，验证开始时间为 `2026-05-23 00:00:00 Asia/Shanghai`，结束时间为 `2026-06-23 23:59:59.999 Asia/Shanghai`，且不随运行时刻变化。

**验收场景**：

1. **Given** 记录时间等于 `2026-05-23 00:00:00 Asia/Shanghai`，**When** 查询，**Then** 该记录可进入结果。
2. **Given** 记录时间早于 `2026-05-23 00:00:00 Asia/Shanghai`，**When** 查询，**Then** 该记录不进入结果。
3. **Given** 记录时间等于 `2026-06-23 23:59:59.999 Asia/Shanghai`，**When** 查询，**Then** 该记录可进入结果。
4. **Given** 记录时间在 `2026-06-24 00:00:00 Asia/Shanghai` 及之后，**When** 查询，**Then** 该记录不进入结果。

### 用户故事 3 - 只导出私聊双方文本（优先级：P1）

导出结果必须包含私聊中老师和学员双方文本，便于完整复盘一对一沟通上下文；群聊消息不进入结果。

**独立测试**：复用私聊 `buildExportRequest` 的私聊过滤；在 App 层用 fake repository 验证私聊老师/学员消息进入结果，撤回、空文本与无法解析的记录被剔除。

**验收场景**：

1. **Given** 某条记录 `is_group=true`，**When** 导出，**Then** 该群聊记录**不进入**结果。
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

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - 固定账号：新增常量 `SINGLE_CHAT_EXPORT_USER_IDS`，1 个 `user_id`（`15110230427`），调用 OTS 前已确定。
  - 固定开始时间：`LocalDate.of(2026, 5, 23).atStartOfDay(Asia/Shanghai)` 转毫秒，调用 OTS 前确定。
  - 固定结束时间：`LocalDate.of(2026, 6, 23).plusDays(1).atStartOfDay(Asia/Shanghai).minus(1ms)` 转毫秒（即 2026-06-23 23:59:59.999），调用 OTS 前确定，不依赖运行时刻。
  - OTS 查询字段：固定使用 `user_id`，不随 `--field` 切换。
  - OTS 表/索引：`OtsMessageRepository` 固定 `juzi_private_message` / `juzi_private_message_index`。
- 下游读取字段清单：
  - 本模式复用私聊 `buildExportRequest`：查询条件含 `term(user_id)` + `timestamp` 闭区间 + 私聊 should 子句（`is_group` 不存在或 `is_group=false`），按 `timestamp ASC` 排序。
  - 返回列沿用 `EXPORT_COLUMNS`：`payload`、`timestamp`、`message_source`、`isSelf`、`type`、`recall`、`is_group`、`chat_name`、`contact_name`、`external_user_id`、`user_id`。
  - `MessageExportApp.exportUser` 读取 `payload`、`recall`、`external_user_id`、`message_source`、`isSelf`、`chat_name`、`contact_name`、`timestamp`。
  - `OtsUnionIdResolver` 读取 `drh_emp_external_user.external_userid` 并返回 `union_id`；`external_user_id` 可能为空，对应 `union_id` 写空值，不阻断导出。
- 空对象 / 占位对象风险：
  - 不新增 DTO；fake repository 返回空集合表示无数据，不把空查询参数下传到真实 OTS。
- 调用顺序风险：
  - 账号、开始时间、结束时间必须先算好，再调用查询；`union_id` 查询在拿到 `external_user_id` 后逐条执行或缓存。
- 旧逻辑保持：
  - 既有 `export`、`jun3-chat-export`、`may15-chat-export` 入口和结果不变；私聊 `findExportMessages`/`buildExportRequest` 不变。
  - `RollingCsvWriter` 的表头、CSV 转义、10MB 切分和超大单行异常处理不变。
  - `MessageTextExtractor` 的 `payload.text` 解析、撤回跳过、空文本跳过、换行单行化不变。
  - `OtsMessageRepository` 的分页、token、时间窗切片和 timestamp 升序口径不变。
- 需要用户确认的设计选择：
  - 已确认：标识为企业微信员工 `user_id`（`15110230427`），查 OTS `user_id` 字段。
  - 已确认：时间窗口为 2026-05-23 至 2026-06-23（近 1 个月）。
  - 已确认：只导出私聊，排除群聊。
  - 已确认：沿用既有七列 CSV。

## 边界情况

- 账号无记录：不视为失败，汇总中成功账号导出 0 条。
- 账号 OTS 查询失败：记录 `errors.log`，`failedUsers` 计数加一。
- 单条消息 payload 非法 JSON：记录 `MESSAGE_PARSE` 错误并继续处理后续消息。
- 私聊消息 `external_user_id` 为空：`union_id` 写空值，不阻断导出。
- `union_id` 查询不到或查询失败：沿用现有逻辑写空值。
- 群聊判定：`is_group=true` 排除；`is_group=false` 或 `is_group` 不存在视为私聊导出。
- 老师和学员双方消息：不按 `isSelf` 过滤，输出中转换为 `老师发送` / `学员发送`。
- 时间边界：`timestamp >= startTimestamp` 且 `timestamp <= endTimestamp`，闭区间。
- 时区：自然日起点和终点按 `Asia/Shanghai` 计算。
- 单文件大小：沿用 `--max-file-mb`，默认 10MB；不得截断单条 CSV 行。
- 真实跑数需配置 OTS 环境变量 `endpoint`、`accessKey`、`accessSecret`、`instance`。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs\107-qw-single-chat-export` 维护本 Spec Kit 文档。
- **FR-002**：后续实现 MUST 在 `C:\workspace\ju-chat\qw-user-message-export` 新增 `--mode single-chat-export`（含下划线别名 `single_chat_export`）。
- **FR-003**：新模式 MUST 保持既有 CLI 模式行为不变。
- **FR-004**：新模式 MUST 固定处理 `15110230427` 这一个 `user_id`。
- **FR-005**：新模式 MUST 使用 OTS 查询字段 `user_id`，即使传入 `--field external_user_id` 也不切换。
- **FR-006**：新模式 MUST 固定开始时间为 `2026-05-23 00:00:00 Asia/Shanghai`。
- **FR-007**：新模式 MUST 固定结束时间为 `2026-06-23 23:59:59.999 Asia/Shanghai`，不依赖运行时刻。
- **FR-008**：新模式 MUST 使用 `timestamp` 毫秒字段做闭区间过滤。
- **FR-009**：新模式 MUST **只导出私聊**记录，复用私聊 `buildExportRequest` 过滤，排除 `is_group=true`。
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
- **FR-021**：单个账号失败 MUST 记录到 `errors.log`，不中断整体导出。
- **FR-022**：单元测试 MUST 覆盖 mode 解析、分派、固定账号、固定时间窗口、`user_id` 字段、私聊过滤和 CSV 输出。

## 成功标准 *(必填)*

- **SC-001**：本目录包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：文档中没有模板占位符或未澄清标记残留。
- **SC-003**：规格明确目标项目、目标模式、固定账号、OTS 表/索引和查询字段。
- **SC-004**：规格明确时间窗口为 `2026-05-23 00:00:00` 到 `2026-06-23 23:59:59.999`（Asia/Shanghai，闭区间）。
- **SC-005**：规格明确导出口径为只导出私聊，排除 `is_group=true`。
- **SC-006**：规格明确输出 CSV 七列和文本解析规则。
- **SC-007**：实现完成后，新模式不改变现有模式测试结果。
- **SC-008**：实现完成后，新增或更新的 JUnit 测试能断言关键 OTS 查询参数和输出内容。

## 假设

- 用户提供的 `15110230427` 对应 OTS 字段 `user_id`（企业微信员工账号），与既有模式账号类型一致。
- `timestamp` 单位为毫秒，与现有 `OtsMessageRepository` 口径一致。
- `payload` 为 JSON 字符串，目标文本位于顶层 `text` 字段。
- `recall=1` 表示撤回消息，应跳过。
- "近 1 个月"指 2026-05-23 至 2026-06-23，且含 6 月 23 日全天（结束取当日 23:59:59.999）。
- 群聊/私聊由 `is_group` 字段区分，群聊与私聊消息存在于同一张 `juzi_private_message` 表；本模式只取私聊（`is_group` 不存在或为 `false`）。
- 沿用既有七列 CSV。
- 真实 OTS 跑数前由执行环境提供 `endpoint`、`accessKey`、`accessSecret`、`instance`。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档（AGENTS.md、spec.md、tasks.md、checklists/requirements.md）。
- 已完成代码事实确认：目标落点为 `qw-user-message-export` 的 CLI mode 分派、OTS repository、文本解析器、CSV writer 和相关 JUnit 测试。
- 已记录后续实现口径：新增 `--mode single-chat-export`，固定单账号 `15110230427`，固定 2026-05-23 至 2026-06-23 窗口，只导出私聊。
- 已通过 AskUserQuestion 确认：时间范围 5-23 至 6-23、新增 CLI 模式、执行范围为文档+实现+验证。

### D002 - 实现记录

- 实现内容：
  - `ExportConfig`：新增枚举 `SINGLE_CHAT_EXPORT`，`parseMode` 支持 `single-chat-export` 与下划线别名 `single_chat_export`，更新 usage。
  - `MessageExportApp`：新增常量 `SINGLE_CHAT_EXPORT_START_DATE=2026-05-23`、`SINGLE_CHAT_EXPORT_END_DATE=2026-06-23`、`SINGLE_CHAT_EXPORT_USER_IDS`（`15110230427`）；`run` 新增分派；新增 `singleChatExport(config)` 方法，复用既有私聊 `exportMessages`。
  - `README.md`：补充 `single-chat-export` 模式说明。
- 接口口径：新模式固定使用 OTS 字段 `user_id`，`--field` 不影响；时间窗口固定，`--days` 不影响；`--output` 和 `--max-file-mb` 继续生效，`--input` 不生效。
- 既有私聊 `findExportMessages`/`buildExportRequest` 未改动，`export`/`jun3-chat-export`/`may15-chat-export` 仍只导出私聊。
- 测试结果：目标用例 `mvn ... test` BUILD SUCCESS，Tests run: 38, Failures: 0；完整 `mvn test` BUILD SUCCESS，Tests run: 73, Failures: 0, Skipped: 1（既有真实 OTS 集成测试条件跳过）。
- 自检结论：固定单账号 `15110230427`、固定时间窗口、默认 `user_id` 字段、私聊过滤（排除群聊）、CSV 输出、双方消息保留、单账号失败不中断均有测试覆盖；当前未真实访问 OTS。

### D003 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
