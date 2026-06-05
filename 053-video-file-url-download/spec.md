# 功能规格：JSONL 日志 file_url 解析与视频下载

**功能目录**：`053-video-file-url-download`  
**创建日期**：`2026-06-05`  
**状态**：Implemented（临时脚本已执行，215 个唯一视频已下载完成）  
**输入**：`C:\workspace\video_file\d0fd9893-08ef-46db-a4c7-1a81b3a38d5d.json` 每行是一个 JSON 对象，`message` 字段内包含 `input: {...}`，内嵌 JSON 中有 `file_url`。需求是解析 `file_url` 地址，并将视频下载到 `C:\workspace\video_file\videos`。

## 背景

- 当前问题：源文件是 JSONL 日志，不是直接的 URL 列表；`file_url` 位于 `message` 日志文本内的内嵌 `input` JSON 中。
- 当前行为：尚未提供稳定脚本批量提取 URL、去重、下载和记录失败原因。
- 目标行为：提供可复跑的离线工具，从源文件解析所有有效 `file_url`，去重后下载到目标目录，并产出清单与错误记录。
- 非目标：不分析视频内容，不调用钢琴作业识别模型，不修改原始 JSONL 文件，不上传视频，不改业务服务代码。

## 已确认的数据事实

- 源文件存在：`C:\workspace\video_file\d0fd9893-08ef-46db-a4c7-1a81b3a38d5d.json`
- 源文件大小：`2,240,928` 字节。
- 输出目录已存在：`C:\workspace\video_file\videos`
- 静态抽样与解析确认结果：
  - 总行数：`260`
  - 顶层 JSON 可解析行数：`260`
  - `message` 内嵌 `input` JSON 可解析行数：`260`
  - 含 `file_url` 行数：`260`
  - 去重后 `file_url` 数：`215`

## 用户场景与测试

### 用户故事 1 - 批量解析并下载视频（优先级：P1）

用户提供 JSONL 日志文件后，工具可以自动解析每行 `message` 中的 `input.file_url`，下载所有唯一视频到目标目录。

**独立测试**：使用当前源文件执行 dry-run，断言解析出 `260` 条行级 URL、`215` 条唯一 URL，并生成清单预览。

**验收场景**：

1. **Given** 源文件每行都是有效 JSON 且 `message` 中包含 `input.file_url`，**When** 执行下载工具，**Then** 工具按完整 URL 去重后下载到 `C:\workspace\video_file\videos`。
2. **Given** 多行记录包含相同 `file_url`，**When** 工具解析 URL，**Then** 只下载一次，清单中保留每条来源行到本地文件的映射。
3. **Given** 目标文件已存在且非空，**When** 未指定覆盖参数，**Then** 跳过下载并在清单中记录 `skipped_existing`。

### 用户故事 2 - 可诊断失败与边界数据（优先级：P1）

当某行 JSON 格式异常、缺少 `message`、缺少 `file_url` 或 HTTP 下载失败时，工具不中断全量任务，而是记录明确失败原因。

**独立测试**：构造包含坏 JSON、无 `message`、无 `input`、无 `file_url`、非法 URL、HTTP 404 的测试夹具，断言每条失败都有行号和原因。

**验收场景**：

1. **Given** 某行顶层 JSON 解析失败，**When** 执行工具，**Then** 该行记为 `parse_top_json_failed`，后续行继续处理。
2. **Given** `message` 中没有可解析的 `input` JSON，**When** 执行工具，**Then** 该行记为 `parse_input_json_failed` 或 `missing_input_json`。
3. **Given** 下载响应不是 2xx 或写文件失败，**When** 执行下载，**Then** 清单记录失败 URL、HTTP 状态或异常信息，不影响其他 URL 下载。

### 用户故事 3 - 支持复跑和人工核查（优先级：P2）

工具生成稳定文件名和下载清单，复跑时可以跳过已成功文件，人工可以根据 `lineNo`、`messageId`、`taskId` 追溯来源。

**独立测试**：重复执行工具两次，第一次下载成功后第二次应跳过已有非空文件，并保持清单可读。

**验收场景**：

1. **Given** URL path 扩展名为 `.mp4`，**When** 生成本地文件名，**Then** 文件名保留 `.mp4` 扩展名。
2. **Given** 两个 URL 的 `messageId` 相同但 URL 不同，**When** 生成本地文件名，**Then** 追加 URL 短哈希避免覆盖。
3. **Given** 下载过程中断留下 `.part` 文件，**When** 复跑工具，**Then** 忽略半成品并重新下载该 URL。

## 解析与下载契约

- 默认输入参数：`--input C:\workspace\video_file\d0fd9893-08ef-46db-a4c7-1a81b3a38d5d.json`
- 默认输出参数：`--output C:\workspace\video_file\videos`
- 建议参数：
  - `--dry-run`：只解析和生成预览，不下载。
  - `--overwrite`：覆盖已存在的非空目标文件。
  - `--timeout-seconds`：单次 HTTP 请求超时，默认 `60`。
  - `--max-retries`：单个 URL 最大重试次数，默认 `3`。
