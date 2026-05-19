# 功能规格：906 私聊聊天记录 CSV 导出

**功能目录**: `020-qw-user-message-export-906`  
**创建日期**: 2026-05-18  
**状态**: Draft - Documentation Only  
**输入**: 用户要求先在 `C:\workspace\ju-chat\specs` 编写 Spec Kit 文档，不改代码；后续修改 `C:\workspace\ju-chat\qw-user-message-export`，导出 `yangfan`、`LiYan`、`ZengYan` 三个账号最近 15 天的私聊聊天记录，输出 CSV 文件，并保留 `union_id` 与格式化后的 `timestamp`。导出时老师和用户的消息都要保留，不做 `isSelf` 过滤，不导出群聊消息；`chat_name` 只保留以 `906` 开头的记录；输出时 `message_source` 保持原始值，`isSelf` 仅在输出中转换为“老师发送 / 学员发送”，最终字段顺序固定为 `message_source`、`isSelf`、`chat_name`、`contact_name`、`union_id`、`timestamp`、`text`。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 按指定三个账号导出私聊聊天记录（优先级：P1）

运营或数据整理人员需要只导出 `yangfan`、`LiYan`、`ZengYan` 三个账号对应的聊天记录，用于后续归档和核对。导出工具应只处理这三个账号，且账号以 `qwUserId` 方式传入或映射到现有查询条件。

**独立测试**：准备多个账号的数据，其中包含这三个指定账号和其他账号，运行导出后验证只会处理指定三个账号。

**验收场景**：

1. **Given** 导出任务配置了 `yangfan`、`LiYan`、`ZengYan`，**When** 开始导出，**Then** 系统只查询并处理这三个账号。
2. **Given** 存在其他账号的聊天记录，**When** 运行导出，**Then** 其他账号的记录不会进入结果。
3. **Given** 三个账号中的任意一个没有匹配记录，**When** 运行导出，**Then** 任务应继续处理其余账号，不因为单账号无结果而失败。

### 用户故事 2 - 仅查询最近 15 天的聊天记录（优先级：P1）

导出任务只关心最近 15 天内的聊天记录，历史更早的数据不应进入结果，避免结果过大且与当前需求无关。

**独立测试**：准备 15 天内、15 天前以及更早的混合数据，运行导出并验证只保留最近 15 天的数据。

**验收场景**：

1. **Given** 某条记录的时间在最近 15 天内，**When** 运行导出，**Then** 该记录进入结果。
2. **Given** 某条记录的时间早于最近 15 天开始时间，**When** 运行导出，**Then** 该记录不进入结果。
3. **Given** 同一账号同时存在最近 15 天内和更早的记录，**When** 运行导出，**Then** 仅最近 15 天内的记录保留。

### 用户故事 3 - 保留老师和用户双方消息，不做 `isSelf` 过滤（优先级：P1）

导出结果需要保留同一私聊中的全部聊天文本，不区分老师或用户发出消息，因此不能再用 `isSelf` 作为过滤条件。

**独立测试**：准备同一私聊中同时包含老师消息和用户消息的数据，验证导出结果包含双方消息。

**验收场景**：

1. **Given** 一条消息为老师发送，**When** 运行导出，**Then** 该消息应进入结果。
2. **Given** 一条消息为用户发送，**When** 运行导出，**Then** 该消息应进入结果。
3. **Given** 现有数据中 `isSelf=true` 或 `isSelf=false`，**When** 运行导出，**Then** 系统不得仅凭 `isSelf` 过滤掉任意一方消息。

### 用户故事 4 - 仅导出私聊记录并排除群聊消息（优先级：P1）

导出工具只面向单聊记录，不应包含群聊消息，以免把群内讨论混入个人聊天档案。

**独立测试**：准备同一账号下的私聊和群聊混合数据，运行导出并验证群聊记录不出现。

**验收场景**：

1. **Given** 某条记录属于群聊，**When** 运行导出，**Then** 该记录不进入结果。
2. **Given** 某条记录属于私聊，**When** 运行导出，**Then** 该记录按其文本内容进入结果。
3. **Given** 同一联系人既有私聊也有群聊消息，**When** 运行导出，**Then** 仅私聊消息保留。

### 用户故事 5 - 只保留 `chat_name` 以 `906` 开头的记录（优先级：P1）

导出结果还需要按 `chat_name` 前缀做二次筛选，只保留 `chat_name` 以 `906` 开头的聊天记录。

**独立测试**：准备 `chat_name` 以 `906` 开头和非 `906` 开头的记录，运行导出并验证只有前者保留。

**验收场景**：

1. **Given** 某条记录的 `chat_name` 以 `906` 开头，**When** 运行导出，**Then** 该记录进入结果。
2. **Given** 某条记录的 `chat_name` 不以 `906` 开头，**When** 运行导出，**Then** 该记录不进入结果。
3. **Given** 同一账号下同时存在 `906` 前缀和非 `906` 前缀记录，**When** 运行导出，**Then** 仅 `906` 前缀记录保留。

### 用户故事 6 - 输出固定七列 CSV（优先级：P1）

后续人工处理需要机器可读的结果，因此导出内容必须稳定输出 CSV，列顺序固定为 `message_source`、`isSelf`、`chat_name`、`contact_name`、`union_id`、`timestamp`、`text`。其中 `message_source` 必须保留原始值，`isSelf` 必须转换为“老师发送 / 学员发送”，CSV 首行必须输出表头，且 `union_id` / `timestamp` 需要保留便于回溯。

