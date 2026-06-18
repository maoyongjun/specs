# 任务清单：钢琴视频告警模板与当天提交超两次提醒

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于 `C:\workspace\ju-chat\fc\sop-reply` 模块的钢琴视频识别与 SOP 回复链路。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和测试落点。
  - 未识别天数告警：`PianoVideoHomeWorkHandleServiceImpl.warnIfPianoVideoDayUnknown(...)` -> `notifyPianoVideoRecognitionWarn(...)` -> `service_sys/common_warn_sender`。
  - 当天提交次数：`SopReply.handleRequest(...)` 中作业识别通过后可按自然日独立计数，不复用课程/作业天数维度的 `currentDay/submitDay/commentIndex/submitDayCommentIndex`。
  - 测试落点：`fc/sop-reply/src/test/java`。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
  - `warnReason` 为字符串常量；`sendTemplateList` 当前固定 `WX003`。
  - `skuId` 为 `Integer`，钢琴 SKU 为 `4`。
  - 自然日日期需在当前层通过 `LocalDate.now(ZoneId.of("Asia/Shanghai"))` 现算现用；`messageId` 可用于同一消息去重。
- [x] T004 确认配置来源、环境变量、Redis key、MQ topic/tag、Feign/FC/HTTP 调用或数据库表是否受影响。
  - 复用 `service_sys/common_warn_sender` FC。
  - 提交超两次提醒需要新增 Redis 自然日计数 key、消息去重 key 和告警去重 key；不涉及 MQ、数据库、Feign 或新 HTTP 接口。
- [x] T005 确认已有旧逻辑中必须保持不变的过滤、幂等、异常处理、日志、延迟和 fallback。
  - `WX003` 旧告警、识别缓存/等待、SOP 路由、发送、计数持久化不变。

**检查点**：T001-T005 已在计划阶段完成；实施前需重新快速复查。

## Phase 2：风险门禁

- [x] T006 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参。
  - `HomeWorkResultDto` 可为空或 `id=null`，只影响 `WX_005` 不触发。
  - `WebChatVoiceDto` 可能缺少 `external_user_id` 或无法构造 `externalKey`，`WX_006` 应跳过并记录日志。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段。
  - `WX_006` 判断必须放在识别通过且 `recognitionOnly` 判断之后；不依赖后续 SOP 路由字段补齐。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用。
  - `WX_005` 读取 `warnReason/externalKey/messageId`；`WX_006` 读取 `skuId/external_user_id/messageId/naturalDate/externalKey`。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为。
  - 会新增一次条件性 FC 告警调用和一个 Redis 去重 key；不改变原 SOP 主流程。
- [x] T010 对需要用户确认的业务语义变化做记录；未确认前不得实现该变化。
  - 用户已确认：“当天”按自然日，与之前课程/作业天数业务含义无需相同；同一自然日只提醒一次。
- [x] T011 为每个关键行为建立测试映射，至少覆盖正常路径、边界路径和不回归路径。
  - `UNKNOWN_DAY` -> `WX_005`。
  - `TIMEOUT/EXCEPTION/UNKNOWN_TITLE` -> `WX003`。
  - 钢琴同一自然日第 3 次 -> `WX_006`；第 2 次、非钢琴、`recognitionOnly` 不触发；同一 `messageId` 重试不重复计数。

**检查点**：T006-T011 已有明确结论；等待用户确认计划后进入实现。

## Phase 3：实现

- [x] T012 将钢琴视频识别告警模板从固定常量改为按 `warnReason` 选择：`UNKNOWN_DAY` 使用 `WX_005`，其他保持 `WX003`。
- [x] T013 在 `SopReply` 中新增钢琴自然日提交超两次提醒常量、判断方法、FC 调用方法、Redis 自然日计数方法和去重方法。
- [x] T014 在识别通过且 `recognitionOnly` 判断之后调用自然日提交计数与提醒判断，保持 SOP 主流程不变。
- [x] T015 如测试需要，提取最小 package-private/static 判断方法或模板选择方法，避免单元测试真实访问 Redis/FC。
- [x] T016 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [x] T017 新增或更新单元测试，覆盖模板选择和提交次数判断。
- [x] T018 测试中断言关键下游模板编码或判断结果，不只断言最终返回。
- [x] T019 验证 `WX003` 旧逻辑、`id=null`、非钢琴、`recognitionOnly`、同一消息重试、第 2 次不回归。
- [x] T020 运行目标模块 focused test 和编译命令，并记录结果。
- [x] T021 搜索确认新增模板码、去重 key 和调用点符合规格。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `103-piano-video-warn-template-and-over-submit` 规格文档，确认 `PianoVideoHomeWorkHandleServiceImpl` 当前固定 `WX003` 模板、`SopReply` 已有作业天数维度计数和钢琴 SKU 判定。
- 验证方式：读取 `PianoVideoHomeWorkHandleServiceImpl`、`SopReply`、`HomeWorkMessageDto`、模板目录和当前 git status；使用代码搜索确认 `common_warn_sender`、`sendTemplateList`、Redis dayCount key 和测试落点。
- 自检结论：计划阶段满足强制门禁；用户已确认超两次提醒按自然日口径，尚未修改业务代码。

### D002 - 实现记录

- 实现内容：`PianoVideoHomeWorkHandleServiceImpl` 按 `warnReason` 选择告警模板，`UNKNOWN_DAY` 使用 `WX_005`，其他继续 `WX003`；`SopReply` 新增钢琴自然日提交计数、同 `messageId` 去重、同自然日告警去重和 `WX_006` 告警发送；`RedisClient` 新增 `incrementWithExpire(...)` 用于原子递增自然日计数；新增/更新 focused JUnit 测试。
- 测试命令：`mvn "-Dtest=PianoVideoHomeWorkHandleServiceImplTest,SopReplyTest" test`；`mvn -DskipTests compile`
- 测试结果：通过，focused test 为 `Tests run: 5, Failures: 0, Errors: 0, Skipped: 0`；compile 为 `BUILD SUCCESS`。
- 自检结论：`id=-1` 告警模板为 `WX_005`；原 `UNKNOWN_TITLE/TIMEOUT` 回落 `WX003`；钢琴同一自然日第 3 次及以上提交进入 `WX_006` 判断，第 2 次、非钢琴、`recognitionOnly`、同一消息重试不触发；SOP 路由、发送和旧课程天数计数不变。

### D003 - 纠正记录模板

- 触发原因：说明为什么需要纠正。
- 修正内容：说明具体修正。
- 文档同步：说明同步了哪些文件。
- 验证结果：说明测试或静态验证。

### D003 - 自然日口径纠正

- 触发原因：用户明确补充“超过三次的告警，按自然日来，与之前的业务含义无需相同”。
- 修正内容：将 `WX_006` 从课程/作业天数口径改为自然日独立计数；实现任务调整为新增自然日计数 key、消息去重 key 和自然日告警去重 key。
- 文档同步：已同步 `spec.md`、`tasks.md`、`checklists/requirements.md`。
- 验证结果：计划阶段文档更新，尚未修改业务代码。

### D004 - 阈值纠正为超过两次

- 触发原因：用户补充“超过三次，改为超过两次”。
- 修正内容：将 `WX_006` 触发阈值从自然日第 4 次及以上，改为自然日第 3 次及以上；第 2 次及以下不触发。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 验证结果：计划阶段文档更新，尚未修改业务代码。
