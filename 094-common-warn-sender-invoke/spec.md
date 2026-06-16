# 功能规格：通用预警插件调用

**功能目录**：`094-common-warn-sender-invoke`  
**创建日期**：`2026-06-16`  
**状态**：Draft  
**输入**：仿照 Coze Python handler 代码，通过 FC 转发代理异步调用 `common_warn_sender` 插件。服务名 `service_sys`，方法名测试环境 `common_warn_sender`、正式环境 `common_warn_sender_test`。插件源码位于 `C:\workspace\ju-chat\coze_plugin\common_warn_sender`。

## 背景

- 当前问题：Java 应用（`ju-chat` 体系）需要触发通用预警发送流程时，缺少统一的异步调用入口。现有 `FcInvokeUtils.doSyncTask` 走阿里云 FC SDK 同步调用（`Sync`），而 Coze 插件侧已有成熟的 HTTP 异步调用模式（POST 到 FC 转发代理 + `X-Fc-Invocation-Type: Async`），需要在 Java 侧复制该模式以触发 `common_warn_sender` 插件。
- 当前行为：`common_warn_sender` 插件已部署为阿里云 FC 函数（`com.drh.commonwarnsender.service.AppTask` 实现 `PojoRequestHandler<CommonWarnSenderInput, JSONObject>`），接受 `CommonWarnSenderInput` 参数并通过 Center 查询员工信息、解析预警策略、经飞书/企微发送预警消息。Java 侧现有 `FcInvokeUtils` 仅支持 FC SDK 同步调用，不支持通过 HTTP 转发代理异步调用。
- 目标行为：新增 Java 侧调用能力，通过 HTTP POST 异步调用 FC 转发代理，触发 `common_warn_sender` 插件。调用参数仿照 Python handler 模式：`serviceName=service_sys`、`functionName` 按环境区分（测试 `common_warn_sender` / 正式 `common_warn_sender_test`）、`taskObj` 传入插件入参。调用为异步（fire-and-forget），不等待插件执行结果。
- 非目标：不修改 `common_warn_sender` 插件内部逻辑、不新增 FC 转发代理服务、不实现同步调用模式、不轮询异步执行结果、不修改现有 `FcInvokeUtils.doSyncTask`。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 异步触发通用预警（优先级：P1）

调用方（Java 应用中的某个业务服务）需要触发通用预警时，组装 `external_key` 和 `sendTemplateList` 等参数，通过 FC 转发代理异步调用 `common_warn_sender` 插件。调用方发出 HTTP POST 请求后即返回（fire-and-forget），由 FC 异步执行插件逻辑（查询员工、解析策略、发送飞书/企微消息）。

**独立测试**：mock HTTP 客户端，断言请求 URL 指向 FC 转发代理、请求头包含 `Content-Type: application/json` 和 `X-Fc-Invocation-Type: Async`、请求体包含正确的 `serviceName`、`functionName` 和 `taskObj`（含 `external_key`、`sendTemplateList` 等字段）。

**验收场景**：

1. **Given** 调用方传入有效 `external_key`（格式 `externalUserId:empId:campDateId:qwUserId`）和 `sendTemplateList`（如 `["FX_001"]`），**When** 发起异步调用，**Then** HTTP POST 请求发往 FC 转发代理，请求体 `serviceName="service_sys"`、`functionName` 按环境取值、`taskObj` 包含完整 `CommonWarnSenderInput` 结构，请求返回 HTTP 202（异步接受）。
2. **Given** 当前运行环境为测试，**When** 发起调用，**Then** `functionName="common_warn_sender"`。
3. **Given** 当前运行环境为正式，**When** 发起调用，**Then** `functionName="common_warn_sender_test"`。

### 用户故事 2 - 外部键为空时的前置校验（优先级：P2）

调用方在发起调用前检查 `external_key` 是否为空。如果为空，不调用 FC 转发代理，直接返回或记录日志，避免无效请求。这与 Python handler 中 `if(not empty(input_data.external_key)): return {"message": "null"}` 的行为一致。

**独立测试**：传入空 `external_key`，断言不发起 HTTP 请求，方法返回空结果或抛出明确异常。

**验收场景**：

