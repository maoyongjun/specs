# 任务清单：钢琴作业视频按 speakerId 分流（雅琪 113）

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 项目/模块/链路：目标项目 `fc`；模块 `fc/sop-reply`（speakerId 透传 + 提示词选择）与 `fc/Gemini-Api`（speakerId 读取 + 雅琪识别分支）；链路 SopReply → PianoVideoHomeWorkHandleServiceImpl →（FC 异步 service_sys/Piano-homework-video）→ PianoHomeWorkVideoV2Task。
- [x] T002 入口/调用链/落点已确认：
  - `SopReply.resolveVideoRecognizeService(request, userMsg)`（[SopReply.java:924](../../fc/sop-reply/src/main/java/com/drh/homework/service/SopReply.java)）按 `skuId==SKU_PIANO` 派发；`resolveHomeworkMessage(request, userMsg, msgType, logicalDay)` 构建 `HomeWorkMessageDto`（含 userMsg，可取 speakerId）。
  - `PianoVideoHomeWorkHandleServiceImpl.resolvePianoVideoPrompt`（env `piano_video_prompt` + `D%s`）、`appendRecognitionContext`（taskObj 透传）。
  - `PianoHomeWorkVideoV2Task.analyzeVideo`（音序 → FeatureExtractor → TemplateMatcher.match → 高置信覆盖 → 注入 → Gemini）、`resolveExpectedDay`、`resolveSubmissionType`、`injectEngineeringContext`、`ENGINEERING_CONTEXT_PLACEHOLDER`。
  - `PianoNoteSequenceTemplateMatcher.match(observed, monoDescending)` 静态、Template(day,id,title,noteSequence)、MatchResult。
  - 测试落点：`fc/Gemini-Api/.../PianoHomeWorkVideoV2TaskTest`、matcher 单测；`fc/sop-reply` 对应单测。
- [x] T003 关键参数：`speakerId`（WebChatVoiceDto.speakerId / resolveSpeakerId via CampInfo，Integer）；`HomeWorkMessageDto` 当前**无** speakerId 字段、`taskObj` 当前**无** speakerId，均需新增；`expectedDay/logicalDay` 现状不变；雅琪 `recognizedGroup`/`submissionType` 在 Gemini-Api 现算。
- [x] T004 配置/外部：新增 env `piano_video_prompt_speaker_113`；FC `taskObj` 新增字段 `speakerId`（FC body 契约变更，向后兼容）；FC 服务名/函数名不变；不涉及 Redis key/TTL、MQ topic/tag、DB、OTS 变更（缓存/锁 key 沿用 cacheKey 既有构造）。
- [x] T005 必须保持不变：110/默认的提示词 env、现有 D1/D2/D3 模板与高置信规则、高置信覆盖、`${audioseq}`/`${engineeringContext}` 注入、`<5` 短路、FC 异步 + Redis、三模式回退、RUNNING/SUCCESS/FAIL 缓存与字段与 TTL、分发锁、MDC、脱敏、`resolvePianoVideoPrompt` 的 `D%s` 替换与「无占位符原样返回」。

**检查点**：T001-T005 已完成。

## Phase 2：风险门禁

- [x] T006 占位对象：`taskObj.speakerId` 仅有效时写入，否则不写；雅琪两组都不匹配时 `recognizedGroup=未匹配`、`submissionType=未知`，不构造占位曲目组/作业类型；不新增 `new XxxDto()` 空对象下传。
- [x] T007 调用后赋值：`speakerId` 必须在 `appendRecognitionContext`/FC 提交前写入 taskObj；雅琪 `recognizedGroup`→`submissionType`→`engineeringContext` 注入→Gemini 严格时序，均在当前层现算现用。
- [x] T008 下游来源：`taskObj.speakerId`←`HomeWorkMessageDto.speakerId`←SopReply 填充；`promptEnvName`←speakerId 现算；`recognizedGroup`←右手 pitchClasses 现算；`submissionType`←recognizedGroup+expectedDay 现算，均有确定来源。
- [x] T009 契约/顺序变化：①FC `taskObj` 新增 speakerId；②新增 env；③`PianoNoteSequenceTemplateMatcher` 扩展为按 speakerId 分流（110 走原 `match`、113 走独立方法）。这些为本次受控变更，已在 spec「需要用户确认的设计选择」列出，待用户确认。
- [x] T010 业务语义变化记录：雅琪「声音只判曲目组、单双手细分交 Gemini、submissionType 工程侧算好注入、仅注入不覆盖」已记录并经用户确认。
- [x] T011 测试映射：speakerId 透传、env 选择、组 X/组 Y/未匹配、四种 submissionType、仍传视频、不覆盖分类、110 不回归——每项至少一条单测（见 Phase 4）。

**检查点**：T006-T011 结论明确，未发现需先改 spec 的新增高风险点；待用户确认受控契约变更后进入实现。

## Phase 3：实现（待用户确认后执行）

