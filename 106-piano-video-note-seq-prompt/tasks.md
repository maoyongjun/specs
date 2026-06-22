# 任务清单：钢琴作业视频 V2 先取音序再注入提示词

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查需求与 `AGENTS.md`：本次目标项目 `fc`、模块 `Gemini-Api`，业务链路为钢琴作业视频 V2 识别（`PianoHomeWorkVideoV2Task`）。
- [x] T002 确认真实入口与调用链：入口 `handleRequest` → `analyzeVideo` → `callFileUrl`/`callInlineData`/`callAuto` → `geminiCaller.*`。测试落点 `PianoHomeWorkVideoV2TaskTest`（基于接口 + Fake）。FC 调用工具 `FcInvokeUtils.doSyncTask*`、入参 `FcInvokeInput`，本模块已由 `AppTask` 使用。
- [x] T003 确认关键参数：`prompt`/`file_url`/`taskId` 来自请求；`VideoToNoteSeq` event 字段 `video_path`（来自 `file_url`）；返回结构 `{taskId,videoPath,sampleRate,noteCount,notes:[{note,midi,start,duration,frequency,confidence}]}`（来源 spec 105 `index.py`/`note_extractor.py`，`note` 为 ASCII 音名）。
- [x] T004 确认配置/外部调用影响：新增一次同步 FC 自调用（`FcOssFFmpeg-3278/VideoToNoteSeq`，可 env 覆盖服务/函数名）；不涉及新增 Redis key、MQ topic/tag、数据库表；缓存 key/TTL、分发锁不变。
- [x] T005 确认必须保持不变的旧逻辑：RUNNING/SUCCESS/FAIL 三态缓存与字段与 TTL（1800s）、分发锁释放、MDC requestId、入参脱敏日志、三输入模式与 401/403 不回退、`resolveConfig`/`resolveMimeType` 等、`validateRequired` 错误口径（`prompt is empty`/`file_url is empty`）。

**检查点**：T001-T005 已完成，可进入实现前的风险门禁。

## Phase 2：风险门禁

- [x] T006 占位对象检查：新增 `FcInvokeInput` 在调用前 set `serviceName`/`functionName`/`taskObj(event 含 video_path)`，非空占位；`event` 至少含 `video_path`，不传空 JSON 下游。结论：无占位风险。
- [x] T007 调用后赋值检查：存在「`event.video_path` 调用前赋值 → `VideoToNoteSeq` 返回后才有 `notes` → 替换后才有最终 `prompt`」时序；`noteSeqText` 在替换前由 `buildNoteSequenceText` 现算；`prompt`/`file_url` 在音序调用前已 `validateRequired`。结论：时序明确，无「下游已读但尚未赋值」风险。
- [x] T008 下游读取来源检查：`VideoToNoteSeq` 读 `event.video_path`（=file_url，已校验非空）；`buildNoteSequenceText` 读 `notes[*].note`（缺失/空 → 跳过/空文本）；Gemini 读替换后的 `prompt` 与 `fileUri`（均有来源）。结论：全部有来源。
- [x] T009 影响范围检查：新增一次同步远程调用（FC→FC），插在 Gemini 调用之前——属「新增远程调用 + 调整调用前处理」，已通过 AskUserQuestion 取得用户明确要求；不改接口契约、不改 MQ body、不改 Redis TTL、不改数据库；Gemini 调用契约保持（仍传视频）。
- [x] T010 业务语义确认：①音名序列文本、②仍传视频、③失败/空也继续——三项均经 AskUserQuestion 确认并记入 `spec.md` D001。结论：无未确认的业务语义变化。
- [x] T011 测试映射：取音序下游参数、音名拼接、占位符替换、失败继续、空音序、无占位符、旧逻辑不回归——逐条在 Phase 4 建立断言。

**检查点**：T006-T011 已有明确结论，无高风险阻塞，可进入实现。

## Phase 3：实现

