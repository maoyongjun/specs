# 规格质量检查清单：钢琴作业视频按 speakerId 分流（雅琪 113）

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-06-23`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目、模块、入口和核心实现位置（fc/sop-reply + fc/Gemini-Api，见 AGENTS「重点代码位置」）。
- [x] 明确用户目标、成功标准和非目标。
- [x] 明确新增、修改和禁止改变的行为（110 不回归、雅琪仅注入不覆盖）。
- [x] 明确日志、时间、延迟、幂等、fallback、兼容性或异常处理要求（speakerId 缺失/ env 缺失/两组不匹配兜底）。
- [x] 明确后续实现必须增加测试或静态验证记录（Phase 4）。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 残留；非阻塞假设已在「假设」显式标注（模板阈值、env 命名、不覆盖策略）。
- [x] 需求可测试且无明显歧义（FR-001~012）。
- [x] 成功标准可衡量（SC-001~007）。
- [x] 验收场景覆盖正常路径、边界路径和不回归路径（故事 1~4）。
- [x] 边界情况已识别并明确兜底（speakerId/ env 缺失、两组不匹配、`<5`、expectedDay 非法、错配）。

## 参数完整性门禁

- [x] 已列出关键参数来源和赋值时机（speakerId/promptEnvName/recognizedGroup/submissionType）。
- [x] 已列出下游读取字段清单。
- [x] 没有未解释的 `new XxxDto()`、空 JSON、空 Map 或占位参数（taskObj.speakerId 仅有效时写；曲目组未匹配不伪造）。
- [x] 下游读取字段在调用前已赋值，或在当前层现算现用（speakerId 先于 FC 提交；雅琪证据先于注入/Gemini）。
- [x] 不存在未处理的调用后赋值风险（已在 T007 列出严格时序）。
- [x] 外部接口/FC/Redis 等关键参数已有下游参数断言方案（taskObj.speakerId、注入 prompt 内容、recognizedGroup/submissionType）。
- [ ] 若修复会改变调用顺序、接口契约、远程调用或业务语义，已记录并完成用户确认 —— **已记录（FC taskObj 增字段、新增 env、matcher 按 speaker 分流），用户确认待办**。

## 实施就绪度

- [x] 实现范围已限定（仅 fc/sop-reply + fc/Gemini-Api + 提示词文本），不扩散到无关模块。
- [x] 不新增数据库表、不新增对外 API、不改 MQ/Redis 契约；FC taskObj 新增字段与新增 env 为受控变更，规格已明确并待确认。
- [x] 已确认旧逻辑中必须保持不变项（110 全链路、`D%s` 替换、`<5` 短路、缓存/锁/三模式/脱敏）。
- [x] 每个关键需求至少有一条测试/编译/静态验证任务（Phase 4 T016~T020）。
- [x] 单测计划避免真实访问 Redis/OTS/Center/RocketMQ/FC/外部 HTTP（用注入的 env 读取器、Fake 匹配/注入断言）。
- [x] 补充/纠正需求时同步更新 spec/tasks/AGENTS/checklist（流程已约定）。

## 备注

- 强制门禁未完成前不进入实现；当前待用户确认 3 项受控契约变更后进入 Phase 3。
- 雅琪模板阈值（最低分/gap）需在实现时按现有 `score` 口径标定，必要时按 Dxxx 用真实样本调整。
