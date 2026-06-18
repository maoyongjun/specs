# 功能规格：钢琴视频告警模板与当天提交超两次提醒

**功能目录**：`103-piano-video-warn-template-and-over-submit`  
**创建日期**：`2026-06-18`  
**状态**：Implemented  
**输入**：用户补充要求：“未能识别天数的告警使用WX_005，钢琴当天提交超过三次进行提醒，使用WX_006。”后续纠正为“超过三次改为超过两次”。

## 背景

- 当前问题：`PianoVideoHomeWorkHandleServiceImpl` 已能在 `HomeWorkResultDto.id=-1` 时触发 `UNKNOWN_DAY` 告警，但当前所有钢琴视频识别告警共用 `WX003`；`SopReply` 已维护作业天数维度的提交/点评次数，但没有对钢琴当天提交超过两次单独提醒。
- 当前行为：
  - `PianoVideoHomeWorkHandleServiceImpl.notifyPianoVideoRecognitionWarn(...)` 构造 `service_sys/common_warn_sender` 参数，`sendTemplateList` 固定使用 `WX003`。
  - `SopReply` 在识别通过后读取 `ReviewProgressSnapshot`，通过 `commentIndex` 和 `submitDayCommentIndex` 表示本次提交在当前天/提交天的序号，成功发送后通过 Redis key `ai:sopReply:homework:review:dayCount:{external_user_id}:{day}` 持久化；这套计数是课程/作业天数维度，不是自然日维度。
  - `SopReply` 通过 `SKU_PIANO = 4` 区分钢琴业务。
- 目标行为：
  - `HomeWorkResultDto.id=-1` 的未能识别天数告警，改用模板 `WX_005`。
  - 保持超时、异常、`title=未知` 等旧识别告警模板不变，仍使用现有 `WX003`。
  - 钢琴自然日提交超过两次时，通过 `service_sys/common_warn_sender` 发送模板 `WX_006` 提醒；该自然日计数与原课程/作业天数计数互不复用。
- 非目标：
  - 不改变钢琴视频识别 FC 调用、缓存 key、等待时长、Redis TTL、识别结果返回逻辑。
  - 不新增数据库、MQ 或对外 API。
  - 不改变 SOP 路由、自动回复发送、未来作业固定回复和已存在的点评进度持久化逻辑。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 未识别天数使用专用模板（优先级：P1）

作为运营或班主任，当钢琴视频识别无法判断作业所属天数时，需要通过专用模板区分“未识别天数”问题。

**独立测试**：构造 `WARN_REASON_UNKNOWN_DAY` 或等价输入，验证模板选择结果为 `WX_005`；构造超时/异常/标题未知，验证仍为 `WX003`。

**验收场景**：

1. **Given** 识别结果 `HomeWorkResultDto.id=-1`，**When** 返回前触发 `UNKNOWN_DAY` 告警，**Then** `common_warn_sender` 的 `sendTemplateList` 使用 `WX_005`。
2. **Given** 识别超时、异常或 `title=未知`，**When** 触发原有识别告警，**Then** `sendTemplateList` 仍使用 `WX003`。

### 用户故事 2 - 钢琴当天提交超过两次提醒（优先级：P1）

作为运营或班主任，当钢琴学员当天作业提交次数超过两次时，需要收到单独提醒，便于人工关注重复提交情况。

**独立测试**：构造钢琴 SKU、自然日累计提交次数为第 3 次的场景，验证会选择模板 `WX_006`；构造非钢琴、自然日第 2 次及以下、`recognitionOnly` 的场景，验证不提醒。

**验收场景**：

