# 功能规格：企微用户近三个月消息导出

**功能目录**: `016-qw-user-message-export`  
**创建日期**: 2026-05-14  
**状态**: Draft - Documentation Only  
**输入**: 用户要求先在 `C:\workspace\ju-chat\specs` 编写 Spec Kit 文档，不编码；后续创建一个项目，读取项目的 `userIds.txt` 文件，每行是一个 `qwUserId`，根据 `qwUserId` 依次查询 OTS 表中最近三个月用户发送的消息，生成到 `txt`；每条消息一行；单个文件超过 10MB 时写入新文件；查询 OTS 表可参考 `C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\util\OtsUtil.java` 的 `getLatestMessage` 方法；使用 `timestamp` 筛选时间范围；目标消息为用户发送的文字或语音/文件类消息，`type in (2, 7)`，需要解析 `payload` JSON 中的 `text` 内容，例如 `"text":"老师好.."`。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 从 userIds.txt 批量读取 qwUserId（优先级：P1）

运营或数据整理人员将待分析用户的企微用户 id 放入项目目录下的 `userIds.txt`，每行一个 `qwUserId`。导出工具运行后应按文件顺序读取所有有效 id，并逐个执行消息查询。

**独立测试**：准备一个包含空行、前后空格和重复 `qwUserId` 的 `userIds.txt`，运行导出流程，验证系统忽略空行、裁剪前后空格，并按明确的重复处理策略执行。

**验收场景**：

1. **Given** `userIds.txt` 存在且每行一个有效 `qwUserId`，**When** 启动导出，**Then** 系统按文件顺序处理每个 `qwUserId`。
2. **Given** `userIds.txt` 中存在空行或只有空白字符的行，**When** 启动导出，**Then** 系统跳过这些行。
3. **Given** `userIds.txt` 不存在或没有有效 `qwUserId`，**When** 启动导出，**Then** 系统应给出明确失败原因且不创建空结果文件。
4. **Given** `userIds.txt` 中存在重复 `qwUserId`，**When** 启动导出，**Then** 后续实现必须按规格中确定的策略处理，默认建议去重后导出，避免同一用户消息重复进入结果集。

### 用户故事 2 - 查询最近三个月用户发送的目标消息（优先级：P1）

数据整理人员只需要这些用户最近三个月主动发送的消息。导出工具应使用 `timestamp` 设置时间范围，查询 OTS 中 `isSelf=false` 且 `type in (2, 7)` 的消息。

**独立测试**：准备同一个 `qwUserId` 在三个月内、三个月前、员工发送、用户发送、不同 `type` 的 OTS 测试数据，运行查询，验证只返回最近三个月内用户发送且类型符合要求的消息。

**验收场景**：

1. **Given** 某 `qwUserId` 最近三个月内存在用户发送的 `type=2` 消息，**When** 查询该用户，**Then** 该消息进入导出结果。
2. **Given** 某 `qwUserId` 最近三个月内存在用户发送的 `type=7` 消息，**When** 查询该用户，**Then** 该消息进入导出结果。
3. **Given** 某消息 `timestamp` 早于最近三个月开始时间，**When** 查询该用户，**Then** 该消息不进入导出结果。
4. **Given** 某消息为员工发送，即 `isSelf=true`，**When** 查询该用户，**Then** 该消息不进入导出结果。
5. **Given** 某消息类型不在 `2` 和 `7` 范围内，**When** 查询该用户，**Then** 该消息不进入导出结果。

### 用户故事 3 - 从 payload 中解析 text 并按一行一条写入 txt（优先级：P1）

后续归类整理只关心消息文本内容。导出工具应从 OTS 行的 `payload` JSON 中解析 `text` 字段，写入 `txt` 文件，并保证每条消息占一行。

**独立测试**：准备 `payload` 为 `{"text":"老师好.."}`、`{"text":""}`、缺少 `text` 字段、非法 JSON 和包含换行符文本的测试数据，验证只有有效文本被输出，且输出保持一条消息一行。

**验收场景**：

1. **Given** OTS 行 `payload` 包含 `"text":"老师好.."`，**When** 导出消息，**Then** 输出文件包含一行 `老师好..`。
2. **Given** OTS 行 `payload.text` 为空或仅空白，**When** 导出消息，**Then** 该消息不写入结果文件。
3. **Given** OTS 行 `payload` 不是合法 JSON，**When** 导出消息，**Then** 系统记录该行解析失败并继续处理后续消息。
4. **Given** `payload.text` 内部包含换行符，**When** 写入 `txt`，**Then** 后续实现应将其规范化为单行文本，避免一条消息拆成多行。

### 用户故事 4 - 输出文件超过 10MB 时自动切分（优先级：P1）

导出结果可能很大。导出工具应限制单个 `txt` 文件大小，单个文件达到或即将超过 10MB 时，切换到新的输出文件继续写入。

**独立测试**：准备足够多的消息，使输出超过 10MB，运行导出流程，验证系统生成多个 `txt` 文件，且每条消息完整出现在某一个文件中，不被截断。

**验收场景**：

