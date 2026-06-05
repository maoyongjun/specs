# 规格执行说明

本目录记录“从 JSONL 日志解析 file_url 并下载视频文件”的 Spec Kit 文档。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\053-video-file-url-download`
- 目标项目：`C:\workspace\ju-chat`
- 源数据文件：`C:\workspace\video_file\d0fd9893-08ef-46db-a4c7-1a81b3a38d5d.json`
- 输出目录：`C:\workspace\video_file\videos`
- 临时脚本位置：`C:\workspace\video_file\download_tool_tmp\download_videos.py`

## 当前目标

- 读取源 JSONL 文件，每行按 JSON 对象解析。
- 从每行 `message` 字段中的 `input` JSON 提取 `file_url`。
- 对 URL 去重后下载视频到 `C:\workspace\video_file\videos`。
- 生成下载清单和错误记录，便于复跑和人工核查。

## 执行原则

- 使用结构化 JSON 解析，禁止用脆弱字符串截取直接拼接下载逻辑。
- 解析 `message` 内嵌 `input` JSON 时，必须处理 prompt 字段中包含换行、引号和花括号的情况。
- 下载文件名必须可追踪来源，优先包含 `messageId` 或 `taskId`，并追加 URL 哈希避免重名覆盖。
- 默认不覆盖已有非空文件；需要覆盖时必须显式传入参数。
- 下载必须采用临时文件落盘，成功后原子改名，避免中断留下半成品被当成成功文件。
- 日志和清单不得输出完整 prompt 内容。
- 单元测试或静态验证不能只看最终文件数量，必须断言解析出的 `file_url`、去重结果、目标文件名和失败原因。

## 强制门禁

实现前必须确认并记录：

- 输入文件是否存在、行数和编码。
- 每行顶层 JSON 是否可解析。
- `message` 字段中 `input` JSON 的提取方式是否能处理嵌套字符串。
- `file_url` 是否为空、是否为 HTTP/HTTPS URL。
- URL 去重口径：按完整 URL 字符串去重。
- 文件命名口径：来源标识加 URL 短哈希，扩展名从 URL path 获取，缺失时默认 `.mp4`。
- 已存在文件、零字节文件、`.part` 文件、HTTP 失败、解析失败的处理方式。
- 下载清单字段和错误记录字段。

## 重点代码位置

- 临时解析和下载脚本：`C:\workspace\video_file\download_tool_tmp\download_videos.py`
- 下载来源清单：`C:\workspace\video_file\download_tool_tmp\download_manifest.csv`
- 唯一 URL 下载清单：`C:\workspace\video_file\download_tool_tmp\download_unique_manifest.csv`
- 下载错误记录：`C:\workspace\video_file\download_tool_tmp\download_errors.jsonl`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务和验证任务。
- `checklists/requirements.md` 用于验证规格质量和实施就绪度。
- 每次补充下载口径、命名口径或失败重试策略，都必须同步更新本目录所有相关文档。
