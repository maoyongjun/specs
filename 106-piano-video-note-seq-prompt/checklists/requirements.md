# 规格质量检查清单：钢琴作业视频 V2 先取音序再注入提示词

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-06-21`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目（`fc`）、模块（`Gemini-Api`）、入口（`handleRequest`/`analyzeVideo`）和核心实现位置（`PianoHomeWorkVideoV2Task`）。
- [x] 明确用户目标（先取音序注入提示词再交 Gemini）、成功标准（SC-001~005）和非目标。
- [x] 明确新增（取音序+占位符替换）、保持（仍传视频）和禁止改变（缓存/锁/三模式/脱敏）的行为。
- [x] 明确失败/空音序兜底、warn 日志、不写 FAIL、占位符缺失处理等异常要求。
- [x] 明确后续实现必须增加下游参数断言测试（FR-007/008）。
- [x] D005 明确音序同步调用 endpoint 目标：默认音序路径走北京 VPC endpoint，默认 `doSyncTask` 不全局迁移。
- [x] D006 明确音序调用改走 transfer/fc HTTP 网关，D005 SDK VPC 方案被取代。
- [x] D007 明确音序调用改走异步 FC + Redis：Java 异步提交，Python 写 Redis 状态，Java 轮询结果；D006 HTTP 默认方案被取代。
- [x] D008 明确替换完音序后的 prompt 需要打印日志，且有单测验证日志内容。
- [x] D009 明确工程侧输出固定音序特征 JSON 和弱上下文，不输出候选排名；并明确有效音 `<5` 的代码层短路返回策略。
- [x] D013 明确工程侧模板覆盖扩展到 D1/D2/D3；D2 新左右手分句模板、D3 无和弦模板、结尾连续 E 音级 D2 优先规则均已记录。
- [x] D016 明确李瑶 D5/D6 萱草花工程模板、D3-D4/D5-D6 组内按 `expectedDay` 定最终天数，以及提示词 `${engineeringContext}` 分工说明。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 或未替换占位内容残留（D002/D003 为待实现后回填模板，非未决问题）。
- [x] 需求可测试且无明显歧义（三项业务口径已 AskUserQuestion 确认）。
- [x] 成功标准可衡量（音名拼接结果、下游参数、不写 FAIL、现有用例通过）。
- [x] 验收场景覆盖正常路径、边界路径（失败/空/无占位符）和不回归路径（缺 prompt、auto 回退）。
- [x] 边界情况已识别，并明确跳过、兜底、抛错或记录日志的策略。

## 参数完整性门禁

- [x] 已列出关键参数来源和赋值时机（`prompt`/`file_url`/`noteSeqText`/`serviceName`/`functionName`/`event.video_path`/`task_id`）。
- [x] 已列出下游读取字段清单（`VideoToNoteSeq`/`buildNoteSequenceText`/Gemini 链路）。
- [x] 没有未解释的 `new XxxDto()`、空 JSON、空 Map 或占位参数（`FcInvokeInput` 调用前 set 齐，`event` 含 `video_path`）。
- [x] 下游读取字段在调用前已赋值，或在当前层现算现用（`noteSeqText` 替换前现算）。
- [x] 不存在未处理的调用后赋值风险（时序：赋 video_path → 取音序 → 算文本 → 替换 → 调 Gemini）。
- [x] 外部接口（FC `VideoToNoteSeq`、Gemini）关键参数已有下游参数断言方案（FR-008）。
- [x] 本次新增同步远程调用、调整 Gemini 调用前处理，已记录并完成用户确认（音序形式/仍传视频/失败继续）。
- [x] D005 已补充 endpoint/client 来源、赋值时机和下游读取风险：`clientBeijing`/`runtimeBeijing` 静态初始化后供显式 VPC 同步调用使用。
- [x] D006 已补充 transfer URL、transfer body、`taskObj`、`isVpc` 来源与赋值时机。
- [x] D007 已补充内部音序 `cacheKey`、Redis 状态 JSON、异步 FC event、等待参数来源与赋值时机。
- [x] D009 已补充 `engineeringContext`、去噪规则、八度归一化指纹、有效音短路、`expectedDay`、私聊最近 3 条聊天记录的来源、赋值时机和弱参考边界。
- [x] D012 已补充 D1/D2 模板来源、模板匹配分数、`engineeringDecision`、分类字段覆盖时机与覆盖范围；明确低置信不覆盖。
- [x] D013 已补充 D3 模板来源、D2 结尾 E 优先指纹、完整覆盖率高置信规则，以及冲突 evidence 的替换时机。
- [x] D014 已补充 `contiguousPhraseSimilarity` 来源、D1 窄口径纠偏条件、D1 移调评分适用范围、`transpositionShift` 输出时机，以及新增 D1 样本回归结果。
- [x] D016 已补充 D5 萱草花模板来源、`dayMin/dayMax` 组范围、`expectedDay` 到最终 `id/recognizedDay/submissionType` 的赋值时机，以及高置信 `engineeringDecision` 不再只使用模板代表天的风险控制。

## 实施就绪度

- [x] 实现范围限定在 `fc/Gemini-Api`（`PianoHomeWorkVideoV2Task` 及其单测），不扩散到无关模块。
- [x] 不新增数据库表、不新增对外 API、不修改 MQ/Redis/配置契约（仅复用既有 FC 调用工具，服务/函数名走常量+env）。
- [x] 已确认旧逻辑中必须保持不变的过滤、异常、日志、延迟和 fallback。
- [x] 每个关键需求至少有一条测试/编译/静态验证任务（Phase 4 T016-T020）。
- [x] 单元测试计划避免真实访问 Redis/OTS/Center/RocketMQ/FC/外部 HTTP（音序调用、Gemini、缓存、下载均以接口 + Fake 注入）。
- [x] 补充/纠正需求时，已规划同步更新 `spec.md`、`tasks.md`、`AGENTS.md`。
- [x] D005 验证计划覆盖 focused 单测、模块编译和静态 endpoint 路径审查。
- [x] D006 验证计划覆盖 HTTP URL/body/isVpc/taskObj 断言、focused 单测、模块编译和静态遗留代码审查。
- [x] D007 验证计划覆盖 Java 异步 FC event/cacheKey/Redis 成功失败超时断言、Python Redis RUNNING/SUCCESS/FAIL 写入测试、Java 编译测试与 Python py_compile/unittest。
- [x] D009 验证计划覆盖音序特征提取、Gemini prompt 注入、私聊/群聊上下文透传；临时视频 URL 回归待用户提供。
- [x] D012 验证计划覆盖 D1/D2 模板高置信命中、低置信不覆盖、分类字段覆盖且诊断字段保留，以及 `视频理解提示词V1_2.txt` 的 6 视频 D2 回归矩阵。
- [x] D013 验证计划覆盖 D3 模板高置信命中、D2 结尾 E 优先、冲突 evidence 清理，以及最新 6 视频 D2 回归矩阵。
- [x] D014 验证计划覆盖用户 D1 误判音序、真实新增 D1 移调音序、Fake Gemini 返回 D2 时工程覆盖为 D1，以及两个提示词 x 7 视频真实链路回归。
- [x] D016 验证计划覆盖萱草花 D5-D6 模板、D3/D5 组边界天数、低分人工介入、Gemini 失败兜底与提示词副本；本次只跑 Fake 单元测试，不跑真实 Gemini/FC/Redis。

## 备注

- 强制门禁已完成（Phase 1/2 结论见 `tasks.md`）。
- D007/D008 已实施并回填 `spec.md`/`tasks.md`/`AGENTS.md`：默认音序调用已从 transfer/fc HTTP 网关改为异步 FC + Redis，并新增替换后 prompt 日志，当前等待用户验收。
- D009 已进入实施：工程侧音序特征 JSON 与私聊弱上下文注入，部署视频 URL 回归等待用户补充可访问 URL。
- D010 已执行 D2 主进度回归；当前阻塞于本地 Redis 结果读取失败，未形成提示词识别效果对比结论。
- D011 已在 Redis 可访问后重跑 D2 主进度回归；真实链路可取得音序并进入 Gemini。旧提示词 `4/5 PASS`，V3 音序提示词 `1/5 PASS`，当前不建议把 V3 作为默认提示词，V2 多声部主旋律提取仍需后续优化。
- D012 已实施：新增 D1/D2 工程侧模板优先判定，高置信时覆盖课程分类字段。
- D013 已实施：扩展 D1/D2/D3 工程侧模板优先判定，新增 D2 结尾连续 E 音级优先规则；已完成聚焦单测与 `视频理解提示词V1_2.txt` 六视频真实链路回归，最新结果 6/6 PASS。当前残余风险为 D5/D6 仍依赖 Gemini，模型代理波动时仍可能影响非模板覆盖样本。
- D014 已实施：新增连续短语相似度和 D1 窄口径纠偏，新增 D1 视频两个提示词版本均已通过；最新 14 次真实链路回归为 13/14 PASS，唯一失败为 `视频理解的提示词V3 + V5-1`，属于 D5 仍依赖 Gemini/V3 提示词排除法过硬的既有风险。
- D016 已实施：修复 ClaudeCode 未完成的 D5/D6 萱草花工程模板与组内天数计算；`Gemini-Api` 聚焦单元测试通过（50 tests）。
