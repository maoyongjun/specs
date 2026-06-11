# 功能规格：四账号 6 月 3 日起私聊导出

**功能目录**：`076-qw-user-chat-export-jun3`  
**创建日期**：`2026-06-11`  
**状态**：Draft - Documentation Only  
**输入**：用户要求在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档，后续通过 OTS 表导出 `userId` 为 `maiweigml`、`LiXin`、`XieWenHao1`、`LiuYuan_3` 四个账号从 `2026-06-03` 到现在的聊天记录。已确认导出口径为私聊 CSV，后续实现新增专用模式，不覆盖现有 `export` 模式。

## 背景

- 当前问题：现有 `qw-user-message-export` 的 `export` 模式固定导出 `15311073569`、`15313302127` 最近 15 天记录，不满足本次固定四账号和固定 6 月 3 日起始窗口。
- 当前行为：`MessageExportApp.export` 使用固定账号列表、运行时向前回溯 15 天、输出七列 CSV，并通过 `OtsMessageRepository.findExportMessages` 查询 OTS 私聊记录。
- 目标行为：后续新增 `--mode jun3-chat-export`，固定导出四个指定 `user_id` 从 `2026-06-03 00:00:00 Asia/Shanghai` 到运行时刻的私聊聊天记录。
- 非目标：当前阶段不修改业务代码；后续不导出群聊、不导出原始 OTS JSON、不改变现有 `export`、`open-rate`、`interaction-rate` 等模式行为。

## 用户场景与测试

### 用户故事 1 - 固定四账号导出（优先级：P1）

运营或数据人员需要只导出 `maiweigml`、`LiXin`、`XieWenHao1`、`LiuYuan_3` 四个企业微信账号的聊天记录，用于后续核对和分析。

**独立测试**：使用 fake `OtsMessageRepository` 捕获查询参数，运行新模式，验证只查询这四个 `user_id`，且按固定顺序处理。

**验收场景**：

1. **Given** 运行 `--mode jun3-chat-export`，**When** 系统开始查询，**Then** 只处理 `maiweigml`、`LiXin`、`XieWenHao1`、`LiuYuan_3`。
2. **Given** OTS 中存在其他 `user_id` 的记录，**When** 导出完成，**Then** 其他账号记录不会进入输出文件。
3. **Given** 四个账号中某个账号没有匹配记录，**When** 导出完成，**Then** 任务继续处理剩余账号并生成汇总。

### 用户故事 2 - 固定时间窗口导出（优先级：P1）

数据人员只需要 2026 年 6 月 3 日起到导出执行时刻的记录，早于该时间的聊天不应进入结果。

**独立测试**：固定测试时钟，捕获 OTS 查询时间戳，验证开始时间为 `2026-06-03 00:00:00 Asia/Shanghai`，结束时间为 `clock.millis()`。

**验收场景**：

1. **Given** 记录时间等于 `2026-06-03 00:00:00 Asia/Shanghai`，**When** 查询，**Then** 该记录可进入结果。
2. **Given** 记录时间早于 `2026-06-03 00:00:00 Asia/Shanghai`，**When** 查询，**Then** 该记录不进入结果。
3. **Given** 记录时间等于程序运行时刻，**When** 查询，**Then** 该记录可进入结果。

### 用户故事 3 - 导出私聊双方文本（优先级：P1）

导出结果应包含私聊中的老师和学员双方文本，便于完整复盘一对一沟通上下文。

**独立测试**：构造同一 `user_id` 下私聊、群聊、老师消息、学员消息、撤回消息、空文本和非法 payload，验证只输出私聊双方的有效文本。

**验收场景**：

1. **Given** 某条记录 `is_group=true`，**When** 导出，**Then** 该记录不进入结果。
2. **Given** 某条私聊记录 `isSelf=true`，**When** 导出，**Then** 该老师消息进入结果。
3. **Given** 某条私聊记录 `isSelf=false`，**When** 导出，**Then** 该学员消息进入结果。
4. **Given** 某条记录 `recall=1`，**When** 导出，**Then** 该撤回消息跳过。
5. **Given** `payload.text` 为空、缺失或只有空白，**When** 导出，**Then** 该行不写入主 CSV。

### 用户故事 4 - 输出稳定 CSV（优先级：P1）

数据人员需要可导入表格工具的稳定格式。导出文件应沿用现有七列 CSV，并保留 `union_id` 和格式化时间。

**独立测试**：准备含逗号、引号和换行的文本，验证 CSV 表头、列顺序、转义、单行化和 10MB 文件切分行为。

**验收场景**：

