# 任务清单：视频号占位消息拆分发送

**输入**：来自 `specs/001-video-channel-placeholder-send/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`  
**测试**：本任务清单默认测试先行；按用户确认，后续实现需要为相关 Maven 模块补充 JUnit 测试能力，并通过 `mvn test` 执行。  

**组织方式**：任务按阶段和用户故事依赖组织，以支持先建立 common 共享能力，再分别接入 `delay-mq` 与 `ai-reply`。

## 格式：`[ID] [P?] [Story] Description`

- **[P]**：可并行执行（不同文件、没有依赖）
- **[Story]**：任务所属用户故事（US1、US2、US3、US4、US5、US6）
- 描述中包含精确文件路径或明确模块范围
- 所有任务初始状态均为未完成；执行后再补充执行记录和自检结论

## /plan 实施计划（待执行）

**当前状态**：任务清单已生成，尚未开始实现。

**范围约束**：

- 仅实现 `spec.md` 中视频号占位消息拆分发送相关 US1-US6、FR-001 至 FR-033、SC-001 至 SC-013。
- 不新增对外接口，不改变现有 URL，不改函数计算 `SEND_MESSAGE` 的外部调用语义。
- 不手动携带 token；函数计算内部继续自动处理 token。
- `type != 1` 的原有分支保持不变。
- common 共享能力不得直接依赖 `fc/delay-mq` 或 `fc/ai-reply` 的具体 Redis 类。

**执行节奏**：

- 先完成 Setup 和 Foundational，再进入 common 实现。
- 测试类任务优先于对应实现任务；实现完成后必须重跑对应测试。
- 即使任务标记 `[P]`，实际执行时也应避免同时修改同一文件。
- 每个任务完成后在本文件追加执行记录，至少包含：执行内容、测试命令、测试结果、自检结论。

**每个 task 的完成记录模板**：

- 执行内容：
- 测试命令：
- 测试结果：
- 自检结论：

---

## Phase 1：Setup（代码基线与真实落点）

**目的**：确认规格范围、现有发送链路和视频号 demo 的真实行为。

- [x] T001 复查 `specs/001-video-channel-placeholder-send/spec.md`、`specs/001-video-channel-placeholder-send/AGENTS.md`、`specs/001-video-channel-placeholder-send/checklists/requirements.md`，确认本次范围只覆盖视频号占位发送
- [x] T002 [P] 定位 `fc/ai-reply/src/main/java/com/drh/delay/consumer/util/CozeUtil.java`、`fc/delay-mq/src/main/java/com/drh/delay/consumer/util/CozeUtil.java`、`fc/delay-mq/src/main/java/com/drh/delay/consumer/util/CozeUtilV2.java` 中 `sendJuzi`、`sendJuziTextOrImage`、`splitJuziContent` 的当前实现
- [x] T003 [P] 记录 `fc/delay-mq/src/test/java/TestSendVideoChannelBatchMessage.java` 与 `fc/delay-mq/src/test/resources/video-channel-batch-config.json` 的可复用行为：messageType 14、`functionCode = "SEND_MESSAGE"`、gzip 读取、description 兜底、同步发送和 dry-run

**检查点**：实现入口、复用 demo 和不变行为已确认。

---

## Phase 2：Foundational（测试基础）

**目的**：建立可自动化验证的测试基础，避免只依赖手动 main demo。

**CRITICAL**：此阶段完成前不得开始 common 生产代码实现。

- [x] T004 在 `fc/pom.xml` 增加 `junit:junit:4.13.2` test scope 依赖，供 `common`、`delay-mq`、`ai-reply` 共享测试能力
- [x] T005 [P] 在 `fc/common/src/test/java` 新增占位符解析测试，覆盖普通文本、`##{image:...}`、`![photo](...)`、`##{channels:V18}`、`##{channels:v18}`、多段顺序和 malformed 占位符
- [x] T006 [P] 在 `fc/common/src/test/java` 新增视频号 payload 测试，覆盖 raw JSON 字段复制、messageType 14、description 兜底和不透传 token
- [x] T007 [P] 在 `fc/common/src/test/java` 新增配置与 OSS 读取测试，覆盖 `video-channel-batch-config.json` code 查找、gzip JSON 读取、UTF-8 解析和无效 JSON
- [x] T008 [P] 在 `fc/common/src/test/java` 新增缓存测试，使用 fake cache 验证 Redis TTL 为 1800 秒、缓存命中不访问 OSS、缓存 key 区分 code + rawMsgUrl

