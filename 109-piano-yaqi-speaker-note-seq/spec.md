# 功能规格：钢琴作业视频按 speakerId 分流（雅琪 113 独立提示词与识别逻辑）

**功能目录**：`109-piano-yaqi-speaker-note-seq`  
**创建日期**：`2026-06-23`  
**状态**：Draft（待用户确认进入实施）  
**输入**：用户需求——「增加另外一个 speakerId 的音序识别，这个 speakerId 使用单独的提示词以及单独的识别逻辑」。明确口径（多轮 AskUserQuestion + 文字确认）：
- speakerId=110（李瑶）使用原提示词 env `piano_video_prompt`，识别逻辑保持现状（四季歌/铁血丹心/沧海一声笑 D1/D2/D3）。
- speakerId=113（雅琪）使用 env `piano_video_prompt_speaker_113`，使用单独的曲目模板与识别逻辑。
- 雅琪课程共 4 天 4 首（D5/D6 暂不做）：**D1/D2/D3=但愿人长久（上/中/下），右手旋律基本相同，仅和弦深浅不同（组 X）；D4=沧海一声笑·有和弦，旋律不同（组 Y）**。
- 音序（声音）层面**不细分 D1/D2/D3**，只用右手旋律判定属于「组 X（D1-D3 同首）」还是「组 Y（D4）」；具体单双手细分到 D1/D2/D3 交给 Gemini 看视频判断。
- 作业天数：若识别为组 X/组 Y，按推荐天数（expectedDay）与识别曲目组算 `submissionType`；D1/D2/D3 互相视为今日作业，D4 进度交 D1-D3 判补交、D1-D3 进度交 D4 判提前提交。
- `submissionType` 由**工程侧直接算好注入**；曲目组也注入提示词；雅琪场景工程侧**仅注入证据、不覆盖** Gemini 最终分类字段（对应「仅注入特征交 Gemini」）。
- 提示词文件位于 `C:\Users\EDY\Downloads\视频理解提示词V1_3.txt`（已是雅琪课程体系），按本规格做必要调整后作为 `piano_video_prompt_speaker_113` 内容。

## 背景

- 当前问题：钢琴作业视频识别整条链路只认 `skuId == SKU_PIANO`，内部仅按 `logicalDay` 分类，提示词固定取 env `piano_video_prompt`，识别固定用 `PianoNoteSequenceTemplateMatcher` 内硬编码的四季歌/铁血/沧海 D1/D2/D3 模板——这套实际对应李瑶（speakerId=110）的曲库。现要新增雅琪（speakerId=113）的另一套课程，需要独立提示词与独立识别逻辑，且 **speakerId 当前完全没有透传进钢琴识别链路**。
- 当前行为：
  - `SopReply.resolveVideoRecognizeService(request, userMsg)` 按 `skuId==SKU_PIANO` 选 `PianoVideoHomeWorkHandleServiceImpl`（[SopReply.java:926](../../fc/sop-reply/src/main/java/com/drh/homework/service/SopReply.java)）。
  - `PianoVideoHomeWorkHandleServiceImpl.resolvePianoVideoPrompt` 取 env `piano_video_prompt`，按 `logicalDay` 替换 `D%s`；`appendRecognitionContext` 仅透传 `expectedDay/logicalDay/isGroup/recentPrivateChatMessages` 进 `taskObj`，**无 speakerId**；FC 异步提交 `service_sys/Piano-homework-video`。
  - Gemini-Api `PianoHomeWorkVideoV2Task` 取音序 → `PianoNoteSequenceFeatureExtractor.extract` → `PianoNoteSequenceTemplateMatcher.match(observed, monoDescending)`（静态、硬编码 D1/D2/D3，且 endingRepeatedE / D2 长模板纠偏 / monoDescending 抑制等高置信规则是为这三首特调）→ 高置信时**覆盖**课程分类字段 → 注入 `${audioseq}`/`${engineeringContext}` → 调 Gemini。
  - `HomeWorkMessageDto` 无 `speakerId` 字段；`taskObj` 无 `speakerId`。