1. **Given** 有效私聊文本记录，**When** 写入输出，**Then** CSV 表头为 `message_source,isSelf,chat_name,contact_name,union_id,timestamp,text`。
2. **Given** 文本包含换行、逗号或引号，**When** 写入 CSV，**Then** 换行被单行化，逗号和引号按 CSV 规则转义。
3. **Given** 下一行写入会超过单文件大小限制，**When** 写入，**Then** 系统切换到新的 `messages_NNN.csv` 文件且不截断单行。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - 固定账号列表：后续新增常量，值为 `maiweigml`、`LiXin`、`XieWenHao1`、`LiuYuan_3`；调用 OTS 前已确定。
  - 固定开始时间：后续新增 `LocalDate.of(2026, 6, 3).atStartOfDay(Asia/Shanghai)`；调用 OTS 前转成毫秒。
  - 结束时间：`clock.millis()`；调用 OTS 前确定。
  - OTS 查询字段：沿用 `ExportConfig.DEFAULT_FIELD = "user_id"`，不切换到 `external_user_id`。
  - OTS 表/索引：`OtsMessageRepository` 固定 `juzi_private_message` / `juzi_private_message_index`。
- 下游读取字段清单：
  - `OtsMessageRepository.buildExportRequest` 查询 `user_id`、`timestamp`、`is_group`，返回 `payload`、`timestamp`、`message_source`、`isSelf`、`type`、`recall`、`is_group`、`chat_name`、`contact_name`、`external_user_id`、`user_id`。
  - `MessageExportApp.exportUser` 读取 `payload`、`recall`、`external_user_id`、`message_source`、`isSelf`、`chat_name`、`contact_name`、`timestamp`。
  - `OtsUnionIdResolver` 读取 `drh_emp_external_user.external_userid` 并返回 `union_id`。
- 空对象 / 占位对象风险：
  - 无需新增 DTO；后续测试 fake repository 可以返回空集合表示无数据，不得把空查询参数下传到真实 OTS。
- 调用顺序风险：
  - 账号列表、开始时间、结束时间必须先算好，再调用 `findExportMessages`；`union_id` 查询必须在拿到 `external_user_id` 后逐条执行或缓存。
- 旧逻辑保持：
  - 现有 `export` 固定账号、15 天窗口、CSV 输出、`open-rate`、`activity-rate`、`interaction-rate`、`piano-daily-open-rate` 的入口和结果文件不变。
  - `RollingCsvWriter` 的表头、CSV 转义、10MB 切分和超大单行异常处理口径不变。
  - `MessageTextExtractor` 的 `payload.text` 解析、撤回跳过、空文本跳过、换行单行化口径不变。
  - `OtsMessageRepository` 的分页、token、时间窗切片和 timestamp 升序输出口径不变。
- 需要用户确认的设计选择：
  - 已确认：导出口径为私聊 CSV。
  - 已确认：后续实现新增模式，不覆盖现有 `export`。

## 边界情况

- 任一账号无记录：不视为失败，汇总中成功账号仍可为 0 条导出。
- 单个账号 OTS 查询失败：记录 `errors.log`，继续处理其他账号。
- 单条消息 payload 非法 JSON：记录错误并继续处理后续消息。
- `external_user_id` 为空：`union_id` 写空值，不阻断导出。
- `union_id` 查询不到或查询失败：沿用现有逻辑写空值并向 stderr 记录。
- 群聊消息：`is_group=true` 跳过；`is_group` 不存在或为 `false` 视为私聊。
- 老师和学员双方消息：不按 `isSelf` 过滤，只在输出中转换为 `老师发送` / `学员发送`。
- 时间边界：`timestamp >= startTimestamp` 且 `timestamp <= endTimestamp`。
- 时区：自然日起点按 `Asia/Shanghai` 计算。
- 单文件大小：沿用 `--max-file-mb`，默认 10MB；不得截断单条 CSV 行。
- 当前本机是否配置真实 OTS 环境变量不影响文档创建；真实跑数需配置 `endpoint`、`accessKey`、`accessSecret`、`instance`。

## 需求

