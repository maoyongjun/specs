# 任务清单：Gemini AppTask 重试模型切换

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于 `C:\workspace\ju-chat\fc\Gemini-Api` 项目、`AppTask` 音频 Gemini 调用链路。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和测试落点：入口 `AppTask.handleRequest`；调用链 `callExternalGeminiApiAndExtractText` -> `callExternalGeminiApi`；测试落点 `AppTaskRateLimitTest`。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型：`retryCountNum` 为输入 JSON Integer，方法开始默认 `0`，失败调度前写回 `retryCountNum + 1`。
- [x] T004 确认配置来源、环境变量、Redis key、MQ topic/tag、Feign/FC/HTTP 调用或数据库表是否受影响：只影响音频 Gemini HTTP URL 中的模型段；`GEMINI_API_TOKEN`、FC 延迟、Redis key、callback 不变。
- [x] T005 确认已有旧逻辑中必须保持不变的过滤、幂等、异常处理、日志、延迟和 fallback：限流、pic_id 限频、失败重试、飞书告警、失败 callback 均保持。
- [x] T005a 复查 mp3 大文件补充需求：`convertAudioUrlToBase64(picUrl)` 是 AppTask 音频入口；通用 `convertAudioToBase64` 还被视频任务复用，必须保持全量下载行为。

**检查点**：T001-T005 已完成，可以进入实现方案确认。

## Phase 2：风险门禁

- [x] T006 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参：本次不新增占位对象；现有重试输入 JSON 保持原用法。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段：模型选择应在 Gemini 调用前完成；不依赖调用后赋值。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用：`model` 在当前层按 `retryCountNum > 0` 现算；`prompt`、`audioBase64` 已有来源。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为：只改变重试路径 Gemini HTTP 请求 URL 的模型名；不改变接口契约、MQ/Redis/DB/FC 行为。
- [x] T010 对需要用户确认的业务语义变化做记录；未确认前不得实现该变化：无额外语义选择；按用户需求解释为 `retryCountNum > 0`。
- [x] T011 为每个关键行为建立测试映射，至少覆盖正常路径、边界路径和不回归路径：补充首轮模型、重试模型断言；复用现有限流/重试测试防回归。
- [x] T011a 为 mp3 大文件裁剪建立测试映射：小于 5MiB、等于 5MiB、实际超过 5MiB、`Content-Length > 5MiB`、`Content-Length` 不可信。

**检查点**：T006-T011 已完成；未发现阻断实现的高风险。

## Phase 3：实现

- [x] T012 按规格实现最小范围改动。
- [x] T013 保持未声明的旧行为不变。
- [x] T014 对外部调用参数增加可测试断言点，确认模型值。
- [x] T015 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [x] T016 新增或更新单元测试，覆盖关键行为。
- [x] T017 测试中断言关键下游参数内容，不只断言最终结果。
- [x] T018 验证边界情况和旧逻辑不回归。
- [x] T019 运行目标模块测试或编译命令，并记录结果。
- [x] T020 搜索确认没有残留旧调用、旧字段、旧日志或旧口径。

## 执行记录

### D001 - 文档记录

- 执行内容：创建规格目录并记录 AppTask 重试模型切换需求。
- 验证方式：读取 `AppTask.java`、`AppTaskRateLimitTest.java`、`pom.xml`，使用 `rg` 搜索 `retryCountNum`、`callExternalGeminiApiAndExtractText`、`gemini-3`。
- 自检结论：Phase 1 / Phase 2 门禁已完成，业务代码待确认后修改。

### D002 - 实现记录

- 实现内容：新增 AppTask 首轮/重试模型常量和模型选择方法；`handleRequest` 按 `retryCountNum > 0` 传入 `gemini-3.5-flash`，首轮继续传入 `gemini-3-pro`；新增三参 Gemini 调用重载并保留原两参兼容入口；更新 `AppTaskRateLimitTest` 记录并断言模型参数。
- 测试命令：`mvn -pl Gemini-Api -Dtest=AppTaskRateLimitTest test`。
- 测试结果：BUILD SUCCESS；`Tests run: 16, Failures: 0, Errors: 0, Skipped: 0`。
- 自检结论：关键参数在调用前现算现用；未改变 FC 延迟、Redis、callback、飞书告警和请求体结构；测试覆盖首轮模型和重试模型。

### D003 - 纠正记录模板

- 触发原因：用户补充要求 AppTask 传入的 mp3 URL 超过 5M 时裁剪成 2M 以内。
- 修正内容：新增 AppTask 专用 mp3 下载/裁剪逻辑，`Content-Length` 或实际读取超过 5MiB 时只返回前 2MiB 原始字节 Base64；5MiB 内保持完整；通用 `convertAudioToBase64` 不变。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 验证结果：`mvn -pl Gemini-Api '-Dtest=AppTaskRateLimitTest,AppTaskAudioLimitTest' test` 通过；`Tests run: 21, Failures: 0, Errors: 0, Skipped: 0`。

### D004 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
