# 规格执行说明

本目录对应需求「钢琴作业视频按 speakerId 分流：雅琪（113）独立提示词与识别逻辑」。独立于 `108-yaqi-piano-homework-config`（按用户要求不共用）。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\109-piano-yaqi-speaker-note-seq`
- 目标项目：`C:\workspace\ju-chat\fc`（多模块 Maven，Java 8）
- 目标模块：`fc/sop-reply`（speakerId 透传 + 提示词按 speaker 选 env）、`fc/Gemini-Api`（speakerId 读取 + 雅琪曲目组识别 + submissionType + 仅注入不覆盖）
- 相关模块：`fc/common`（`FcInvokeUtils`/`FcInvokeInput`，本次不改其行为）
- 相关项目：`C:\workspace\ju-chat\videoToAudio`（`VideoToNoteSeq` 单音提取，本次**不改**）
- 关联 spec：`106-piano-video-note-seq-prompt`（音序注入 + D1/D2/D3 工程侧模板与高置信覆盖，110 现状来源）、`101-piano-homework-video-v2-task`（被改类初始 spec）、`105-video-to-note-sequence`（音序返回结构）
- 提示词文件：`C:\Users\EDY\Downloads\视频理解提示词V1_3.txt`（雅琪课程体系，按本规格调整后作为 `piano_video_prompt_speaker_113`）

## 当前目标

- 打通 speakerId 透传：`HomeWorkMessageDto` 增 `speakerId`，SopReply 填充，`taskObj` 透传，`PianoHomeWorkVideoV2Task` 读取。
- 提示词按 speakerId 选 env：110/空/未知 → `piano_video_prompt`（不回归）；其它 → `piano_video_prompt_speaker_<id>`（113 → `piano_video_prompt_speaker_113`）；仍按 `logicalDay` 替换 `D%s`。
- 雅琪识别逻辑：用右手 pitch class 判「组 X=但愿人长久（D1-D3）/ 组 Y=沧海一声笑·有和弦（D4）/ 未匹配」；按组与 expectedDay 算 `submissionType`（D1/D2/D3 互为今日，D4↔D1-3 判补交/提前）；把 `recognizedGroup`/`submissionType` 经 `${engineeringContext}` 注入；**不覆盖** Gemini 的 `id/recognizedDay/title`，单双手细分交 Gemini。
- 110（李瑶）提示词、模板、高置信覆盖、缓存/锁/三模式/脱敏/`<5` 短路全部不回归。
- 调整 `视频理解提示词V1_3.txt` 接收工程侧证据并写明判定职责分工。

## 执行原则

- 先读代码，再定方案，后实现。入口、调用链、字段来源、配置来源、测试落点已在 `spec.md` 与 `tasks.md` Phase 1 确认。
- 不允许把空对象/未赋值结果当有效输入下传：`taskObj.speakerId` 仅有效时写；雅琪两组不匹配 → `未匹配`/`未知`，不伪造曲目组或作业类型。
- 雅琪分支与 110 `match` 严格隔离：110 走原 `match` 与全部高置信规则，113 走独立模板与判定，互不污染。
- speakerId 必须在 FC 提交前写入 taskObj；雅琪 `recognizedGroup`→`submissionType`→注入→Gemini 严格时序。
- 单元测试必须断言下游参数（`taskObj.speakerId`、所选 env、`recognizedGroup`、`submissionType`、注入 prompt、仍传视频、不覆盖分类），不能只断言最终结果。

## 强制门禁

实现前必须完成并记录（见 `tasks.md` Phase 1/2）：

- 参数来源：`speakerId`、`promptEnvName`、`recognizedGroup`、`submissionType` 从哪里来，是否调用前赋值。
- 赋值时机：speakerId 是否在 FC 提交前写入；雅琪证据是否在注入/Gemini 调用前算好。
- 占位对象：`taskObj.speakerId` 与雅琪曲目组是否避免占位；不新增空 DTO 下传。
- 下游读取：`appendRecognitionContext`/`resolvePianoVideoPrompt`/`PianoHomeWorkVideoV2Task`/雅琪匹配的读取字段是否全部有来源。
- 旧逻辑保持：110/默认全部既有行为不变；`resolvePianoVideoPrompt` 的 `D%s` 与无占位符分支不变。
- 影响范围：仅 `fc/sop-reply`+`fc/Gemini-Api`（及提示词文本）；FC taskObj 新增字段与新增 env 为受控变更，需用户确认；不改 Python、不改 MQ/Redis/DB/OTS。
- 测试映射：每个关键行为至少一条单测/静态验证。

## 重点代码位置

- `fc/sop-reply/src/main/java/com/drh/homework/dto/HomeWorkMessageDto.java`：新增 `Integer speakerId`。
- `fc/sop-reply/src/main/java/com/drh/homework/service/SopReply.java`：`resolveHomeworkMessage` 填充 speakerId（`resolveVideoRecognizeService`/`resolveSpeakerId` 周边）。
- `fc/sop-reply/src/main/java/com/drh/homework/service/homeworkhandle/PianoVideoHomeWorkHandleServiceImpl.java`：`appendRecognitionContext`（写 taskObj.speakerId）、`resolvePianoVideoPrompt`（按 speakerId 选 env）。
- `fc/Gemini-Api/src/main/java/com/drh/gemini/api/PianoHomeWorkVideoV2Task.java`：读 request speakerId；雅琪分支（曲目组识别 + submissionType + 注入 + 不覆盖）；复用 `injectEngineeringContext`/`ENGINEERING_CONTEXT_PLACEHOLDER`/`resolveExpectedDay`。
- `fc/Gemini-Api/src/main/java/com/drh/gemini/api/PianoNoteSequenceTemplateMatcher.java`：新增雅琪组 X/组 Y 模板常量与独立匹配方法（输出 recognizedGroup），110 `match` 不变。
- `fc/Gemini-Api/src/test/java/com/drh/gemini/api/PianoHomeWorkVideoV2TaskTest.java`：新增雅琪用例与 110 不回归断言。
- `C:\Users\EDY\Downloads\视频理解提示词V1_3.txt`：调整为 `piano_video_prompt_speaker_113` 内容。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