- [x] T012 `fc/sop-reply`：`HomeWorkMessageDto` 增 `Integer speakerId`；`SopReply.resolveHomeworkMessage` 填充 speakerId；`PianoVideoHomeWorkHandleServiceImpl.appendRecognitionContext` 写 `taskObj.speakerId`；`resolvePianoVideoPrompt` 按 speakerId 选 env（110/空→`piano_video_prompt`，其它→`piano_video_prompt_speaker_<id>`），保留 `D%s` 替换与无占位符分支。
- [x] T013 `fc/Gemini-Api`：`PianoHomeWorkVideoV2Task` 读 request `speakerId`；speakerId=113 走雅琪分支（曲目组匹配 + submissionType + 注入证据 + 不覆盖），其它走现有逻辑不变。
- [x] T014 `PianoNoteSequenceTemplateMatcher`：新增雅琪组 X/组 Y 模板常量与独立匹配方法（输出 recognizedGroup），与 110 `match` 隔离；`PianoHomeWorkVideoV2Task` 雅琪分支算 `submissionType` 并把 `recognizedGroup`/`submissionType` 加入 `engineeringContextJson`。
- [x] T015 调整 `视频理解提示词V1_3.txt`：补 `${engineeringContext}` 占位与字段说明、写明组内单双手细分由 Gemini 判、submissionType 以工程侧为准；产出作为 `piano_video_prompt_speaker_113` 交付文本。同步 spec/tasks/AGENTS/checklist 口径。

## Phase 4：测试与验证（待实现后执行）

- [x] T016 `fc/sop-reply` 单测：speakerId 填充与 `taskObj.speakerId`；`resolvePianoVideoPrompt` 对 110/113/空 选对 env 并替换 `D%s`；env 缺失边界。
- [x] T017 `fc/Gemini-Api` 单测：断言注入 Gemini 的 prompt 含 `recognizedGroup`/`submissionType`、仍传 fileUri、未覆盖 Gemini 分类字段；matcher 雅琪分支组 X/组 Y/未匹配。
- [x] T018 边界与不回归：四种 submissionType；speakerId=110/空 走原 `match` 与原覆盖；`<5` 短路、空音序、env 缺失。
- [x] T019 运行：`mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am test "-Dtest=PianoHomeWorkVideoV2TaskTest" -q` 等 focused 用例 + sop-reply 相关用例，记录结果。
- [x] T020 残留检查：确认无遗漏的旧 `match` 直调使雅琪误走 110 模板、无 speakerId 透传断点、无 env 名硬编码错误。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `109-piano-yaqi-speaker-note-seq` 四件套；完成 Phase 1 事实确认与 Phase 2 风险门禁结论。
- 验证方式：代码搜索与阅读确认入口、调用链、字段来源、配置来源、测试落点（见 T001-T011）。
- 自检结论：满足强制门禁；待用户确认 3 项受控契约变更（FC taskObj 增字段、新增 env、matcher 按 speaker 分流）后进入实现。

### D002 - 实现记录

- 实现内容：见 `spec.md` D002（sop-reply speakerId 透传 + 提示词 env 路由；Gemini-Api 雅琪分支 matchYaqi + submissionType + 仅注入不覆盖；提示词文件交付）。
- 测试命令：
  - `mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am test "-Dtest=PianoHomeWorkVideoV2TaskTest,PianoNoteSequenceTemplateMatcherTest" "-Dsurefire.failIfNoSpecifiedTests=false"`
  - `mvn -f C:\workspace\ju-chat\fc\pom.xml -pl sop-reply -am test "-Dtest=PianoVideoPromptRoutingTest" "-Dsurefire.failIfNoSpecifiedTests=false"`
- 测试结果：Gemini-Api `Tests run: 39, Failures: 0, Errors: 0`；sop-reply `Tests run: 4, Failures: 0, Errors: 0`；均 BUILD SUCCESS。
- 自检结论：speakerId 透传、提示词 env 路由（110/113）、组X/组Y/未匹配、四种 submissionType、仅注入不覆盖、110 不回归均有测试断言；下游参数（taskObj.speakerId、所选 env 名、注入 prompt 的 recognizedGroup/submissionType）已断言。剩余风险=雅琪阈值与组X模板待真实样本回归校准。

### D003 - 纠正记录（gap 阈值放宽）

- 触发原因：13 个真实视频回归发现 D4「沧海一声笑·有和弦」左手和弦低音混入音序，使 groupX≈groupY、gap 跌破 0.10 判未匹配（方向仍 groupY 占优）。用户确认放宽 gap。
- 修正内容：`YAQI_GROUP_MIN_GAP` 由 0.10 改为 0.0（达 min_score 后按更高分组判定）；详见 `spec.md` D003。
- 测试结果：`PianoNoteSequenceTemplateMatcherTest`（含新增 yaqi_D4_3 样本）+ `PianoHomeWorkVideoV2TaskTest` 共 40 个单测全过；真实回归 yaqi_D4_3 由未匹配改判组Y。
- 自检结论：D1-D3 gap 均远大于 0，不回归；雅琪仅注入不覆盖 + min_score 把关，鲁棒性可接受。临时回归测试已删除。

### D004 - 纠正记录（组X 今日作业按 expectedDay 定 id）

- 触发原因：但愿人长久 D2 视频被 Gemini 细分误判 D3。
- 修正内容：组X 今日作业按 expectedDay 注入 `recognizedDay/recognizedId`（组Y=D4，组X 补交/提前不注入），提示词规定 id 直接采用、禁止细分；详见 `spec.md` D004。
- 测试结果：42 单测全过；组X今日注入 D2/id2、组Y 注入 D4、组X补交不注入均有断言。

### D005 - 纠正记录（分层阈值 + 未匹配判 id=-1）

- 触发原因：gap=0 导致但愿人长久(0.42/0.51,gap0.09)误判沧海；用户要求分数低直接 id=-1 人工介入。
- 修正内容：分层阈值 high=0.65/midGap=0.10 取代 gap=0；雅琪未匹配短路返回 id=-1 人工复核、不调 Gemini；详见 `spec.md` D005。
- 测试结果：42 单测全过（含误判案例→未匹配、未匹配→id=-1 短路）；D4_3 高分仍组Y、D2_1 仍组X 不回归。