- [x] T012 在 `PianoHomeWorkVideoV2Task` 新增：服务/函数名常量（`DEFAULT_NOTE_SEQ_SERVICE=FcOssFFmpeg-3278`、`DEFAULT_NOTE_SEQ_FUNCTION=VideoToNoteSeq`）与 env 覆盖键、占位符常量 `${audioseq}`；新增 `NoteSequenceCaller` 接口与 `DefaultNoteSequenceCaller`（委托 `FcInvokeUtils.doSyncTaskReturnJSONObj`）；构造函数注入该接口（无参默认构造补默认实现）。
- [x] T013 在 `analyzeVideo` 的 `validateRequired(prompt)`、`validateRequired(file_url)` 之后、`resolveConfig` 之前：构造 `event{video_path,(task_id)}` → 调用音序（try/catch，失败 warn + 空文本）→ `buildNoteSequenceText` → `replacePromptPlaceholder` 替换 `${audioseq}`；其余链路保持不变（仍传视频）。
- [x] T014 保持未声明的旧行为不变（缓存/锁/MDC/脱敏/三模式/回退/错误口径）。
- [x] T015 同步更新 `spec.md` D002、`tasks.md` D002 执行记录。
- [x] T021 [D005] 在 `FcInvokeUtils` 增加显式北京 VPC 同步调用方法（或等价显式路径），复用 `clientBeijing` / `runtimeBeijing`，不改变现有 `doSyncTask` 默认 endpoint 行为。
- [x] T022 [D005] 将 `PianoHomeWorkVideoV2Task.DefaultNoteSequenceCaller` 改为调用北京 VPC 同步 JSON 方法，保持 service/function/event/traceId 与失败继续逻辑不变。
- [x] T023 [D005] 避免扩大影响：不改 `doTask`、`doTaskWithDelay`、默认 `doSyncTask` 语义；如新增公共方法，命名需体现北京 VPC 同步调用用途。
- [x] T027 [D006] 将 `PianoHomeWorkVideoV2Task.DefaultNoteSequenceCaller` 改为 POST transfer/fc HTTP 网关，请求 body 包含 `taskObj`、`serviceName`、`functionName`、`isVpc=true`。
- [x] T028 [D006] 增加 transfer/fc URL 默认常量与可选 env 覆盖，默认值为 `http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/ai/transfer/fc`。
- [x] T029 [D006] 兼容解析 transfer/fc 返回：直接音序 JSON、`data` 对象/字符串、`result` 对象/字符串；无法解析按异常抛出，由上层既有失败继续策略兜底。
- [x] T030 [D006] 移除 D005 新增但不再使用的 `FcInvokeUtils.doSyncTaskWithBeijingVpc` 与 `doSyncTaskReturnJSONObjWithBeijingVpc`，保持默认 `doSyncTask`、`doTaskWithDelay` 不变。
- [x] T041 [D007] Java 默认音序调用从 transfer/fc HTTP 改为异步 FC：构造 `FcInvokeInput(serviceName,functionName,event)`，event 含 `video_path`、可选 `task_id`、内部音序 `cacheKey`，调用 `FcInvokeUtils.doTask`。
- [x] T042 [D007] Java 新增 Redis 轮询：读取音序 `cacheKey` 的 `status/result/error`，`SUCCESS.result` 解析为音序 JSON，`FAIL`/超时/空结果抛异常交由既有失败继续策略兜底。
- [x] T043 [D007] Java 抽象异步调用与 Redis 读取为可注入接口，测试不真实访问 FC/Redis；清理 D006 默认 HTTP 调用相关未使用代码/import。
- [x] T044 [D007] Python `videoToAudio/index.py` 支持 `cacheKey`：有 `cacheKey` 写 Redis `RUNNING`，成功写 `SUCCESS.result`，异常写 `FAIL.error/errorStage`；无 `cacheKey` 保持直接 return。
- [x] T045 [D007] Python `requirements.txt` 增加 Redis 客户端依赖，README 更新 `cacheKey` 与 Redis 状态结构说明。

## Phase 4：测试与验证

