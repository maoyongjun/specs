# 功能规格：钢琴作业识别——移调补救假阳性修复 + 萱草花提示词锚点

**功能目录**：`112-piano-video-transpose-rescue-and-xuancaohua-prompt`
**创建日期**：`2026-06-26`
**状态**：Draft
**输入**：用户提供萱草花四句音序（第一句 E5 E5 E5 G5 A5 G5 C5 D5 E5 C5 G4；第二句 A4 C5 A4 G4 C5 G4 A4 B4 C5 E5 D5 C5 D5；第三句 E5 E5 E5 G5 A5 G5 C5 D5 E5 G5 E5；第四句 A4 C5 A4 G4 C5 G4 E5 D5 A4 C5 D5 C5），要求「修改提示词和识别的代码」；另报一例非作业视频被错误识别成「铁血丹心」，要求告警（非作业）。问题视频日志关键片段：`noteSequenceText=D3 F3 F#3 F#3 C#3 F#3 B3 F#3 D#3 D#3 D3 C#3 C#3`，`engineeringDecision.recognizedDay=D2`、`title=铁血丹心`、`score=0.74`、`reason=原调匹配分低，整体移调9半音后命中D2`、`submissionType=补交作业`。

> 备注：用户文字写作「萱花草」，曲目正式名与现有代码/提示词一致为「萱草花」，本规格统一用「萱草花」。

## 背景

- 当前问题：
  1. 非作业视频（全升号噪声音序，疑似非钢琴乐器/乱弹）被工程侧移调补救误判为高置信 D2《铁血丹心》并按补交作业输出，未被「课程外音级」拦截。
  2. 萱草花完整旋律此前只在识别代码 `D5_TEMPLATE` 中维护，提示词 `demo-prompt` 的 D5/D6 段仅有简谱指纹（`3 3 3 5`），缺完整旋律锚点。
  3. D007 追加问题：雅琪（speakerId=113）低质量沧海音序 `C2 C3 G3 D5 C4 C3 F2 F2 A3 G4 C2 C2 G3` 被公共音级抬高 groupX 分数，误判为 `组X(但愿人长久)`；该类弹得差、组别不稳定的样本应转人工。
  4. D008 追加问题：李瑶体系低质量《沧海一声笑》升半音音序 `A#4 G#4 F4 D#4 C#4 A#2 F4 D#4 C#4 A#3 G#3 A#3 G#3 G#2 A#3 G#3 A#3 C#4 D#4 F4 G#4 A#4 G#4 F4 D#4 C#4 D4 D#4`，旧逻辑被 D2《铁血丹心》整体移调 6 半音的远距离硬凑分 `0.91` 抢走，误判为 D2；实际应按近距离整体升半音命中 D3/D4《沧海一声笑》。
- 当前行为：
  - `PianoNoteSequenceTemplateMatcher.match` 在原调最佳分 ≤ 0.50 时调用 `bestTransposedRescue`，对 D1/D2/D3/D5 做整体移调评分，只要某移调分 ≥ 0.70 且比原调高 ≥ 0.15 即判高置信命中。`score = 0.55*coverage + 0.30*histogram + 0.15*prefix`，不含连续短语项。对最长的 D2 铁血丹心模板，短音序极易靠 coverage 虚高凑分，使噪声被移调命中 D2。
  - 命中后 `highConfidence=true`，`PianoHomeWorkVideoV2Task.isOutOfScalePitchSequence` 因「已高置信不拦截」而放行（设计初衷是避免误伤真升降调演奏），最终输出 D2 作业。
- 目标行为：
  1. 移调补救必须额外要求「连续短语相似度（contiguousPhraseSimilarity）」达标，才认定为真实移调演奏；噪声序列因连续短语极低不再被补救，`highConfidence` 回到 false，由下游 `isLowScoreTemplateMatch`（bestScore < 0.50）短路为「非作业 + 人工复核」（id=-1、isHomeWork=否、needHumanReview=true、confidence=0.3），不再调 Gemini、不再判 D2。
  2. 真升半音铁血丹心仍能被补救命中 D2（连续短语足够高）。
  3. 提示词 `demo-prompt` 的 D5/D6 段补充萱草花完整旋律锚点（绝对音名四句）。识别代码 `D5_TEMPLATE` 经核对与给定音序完全一致，仅新增锁定测试，不改模板内容。
  4. 雅琪组别匹配除分数/gap/有效音门禁外，必须有足够连续短语支撑；低质量短音序不稳定时返回未匹配，由 V2 task 走 `id=-1` 人工介入。
  5. 移调补救只允许小范围升/降调（绝对移调距离 ≤ 2 半音）自动高置信覆盖；远距离 6/9 半音硬凑不再参与自动补救。D008 样本应被 D3/D4《沧海一声笑》整体升 1 半音候选接管，不再判 D2《铁血丹心》。
