# 功能规格：skuId=4 隔天消息分流到 ai-reply

**功能目录**：`040-app-task-sku4-ai-reply-route`  
**创建日期**：`2026-05-29`  
**状态**：Implemented  
**输入**：用户要求修改 `C:\workspace\ju-chat\fc\rocket-mq-consumer\src\main\java\com\drh\mq\service\AppTask.java`，隔天 MQ 消息当前路由到 `prod-msg-consumer`，需要对 `skuId=4` 的消息分流到 `ai-reply`，并检查给定 JSON 格式是否兼容。

## 背景

- 当前问题：`AppTask` 对所有 MQ 消息都使用 `System.getenv("function_name")` 作为 FC 函数名，生产环境会落到 `prod-msg-consumer`。
- 当前行为：解析每条 MQ 事件的 `body`，固定 `serviceName=ai-service`，原样下传 `body`。
- 目标行为：当 `body.sku_id` 或兼容字段 `body.skuId` 为 `4` 时，函数名改为 `ai-reply`；其他消息维持原有环境变量路由。
- 非目标：不修改 MQ 协议、Redis key、OTS/数据库写入、上游延迟消息生成、`ai-reply` 内部处理逻辑。

## 用户场景与测试 *(必填)*

### 用户故事 1 - sku_id=4 消息进入 ai-reply（优先级：P1）

隔天消息中 `sku_id` 为 `4` 时，需要走 `ai-reply` 的通用聊天处理，而不是继续走 `prod-msg-consumer`。

**独立测试**：构造包含样例核心字段的 MQ 事件，调用 `AppTask.handleRequest`，捕获 `FcInvokeInput`，断言 `functionName=ai-reply` 且 `taskObj` 保留 `redisKey`、`timestamp`、`day`、`agent_id` 等字段。

**验收场景**：

1. **Given** MQ body 包含 `sku_id:"4"`，**When** `AppTask` 处理消息，**Then** FC 调用目标为 `ai-service/ai-reply`。
2. **Given** MQ body 包含 `skuId:4` 但没有 `sku_id`，**When** `AppTask` 处理消息，**Then** FC 调用目标为 `ai-service/ai-reply`，且下传 `taskObj.sku_id="4"`。

### 用户故事 2 - 非 4 消息保持旧路由（优先级：P1）

除 `skuId=4` 之外的隔天消息不能受影响，仍走原有 `function_name` 环境变量配置。

**独立测试**：构造 `sku_id=5` 或缺失 sku 的 MQ 事件，断言捕获到的 `functionName` 等于测试任务覆盖的默认函数名。

**验收场景**：

1. **Given** MQ body 包含 `sku_id:"5"`，**When** `AppTask` 处理消息，**Then** FC 调用目标继续使用默认函数名。
2. **Given** MQ body 不含 sku 字段，**When** `AppTask` 处理消息，**Then** FC 调用目标继续使用默认函数名。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `body`：来源为 `JSONArray input` 中每个事件的 `body` 字段；在构造 `FcInvokeInput` 前解析。
  - `sku_id` / `skuId`：来源为 `body`；在 `resolveFunctionName` 前读取；若兼容字段 `skuId` 命中 ai-reply 分支，则调用前补齐 `sku_id`。
  - `functionName`：`sku=4` 时当前层现算为 `ai-reply`；其他情况来自 `System.getenv("function_name")`。
  - `serviceName`：保持当前层固定值 `ai-service`。
- 下游读取字段清单：
  - `ai-reply AppTask` 通过 `EmpExternalDto` 读取 `redisKey`、`timestamp`、`time_gap`、`day`、`sku_id`、`agent_id`、`external_user_id`、`user_id`、`user_bot_id`、`camp_date_id`、`emp_id`、`is_first`、`isGroup`、`msgType`、`messageId`。
- 空对象 / 占位对象风险：
  - 不允许缺失或无法解析的 `body` 构造成空 JSON 下传；实现应跳过并记录日志。
- 调用顺序风险：
  - `functionName` 和 `sku_id` 兼容补齐必须发生在 `FcInvokeUtils.doTask` 前。
- 旧逻辑保持：
  - `serviceName=ai-service`、异步 FC 调用、原始 `body` 下传、MDC 字段、非 4 默认函数名来源保持不变。
