# 规格质量检查清单：钢琴作业识别——移调补救假阳性修复 + 萱草花提示词锚点

**用途**：验证需求完整性、参数完整性和实施就绪度
**创建日期**：`2026-06-26`
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目（fc/Gemini-Api）、模块、入口（V2 handleRequest）和核心实现位置（bestTransposedRescue）。
- [x] 明确用户目标、成功标准和非目标。
- [x] 明确新增（连续短语门禁、萱草花锚点、锁定测试）、修改与禁止改变的行为。
- [x] 明确日志/fallback/兼容性/异常口径：复用既有低分人工复核 fallback，不改异常处理与 JSON 结构。
- [x] 明确后续实现必须增加测试或静态验证记录。
- [x] D005 已补充真实 `VideoToNoteSeq` 调用回归记录、明细 JSON 路径和剩余口径差异。
- [x] D007 已补充雅琪低质量沧海误判组X的回归记录和人工介入断言。
- [x] D008 已补充低质量升半音沧海误判铁血丹心的回归记录和工程侧覆盖断言。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 或未替换占位内容残留（仅 D002 待实现后回填）。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量（具体音序→具体输出字段、既有测试通过）。
- [x] 验收场景覆盖正常路径（萱草花/真升半音）、边界路径（噪声/短序列）、不回归路径（真升半音两条既有测试）。
- [x] 边界情况已识别（短序列保守转人工、阈值取值实测、提示词单行格式）。

## 参数完整性门禁

- [x] 已列出关键参数来源和赋值时机（observed/baseBestScore/transposed）。
- [x] 已列出下游读取字段清单（transpositionShift/score/contiguousPhraseSimilarity；highConfidence/bestScore.score）。
- [x] 没有未解释的 `new XxxDto()`、空 JSON、空 Map 或占位参数。
- [x] 下游读取字段在调用前已赋值或当前层现算现用。
- [x] 不存在未处理的调用后赋值风险。
- [x] 本次不涉及外部接口/Feign/FC/MQ/Redis/DB 写入参数变更；task 级测试断言最终下游结果（id/needHumanReview/Gemini 调用次数）。
- [x] 修复不改调用顺序/接口契约/远程调用/业务语义中需用户确认的部分均已确认（D001）。

## 实施就绪度

- [x] 实现范围限定在 `PianoNoteSequenceTemplateMatcher`、`demo-prompt` 与两套测试，不扩散到无关模块。
- [x] 不新增数据库表、对外 API，不修改 MQ/Redis/配置契约。
- [x] 已确认旧逻辑必须保持不变的分支与 fallback。
- [x] 每个关键需求至少有一条测试或静态验证任务（见 tasks Phase 4）。
- [x] 单元测试用 Fake 注入，避免真实访问 Redis/OTS/FC/HTTP。
- [x] 如补充或纠正需求，将同步更新 spec/tasks/AGENTS/checklist。

## 备注

- 强制门禁已完成，可在用户确认后进入实现。
- 阈值 `TRANSPOSE_RESCUE_MIN_CONTIGUOUS` 以实测两端数值定稿，记录在 spec D002。
- D006 已确认：`V5-1_D4` 识别 D5 后作业类型为「提前提交」是正确口径，用户前文「当日作业」为口误；无需调整 `resolveTemplateSubmissionType`。
- D007 已确认：雅琪低质量短音序组别不稳定时应返回 `id=-1` 人工介入；修复通过连续短语门禁完成。
- D008 已确认：低质量但旋律指向明确的升半音沧海应输出《沧海一声笑》，不是 `id=-1`；修复通过远距离移调门禁让 D3/D4 近距离候选胜出。