1. **Given** `external_key` 为 `null` 或空串，**When** 尝试调用，**Then** 不发 HTTP 请求，返回标识"参数为空"的结果。
2. **Given** `external_key` 有值但格式不足 4 段（`split(":")` 长度 < 4），**When** 调用到达插件，**Then** 由插件内部校验返回 `external_key format error`（此为插件行为，调用方不前置校验格式）。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `external_key`：来源 调用方业务上下文（通常从外部事件或定时任务中获取）；赋值时机 在构建 `taskObj` 前已确定；下游由插件 `AppTask.handleRequest` 读取，`split(":")` 解析为 `externalUserId`、`empId`、`campDateId`、`qwUserId`。
  - `sendTemplateList`：来源 调用方根据业务场景确定的策略编码列表（如 `["FX_001", "WX_001"]`）；赋值时机 在构建 `taskObj` 前已确定；下游由插件 `normalizeCodes` 方法读取并标准化。
  - `templateVariable`（可选）：来源 调用方传入的额外模板变量 `JSONObject`；赋值时机 可选，在构建 `taskObj` 前设置；下游由 `buildBaseTemplateVariables` 合并到模板变量中。
  - `appendJumpLink`（可选）：来源 调用方指定是否追加企微聊天跳转链接，默认 `true`；赋值时机 可选；下游由 `buildWeComContent` 读取。
  - `serviceName`：固定常量 `"service_sys"`；在构建请求体前确定。
  - `functionName`：按环境区分，测试 `"common_warn_sender"` / 正式 `"common_warn_sender_test"`；在构建请求体前由环境配置或环境变量确定。
  - FC 转发代理 URL：来源 环境变量或配置文件（参考 Python 代码中 `https://fc.kkhuacai.cn/transfer/fc`）；在发起 HTTP 请求前确定。
- 下游读取字段清单：
  - 插件 `AppTask.handleRequest` 读取 `external_key`（必填，split 解析）、`sendTemplateList`（必填，策略编码）、`templateVariable`（可选，额外模板变量）、`appendJumpLink`（可选，默认 true）。
  - FC 转发代理读取 `serviceName`、`functionName`、`taskObj`，将 `taskObj` 反序列化后传递给目标函数。
- 空对象 / 占位对象风险：
  - `taskObj` 不应为空 `new CommonWarnSenderInput()`（所有字段为 null）；至少 `external_key` 和 `sendTemplateList` 必须有值，否则插件直接返回失败。调用方在构建请求体前必须校验。
  - `templateVariable` 可为 `null`（插件内部 `buildBaseTemplateVariables` 有 null 检查）。
- 调用顺序风险：
  - 无调用后赋值问题；所有参数在构建 HTTP 请求体前已确定。
  - 异步调用为 fire-and-forget，调用方不等待结果；若需确认发送结果，需依赖插件侧日志或回调（不在本规格范围）。
- 旧逻辑保持：
  - 现有 `FcInvokeUtils.doSyncTask`（FC SDK 同步调用）保持不变，本规格新增独立的 HTTP 异步调用路径。
  - 插件内部逻辑（`AppTask.handleRequest` 全链路：Center 查询、策略解析、飞书/企微发送、Redis 频控、升级机制）不变。
  - 异步调用使用 `X-Fc-Invocation-Type: Async`，与现有同步调用（`Sync`）互不干扰。
- 需要用户确认的设计选择：
  - FC 转发代理 URL：Python 代码中使用 `https://fc.kkhuacai.cn/transfer/fc`，Java 侧是否使用相同 URL 还是从环境变量读取？
  - 环境判断机制：是通过环境变量（如 `spring.profiles.active`）区分测试/正式，还是通过 `external_key` 后缀判断（类似 Python 代码中 `determine_environment` 的逻辑）？
  - HTTP 客户端选型：使用 `hutool-http`（项目已有依赖）还是其他 HTTP 客户端？

## 边界情况