- [x] T016 更新 `PianoHomeWorkVideoV2TaskTest`：新增 `FakeNoteSequenceCaller`（记录 serviceName/functionName/event，可设返回 notes 或抛异常），并给 `newTask` 增加重载参数；现有 5 个用例经默认音序调用器后保持通过。
- [x] T017 新增断言：①音序调用收到 `serviceName=FcOssFFmpeg-3278`、`functionName=VideoToNoteSeq`、`event.video_path=<file_url>`、`event.task_id=<taskId>`；②传给 Gemini 的 `prompt` 中 `${audioseq}` 被替换为 `C4 D4 E4`；③Gemini 仍收到 `fileUri=<file_url>`（仍传视频）。
- [x] T018 边界用例：音序调用抛异常时不写 FAIL、`${audioseq}`→空、仍调用 Gemini 并写 SUCCESS；空音序(noteCount=0)→`${audioseq}`→空；prompt 无 `${audioseq}` 占位符时原样不变。
- [x] T019 运行 `mvn -f fc/pom.xml -pl Gemini-Api -am test -Dtest=PianoHomeWorkVideoV2TaskTest -Dsurefire.failIfNoSpecifiedTests=false`，结果 `Tests run: 9, Failures: 0, Errors: 0, Skipped: 0`。
- [x] T020 搜索确认无残留旧调用/旧口径，未引入 OSS/MQ/数据库调用（仅复用既有 `FcInvokeUtils`/`FcInvokeInput`）。
- [x] T024 [D005] 回跑 `PianoHomeWorkVideoV2TaskTest`，确认音序注入、失败继续、置信度过滤、占位符等既有用例不回归。
- [x] T025 [D005] 编译 `Gemini-Api` 及依赖模块，确认新增 `FcInvokeUtils` 方法对调用方无编译破坏。
- [x] T026 [D005] 静态审查：确认音序默认调用路径使用北京 VPC 方法；默认 `FcInvokeUtils.doSyncTask` 仍使用原 `client` 和 `fnEndpoint` 覆盖逻辑。
- [x] T031 [D006] 更新 `PianoHomeWorkVideoV2TaskTest`：Fake/Spy 能断言 transfer URL、body、`isVpc=true`、`taskObj.video_path/task_id`，并模拟返回音序 JSON。
- [x] T032 [D006] 回跑 `PianoHomeWorkVideoV2TaskTest`，确认音序注入、失败继续、置信度过滤、占位符、auto 回退不回归。
- [x] T033 [D006] 编译 `Gemini-Api` 及依赖模块，确认 HTTP 网关改造无编译破坏。
- [x] T034 [D006] 静态审查：确认默认音序调用路径不再使用 `FcInvokeUtils`，且 `FcInvokeUtils` 没有遗留 D005 未使用公共方法。
- [x] T046 [D007] Java 单测更新：断言异步 FC event 的 service/function/video_path/task_id/cacheKey，模拟 Redis `SUCCESS.result` 后完成 `${audioseq}` 替换。
- [x] T047 [D007] Java 单测覆盖：异步提交失败、Redis `FAIL`、等待超时均不写当前任务 FAIL，仍以空音序继续 Gemini。
- [x] T048 [D007] Python 单测新增/更新：mock `video_to_notes` 与 Redis writer，断言 `RUNNING -> SUCCESS`、异常写 `FAIL`、无 `cacheKey` 不写 Redis且 return 不变。
- [x] T049 [D007] 运行 Java 编译和 focused 测试：`Gemini-Api` compile + `PianoHomeWorkVideoV2TaskTest`。
- [x] T050 [D007] 运行 Python `py_compile` 与 `unittest discover -s tests`，记录音频依赖导致的 skip 情况。
- [x] T051 [D008] 在音序替换完成后、调用 Gemini 前打印替换后的 prompt 日志，包含长度与内容，超长内容做截断保护。
- [x] T052 [D008] 增加日志断言单测并回跑 `PianoHomeWorkVideoV2TaskTest`。
- [x] T053 [D009] 新增音序特征提取器，只输出固定工程侧 JSON 字段，不输出候选 id/title 或候选排名。
- [x] T054 [D009] `PianoHomeWorkVideoV2Task` 保留 `${audioseq}`，新增 `${engineeringContext}` 或自动追加工程侧音序特征 JSON，并注入 expectedDay/聊天弱上下文。
- [x] T055 [D009] `sop-reply` 调用识别 FC 时透传 `expectedDay=logicalDay`，私聊传最近 3 条非空聊天记录，群聊不传。
- [x] T056 [D009] 增加音序特征、prompt 注入和私聊/群聊上下文单测。
- [x] T057 [D009] 回跑 `Gemini-Api` 与 `sop-reply` 聚焦单测，记录无法完成的临时视频 URL 回归项。
- [x] T058 [D010] 使用 D2 当前进度执行两个提示词文件 x 5 个 demo 视频的本地真实链路回归。
- [x] T059 [D010] 回归前重跑 `Gemini-Api` 和 `sop-reply` 聚焦单测。
- [x] T060 [D010] 汇总 10 次回归结果，按 Pass/Warn/Fail 口径判定。
- [x] T061 [D010] 定位外部依赖失败阶段并记录：FC 异步提交成功返回 202，但本地 Redis 结果读取失败。
- [x] T062 [D011] 使用用户补充的 Redis 连接环境重跑 D2 回归矩阵，确认 FC 异步结果可从 Redis 取回。
- [x] T063 [D011] 汇总 Redis 跑通后的两个提示词版本识别差异。
- [x] T064 [D011] 记录真实失败点：旧提示词主要错 V2；V3 音序提示词对 V1/V5 误判或兜底，V2 多声部音序仍不能稳定命中 D2。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `106-piano-video-note-seq-prompt` 四件套；完成 Phase 1/2 事实确认与风险门禁结论。
- 验证方式：阅读目标类、单测、`FcInvokeUtils`/`FcInvokeInput`、spec 105 `index.py`/`note_extractor.py`、`AppTask` 范例、`pom.xml` 依赖链。
- 自检结论：满足强制门禁，无未确认业务语义变化，待用户确认进入实施。

### D002 - 实现记录

