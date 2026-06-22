# 功能规格：从视频中提取单音旋律的音符序列

**功能目录**：`105-video-to-note-sequence`  
**创建日期**：`2026-06-21`  
**状态**：Draft（待用户确认进入实施）  
**输入**：用户需求——「编写一个从视频中提取音符序列：先用 FFmpeg 提取音频，再用 librosa 提取音符序列并输出。代码写在 `C:\workspace\ju-chat\videoToAudio`，仿照给出的阿里云 FC handler 源码风格编写。」澄清结论：①提取出音符序列直接返回即可，不需要 OSS 存储与回调；②按单音旋律方式提取；③目标服务器 Python 3.10；④（D003 纠正）入口写成函数计算 `handler(event, context)` + 核心模块；⑤（D003 纠正）本地不安装 librosa/ffmpeg，改为在函数计算服务器上验证。

## 背景

- 当前问题：`videoToAudio` 目录为空，需要从零搭建一个「视频 → 音频 → 音符序列」的处理工具。
- 当前行为：无代码。用户提供了一段阿里云 FC handler 源码作为**风格参照**（其逻辑为：从 OSS 拉视频 → FFmpeg 提取音频 → 上传 OSS → HTTP 回调）。
- 目标行为：实现一个部署在阿里云函数计算的 Python 工具。入口 `handler(event, context)` 从 `event` 读取 `video_path`（视频 URL）等参数，用 FFmpeg 在 `/tmp` 提取音频文件，再用 librosa（pyin 单音基频跟踪 + 起止分段）得到按时间排序的音符序列，**handler 直接 return 该序列（JSON 结构）**。核心提取逻辑独立成模块供复用。
- 非目标：
  - 不做 OSS 上传、不做 HTTP 回调（用户明确不需要）。
  - 不写本地输出文件（FC 无状态，结果由 handler 直接返回）。
  - 不做多音/和弦的复音转录（本次仅单音旋律）。
  - 不输出 MIDI 文件、不做乐谱渲染（本次只输出结构化音符序列；如需 MIDI 列为后续可选项）。
  - 不实现实时/流式处理。
  - 本次不在本地安装依赖运行验证（本地仅语法/静态检查），功能验证在函数计算服务器执行。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 从本地视频提取音符序列（优先级：P1）

作为使用者，我提供一个包含单音旋律（如钢琴单音独奏、哼唱）的视频文件，希望工具自动提取音频并给出按时间排序的音符序列（每个音符含音名、MIDI 号、起始时间、时长、频率、置信度），便于后续比对或分析。

**独立测试**：准备一段已知旋律的短视频 URL（或直接用已知音高的合成音频绕过 FFmpeg），在函数计算上触发 handler，检查返回的音符序列在音名与时序上与预期一致。

**验收场景**：

1. **Given** 一个含单音旋律的视频 URL，**When** 以 `event = {"video_path": "<URL>"}` 触发 handler，**Then** handler return 一个 JSON，含按 `start` 升序排列的音符数组（六字段），不产生 OSS/回调动作。
2. **Given** 一段纯 A4（440Hz）正弦音频，**When** 调用核心提取函数，**Then** 返回的音符中至少有一个音名为 `A4`、MIDI 号为 `69`、频率接近 440Hz。
3. **Given** 视频中存在静音/无音高段（如换气、停顿），**When** 提取，**Then** 这些段不产生音符（被过滤），不会出现频率为 0 或 NaN 的音符项。

### 用户故事 2 - handler 入参与返回结构（优先级：P2）

作为部署者，我在函数计算上以 `event` JSON 传入 `video_path`（视频 URL）及可选参数（编码、比特率、采样率、fmin/fmax 等），希望 handler 解析后完成提取并以稳定结构返回。

**独立测试**：构造 `event` JSON 触发 handler，确认 FFmpeg 命令以该 URL 为 `-i` 输入、`/tmp` 为输出目录，handler 返回结构含音符数组与基本元信息（如音符数量、采样率）。

**验收场景**：