- 目标行为：
  - 打通 speakerId 透传：`HomeWorkMessageDto` 增 `speakerId`，SopReply 侧填充，`taskObj` 透传，`PianoHomeWorkVideoV2Task` 读取。
  - 提示词按 speakerId 选 env：110/空/未知 → `piano_video_prompt`（不回归）；其它 speakerId → `piano_video_prompt_speaker_<id>`（雅琪即 `piano_video_prompt_speaker_113`）；仍按 `logicalDay` 替换 `D%s`。
  - 识别逻辑按 speakerId 分流：110/默认 → 现有 `match` 与高置信覆盖**完全不变**；113 → 走雅琪独立分支：用「组 X=但愿人长久 / 组 Y=沧海一声笑·有和弦」两条右手 pitch class 模板判定曲目组，算 `submissionType`，注入证据，**不覆盖** Gemini 分类字段。
  - 调整 `视频理解提示词V1_3.txt` 接收工程侧注入的「曲目组 + submissionType」，并写明「组内单双手细分由 Gemini 判」。
- 非目标：
  - 不改 110（李瑶）现有提示词、模板、高置信覆盖、缓存、锁、三模式回退、脱敏等任何行为。
  - 不改 `VideoToNoteSeq`（Python）——音序仍是单音右手提取，不做和弦/低频/复音检测（已论证：组 X 与组 Y 旋律差异足以用右手区分）。
  - 不改 FC 服务名/函数名（`service_sys/Piano-homework-video`、Gemini 代理配置）、不改 MQ、不改数据库、不改 OTS 表。
  - 不做雅琪 D5/D6（暂未提供曲目）。
  - 雅琪场景工程侧不硬判最终 `id/recognizedDay/title`（仅注入证据，交 Gemini）。

## 用户场景与测试 *(必填)*

### 用户故事 1 - speakerId 透传打通（优先级：P1）

作为维护者，我希望钢琴识别链路把 speakerId 从 SopReply 一路透传到 Gemini-Api，使下游能据此选提示词与识别逻辑。

**独立测试**：构造带 speakerId 的 `userMsg`/`HomeWorkMessageDto`，断言 `appendRecognitionContext` 写出的 `taskObj.speakerId` 正确；构造带 `speakerId` 的 request，断言 `PianoHomeWorkVideoV2Task` 解析到的 speakerId 正确。

**验收场景**：
1. **Given** `userMsg.speakerId=113`，**When** SopReply 构建 `HomeWorkMessageDto` 并触发钢琴识别，**Then** `HomeWorkMessageDto.speakerId=113`，`taskObj.speakerId=113`。
2. **Given** 无法解析出 speakerId（空/异常），**When** 触发识别，**Then** `taskObj` 不写 speakerId 或写 null，下游按「默认/110」路径处理（不回归）。

### 用户故事 2 - 提示词按 speakerId 选 env（优先级：P1）

作为业务方，我希望李瑶用原提示词、雅琪用专属提示词。

**独立测试**：注入可控的 env 读取器，断言 speakerId=110/空 取 `piano_video_prompt`、speakerId=113 取 `piano_video_prompt_speaker_113`，且都按 `logicalDay` 替换 `D%s`。

**验收场景**：
1. **Given** `speakerId=110`、`logicalDay=2`，**When** `resolvePianoVideoPrompt`，**Then** 取 `piano_video_prompt` 并把 `D%s`→`D2`。
2. **Given** `speakerId=113`、`logicalDay=4`，**When** `resolvePianoVideoPrompt`，**Then** 取 `piano_video_prompt_speaker_113` 并把 `D%s`→`D4`。
3. **Given** `speakerId=null`，**When** `resolvePianoVideoPrompt`，**Then** 取 `piano_video_prompt`（与现状一致）。
4. **Given** `speakerId=113` 但 `piano_video_prompt_speaker_113` 未配置（env 缺失），**When** `resolvePianoVideoPrompt`，**Then** 按既有空提示词口径处理（不抛新异常、不污染 110 提示词）。

### 用户故事 3 - 雅琪曲目组识别与作业类型（优先级：P1）

作为业务方，我希望雅琪视频先用右手音序判定属于组 X（但愿人长久 D1-D3）还是组 Y（沧海一声笑 D4），按推荐天数算出 `submissionType` 注入，再交 Gemini 看单双手细分到 D1/D2/D3。

**独立测试**：用组 X / 组 Y 的右手 pitch class 序列驱动雅琪匹配分支，断言识别到的曲目组、注入 `engineeringContext` 中的 `recognizedGroup` 与 `submissionType`，并断言 Gemini 收到的 prompt 含这些证据、视频仍被传给 Gemini、且工程侧未覆盖 Gemini 分类字段。

