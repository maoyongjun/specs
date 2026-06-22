# 任务清单：从视频中提取单音旋律的音符序列

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认（已在计划阶段完成）

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标项目为 `C:\workspace\ju-chat\videoToAudio`（全新独立 Python 项目），任务链路为「视频 → FFmpeg 提取音频 → librosa 单音音符提取 → 返回/打印/写 JSON」。
- [x] T002 确认真实入口与落点：目录为空，需新建 `note_extractor.py`（核心）、`cli.py`（入口）、`requirements.txt`、`tests/test_note_extractor.py`。无既有调用链可复用。
- [x] T003 确认关键参数来源与类型：`video_path`(str, 入参)、`audio_path`(str, 当前层生成)、`sample_rate`(int, 默认22050)、`fmin/fmax`(float, 默认C2/C7)、`min_note_duration`(float, 默认~0.05s)。详见 spec「历史问题防漏分析」。
- [x] T004 确认环境/外部依赖：依赖外部命令 `ffmpeg`（PATH）与 Python 包 `librosa/soundfile/numpy`。不涉及 Redis/MQ/数据库/Feign/FC/OTS/OSS。目标 Python 3.10，本地用 3.12 venv 验证。
- [x] T005 确认必须保持不变的「参照源码旧逻辑」：`-y`/`-vn`、latin-1 容错解码 stderr、执行耗时日志装饰器、唯一文件名生成、临时文件清理、中文日志。

**检查点**：T001-T005 已完成，可进入实现（待用户确认）。

## Phase 2：风险门禁（已在计划阶段分析）

- [x] T006 占位对象检查：Python 项目无 DTO 占位；等价风险=空音频路径/空音符列表伪装成功，处理策略见 spec FR-005。结论：已识别并定策略。
- [x] T007 调用后赋值检查：存在「先生成 audio_path 字符串、FFmpeg 后文件才存在」时序，处理策略=严格顺序 + FFmpeg `check=True` + 文件存在性与非空校验后再交 librosa。结论：已识别并定策略。
- [x] T008 下游读取来源检查：librosa 读取的 `audio_path/sample_rate/fmin/fmax/hop_length` 均在调用前赋值或为模块常量。结论：全部有来源。
- [x] T009 影响范围检查：本项目独立新建，不改任何既有接口契约/调用顺序/外部请求；明确不引入 OSS/回调。结论：影响范围仅限新目录。
- [x] T010 业务语义变化记录：相对参照源码，去掉了 OSS 上传与回调（用户已确认），新增 librosa 音符提取（这是需求本身）。无未确认的语义变化。
- [x] T011 测试映射：FFmpeg 命令参数断言、pyin 参数断言、合成音频音符正确性、静音段无音符、空结果不报错——均映射到 `tests/test_note_extractor.py`。

**检查点**：T006-T011 结论明确，无未确认高风险。

## Phase 3：实现（已完成）

- [x] T012 新建 `requirements.txt`：librosa、soundfile、numpy（pin 兼容 Python 3.10 的版本，用于函数计算部署）。
- [x] T013 实现 `audio_ffmpeg.py`（**不 import librosa**）：
  - `print_excute_time` 装饰器、`get_file_name_ext`、`generate_unique_filename`（沿用参照源码风格，UTC+8 时间戳 + 短 UUID）。
  - `build_ffmpeg_cmd(video_path, audio_codec, audio_bitrate, dst_audio_path)`：纯函数构造命令字符串（保留 `-y`/`-vn`），便于单元测试断言。
  - `extract_audio(video_path, ...)`：在 `/tmp` 生成唯一音频路径 → 执行 FFmpeg（`shell=True`、`executable="/bin/bash"`、`check=True`、latin-1 容错解码、失败抛异常）→ 校验文件存在非空 → 返回音频路径。
- [x] T014 实现 `note_extractor.py`（import librosa + audio_ffmpeg）：
  - `extract_notes(audio_path, ...)` / `extract_notes_from_signal(y, sr, ...)`：`librosa.pyin` → 逐帧 F0/voiced → MIDI 量化 → 连续同音高合并为音符 → 过滤短音符 → 返回音符列表（六字段）。额外抽出 `extract_notes_from_signal` 便于用合成信号做单元测试。
  - `video_to_notes(video_path, ...)`：编排 `extract_audio` → `extract_notes` → `finally` 中清理临时音频（除非 keep_audio）→ 直接返回音符序列。
- [x] T015 实现 `index.py`：`handler(event, context)` 兼容 bytes/str/dict 的 event，解析 `video_path`(必填) + 可选参数 → 调用 `video_to_notes` → return 音符序列 JSON（taskId/videoPath/sampleRate/noteCount/notes）。不做 OSS/回调/写文件。
- [x] T016 编写 `README.md`：函数计算部署说明、ffmpeg 依赖、event 入参示例、返回结构示例、本地测试方法、Python 3.10 兼容说明。