- 非目标：
  - 不改 V2 生产提示词的上游真实来源（kkhc/配置/DB），该侧需用户方同步同一萱草花锚点改动（见假设）。
  - 不改 `outOfScaleRatio` 阈值与「已高置信不拦截」的既有设计，只通过收紧移调补救让噪声不再进入高置信。
  - 不扩展雅琪曲目范围或改变组X/组Y定义；D007 仅收紧低质量样本的组别命中门禁。
  - 不禁用真实近距离移调识别；D008 仅排除远距离硬凑，保留升半音铁血丹心和升半音沧海。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 全升号噪声不再被误判铁血丹心（优先级：P1）

学员提交的并非课程作业（音序为全升号噪声/非钢琴乐器），系统应识别为「非作业」并转人工复核，而不是误判成《铁血丹心》补交作业。

**独立测试**：用日志音序 `D3 F3 F#3 F#3 C#3 F#3 B3 F#3 D#3 D#3 D3 C#3 C#3` 调 `PianoNoteSequenceTemplateMatcher.match`，断言 `highConfidence=false` 且未发生移调命中（bestScore.transpositionShift==0）。再用同音序走 `PianoHomeWorkVideoV2Task.handleRequest`（expectedDay=2），断言 `id=-1`、`needHumanReview=true`、`isHomeWork=否`、Gemini 调用 0 次。

**验收场景**：
1. **Given** 噪声音序 `D3 F3 F#3 F#3 C#3 F#3 B3 F#3 D#3 D#3 D3 C#3 C#3`，**When** 调用 `match`，**Then** 不发生移调补救命中、`highConfidence=false`、`bestTemplate` 不是因移调而来的 D2。
2. **Given** 同噪声音序，**When** 走 V2 `handleRequest`，**Then** 返回 `isHomeWork=否`、`id=-1`、`needHumanReview=true`、`confidence=0.3`，且 `caller.fileCalls=0`（不调 Gemini）。

### 用户故事 2 - 真升半音铁血丹心仍能被识别（优先级：P1，防回归）

学员真把《铁血丹心》整体升半音弹奏，工程侧仍应通过移调补救命中 D2。

**独立测试**：用既有样本 `F5 D#5 C#5 C5 A#4 F4 A#4 A#4 G#4 F4 G#4 D#4 E4 F4 F5 D#5 C#5 C5 A#4 F4 A#4 D#5 C#5 A#4 C5 C#5 D#5 E5 F5` 调 `match`，断言命中 D2 且 `transpositionShift != 0`。

**验收场景**：
1. **Given** 升半音铁血丹心样本，**When** 调用 `match`，**Then** `bestTemplate.day=D2`、`id=2`、`transpositionShift!=0`（既有测试不回归）。
2. **Given** 同样本走 V2 `handleRequest`（expectedDay=2），**Then** `id=2`、`title=铁血丹心`、`recognizedDay=D2`、evidence 含「移调」（既有测试不回归）。

### 用户故事 3 - 萱草花旋律锚点与模板核对（优先级：P2）

提示词需带萱草花完整旋律锚点（绝对音名），识别代码模板需与给定音序一致。

**独立测试**：静态检查 `demo-prompt` D5/D6 段含四句绝对音名锚点；新增 `match` 测试用给定四句绝对音名音序断言高置信命中 D5。

**验收场景**：
1. **Given** 给定萱草花四句绝对音名连成的音序，**When** 调用 `match`，**Then** `highConfidence=true`、`bestTemplate.day=D5`、`id=5`、`dayMin=5`、`dayMax=6`。
2. **Given** 读取 `demo-prompt`，**When** 查看 D5/D6 段，**Then** 含四句绝对音名旋律锚点。