- 解析步骤：
  1. 逐行读取源文件。
  2. 用 JSON parser 解析顶层对象。
  3. 从 `message` 字段定位 `input:` 后的第一个 `{`。
  4. 用支持 JSON 字符串转义的括号深度扫描提取完整内嵌 JSON，避免 prompt 中的花括号干扰。
  5. 解析内嵌 JSON 并读取 `file_url`、`messageId`、`taskId`。
  6. 验证 `file_url` 只接受 `http` 或 `https`。
- 去重口径：按完整 `file_url` 字符串去重，不去掉 query，不做大小写归一。
- 文件命名：
  - 优先使用 `messageId`，无值时使用 `taskId`，再无值时使用 `lineNo`。
  - 文件名格式建议：`{sourceId}_{urlHash12}{ext}`。
  - `urlHash12` 为 URL 的 SHA-256 前 12 位。
  - `ext` 从 URL path 提取，缺失时默认 `.mp4`。
  - 所有文件名必须移除 Windows 非法字符。
- 下载落盘：
  - 写入 `{target}.part` 临时文件。
  - HTTP 状态为成功且文件非空后，原子重命名为目标文件。
  - 默认跳过已存在且非空的目标文件。

## 结果文件

- `download_manifest.csv` 字段：
  - `lineNo`
  - `messageId`
  - `taskId`
  - `file_url`
  - `urlHash12`
  - `localPath`
  - `status`
  - `httpStatus`
  - `bytes`
  - `error`
- `download_errors.jsonl` 字段：
  - `lineNo`
  - `stage`
  - `messageId`
  - `taskId`
  - `file_url`
  - `errorCode`
  - `errorMessage`

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `inputPath`：来源 CLI 参数或默认值；赋值时机为程序启动参数解析完成后；下游读取位置为 JSONL reader。
  - `outputDir`：来源 CLI 参数或默认值；赋值时机为程序启动参数解析完成后；下游读取位置为 filename resolver 和 downloader。
  - `message`：来源每行顶层 JSON 字段；赋值时机为单行解析完成后；下游读取位置为 embedded input parser。
  - `file_url`：来源 `message` 内嵌 `input` JSON；赋值时机为内嵌 JSON 解析完成后；下游读取位置为 URL validator、deduper、downloader。
  - `messageId` / `taskId`：来源内嵌 `input` JSON；赋值时机为内嵌 JSON 解析完成后；下游读取位置为 filename resolver 和 manifest writer。
- 下游读取字段清单：
  - URL validator 读取 `file_url`。
  - Deduper 读取完整 `file_url`。
  - Filename resolver 读取 `messageId`、`taskId`、`lineNo`、`file_url`。
  - Downloader 读取 `file_url`、`localPath`、`overwrite`、`timeoutSeconds`、`maxRetries`。
  - Manifest writer 读取 `lineNo`、`messageId`、`taskId`、`file_url`、`localPath`、`status`、`error`。
- 空对象 / 占位对象风险：
  - 顶层 JSON 为空、`message` 为空、内嵌 `input` JSON 为空或 `file_url` 为空时，不允许构造空下载任务；必须记录跳过或失败原因。
- 调用顺序风险：
  - 必须先解析并验证 `file_url`，再加入下载队列。
  - 必须先解析 `messageId` / `taskId` 并生成安全文件名，再写入临时文件。
  - 必须先成功写完临时文件并校验非空，再改名为最终文件。
- 旧逻辑保持：
  - 不修改源 JSONL 文件。
  - 不修改 `C:\workspace\video_file\videos` 中已有非空文件，除非显式指定 `--overwrite`。
  - 不访问数据库、Redis、MQ、FC 或业务接口。
  - 不输出完整 prompt 内容到日志或清单。
- 需要用户确认的设计选择：
  - 若需要真实下载前先生成 URL 列表文件、或要求文件名必须按行号而非 `messageId` 命名，需要追加确认。

## 边界情况

- 源文件不存在：程序失败退出，提示 `input_file_not_found`。
- 输出目录不存在：自动创建；创建失败则退出。
- 顶层 JSON 解析失败：记录该行错误，继续处理下一行。
- `message` 字段缺失或不是字符串：记录 `missing_message`。
- 找不到 `input:` 或找不到后续 JSON 对象：记录 `missing_input_json`。
- 内嵌 JSON 解析失败：记录 `parse_input_json_failed`。
- `file_url` 缺失或为空：记录 `missing_file_url`。
- URL 非 HTTP/HTTPS：记录 `invalid_file_url`，不下载。
- 重复 URL：只下载一次，所有来源行映射到同一个本地文件。
- 目标文件已存在且非空：默认跳过；指定 `--overwrite` 时重新下载。
- 目标文件为零字节：视为未成功文件，允许重新下载。
- HTTP 失败、超时或网络异常：按配置重试，最终失败写入清单和错误文件。
- Content-Type 不是视频：不作为硬失败，但在清单中记录警告字段或 error 说明。

