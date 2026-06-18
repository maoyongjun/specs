# 任务清单：钢琴作业视频 V2 入口接入

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于 `C:\workspace\ju-chat\fc\Gemini-Api` 模块和钢琴作业视频 FC 入口链路。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和测试落点。
  - 旧入口：`PianoHomeWorkVideoTask`。
  - 新源码来源：`gemini-video-recognition/src/main/java/com/drh/gemini/video`。
  - 测试落点：`fc/Gemini-Api/src/test/java/com/drh/gemini/api`。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
  - `prompt`、`file_url`、`cacheKey`、`dispatchLockKey`、`taskId` 均来自 FC 入参或 `requestPayload`。
  - V2 请求构建前必须完成配置和入参解析。
- [x] T004 确认配置来源、环境变量、Redis key、MQ topic/tag、Feign/FC/HTTP 调用或数据库表是否受影响。
  - 涉及 Gemini HTTP 调用、Redis 缓存状态和 Redis 锁释放。
  - 不涉及 MQ、Feign、数据库表结构。
  - 用户确认不使用 jar 依赖，采用源码迁移。
- [x] T005 确认已有旧逻辑中必须保持不变的过滤、幂等、异常处理、日志、延迟和 fallback。
  - 旧入口不修改。
  - V2 保持 `requestPayload`、缓存状态、30 分钟 TTL 和 finally 释放锁语义。

**检查点**：T001-T005 已在计划阶段完成，并在实施开始前重新读取本目录 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。

## Phase 2：风险门禁

- [x] T006 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参。
  - V2 不应构建空 `GeminiProxyRequest`；缺少 `prompt`、`file_url` 或配置时失败。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段。
  - Gemini 调用前必须完成所有请求字段赋值。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用。
  - `apiKey`、`baseUrl`、`model`、`authMode`、`fieldStyle`、`mimeType`、`prompt`、`fileUri/inlineData` 均在当前层解析或构造。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为。
  - 新增 V2 外部请求路径；旧入口接口契约不改。
  - Redis TTL 和状态结构按旧入口保持。
- [x] T010 对需要用户确认的业务语义变化做记录；未确认前不得实现该变化。
  - 用户已确认源码迁移替代 jar 依赖。
  - 默认 key 硬编码有安全风险，但用户明确要求；实现需支持环境变量覆盖并脱敏。
- [x] T011 为每个关键行为建立测试映射，至少覆盖正常路径、边界路径和不回归路径。
  - 正常路径：V2 请求构造和响应解析。
  - 边界路径：缺少 key/缺少 prompt/缺少 file_url/响应无文本。
  - 不回归：旧入口测试或编译不受影响；`pom.xml` 不新增 jar 依赖。

**检查点**：T006-T011 已有明确结论；实施前按当前代码状态完成复查。

## Phase 3：实现

- [x] T012 迁移 V2 所需源码到 `fc/Gemini-Api/src/main/java/com/drh/gemini/video`。
  - 预计迁移：`AuthMode`、`FieldStyle`、`InputMode`、`GeminiProxyApiException`、`GeminiProxyClient`、`GeminiProxyRequest`、`GeminiProxyResponse`、`GeminiResponseParser`。
  - 不迁移：`GeminiVideoCli`、`CliOptions`、`EnvLoader`、`VideoPromptMappingLoader`、`VideoPromptItem`。
- [x] T013 新增 `PianoHomeWorkVideoV2Task`，复用旧入口的入参解析、缓存状态、异常状态和锁释放口径。
- [x] T014 为 V2 配置解析增加默认值、环境变量覆盖和 key 脱敏。
- [x] T015 保持未声明的旧行为不变，不修改旧入口。
- [x] T016 对外部调用参数增加可测试断言点，避免真实访问 Gemini。
- [x] T017 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [x] T018 新增或更新单元测试，覆盖 V2 关键行为。
- [x] T019 测试中断言关键下游参数内容，不只断言最终结果。
- [x] T020 验证边界情况和旧逻辑不回归。
- [x] T021 运行目标模块测试或编译命令，并记录结果。
- [x] T022 搜索确认没有新增 `gemini-video-recognition` jar 依赖，没有日志输出完整默认 key。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `101-piano-homework-video-v2-task` 规格文档，并根据用户补充将接入方式调整为源码迁移。
- 验证方式：读取旧入口、目标源码项目、`Gemini-Api` pom、测试目录和 spec 模板；使用代码搜索确认调用链和测试落点。
- 自检结论：计划阶段满足强制门禁；尚未进入业务代码实施。

### D002 - 实现记录

- 实现内容：
  - 新增 `fc/Gemini-Api/src/main/java/com/drh/gemini/video` 源码迁移类：`AuthMode`、`FieldStyle`、`InputMode`、`GeminiProxyApiException`、`GeminiProxyClient`、`GeminiProxyRequest`、`GeminiProxyResponse`、`GeminiResponseParser`。
  - 新增 `PianoHomeWorkVideoV2Task`，支持 `requestPayload`、`prompt`、`file_url`、`cacheKey`、`dispatchLockKey`、`taskId`；默认走 `fileUrl`，显式 `inputMode=auto` 时支持 fileUrl 失败后 inlineData fallback，显式 `inputMode=inlineData` 时下载远程视频转 base64。
  - V2 配置支持 `PIANO_HOMEWORK_VIDEO_V2_*` 和 `GEMINI_PROXY_*` 环境变量覆盖；默认 key 按用户要求写入常量并在日志/错误中脱敏。
  - 未修改旧 `PianoHomeWorkVideoTask`，未新增 `gemini-video-recognition` jar 依赖。
- 测试命令：
  - `mvn -Dtest=PianoHomeWorkVideoV2TaskTest test`
  - `mvn '-Dtest=PianoHomeWorkVideoTaskRouteTest,PianoHomeWorkVideoV2TaskTest' test`
  - `rg -n "gemini-video-recognition" fc/Gemini-Api/pom.xml fc/Gemini-Api/src/main/java`
  - `rg -n "sk-AFWubtUm4KW7K86m3fyV6OWOGRFcVtVNPLixT9cTHDB7fz40" fc/Gemini-Api/src/main/java fc/Gemini-Api/src/test/java`
- 测试结果：
  - V2 focused test：5 tests，0 failures，BUILD SUCCESS。
  - 旧入口路由 + V2：20 tests，0 failures，BUILD SUCCESS。
  - `gemini-video-recognition` 依赖搜索无结果。
  - 完整默认 key 仅出现在 `PianoHomeWorkVideoV2Task.DEFAULT_API_KEY` 常量处。
- 自检结论：
  - 关键参数在 Gemini 调用前完成解析和赋值；测试断言了下游 `GeminiProxyRequest` 字段。
  - RUNNING/SUCCESS/FAIL 缓存状态和 finally 解锁已由单测覆盖。
  - 旧入口类未改动，旧路由测试通过。
  - 未运行真实供应商集成测试，避免访问外部 Gemini/供应商接口。

### D003 - 纠正记录模板

- 触发原因：说明为什么需要纠正。
- 修正内容：说明具体修正。
- 文档同步：说明同步了哪些文件。
- 验证结果：说明测试或静态验证。