- 实现内容：`PianoHomeWorkVideoV2Task` 新增音序服务/函数名常量与 env 覆盖键、`${audioseq}` 占位符常量、`NoteSequenceCaller` 接口 + `DefaultNoteSequenceCaller`（委托 `FcInvokeUtils.doSyncTaskReturnJSONObj`）、构造函数注入；`analyzeVideo` 在两处 `validateRequired` 之后插入「取音序 → `buildNoteSequenceText` 拼音名 → `replacePromptPlaceholder` 替换 `${audioseq}`」，失败/空音序兜底空文本继续；单测新增 `FakeNoteSequenceCaller`、`noteSequenceResponse` 与 4 个用例，`newTask` 加重载。
- 测试命令：`mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am test "-Dtest=PianoHomeWorkVideoV2TaskTest" "-Dsurefire.failIfNoSpecifiedTests=false" -q`。
- 测试结果：`Tests run: 9, Failures: 0, Errors: 0, Skipped: 0`（5 个旧用例不回归 + 4 个新用例通过）；编译通过（JDK17 编 1.8 字节码）。
- 自检结论：参数来源（`video_path=file_url`、`task_id=taskId`、`serviceName/functionName` 常量+env、`noteSeqText` 替换前现算）齐备；调用顺序（校验 → 取音序 → 拼音名 → 替换 → 调 Gemini）正确；旧逻辑（缓存三态/TTL/锁/MDC/脱敏/三模式回退/错误口径）保持不变；剩余风险=`VideoToNoteSeq` 真实返回字段名与同步耗时需在函数计算实跑验证（部署侧）。

### D003 - 纠正记录（音名拼接按置信度过滤）

- 触发原因：用户提供 `VideoToNoteSeq` 真实返回数据（105 个音符，含大量 `confidence≈0.01` 的噪声 C2），确认改为按置信度过滤。
- 修正内容：`buildNoteSequenceText` 改为先按 `confidence ≥ 阈值`（默认 0.5，env `PIANO_HOMEWORK_VIDEO_V2_NOTE_SEQ_MIN_CONFIDENCE` 可覆盖）过滤再拼音名；新增阈值常量/env/解析（非法回退默认+warn）；新增/调整单测：`noteSequenceResponse` 默认带高 confidence、新增 `noteSequenceResponseWithConfidence`、过滤用例与 env 阈值用例、真实数据片段用例。
- 文档同步：已同步 `spec.md`（FR-002、历史防漏分析、边界、假设、D003）、`AGENTS.md`（当前目标、重点代码位置）、本 `tasks.md`、`checklists/requirements.md`。
- 验证结果：`mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am test "-Dtest=PianoHomeWorkVideoV2TaskTest" "-Dsurefire.failIfNoSpecifiedTests=false" -q` → `Tests run: 12, Failures: 0, Errors: 0, Skipped: 0`。

### D005 - 计划记录（音序同步调用使用北京 VPC endpoint）

- 触发原因：线上 `PianoHomeWorkVideoV2Task` 音序调用 `FcOssFFmpeg-3278/VideoToNoteSeq` 报 `TeaUnretryableException: connect timed out`；代码审查确认当前 `DefaultNoteSequenceCaller` 走 `FcInvokeUtils.doSyncTaskReturnJSONObj`，最终使用默认 `client`，未使用固定北京 VPC endpoint 的 `clientBeijing`。
- 事实确认：
  - `FcInvokeUtils.createClient` 默认 `client.endpoint` = `fnEndpoint` 环境变量，否则 `fc.cn-beijing.aliyuncs.com`。
  - `clientBeijing.endpoint` = `fc-vpc.cn-beijing.aliyuncs.com`，当前仅 `doTaskWithDelay` 使用。
  - `PianoHomeWorkVideoV2Task.DefaultNoteSequenceCaller` 调用 `doSyncTaskReturnJSONObj`，不是 VPC 客户端。
- 实施计划：新增显式北京 VPC 同步 JSON 调用方法，并只在音序默认调用器中使用；默认 `doSyncTask` 不做全局迁移，避免影响其他模块。
- 实现内容：`FcInvokeUtils` 新增 `doSyncTaskWithBeijingVpc` 与 `doSyncTaskReturnJSONObjWithBeijingVpc`，复用 `clientBeijing`/`runtimeBeijing`；`PianoHomeWorkVideoV2Task.DefaultNoteSequenceCaller` 从 `doSyncTaskReturnJSONObj` 切换为 `doSyncTaskReturnJSONObjWithBeijingVpc`。
- 测试命令：
  - `mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am compile -q`
  - `mvn -f C:\workspace\ju-chat\fc\pom.xml -pl common install -DskipTests -q`
  - `mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am test "-Dtest=PianoHomeWorkVideoV2TaskTest" "-Dsurefire.failIfNoSpecifiedTests=false" -q`