### 用户故事 4 - 雅琪低质量沧海不误判但愿人长久（优先级：P1，D007 追加）

雅琪学员提交《沧海一声笑》但弹得差、音序只剩公共音级时，系统不应硬判为 `组X(但愿人长久)`，应转人工介入。

**独立测试**：用日志音序 `C2 C3 G3 D5 C4 C3 F2 F2 A3 G4 C2 C2 G3` 调 `matchYaqi`，断言未匹配；再用同音序走 `PianoHomeWorkVideoV2Task.handleRequest`（speakerId=113），断言 `id=-1`、`isHomeWork=否`、`needHumanReview=true`、Gemini 调用 0 次。

**验收场景**：
1. **Given** 低质量雅琪沧海音序，**When** 调用 `matchYaqi`，**Then** `recognizedGroup=未匹配`。
2. **Given** 同音序走 V2 `handleRequest` 且 `speakerId=113`，**Then** 返回人工介入结果 `id=-1`，且不调用 Gemini 硬猜。

### 用户故事 5 - 低质量升半音沧海不被远距离移调抢成铁血（优先级：P1，D008 追加）

李瑶学员提交《沧海一声笑》但弹得不好、音序带大量升号时，系统不应被 D2《铁血丹心》远距离移调 6 半音硬凑抢走；应按更合理的近距离整体升半音命中 D3/D4《沧海一声笑》。

**独立测试**：用日志音序 `A#4 G#4 F4 D#4 C#4 A#2 F4 D#4 C#4 A#3 G#3 A#3 G#3 G#2 A#3 G#3 A#3 C#4 D#4 F4 G#4 A#4 G#4 F4 D#4 C#4 D4 D#4` 调 `match`，断言 `highConfidence=true`、`bestTemplate.day=D3`、`title=沧海一声笑`、`transpositionShift=1`。再用同音序走 `PianoHomeWorkVideoV2Task.handleRequest`（expectedDay=4），即使 Gemini 返回 D2，也断言最终工程侧覆盖为 `id=4`、`title=沧海一声笑`、`recognizedDay=D4`、`submissionType=今日作业`。

**验收场景**：
1. **Given** D008 线上日志音序，**When** 调用 `match`，**Then** 远距离 6 半音 D2 不参与自动补救，近距离 1 半音 D3/D4 沧海胜出。
2. **Given** 同音序走 V2 `handleRequest` 且 `expectedDay=D4`，**Then** 返回 `id=4`、`title=沧海一声笑`、`recognizedDay=D4`，不再输出 D2《铁血丹心》。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `observed`：来源 `PianoNoteSequenceFeatureExtractor.buildPitchClasses(notes)`；赋值时机 调用 `match` 前；下游读取 `match`/`bestTransposedScore`/`scoreAgainstPitchClasses`。
  - `baseBestScore`：来源 `match()` 内原始排序后的 `best.score.score`；赋值时机 调用 `bestTransposedRescue` 前。
  - `transposed`（Score，含 `contiguousPhraseSimilarity`/`score`/`transpositionShift`）：来源 `bestTransposedScore`→`scoreAgainstPitchClasses`，三字段同次计算；赋值早于本次新增门禁读取。
  - `TRANSPOSE_RESCUE_MAX_ABS_SHIFT`：常量，限定自动补救可接受的最小绝对移调距离（`min(shift, 12-shift)`）不超过 2 半音。
- 下游读取字段清单：
  - `bestTransposedRescue` 读取 `transposed.transpositionShift`、`transposed.score`、`transposed.contiguousPhraseSimilarity`，D008 新增读取移调距离门禁。
  - `PianoHomeWorkVideoV2Task.analyzeVideo` 读取 `templateMatch.highConfidence`、`templateMatch.bestScore.score`、`isOutOfScalePitchSequence`（依赖 highConfidence）。