**检查点**：核心解析、payload、配置、OSS 和缓存行为均有失败优先测试。

---

## Phase 3：Common 共享能力（US1、US2、US3、US4 基础）

**目标**：将视频号占位解析、配置读取、OSS JSON 获取、Redis 缓存和 payload 构建沉到 `fc/common`，供两个函数模块复用。

**独立测试**：运行 common 单测即可验证解析、payload、OSS、缓存和错误处理。

- [x] T009 [US3] 在 `fc/common/src/main/java/com/drh/common` 体系下设计共享消息片段模型，类型包含 `TEXT`、`IMAGE`、`VIDEO_CHANNEL`，视频号 code 统一大写
- [x] T010 [US1] 在 `fc/common/src/main/java/com/drh/common` 体系下实现统一内容解析器，替代两个模块内重复的 `splitJuziContent` 规则，并保持现有图片占位符兼容
- [x] T011 [US2] 将 `video-channel-batch-config.json` 提升为可被两个模块读取的公共资源，优先放在 `fc/common/src/main/resources`
- [x] T012 [US2] 在 `fc/common/src/main/java/com/drh/common` 体系下实现视频号配置加载器，根据规范化 code 查找 `rawMsgUrl`
- [x] T013 [US2] 在 `fc/common/src/main/java/com/drh/common` 体系下实现 OSS raw JSON 读取器，支持 gzip 探测、UTF-8 读取、连接超时和 JSON 解析失败上抛可定位异常
- [x] T014 [US4] 在 `fc/common/src/main/java/com/drh/common` 体系下定义缓存适配接口，业务模块通过现有 `RedisClient#getStringValue` 和 `setTokenWithExpire` 接入，固定 TTL 为 1800 秒
- [x] T015 [US2] 在 `fc/common/src/main/java/com/drh/common` 体系下实现视频号 payload / `SEND_MESSAGE` taskObj 构建工具，保持 `functionCode = "SEND_MESSAGE"`，messageType 为 14，并且不手动携带 token

**检查点**：common 层可独立完成从 `##{channels:V18}` 到可发送视频号业务请求体的构建。

---

## Phase 4：用户故事 1/2/4 - `delay-mq` 接入

**目标**：`delay-mq` 收到扣子回复后，按原文顺序串行发送文本、图片、视频号。

**独立测试**：使用同一输入验证 `delay-mq` 的发送片段顺序、视频号 payload 和异常跳过行为。

### `delay-mq` 的测试

- [x] T016 [US1] 在 `fc/delay-mq/src/test/java` 增加测试：输入 `视频编号： V18\n##{channels:v18}` 时，发送顺序为文本消息后接 V18 视频号消息
- [x] T017 [US4] 在 `fc/delay-mq/src/test/java` 增加测试：未知 code、OSS 失败或 JSON 缺字段时跳过 malformed 视频号片段，并继续发送其他有效文本或图片片段
- [x] T018 [US2] 在 `fc/delay-mq/src/test/java` 增加测试：视频号发送使用 Redis 缓存，缓存命中时不重复读取 OSS

### `delay-mq` 的实现

- [x] T019 [US1] 更新 `fc/delay-mq/src/main/java/com/drh/delay/consumer/util/CozeUtil.java` 的 `sendJuzi`，使用 common 解析文本、图片、视频号片段
- [x] T020 [US1] 更新 `CozeUtil.sendJuzi` 的发送循环，句子 `type=1` 片段串行发送，使用同步提交或等价顺序保证，避免编号文本和视频号卡片错位
- [x] T021 [US2] 在 `CozeUtil` 中新增视频号发送接入，复用 common 配置解析、OSS 读取、Redis 缓存和 messageType 14 payload 构建
- [x] T022 [US1] 同步更新 `fc/delay-mq/src/main/java/com/drh/delay/consumer/util/CozeUtilV2.java`，确保 V2 链路与 `CozeUtil` 行为一致

**检查点**：`delay-mq` 已完整支持视频号占位符并保持文本、图片原有行为。

---

## Phase 5：用户故事 1/2/4 - `ai-reply` 接入

**目标**：`ai-reply` 使用同一套 common 能力，和 `delay-mq` 对相同输入保持一致行为。