**验收场景**（组 X={D1,D2,D3}、组 Y={D4}）：
1. **Given** `speakerId=113`、`expectedDay=D2`、右手音序匹配组 X，**When** 识别，**Then** `recognizedGroup=组X(但愿人长久)`、`submissionType=今日作业`（D1/D2/D3 互为今日）。
2. **Given** `speakerId=113`、`expectedDay=D4`、右手音序匹配组 X，**When** 识别，**Then** `submissionType=补交作业`。
3. **Given** `speakerId=113`、`expectedDay=D1`、右手音序匹配组 Y，**When** 识别，**Then** `submissionType=提前提交`。
4. **Given** `speakerId=113`、`expectedDay=D4`、右手音序匹配组 Y，**When** 识别，**Then** `submissionType=今日作业`。
5. **Given** `speakerId=113`、右手音序两组都不匹配（低分），**When** 识别，**Then** `recognizedGroup=未匹配`、不强判 `submissionType`（标未知），交 Gemini 兜底（提示词 Step 4 可输出 `id=-1`）。
6. **Given** 任一雅琪场景，**When** 识别，**Then** 工程侧不覆盖 Gemini 返回的 `id/recognizedDay/title`（仅注入证据）。

### 用户故事 4 - 李瑶（110）不回归（优先级：P1）

作为维护者，我希望本次只为 113 新增分支，110 的提示词、模板、高置信覆盖、缓存、锁、三模式回退、脱敏全部不变。

**独立测试**：现有 `PianoHomeWorkVideoV2TaskTest`、`PianoNoteSequenceTemplateMatcher` 相关单测在新增 speakerId 分支后全部通过；针对 speakerId=110/空的用例断言走原 `match` 与原覆盖逻辑。

**验收场景**：
1. **Given** `speakerId=110` 或空，**When** 识别，**Then** 调用现有 `match(observed, monoDescending)`、保留高置信覆盖与全部既有行为。
2. **Given** 现有 110 的 D1/D2/D3 回归样本，**When** 识别，**Then** 结果与改造前一致。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `speakerId`（**新增**）：来源 = `userMsg.getSpeakerId()`（`WebChatVoiceDto.speakerId`），或 `SopReply.resolveSpeakerId(userMsg)`（CampInfo via camp_date_id）；赋值时机 = `SopReply.resolveHomeworkMessage` 构建 `HomeWorkMessageDto` 时；下游读取 = `appendRecognitionContext` 写 `taskObj.speakerId`，`PianoHomeWorkVideoV2Task` 从 request 读取。**必须在 FC 异步提交前已写入 taskObj**。
  - `promptEnvName`（**新增**）：来源 = 按 `speakerId` 现算（110/空 → `piano_video_prompt`，其它 → `piano_video_prompt_speaker_<id>`）；赋值时机 = `resolvePianoVideoPrompt` 内；下游读取 = `System.getenv(promptEnvName)`。
  - `recognizedGroup`（雅琪，**新增**）：来源 = 当前层用 `PianoNoteSequenceTemplateMatcher` 雅琪分支对右手 pitch class 现算；赋值时机 = Gemini 调用前；下游读取 = `engineeringContext` 注入、`submissionType` 计算。
  - `submissionType`（雅琪，**新增按组算**）：来源 = 当前层基于 `recognizedGroup` 的天集合与 `expectedDay` 现算（组 X={1,2,3}、组 Y={4}）；赋值时机 = 注入前；下游读取 = `engineeringContext` 注入。沿用现有取值「今日作业/补交作业/提前提交/未知」。
  - `expectedDay`：来源不变（request `expectedDay`/`logicalDay`，[PianoHomeWorkVideoV2Task.java:338](../../fc/Gemini-Api/src/main/java/com/drh/gemini/api/PianoHomeWorkVideoV2Task.java)）。
  - 雅琪模板（**新增常量**）：组 X 但愿人长久右手、组 Y 沧海一声笑·有和弦右手，音名序列文本来源 = `视频理解提示词V1_3.txt` 与用户确认的右手转写，编译期常量。
- 下游读取字段清单：
  - `appendRecognitionContext` 读 `homeWorkMessageDto.speakerId` 写 `taskObj.speakerId`。
  - `resolvePianoVideoPrompt` 读 `homeWorkMessageDto.speakerId`、`logicalDay`。
  - `PianoHomeWorkVideoV2Task` 读 request `speakerId`、`expectedDay`、`prompt`、`file_url`；雅琪分支读 matcher 输出 `recognizedGroup`、模板分数。
  - 雅琪匹配分支读 `extractResult` 的右手 `pitchClasses`、`validNoteCount`。