### 功能需求

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs\076-qw-user-chat-export-jun3` 维护本 Spec Kit 文档。
- **FR-002**：当前阶段 MUST 只创建规格文档，不修改业务代码。
- **FR-003**：后续实现 MUST 在 `C:\workspace\ju-chat\qw-user-message-export` 新增 `--mode jun3-chat-export`。
- **FR-004**：后续实现 MUST 保持既有 CLI 模式行为不变。
- **FR-005**：新模式 MUST 固定处理 `maiweigml`、`LiXin`、`XieWenHao1`、`LiuYuan_3` 四个 `user_id`。
- **FR-006**：新模式 MUST 使用 OTS 查询字段 `user_id`，不得改用 `external_user_id`。
- **FR-007**：新模式 MUST 固定开始时间为 `2026-06-03 00:00:00 Asia/Shanghai`。
- **FR-008**：新模式 MUST 以程序运行时刻作为结束时间。
- **FR-009**：新模式 MUST 使用 `timestamp` 毫秒字段做闭区间过滤。
- **FR-010**：新模式 MUST 只导出私聊记录，排除 `is_group=true`。
- **FR-011**：新模式 MUST 保留 `isSelf=true` 和 `isSelf=false` 双方消息，不按 `isSelf` 过滤。
- **FR-012**：新模式 MUST 只输出可从 `payload.text` 解析出的非空文本。
- **FR-013**：新模式 MUST 跳过 `recall=1` 的撤回消息。
- **FR-014**：新模式 MUST 输出 CSV 表头 `message_source,isSelf,chat_name,contact_name,union_id,timestamp,text`。
- **FR-015**：新模式 MUST 按现有口径将 `isSelf=true` 输出为 `老师发送`，`isSelf=false` 输出为 `学员发送`。
- **FR-016**：新模式 MUST 按 `yyyy-MM-dd HH:mm:ss` 和 `Asia/Shanghai` 输出 `timestamp`。
- **FR-017**：新模式 MUST 通过 `drh_emp_external_user` 按 `external_userid` 查询并输出 `union_id`。
- **FR-018**：新模式 MUST 支持 OTS 分页和时间窗切片，避免单页限制漏数。
- **FR-019**：新模式 SHOULD 按 `timestamp ASC` 输出，便于人工阅读。
- **FR-020**：新模式 SHOULD 沿用 `RollingCsvWriter` 的文件切分和 CSV 转义逻辑。
- **FR-021**：单元测试 MUST 覆盖 mode 解析、固定四账号、固定开始时间、运行时结束时间、私聊过滤、双方消息保留、CSV 输出和单账号失败不中断。

## 成功标准

- **SC-001**：本目录包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：文档中没有模板占位符或未澄清标记残留。
- **SC-003**：规格明确目标项目、目标模式、固定四账号、OTS 表/索引和查询字段。
- **SC-004**：规格明确时间窗口为 `2026-06-03 00:00:00 Asia/Shanghai` 到程序运行时刻。
- **SC-005**：规格明确导出口径为私聊 CSV，排除群聊，保留双方消息。
- **SC-006**：规格明确输出 CSV 七列和文本解析规则。
- **SC-007**：后续实现完成后，新模式不会改变现有模式测试结果。
- **SC-008**：后续实现完成后，新增或更新的 JUnit 测试能断言关键 OTS 查询参数和输出内容。

## 假设

- “到现在”指程序实际运行时刻，而不是 `2026-06-11 23:59:59`。
- 用户给出的 `userId` 对应 OTS 字段 `user_id`。
- `timestamp` 单位为毫秒，与现有 `OtsMessageRepository` 口径一致。
- `payload` 为 JSON 字符串，目标文本位于顶层 `text` 字段。
- `recall=1` 表示撤回消息，应跳过。
- 真实 OTS 跑数前由执行环境提供 `endpoint`、`accessKey`、`accessSecret`、`instance`。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成代码事实确认：目标落点为 `qw-user-message-export` 的 CLI mode 分派、OTS repository、文本解析器、CSV writer 和相关 JUnit 测试。
- 已记录后续实现口径：新增 `--mode jun3-chat-export`，固定四账号，固定 2026-06-03 起始窗口，结束为运行时刻。
- 已记录导出口径：私聊 CSV，排除群聊，保留老师和学员双方消息，不按 `isSelf` 过滤。
- 本阶段未修改业务代码，未真实访问 OTS。

### D002 - 实现记录

- 实现内容：已在 `C:\workspace\ju-chat\qw-user-message-export` 新增 `--mode jun3-chat-export`，新增枚举 `JUN3_CHAT_EXPORT`，固定四账号 `maiweigml`、`LiXin`、`XieWenHao1`、`LiuYuan_3`，固定开始时间 `2026-06-03 00:00:00 Asia/Shanghai`，结束时间为运行时刻。
- 实现范围：复用现有 CSV 导出、OTS 私聊查询、分页/切片、`union_id` 查询、文本解析、错误日志和 10MB 文件切分逻辑；未修改既有 `export`、`open-rate`、`activity-rate`、`interaction-rate`、`piano-daily-open-rate` 业务口径。
- 接口口径：新模式固定使用 OTS 字段 `user_id`，即使传入 `--field external_user_id` 也不切换查询字段；`--output` 和 `--max-file-mb` 继续生效，`--input` 和 `--days` 对新模式不生效。
- 测试命令：`mvn "-Dtest=ExportConfigTest,MessageExportAppModeTest,MessageExportAppJun3ChatExportTest,OtsMessageRepositoryTest,MessageExportAppExportTest" test`。
- 测试结果：BUILD SUCCESS，Tests run: 30, Failures: 0, Errors: 0, Skipped: 0。
- 完整验证：`mvn test` BUILD SUCCESS，Tests run: 65, Failures: 0, Errors: 0, Skipped: 1；跳过项为既有真实数据集成测试条件不满足时的跳过。
- 自检结论：固定账号、固定时间窗口、默认 `user_id` 字段、CSV 输出、双方消息保留、单账号失败不中断均已有测试覆盖；当前未真实访问 OTS。

### D003 - 纠正记录模板

- 触发原因：用户补充、测试失败、代码审查发现、参数遗漏或调用顺序问题。
- 修正内容：写清楚旧口径和新口径。
- 文档同步：说明 `spec.md`、`tasks.md`、`AGENTS.md`、checklist 是否已同步。
- 验证结果：说明测试或静态验证结果。