**独立测试**：复用相同输入，验证 `ai-reply` 拆分结果和视频号 payload 与 `delay-mq` 一致。

### `ai-reply` 的测试

- [x] T023 [US3] 在 `fc/ai-reply/src/test/java` 增加测试：同一段包含文本、图片和视频号的输入，拆分结果与 common 预期一致
- [x] T024 [US3] 在 `fc/ai-reply/src/test/java` 增加测试：视频号 payload 字段和 messageType 与 `delay-mq` 期望一致

### `ai-reply` 的实现

- [x] T025 [US1] 更新 `fc/ai-reply/src/main/java/com/drh/delay/consumer/util/CozeUtil.java` 的 `sendJuzi`，使用 common 解析文本、图片、视频号片段
- [x] T026 [US1] 更新 `ai-reply` 发送循环，保持文本、图片、视频号严格按原文顺序提交
- [x] T027 [US4] 接入 `ai-reply` 现有 `RedisClient` 到 common 缓存适配接口，缓存 TTL 固定为 1800 秒
- [x] T028 [US3] 确认 `ai-reply` 与 `delay-mq` 对相同输入产生一致的片段类型、视频号 code 和 payload 字段

**检查点**：`ai-reply` 与 `delay-mq` 共享 common 行为，无重复业务规则。

---

## Phase 6：Polish & Cross-Cutting Concerns

**目的**：完成手动 demo 保留、自动化回归和规格覆盖复查。

- [x] T029 [P] 保留并调整 `fc/delay-mq/src/test/java/TestSendVideoChannelBatchMessage.java` 为手动 demo，确保仍能 dry-run 验证 V1-V18，并明确它不是自动化测试的替代品
- [x] T030 运行 `mvn -pl common,delay-mq,ai-reply -am test`，修复所有新增失败
- [x] T031 使用包含 `视频编号： V18\n##{channels:v18}` 的样例验证 SC-001：先发送文本 `视频编号： V18`，再发送 V18 视频号消息
- [x] T032 使用 18 个编号和 18 个视频号占位符验证 SC-002：所有文本编号与视频号卡片一一相邻且顺序一致
- [x] T033 复查 `specs/001-video-channel-placeholder-send/spec.md` 的 FR-001 至 FR-019、SC-001 至 SC-007，确认任务清单全覆盖
- [x] T034 更新 `specs/001-video-channel-placeholder-send/checklists/requirements.md` 或本文件任务完成记录，标记进入实现前/实现后检查结果

**检查点**：自动化测试、手动 dry-run 验收和规格覆盖复查全部完成。

---

## Phase 7：增量需求 - 视频号 7 天限发（US5）

**目标**：同一外部联系人、同一企微员工、同一视频号编码 7 天内只成功提交一次视频号卡片；重复命中只跳过视频号卡片，其他文本和图片继续发送。

- [x] T035 [US5] 更新 `spec.md`、`tasks.md`、`checklists/requirements.md`，补充 7 天限发的口径、边界和成功标准
- [x] T036 [US5] 在 `fc/common` 新增 `VideoChannelSendLimitStore` 与 `VideoChannelSendLimitService`，封装 Redis key、604800 秒 TTL、NX 占位、失败释放和 Redis 异常 fail-open
- [x] T037 [US5] 在 `fc/common/src/test/java` 增加限发服务单测，覆盖 key 维度、code 大写、首次允许、重复拦截、释放后可重试、Redis 异常继续发送
- [x] T038 [US5] 在 `fc/ai-reply` 与 `fc/delay-mq` 的 `RedisClient` 增加 `setIfAbsentWithExpire`，使用 Jedis `SetParams.nx().ex(seconds)` 原子占位
- [x] T039 [US5] 在 `ai-reply` 的 `CozeUtil`、`delay-mq` 的 `CozeUtil` 和 `CozeUtilV2` 接入 7 天限发：构建 taskObj 后占位，重复命中跳过，函数计算提交失败释放占位
- [x] T040 [US5] 在 `ai-reply` 与 `delay-mq` 模块测试中增加同一回复重复视频号用例，验证只跳过重复卡片并继续发送其他文本

**检查点**：7 天限发与现有 30 分钟 OSS JSON 缓存相互独立，两个函数模块使用同一 common 限发规则。

---

## Phase 8：增量需求 - 条件文本跟随后面视频号发送（US6）