- 空对象 / 占位对象风险：
  - 不构造 `new XxxDto()` 占位下传。`taskObj.speakerId` 仅在解析到有效 speakerId 时写入；解析不到则不写（下游按默认路径），不写 0/占位值伪装。
  - 雅琪两组都不匹配时 `recognizedGroup=未匹配`、`submissionType=未知`，不伪造曲目组或作业类型。
- 调用顺序风险：
  - 存在严格时序：`speakerId` 必须在 `appendRecognitionContext`/FC 提交前写入 → `PianoHomeWorkVideoV2Task` 才能读到；雅琪 `recognizedGroup` 必须先于 `submissionType` 计算、二者必须先于 `engineeringContext` 注入与 Gemini 调用。`prompt`/`file_url` 仍先 `validateRequired`。
  - `match` 由静态无 speaker 参数改为支持按 speakerId 分流，属接口签名/调用契约变化——MUST 保持 110/默认走原 `match` 行为，雅琪走独立方法，避免影响其它调用方。
- 旧逻辑保持：
  - 110/默认：`piano_video_prompt`、现有 D1/D2/D3 模板与全部高置信规则（endingRepeatedE、D2 纠偏、monoDescending 抑制、exactCoverage）、高置信覆盖、`${audioseq}`/`${engineeringContext}` 注入、`<5` 有效音短路、FC 异步 + Redis、三模式回退、RUNNING/SUCCESS/FAIL 缓存与字段与 TTL、分发锁、MDC、脱敏，全部不变。
  - `resolvePianoVideoPrompt` 对 `D%s` 的替换与「无占位符原样返回」分支不变。
- 需要用户确认的设计选择（实施前确认）：
  - FC `taskObj` 新增 `speakerId` 字段（接口契约变更，向后兼容：旧消息无该字段时走默认路径）。
  - 新增 env `piano_video_prompt_speaker_113`（远程配置，部署侧需配置调整后的 V1_3 提示词全文）。
  - `PianoNoteSequenceTemplateMatcher` 由静态无 speaker 的 `match` 扩展为支持 speakerId 分流（新增雅琪独立方法/模板，不改 110 路径）。
  - 雅琪场景工程侧「仅注入证据、不覆盖 Gemini 分类字段」，但 `submissionType` 由工程侧算好注入（强参考）。

## 边界情况