1. **Given** 钢琴学员在同一自然日内第 3 次提交作业，**When** `SopReply` 识别通过且不是 `recognitionOnly`，**Then** 调用 `common_warn_sender`，`sendTemplateList` 使用 `WX_006`。
2. **Given** 钢琴学员在同一自然日内第 2 次提交作业，**When** `SopReply` 处理，**Then** 不触发 `WX_006`。
3. **Given** 非钢琴 SKU 在同一自然日内提交次数超过两次，**When** `SopReply` 处理，**Then** 不触发“当天提交超过两次”提醒。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `warnReason`：来源 `PianoVideoHomeWorkHandleServiceImpl` 内部常量；在调用 `notifyPianoVideoRecognitionWarn(...)` 前确定；下游用于选择 `sendTemplateList` 模板。
  - `HomeWorkResultDto.id`：来源钢琴视频识别缓存/异步结果解析；在 `warnIfPianoVideoDayUnknown(...)` 判断前已完成解析。
  - `externalKey`：来源 `HomeWorkMessageDto.externalKey` 或 `SopReply.buildExternalKey(userMsg)`；在调用 `common_warn_sender` 前需要非空。
  - `skuId`：来源 `SopReply.resolveSkuId(request, userMsg)`；用于判断是否钢琴 `SKU_PIANO = 4`。
  - `naturalDate`：来源 `LocalDate.now(ZoneId.of("Asia/Shanghai"))`，格式 `yyyyMMdd`；用于自然日提交次数 Redis key。
  - `messageId`：来源 `WebChatVoiceDto.messageId`；用于同一自然日同一消息的计数去重。
  - `currentDay`、`submitDay`、`commentIndex` / `submitDayCommentIndex`：仍按旧逻辑计算并用于 SOP 路由，不参与 `WX_006` 自然日计数。
- 下游读取字段清单：
  - `notifyPianoVideoRecognitionWarn(...)` 读取 `externalKey`、`messageId`、`warnReason`、`warnStage`，并构造 `FcInvokeInput(service_sys/common_warn_sender)`。
  - 新增的自然日提交超两次提醒方法读取 `external_user_id`、`messageId`、`externalKey`、`naturalDate`、`skuId`、自然日累计提交次数。
  - Redis 计数/去重方法读取 `external_user_id`、`messageId`、`naturalDate` 和提醒原因。
- 空对象 / 占位对象风险：
  - `HomeWorkResultDto` 可能为空或 `id == null`，不得误触发 `WX_005`。
  - `HomeWorkMessageDto.externalKey` 为空时沿用现有 skip 行为，不调用 `common_warn_sender`。
  - `WebChatVoiceDto.external_user_id` 或 `externalKey` 无法构造时，提交超两次提醒应记录 skip 日志并不调用 FC。
- 调用顺序风险：
  - `WX_005` 模板选择必须发生在构造 `sendTemplateList` 前。
  - `WX_006` 自然日计数必须发生在作业识别通过且 `recognitionOnly` 判断之后；不得依赖后续课程天数、SOP 配置拉取、路由匹配和发送流程。
- 旧逻辑保持：
  - 超时、异常、标题未知仍走原告警链路，模板保持 `WX003`。
  - `id=-1` 判断仍在初始缓存命中和首次等待成功返回前执行。
  - `SopReply` 的 recent process 去重、手动沉默、recognitionOnly、未来作业固定回复、SOP 发送、点评进度持久化不变；`recognitionOnly` 不产生 `WX_006` 计数或告警副作用。
- 需要用户确认的设计选择：
  - 用户已确认“当天提交超过两次”按自然日判断，与原课程/作业天数业务含义无需相同。
  - `WX_006` 计划对同一 `external_user_id + naturalDate` 做 Redis 去重，避免第 3、4、5 次连续重复提醒；计数和去重 TTL 计划覆盖到下一个自然日后，暂定 2 天。

## 边界情况

- `id=-1` 且 `externalKey` 为空：记录 skip 日志，不调用 `common_warn_sender`。
- `warnReason` 不是 `UNKNOWN_DAY`：模板保持 `WX003`。
- 钢琴同一自然日第 2 次提交：不触发 `WX_006`。
- 钢琴同一自然日第 3 次提交：触发 `WX_006`。
- 钢琴补交过去作业或预习未来作业：只要属于同一自然日内第 3 次及以上提交，也可触发 `WX_006`。
- 非钢琴 SKU：不触发 `WX_006`。
- `recognitionOnly=true`：不计入自然日提交次数，不触发 `WX_006`。
- 同一 `messageId` 重试：只计数一次。
- Redis 去重写入失败：记录日志并按 fail-open 策略允许提醒，避免漏告警。
- FC 调用失败：记录错误日志，不影响原 SOP 回复流程。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `UNKNOWN_DAY` 未识别天数告警中使用模板 `WX_005`。
- **FR-002**：系统 MUST 保持超时、异常、标题未知等原有钢琴视频识别告警继续使用 `WX003`。
- **FR-003**：系统 MUST 在钢琴 SKU 且同一自然日提交次数超过两次时调用 `common_warn_sender`，模板使用 `WX_006`。
- **FR-004**：系统 MUST NOT 改变 SOP 回复原有路由、发送、计数持久化、识别缓存、识别等待和异常处理行为。
- **FR-005**：系统 MUST 使用独立 Redis key 维护钢琴自然日提交次数，不能复用 `KEY_HOMEWORK_REVIEW_DAY_COUNT` 的课程/作业天数计数。
- **FR-006**：测试 MUST 覆盖 `WX_005` 模板选择、旧 `WX003` 不回归、`WX_006` 触发与不触发边界。