- 空对象 / 占位对象风险：否；改动仅在已构造的 `Score` 上增加一个标量阈值比较，不新建/传递占位对象。
- 调用顺序风险：否；不改调用顺序，不引入异步/调用后赋值。新增读取字段与既有读取字段同源同时机。
- 旧逻辑保持：
  - 真升半音铁血丹心移调补救命中 D2（两条既有测试）。
  - 真升半音沧海样本可被近距离移调补救命中 D3/D4（D008 新增测试）。
  - 原调 D1/D2/D3/D5 精细区分；结尾连续 E 指纹优先 D2；D2→D1 / D2→D3 纠偏；萱草花开头指纹优先 D5；课程外音级拦截与「已高置信不拦截」语义；假高置信 D2 拦截；低分（<0.50）人工复核短路。
  - `toTemplateScoresJson`/`toEngineeringDecisionJson` 输出结构不变。
- 需要用户确认的设计选择：
  - 提示词落点改 `demo-prompt`、锚点用绝对音名、告警走现有「非作业+人工复核」路径——均已与用户确认（见 D001）。

## 边界情况

- 噪声序列原调最佳分本就 < 0.50：补救被收紧后不命中 → 命中下游低分人工复核（已覆盖）。
- 真移调演奏但音序较短：若连续短语达标仍可补救；若过短导致连续短语不足，则保守转人工（可接受，安全侧）。
- 远距离整体移调（绝对距离 >2 半音）：不作为自动补救；即使分数高，也视为曲目间硬凑风险，交给其他近距离候选或后续人工/模型链路。
- 连续短语阈值取值：以「真升半音铁血（连续短语高）通过、噪声（连续短语极低）不通过」为准，实现阶段实测两端数值后定阈并记录。
- 提示词为单物理行、内含字面 `\n` 转义：编辑须沿用同格式，避免破坏既有结构。

## 需求 *(必填)*

### 功能需求

- **FR-001**：`bestTransposedRescue` MUST 在原有「移调命中、分≥HIGH_CONFIDENCE_MIN_SCORE、比原调高≥TRANSPOSE_RESCUE_MIN_DELTA」基础上，额外要求 `transposed.contiguousPhraseSimilarity >= TRANSPOSE_RESCUE_MIN_CONTIGUOUS`，否则不视为命中。
- **FR-002**：对噪声音序 `D3 F3 F#3 F#3 C#3 F#3 B3 F#3 D#3 D#3 D3 C#3 C#3`，`match` MUST 返回 `highConfidence=false` 且不产生移调命中；V2 `handleRequest` MUST 输出 `id=-1`、`isHomeWork=否`、`needHumanReview=true` 且不调用 Gemini。
- **FR-003**：系统 MUST NOT 改变真升半音铁血丹心的移调补救命中结果（仍命中 D2、transpositionShift!=0）。
- **FR-004**：系统 MUST NOT 改变方法签名、JSON 输出结构、`outOfScaleRatio` 阈值、「已高置信不拦截」语义及其他既有分支。
- **FR-005**：`demo-prompt` 的 D5/D6 段 MUST 补充萱草花四句绝对音名旋律锚点；`D5_TEMPLATE` 保持与给定四句音序一致（核对，不改内容）。
- **FR-006**：单元测试 MUST 覆盖：噪声不命中（matcher 级）、噪声转人工（task 级，断言 id/needHumanReview/Gemini 调用次数）、真升半音不回归、萱草花绝对音名锁定命中 D5。
- **FR-007**：雅琪 `matchYaqi` MUST 要求最佳组别 `contiguousPhraseSimilarity >= YAQI_GROUP_MIN_CONTIGUOUS`；对音序 `C2 C3 G3 D5 C4 C3 F2 F2 A3 G4 C2 C2 G3` MUST 返回未匹配，V2 task MUST 输出 `id=-1` 且不调用 Gemini。
- **FR-008**：`bestTransposedRescue` MUST 要求 `min(transpositionShift, 12-transpositionShift) <= TRANSPOSE_RESCUE_MAX_ABS_SHIFT`；对 D008 音序 MUST 阻断 6 半音 D2 远距离补救，并允许 1 半音 D3/D4《沧海一声笑》候选胜出。

## 成功标准 *(必填)*