- speakerId 缺失/解析失败：不写 `taskObj.speakerId`，提示词取 `piano_video_prompt`，识别走现有 `match`（等价 110，不回归）。
- `piano_video_prompt_speaker_113` 未配置：`resolvePianoVideoPrompt` 返回空/原口径，不抛新异常、不回退污染 110 提示词；Gemini 侧按现有空提示词处理（极端边界）。
- 雅琪右手音序为空 / 有效音 `<5`：沿用现有 `<5` 短路或空音序处理（不强判曲目组），交人工复核/Gemini 兜底。
- 雅琪两组分数都低于阈值：`recognizedGroup=未匹配`、`submissionType=未知`，注入证据后交 Gemini Step 4 兜底（可 `id=-1`）。
- `expectedDay` 非法/缺失：`submissionType=未知`（沿用现有 `parseDayNumber<=0` 口径）。
- 组 X 与组 Y 分数接近（理论上旋律差异大，少见）：取高分组；若 gap 不足阈值则 `未匹配`，不强判。
- speakerId=113 但视频实际是李瑶曲库（错配）：雅琪模板两组都不匹配 → 未匹配 → 交 Gemini，不串到 110 模板。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `HomeWorkMessageDto` 新增 `speakerId` 字段，并在 `SopReply.resolveHomeworkMessage` 用 `userMsg.getSpeakerId()` 或 `resolveSpeakerId(userMsg)` 填充；解析不到时保持为空，不写占位值。
- **FR-002**：系统 MUST 在 `PianoVideoHomeWorkHandleServiceImpl.appendRecognitionContext` 把有效 `speakerId` 写入 `taskObj`，并 MUST 在 FC 异步提交前完成写入；speakerId 为空时 MUST NOT 写入占位值。
- **FR-003**：系统 MUST 让 `PianoHomeWorkVideoV2Task` 从 request 解析 `speakerId`（与 `expectedDay` 同源风格），供提示词外的识别分流使用。
- **FR-004**：`resolvePianoVideoPrompt` MUST 按 speakerId 选 env：speakerId=110/空/未知 → `piano_video_prompt`；其它 speakerId → `piano_video_prompt_speaker_<speakerId>`（113 即 `piano_video_prompt_speaker_113`）；两者 MUST 仍按 `logicalDay` 替换 `D%s`，且保留「无占位符原样返回」行为。
- **FR-005**：系统 MUST 为雅琪（speakerId=113）提供独立曲目模板：组 X=但愿人长久（右手旋律，覆盖 D1/D2/D3）、组 Y=沧海一声笑·有和弦（右手旋律，D4）；MUST 用右手 pitch class（八度归一化）匹配，仅区分「组 X / 组 Y / 未匹配」，MUST NOT 在工程侧细分到具体 D1/D2/D3。
- **FR-006**：系统 MUST 按「组 X={D1,D2,D3}、组 Y={D4}」与 `expectedDay` 计算 `submissionType`：识别组覆盖 expectedDay → 今日作业；识别组天集合整体早于 expectedDay → 补交作业；整体晚于 expectedDay → 提前提交；无法判定 → 未知。取值沿用现有「今日作业/补交作业/提前提交/未知」。
- **FR-007**：雅琪场景系统 MUST 把 `recognizedGroup`（组 X/组 Y/未匹配）与工程侧算好的 `submissionType` 注入提示词（经 `engineeringContext`），并 MUST 在替换音序后仍把视频传给 Gemini。
- **FR-008**：雅琪场景系统 MUST NOT 在工程侧覆盖 Gemini 返回的 `id/recognizedDay/title` 等课程分类字段（仅注入证据，单双手细分交 Gemini）。
- **FR-009**：系统 MUST NOT 改变 speakerId=110/空 的任何行为：提示词取 `piano_video_prompt`、识别走现有 `match` 与全部高置信覆盖规则、缓存/锁/三模式回退/脱敏/`<5` 短路全部不变。
- **FR-010**：`PianoNoteSequenceTemplateMatcher` 的雅琪分支 MUST 与 110 的 `match` 隔离（独立模板与判定），MUST NOT 把雅琪的纠偏/阈值套到 110，也 MUST NOT 把 110 的 endingRepeatedE/D2 纠偏/monoDescending 抑制套到雅琪。
- **FR-011**：系统 MUST 按本规格调整 `视频理解提示词V1_3.txt`，增加接收工程侧 `recognizedGroup`/`submissionType` 的占位（`${engineeringContext}`）与说明，并写明「组内单双手细分由 Gemini 判、submissionType 以工程侧为准」；该文件作为 `piano_video_prompt_speaker_113` 内容交付。
- **FR-012**：单元测试 MUST 断言下游参数：`taskObj.speakerId`、所选提示词 env、`recognizedGroup`、`submissionType`、注入 Gemini 的 prompt（含证据）与仍传视频；MUST 覆盖组 X/组 Y/未匹配、四种 submissionType、110 不回归。

## 成功标准 *(必填)*

- **SC-001**：`speakerId=113` 时，`taskObj.speakerId=113`，提示词取自 `piano_video_prompt_speaker_113`，单元测试可断言。
- **SC-002**：`speakerId=110`/空 时，`taskObj` 不含 speakerId 占位、提示词取 `piano_video_prompt`、识别走原 `match`，与改造前一致。
- **SC-003**：雅琪组 X 右手音序 → `recognizedGroup=组X`；组 Y 右手音序 → `recognizedGroup=组Y`；都不匹配 → `未匹配`，单元测试可断言。
- **SC-004**：四组（expectedDay × 识别组）→ `submissionType` 映射符合 FR-006，单元测试逐条断言。
- **SC-005**：雅琪场景工程侧不覆盖 Gemini 的 `id/recognizedDay/title`，且注入的 prompt 含 `recognizedGroup`/`submissionType`、视频仍传 Gemini。
- **SC-006**：现有 `PianoHomeWorkVideoV2TaskTest` 与 matcher 相关单测在改造后全部通过（110 不回归）。
- **SC-007**：`mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am test`（雅琪相关用例）与 `fc/sop-reply` 相关用例编译并通过；不新增 OSS/MQ/数据库/OTS 调用。

## 假设