## 需求

### 功能需求

- **FR-001**：系统 MUST 支持从默认输入文件逐行读取 JSONL 日志。
- **FR-002**：系统 MUST 用 JSON parser 解析顶层行对象，不得依赖固定列宽或简单 split。
- **FR-003**：系统 MUST 从 `message` 内嵌 `input` JSON 中提取 `file_url`、`messageId`、`taskId`。
- **FR-004**：系统 MUST 正确处理内嵌 prompt 字段中出现的换行、引号和花括号。
- **FR-005**：系统 MUST 按完整 `file_url` 去重后下载，重复 URL 不重复请求。
- **FR-006**：系统 MUST 将视频下载到 `C:\workspace\video_file\videos`，并使用可追踪且不冲突的文件名。
- **FR-007**：系统 MUST 生成下载清单，记录每行来源、URL、本地路径、状态、字节数和错误信息。
- **FR-008**：系统 MUST 对解析失败、非法 URL、HTTP 失败、文件写入失败继续处理后续记录。
- **FR-009**：系统 MUST NOT 修改源 JSONL 文件。
- **FR-010**：系统 MUST NOT 默认覆盖已有非空视频文件。
- **FR-011**：测试 MUST 覆盖正常解析、prompt 中含花括号、重复 URL、缺失字段、HTTP 失败和复跑跳过。

## 成功标准

- **SC-001**：对当前源文件执行 dry-run，解析结果为 `260` 条行级 URL、`215` 条唯一 URL，且无解析错误。
- **SC-002**：真实下载执行后，每个唯一 URL 在清单中状态为 `downloaded`、`skipped_existing` 或带有明确原因的 `failed`。
- **SC-003**：任意下载失败不导致全局任务中断，最终清单和错误文件均可用于复查。
- **SC-004**：重复执行工具时，已存在非空文件默认跳过，不重复下载。
- **SC-005**：测试或静态验证记录覆盖解析参数、文件名、去重和下载失败，不只断言最终文件数量。

## 假设

- 源文件为 UTF-8 或兼容 UTF-8 的 JSONL 文本。
- `message` 内的 `input` JSON 是日志行中 `input:` 后的完整 JSON 对象。
- `file_url` 指向可直接 HTTP/HTTPS GET 的视频资源。
- 当前需求允许使用离线脚本完成，不要求接入现有 Java 服务。
- 当前需求按完整 URL 去重；若同一视频有不同 query URL，会视为不同资源。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已确认源文件存在、目标目录存在，并完成静态解析抽样。
- 当前源文件解析确认：总行数 `260`，行级 `file_url` `260` 条，唯一 `file_url` `215` 条。
- 本阶段未实现脚本，未修改业务代码，未实际下载视频。

### D002 - 临时脚本与下载执行记录

- 实现内容：在 `C:\workspace\video_file\download_tool_tmp\download_videos.py` 新增临时 Python 脚本；脚本逐行解析 JSONL，从 `message` 内嵌 `input` JSON 提取 `file_url`、`messageId`、`taskId`，按完整 URL 去重后下载到 `C:\workspace\video_file\videos`。
- 清单输出：生成 `C:\workspace\video_file\download_tool_tmp\download_manifest.csv`、`C:\workspace\video_file\download_tool_tmp\download_unique_manifest.csv`、`C:\workspace\video_file\download_tool_tmp\download_errors.jsonl`。
- 验证命令：`python -m py_compile C:\workspace\video_file\download_tool_tmp\download_videos.py`；`python C:\workspace\video_file\download_tool_tmp\download_videos.py --dry-run`；`python C:\workspace\video_file\download_tool_tmp\download_videos.py --timeout-seconds 90 --max-retries 3`。
- 测试结果：语法检查通过；dry-run 解析 `sourceRecords=260`、`uniqueUrls=215`、`parseErrors=0`；真实下载 `downloaded=215`、`errors=0`。
- 文件验证：`C:\workspace\video_file\videos` 下共有 `215` 个文件，总大小约 `984.40 MB`，零字节文件 `0`，残留 `.part` 文件 `0`。
- 自检结论：下载完成；本次为临时脚本执行，未修改业务代码；未新增单元测试，验证依据为语法检查、dry-run、完整下载和落盘结果检查。

### D003 - 纠正记录模板

- 触发原因：发生用户补充、测试失败、下载失败、命名口径变化或解析口径变化时追加。
- 修正内容：追加时写清楚旧口径和新口径。
- 文档同步：追加时说明 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 是否已同步。
- 验证结果：追加时说明测试或静态验证结果。
