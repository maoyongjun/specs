# 任务清单：通用预警插件调用

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的单元测试，并断言下游 HTTP 请求参数内容。

## Phase 1：代码事实确认

- [ ] T001 复查用户需求和本目录 `AGENTS.md`，确认目标为通过 FC 转发代理异步调用 `common_warn_sender` 插件，服务名 `service_sys`，方法名按环境区分。
- [ ] T002 用代码搜索确认插件入口 `AppTask.handleRequest`、入参 `CommonWarnSenderInput`（4 字段）、现有 `FcInvokeUtils.doSyncTask`（FC SDK 同步调用）的实现细节。
- [ ] T003 确认关键参数：`external_key` 格式（`split(":")` 至少 4 段）、`sendTemplateList`（策略编码列表）、`templateVariable`（可选额外模板变量）、`appendJumpLink`（可选默认 true）。
- [ ] T004 确认 FC 转发代理 URL 来源（环境变量 or 硬编码）、环境判断机制（如何区分测试/正式方法名）、HTTP 客户端选型（hutool-http or 其他）。
- [ ] T005 确认必须保持不变的旧逻辑：现有 `FcInvokeUtils.doSyncTask` 同步调用路径、插件内部全链路（Center 查询、策略解析、飞书/企微发送、Redis 频控、升级机制）。

**检查点**：不得在未完成 T001-T005 前进入实现。

## Phase 2：风险门禁

- [ ] T006 检查是否存在空 `taskObj` 或只赋值部分字段的风险：`CommonWarnSenderInput` 至少需要 `external_key` 和 `sendTemplateList`，调用方前置校验。
- [ ] T007 检查是否存在调用后赋值：所有参数在构建 HTTP 请求体前确定，异步调用后无后续赋值。
- [ ] T008 检查下游读取字段来源：FC 转发代理读取 `serviceName`/`functionName`/`taskObj`，插件读取 `taskObj` 中 4 字段，全部有明确来源。
- [ ] T009 检查本次方案是否改变现有调用契约：新增 HTTP 异步调用路径，不改现有 FC SDK 同步调用、不改插件源码、不新增 FC 服务。
- [ ] T010 对需要用户确认的业务语义变化做记录（FC 转发代理 URL、环境判断机制、HTTP 客户端选型）；未确认前不得实现该变化。
- [ ] T011 为每个关键行为建立测试映射：HTTP 请求参数断言、`external_key` 为空校验、环境区分 `functionName`，至少覆盖正常路径、边界路径和不回归路径。

**检查点**：T006-T011 必须有明确结论；发现高风险时先更新 `spec.md` 的"历史问题防漏分析"。

## Phase 3：实现

- [ ] T012 新增 HTTP 异步调用方法（或工具类），构建 FC 转发代理请求：URL、请求头（`Content-Type`、`X-Fc-Invocation-Type: Async`）、请求体（`serviceName`、`functionName`、`taskObj`）。
- [ ] T013 实现环境判断逻辑：根据配置或环境变量确定 `functionName`（测试 `common_warn_sender` / 正式 `common_warn_sender_test`）。
- [ ] T014 实现 `external_key` 前置校验：为空时不发 HTTP 请求，返回空结果或记录日志。
- [ ] T015 调用日志：记录请求 URL、`serviceName`、`functionName`、`external_key` 摘要和 HTTP 响应状态码。
- [ ] T016 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [ ] T017 新增单元测试，断言 HTTP 请求参数：URL、请求头（`Content-Type`、`X-Fc-Invocation-Type`）、请求体中 `serviceName="service_sys"`、`functionName` 按环境取值、`taskObj` 包含正确的 `external_key`/`sendTemplateList` 等字段。
- [ ] T018 测试 `external_key` 为空时不发起 HTTP 请求。
- [ ] T019 测试环境区分：测试环境 `functionName="common_warn_sender"`，正式环境 `functionName="common_warn_sender_test"`。
- [ ] T020 验证现有 `FcInvokeUtils.doSyncTask` 不受影响（不回归）。
- [ ] T021 运行目标模块测试或编译命令，并记录结果。
- [ ] T022 搜索确认没有残留旧调用、旧字段或旧口径。

## 执行记录

### D001 - 文档记录

- 执行内容：创建并填写 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- 验证方式：代码阅读 + 插件源码事实确认（`AppTask.handleRequest`、`CommonWarnSenderInput`、`FcInvokeUtils.doSyncTask`）；Phase 1/2 门禁待实现前逐项确认。
- 自检结论：满足强制门禁要求；待用户确认 FC 转发代理 URL、环境判断机制和 HTTP 客户端选型后进入实现。

### D002 - 实现记录

- 实现内容：`<代码改动摘要>`。
- 测试命令：`<命令>`。
- 测试结果：`<Tests run / BUILD SUCCESS / 静态检查结果>`。
- 自检结论：`<参数来源、调用顺序、旧逻辑保持、剩余风险>`。

### D003 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