- `external_key` 为 `null` 或空串：调用方前置校验，不发 HTTP 请求，返回空结果或记录日志。
- `external_key` 格式不足 4 段：插件内部校验返回 `external_key format error`；调用方不前置校验格式（由插件负责）。
- `sendTemplateList` 为 `null` 或空列表：插件内部校验返回 `sendTemplateList is required`；调用方应前置校验以避免无效请求。
- FC 转发代理返回 HTTP 202：异步调用已接受，调用方无需额外处理（fire-and-forget）。
- FC 转发代理返回非 202（如 500、超时）：调用方记录错误日志；可配置重试策略（不在本规格范围，但预留日志点）。
- `profile` 字段（Python 代码中出现但 `CommonWarnSenderInput` 无此字段）：需确认是否为旧版本字段或额外透传参数。如插件不需要，可不传。
- 网络超时或连接失败：HTTP 客户端设置合理超时（参考 `FcInvokeUtils` 中 `readTimeout=86400`），异步调用超时后记录日志。
- 并发调用：异步调用无状态，支持并发；插件内部通过 Redis 频控（`repeatLimitType`）防止重复发送。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 通过 HTTP POST 异步调用 FC 转发代理，请求体包含 `serviceName="service_sys"`、`functionName`（按环境区分）和 `taskObj`（`CommonWarnSenderInput` 结构）。
- **FR-002**：HTTP 请求头 MUST 包含 `Content-Type: application/json` 和 `X-Fc-Invocation-Type: Async`。
- **FR-003**：`functionName` MUST 根据运行环境区分：测试环境 `"common_warn_sender"`，正式环境 `"common_warn_sender_test"`。
- **FR-004**：`taskObj` MUST 至少包含 `external_key`（非空）和 `sendTemplateList`（非空列表）；`templateVariable` 和 `appendJumpLink` 可选。
- **FR-005**：调用方 MUST 在发起 HTTP 请求前校验 `external_key` 非空；为空时不发请求，返回空结果或记录日志。
- **FR-006**：调用为异步（fire-and-forget），调用方 MUST NOT 阻塞等待插件执行结果。
- **FR-007**：系统 MUST 记录调用日志，包含请求 URL、`serviceName`、`functionName`、`external_key` 摘要和 HTTP 响应状态码。
- **FR-008**：系统 MUST NOT 修改现有 `FcInvokeUtils.doSyncTask` 同步调用逻辑。
- **FR-009**：系统 MUST NOT 修改 `common_warn_sender` 插件源码。
- **FR-010**：单元测试 MUST 覆盖 HTTP 请求参数断言（URL、请求头、请求体中 `serviceName`/`functionName`/`taskObj` 字段内容）和 `external_key` 为空时的前置校验。

## 成功标准 *(必填)*

- **SC-001**：异步调用发出后，FC 转发代理返回 HTTP 202，表示任务已被接受。
- **SC-002**：请求体中 `serviceName`、`functionName`、`taskObj` 参数正确传递，与 Python handler 调用模式一致。
- **SC-003**：测试环境和正式环境使用不同的 `functionName`，互不影响。
- **SC-004**：`external_key` 为空时，不发起无效 HTTP 请求。
- **SC-005**：现有 `FcInvokeUtils.doSyncTask` 同步调用路径不受影响（不回归）。
- **SC-006**：单元测试全部通过，且断言到下游 HTTP 请求参数内容。

## 假设

- FC 转发代理 URL 可从环境变量获取，或与 Python 代码中的 `https://fc.kkhuacai.cn/transfer/fc` 一致。
- HTTP 客户端使用项目已有的 `hutool-http`（`cn.hutool:hutool-http:5.8.11`），与插件侧依赖一致。
- `service_sys` 是 FC 转发代理上已注册的服务名，对应 `common_warn_sender` 插件的 FC 函数。
- `external_key` 格式与插件内部解析规则一致（至少 4 段，`:` 分隔：`externalUserId:empId:campDateId:qwUserId[:debug]`）。
- Python 代码中的 `profile` 字段为旧版或额外透传参数，`CommonWarnSenderInput` 中无此字段；如调用方需要传递额外参数，可通过 `templateVariable` 字段实现。
- 若上述任一假设被推翻，需要追加 Dxxx 纠正记录。

## 执行记录

### D001 - 文档记录

- 已基于 `_template` 创建本 Spec Kit 文档（AGENTS/spec/tasks/checklist）。
- 已完成历史问题防漏分析和强制门禁检查（参数来源、占位对象、调用顺序、下游字段、旧逻辑保持、影响范围、测试映射）。
- 本阶段已确认事实：插件入口 `AppTask.handleRequest`、入参 `CommonWarnSenderInput`（4 字段）、FC 转发代理调用模式（HTTP POST + Async）、环境区分机制（`functionName` 测试/正式）、现有 `FcInvokeUtils.doSyncTask` 同步调用保持不变。
- 本阶段未修改业务代码。

### D002 - 实现记录

- `<实现后填写：实现内容、影响范围、测试命令、测试结果、自检结论。>`

### D003 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