**目标**：支持 `##{text:...}` 条件文本，只在后面紧邻的视频号会发送时发送；普通文本、图片和独立视频号保持原行为。

- [x] T041 [US6] 更新 `spec.md`、`tasks.md`、`checklists/requirements.md`、`AGENTS.md`，补充条件文本语义、绑定口径、失败口径和成功标准
- [x] T042 [US6] 在 `fc/common` 扩展消息片段模型，新增 `CONDITIONAL_TEXT` 类型、工厂方法和判断方法
- [x] T043 [US6] 更新 `JuziContentParser`，识别 `##{text:<content>}` 并保持 malformed 条件文本按普通文本处理
- [x] T044 [US6] 更新 common 单测，覆盖条件文本解析、紧邻视频号组合、多组合、malformed 条件文本和未绑定条件文本
- [x] T045 [US6] 调整 `ai-reply`、`delay-mq` 的 `CozeUtil` / `CozeUtilV2` 发送循环，按 index 识别 `CONDITIONAL_TEXT + VIDEO_CHANNEL` 组合
- [x] T046 [US6] 在绑定组合中先构建视频号 taskObj 并执行 7 天限发预检；视频号不会发送时同步跳过条件文本和视频号
- [x] T047 [US6] 在绑定组合预检通过时先发送条件文本、再发送视频号；视频号提交失败时释放 7 天限发占位但不回滚条件文本
- [x] T048 [US6] 更新 `ai-reply` 与 `delay-mq` 模块测试，覆盖首次可发送、7 天命中、未绑定条件文本和视频号构建失败
- [x] T049 [US6] 运行 `mvn -pl common,delay-mq,ai-reply -am test` 并记录结果

**检查点**：条件文本不会泄露控制语法，且不会影响普通文本、图片、独立视频号或 `type != 1` 分支。

---

## Phase 9：增量需求 - 作业点评配置台视频号动作配置（US7）

**目标**：`data-RC/juzi-service` 作业点评配置台新增 `VIDEO_CHANNEL` 动作，运营只配置 `V15` 这类编码，配置 JSON 输出规范化编码。