- 测试结果：编译通过；focused 单测 `PianoHomeWorkVideoV2TaskTest` 通过，`Tests run: 12, Failures: 0, Errors: 0, Skipped: 0`。
- 自检结论：音序默认调用路径使用 `clientBeijing` 对应的 `fc-vpc.cn-beijing.aliyuncs.com`；默认 `doSyncTask` 未改，仍使用原 `client`（`fnEndpoint` 覆盖，否则 `fc.cn-beijing.aliyuncs.com`）；未改 service/function/event、失败继续、置信度过滤、占位符替换、三模式回退、缓存锁。

### D006 - 计划记录（音序调用改走 transfer/fc HTTP 网关）

- 触发原因：用户要求将刚才的 `VideoToNoteSeq` 调用改为 `http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/ai/transfer/fc` 接口调用，参数结构参照 `{taskObj, serviceName, functionName, isVpc:true}`。
- 事实确认：
  - `PianoHomeWorkVideoV2Task.DefaultNoteSequenceCaller` 当前仍是默认音序调用落点。
  - `Gemini-Api` 已使用 Apache HttpClient（`GeminiProxyClient`、`GeminiSupplierClient`、`AppTask`），可复用该风格实现 HTTP POST。
  - 当前 `NoteSequenceCaller` 已可注入，适合单元测试隔离真实 HTTP；若要断言默认 HTTP body，需要给默认调用器引入可注入 HTTP 执行器或可测试方法。
- 实施计划：默认音序调用器构造 transfer/fc JSON body 并 POST；支持默认 URL + env 覆盖；兼容解析直接返回、`data`、`result` 三类返回体；移除 D005 新增的 `FcInvokeUtils` VPC 同步公共方法。
- 验证计划：更新/新增单测断言 HTTP URL/body/isVpc/taskObj；回跑 `PianoHomeWorkVideoV2TaskTest`；编译 `Gemini-Api` 及依赖；静态审查确认默认音序调用不再依赖 `FcInvokeUtils`。

### D006 - 实现记录（音序调用改走 transfer/fc HTTP 网关）

- 实现内容：`PianoHomeWorkVideoV2Task.DefaultNoteSequenceCaller` 已改为 POST `http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/ai/transfer/fc`，body 为 `{taskObj:event, serviceName, functionName, isVpc:true}`；新增 `DEFAULT_NOTE_SEQ_TRANSFER_URL`、`PIANO_HOMEWORK_VIDEO_V2_NOTE_SEQ_TRANSFER_URL` 与可注入 `NoteSequenceTransferClient`；兼容解析直接音序 JSON、`data` 对象/字符串、`result` 对象/字符串；HTTP 非 2xx、网络异常、空响应或无法识别响应均抛异常，由上层既有失败继续策略处理。
- 清理内容：移除 `PianoHomeWorkVideoV2Task` 对 `FcInvokeUtils`/`FcInvokeInput` 的引用；移除 `FcInvokeUtils.doSyncTaskWithBeijingVpc` 与 `doSyncTaskReturnJSONObjWithBeijingVpc`，默认 `doSyncTask`、`doTaskWithDelay` 未改。
- 测试命令：
  - `mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am compile -q`
  - `mvn -f C:\workspace\ju-chat\fc\pom.xml -pl Gemini-Api -am test "-Dtest=PianoHomeWorkVideoV2TaskTest" "-Dsurefire.failIfNoSpecifiedTests=false" -q`
- 测试结果：编译通过；focused 单测通过。新增断言覆盖 transfer URL、body 中 `serviceName`/`functionName`/`isVpc=true`/`taskObj.video_path`/`taskObj.task_id`、URL env 覆盖、`data` 字符串返回、`result` 对象返回；既有音序注入、失败继续、空音序、无占位符、置信度过滤、auto 回退等用例不回归。
- 静态验证：`rg "doSyncTask(ReturnJSONObj)?WithBeijingVpc|FcInvokeUtils|FcInvokeInput" ...` 确认默认音序调用类无 `FcInvokeUtils`/`FcInvokeInput` 引用；`FcInvokeUtils` 中无 D005 VPC 同步公共方法残留。
- 自检结论：D006 已实现，满足 T027~T034；等待用户验收后再进入本地提交阶段。

### D007 - 计划记录（音序调用改为异步 FC + Redis）

- 触发原因：用户要求 `VideoToNoteSeq` 函数计算改为异步调用，通过 Redis 获取结果，参考 `sop-reply` 调用 `PianoHomeWorkVideoV2Task` 的写法；用户确认 `VideoToNoteSeq` 尚不支持 Redis 写回，并给出源码目录 `C:\workspace\ju-chat\videoToAudio`。
- 事实确认：
  - `sop-reply` 的 `PianoVideoHomeWorkHandleServiceImpl` 模式：生成 `cacheKey`/`taskId`，异步 `FcInvokeUtils.doTask`，轮询 Redis 状态 JSON（`status/result/error/updatedAt`），超时/失败走兜底。
  - `videoToAudio/index.py` 当前仅直接 return 音序 JSON，不读取 `cacheKey`，不写 Redis；`requirements.txt` 无 Redis 客户端依赖。
  - `Gemini-Api` 的 `RedisClient` 已有 `getStringValue`，可支撑 Java 端轮询；音序 Redis key 应独立于外层主任务 `cacheKey`。
