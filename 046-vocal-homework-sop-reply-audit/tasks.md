# 任务清单：声乐作业点评 SopReply 迁移核查

**输入**：来自 `spec.md` 的核查规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：本次为文档核查，验证方式为静态搜索、git 历史核查和文档占位符检查。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标项目为 `C:\workspace\ju-chat\fc`。
- [x] T002 用 `rg` 确认真实入口、调用链、核心实现类和旧入口位置。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
- [x] T004 确认配置来源、环境变量和 FC 调用名是否受影响。
- [x] T005 确认旧逻辑中必须保持不变的灰度、fallback、群聊分支、识别-only 分支和异常处理。
- [x] T005A 追加核查 `sopReply time window config is empty` 的触发路径、配置来源和旧逻辑差异。
- [x] T005B 补充现场排查三步口径：开关、课程时间、调用链。

**检查点**：已完成 T001-T005。本次不进入业务代码实现。

## Phase 2：风险门禁

- [x] T006 检查是否存在空 DTO 或占位结果风险：当前旧逻辑会用 `new HomeWorkResultDto()` 表达未命中或跳过，文档已记录。
- [x] T007 检查是否存在调用后赋值风险：本次未修改代码，已记录 `sop-reply` 发送后才持久化点评进度和打标签。
- [x] T008 检查每个下游读取字段是否有来源：已在 `spec.md` 记录。
- [x] T009 检查是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为：本次不改业务代码。
- [x] T010 对需要用户确认的业务语义变化做记录：全量切换、移除 fallback、修改 prod function 默认值均需另行确认。
- [x] T011 为关键行为建立验证映射：静态搜索、git history、占位符检查、git status。
- [x] T011A 为时间窗口空配置建立验证映射：静态确认 Redis key、Center 接口字段、`SopReply` 返回路径、旧 `homework-review` fallback。
- [x] T011B 为现场三步排查建立验证映射：开关配置、课程时间 SQL、`Delay-mq -> sop-reply` 调用链。

**检查点**：T006-T011 已完成，结论写入 `spec.md`。

## Phase 3：文档创建

- [x] T012 从 `specs/_template` 复制创建 `046-vocal-homework-sop-reply-audit`。
- [x] T013 填写 `AGENTS.md`，标明目标项目、模块、核查目标和强制门禁。
- [x] T014 填写 `spec.md`，记录代码事实、提交历史、当前调用链、时间窗口空配置原因、现场三步排查口径和运行时未知点。
- [x] T015 填写 `tasks.md` 和 `checklists/requirements.md`，同步本次核查任务和文档质量门禁。

## Phase 4：测试与验证

- [x] T016 运行模板占位符检查，确认无残留模板占位内容。
- [x] T017 运行 `git status --short`，确认 `specs` 只新增本需求目录。
- [x] T018 确认 `fc` 既有 dirty 文件未被触碰。
- [x] T019 记录最终验证结果。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `046-vocal-homework-sop-reply-audit`，并填充 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- 验证方式：`rg` 静态搜索、`git log`、`git show`、模板占位符检查、`git status --short`。
- 自检结论：代码事实已确认；模板占位符检查已通过；线上配置值仍需运行时查询。

### D002 - 代码事实确认记录

- `delay-mq/AppTask.java`：存在 `homeWorkSopReplyPercent` 灰度逻辑，默认 10%；命中灰度调用 `invokeSopReplyFc()`，未命中调用 `invokeHomeWorkReviewFc()`。
- `delay-mq/VoiceService.java`：`invokeSopReplyFc()` 调用 `sop-reply`，`invokeHomeWorkReviewFc()` 调用 `prod-homework-review` 或 `homework-review`。
- `sop-reply/SopReply.java`：新 handler 负责识别、配置路由、发送、点评进度持久化和打标签。
- `homework-review/AppTask.java`：旧 handler 仍存在，作为非灰度路径和异常 fallback 的目标函数。

### D003 - 后续运行时核验任务

- 查询线上 `homeWorkSopReplyPercent`。
- 查询线上 `sopReplyServiceName`、`sopReplyFunctionName`、`sopReplyFunctionNameProd`、`sopReplyFunctionNameTest`。
- 查询线上 `sop-reply` 函数 handler 绑定。

### D004 - 验证记录

- 模板占位符检查：通过，无匹配。
- `specs` 仓库状态：仅新增 `046-vocal-homework-sop-reply-audit/`。
- `fc` 仓库状态：仍只有既有 `qw-tag/dependency-reduced-pom.xml`、`rocket-mq-consumer/dependency-reduced-pom.xml` 修改；本次未触碰。

### D005 - time window config is empty 核查记录

- 执行内容：核查 `SopReply.checkTimeIsOpen()`、`getConfigTimes()`、`getHomeBeginTime()`、`RedisConstants.getConfigTimeKey()`、`CenterUtil.selectUserJson()`，并对比旧 `homework-review/AppTask.checkTimeIsOpen()`。
- 静态结论：该 warning 的直接原因是 `getConfigTimes()` 返回空；典型原因是 Redis key `ai:configTime:{campDateId}:{dayNum}` 没有缓存，且 Center 接口响应缺少 `jsonObject.live_end_time`。
- 行为影响：`SopReply` 会在作业识别前返回空结果；旧 `homework-review` 遇到课程时间为空会 fallback 到旧 `enableTime`/特殊账号时间窗口，`SopReply` 当前不会。
- 剩余风险：需要线上核验具体 `campDateId/dayNum/externalUserId` 对应 Redis key、接口响应和 `sys_domain`。

### D006 - 三点排查口径记录

- 作业点评开关：`ai_auto_review_config:568:269` / `ai_auto_review_config:%s:%s`，示例配置 `{"aiAutoReview":1,"aiStatus":1,"chatList":["wraZOBSgAAH9bUZP_bubjJNTu5Lz5h0A"],"qwUserId":"Dong"}`。
- 课程时间：`drh_live`，示例查询 `select * from drh_live where live_camp_id =1692 and mark=1 and is_del =0 order by class_time limit 6;`。
- 调用链：`Delay-mq -> sop-reply`。