1. **Given** 一个 http(s) 视频 URL 的 `event`，**When** 触发 handler，**Then** FFmpeg 以该 URL 为输入在 `/tmp` 提取音频，librosa 处理后 handler 直接 return 音符序列 JSON。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `video_path`：来源 CLI 参数 / 函数入参；调用前赋值；下游读取位置 = FFmpeg 命令的 `-i` 输入。
  - `audio_path`（中间音频文件路径）：来源 = 当前层基于唯一文件名生成（参照源码 `generate_unique_filename` 风格，落在临时目录）；赋值时机 = FFmpeg 调用前生成路径字符串，FFmpeg 调用后文件才真正存在；下游读取位置 = librosa `load(audio_path)`。**必须保证 FFmpeg 成功返回后再交给 librosa**。
  - `sample_rate`（采样率）：来源 = 模块常量/入参默认 `22050`；调用前赋值；下游读取 = `librosa.load(sr=...)` 与 `librosa.pyin`/帧时间换算。
  - `fmin`/`fmax`（pyin 频率上下界）：来源 = 模块常量默认（如 `C2`≈65.4Hz 到 `C7`≈2093Hz）；调用前赋值；下游读取 = `librosa.pyin`。
  - `min_note_duration`（最短音符时长，过滤毛刺）：来源 = 模块常量/入参默认；调用前赋值；下游读取 = 音符分段合并阶段。
- 下游读取字段清单：
  - FFmpeg 阶段读取：`video_path`、`audio_codec`、`audio_bitrate`、`audio_path`（输出）。
  - librosa 阶段读取：`audio_path`、`sample_rate`、`fmin`、`fmax`、`frame_length`/`hop_length`。
  - 音符分段阶段读取：逐帧 `f0`、`voiced_flag`/`voiced_prob`、帧时间轴、`min_note_duration`。
- 空对象 / 占位对象风险：
  - 不存在 `new XxxDto()` 式占位（Python 项目）。需防止的等价风险：①FFmpeg 失败却继续把不存在的 `audio_path` 传给 librosa；②librosa 整段未检测到有声段时返回空列表却被当作「成功且有结果」。处理策略：FFmpeg 失败抛异常并中止；空音符序列要么明确返回空数组并在日志/返回结构中标注，不伪装成有结果。
- 调用顺序风险：
  - 存在「先生成 `audio_path` 字符串、FFmpeg 之后文件才存在」的时序。处理策略：严格顺序——生成路径 → FFmpeg 提取（`check=True`）→ 校验文件存在且非空 → 再 librosa 读取。
- 旧逻辑保持（对照参照源码必须保留的行为）：
  - FFmpeg 命令保留 `-y`（覆盖输出）、`-vn`（去除视频流）。
  - 执行方式保留 `subprocess.run(..., shell=True, executable="/bin/bash", check=True)`，输出目录 `/tmp`（FC Linux 环境）。
  - stderr/stdout 用 `latin-1` + `errors='ignore'` 容错解码（避免非 UTF-8 字节报错）。
  - 保留 `print_excute_time` 执行耗时日志装饰器风格。
  - 保留 `generate_unique_filename` 唯一文件名生成（时间戳 UTC+8 + 短 UUID）思路，用于 `/tmp` 中间音频文件。
  - 保留临时文件清理（处理完成后删除中间音频文件，可由 `event.keep_audio` 控制是否保留以便调试）。
  - 日志保留中文描述（符合本仓库约定）。
- 需要用户确认的设计选择：
  - 音符输出字段集合（本规格默认：音名、MIDI 号、起始时间、时长、频率、置信度）——作为默认假设，若用户有特定下游格式要求需调整。
  - 是否保留中间音频文件（默认删除，提供 `event.keep_audio` 保留）。
  - handler 返回结构是否需要额外元信息（如音符数量、采样率、耗时）——默认附带，若不需要可精简。

## 边界情况