- speakerId 在 `SopReply.resolveHomeworkMessage` 可经 `userMsg.getSpeakerId()` 或 `resolveSpeakerId(userMsg)`（CampInfo via camp_date_id）取得（二者均已存在于 sop-reply）；若实际取数路径不同，按 Dxxx 纠正。
- env 命名规则固定为：默认 `piano_video_prompt`、speaker 专用 `piano_video_prompt_speaker_<speakerId>`；110 视为默认、用基础名以兼容现状。后续新增 speaker 自动按该规则拼接。
- 组 X 模板用 D1/D2/D3 共同的右手句 1+句 2：`C5 C5 A4 G4 A4 C5 C5 C5 C5 A4 G4 A4 D5 D5 E5 C5 A4 E5 C5 A4 D5 C5 A4 F5 F5 A4 B4 C5 D5`（可选追加 D3 第三句 `D5 G4 B4 A4 B4 C5` 作容错）；组 Y 模板用 D4 沧海一声笑·有和弦右手：`A5 G5 E5 D5 C5 E5 D5 C5 A4 G4 G4 A4 G4 A4 C5 D5 E5 G5 A5 G5 E5 D5 C5 D5`。pitch class 八度归一化后组 X 起手 `0 0 9 7 9 0`、组 Y 起手 `9 7 4 2 0`，区分度高。模板阈值（最低分/gap）在实现时按现有 `score` 口径标定，若与真实样本不符按 Dxxx 调整。
- 雅琪场景工程侧仅注入证据、不覆盖 Gemini 分类字段；`submissionType` 工程侧算好注入作为强参考，由 Gemini 在输出中采用。若用户要求工程侧硬覆盖 `submissionType`，按 Dxxx 纠正。
- 注入通道复用现有 `${engineeringContext}`（`PianoHomeWorkVideoV2Task` 已有 `injectEngineeringContext`），在 `engineeringContextJson` 增加 `recognizedGroup`/`submissionType` 字段；不新增占位符类型。
- 雅琪 D5/D6 暂不实现；后续提供曲目再追加模板与组定义。
- 音序仍只用单音右手提取，不修改 `VideoToNoteSeq`（组 X/组 Y 旋律差异足以用右手区分，无需和弦检测）。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档（`109-piano-yaqi-speaker-note-seq`），独立于 `108-yaqi-piano-homework-config`（按用户要求不共用）。
- 已完成历史问题防漏分析与强制门禁初稿：speakerId 透传时序、env 选择、雅琪曲目组/submissionType 现算、占位风险、110 不回归。
- 关键业务口径已经多轮 AskUserQuestion 与文字确认：同 SKU 内按 speaker 分流、现有类内分流、按 Dx 多天分类、仅右手旋律、声音只判曲目组、submissionType 工程侧算好注入、仅注入不覆盖、env 映射 110→piano_video_prompt / 113→piano_video_prompt_speaker_113。
- 本阶段未修改任何业务代码，等待用户确认进入实施。

### D002 - 实现记录

- 实现内容：
  - `fc/sop-reply`：`HomeWorkMessageDto` 新增 `Integer speakerId`；`SopReply.resolveHomeworkMessage` 用 `parsePositiveInteger(resolveSpeakerId(userMsg))` 填充 speakerId；`PianoVideoHomeWorkHandleServiceImpl.appendRecognitionContext` 仅在非空时写 `taskObj.speakerId`；`resolvePianoVideoPrompt` 抽出 `resolvePianoVideoPromptEnvName(speakerId)`，110/空→`piano_video_prompt`、其它→`piano_video_prompt_speaker_<id>`，保留 `D%s` 替换与无占位符分支。
  - `fc/Gemini-Api`：`PianoHomeWorkVideoV2Task` 新增 `YAQI_SPEAKER_ID=113`、`resolveSpeakerId/isYaqiSpeaker`、`resolveTemplateMatch`（雅琪走 `matchYaqi`，注入 `speakerId/recognizedGroup/recognizedTitle/submissionType/yaqiTemplateScores` 且返回 `templateMatch=null` 以跳过课程分类覆盖；其它 speaker 走原 `match`+engineeringDecision）、`resolveYaqiSubmissionType`（组X={1,2,3}/组Y={4} × expectedDay）。
  - `PianoNoteSequenceTemplateMatcher` 新增雅琪组X（但愿人长久）/组Y（沧海一声笑·有和弦）模板、`matchYaqi`、`YaqiMatchResult`/`YaqiGroupTemplate` 内部类、阈值 `YAQI_GROUP_MIN_SCORE=0.40`/`YAQI_GROUP_MIN_GAP=0.10`；110 的 `match` 与全部高置信规则不变。
  - 提示词：基于 `视频理解提示词V1_3.txt` 生成 [prompt/piano_video_prompt_speaker_113.txt](prompt/piano_video_prompt_speaker_113.txt)，接入 `${engineeringContext}`、写明曲目组以工程侧为准、组X 内 D1/D2/D3 由 Gemini 看单双手细分、submissionType 以工程侧为准。
