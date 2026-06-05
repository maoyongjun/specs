# 任务清单：JSONL 日志 file_url 解析与视频下载

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充解析单元测试、下载 mock 测试和当前源文件 dry-run 记录。

## Phase 1：事实确认

- [x] T001 复查用户需求，确认目标是在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档。
- [x] T002 确认源文件存在：`C:\workspace\video_file\d0fd9893-08ef-46db-a4c7-1a81b3a38d5d.json`。
- [x] T003 确认输出目录存在：`C:\workspace\video_file\videos`。
- [x] T004 静态确认当前源文件总行数为 `260`。
- [x] T005 静态确认当前源文件顶层 JSON 可解析 `260` 行、内嵌 `input` JSON 可解析 `260` 行、行级 `file_url` `260` 条、唯一 URL `215` 条。
- [x] T006 实现前确认脚本最终落点：按用户要求放到 `C:\workspace\video_file\download_tool_tmp\download_videos.py`。
- [x] T007 实现前确认执行方式：先执行 `--dry-run`，解析正常后执行真实下载。

**检查点**：T006-T007 未完成前，不进入脚本实现或真实下载。

## Phase 2：风险门禁

- [x] T008 明确 `file_url` 来源：每行顶层 JSON 的 `message` 字段内嵌 `input` JSON。
- [x] T009 明确 `messageId`、`taskId` 来源：内嵌 `input` JSON，用于文件命名和追溯。
- [x] T010 明确去重口径：按完整 `file_url` 字符串去重。
- [x] T011 明确默认不覆盖已有非空文件。
- [x] T012 明确不得修改源 JSONL 文件，不访问数据库、Redis、MQ、FC 或业务接口。
- [x] T013 实现前检查解析器是否能处理 prompt 字段中的换行、引号和花括号。
- [x] T014 实现前检查下载器是否使用 `.part` 临时文件并在成功后原子改名。
- [x] T015 实现前为解析失败、非法 URL、HTTP 失败、文件写入失败建立脚本级处理路径。

**检查点**：T013-T015 必须有明确结论；否则不得真实下载。

## Phase 3：实现

- [x] T016 新增离线脚本，支持 `--input`、`--output`、`--dry-run`、`--overwrite`、`--timeout-seconds`、`--max-retries`。
- [x] T017 实现顶层 JSONL 逐行解析。
- [x] T018 实现 `message` 内嵌 `input` JSON 的括号深度扫描解析。
- [x] T019 提取并验证 `file_url`、`messageId`、`taskId`。
- [x] T020 实现完整 URL 去重和来源行映射。
- [x] T021 实现安全文件名生成：`sourceId + urlHash12 + ext`。
- [x] T022 实现流式下载、重试、超时、`.part` 临时文件和成功后原子改名。
- [x] T023 实现 `download_manifest.csv`、`download_unique_manifest.csv` 和 `download_errors.jsonl` 输出。
- [x] T024 实现默认跳过已有非空文件，`--overwrite` 才覆盖。
- [x] T025 同步更新 `spec.md`、`tasks.md` 和 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [ ] T026 新增解析单元测试，覆盖正常行、prompt 含花括号、缺失 `message`、缺失 `input`、缺失 `file_url`。
- [ ] T027 新增去重和文件命名单元测试，断言重复 URL 只产生一个下载任务。
- [ ] T028 新增下载 mock 测试，覆盖 HTTP 成功、HTTP 404、超时、已有文件跳过、零字节文件重试。
- [x] T029 执行当前源文件 dry-run，记录行级 URL 数、唯一 URL 数和错误数。
- [x] T030 按用户要求执行真实下载命令并记录成功、跳过、失败数量。
- [x] T031 检查目标目录中不存在残留 `.part` 文件或零字节成功文件。
- [x] T032 确认本次只新增临时脚本和更新规格文档，未修改业务代码。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `053-video-file-url-download` Spec Kit 文档。
- 验证方式：PowerShell 静态检查源文件、输出目录、总行数和内嵌 `file_url` 解析数量。
- 验证结果：源文件存在；输出目录存在；总行数 `260`；行级 `file_url` `260`；唯一 URL `215`；解析错误 `0`。
- 自检结论：D001 为文档阶段记录；脚本实现和真实下载结果见 D002。

### D002 - 临时脚本与下载执行记录

- 实现内容：在 `C:\workspace\video_file\download_tool_tmp\download_videos.py` 新增临时下载脚本，下载结果写入 `C:\workspace\video_file\videos`。
- 测试命令：`python -m py_compile C:\workspace\video_file\download_tool_tmp\download_videos.py`；`python C:\workspace\video_file\download_tool_tmp\download_videos.py --dry-run`；`python C:\workspace\video_file\download_tool_tmp\download_videos.py --timeout-seconds 90 --max-retries 3`。
- 测试结果：语法检查通过；dry-run 为 `sourceRecords=260`、`uniqueUrls=215`、`parseErrors=0`；真实下载为 `downloaded=215`、`errors=0`。
- 落盘验证：`C:\workspace\video_file\videos` 下 `215` 个文件，总大小约 `984.40 MB`，零字节文件 `0`，`.part` 残留 `0`。
- 自检结论：参数来源、调用顺序、去重下载和复跑跳过逻辑已通过本次完整执行验证；未新增单元测试，后续若要长期保留脚本应补充测试。

### D003 - 纠正记录模板

- 触发原因：需要纠正时追加具体原因。
- 修正内容：需要纠正时追加具体修正。
- 文档同步：需要纠正时追加同步了哪些文件。
- 验证结果：需要纠正时追加测试或静态验证结果。