- **SC-001**：噪声样本经 V2 链路输出非作业人工复核（id=-1、needHumanReview=true），不再输出 D2 铁血丹心。
- **SC-002**：真升半音铁血丹心既有两条测试仍通过（命中 D2）。
- **SC-003**：`PianoNoteSequenceTemplateMatcherTest` 与 `PianoHomeWorkVideoV2TaskTest` 全量通过，无回归。
- **SC-004**：`demo-prompt` D5/D6 段含萱草花四句绝对音名锚点；萱草花绝对音名锁定测试高置信命中 D5。
- **SC-005**：雅琪低质量沧海误判组X样本转人工介入，且既有雅琪组X、组Y、低音混入沧海正例不回归。
- **SC-006**：D008 低质量升半音沧海样本最终输出 D4《沧海一声笑》，不再输出 D2《铁血丹心》。

## 假设

- V2 生产实际提示词由上游 kkhc/配置/DB 维护，不在本仓库；本次仅改仓库内 `demo-prompt`，萱草花锚点需用户方在上游同步同一改动。（用户已确认此口径）
- 「告警」即现有「非作业 + 人工复核」JSON 输出，本仓库无独立告警/通知通道。（用户已确认）
- 连续短语阈值 `TRANSPOSE_RESCUE_MIN_CONTIGUOUS` 初定 0.20，最终以实测真升半音/噪声两端数值确定并在 D002 记录；若被推翻追加 Dxxx。
- 自动移调补救最大绝对移调距离 `TRANSPOSE_RESCUE_MAX_ABS_SHIFT=2`；覆盖常见半音/全音偏移，远距离转调不在工程侧自动高置信覆盖范围内。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已就三处口径与用户确认：提示词落点改 `demo-prompt` 并标注上游需同步；萱草花锚点用绝对音名；告警走现有「非作业+人工复核」路径。
- 已完成历史问题防漏分析和强制门禁检查。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：
  1. `PianoNoteSequenceTemplateMatcher` 新增常量 `TRANSPOSE_RESCUE_MIN_CONTIGUOUS=0.20`，在 `bestTransposedRescue` 命中条件加入 `transposed.contiguousPhraseSimilarity >= TRANSPOSE_RESCUE_MIN_CONTIGUOUS`；同步更新方法注释。
  2. `demo-prompt` 的 D5 段补萱草花四句绝对音名旋律锚点，D6 段标注「旋律锚点见 D5」。
  3. 新增测试：matcher 级 `match_shouldNotRescueOutOfScaleNoiseToTransposedD2`、`match_shouldHighConfidenceMatchD5XuanCaoHuaAbsoluteSequence`；task 级 `handleRequest_transposedOutOfScaleNoise_shouldShortCircuitToManualReview`（断言 id=-1/isHomeWork=否/needHumanReview=true/fileCalls=0）。
- 影响范围：纯内存评分逻辑 + 提示词资源 + 测试；未改方法签名、JSON 结构、`outOfScaleRatio` 阈值、远程调用/MQ/Redis/DB/配置契约。
- 测试命令：`mvn -f fc/pom.xml -pl Gemini-Api test -Dtest='PianoNoteSequenceTemplateMatcherTest,PianoHomeWorkVideoV2TaskTest'`
- 测试结果：本次目标行为全部通过——3 条新测试通过；真升半音回归保护 `match_shouldRescueTransposedD2TieXueDanXin`、`handleRequest_transposedD2_shouldRescueAndOverrideToD2` 通过；`PianoHomeWorkVideoV2TaskTest` 全通过。阈值 0.20 经实测有效分隔（真升半音连续短语足够通过；课程外音级噪声连续短语过低被挡）。
- 仅剩 2 条失败，均为既有回归（见 D003），与本次改动无关。
- 自检结论：参数来源/赋值时机正常，无占位对象、无调用后赋值；旧逻辑（真升半音补救、其余分支）保持。剩余风险=D003 两条既有失败待用户定夺。

### D003 - 纠正/发现记录（D5 过度贪婪既有回归）

- 触发原因：运行全量测试发现 `PianoNoteSequenceTemplateMatcherTest` 有 2 条失败：
  - `match_shouldHighConfidenceMatchNoisyD2Sequence`（`E2 G2 C4 D2 G2 G2 G2 G2 C4 D2 G2 G2 A2`）期望 D2，实际 D5。
  - `match_shouldCorrectD2ToD3WhenChorusHistogramAndPhraseStronger`（`A3 G3 C4 A2 C4 A3 G3 B2 G3 G3 C4 G4 G4 B2`）期望 D3，实际 D5。
