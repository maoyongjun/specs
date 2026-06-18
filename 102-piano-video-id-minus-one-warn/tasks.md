# 任务清单：钢琴视频识别 id=-1 告警

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于 `C:\workspace\ju-chat\fc\sop-reply` 模块的钢琴视频作业识别处理链路。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和测试落点。
  - 入口/核心类：`PianoVideoHomeWorkHandleServiceImpl.handle(...)`。
  - 结果 DTO：`HomeWorkResultDto.id`，类型为 `Integer`。
  - 现有告警链路：`notifyPianoVideoRecognitionWarn(...)` -> `FcInvokeUtils.doTask(service_sys/common_warn_sender)`。
  - 测试落点：`fc/sop-reply/src/test/java`，可新增 JUnit focused test。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
  - `id` 来源于缓存/异步返回文本解析后的 `HomeWorkResultDto`，在返回结果前读取。
  - `externalKey/messageId/cacheKey` 在告警前已有来源。
- [x] T004 确认配置来源、环境变量、Redis key、MQ topic/tag、Feign/FC/HTTP 调用或数据库表是否受影响。
  - 复用 `WX003` 模板、`common_warn_sender` FC、现有 Redis 去重 key 前缀。
  - 不新增 MQ、Feign、数据库、环境变量。
- [x] T005 确认已有旧逻辑中必须保持不变的过滤、幂等、异常处理、日志、延迟和 fallback。
  - 不改异步识别触发、等待时长、缓存状态、错误处理、标题未知告警。

**检查点**：T001-T005 已在计划阶段完成，实施前需重新快速复查。

## Phase 2：风险门禁

- [x] T006 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参。
  - `new HomeWorkResultDto()` 的 `id` 为 null，不应触发新增告警。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段。
  - `id=-1` 判断必须在解析结果完成后执行，不依赖后续补齐。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用。
  - `id/title/question/isHomeWork` 来自结果 DTO；`externalKey/messageId` 来自消息 DTO；`cacheKey` 当前层构建。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为。
  - 只新增一个现有告警通道调用，不改变返回结果和识别流程。
- [x] T010 对需要用户确认的业务语义变化做记录；未确认前不得实现该变化。
  - 无阻塞项；沿用现有告警通道和模板编码。
- [x] T011 为每个关键行为建立测试映射，至少覆盖正常路径、边界路径和不回归路径。
  - `id=-1`：应触发 `UNKNOWN_DAY` 判断。
  - `id=1/null`：不触发 `UNKNOWN_DAY`。
  - `title=未知`：旧 `UNKNOWN_TITLE` 判断仍成立。

**检查点**：T006-T011 已有明确结论；实施前仍需按当前代码状态复查。

## Phase 3：实现

- [x] T012 新增 `WARN_REASON_UNKNOWN_DAY` 常量和人工介入文案常量。
- [x] T013 新增 `warnIfPianoVideoDayUnknown(...)` 与 `isUnknownDay(...)` 或等价判断。
- [x] T014 在初始缓存命中和首次等待成功返回前调用新增判断。
- [x] T015 保持标题未知、超时、异常、缓存和返回结果逻辑不变。
- [x] T016 如测试需要，提取最小可测的 package-private 判断方法，避免真实访问 Redis/FC。
- [x] T017 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [x] T018 新增或更新单元测试，覆盖 `id=-1` 告警判断。
- [x] T019 测试中断言关键下游参数或判断结果，不只断言最终返回。
- [x] T020 验证 `id=null`、`id=1`、`title=未知` 不回归。
- [x] T021 运行目标模块 focused test 或编译命令，并记录结果。
- [x] T022 搜索确认新增告警原因、文案和调用点符合规格。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `102-piano-video-id-minus-one-warn` 规格文档，确认目标类现有告警链路和 `HomeWorkResultDto.id` 类型。
- 验证方式：读取目标类、`HomeWorkResultDto`、`HomeWorkMessageDto`、`SopHomeWorkHandleService`、`RedisClient`、模块 `pom.xml` 和测试目录；使用代码搜索确认 `WX003/common_warn_sender` 现有告警方式。
- 自检结论：计划阶段满足强制门禁；尚未进入业务代码实施。

### D002 - 实现记录

- 实现内容：在 `PianoVideoHomeWorkHandleServiceImpl` 新增 `UNKNOWN_DAY` 告警原因、人工介入文案、`warnIfPianoVideoDayUnknown(...)` 和 `isUnknownDay(...)`；在初始缓存命中结果和首次等待成功结果返回前新增 `id=-1` 判断；新增 focused JUnit 覆盖 `id=-1/null/1` 与旧 `title=未知` 判断。
- 测试命令：`mvn -Dtest=PianoVideoHomeWorkHandleServiceImplTest test`；`mvn -DskipTests compile`
- 测试结果：通过，focused test 为 `Tests run: 2, Failures: 0, Errors: 0, Skipped: 0`；compile 为 `BUILD SUCCESS`。
- 自检结论：新增告警判断命中范围为 `HomeWorkResultDto.id == -1`；原标题未知、超时、异常、缓存、等待和返回结果逻辑未改变。

### D003 - 纠正记录模板

- 触发原因：说明为什么需要纠正。
- 修正内容：说明具体修正。
- 文档同步：说明同步了哪些文件。
- 验证结果：说明测试或静态验证。