- 影响范围：仅 `fc/sop-reply` + `fc/Gemini-Api` + 提示词文本；未改 Python/VideoToNoteSeq、MQ、Redis、DB、OTS；110 行为不回归。
- 测试命令：
  - `mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am test "-Dtest=PianoHomeWorkVideoV2TaskTest,PianoNoteSequenceTemplateMatcherTest" "-Dsurefire.failIfNoSpecifiedTests=false"`
  - `mvn -f C:\workspace\ju-chat\fc\pom.xml -pl sop-reply -am test "-Dtest=PianoVideoPromptRoutingTest" "-Dsurefire.failIfNoSpecifiedTests=false"`
- 测试结果：Gemini-Api `Tests run: 39, Failures: 0, Errors: 0`（含新增 4 个雅琪集成 + 3 个 matchYaqi，原 32 不回归）；sop-reply `Tests run: 4, Failures: 0, Errors: 0`；均 BUILD SUCCESS。雅琪组Y 实测 groupYScore=1.0、groupXScore=0.64、gap=0.36，expectedDay=D1 时 submissionType=提前提交。
- 自检结论：满足 FR-001~012 与 SC-001~007；speakerId 在 FC 提交前写入、雅琪证据在注入前算好、`templateMatch=null` 天然不覆盖、110 走原 `match`；剩余风险=雅琪阈值（0.40/0.10）与组X模板需真实样本回归校准；提示词 env `piano_video_prompt_speaker_113` 需部署侧配置。

### D003 - 纠正记录（雅琪曲目组 gap 阈值放宽）

- 触发原因：用户提供 13 个真实视频，经 `FcOssFFmpeg-3278/VideoToNoteSeq` 同步提取音序后回归。D1-D3（10 个）全部稳定命中组X；D4「沧海一声笑·有和弦」3 个里 `yaqi_D4_1` 命中组Y，但 `yaqi_D4_2`(groupX=0.45/groupY=0.48)、`yaqi_D4_3`(groupX=0.67/groupY=0.68) 因左手三音和弦低音被单音 pyin 混入、拉近两组音级分布，`scoreGap`(0.01~0.03) 跌破原阈值 0.10 → 判未匹配（但 groupY 方向仍占优）。经 AskUserQuestion 确认选「放宽 gap 门槛」。
- 修正内容：旧口径 `YAQI_GROUP_MIN_GAP=0.10`；新口径=`0.0`（达 `YAQI_GROUP_MIN_SCORE=0.40` 后按更高分组判定、不要求分差，由 `min_score` 把关）。D1-D3 的 gap 均 0.12~0.46，不受影响；雅琪仅注入不覆盖、有 `min_score` 把关，鲁棒性可接受。
- 文档同步：`spec.md`（本记录、假设阈值由 0.40/0.10 改为 0.40/0.0）、`tasks.md`（D003）。
- 验证结果：`PianoNoteSequenceTemplateMatcherTest` 新增真实 `yaqi_D4_3` 序列样本断言命中组Y，40 个单测全过；真实回归 `yaqi_D4_3` 由「未匹配」改判「组Y(沧海一声笑)」PASS（groupX=0.67/groupY=0.68，gap=0.01）。`yaqi_D4_2` 数据（groupY 0.48 > groupX 0.45）在 gap=0 下确定命中组Y。
- 备注：FC `VideoToNoteSeq` 同步调用在高负载时偶发超时（`yaqi_D1_1`/`yaqi_D4_2` 多次 ERROR，单次曾达 175s），属音序提取服务性能波动，与识别逻辑无关；生产用异步 + Redis（10min 等待超时）规避。回归用的临时手动测试 `YaqiVideoRegressionManualTest` 已删除、不入库。

### D004 - 纠正记录（组X 今日作业按 expectedDay 定 id，消除 D2/D3 误判）