- 视频无音轨：FFmpeg 提取失败或生成空音频 → 抛出明确异常并记录中文日志，不进入 librosa。
- 视频/URL 不可达：FFmpeg 非零退出 → 捕获 `CalledProcessError`，记录返回码与 stderr，抛出业务异常。
- 全程静音或无可识别音高：pyin 全部 `voiced=False` → 返回空音符数组，日志提示「未检测到有效音高」，不报错。
- 极短音符/毛刺：时长小于 `min_note_duration` 的片段被过滤，避免抖动产生大量碎片音符。
- 音高跳变与连续同音：相邻帧同一 MIDI 音高合并为一个音符；不同音高切分为相邻音符。
- 采样率与时长换算：所有时间用 `hop_length / sample_rate` 统一换算，避免单位错乱。
- ffmpeg 不在 PATH：启动时检测，缺失则给出明确中文报错与安装提示，而非晦涩异常。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 使用 FFmpeg 从输入视频（本地路径或 URL）提取音频到本地临时文件，命令保留 `-y` 与 `-vn`，音频编码/比特率可配置（默认与音符分析友好的 wav/PCM 或 mp3）。
- **FR-002**：系统 MUST 使用 librosa `pyin` 做单音基频(F0)跟踪，并基于逐帧 F0 与有声标记，将连续同音高帧合并为音符，输出按起始时间升序排列的音符序列。
- **FR-003**：每个音符 MUST 至少包含：音名（如 `A4`）、MIDI 号（整数）、起始时间 `start`（秒）、时长 `duration`（秒）、频率 `frequency`（Hz）、置信度 `confidence`。
- **FR-004**：入口 `handler(event, context)` MUST 从 `event` 读取 `video_path` 等参数，并把音符序列作为返回值 return（JSON 结构）；MUST NOT 进行 OSS 上传、HTTP 回调或写本地输出文件。
- **FR-005**：系统 MUST 在 FFmpeg 失败或音频文件未生成/为空时中止并抛出明确异常，MUST NOT 把不存在的音频路径交给 librosa。
- **FR-006**：系统 MUST NOT 改变参照源码中保留的容错与运行行为（`-y`/`-vn`、`latin-1` 解码 stderr、`shell=True` + `executable="/bin/bash"`、`/tmp` 临时目录、唯一文件名、临时文件清理、中文日志、执行耗时日志）。
- **FR-007**：代码 MUST 兼容 Python 3.10（函数计算运行环境）；功能验证在函数计算服务器执行，本地仅做语法/静态检查（不安装 librosa/ffmpeg）。
- **FR-008**：单元测试 MUST 断言下游关键参数（FFmpeg 命令含 `-vn`/`-y`/正确输入与 `/tmp` 输出路径；pyin 的 `fmin`/`fmax`/`sr`），并断言音符分段在已知合成音频上的正确性；测试在具备依赖的环境运行。
- **FR-009**：FFmpeg 命令构造 MUST 与 librosa 解耦放在独立模块（`audio_ffmpeg.py`，不 import librosa），以便在无 librosa 的本地环境完成命令断言与 `py_compile` 语法检查。

## 成功标准 *(必填)*

- **SC-001**：对一段纯 A4（440Hz）合成音频，提取结果中存在音名 `A4`、MIDI `69`、频率落在 435–445Hz 的音符。
- **SC-002**：对含明显停顿的旋律，静音段不产生音符，且无频率为 0/NaN 的音符项。
- **SC-003**：FFmpeg 命令字符串包含 `-y`、`-vn`、正确的 `-i 输入` 与输出音频路径，并能由单元测试断言。
- **SC-004**：在函数计算（Python 3.10）以 `event = {"video_path": "<样例URL>"}` 触发 handler 能成功跑通并 return 音符序列 JSON；具备依赖的环境中单元测试全部通过。
- **SC-005**：代码不含 OSS/回调/写本地文件相关调用，且未引入对 workspace 内其他项目的依赖。
- **SC-006**：本地对全部 `.py` 文件执行 `py_compile` 语法检查通过；`audio_ffmpeg.py` 不 import librosa，其命令断言测试可在无 librosa 环境运行。

## 假设

- 音符输出字段集合采用默认六项（音名、MIDI、start、duration、frequency、confidence）；若用户后续指定下游格式，按 Dxxx 纠正。
- 默认采样率 `22050`、`fmin=C2`、`fmax=C7`、最短音符时长 `~0.05s`，均为可调参数（可由 `event` 覆盖），作为合理默认值。
- `event.video_path` 为可被 FFmpeg 直接 `-i` 拉取的视频 URL（与参照源码一致）；本次不从 OSS 下载视频。如实际为 OSS 内部路径，按 Dxxx 纠正。
- 函数计算运行环境为 Linux（沿用 `/bin/bash`、`/tmp`），ffmpeg 通过自定义运行时/层或部署包在 PATH 中可用；librosa/soundfile/numpy 通过部署依赖包或层提供。具体打包方式由部署侧负责，本次只声明 `requirements.txt`。
- 代码保持 Python 3.10 兼容语法；不在本地（3.12/3.14）安装 librosa/ffmpeg 运行，本地仅 `py_compile` 语法检查 + 不依赖 librosa 的命令断言测试。功能验证由用户在函数计算上执行。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档（105-video-to-note-sequence）。
- 已完成历史问题防漏分析和强制门禁分析（参数来源、调用时序、旧逻辑保持、空结果风险、测试映射）。
- 本阶段未编写任何业务代码，等待用户确认进入实施。