- 风险门禁结论：
  - 参数来源：Java 端生成内部音序 `cacheKey` 并在异步提交前写入 event；Python handler 从 event 读取 `cacheKey` 并写 Redis；Java 轮询同一 key。
  - 调用顺序：校验 prompt/file_url → 生成 event/cacheKey → 异步提交 FC → 等 Redis 成功/失败/超时 → 成功时解析音序并替换 `${audioseq}` → 调 Gemini。
  - 旧逻辑保持：Gemini 主任务 RUNNING/SUCCESS/FAIL 缓存、主 `dispatchLockKey` 释放、三模式回退、失败继续策略不变；音序失败仍只影响 `${audioseq}` 为空。
- 实施计划：完成 T041~T045。
- 验证计划：完成 T046~T050。
- 状态：用户已确认进入实施，D007 已实现并进入待验收。

### D007 - 实现记录（音序调用改为异步 FC + Redis）

- 实现内容（Java）：`PianoHomeWorkVideoV2Task.DefaultNoteSequenceCaller` 已从 D006 transfer/fc HTTP 同步网关切回 `FcInvokeUtils.doTask` 异步 FC；新增可注入 `NoteSequenceAsyncInvoker`、`NoteSequenceResultStore`、`NoteSequenceCacheKeyGenerator`、`Sleeper`；默认生成独立音序 Redis key（前缀 `ai:gemini:pianoVideoV2:noteSeq:`），event 写入 `video_path`、可选 `task_id`、`cacheKey` 后异步提交；轮询 Redis `SUCCESS.result`/`FAIL.error`/超时，成功解析音序 JSON，失败抛给既有 `fetchNoteSequenceTextSafely` 兜底为空音序并继续 Gemini。
- 实现内容（Python）：`videoToAudio/index.py` 支持 `cacheKey`，有 `cacheKey` 时写 Redis `RUNNING`，成功写 `SUCCESS` 且 `result` 为完整音序 JSON 字符串，异常写 `FAIL` 且包含 `error`/`errorStage`；无 `cacheKey` 时不访问 Redis并保持直接 return；`requirements.txt` 增加 `redis>=5.0,<6.0`，`README.md` 更新 Redis 环境变量与状态结构说明。
- 测试更新：Java `PianoHomeWorkVideoV2TaskTest` 替换旧 HTTP transfer/fc 默认调用器测试，新增异步 event/cacheKey、Redis `SUCCESS`、Redis `FAIL`、异步提交返回 `0`、超时等用例；Python 新增 `tests/test_index.py`，mock `note_extractor.video_to_notes` 与 Redis，覆盖 `RUNNING -> SUCCESS`、异常 `FAIL`、无 `cacheKey` 不写 Redis。
- 测试命令：
  - `mvn -q compile`（workdir: `C:\workspace\ju-chat\fc\Gemini-Api`）
  - `mvn -q -Dtest=PianoHomeWorkVideoV2TaskTest test`（workdir: `C:\workspace\ju-chat\fc\Gemini-Api`）
  - `python -m py_compile audio_ffmpeg.py note_extractor.py index.py tests\test_audio_ffmpeg.py tests\test_note_extractor.py tests\test_index.py`（workdir: `C:\workspace\ju-chat\videoToAudio`）
  - `python -m unittest discover -s tests`（workdir: `C:\workspace\ju-chat\videoToAudio`）
- 测试结果：Java compile 通过；Java focused 单测通过；Python `py_compile` 通过；Python unittest 通过，`Ran 14 tests in 0.033s, OK (skipped=3)`，3 个跳过为既有 `librosa/numpy` 依赖测试。
- 静态审查：目标类与目标测试中无 D006 `DEFAULT_NOTE_SEQ_TRANSFER_URL`、`ENV_NOTE_SEQ_TRANSFER_URL`、`NoteSequenceTransferClient`、transfer/fc HTTP 默认调用路径残留；`FcInvokeUtils.doTask` 默认 endpoint 为 `fc.cn-beijing.aliyuncs.com`（除非 `fnEndpoint` 覆盖），与 `sop-reply` 当前异步触发模式一致。
- 自检结论：满足 T041~T050、FR-016~022、SC-009~012；当前进入待用户验收阶段，尚未提交 git。

### D008 - 实现记录（打印替换后的提示词）