## 成功标准 *(必填)*

- **SC-001**：`id=-1` 告警参数中的 `sendTemplateList` 为 `["WX_005"]`。
- **SC-002**：钢琴同一自然日第 3 次及以上提交会进入 `WX_006` 提醒判断，第 2 次及以下不进入。
- **SC-003**：focused test 和模块编译通过，旧 `WX003` 行为不回归。

## 假设

- `WX_005`、`WX_006` 是 `common_warn_sender` 接受的准确模板编码，包含下划线。
- 自然日按 `Asia/Shanghai` 时区计算，Redis key 中日期格式使用 `yyyyMMdd`。
- `WX_006` 只需提醒一次同一学员同一自然日超过两次的事实，不需要每次超过两次都重复发送。
- 如果以上假设被推翻，需要追加 D003 纠正记录并重新确认实施。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成目标类、`SopReply` 计数来源、Redis key、FC 告警调用和测试落点的初步确认。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：`PianoVideoHomeWorkHandleServiceImpl` 新增 `WX_005` 模板选择，`UNKNOWN_DAY` 使用 `WX_005`，其他告警继续 `WX003`；`SopReply` 新增钢琴自然日提交计数、同 `messageId` 去重、同自然日告警去重和 `WX_006` 告警发送；`RedisClient` 新增 `incrementWithExpire(...)` 支持原子递增并设置 TTL；新增/更新 focused JUnit 测试。
- 影响范围：仅新增条件性告警和独立 Redis 自然日计数 key，不改变 SOP 回复路由、发送、原课程天数计数、识别缓存、识别等待和异常处理。
- 测试命令：`mvn "-Dtest=PianoVideoHomeWorkHandleServiceImplTest,SopReplyTest" test`；`mvn -DskipTests compile`
- 测试结果：通过，focused test 为 `Tests run: 5, Failures: 0, Errors: 0, Skipped: 0`；compile 为 `BUILD SUCCESS`。
- 自检结论：`id=-1` 告警模板为 `WX_005`；原 `UNKNOWN_TITLE/TIMEOUT` 回落 `WX003`；钢琴同一自然日第 3 次及以上提交进入 `WX_006` 判断，第 2 次、非钢琴、`recognitionOnly`、同一消息重试不触发。

### D003 - 纠正记录模板

- 触发原因：用户补充、测试失败、代码审查发现、参数遗漏、调用顺序问题或业务口径调整。
- 修正内容：写清楚旧口径和新口径。
- 文档同步：确认 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 是否已同步。
- 验证结果：记录测试或静态验证结果。

### D003 - 自然日口径纠正

- 触发原因：用户明确补充“超过三次的告警，按自然日来，与之前的业务含义无需相同”。
- 修正内容：将 `WX_006` 判断从 `submitDay == currentDay` 的课程/作业天数口径，改为独立自然日计数口径；自然日使用 `Asia/Shanghai` 的 `yyyyMMdd`。
- 文档同步：已同步 `spec.md`、`tasks.md`、`checklists/requirements.md`。
- 验证结果：计划阶段文档更新，尚未修改业务代码。

### D004 - 阈值纠正为超过两次

- 触发原因：用户补充“超过三次，改为超过两次”。
- 修正内容：将 `WX_006` 触发阈值从自然日第 4 次及以上，改为自然日第 3 次及以上；第 2 次及以下不触发。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 验证结果：计划阶段文档更新，尚未修改业务代码。
