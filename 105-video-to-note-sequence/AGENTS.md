# 规格执行说明

本目录对应需求「从视频中提取单音旋律的音符序列」。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\105-video-to-note-sequence`
- 目标项目：`C:\workspace\ju-chat\videoToAudio`（全新独立 Python 项目，非 git 仓库内子模块）
- 相关模块：FFmpeg 音频提取 + librosa 单音基频跟踪（pyin）+ 音符序列输出

## 当前目标

- 入口为阿里云函数计算 `handler(event, context)`：从 `event` 读取 `video_path`（视频 URL）等参数，先用 FFmpeg 从视频中提取音频（参照用户给出的 FC handler 源码风格，Linux 环境 `/tmp` + `/bin/bash`）。
- 再用 librosa 对提取出的音频做单音旋律的基频(F0)跟踪与音符分段，得到按时间排序的音符序列。
- handler **直接 return 音符序列**（JSON 结构）；**不需要 OSS 上传与回调，不写本地文件**。
- **本地不安装 librosa/ffmpeg，不做本地运行验证**；功能验证在函数计算服务器（Python 3.10）上进行。本地只做语法/静态检查。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、配置来源和测试落点。
- 不允许把空对象或未赋值结果当成有效输入继续传递（本项目对应：不向 librosa 传未生成的音频路径，不把空音符列表当成功结果）。
- 对调用后赋值、字段来源不明、旧逻辑副作用，必须先标记风险。
- 发现关键参数依赖后续步骤补齐时，优先在当前层现算现用。
- 任何会改变调用顺序、接口契约、外部行为的方案，实施前必须确认业务意图。
- 单元测试不能只验证最终结果；必须断言传给 FFmpeg / librosa 的关键参数内容（命令参数、采样率、pyin 频率上下界等）。

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：每个关键参数（视频路径、音频中间文件路径、采样率、pyin 上下界、最短音符时长）从哪里来，是否在调用前赋值。
- 赋值时机：是否存在 FFmpeg 还未生成音频文件，librosa 就去读取的时序问题。
- 占位对象：是否存在把空音频路径、空 ndarray、空音符列表当成有效结果继续传递。
- 下游读取：librosa 阶段实际读取哪些输入（音频文件路径、采样率），是否全部有来源。
- 旧逻辑保持：参照源码中必须保留的行为——`-y` 覆盖、`-vn` 去视频、latin-1 容错解码 stderr、执行耗时日志装饰器、唯一文件名生成、临时文件清理。
- 影响范围：本项目为独立新建项目，不影响 workspace 内其他项目；确认不引入 OSS/回调等额外外部调用。
- 测试映射：每个关键行为至少对应一条单元测试或静态验证记录。

## 重点代码位置

- `videoToAudio/audio_ffmpeg.py`：FFmpeg 命令构造与音频提取（**不 import librosa**，便于在无 librosa 的本地环境做语法检查与命令断言）。
- `videoToAudio/note_extractor.py`：核心模块（librosa 提取音符序列 + 编排 `video_to_notes`）。
- `videoToAudio/index.py`：函数计算入口 `handler(event, context)`（解析 event → 调用核心 → return 音符序列 JSON）。
- `videoToAudio/requirements.txt`：依赖声明（librosa、soundfile、numpy 等）。
- `videoToAudio/tests/test_audio_ffmpeg.py`、`tests/test_note_extractor.py`：单元测试落点（在具备依赖的环境运行）。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