- 触发原因：用户要求将替换完音序的提示词打印到日志。
- 实现内容：`PianoHomeWorkVideoV2Task.injectNoteSequence` 在占位符替换后新增 info 日志：`Piano homework video v2 prompt after note sequence injection`，打印替换后 prompt 的 `textLength` 和内容；新增 `summarizePromptForLog`，超过 4000 字符时截断并标注原始长度。
- 测试更新：`PianoHomeWorkVideoV2TaskTest` 新增 `handleRequest_shouldLogPromptAfterNoteSequenceInjection`，通过 logback `ListAppender` 断言日志包含 `请结合音序 C4 D4 点评`。
- 测试命令：`mvn -q -Dtest=PianoHomeWorkVideoV2TaskTest test`（workdir: `C:\workspace\ju-chat\fc\Gemini-Api`）。
- 测试结果：通过。
- 自检结论：满足 T051~T052；当前仍为待用户验收阶段，尚未提交 git。

### D009 - 计划记录（工程侧音序特征 JSON、可算法化指纹与弱上下文注入）

- 实施目标：新增工程侧音序特征 JSON，作为模型客观证据注入 prompt；工程侧不输出候选排名、不覆盖最终课程判断。例外：去噪后有效音 `<5` 时直接返回人工复核 JSON，不调用 LLM。
- 去噪口径：`octave <= 2` 且持续时长 `<0.3s` 的极低短音直接丢弃；之后再按 confidence/voiced_prob 阈值过滤。
- 字段口径：`validNoteCount` 为去噪和 confidence 过滤后的有效音符数；`hasSameNoteRepeat` 看起手 N 个音中八度归一化后的连续相邻同音；`isMonoDescending` 看前 5 音八度归一化差分全负；`hasFa` 看 F/F# 音级；`isWavy` 看八度归一化差分有正有负；`mainOctave` 为八度众数；`highestNote`/`lowestNote` 由有效音 midi 统计；`rhythmStability`/`pauseOrStumble` 由 duration/gap/`>1s` 长停顿统计；`pyinConfidenceMean` 优先用 `voiced_prob`，缺失时用 `confidence`；`noteSequence` 为过滤后音序文本。
- 入口变更：`PianoHomeWorkVideoV2Task` 继续替换 `${audioseq}`，并替换 `${engineeringContext}` 或自动追加工程侧特征段；`expectedDay/currentDay/logicalDay` 和私聊最近消息仅作为弱上下文写入提示词。
- `sop-reply` 变更：`HomeWorkMessageDto` 增加群聊标记与最近消息；`PianoVideoHomeWorkHandleServiceImpl` 向识别 FC 透传 `expectedDay` 和私聊最近 3 条非空聊天记录，群聊不传。
- 测试计划：完成 T053~T057。临时视频 URL 尚未提供，部署回归验证暂记为待用户补充 URL。

### D009 - 实现记录（工程侧音序特征 JSON、有效音短路与弱上下文注入）

- 实现内容（Gemini-Api）：新增 `PianoNoteSequenceFeatureExtractor`，按低八度短噪声、confidence/voiced_prob 阈值过滤音符；八度归一化计算 `hasSameNoteRepeat`、`isMonoDescending`、`hasFa`、`isWavy`；统计 `mainOctave`、`highestNote`、`lowestNote`、`rhythmStability`、`pauseOrStumble`、`pyinConfidenceMean`、`noteSequence`。`PianoHomeWorkVideoV2Task` 保留 `${audioseq}`，新增 `${engineeringContext}` 替换/自动追加，并在有效音 `<5` 时直接返回人工复核 JSON（`confidence=0.3`、`needHumanReview=true`、`id=-1`），不调用 LLM。
- 实现内容（sop-reply）：`HomeWorkMessageDto` 增加 `groupChat` 与 `recentMessageModels`；`SopReply.resolveHomeworkMessage` 从 `WebChatVoiceDto` 透传；`PianoVideoHomeWorkHandleServiceImpl` 向识别 FC `taskObj` 写入 `expectedDay/logicalDay/isGroup`，仅私聊写入最近 3 条非空聊天记录。
- 测试命令：
  - `mvn -q "-Dtest=PianoHomeWorkVideoV2TaskTest,PianoNoteSequenceFeatureExtractorTest" test`（workdir: `C:\workspace\ju-chat\fc\Gemini-Api`）
  - `mvn -q "-Dtest=PianoVideoHomeWorkHandleServiceImplTest" test`（workdir: `C:\workspace\ju-chat\fc\sop-reply`）
- 测试结果：两组聚焦测试均通过。
- 未完成项：用户尚未提供临时可访问视频 URL，无法执行部署回归验证 V1->D1、V2->D2、V3->D3、V5->D5。