- 触发原因：用户反馈某「但愿人长久」D2 视频被识别为 D3。根因：组X(D1/D2/D3 右手旋律相同) 内的 D1/D2/D3 细分原交给 Gemini 看视频单双手判断，Gemini 把 D2 误判 D3。
- 修正内容：组X 是同一首曲子的不同深度，今日作业一律按当前进度 `expectedDay` 计 id。工程侧雅琪分支新增 `resolveYaqiRecognizedDay`：组X 今日作业 → `recognizedDay=D{expectedDay}`/`recognizedId=expectedDay`；组Y → D4；组X 非今日（补交/提前）不给（交模型）。注入 `engineeringContext`。提示词改为「组X 命中时 `id`/`recognizedDay` 直接采用工程侧 `recognizedDay`，禁止细分 D1/D2/D3；单双手/和弦/第三句仅作诊断」。
- 文档同步：`spec.md`（本记录）、`tasks.md`、提示词。
- 验证结果：单测断言组X今日注入 `recognizedDay=D2/recognizedId=2`、组Y=D4、组X补交不注入；42 单测全过。

### D005 - 纠正记录（分层阈值 + 未匹配判 id=-1 人工介入）

- 触发原因：D003 的 `gap=0` 太激进——用户反馈某「但愿人长久」视频（音序采集质量差、未抓到标准右手高音旋律，`groupX=0.42`/`groupY=0.51`/`gap=0.09`）被误判沧海(组Y)。两组都低分且接近时纯方向判定不可靠。用户要求「分数低的直接判 id=-1，后续人工介入」。
- 修正内容：
  - 分层阈值取代 `gap=0`：新增 `YAQI_GROUP_HIGH_SCORE=0.65`（高分直接判，救 D4_3=0.68 等）；`YAQI_GROUP_MIN_GAP` 恢复 `0.10`（中等分 0.40~0.65 需 `gap≥0.10` 否则未匹配）。该案例(0.51/gap0.09)改判未匹配。
  - 未匹配（分数低）直接判 `id=-1`：雅琪曲目组未匹配时工程侧短路返回 `id=-1`/`needHumanReview=true` 人工复核 JSON（新增 `isYaqiGroupUnmatched`/`buildYaqiUnmatchedResult`），不调 Gemini 硬猜。提示词「未匹配」分支同步说明已由工程侧拦截为人工介入。
- 文档同步：`spec.md`、`tasks.md`、提示词。
- 验证结果：单测新增「误判案例音序→未匹配」「雅琪未匹配→id=-1 短路不调 Gemini」；matcher 11 + task 31 = 42 单测全过；D4_3(0.68)高分仍命中组Y、D2_1(gap0.12)仍组X 不回归。
- 假设更新：D003 的阈值口径 `0.40/0.0` 被本记录的分层阈值 `min=0.40 / high=0.65 / midGap=0.10` 取代。

### D006 - 纠正记录（有效音太少/两组太接近 → 雅琪未匹配人工）

- 触发原因：用户提供一段雅琪视频，只有 5 个有效音 `A4 G4 C5 A4 D5`（pitch class 9 7 0 9 2，恰好同时落在但愿人长久和沧海的音级集合里），导致 `groupX=0.90`/`groupY=0.93`/`gap=0.03` 两组都高且接近；雅琪「高分(>=0.65)直接判」规则判了 groupY(沧海D4)，但 5 个音根本无法区分两首曲子，期望 D3 却返回 D4。
- 修正内容：`matchYaqi` 增加两道未匹配判定（满足其一即 `matched=false`，走雅琪未匹配 id=-1 人工短路）：
  - `tooFewToDistinguish`：有效音 `< YAQI_MIN_OBSERVED_NOTES(8)`，音太少无法可靠区分曲目组；
  - `ambiguousBothHigh`：`groupX>=YAQI_AMBIGUOUS_BOTH_HIGH(0.85) && groupY>=0.85 && gap<YAQI_GROUP_MIN_GAP(0.10)`，两组都很高且接近（音序短/公共音重叠）无法区分。
- 验证结果：新增单测 `matchYaqi_shouldReturnUnmatchedForTooFewNotes`（5 音案例→未匹配）；D4_3(23 音、groupX=0.67<0.85，两条都不触发)仍判组Y、其余雅琪组X/组Y/低分用例不回归。matcher 18 + task 39 = 57 单测全过。
- 备注：案例只有日志音序（无视频 URL），matcher 单测直接用真实音序锁定→未匹配。