- [x] T050 [US7] 更新 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`，记录 D004 增量范围和实施计划
- [x] T051 [US7] 在 `data-RC/juzi-service` 增加 `HomeworkActionType.VIDEO_CHANNEL`
- [x] T052 [US7] 扩展动作 DTO/服务层，新增 `videoChannelCode` 输出语义；保存时复用 `text_content` 存储规范化编码，不新增表字段
- [x] T053 [US7] 更新动作新增和编辑校验：`VIDEO_CHANNEL` 不要求上传文件，编码必须匹配 `V` 或 `v` 加数字，并统一保存为大写
- [x] T054 [US7] 更新 `homework-config.html`，动作类型下拉增加视频号；根据类型切换为编码输入框，并支持新增、编辑、展示和 JSON 预览
- [x] T055 [US7] 补充 `juzi-service` 测试，覆盖 `v15` 规范化、非法编码拒绝、JSON 输出 `videoChannelCode=V15`、不触发文件上传字段

**检查点**：配置台可维护视频号编码动作，配置 JSON 不包含真实视频号 payload。

---

## Phase 10：增量需求 - sop-reply 配置发送链路支持 VIDEO_CHANNEL（US7）

**目标**：`SopConfigSender` 可读取配置台生成的 `VIDEO_CHANNEL` 动作，并复用 `fc/common` 视频号能力发送真实视频号卡片。

- [x] T056 [US7] 在 `fc/sop-reply` 扩展 `SopActionType` 和 `SopAction`，支持 `VIDEO_CHANNEL` 与 `videoChannelCode`，并兼容从 `textContent` 读取编码
- [x] T057 [US7] 新增或封装 `sop-reply` 视频号发送适配器，接入 `VideoChannelMessageService`、`VideoChannelSendLimitService`、`VideoChannelConfigLoader.fromDefaultResource()`、`UrlVideoChannelRawMessageReader`
- [x] T058 [US7] 为 `sop-reply` 现有 `RedisClient` 增加 common `VideoChannelCache` 和 `VideoChannelSendLimitStore` 适配，保留 30 分钟 raw JSON 缓存和 7 天限发规则
- [x] T059 [US7] 更新 `SopConfigSender.sendSingleAction`，`VIDEO_CHANNEL` 分支构建 `messageType=14` 的 `SEND_MESSAGE` taskObj，保持现有 delay、动作条件、`wxsend=false` 预览和 sentCount 语义
- [x] T060 [US7] 发送失败时释放 7 天限发占位；未知编码、OSS 失败、JSON 缺字段或限发命中时跳过当前视频号并继续后续动作
- [x] T061 [US7] 补充 `SopConfigSender` 测试，覆盖 V15 发送 payload、限发命中跳过、未知编码跳过、`wxsend=false` 预览和现有动作类型回归

**检查点**：配置驱动的作业点评策略可以发送视频号，且复用 common 的真实 payload、缓存和限发能力。

---

## Phase 11：增量需求 - HomeWorkCommentService 支持视频号编码发送（US7）

**目标**：旧 `HomeWorkCommentService` / `SendInfo` 发送链路具备按编码发送视频号的基础能力，供识别后的旧路径或直接调用复用。

- [x] T062 [US7] 扩展 `SendInfo`，增加可选视频号编码列表或等价结构，编码语义与配置台一致
- [x] T063 [US7] 在 `HomeWorkCommentService` 增加 `sendVideoChannel(WebChatVoiceDto, String code, Integer delaySeconds)`，复用 Phase 10 的视频号发送适配器
- [x] T064 [US7] 更新 `sendInfo` 发送流程，将视频号编码按既定顺序和 delay 规则发送，默认放在奖励图片之后、提醒文本之前；不改变现有文本、语音、文件、图片顺序
- [x] T065 [US7] 保持 `PianoVideoHomeWorkHandleServiceImpl` 仅负责识别，不在识别类内拼接真实视频号 payload
- [x] T066 [US7] 补充 `HomeWorkCommentService` 测试，覆盖编码发送、限发/异常跳过、delay 累加和原有动作回归

**检查点**：旧发送链路可发送视频号编码，且不破坏原有点评消息编排。

---

## Phase 12：增量需求 - 回归验证与文档记录（US7）

**目标**：完成配置台与 sop-reply 的端到端回归，并把实现结论写回 spec-kit。

- [x] T067 [US7] 运行 `mvn -pl common,sop-reply -am test`，确认 common 与 sop-reply 回归通过
- [x] T068 [US7] 运行 `mvn -pl juzi-service -DskipTests=false test`；若环境测试依赖缺失，则至少运行 `mvn -pl juzi-service -DskipTests package` 并记录原因
- [x] T069 [US7] 手工或单测验证配置 JSON 中 `VIDEO_CHANNEL/V15` 能被 `SopConfigSender` 转为 `messageType=14` 请求
- [x] T070 [US7] 复查 FR-034 至 FR-045、SC-014 至 SC-019 覆盖情况
- [x] T071 [US7] 更新本文件执行记录、`checklists/requirements.md` 和必要的 spec D004 验证结果

**检查点**：配置台、sop-reply、旧发送链路和现有动作类型均完成验证记录。

---

## 依赖与执行顺序

### 阶段依赖

- **Setup（Phase 1）**：无依赖，可以立即开始。
- **Foundational（Phase 2）**：依赖 Setup，且阻塞 common 生产代码实现。
- **Common（Phase 3）**：依赖 Foundational，且阻塞两个函数模块接入。
- **delay-mq（Phase 4）**：依赖 Common，可先于 `ai-reply` 完成并独立验收。
- **ai-reply（Phase 5）**：依赖 Common，最终需要与 `delay-mq` 行为一致。
- **Polish（Phase 6）**：依赖 Phase 3 至 Phase 5 完成。
- **配置台视频号动作（Phase 9）**：依赖既有 common 视频号配置与 payload 能力，先于 `sop-reply` 配置发送接入。
- **sop-reply 配置发送（Phase 10）**：依赖 Phase 9 的 JSON 形态和 common 视频号工具。
- **HomeWorkCommentService 旧链路（Phase 11）**：依赖 Phase 10 的视频号发送适配器。
- **回归与文档（Phase 12）**：依赖 Phase 9 至 Phase 11 完成。

### 并行机会

- T002、T003 可并行阅读记录。
- T005、T006、T007、T008 可并行编写测试，但不要同时修改同一测试辅助类。
- T016、T017、T018 可并行编写 `delay-mq` 测试。
- T023、T024 可并行编写 `ai-reply` 测试。
- T029 可与最终文档复查准备并行。
- T051-T055 和 T056-T061 不建议并行修改同一 JSON 合同；可先完成配置台 JSON 形态，再接入 `sop-reply`。
- T062-T066 可在 Phase 10 发送适配器接口稳定后与部分回归准备并行。

### MVP 优先

1. 完成 Phase 1 和 Phase 2，建立测试基础。
2. 完成 Phase 3，先让 common 能解析和构建视频号请求体。
3. 完成 Phase 4，让 `delay-mq` 可按顺序发送文本、图片、视频号。
4. 完成 Phase 5，让 `ai-reply` 与 `delay-mq` 行为一致。
5. 完成 Phase 6，跑自动化回归并做手动 dry-run 验收。
6. 完成 Phase 9，让配置台能产出 `VIDEO_CHANNEL` 编码动作。
7. 完成 Phase 10，让 `sop-reply` 配置发送链路能把编码转真实视频号发送。
8. 完成 Phase 11，让旧 `HomeWorkCommentService` 链路具备按编码发送能力。
9. 完成 Phase 12，跑跨模块回归并更新文档记录。

## 接口与默认值

- 共享模型默认放在 `com.drh.common` 体系下。
- Redis 缓存 TTL 固定为 1800 秒。
- Redis 缓存 key 建议形如 `juzi:video-channel:raw:{CODE}:{md5(rawMsgUrl)}`。
- 视频号 7 天限发 TTL 固定为 604800 秒。
- 视频号 7 天限发 key 固定为 `juzi:video-channel:sent:{externalUserId}:{userId}:{CODE}`。
- 7 天限发命中时只跳过视频号卡片；Redis 限发异常时继续发送并记录日志。
- 条件文本占位符格式为 `##{text:...}`，只绑定紧邻后一个视频号。
- 条件文本绑定的视频号不会发送时，条件文本也不发送。
- 视频号合法 code 为 `V` 或 `v` 加数字，内部统一为大写。
- 配置台 `VIDEO_CHANNEL` 动作只配置编码，DTO/JSON 输出 `videoChannelCode`，存储复用 `text_content`，不新增表字段。
- `sop-reply` 读取 `VIDEO_CHANNEL` 时优先使用 `videoChannelCode`，并兼容 `textContent` 中的编码。
- 配置台不解析真实视频号 raw JSON；真实 payload 仍由发送端通过 `fc/common` 构建。
- malformed 占位符不发送视频号。
- 未知 code、OSS 失败、JSON 缺字段时记录日志并继续发送其他片段。
- `type != 1` 的原有分支保持不变。

