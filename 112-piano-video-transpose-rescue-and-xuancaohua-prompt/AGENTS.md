# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\112-piano-video-transpose-rescue-and-xuancaohua-prompt`
- 目标项目：`C:\workspace\ju-chat\fc\Gemini-Api`
- 相关模块：钢琴作业视频识别 V2 链路（音序模板匹配 + 提示词注入）

## 当前目标

- 目标 1：修复移调补救 `bestTransposedRescue` 对「课程外音级噪声序列」的假阳性——日志中 `D3 F3 F#3 F#3 C#3 F#3 B3 F#3 D#3 D#3 D3 C#3 C#3` 这类全升号噪声被整体移调 9 半音后靠铁血丹心超长模板 coverage 虚高凑成高置信 D2，应改为不命中、走「非作业 + 人工复核」。
- 目标 2：核对识别代码 `D5_TEMPLATE`（萱草花）与用户给定四句音序一致（已确认完全一致），新增锁定测试；并修复 D5 过度贪婪（仅凭音级集合虚高抢 D2/D3）的既有回归（见 spec D003/D004）。
- 目标 3：把修正后的完整 V2 提示词（D5/D6 音序改 C 大调权威四句、修正关键特征/规则）放入本目录 `prompt-v2-revised.md`，由用户方更新到线上。（注：仓库内 demo-prompt 为 V1 新供应商测试用，非本 V2 提示词，先前对它的改动已还原。）
- 目标 4：D005 已真实调用 `FcOssFFmpeg-3278/VideoToNoteSeq` 完成视频回归，结果见 `regression.md` 与 `out/real-regression-results.json`；D006 已确认 D4 下 V5 识别 D5 后应判「提前提交」，前文「当日作业」为用户口误。
- 目标 5：D007 修复雅琪 speakerId=113 低质量沧海音序误判 `组X(但愿人长久)`；该类组别不稳定样本应转 `id=-1` 人工介入。
- 目标 6：D008 修复李瑶体系低质量升半音沧海被 D2《铁血丹心》远距离整体移调 6 半音抢走；自动移调补救仅允许绝对距离 ≤2 半音，D008 样本应输出 D4《沧海一声笑》。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、配置来源和测试落点。
- 不允许把空对象、占位 DTO 或未赋值字段当成有效输入继续传递。
- 对跨层可变 DTO、调用后赋值、字段来源不明、旧逻辑副作用，必须先标记风险。
- 任何会改变调用顺序、接口契约、远程调用、MQ 字段、Redis key、数据库结构或外部行为的方案，实施前必须确认业务意图。
- 单元测试不能只验证最终结果；本次涉及音序判定结果与 FC 调用次数，必须断言下游结果（id/needHumanReview/Gemini 调用次数）。

## 强制门禁

- 参数来源：`observed`（pitchClasses）来自 `PianoNoteSequenceFeatureExtractor.buildPitchClasses`，在 `match()` 调用前已赋值；`baseBestScore` 在 `match()` 内、调用 `bestTransposedRescue` 前由原始最佳分算出；`transposed`（含 `contiguousPhraseSimilarity`、`transpositionShift`）由 `scoreAgainstPitchClasses` 计算并在读取前已赋值。
- 赋值时机：无「调用后才赋值、下游已读取」的字段。新增门禁读取的 `transposed.contiguousPhraseSimilarity` 与 `transposed.score`、`transposed.transpositionShift` 同处一次计算，赋值早于读取。
- 占位对象：无 `new XxxDto()`/空 Map/空 JSON 占位传参；改动仅为标量阈值判断。
- 下游读取：`PianoHomeWorkVideoV2Task` 依据 `templateMatch.highConfidence` 与 `bestScore.score` 决定走「人工复核短路」还是覆盖；D002 让噪声序列 highConfidence 回到 false，下游既有分支自然命中低分人工复核；D008 挡掉远距离 D2 后让近距离 D3/D4 沧海高置信覆盖。
- 旧逻辑保持：真升半音铁血丹心移调补救（`match_shouldRescueTransposedD2TieXueDanXin`、`handleRequest_transposedD2_shouldRescueAndOverrideToD2`）必须仍命中 D2；原调 D1/D2/D3/D5 精细区分、结尾连续 E 指纹、D1/D3 纠偏、萱草花开头指纹、课程外音级拦截、假高置信 D2 拦截、低分人工复核均不变。
- 影响范围：纯内存评分逻辑改动，不改方法签名、不改 JSON 结构、无远程调用/MQ/Redis/DB/配置契约变化。
- 测试映射：见 `tasks.md` Phase 4。

## 重点代码位置

- 移调补救（本次修复核心）：`PianoNoteSequenceTemplateMatcher.bestTransposedRescue`（fc/Gemini-Api/src/main/java/com/drh/gemini/api/PianoNoteSequenceTemplateMatcher.java:309-324）
- 移调评分：`PianoNoteSequenceTemplateMatcher.scoreAgainstPitchClasses` / `contiguousPhraseSimilarity`（同文件 334-404）
- 萱草花模板与开头指纹：`D5_TEMPLATE`（86-95）、`hasXuanCaoHuaOpeningPattern`（256-276）
- 下游人工复核短路：`PianoHomeWorkVideoV2Task.isLowScoreTemplateMatch` / `isOutOfScalePitchSequence` / `buildLowScoreManualReviewResult`（fc/Gemini-Api/src/main/java/com/drh/gemini/api/PianoHomeWorkVideoV2Task.java:194-214、376-460）
- 提示词交付物：`specs/112-piano-video-transpose-rescue-and-xuancaohua-prompt/prompt-v2-revised.md`（修正后完整 V2 提示词，线上由用户更新；仓库内 demo-prompt 已还原不在本次范围）
- 真实回归产物：`specs/112-piano-video-transpose-rescue-and-xuancaohua-prompt/regression.md`、`out/real-regression-results.json`、`scripts/RealPianoRegressionRunner.java`
- 测试落点：`PianoNoteSequenceTemplateMatcherTest`、`PianoHomeWorkVideoV2TaskTest`
- 雅琪 D007 修复核心：`PianoNoteSequenceTemplateMatcher.matchYaqi` 的 `YAQI_GROUP_MIN_CONTIGUOUS` 连续短语门禁。
- 李瑶 D008 修复核心：`PianoNoteSequenceTemplateMatcher.bestTransposedRescue` 的 `TRANSPOSE_RESCUE_MAX_ABS_SHIFT` 远距离移调门禁。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