- 复现确认：临时撤掉本次新增的连续短语门禁后，这 2 条仍失败（实际 D5），证明与本次「收紧移调补救」改动无关，是更早引入 D5（萱草花）模板/打分时埋下的回归——D5 的音级集合（E/G/A/C/D/B）较宽，对「偏 G 的稀疏 D2 噪声样本」「含 B2 左手低音的沧海 D3 样本」histogram 偏高把它们抢成 D5。
- 处置：用户确认「本次一并修复 D5 过度贪婪」。修复方案见 D004。
- 文档同步：本 D003 已记录；tasks D002 已同步。
- 验证结果：基线复现已确认；修复见 D004。

### D004 - 纠正记录（提示词落点改为 spec-kit + D5 过度贪婪修复）

- 触发原因：
  1. 用户提供了 V2 任务实际使用的生产提示词原文，并要求「在这个基础上修改、放进 spec-kit，由用户更新到线上」。该提示词与仓库内 demo-prompt（V1 新供应商测试用）不是同一份。
  2. 用户确认 D5 过度贪婪纳入本次范围。
- 修正内容：
  1. 提示词落点：撤销先前对 `demo-prompt` 的改动（还原原状，避免改 V1 无关产物）；改为在本规格目录新增 [prompt-v2-revised.md](../prompt-v2-revised.md) 给出修正后的完整 V2 提示词。关键修正：D5/D6 段音序由旧 Bb 转调写法（`D4 D4 D4 F4 …`）改为权威 C 大调四句绝对音名（与代码 `D5_TEMPLATE` 一致）；D5「关键特征」由错误的「含 Bb/A#、不含 E/B」改为「不含 4(Fa)、含 7(Si)」；同步修正「D1 vs D5」规则里引用旧 Bb 写法的描述。其余段落逐字保留。线上提示词由用户方更新。
  2. D5 过度贪婪修复（`PianoNoteSequenceTemplateMatcher.match`）：D5 仅在「出现萱草花开头指纹（连续三个 Mi 上行小三度到 Sol，3 3 3 5）」或「D5 coverage≥0.95 且 contiguousPhraseSimilarity≥D5_EXACT_MIN_CONTIGUOUS(0.30)」时才加入候选竞争；否则不让 D5 仅凭音级集合（含 Si/B）在 48 音长模板里 coverage 虚高，把「偏 G 的稀疏铁血噪声」「含 B 低音的沧海」误抢为 D5。d5Score 仍照常计算并输出到 templateScores JSON，仅不参与 best 竞争。
- 影响/旧逻辑保持：所有既有 D5 命中用例均带开头指纹（`D4 D4 D4 F4`、`E5 E5 E4 G3`、`E5 E5 E5 G5`、`D4 D4 D4 F4`(task)），不受影响；移调补救仍独立遍历含 D5 的模板集。新增风险：真实整段萱草花若起手被采集污染导致既无指纹、连续短语又不足，则工程侧不再高置信判 D5，降级交 Gemini（提示词已带 C 大调旋律）/人工——属安全侧降级。
- 文档同步：spec D004、tasks D002 已更新；新增 prompt-v2-revised.md。
- 验证结果：`mvn -f fc/pom.xml -pl Gemini-Api test -Dtest='PianoNoteSequenceTemplateMatcherTest,PianoHomeWorkVideoV2TaskTest'` → Tests run: 60, Failures: 0, Errors: 0, BUILD SUCCESS（两条既有失败 `match_shouldHighConfidenceMatchNoisyD2Sequence`/`match_shouldCorrectD2ToD3WhenChorusHistogramAndPhraseStronger` 已转绿，且未回归任何 D5/真升半音用例）。

### D005 - 真实调用回归记录（VideoToNoteSeq + 工程侧判定）