## 测试计划

- common JUnit 单测覆盖解析、配置、OSS、缓存、payload 构造、7 天限发和条件文本解析。
- `delay-mq` 与 `ai-reply` 模块测试覆盖同输入一致性、顺序发送、异常跳过、重复视频号跳过和条件文本绑定发送。
- `juzi-service` 测试覆盖 `VIDEO_CHANNEL` 动作新增、编辑、编码规范化、非法编码拒绝和配置 JSON 输出。
- `sop-reply` 测试覆盖 `SopConfigSender` 发送 `VIDEO_CHANNEL`、`HomeWorkCommentService` 按编码发送视频号、7 天限发、30 分钟缓存和未知编码跳过。
- 回归命令固定为：`mvn -pl common,delay-mq,ai-reply -am test`。
- 本次增量回归命令补充：`mvn -pl common,sop-reply -am test` 与 `mvn -pl juzi-service -DskipTests=false test`。
- 手动 demo 只作为补充验收，不替代 JUnit 自动化测试。

## 执行记录（2026-04-29）

### T001-T003 Setup

- 执行内容：复查规格、任务范围和当前代码落点；确认 `sendJuzi`、`sendJuziTextOrImage`、`splitJuziContent` 分布在 `ai-reply`、`delay-mq` 的 `CozeUtil` / `CozeUtilV2`，视频号 demo 位于 `delay-mq/src/test/java/TestSendVideoChannelBatchMessage.java`。
- 测试命令：不适用，阅读与定位任务。
- 测试结果：已确认现有 demo 包含 messageType 14、`SEND_MESSAGE`、gzip 读取、description 兜底、dry-run 和同步发送参考。
- 自检结论：实现入口和复用行为已定位。

### T004-T015 Foundational / Common