## Phase 4：测试与验证（已完成本地可执行项）

- [x] T017 单元测试 `test_audio_ffmpeg.py`：断言 `build_ffmpeg_cmd` 含 `-y`、`-vn`、`-i "<video_path>"`、`-acodec` 与 `/tmp` 输出路径；mock `subprocess.run` 断言 `extract_audio` 传参（shell=True/executable=/bin/bash/check=True）。本地通过（不依赖 librosa/ffmpeg）。
- [x] T018 单元测试 `test_note_extractor.py`：对合成 A4(440Hz) 正弦调用 `extract_notes_from_signal`，断言含 `A4`/MIDI 69/频率 435–445Hz。已编写；本地无 librosa 自动跳过，待 FC/具备依赖环境运行。
- [x] T019 单元测试：静音输入断言返回空音符列表、字段完整、无 NaN/0 频率项。已编写；本地跳过，待 FC 运行。
- [x] T020 本地 `py_compile` 五个文件全部通过；`python -m unittest discover -s tests` 通过（8 通过 / 3 跳过）。功能验证由用户在函数计算（Python 3.10）以 `event` 触发 handler。
- [x] T021 已 grep 确认无 `oss2/StsAuth/put_object/callback/requests.post/open(/.write(/quote(` 残留。

## 执行记录

### D001 - 文档记录

- 执行内容：基于用户需求与三点澄清，创建 105 号 Spec Kit 文档；完成 Phase 1/2 事实确认与风险门禁分析。
- 验证方式：环境探查（Python/pip/ffmpeg/librosa 现状）、模板对照、参数来源与调用时序梳理。
- 自检结论：满足强制门禁，无未确认的业务语义变化；待用户确认后进入实现。

### D002 - 实现记录

- 实现内容：新建 `videoToAudio` 项目——`audio_ffmpeg.py`（FFmpeg 提取，不依赖 librosa）、`note_extractor.py`（librosa pyin 音符提取 + 编排）、`index.py`（FC handler）、`requirements.txt`、`README.md`、`tests/`（两套单元测试）。
- 测试命令：
  - `python -m py_compile audio_ffmpeg.py note_extractor.py index.py tests/test_audio_ffmpeg.py tests/test_note_extractor.py`
  - `python -m unittest discover -s tests -v`
- 测试结果：py_compile 全部通过；unittest `Ran 11 tests ... OK (skipped=3)`（8 个 audio_ffmpeg 测试通过，3 个 note_extractor 测试因本地无 librosa 跳过）。
- 自检结论：
  - 参数来源：`video_path` 来自 event 必填；`audio_path` 由当前层 `generate_unique_filename` 生成并在 FFmpeg 成功后校验存在非空才交 librosa；pyin 的 `fmin/fmax/sr` 为常量默认或 event 覆盖，调用前赋值。
  - 调用顺序：extract_audio(check=True + 文件校验) → extract_notes 严格顺序，无调用后赋值风险。
  - 旧逻辑保持：`-y`/`-vn`、`shell=True`+`/bin/bash`、`/tmp`、latin-1 容错解码、`print_excute_time`、唯一文件名、临时清理、中文日志均保留。
  - 剩余风险：①功能（真实视频/A4 识别/静音）需在 FC 或装有 librosa 的环境验证；②`datetime.utcnow()` 在 Python 3.12+ 有弃用警告，目标 3.10 无影响（贴合参照源码保留）；③librosa/ffmpeg 在 FC 的打包/层由部署侧负责。

### D003 - 纠正记录（入口形态 + 验证方式）

- 触发原因：用户补充「本地不安装 librosa/ffmpeg，用函数计算服务器验证」，并选定「FC handler + 核心模块」入口。
- 修正内容：入口由 CLI 改为 `handler(event, context)`，直接 return 音符序列、不写本地文件；FFmpeg 命令拆到不依赖 librosa 的 `audio_ffmpeg.py`；本地仅 `py_compile` + 命令断言测试，功能验证在函数计算执行。
- 文档同步：已同步 `spec.md`、`AGENTS.md`、`tasks.md`（本节及 Phase 3/4）、`checklists/requirements.md`。
- 验证结果：本阶段未写代码，待实现后补记录。

### D004 - 环境适配记录（numba 与 coverage 导入冲突）

- 触发原因：FC 实跑在 `librosa.load` 处报错，堆栈终点 `numba/misc/coverage_support.py` 的 `class NumbaTracer(coverage.types.Tracer)`——层内 coverage 与 numba 不兼容。
- 修正内容：`note_extractor.py` 在 `import librosa` 前加 `sys.modules.setdefault("coverage", None)`，让 numba 走无 coverage 降级分支。建议重打层时不含 coverage/pytest。
- 文档同步：`spec.md`（D004）、`tasks.md`（本节）。
- 验证结果：`py_compile` 通过、`unittest` 8 通过/3 跳过；FC 待重新部署 `note_extractor.py` 重测。
