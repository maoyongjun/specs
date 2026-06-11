# 功能规格：学习之星奖状 OOM 修复

**功能目录**：`077-learning-star-certificate-oom-fix`  
**创建日期**：`2026-06-11`  
**状态**：Implemented  
**输入**：`LearningStarCertificateServiceImpl.java` 处理学习之星奖状候选营期异常，日志显示 `java.lang.OutOfMemoryError: Java heap space`，发生在 `学习之星奖状处理候选营期异常,campDateId=3933,chatId=YangFan_1,empId=2250`。

## 背景

- 当前问题：学习之星奖状定时任务会全量扫描钢琴 AI 营期，对单个候选营期一次性加载全部学员、预检结果、`CompletableFuture` 和渲染结果；奖状渲染器每次重复读取模板并重复生成大 Base64 SVG，堆内存峰值过高。
- 当前行为：`processCampCandidate` 对一个候选营期调用 `selectStudents` 一次性取全量学员，再在 `processCampStudents` 中一次性提交所有并发渲染任务；并发路径还在渲染前构造 `LearningStarDelaySendInput`，导致图片 URL 可能为空。
- 目标行为：候选营期只扫描可能命中当天 D3/D4 的数据，学员按 keyset 分批处理，渲染按小批次提交，图片 URL 在渲染成功后再构造发送入参，WX_004 只统计成功投递 MQ 的学员。
- 非目标：不新增对外接口，不改学习之星消息格式、MQ tag、Redis key 前缀、OTS 标签规则、D3/D4 规则和测试发送入口。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 大营期不会撑爆堆内存（优先级：P1）

运维希望再次执行学习之星奖状任务时，即使某个销售 `chatId` 窗口内好友关系很多，也不会一次性把所有学员和所有渲染任务保留在堆内。

**独立测试**：构造超过两批的学员数据，断言服务按批查询、按批预检/渲染/投递，并在每批完成后释放锁和临时结果。

**验收场景**：

1. **Given** 某候选营期有超过 `studentBatchSize` 的学员，**When** 执行学习之星奖状任务，**Then** 系统按 `id` keyset 分批处理，不一次性创建所有 future。
2. **Given** 某批学员超过 `renderBatchSize`，**When** 渲染奖状，**Then** 同一批最多提交 `renderBatchSize` 个渲染任务。

### 用户故事 2 - 图片 URL 完整后才允许发送（优先级：P1）

运营希望收到的学习之星图片消息一定使用 OSS/CDN URL，不能出现空图片消息。

**独立测试**：Mock 渲染返回 URL，断言 RocketMQ 入参 `certificateImageUrl` 和第一条图片消息 `url` 均等于该 URL；Mock 渲染失败时断言不投递 MQ。

**验收场景**：

1. **Given** 渲染和 OSS 上传成功返回 `https://cdn/x.png`，**When** 投递延迟消息，**Then** 延迟消息体中的 `certificateImageUrl` 与图片消息 `url` 均为该 URL。
2. **Given** 渲染返回空 URL，**When** 当前学员处理，**Then** 不投递 MQ，计入 `certificateUploadFail`。

### 用户故事 3 - 通知数量按成功投递统计（优先级：P2）

销售收到 WX_004 通知时，触达学员数必须等于本次真正成功投递延迟消息的学员数。

**独立测试**：Mock 部分学员 MQ 投递失败，断言 WX_004 `sendNums` 只包含成功投递数量。

**验收场景**：

1. **Given** 3 个学员渲染成功但只有 2 个 MQ 投递成功，**When** 营期候选处理结束，**Then** WX_004 `sendNums = 2`。
2. **Given** 成功投递数为 0，**When** 营期候选处理结束，**Then** 不发送 WX_004。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `campDateId/chatId/startTime/classTime`：来源 `LearningStarCampCandidateDto`；在候选 SQL 返回时赋值；下游用于渠道、天数和学员查询。
  - `studentBatchSize`：来源 `LearningStarCertificateConfig`；运行时通过 clamp 得到 `1..200`；下游用于学员分页查询。
  - `renderBatchSize`：来源 `LearningStarCertificateConfig`；运行时通过 clamp 得到 `1..4`；下游用于并发渲染小批次。
  - `certificateUrl`：来源 `renderUploadCertificate`；渲染成功后赋值；下游 `buildDelaySendInput` 和图片消息读取。