- 执行内容：在 `fc/pom.xml` 增加 JUnit 4.13.2 test 依赖；在 `fc/common` 新增文本/图片/视频号片段模型、统一解析器、视频号配置加载、gzip URL 读取、缓存接口、payload 构建和 30 分钟缓存解析服务；将 `video-channel-batch-config.json` 提升到 common resource。
- 测试命令：`mvn -pl common test`
- 测试结果：`Tests run: 12, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：common 已覆盖占位符解析、payload 构造、配置读取、gzip JSON、缓存 TTL、cache key 和非法缓存 fallback。

### T016-T022 delay-mq

- 执行内容：更新 `delay-mq` 的 `CozeUtil` 与 `CozeUtilV2`，使用 common 解析文本、图片、视频号片段；句子 `type=1` 使用同步函数计算调用串行提交；视频号发送复用 common 配置、OSS、Redis 缓存和 messageType 14 payload 构建。
- 测试命令：`mvn -pl delay-mq -am test`
- 测试结果：`Tests run: 15, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：`delay-mq` 模块测试覆盖 V18 顺序、异常跳过和缓存命中。

### T023-T028 ai-reply

- 执行内容：更新 `ai-reply` 的 `CozeUtil`，使用 common 解析和视频号发送能力；接入现有 `RedisClient` 到 common 缓存接口；新增模块测试验证同输入解析和视频号 payload 合同。
- 测试命令：`mvn -pl ai-reply -am test`
- 测试结果：`Tests run: 14, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：`ai-reply` 与 `delay-mq` 共享 common 行为，未复制视频号业务规则。

### T029-T034 Polish

- 执行内容：保留现有 `TestSendVideoChannelBatchMessage` 手动 demo；复查 FR-001 至 FR-019、SC-001 至 SC-007；运行目标回归。
- 测试命令：`mvn -pl common,delay-mq,ai-reply -am test`
- 测试结果：`Tests run: 17, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：目标模块回归通过，任务清单已全部勾选完成。

## 执行记录（2026-05-06）

### T035-T040 视频号 7 天限发

- 执行内容：更新规格和任务记录；在 `fc/common` 新增 7 天限发 store/service；在 `ai-reply`、`delay-mq` 的 RedisClient 增加 Jedis `NX + EX` 原子占位；在三个视频号发送入口接入构建后占位、重复跳过和提交失败释放；补充 common、ai-reply、delay-mq 自动化测试。
- 测试命令：`mvn -pl common,delay-mq,ai-reply -am test`
- 测试结果：common `Tests run: 18, Failures: 0, Errors: 0, Skipped: 0`；delay-mq `Tests run: 4, Failures: 0, Errors: 0, Skipped: 0`；ai-reply `Tests run: 3, Failures: 0, Errors: 0, Skipped: 0`；整体 `BUILD SUCCESS`。
- 自检结论：7 天限发口径为 `external_user_id + user_id + CODE`，重复命中只跳过视频号卡片；Redis 限发异常继续发送；30 分钟 OSS JSON 缓存未改变。

### T041-T049 条件文本跟随后面视频号发送

- 执行内容：更新 spec-kit 文档；在 common 新增 `CONDITIONAL_TEXT` 片段类型并支持解析 `##{text:...}`；调整 `ai-reply`、`delay-mq` 的三个 `sendJuzi` 循环，按 index 识别条件文本和紧邻视频号组合；绑定视频号预检失败或 7 天命中时跳过条件文本和视频号；预检通过时先发送条件文本再发送视频号。
- 测试命令：`mvn -pl common,delay-mq,ai-reply -am test`
- 测试结果：common `Tests run: 22, Failures: 0, Errors: 0, Skipped: 0`；delay-mq `Tests run: 8, Failures: 0, Errors: 0, Skipped: 0`；ai-reply `Tests run: 7, Failures: 0, Errors: 0, Skipped: 0`；整体 `BUILD SUCCESS`。
- 自检结论：条件文本只绑定紧邻后一个视频号；普通文本仍独立发送；未绑定或绑定视频号不会发送时，条件文本不会泄露给用户。

## 执行记录（2026-06-23）

### T050 / D004 作业点评配置台视频号动作文档同步

