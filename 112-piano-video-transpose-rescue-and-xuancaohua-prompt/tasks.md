# 任务清单：钢琴作业识别——移调补救假阳性修复 + 萱草花提示词锚点

**输入**：来自 `spec.md` 的功能规格
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 项目=fc/Gemini-Api，模块=钢琴作业视频识别 V2；链路：V2 任务先调 VideoToNoteSeq 取音序→特征提取→模板匹配→（高置信覆盖 / 低分人工复核）→注入提示词调 Gemini。
- [x] T002 入口 `PianoHomeWorkVideoV2Task.handleRequest`/`analyzeVideo`；核心 `PianoNoteSequenceTemplateMatcher.match` 与 `bestTransposedRescue`；测试落点 `PianoNoteSequenceTemplateMatcherTest`、`PianoHomeWorkVideoV2TaskTest`。
- [x] T003 关键参数：`observed`（pitchClasses，match 前赋值）、`baseBestScore`（rescue 前算）、`transposed`（含 contiguousPhraseSimilarity，scoreAgainstPitchClasses 一次性算）。类型均为标量/List<Integer>。
- [x] T004 配置/外部：不涉及环境变量/Redis key/MQ/Feign/DB 改动；纯内存评分。提示词为 classpath 资源 `demo-prompt`（V1 任务加载）。
- [x] T005 须保持不变：真升半音铁血补救命中 D2；原调精细区分；结尾连续 E/D1/D3 纠偏/萱草花开头指纹；课程外音级拦截「已高置信不拦截」语义；假高置信 D2 拦截；低分人工复核短路；JSON 输出结构。

**检查点**：T001-T005 已完成。

## Phase 2：风险门禁

- [x] T006 无 `new XxxDto()`/空 JSON/空 Map 占位传参；仅新增标量阈值比较。
- [x] T007 无调用后赋值/异步后赋值；新增读取的 `transposed.contiguousPhraseSimilarity` 与既有读取字段同源同时机。
- [x] T008 下游读取字段（transpositionShift/score/contiguousPhraseSimilarity）均在 `scoreAgainstPitchClasses` 内赋值后才读取。
- [x] T009 不改调用顺序、接口契约、外部请求、MQ body、Redis TTL、DB 写入或异步行为；不改 JSON 结构。
- [x] T010 业务语义变化点（提示词落点/锚点形式/告警形态）已在 D001 与用户确认，无未决项。
- [x] T011 测试映射：噪声不命中（matcher）、噪声转人工（task，断言下游 id/needHumanReview/Gemini 次数）、真升半音不回归（matcher+task）、萱草花绝对音名锁定命中 D5（matcher）。

**检查点**：T006-T011 结论明确，无高风险未记录项。

## Phase 3：实现

- [ ] T012 在 `PianoNoteSequenceTemplateMatcher` 新增常量 `TRANSPOSE_RESCUE_MIN_CONTIGUOUS`，在 `bestTransposedRescue` 的命中条件中加入 `transposed.contiguousPhraseSimilarity >= TRANSPOSE_RESCUE_MIN_CONTIGUOUS`。
- [ ] T013 保持 `match` 其余分支、`scoreAgainstPitchClasses`、下游 task 分支与 JSON 输出不变。
- [ ] T014 task 级测试断言下游结果：`id=-1`、`needHumanReview=true`、`isHomeWork=否`、`caller.fileCalls=0`。
- [ ] T015 实现后如阈值与初值不同，更新 spec D002 假设记录。
- [ ] T016 修改 `demo-prompt` D5/D6 段，补萱草花四句绝对音名锚点（沿用单行 `\n` 字面格式）。

## Phase 4：测试与验证

- [ ] T017 新增 matcher 测试：噪声 `D3 F3 F#3 F#3 C#3 F#3 B3 F#3 D#3 D#3 D3 C#3 C#3` → `highConfidence=false`、无移调命中。
- [ ] T018 新增 task 测试：同噪声 expectedDay=2 → id=-1/needHumanReview=true/isHomeWork=否/fileCalls=0。
- [ ] T019 新增 matcher 测试：萱草花给定四句绝对音名 → 高置信命中 D5（id=5,dayMin=5,dayMax=6）。
- [ ] T020 运行 `mvn -pl Gemini-Api test -Dtest=PianoNoteSequenceTemplateMatcherTest,PianoHomeWorkVideoV2TaskTest`（在 fc/ 下），确认含真升半音两条既有测试在内全量通过；静态确认 demo-prompt 锚点已补。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 112 号规格文档，完成 Phase 1/2 事实确认与风险门禁。
- 验证方式：阅读 `PianoNoteSequenceTemplateMatcher`、`PianoHomeWorkVideoV2Task`、两套测试、`demo-prompt`；逐字核对 `D5_TEMPLATE` 与给定四句音序一致。
- 自检结论：满足强制门禁，无占位对象/调用后赋值风险，业务语义变化点已确认。

### D002 - 实现记录

- 实现内容：`bestTransposedRescue` 增加连续短语门禁（常量 `TRANSPOSE_RESCUE_MIN_CONTIGUOUS=0.20`）；`demo-prompt` D5/D6 补萱草花绝对音名锚点；新增 3 条测试。
- 测试命令：`mvn -f fc/pom.xml -pl Gemini-Api test -Dtest='PianoNoteSequenceTemplateMatcherTest,PianoHomeWorkVideoV2TaskTest'`
- 测试结果：本次目标 3 条新测试 + 真升半音回归 2 条 + V2 任务类全量通过；仅剩 2 条既有失败（D5 过度贪婪，见 spec D003），基线复现确认与本次改动无关。
- 自检结论：T012-T019 完成。剩余风险：见 D003（已由 D004 修复）。

### D004 - D5 过度贪婪修复 + 提示词落点调整

- 实现内容：
  1. `PianoNoteSequenceTemplateMatcher.match` 增加 D5 入选门槛（新增常量 `D5_EXACT_MIN_CONTIGUOUS=0.30`）：D5 仅在「有萱草花开头指纹」或「coverage≥0.95 且 contiguous≥0.30」时参与 best 竞争。
  2. 撤销 demo-prompt 改动（还原），提示词改为本目录 `prompt-v2-revised.md`（修正 D5/D6 音序为 C 大调权威四句 + 关键特征/规则修正），线上由用户更新。
- 测试命令：`mvn -f fc/pom.xml -pl Gemini-Api test -Dtest='PianoNoteSequenceTemplateMatcherTest,PianoHomeWorkVideoV2TaskTest'`
- 测试结果：Tests run: 60, Failures: 0, Errors: 0, BUILD SUCCESS。两条既有失败转绿；移调补救假阳性修复、真升半音回归、萱草花绝对音名锁定、噪声转人工等全部通过。
- 自检结论：仅改内存评分逻辑 + 测试 + spec 文档；未改方法签名/JSON 结构/外部契约；旧 D5 命中用例（均含开头指纹）不回归。