**独立测试**：准备一批符合条件的记录，运行导出并检查 CSV 表头、每行的列顺序、列数量，以及 `message_source` / `isSelf` 的输出语义和 CSV 转义行为。

**验收场景**：

1. **Given** 一条符合条件的聊天记录，**When** 写入输出，**Then** CSV 必须包含表头 `message_source,isSelf,chat_name,contact_name,union_id,timestamp,text`，且该条记录按固定列顺序写入数据行。
2. **Given** 一条记录包含更多原始字段，**When** 写入输出，**Then** 输出 CSV 中不得额外附加其他列。
3. **Given** 一条记录的 `text` 包含逗号、引号或换行，**When** 运行导出，**Then** 后续实现应将逗号和引号按 CSV 规则转义，并将换行规范化为单行安全字符，保证文件仍可被正常解析。
4. **Given** 一条记录的 `text` 为空，**When** 运行导出，**Then** 后续实现应明确处理策略并在规格中保持一致，默认不输出空文本行。

## 边界情况

- `yangfan`、`LiYan`、`ZengYan` 中某个账号无匹配记录。
- 同一账号同时存在私聊和群聊消息。
- 同一账号同时存在 `906` 前缀与非 `906` 前缀的 `chat_name`。
- 老师和用户双方都发送了消息。
- `chat_name` 或 `contact_name` 为空。
- `text` 为空、仅空白或包含换行符。
- `text` 含有逗号、引号或换行，需要按 CSV 规则转义并规范化为单行安全字符。
- `union_id` 查询不到时如何处理，需要保持与旧逻辑一致，默认写空值并记录错误。
- 最近 15 天内无消息。
- OTS 单次查询存在分页限制，需要翻页取全量结果。
- 实现阶段若 `chat_name` 的前缀规则与字段来源存在歧义，应先统一口径再编码。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下维护本 Spec Kit 目录。
- **FR-002**：当前阶段 MUST 只编写 Spec Kit 文档，不修改业务代码。
- **FR-003**：后续实现 MUST 修改 `C:\workspace\ju-chat\qw-user-message-export`，用于导出指定聊天记录。
- **FR-004**：后续实现 MUST 仅处理 `yangfan`、`LiYan`、`ZengYan` 三个账号。
- **FR-005**：后续实现 MUST 仅查询最近 15 天的聊天记录。
- **FR-006**：后续实现 MUST 包含老师和用户双方消息，不得按 `isSelf` 过滤。
- **FR-007**：后续实现 MUST 排除群聊消息。
- **FR-008**：后续实现 MUST 仅保留 `chat_name` 以 `906` 开头的记录。
- **FR-009**：后续实现 MUST 输出 `message_source`、`isSelf`、`chat_name`、`contact_name`、`union_id`、`timestamp`、`text` 七列 CSV。
- **FR-010**：后续实现 MUST 保持输出列顺序固定，CSV 首行 MUST 输出表头 `message_source,isSelf,chat_name,contact_name,union_id,timestamp,text`，且列之间使用英文逗号分隔；字段中包含逗号或引号时 MUST 按 CSV 规则转义。
- **FR-011**：后续实现 SHOULD 支持分页查询，避免遗漏大批量聊天记录。
- **FR-012**：后续实现 SHOULD 在编码前确认 `yangfan`、`LiYan`、`ZengYan` 对应的 OTS 字段映射。
- **FR-013**：后续实现 SHOULD 明确 `chat_name` 和 `contact_name` 的字段来源，避免不同来源口径不一致。
- **FR-014**：后续实现 SHOULD 对空文本、空白文本和换行文本做单行化处理，避免破坏 CSV 输出格式。

## 成功标准 *(必填)*

### 可衡量结果

- **SC-001**：导出结果 100% 只来自 `yangfan`、`LiYan`、`ZengYan` 三个账号。
- **SC-002**：导出结果 100% 仅来自最近 15 天的聊天记录。
- **SC-003**：导出结果 100% 保留老师和用户双方消息，不再因为 `isSelf` 丢失一方文本。
- **SC-004**：导出结果 100% 排除群聊消息。
- **SC-005**：导出结果 100% 只保留 `chat_name` 以 `906` 开头的记录。
- **SC-006**：每一条数据行都严格包含 `message_source`、`isSelf`、`chat_name`、`contact_name`、`union_id`、`timestamp`、`text` 七列，且 CSV 表头与数据列一致。
- **SC-007**：后续实现完成后可通过至少一轮真实或样例数据导出，人工核对字段顺序、CSV 转义与过滤条件无偏差。

## 假设

- `yangfan`、`LiYan`、`ZengYan` 按 `qwUserId` 处理。
- 最近 15 天按任务运行时刻向前回溯 15 天计算。
- `chat_name` 的“906开头”按前缀过滤理解。
- 输出格式采用 CSV 文件，首行包含表头 `message_source,isSelf,chat_name,contact_name,union_id,timestamp,text`，列之间使用英文逗号分隔。
- `message_source` 按原始字段值输出，`isSelf` 按 `true => 老师发送`、`false => 学员发送` 转换后输出。
- `union_id` 由 `drh_emp_external_user` 表按 `external_userid` 查询获取。
- `timestamp` 按 `yyyy-MM-dd HH:mm:ss` 格式输出，时区为 `Asia/Shanghai`。
- `text` 中的换行会在写入前规范化为单行安全字符，包含逗号或引号时按 CSV 规则转义。
- 当前阶段只写 Spec Kit 文档，不修改业务代码。