- 执行内容：复用 `001-video-channel-placeholder-send`，新增 US7、FR-034 至 FR-045、SC-014 至 SC-019；同步 Phase 9-12 任务、AGENTS 约束和 requirements 检查项。明确配置台新增 `VIDEO_CHANNEL` 动作，编码复用 `text_content` 存储，发送端复用 `fc/common` 视频号工具。
- 测试命令：不适用，当前仅更新 spec-kit 文档，未修改业务代码。
- 测试结果：文档更新完成；后续实现阶段按 T051-T071 执行代码和测试。
- 自检结论：本次文档不新建 spec 目录，符合复用同一视频号发送链路规格的规则。

### T051-T055 作业点评配置台视频号动作配置

- 执行内容：在 `data-RC/juzi-service` 新增 `HomeworkActionType.VIDEO_CHANNEL`；`HomeworkActionDto` 增加 `videoChannelCode`；`HomeworkConfigService` 新增编码 trim、大写规范化和 `V` 加数字校验，并复用 `text_content` 存储编码；`addAction` / `updateAction` 和 admin / compat controller 均支持 `videoChannelCode`；`homework-config.html` 下拉、输入、展示、新增和编辑流程支持视频号编码。
- 测试命令：`mvn -pl juzi-service -DskipTests=false -Dtest=HomeworkConfigServiceVideoChannelTest test`
- 测试结果：`Tests run: 2, Failures: 0, Errors: 0, Skipped: 0`，`BUILD SUCCESS`。
- 自检结论：`v15` 能保存为 `V15` 并输出 `videoChannelCode`；非法编码被拒绝；`VIDEO_CHANNEL` 不触发文件上传字段，未新增数据库字段。

### T056-T061 sop-reply 配置发送链路支持 VIDEO_CHANNEL

- 执行内容：在 `SopActionType` / `SopAction` 增加 `VIDEO_CHANNEL` / `videoChannelCode`；新增 `SopVideoChannelSender`，接入 `VideoChannelMessageService`、`VideoChannelConfigLoader.fromDefaultResource()`、`UrlVideoChannelRawMessageReader`、30 分钟 raw JSON Redis 缓存适配和 7 天限发适配；`SopConfigSender` 新增视频号分支，优先读取 `videoChannelCode`，兼容 `textContent`，并保留 delay、条件匹配、`wxsend=false` 预览和 sentCount 语义。
- 测试命令：`mvn -pl common,sop-reply -am test`
- 测试结果：common `Tests run: 22, Failures: 0, Errors: 0, Skipped: 0`；sop-reply `Tests run: 13, Failures: 0, Errors: 0, Skipped: 0`；整体 `BUILD SUCCESS`。
- 自检结论：`SopVideoChannelSenderTest` 已验证 `VIDEO_CHANNEL/V15` 构造 `messageType=14` 请求且 payload 来自 raw JSON；`SopConfigSenderTest` 已验证配置动作调用视频号发送器、`textContent` 兼容读取和视频号跳过后继续发送后续文本动作。

### T062-T066 HomeWorkCommentService 支持视频号编码发送

- 执行内容：`SendInfo` 增加 `videoChannelCodes`；`HomeWorkCommentService` 增加可注入的 `SopVideoChannelSender` 和 `sendVideoChannel(WebChatVoiceDto, String, Integer)`；`sendInfo` 在奖励图片之后、提醒文本之前按编码列表发送视频号，不改变原有文本、语音、文件、图片顺序；`PianoVideoHomeWorkHandleServiceImpl` 保持识别职责，未拼接真实视频号 payload。
- 测试命令：`mvn -pl common,sop-reply -am test`
- 测试结果：见 T056-T061，`HomeWorkCommentServiceVideoChannelTest` 通过。
- 自检结论：旧发送链路具备按编码发送视频号能力；人工接管静默判断仍保留，限发/未知编码/异常由视频号发送适配器跳过并记录，不阻断后续消息。

### T067-T071 回归验证与文档记录

- 执行内容：完成 Phase 9-12 代码实现和自动化测试；复查 FR-034 至 FR-045、SC-014 至 SC-019；更新任务勾选、执行记录、requirements 备注和 D004 验证结果。
- 测试命令：`mvn -pl common,sop-reply -am test`；`mvn -pl juzi-service -DskipTests=false test`
- 测试结果：`common+sop-reply` 整体 `BUILD SUCCESS`；`juzi-service` 全量测试 `Tests run: 161, Failures: 0, Errors: 0, Skipped: 1`，`BUILD SUCCESS`。
- 自检结论：配置台、配置发送链路、旧发送链路和既有动作类型回归均已验证；未执行本地 commit，等待用户验收。