1. **Given** 当前输出文件写入下一条消息后不会超过 10MB，**When** 写入消息，**Then** 消息写入当前文件。
2. **Given** 当前输出文件写入下一条消息后会超过 10MB，**When** 写入消息，**Then** 系统先切换到新文件，再完整写入该消息。
3. **Given** 单条消息自身超过 10MB，**When** 写入消息，**Then** 后续实现必须记录异常并采用明确策略处理，默认建议单独输出到异常文件或跳过并记录，不能截断消息。
4. **Given** 生成多个文件，**When** 查看输出目录，**Then** 文件命名应稳定且可排序，例如 `messages_001.txt`、`messages_002.txt`。

### 用户故事 5 - 导出过程可追踪且不中断整体任务（优先级：P2）

导出任务可能涉及大量用户。单个用户查询失败、单行数据解析失败或单条消息异常不应直接中断整个任务；系统应记录失败原因，并继续处理其他用户。

**独立测试**：准备一个有效 `qwUserId`、一个查询失败的 `qwUserId` 和一条解析失败的消息，运行导出流程，验证最终仍产出有效消息文件，并生成处理统计或日志。

**验收场景**：

1. **Given** 某个 `qwUserId` 查询 OTS 失败，**When** 批量导出，**Then** 系统记录该用户失败原因并继续处理下一个 `qwUserId`。
2. **Given** 某条消息解析失败，**When** 导出该用户消息，**Then** 系统记录该消息失败原因并继续处理后续消息。
3. **Given** 导出完成，**When** 查看执行结果，**Then** 系统应提供处理用户数、成功用户数、失败用户数、导出消息数、输出文件数等统计信息。

## OTS 查询参考

后续实现查询 OTS 表时应参考 `OtsUtil#getLatestMessage` 的写法：

- 使用 `SyncClient` 访问 OTS。
- 使用 `SearchRequest`、`SearchQuery` 和 `QueryBuilders.bool()` 组合查询条件。
- 表名保持 `juzi_private_message`。
- 索引名保持 `juzi_private_message_index`。
- 排序字段使用 `timestamp`，可按业务导出需要选择升序或降序；最终输出建议按 `timestamp ASC` 便于后续阅读和归类。
- 至少获取 `payload`、`isSelf`、`timestamp`、`type`，需要排查 `qwUserId` 对应 OTS 字段后再确定查询字段。

参考方法 `getLatestMessage` 当前使用的查询条件包括：

- `external_user_id`
- `isSelf=false`
- `user_id`
- `type in (2, 7)`
- `timestamp DESC`
- 表 `juzi_private_message`
- 索引 `juzi_private_message_index`

本需求输入为 `qwUserId`，后续编码前必须确认 `qwUserId` 在 OTS 中对应的字段名称。若 `qwUserId` 等同于 `external_user_id`，查询条件使用 `external_user_id = qwUserId`；若对应其他字段，必须在实现前更新本规格或任务记录。

## 时间范围规则

- 最近三个月以任务运行时刻为结束时间。
- 开始时间为运行时刻向前推三个月。
- 查询必须使用 OTS 的 `timestamp` 字段过滤，单位按现有代码口径为毫秒。
- 时间边界建议使用闭区间：`timestamp >= startTimestamp` 且 `timestamp <= endTimestamp`。
- 需要明确运行环境时区，默认按现有服务常用的 `Asia/Shanghai` 计算自然时间。

## 输出格式

默认输出为纯文本文件：

```text
老师好..
这个课什么时候开始
我已经发过去了
```

规则：

- 每条有效消息占一行。
- 默认只输出 `payload.text` 内容，不输出 `qwUserId`、`timestamp`、`message_id` 或原始 JSON。
- 如后续归类整理需要追溯来源，可在实现前新增可选输出格式，但默认结果仍应满足“一条消息一行”的纯文本要求。
- 写入前应将消息内部的 `\r`、`\n` 等换行规范化为空格或其他单行安全字符。
- 输出编码建议使用 UTF-8。

## 边界情况

- 本规格当前阶段只要求文档，不创建项目、不修改 Java 代码、不连接 OTS。
- `userIds.txt` 位于后续导出项目目录下，而不是 `specs` 目录。
- `userIds.txt` 中空行必须跳过。
- 重复 `qwUserId` 默认建议去重，避免重复导出；如业务要求保留重复，需在编码前明确。
- `qwUserId` 与 OTS 字段的映射当前需实现前确认。
- OTS 单次 search 可能存在 limit 或分页限制，后续实现必须支持翻页查询完整时间范围内的数据。
- 最近三个月内无消息的用户不应导致任务失败。
- `payload` 缺失、非法 JSON、缺少 `text`、`text` 为空时，该消息不写入主结果。
- 撤回消息如果 OTS 行存在 `recall=1`，建议沿用 `OtsUtil` 现有口径跳过。
- 单个输出文件大小以写入后的字节数计算，按 UTF-8 编码统计，不按字符数统计。
- 文件切分不能把一条消息拆成两部分。
- 输出目录不存在时应自动创建。
- 输出文件命名应稳定、可排序、避免覆盖已有结果；是否覆盖历史文件需在实现前明确，默认建议每次运行生成独立批次目录。