- 触发原因：用户提供 `FcOssFFmpeg-3278/VideoToNoteSeq` 调用方式与 Redis 参数，要求对 V1-1、V1-2、V2-1、V3-1、V5-1 及 3 条线上视频做真实调用回归，并把回归文件记录到文档。
- 执行内容：
  1. 新增 `regression.md` D005 实测结果，并新增 runner `scripts/RealPianoRegressionRunner.java`；runner 真实调用 `FcOssFFmpeg-3278/VideoToNoteSeq`，通过 Redis 取回音序，再用当前 V2 工程侧代码计算 `templateScores`、`engineeringDecision`、低分/课程外音级/假高置信 D2 短路和作业关系。
  2. 结果明细写入 `out/real-regression-results.json`。
  3. 本次未调用 Gemini；高置信工程侧覆盖与人工复核短路为确定性结论，`NEEDS_GEMINI` 样本只记录工程候选。
- 实测结论：
  - `V1-1_D4`、`V1-2_D4` 均高置信识别为 D1《四季歌》/补交作业，通过。
  - `V3-1_D4` 工程候选为 D4《沧海一声笑》/今日作业，但未高置信（`NEEDS_GEMINI`），工程候选满足用户期望。
  - `V5-1_D2` 高置信识别为 D5《萱草花》/提前提交，通过；`V1-1_D2` 高置信识别为 D1《四季歌》/补交作业，通过。
  - `a8bdb7b2_D4` 真实音序复现为 `D3 F3 F#3 F#3 C#3 F#3 B3 F#3 D#3 D#3 D3 C#3 C#3`，低分人工复核 `id=-1`，通过。
  - `ec62a262_D4` 因课程外音级占比 0.37 且非高置信，走课程外音级人工复核 `id=-1`，通过。
  - `e57f1dda_D4` 高置信纠偏为 D4《沧海一声笑》/今日作业，满足「沧海或 -1」期望，通过。
  - `V2-1_D4` 用户未给明确期望，仅记录实际：音序 `E2 G2 C4 D2 G2 G2 G2 G2 C4 D2 G2 G2 A2` 触发假高置信 D2 防护，实际 `id=-1`。
  - `V5-1_D4` 识别 D5《萱草花》正确，现有代码按 D5>D4 判定为「提前提交」。
- 自检结论：本次新增脚本和输出文件不改生产逻辑；真实 FC/Redis 调用成功取回 10/10 音序；D006 修正用户口误后，明确期望断言 9 条全部通过。

### D006 - 口径纠正记录（V5-1 在 D4 场景为未来作业）

- 触发原因：用户确认 `V5-1.mp4` 在 D4 场景下识别为 D5《萱草花》后，作业类型应为「未来作业/提前提交」；前文「当日作业」是口误。
- 修正内容：
  1. `regression.md` 将 `V5-1_D4` 期望从「D5/当日作业」修正为「D5/提前提交（未来作业）」。
  2. `scripts/RealPianoRegressionRunner.java` 将 `V5-1_D4` 的断言期望同步改为 `acceptedSubmissionTypes=["提前提交"]`。
  3. `out/real-regression-results.json` 同步修正 `V5-1_D4` 的 `userExpected`、`expectation` 和 `verdict`。
- 修正后结论：D005 真实回归中 9 条有明确期望的断言全部通过；`V2-1_D4` 仍为未指定明确期望、仅记录实际。
- 自检结论：本次仅修正文档和回归断言口径，不改生产逻辑。

### D007 - 纠正记录（雅琪低质量沧海误判但愿人长久）