### D010 - 回归验证记录（D2 当前进度，Redis 读取失败）

- 触发原因：用户提供 5 个 demo 视频 URL，要求分别用 `C:\Users\EDY\Downloads\视频理解的提示词.txt` 与 `C:\Users\EDY\Downloads\视频理解的提示词V3.txt` 回归验证，并按 D2 当前进度判断今日/补交/提前提交。
- 验证矩阵：两个提示词 x `V1-1/V1-2/V2-1/V3-1/V5-1` 共 10 次；期望分别为 `V1->id=1`、`V2->id=2`、`V3->id=3`、`V5->id=5`。
- 前置测试：
  - `mvn -q "-Dtest=PianoHomeWorkVideoV2TaskTest,PianoNoteSequenceFeatureExtractorTest" test`（workdir: `C:\workspace\ju-chat\fc\Gemini-Api`）通过。
  - `mvn -q "-Dtest=PianoVideoHomeWorkHandleServiceImplTest" test`（workdir: `C:\workspace\ju-chat\fc\sop-reply`）通过。
- 回归执行方式：在 `Gemini-Api\target\regression-runner` 生成临时 Java runner，调用 `PianoHomeWorkVideoV2Task.handleRequest` 默认真实链路；请求不传主任务 `cacheKey`，传 `expectedDay/currentDay/logicalDay=2`；完整日志写入 `Gemini-Api\target\piano-regression-d010.log`。
- 结果汇总：
  - 10/10 均为 `FAIL`，返回短路 JSON：`isHomeWork=否`、`id=-1`、`title=未知`、`confidence=0.3`、`needHumanReview=true`、`validNoteCount=0`。
  - 失败阶段不是 Gemini 判断错误，也不是提示词差异；日志显示 `FcInvokeUtils` 调 `FcOssFFmpeg-3278/VideoToNoteSeq` 已返回 `statusCode=202`，随后本地读取 Redis 时失败：`redis.clients.jedis.exceptions.JedisConnectionException: Could not get a resource from the pool`。
  - 因音序结果未能从 Redis 取回，工程侧有效音为 0，触发 `<5` 有效音短路，未调用 Gemini；因此两个提示词版本的识别效果无法在本地环境完成对比。
- 自检结论：D010 真实链路回归当前被本地 Redis 访问环境阻塞。恢复/配置可访问的 Redis 后，应复用相同矩阵重跑；若需绕过 Redis，需要另开需求明确是否允许使用同步/直连 `VideoToNoteSeq` 结果作为回归输入。

### D011 - 回归验证记录（D2 当前进度，Redis 跑通后重跑）

- 触发原因：用户补充 Redis 连接信息后，继续复用 D010 的两个提示词 x 5 个 demo 视频矩阵重跑；本次仅通过本地进程环境变量注入 Redis 连接信息，未写入仓库文件。
- 前置验证：最小 Redis 连通性探针通过，`Gemini-Api` 可在 `db=3` 中读取 key；D010 前置聚焦单测已通过，本次未改业务代码。
- 回归执行方式：复用 `Gemini-Api\target\regression-runner` 临时 Java runner 调用 `PianoHomeWorkVideoV2Task.handleRequest` 默认真实链路；不传主任务 `cacheKey`，传 `expectedDay/currentDay/logicalDay=2`；完整日志写入 `Gemini-Api\target\piano-regression-d010-redis-rerun.log`。
- 工程侧音序结果：FC 异步提交和 Redis 结果读取均已跑通；日志显示 V1-1/V1-2 有效音分别为 `35/34`，V2-1 为 `13`，V3-1 为 `26`，V5-1 为 `39`。
- 结果汇总：
  - `视频理解的提示词.txt`：5 条中 4 条 PASS，`V1-1->D1`、`V1-2->D1`、`V3-1->D3`、`V5-1->D5` 命中；`V2-1` 误判为 `id=1/四季歌/补交作业`，FAIL。
  - `视频理解的提示词V3.txt`：5 条中 1 条 PASS，仅 `V3-1->D3` 命中；`V1-1` 误判为 `id=2/铁血丹心/今日作业`，`V1-2` 兜底 `id=-1`，`V2-1` 兜底 `id=-1`，`V5-1` 兜底 `id=-1`。
- 自检结论：Redis 环境问题已解除，本轮形成有效提示词对比结论。旧视频理解提示词在这 5 条样本上整体优于 V3 音序提示词，但旧提示词仍不能识别 V2；V3 音序提示词对工程特征解释过于僵硬，把 V1 的起手重复/跳进误判为 D2 或排除 D1，对 V5 的复杂八度/半音音序过度兜底。V2 多声部/低音弦干扰仍是核心风险，工程侧需进一步提取主旋律或调整提示词对低音伴奏噪声的处理规则后再回归。