## 需求 *(必填)*

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下维护本 Spec Kit 目录。
- **FR-002**：当前阶段 MUST 只编写 Spec Kit 文档，不修改业务代码，不创建实际导出项目。
- **FR-003**：后续实现 MUST 创建一个可运行的消息导出项目或模块。
- **FR-004**：后续项目 MUST 从自身目录读取 `userIds.txt`。
- **FR-005**：`userIds.txt` MUST 支持每行一个 `qwUserId`。
- **FR-006**：后续实现 MUST 跳过 `userIds.txt` 中的空行和空白行。
- **FR-007**：后续实现 SHOULD 默认对重复 `qwUserId` 去重，除非编码前业务明确要求保留重复。
- **FR-008**：后续实现 MUST 根据每个 `qwUserId` 依次查询 OTS 消息。
- **FR-009**：后续实现 MUST 使用 `timestamp` 筛选最近三个月时间范围。
- **FR-010**：后续实现 MUST 查询用户发送的消息，即 `isSelf=false`。
- **FR-011**：后续实现 MUST 查询 `type in (2, 7)` 的消息。
- **FR-012**：后续实现 MUST 从 OTS 行 `payload` JSON 中解析 `text` 字段。
- **FR-013**：后续实现 MUST 只将非空 `payload.text` 写入主输出文件。
- **FR-014**：后续实现 MUST 保证输出 `txt` 中每条消息占一行。
- **FR-015**：后续实现 MUST 将消息内部换行规范化，避免一条消息产生多行输出。
- **FR-016**：后续实现 MUST 在单个输出文件达到或即将超过 10MB 时切换到新文件。
- **FR-017**：后续实现 MUST 保证单条消息完整写入一个输出文件，不能被文件切分截断。
- **FR-018**：后续实现 MUST 支持 OTS 查询分页，避免只导出单页结果。
- **FR-019**：后续实现 SHOULD 按 `timestamp ASC` 输出消息，便于后续归类整理。
- **FR-020**：后续实现 MUST 参考 `OtsUtil#getLatestMessage` 的 OTS SearchRequest、索引、表名和 payload 解析方式。
- **FR-021**：后续实现 MUST 在编码前确认 `qwUserId` 对应的 OTS 查询字段。
- **FR-022**：后续实现 SHOULD 跳过 `recall=1` 的撤回消息。
- **FR-023**：后续实现 MUST 对单个用户查询失败、单条消息解析失败进行记录，并继续处理剩余用户和消息。
- **FR-024**：后续实现 SHOULD 输出任务统计，包括处理用户数、成功用户数、失败用户数、导出消息数和输出文件数。
- **FR-025**：后续实现 SHOULD 使用 UTF-8 输出文本文件。
- **FR-026**：后续实现 SHOULD 为每次运行生成独立输出批次目录，避免覆盖历史结果。

## 成功标准 *(必填)*

- **SC-001**：本目录包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：当前提交只包含 Spec Kit 文档变化，不包含业务代码或导出项目代码。
- **SC-003**：规格明确输入文件为项目目录下的 `userIds.txt`，且每行一个 `qwUserId`。
- **SC-004**：规格明确查询范围为最近三个月，并使用 `timestamp` 过滤。
- **SC-005**：规格明确只导出用户发送的消息，即 `isSelf=false`。
- **SC-006**：规格明确目标消息类型为 `type in (2, 7)`。
- **SC-007**：规格明确从 `payload` JSON 的 `text` 字段提取导出内容。
- **SC-008**：规格明确输出 `txt` 每条消息一行。
- **SC-009**：规格明确单个输出文件超过 10MB 时切换新文件。
- **SC-010**：规格明确参考 `OtsUtil#getLatestMessage` 的 OTS 查询方式。
- **SC-011**：规格明确后续编码前必须确认 `qwUserId` 与 OTS 字段的映射。
- **SC-012**：后续实现完成后，准备测试 `userIds.txt`，验证导出文件内容、文件切分和错误处理。
- **SC-013**：后续实现完成后，使用包含超过 10MB 消息量的数据验证文件切分不截断消息。
- **SC-014**：后续实现完成后，使用 OTS 测试数据验证三个月边界、`isSelf`、`type` 和 `payload.text` 过滤规则。

## 假设

- OTS 表 `juzi_private_message` 和索引 `juzi_private_message_index` 可用于查询目标消息。
- `timestamp` 单位为毫秒，与现有 `OtsUtil` 中的口径一致。
- `payload` 字段是 JSON 字符串，目标文本位于顶层 `text` 字段。
- `type in (2, 7)` 的目标数据中，均可通过 `payload.text` 获取后续归类整理所需文本。
- `isSelf=false` 表示用户发送，`isSelf=true` 表示员工或系统侧发送。
- 后续导出项目可以使用现有 OTS 环境变量配置，例如 `endpoint`、`accessKey`、`accessSecret`、`instance`。
- 最近三个月按任务运行时间向前推三个月计算。
- 后续归类整理暂不在本规格内实现，本规格只负责导出原始文本行。