- 需要用户确认的设计选择：
  - 无；用户已明确 `skuId=4` 使用 `ai-reply`，非 4 保持 `function_name`。

## 边界情况

- `body` 是 JSON object 或 JSON string：均解析为 `JSONObject`。
- `sku_id` 为字符串 `"4"`、数字 `4` 或 `skuId` 数字 `4`：均视为 `4`。
- `sku_id` 为空、缺失、非 4 或非法文本：继续使用默认函数名。
- `body` 缺失或解析失败：记录日志并跳过，不调用 FC。
- 样例 `day:"day0"` 可映射到 `ai-reply` 的 `DayEnum.day0`；`sku_id:"4"` 可映射到 `EmpExternalDto.sku_id` 字符串字段。

## 需求 *(必填)*

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下创建本 Spec Kit 目录。
- **FR-002**：`AppTask` MUST 对 `body.sku_id` / `body.skuId` 为 `4` 的消息调用 `ai-service/ai-reply`。
- **FR-003**：`AppTask` MUST 对非 4、缺失或非法 sku 消息保持原有 `function_name` 路由。
- **FR-004**：`skuId` 兼容字段命中 ai-reply 时 MUST 在下传 `taskObj` 中补齐 `sku_id`。
- **FR-005**：系统 MUST NOT 修改 MQ body 协议、Redis、OTS、数据库或 `ai-reply` 内部逻辑。
- **FR-006**：单元测试 MUST 断言 FC 下游参数，不真实调用 FC。

## 成功标准 *(必填)*

- **SC-001**：`sku_id:"4"` 样例格式被路由到 `ai-reply`。
- **SC-002**：`skuId:4` 兼容格式被路由到 `ai-reply` 并补齐 `sku_id`。
- **SC-003**：`sku_id:"5"` 和缺失 sku 继续使用默认函数名。
- **SC-004**：`rocket-mq-consumer` 目标测试通过。

## 假设

- 生产环境 `function_name` 当前配置为 `prod-msg-consumer`。
- `ai-reply` 生产函数名为固定字符串 `ai-reply`，服务名仍为 `ai-service`。
- 本需求只处理隔天 MQ 消费侧路由，不改变上游生成消息的字段。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成参数来源、字段兼容和强制门禁检查。

### D002 - 实现记录

- 实现内容：
  - `AppTask` 新增 `sku_id` / `skuId` 解析，`sku=4` 路由到 `ai-service/ai-reply`，其他消息保持 `System.getenv("function_name")`。
  - 兼容 MQ `body` 为 JSON object 或 JSON string；无法解析的 `body` 记录日志并跳过，不下传空 JSON。
  - `skuId` 兼容字段命中 ai-reply 时补齐 `taskObj.sku_id`。
  - 抽出 `resolveFunctionName`、`resolveSkuId`、`getDefaultFunctionName`、`invokeFc`，用于单测断言下游 FC 参数。
- 测试命令：
  - 首次执行 `mvn -pl rocket-mq-consumer -am "-Dtest=AppTaskTest,UserLevelUpdateTaskTest" test`，聚合依赖模块 `common` 因无匹配测试触发 Surefire 失败。
  - 复跑 `mvn -pl rocket-mq-consumer -am "-Dtest=AppTaskTest,UserLevelUpdateTaskTest" "-Dsurefire.failIfNoSpecifiedTests=false" test`。
- 测试结果：
  - BUILD SUCCESS。
  - `AppTaskTest`：Tests run: 5, Failures: 0, Errors: 0, Skipped: 0。
  - `UserLevelUpdateTaskTest`：Tests run: 4, Failures: 0, Errors: 0, Skipped: 0。
  - 总计：Tests run: 9, Failures: 0, Errors: 0, Skipped: 0。
- 自检结论：
  - 样例字段与 `ai-reply` 的 `EmpExternalDto` 兼容；`day:"day0"` 可映射到 `DayEnum.day0`，`sku_id:"4"` 可映射到字符串字段。
  - 未修改 MQ 协议、Redis、OTS、数据库、`ai-reply` 内部逻辑或非 4 默认路由。
  - 发现 `fc/rocket-mq-consumer/dependency-reduced-pom.xml` 在本次改动前已有 dirty diff，未纳入本需求处理。