### D002 - 实现记录

- 实现内容：新建 `videoToAudio` 项目，含 `audio_ffmpeg.py` / `note_extractor.py` / `index.py`（handler）/ `requirements.txt` / `README.md` / `tests/test_audio_ffmpeg.py` / `tests/test_note_extractor.py`。
- 影响范围：仅新增 `C:\workspace\ju-chat\videoToAudio` 独立目录，未触碰 workspace 内其他项目；不含 OSS/回调/写本地文件。
- 测试命令：`python -m py_compile ...`；`python -m unittest discover -s tests -v`。
- 测试结果：py_compile 全部通过；unittest `Ran 11 tests ... OK (skipped=3)`（audio_ffmpeg 命令/调用断言全过；note_extractor 因本地无 librosa 跳过，待 FC 验证）。已 grep 确认无 OSS/回调残留。
- 自检结论：参数来源与赋值时机、调用顺序（FFmpeg 成功+文件校验后才交 librosa）、旧逻辑保持均符合规格；剩余风险=功能识别需在函数计算实跑验证、`datetime.utcnow()` 弃用警告仅本地 3.14、FC 依赖打包由部署侧负责。

### D003 - 纠正记录（入口形态 + 验证方式）

- 触发原因：用户补充——「本地不用安装 librosa/ffmpeg，使用函数计算服务器去验证」；并确认入口写成「FC handler + 核心模块」。
- 修正内容：
  - 旧口径：本地 CLI 脚本入口，结果打印到控制台 + 写本地 JSON 文件；本地用 Python 3.12 虚拟环境安装依赖运行验证。
  - 新口径：入口为函数计算 `handler(event, context)`，从 `event` 读 `video_path` 等参数，handler **直接 return 音符序列 JSON**，不写本地文件；FFmpeg 命令构造拆到不依赖 librosa 的 `audio_ffmpeg.py`；本地不安装 librosa/ffmpeg，仅 `py_compile` 语法检查 + 命令断言测试，功能验证在函数计算（Python 3.10）执行。
- 文档同步：已同步 `spec.md`（输入澄清④⑤、目标行为、非目标、用户故事 1/2、FR-004/006/007/008/009、SC-004/005/006、假设）、`AGENTS.md`（当前目标、重点代码位置）、`tasks.md`（实现/验证任务与执行记录）、`checklists/requirements.md`（实施就绪度）。
- 验证结果：本阶段未写代码；待实现后补 `py_compile` 与单元测试结果。

### D004 - 环境适配记录（FC 上 numba 与 coverage 导入冲突）

- 触发原因：函数计算实跑——新代码部署成功且 FFmpeg 提取音频已通过，但在 `note_extractor.extract_notes` 的 `librosa.load` 处报错；堆栈终点为 `/opt/python/numba/misc/coverage_support.py` 的 `class NumbaTracer(coverage.types.Tracer)`。即依赖层中的 `coverage` 版本与 numba 不兼容，导致 import numba（进而 import librosa）失败。
- 修正内容：在 `note_extractor.py` 中、`import librosa` 之前加入 `sys.modules.setdefault("coverage", None)`，使 numba 的 coverage_support 走 `except ImportError` 降级分支，跳过 `NumbaTracer` 定义。运行时不需要 coverage，行为无副作用。属环境适配，非业务语义变更。
- 配套建议（未改代码，提示部署侧）：重打依赖层时仅安装 `requirements.txt`，不要把 `coverage`/`pytest` 等开发测试包打进层，保持层精简。
- 文档同步：已同步 `spec.md`（本记录）、`tasks.md`（D004）。
- 验证结果：本地 `py_compile` 通过、`unittest` 11 项（8 通过/3 跳过）不变；函数计算侧待用户重新部署 `note_extractor.py` 后重测。

### D005 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
