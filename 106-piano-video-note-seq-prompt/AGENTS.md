# 规格执行说明

本目录对应需求「钢琴作业视频 V2 先取音序再注入提示词」。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\106-piano-video-note-seq-prompt`
- 目标项目：`C:\workspace\ju-chat\fc`（多模块 Maven，Java 8）
- 目标模块：`fc/Gemini-Api`
- 相关模块：`fc/common`（提供 `FcInvokeUtils`、`FcInvokeInput`、`fc_open20210406` SDK）
- 相关项目：`C:\workspace\ju-chat\videoToAudio`（`VideoToNoteSeq` Python 函数源码）
- 关联 spec：`105-video-to-note-sequence`（`VideoToNoteSeq` 函数返回结构来源）；`101-piano-homework-video-v2-task`（被改类的初始建立 spec）

## 当前目标

- 在 `PianoHomeWorkVideoV2Task.analyzeVideo` 中、对 Gemini 发起调用之前，默认通过 `FcInvokeUtils.doTask` 异步提交函数计算 `FcOssFFmpeg-3278/VideoToNoteSeq`（event `video_path = file_url`，并携带内部音序 `cacheKey`），再通过 Redis 等待音序 JSON。
- 把返回的 `notes` 提炼为**音名序列文本**（先按 `confidence ≥ 阈值` 过滤掉静音/噪声误判音符，默认阈值 `0.5`、可由 env `PIANO_HOMEWORK_VIDEO_V2_NOTE_SEQ_MIN_CONFIDENCE` 覆盖；再以空格连接音名，沿用上游顺序），替换 `prompt` 中的字面量占位符 `${audioseq}`。
- 用替换后的 `prompt` + **原视频** 继续走原有 Gemini 调用链（fileUrl/inlineData/auto 三模式与回退、缓存、锁、脱敏均不变）。
- `VideoToNoteSeq` 失败或返回空音序时**不中断**：以空音序文本继续替换并调用 Gemini，仅记 warn 日志，不写 FAIL。
- D005：`PianoHomeWorkVideoV2Task` 默认音序同步调用必须显式走北京 VPC FC endpoint（`fc-vpc.cn-beijing.aliyuncs.com`）；不要把所有 `FcInvokeUtils.doSyncTask(...)` 调用方全局迁移到 VPC endpoint。
- D006：D005 被新口径取代且已实施。`PianoHomeWorkVideoV2Task` 默认音序调用改为 POST `http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/ai/transfer/fc`，body 为 `{taskObj:event, serviceName, functionName, isVpc:true}`；不再通过 `FcInvokeUtils` 直接调 FC SDK。
- D007：D006 默认调用方式被新口径取代，当前目标改为：Java 端默认音序调用使用 `FcInvokeUtils.doTask` 异步提交 `VideoToNoteSeq`，通过内部音序 Redis `cacheKey` 等待 `SUCCESS.result`；Python `videoToAudio/index.py` 在收到 `cacheKey` 时写 Redis `RUNNING/SUCCESS/FAIL`，无 `cacheKey` 时保持直接 return。D007 已实施，待用户验收。
- D008：在音序替换完成后、调用 Gemini 前打印最终 prompt 日志，包含替换后长度与内容；超长 prompt 做截断保护。D008 已实施，待用户验收。
- D009：新增工程侧音序特征 JSON 注入提示词，字段固定且不输出候选排名/最终课程 id；工程侧先过滤极低短噪声、八度归一化量化同音重复/持续下行/F 音/上下游走/音区/节奏/pyin 置信度。去噪后有效音 `<5` 直接返回人工复核 JSON，不调用 LLM。`sop-reply` 透传 `expectedDay=logicalDay` 与私聊最近 3 条非空聊天记录（群聊不传），这些上下文只作弱参考。
- D010：已按 D2 当前进度尝试两个提示词 x 5 个 demo 视频回归；FC 异步提交返回 202，但本地 Redis 结果读取失败，10 次均因有效音为 0 短路，未进入 Gemini。
- D011：用户补充 Redis 连接信息后已重跑 D2 回归矩阵；FC/Redis 跑通，10 次均进入 Gemini。旧提示词 `4/5 PASS`，仅 V2 误判为 D1；V3 音序提示词 `1/5 PASS`，仅 V3 命中，V1/V5 误判或兜底。结论：V3 音序提示词暂不适合作为默认版本，V2 多声部主旋律提取仍是核心风险。
- D012：已新增 D1/D2 工程侧模板优先判定。高置信模板命中时工程侧可覆盖最终课程分类字段；仍调用 Gemini 保留指法、手型、单双手、节奏等视频诊断。若高置信 D1/D2 命中但 Gemini proxy 调用失败，返回工程分类兜底 JSON 且 `needHumanReview=true`。
- D013：工程侧模板覆盖范围已扩展到 D1/D2/D3。D2 使用用户补充的左右手分句模板并保留长模板容错；D3 使用《沧海一声笑·无和弦》模板；结尾连续 3 个以上 E 音级优先判 D2。`视频理解提示词V1_2.txt` 的 D2 最新 6 视频回归为 6/6 PASS。
- D014：`PianoNoteSequenceTemplateMatcher` 已增加 `contiguousPhraseSimilarity`（2/3/4-gram Dice overlap）和窄口径 D1 纠偏；当基础 best 为 D2 且 D2 未达高置信、D1 音级分布与连续短语显著更强时改判 D1。真实新增 D1 视频存在整体移调，D014 在 D1 纠偏内部增加 D1 模板 12 半音移调评分，命中时输出 `transpositionShift` 并按 D1 高置信覆盖。
- D016：李瑶(110/默认)工程侧模板已扩展为 D1 四季歌、D2 铁血丹心、D3-D4 沧海一声笑、D5-D6 萱草花四个曲目组；D3/D4 与 D5/D6 组内按 `expectedDay` 算最终 `id/recognizedDay/submissionType`，不靠音频细分有无和弦。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；入口、调用链、字段来源、配置来源、测试落点均已在 `spec.md` 与 `tasks.md` Phase 1 确认。
- 不允许把空对象/未赋值结果当有效输入下传（本项目对应：`VideoToNoteSeq` 失败/空音序 → 空音名序列文本，不伪装成有效音序，但按用户确认继续调用 Gemini）。
- 音序结果仍必须在 Gemini 调用之前取得；D007 当前实现为异步提交 FC 后等待 Redis 结果，已取得用户明确要求与确认。
- 单元测试必须断言传给 `VideoToNoteSeq` 的下游参数（serviceName/functionName/event.video_path）与传给 Gemini 的 prompt（占位符已替换）/fileUri（仍传视频），不能只断言最终结果。

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：`prompt`、`file_url`、`noteSeqText`、`serviceName`/`functionName`、`event.video_path`/`task_id` 从哪里来，是否在调用前赋值。
- 赋值时机：是否存在「先赋 `event.video_path`、`VideoToNoteSeq` 返回后才有音序、替换后才有最终 prompt」的时序，确保 `noteSeqText` 在替换前算好、`prompt`/`file_url` 在音序调用前已校验。
- 占位对象：`FcInvokeInput` 是否在调用前 set 齐 `serviceName`/`functionName`/`taskObj`，不传空占位。
- 下游读取：`VideoToNoteSeq` 读 `event.video_path`；`buildNoteSequenceText` 读 `notes[*].note`；Gemini 读替换后的 `prompt` 与 `fileUri`，是否全部有来源。
- 旧逻辑保持：RUNNING/SUCCESS/FAIL 缓存与字段与 TTL、分发锁释放、MDC、脱敏、三模式与回退、`validateRequired` 错误口径，必须不变。
- 影响范围：仅改 `fc/Gemini-Api`（主要是 `PianoHomeWorkVideoV2Task` 及其单测）；不影响其他模块；不引入 OSS/MQ/数据库调用。
- 测试映射：每个关键行为（取音序参数、音名拼接、占位符替换、失败继续、空音序、无占位符、不回归）至少对应一条单元测试。
- D005 endpoint 门禁：音序路径使用 VPC 同步方法；默认 `doSyncTask` 保持原 `fnEndpoint` 覆盖/北京公网 fallback，避免影响其他同步 FC 调用。
- D006 HTTP 门禁：音序路径使用 transfer/fc HTTP 网关；body 中 `isVpc=true`、`taskObj.video_path`、`serviceName/functionName` 必须有测试或静态验证；移除 D005 新增且不再使用的 `FcInvokeUtils` 公共方法。
- D007 异步 Redis 门禁：Java event 中 `cacheKey` 必须在异步提交前生成并传给 Python；Python 必须在有 `cacheKey` 时写 `RUNNING/SUCCESS/FAIL`；Java 必须测试 Redis `SUCCESS`/`FAIL`/超时；音序 Redis key 不得覆盖外层主任务 `cacheKey`。
- D012/D013/D014 模板优先门禁：只有 D1/D2/D3 模板达到高置信规则或 D014 的窄口径 D1 纠偏条件时才覆盖课程分类；覆盖范围限制在分类字段，不能抹掉 Gemini 的诊断字段；低置信不覆盖。D1 移调评分只在 D1 纠偏内部作为补充证据，不能把所有模板全局改成移调匹配。若 Gemini 原分类证据与工程覆盖冲突，最终 evidence 必须替换为工程覆盖说明。
- D016 曲目组门禁：D3-D4、D5-D6 组内最终天数必须由 `expectedDay` 与 `dayMin/dayMax` 现算；高置信工程判定、Gemini 失败兜底和提示词工程证据不得继续只写模板代表天。

## 重点代码位置

- `fc/Gemini-Api/src/main/java/com/drh/gemini/api/PianoHomeWorkVideoV2Task.java`：入口 `handleRequest` 与 `analyzeVideo`（在 `validateRequired` 之后、Gemini 调用之前插入「取音序 + 替换占位符」）；新增 `NoteSequenceCaller` 接口 + 默认实现 + `buildNoteSequenceText`（按 `confidence` 阈值过滤后拼音名）+ `replacePromptPlaceholder` + 服务/函数名/置信度阈值常量与 env。
- `fc/Gemini-Api/src/main/java/com/drh/gemini/api/PianoNoteSequenceFeatureExtractor.java`：D009 音序特征提取器，输出固定工程侧 JSON 与过滤后音序文本，不输出课程候选。
- `fc/Gemini-Api/src/main/java/com/drh/gemini/api/PianoNoteSequenceTemplateMatcher.java`：D1/D2/D3/D5 音序模板匹配器，输出模板分数、高置信工程判定，处理 D2 结尾连续 E 音级优先规则；D014 新增 `contiguousPhraseSimilarity` 与 D1 窄口径纠偏/移调评分，D016 新增萱草花 D5-D6 曲目组证据。
- `fc/sop-reply/src/main/java/com/drh/homework/service/homeworkhandle/PianoVideoHomeWorkHandleServiceImpl.java`：D009 识别 FC 触发参数增加 `expectedDay` 与私聊最近 3 条聊天记录。
- `fc/sop-reply/src/main/java/com/drh/homework/service/SopReply.java`、`fc/sop-reply/src/main/java/com/drh/homework/dto/HomeWorkMessageDto.java`：D009 透传群聊标记与聊天记录。
- `fc/common/src/main/java/com/drh/common/util/FcInvokeUtils.java`：D007 默认音序调用使用 `doTask` 异步提交 FC；D006 的默认 HTTP 网关方案已被取代；不要改动默认 `doSyncTask`、`doTaskWithDelay` 对其他调用方的行为。
- `fc/common/src/main/java/com/drh/common/dto/FcInvokeInput.java`：`serviceName`/`functionName`/`taskObj`/`traceId`（链式 setter）。
- `fc/Gemini-Api/src/main/java/com/drh/gemini/api/AppTask.java`：本模块内 `FcInvokeUtils` 用法范例（已抽象成接口便于测试）。
- `fc/Gemini-Api/src/test/java/com/drh/gemini/api/PianoHomeWorkVideoV2TaskTest.java`：单测落点（新增 `FakeNoteSequenceCaller` 并更新 `newTask`）。
- `specs/105-video-to-note-sequence/index.py`：`VideoToNoteSeq` event 入参（`video_path`）与返回结构（`notes[*].note` 等）来源。
- `videoToAudio/index.py`：D007 需支持 `cacheKey` 写 Redis 状态，同时保留无 `cacheKey` 直接 return。
- `videoToAudio/requirements.txt`、`videoToAudio/README.md`、`videoToAudio/tests/`：D007 需补 Redis 依赖说明与 Python 测试。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
