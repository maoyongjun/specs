# 功能规格：钢琴视频识别 id=-1 告警

**功能目录**：`102-piano-video-id-minus-one-warn`  
**创建日期**：`2026-06-18`  
**状态**：Implemented  
**输入**：修改 `C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\service\homeworkhandle\PianoVideoHomeWorkHandleServiceImpl.java`，如果识别到 `HomeWorkResultDto` 中的 `id` 是 `-1`，进行告警：“未能识别出学员交的作业所属的天数，需人工介入。”

## 背景

- 当前问题：钢琴视频识别结果中 `HomeWorkResultDto.id=-1` 表示未能识别作业所属天数；当前目标类只对识别超时、异常、标题为“未知”做告警，没有针对 `id=-1` 的人工介入告警。
- 当前行为：`PianoVideoHomeWorkHandleServiceImpl` 在初始缓存命中和首次等待结果成功后，会调用 `warnIfPianoVideoTitleUnknown(...)`；标题为“未知”时复用 `notifyPianoVideoRecognitionWarn(...)`，通过 `common_warn_sender` + `WX003` 发送告警，并用 Redis 去重。
- 目标行为：当初始缓存结果或等待结果中的 `HomeWorkResultDto.id` 为 `-1` 时，记录明确日志并触发现有告警通道，告警语义为“未能识别出学员交的作业所属的天数，需人工介入。”
- 非目标：不改变钢琴视频识别 FC 调用、缓存 key、等待时长、Redis TTL、告警模板编码 `WX003`、原有超时/异常/标题未知告警行为；不新增数据库、MQ 或新的外部接口。

## 用户场景与测试 *(必填)*

### 用户故事 1 - id=-1 时触发人工介入告警（优先级：P1）

作为运营或班主任，当钢琴视频识别结果无法判断作业所属天数时，系统要发出告警，提醒人工介入处理。

**独立测试**：构造 `HomeWorkResultDto.id=-1` 和包含 `externalKey/messageId` 的 `HomeWorkMessageDto`，验证新增判断认为应告警，并验证告警原因使用新的 `UNKNOWN_DAY` 语义。

**验收场景**：

1. **Given** 初始缓存命中结果 `id=-1`，**When** `handle(...)` 解析并准备返回该结果，**Then** 触发一次人工介入告警并仍返回原识别结果。
2. **Given** 异步等待结果 `id=-1`，**When** 首次等待成功返回该结果，**Then** 触发一次人工介入告警并仍返回原识别结果。

### 用户故事 2 - 非 id=-1 不影响旧流程（优先级：P2）

正常识别出有效天数时，不应新增额外告警，也不应改变原有标题未知、超时、异常告警。

**独立测试**：构造 `id=1`、`id=null`、`title=未知` 等结果，验证 `id=-1` 告警只在精确命中 `-1` 时成立；标题未知告警仍按旧逻辑成立。

**验收场景**：

1. **Given** 识别结果 `id=1`，**When** 结果返回，**Then** 不触发 `UNKNOWN_DAY` 告警。
2. **Given** 识别结果 `title=未知` 且 `id` 不是 `-1`，**When** 结果返回，**Then** 原有 `UNKNOWN_TITLE` 告警仍可触发。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `HomeWorkResultDto.id`：来源 `parseCachedResult(...)` -> `parseInnerResult(...)` 从缓存或异步 FC 返回文本解析；解析完成后、返回结果前读取；下游读取位置新增 `warnIfPianoVideoDayUnknown(...)` 或等价判断方法。
  - `cacheKey`：来源 `buildCacheKey(...)`，在读取缓存/等待结果前已生成；告警日志和去重上下文读取。
  - `HomeWorkMessageDto.externalKey`：来源上游消息 DTO；告警发送前读取；为空时现有逻辑跳过告警。
  - `HomeWorkMessageDto.messageId`：来源上游消息 DTO；用于日志和 Redis 去重值。
  - `WARN_REASON_*`：目标类常量；新增 `UNKNOWN_DAY`，传入现有 `notifyPianoVideoRecognitionWarn(...)`。
- 下游读取字段清单：
  - `warnIfPianoVideoTitleUnknown(...)` 读取 `title`、`question`、`isHomeWork`、`id`。
  - 新增 `warnIfPianoVideoDayUnknown(...)` 读取 `id`、`title`、`question`、`isHomeWork`。
  - `notifyPianoVideoRecognitionWarn(...)` 读取 `externalKey`、`messageId`、`cacheKey`、`warnReason`、`warnStage`，构造 `FcInvokeInput(service_sys/common_warn_sender)`。
  - `isTimeoutWarnRepeatLimited(...)` 读取 `externalKey`、`messageId`、`warnReason`、`warnStage`，写 Redis 去重 key。
