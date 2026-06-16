# 规格执行说明

本目录是「通用预警插件调用」的 Spec Kit 文档。实现必须按 `spec.md`、`tasks.md` 和 `checklists/requirements.md` 执行。

## 作用范围

- 规格目录：`C:\workspace\ju-chat\specs\094-common-warn-sender-invoke`
- 目标项目：`C:\workspace\ju-chat\coze_plugin\common_warn_sender`（插件源码，只读参考）
- 调用方项目：`C:\workspace\ju-chat` 下需要触发通用预警的 Java 模块
- 插件入口类：`com.drh.commonwarnsender.service.AppTask`（实现 `PojoRequestHandler<CommonWarnSenderInput, JSONObject>`）
- 插件入参 DTO：`com.drh.commonwarnsender.dto.CommonWarnSenderInput`（`external_key`、`sendTemplateList`、`templateVariable`、`appendJumpLink`）
- 现有 FC 调用工具：`com.drh.commonwarnsender.util.FcInvokeUtils`（FC SDK 同步调用，本规格不改）
- 新增调用工具：HTTP 异步调用方法（通过 FC 转发代理 POST）

## 当前目标

- 在 Java 应用中新增通过 FC 转发代理异步调用 `common_warn_sender` 插件的能力，仿照 Python Coze handler 的调用模式。
- 服务名固定为 `service_sys`，方法名按环境区分：测试 `common_warn_sender`、正式 `common_warn_sender_test`。
- 调用为异步（fire-and-forget），HTTP POST 到 FC 转发代理，请求头包含 `X-Fc-Invocation-Type: Async`。
- `taskObj` 传入 `CommonWarnSenderInput` 结构，至少包含 `external_key` 和 `sendTemplateList`。

## 固定实现口径

- FC 转发代理调用模式（仿照 Python handler）：
  - HTTP POST 到 FC 转发代理 URL（参考 Python 代码中 `https://fc.kkhuacai.cn/transfer/fc`）。
  - 请求头：`Content-Type: application/json`、`X-Fc-Invocation-Type: Async`。
  - 请求体结构：`{ "serviceName": "service_sys", "functionName": "<环境方法名>", "taskObj": { ... } }`。
- 服务名固定为 `"service_sys"`，不允许调用方覆盖。
- 方法名按环境区分：
  - 测试环境：`"common_warn_sender"`。
  - 正式环境：`"common_warn_sender_test"`。
  - 环境判断机制待确认（环境变量 / `external_key` 后缀 / 配置文件）。
- `taskObj` 结构对应 `CommonWarnSenderInput`：
  - `external_key`（String，必填）：格式 `externalUserId:empId:campDateId:qwUserId[:debug]`。
  - `sendTemplateList`（List<String>，必填）：预警策略编码列表。
  - `templateVariable`（JSONObject，可选）：额外模板变量。
  - `appendJumpLink`（Boolean，可选，默认 true）：企微消息是否追加聊天跳转链接。
- `external_key` 为空时，调用方前置校验不发起 HTTP 请求（与 Python handler 中 `if(not empty(input_data.external_key)): return` 一致）。
- 异步调用为 fire-and-forget，调用方不阻塞等待结果、不轮询执行状态。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认 FC 转发代理 URL、环境判断机制、HTTP 客户端选型和调用方落点。
- 不允许把空对象、占位 DTO 或未赋值字段当成有效输入继续传递；`taskObj` 中 `external_key` 和 `sendTemplateList` 必须在调用前赋值。
- 任何会改变调用顺序、接口契约、远程调用、MQ 字段、Redis key、数据库结构或外部行为的方案，实施前必须确认业务意图。
- 单元测试不能只验证最终结果；HTTP 调用必须做下游参数断言（URL、请求头、请求体中 `serviceName`/`functionName`/`taskObj` 字段内容）。

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：`external_key`、`sendTemplateList` 来自调用方业务上下文；`serviceName` 为固定常量；`functionName` 由环境配置确定；FC 转发代理 URL 由环境变量或配置确定。
- 赋值时机：所有参数在构建 HTTP 请求体前已确定，无调用后赋值。
- 占位对象：`taskObj` 不允许为 `new CommonWarnSenderInput()` 空对象；至少 `external_key` 和 `sendTemplateList` 必须有值。
- 下游读取：FC 转发代理读取 `serviceName`、`functionName`、`taskObj`；插件读取 `taskObj` 中 4 个字段；全部有来源。
- 旧逻辑保持：现有 `FcInvokeUtils.doSyncTask`（FC SDK 同步调用）不变；插件内部逻辑不变。
- 影响范围：新增一个 HTTP 异步调用方法；不修改现有同步调用；不修改插件源码；不新增 FC 服务。
- 测试映射：HTTP 请求参数断言、`external_key` 为空前置校验、环境区分 `functionName`，均有对应测试。

## 重点代码位置

- 插件入口（只读参考）：`com.drh.commonwarnsender.service.AppTask#handleRequest`
- 插件入参 DTO（只读参考）：`com.drh.commonwarnsender.dto.CommonWarnSenderInput`
- 现有 FC 同步调用（不改）：`com.drh.commonwarnsender.util.FcInvokeUtils#doSyncTask`
- 新增调用方法：待实现（HTTP POST 异步调用 FC 转发代理）
- 测试类：待实现

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