- 触发原因：用户提供线上视频 `870dce3f-e477-445a-b84c-fb2f3172d6dc.mp4` 及日志。该视频实际应按《沧海一声笑》方向理解，但学员弹得差，音序 `C2 C3 G3 D5 C4 C3 F2 F2 A3 G4 C2 C2 G3` 被雅琪组别匹配误判为 `组X(但愿人长久)`，日志中 `groupXScore=0.8`、`groupYScore=0.61`、`scoreGap=0.19`，最终走补交作业；用户要求这类不稳定样本应 `id=-1` 人工介入告警。
- 根因：`matchYaqi` 只用总分、gap、有效音数和“两组都高且 gap 小”判断是否匹配；短/差音序中大量 C/G/F/A/D 公共音级能把 groupX coverage、histogram、prefix 抬高，但连续短语相似度只有 0.30，不足以证明是真正的但愿人长久旋律。
- 修复内容：
  1. `PianoNoteSequenceTemplateMatcher` 新增 `YAQI_GROUP_MIN_CONTIGUOUS=0.35`，雅琪组别命中除既有 score/gap/有效音门禁外，必须满足 `bestScore.contiguousPhraseSimilarity >= 0.35`。
  2. 新增 matcher 测试 `matchYaqi_shouldReturnUnmatchedForPoorCanghaiMisclassifiedAsGroupX`，断言该音序返回未匹配。
  3. 新增 task 测试 `handleRequest_yaqiSpeakerPoorCanghaiMisclassifiedAsGroupX_shouldShortCircuitToManualReview`，断言 speakerId=113 时结果为 `id=-1`、`isHomeWork=否`、`needHumanReview=true`、`caller.fileCalls=0`。
- 阈值依据：坏样本 best/groupX 连续短语为 0.30，被 0.35 挡下；既有正例不受影响：组X 完整但愿人长久约 0.90，组Y 完整沧海约 1.00，带低音混入的沧海样本约 0.53。
- 验证结果：`mvn -f fc/pom.xml -pl Gemini-Api test -Dtest='PianoNoteSequenceTemplateMatcherTest,PianoHomeWorkVideoV2TaskTest'` → Tests run: 62, Failures: 0, Errors: 0, BUILD SUCCESS。
- 自检结论：仅收紧雅琪组别命中条件；未改李瑶 D1/D2/D3/D5 逻辑、JSON 输出契约、FC/Redis/Gemini 调用链。旧雅琪组X/组Y正例、低音混入沧海正例、既有未匹配样本均通过。

### D008 - 纠正记录（低质量升半音沧海误判铁血丹心）

- 触发原因：用户提供线上视频 `a4b39ceb-e6d6-4a37-a61f-3a1dffeff09c.mp4` 及日志。该视频应为《沧海一声笑》，但学员弹得不好；旧逻辑在原调几乎不匹配时，被 D2《铁血丹心》整体移调 6 半音候选 `score=0.91` 抢走，输出 `id=2`、`title=铁血丹心`、`submissionType=补交作业`。
- 根因：D002 只加了连续短语门禁，仍允许任意 1..11 半音移调。D008 音序既能远距离 6 半音硬凑 D2，也能近距离 1 半音命中 D3/D4 沧海；旧逻辑按分数最高选择 D2，缺少「远距离移调不自动高置信」门禁。
- 修复内容：
  1. `PianoNoteSequenceTemplateMatcher` 新增 `TRANSPOSE_RESCUE_MAX_ABS_SHIFT=2`，`bestTransposedRescue` 除 score/gap/contiguous 外，还要求 `min(shift, 12-shift) <= 2`。
  2. 新增 matcher 测试 `match_shouldPreferNearTransposedCanghaiOverTritoneD2Rescue`，断言该音序高置信命中 D3《沧海一声笑》且 `transpositionShift=1`。
  3. 新增 task 测试 `handleRequest_poorCanghaiTritoneRescueToD2_shouldOverrideToCanghai`，断言即使 Gemini 返回 D2，工程侧最终覆盖为 `id=4`、`title=沧海一声笑`、`recognizedDay=D4`、`submissionType=今日作业`。
- 阈值依据：真实升半音铁血丹心 `shift=1` 保留；D008 近距离沧海 `shift=1` 保留；旧误判 D2 `shift=6` 被挡；早期噪声 `shift=9`（绝对距离 3）也被挡，作为 D002 连续短语门禁之外的第二层保护。
- 验证结果：`mvn -f fc/pom.xml -pl Gemini-Api test -Dtest='PianoNoteSequenceTemplateMatcherTest,PianoHomeWorkVideoV2TaskTest'` → Tests run: 64, Failures: 0, Errors: 0, BUILD SUCCESS。
- 自检结论：仅收紧自动移调补救的可接受幅度；未改方法签名、JSON 输出结构、FC/Redis/Gemini 调用链或 `outOfScaleRatio` 语义。真升半音 D2、D008 升半音沧海、D007 雅琪人工介入、D005/D006 相关回归保护均通过目标测试覆盖。