- 下游读取字段清单：
  - `sendDelayMessage` 读取 `campDateId/externalUserId/messages`。
  - `buildLearningStarJuziMessageDto` 读取 `externalUserId/qyvxUserId/corpId/messageType/payload.url/payload.text`。
  - `notifyCertificateSendComplete` 读取成功投递结果中的 `externalUserId/empId/campDateId/qyvxUserId/sendNums`。
- 空对象 / 占位对象风险：
  - 原并发路径提前构造 `certificateUrl=null` 的 `LearningStarDelaySendInput`；本次改为渲染成功后构造，并在投递前校验图片 URL。
- 调用顺序风险：
  - 必须保持：预检通过并加锁 -> 渲染上传得到 URL -> 构造延迟发送入参 -> 投递 MQ -> 写 queued key -> 计入通知数量。
- 旧逻辑保持：
  - D3/D4 判断、渠道解析、OTS 标签匹配、昵称优先级、Redis sent/queued/lock/scheduled key、RocketMQ 延迟投递、FC 消费调度、已发奖状打标和测试发送均保持。
- 需要用户确认的设计选择：
  - 无。本次为内存和参数完整性修复，不改变业务语义。

## 边界情况

- 候选营期为空：返回空 summary。
- 学员分页某批为空：结束该候选营期。
- `studentBatchSize` 配置小于 1 或大于 200：回落到允许范围。
- `renderBatchSize` 配置小于 1 或大于 4：回落到允许范围，确保不突破既定最大并发 4。
- 单学员 OTS 查询失败、标签不匹配、unionId 为空、渲染失败或 MQ 投递失败：只影响该学员，其他学员继续。
- 批次内部分锁已获取：当前批处理完成或异常退出时释放本批锁。
- WX_004 通知发送失败：仅记录异常，不影响主流程。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 将候选营期 SQL 限定为当天可能命中 D3/D4 的 `class_time` 窗口，避免全量钢琴 AI 营期进入 Java 层。
- **FR-002**：系统 MUST 按 `id` keyset 分批查询候选学员，默认每批 50，最大 200。
- **FR-003**：系统 MUST 按小批次提交渲染任务，默认每批 4，最大 4。
- **FR-004**：系统 MUST 在渲染成功拿到非空 URL 后再构造 `LearningStarDelaySendInput` 和 `messages`。
- **FR-005**：系统 MUST NOT 投递 `certificateImageUrl` 或图片消息 `url` 为空的延迟消息。
- **FR-006**：系统 MUST 让 WX_004 `sendNums` 等于成功投递 MQ 的学员数。
- **FR-007**：渲染器 MUST 缓存模板 data URI 和尺寸，并避免同一背景 data URI 在 SVG 中重复写两份。
- **FR-008**：单元测试 MUST 覆盖分批处理、URL 回填、异常隔离、WX_004 投递成功口径和渲染器连续渲染。

## 成功标准 *(必填)*

- **SC-001**：超过两批的学员数据处理时，服务不会一次性保留全量学员、预检结果、future 和渲染结果。
- **SC-002**：并发渲染成功后的 MQ 入参图片 URL 非空且与渲染返回 URL 一致。
- **SC-003**：渲染失败或 MQ 投递失败只影响当前学员，不让候选营期整体抛 `CompletionException`。
- **SC-004**：WX_004 通知数量等于成功投递 MQ 的学员数。
- **SC-005**：目标测试 `LearningStarCertificateServiceImplTest` 和 `LearningStarCertificateRendererTest` 通过。

## 假设

- `drh_emp_external_user.id` 为自增主键，可用于 keyset 分页。
- `class_time` 与业务日均按 `Asia/Shanghai` 口径保存；SQL 使用日期窗口仅用于减少扫描量，Java 层仍保留 D3/D4 精确判断。
- 修复部署后可以重跑任务；已存在 `sent` 或 `queued` Redis key 的学员会被跳过，不会重复发送。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成 OOM 根因、参数完整性和调用顺序风险分析。

### D002 - 实现记录

- 已实现候选营期窗口预筛、学员 keyset 分批、渲染小批次、图片 URL 回填、投递成功口径通知和渲染器模板缓存。
- 测试命令：`mvn -pl ai -am "-Dtest=LearningStarCertificateServiceImplTest,LearningStarCertificateRendererTest" test`。
- 测试结果：待回填。