- 空对象 / 占位对象风险：
  - `HomeWorkResultDto` 可能是 `new HomeWorkResultDto()`，此时 `id == null`，不得误报。
  - `HomeWorkMessageDto` 可能为空，现有告警逻辑会因 `externalKey` 为空跳过；新增逻辑需沿用该行为。
- 调用顺序风险：
  - 必须在 `parseCachedResult(...)` 或 `waitForRecognitionResult(...)` 成功拿到完整 `HomeWorkResultDto` 后判断 `id=-1`。
  - 不改变缓存读取、异步触发、等待、返回结果顺序。
- 旧逻辑保持：
  - 缓存命中仍直接返回缓存结果。
  - 异步等待成功仍直接返回等待结果。
  - 超时、异常、标题未知告警仍使用原有方法和去重规则。
  - 失败业务态 `BUSINESS_FAIL` 仍返回空结果，不新增 `id=-1` 判断。
- 需要用户确认的设计选择：
  - 无阻塞项。计划沿用现有 `common_warn_sender` + `WX003` 告警通道，不新增模板；“未能识别出学员交的作业所属的天数，需人工介入。”会作为日志和告警上下文字段记录。

## 边界情况

- `recognitionResult == null`：不告警。
- `recognitionResult.id == null`：不告警。
- `recognitionResult.id == -1`：触发 `UNKNOWN_DAY` 告警。
- `externalKey` 为空：沿用现有逻辑记录 skip 日志，不调用 `common_warn_sender`。
- 同一 `externalKey` 短时间重复：沿用现有 Redis 去重逻辑，避免重复告警。
- `id=-1` 且 `title=未知`：按计划会触发两个不同原因判断，但同一 `externalKey` 去重可能只实际发送一次；日志会保留两个判断点，避免破坏旧标题未知告警。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `PianoVideoHomeWorkHandleServiceImpl` 识别结果返回前检测 `HomeWorkResultDto.id == -1`。
- **FR-002**：系统 MUST 在命中 `id=-1` 时调用现有 `notifyPianoVideoRecognitionWarn(...)` 告警链路，告警原因使用新增的 `UNKNOWN_DAY` 或等价常量。
- **FR-003**：系统 MUST 在日志中明确输出“未能识别出学员交的作业所属的天数，需人工介入”语义，并包含 `cacheKey`、`messageId`、`externalKey`、`id`、`title` 等排查字段。
- **FR-004**：系统 MUST NOT 改变原有超时、异常、标题未知、缓存、等待、FC 调用、Redis TTL 和返回结果行为。
- **FR-005**：测试 MUST 覆盖 `id=-1` 告警判断、非 `-1` 不告警、`null` 不告警、标题未知旧判断不回归。

## 成功标准 *(必填)*

- **SC-001**：`id=-1` 结果在缓存命中和等待成功路径返回前均有人工介入告警判断。
- **SC-002**：新增或更新测试验证 `id=-1` 与非 `-1` 的分支行为。
- **SC-003**：目标模块 focused test 或编译通过，旧标题未知告警判断不回归。

## 假设

- `HomeWorkResultDto.id=-1` 是无法识别作业所属天数的统一语义。
- 现有 `WX003` 告警模板可以承载钢琴视频识别人工介入提醒；不需要新增模板编码。
- 若后续需要真正把动态文案渲染进企微模板，需要另行确认 `common_warn_sender` 是否支持文案变量。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成历史问题防漏分析和强制门禁检查。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：在 `PianoVideoHomeWorkHandleServiceImpl` 新增 `WARN_REASON_UNKNOWN_DAY` 和人工介入文案；新增 `warnIfPianoVideoDayUnknown(...)`、`notifyPianoVideoUnknownDayWarn(...)`、`isUnknownDay(...)`；在初始缓存命中和首次等待成功返回前新增 `id=-1` 告警判断；新增 `PianoVideoHomeWorkHandleServiceImplTest` 覆盖判断边界。
- 影响范围：仅影响钢琴视频识别结果成功返回前的告警判断；不改变异步识别、缓存、等待、超时、异常、Redis TTL、告警模板编码和返回结果。
- 测试命令：`mvn -Dtest=PianoVideoHomeWorkHandleServiceImplTest test`；`mvn -DskipTests compile`
- 测试结果：通过，focused test 为 `Tests run: 2, Failures: 0, Errors: 0, Skipped: 0`；compile 为 `BUILD SUCCESS`。
- 自检结论：`id=-1` 会进入 `UNKNOWN_DAY` 告警判断；`id=null`、`id=1` 不命中；`title=未知` 旧判断不回归。

### D003 - 纠正记录模板

- 触发原因：用户补充、测试失败、代码审查发现、参数遗漏或调用顺序问题。
- 修正内容：写清楚旧口径和新口径。
- 文档同步：确认 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 是否已同步。
- 验证结果：记录测试或静态检查结果。
