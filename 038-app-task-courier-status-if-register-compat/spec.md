# 功能规格：AppTask 物流注册态兼容与已填写打标限流

**功能目录**：`038-app-task-courier-status-if-register-compat`  
**创建日期**：`2026-05-29`  
**状态**：Implemented  
**输入**：用户要求兼容 `AppTask.java`：如果 `courier_status` 为“是”，则 `jsonObject.put("if_register","是")`，用于处理没有打上“已填写”标签的场景；同时要求 `AiServiceImpl.compensateWriteOverTagIfNeeded` 使用 `RateLimitUtil.limitRun` 限流，防止请求修改标签并发量过高。

## 背景

- 当前问题：部分已发货用户没有“已填写”标签，导致 `if_register` 未返回“是”；物流消息补偿打“已填写”标签时直接调用 FC，缺少并发限流。
- 当前行为：`if_register` 主要由当前 `userid` 下的“已填写”标签写入；`compensateWriteOverTagIfNeeded` 查询 `Write_Over` 自动标签后直接调用 `invokeFc`。
- 目标行为：`courier_status=是` 时补偿返回 `if_register=是`；物流补偿打标 FC 通过独立 Redis key 限流。
- 非目标：不实际补打 `AppTask` 查询链路中的企微标签，不修改物流接口、标签配置、FC taskObj 协议、数据库或 MQ。

## 用户场景与测试

### 用户故事 1 - 已发货但缺少“已填写”标签时返回已注册态（优先级：P1）

当图书物流状态已经是“是”，但用户标签里没有“已填写”时，Coze 返回仍应包含 `if_register=是`。

**独立测试**：构造 `courier_status=是` 且无 `if_register` 的 JSON，执行补偿 helper 后验证 `if_register=是`，并通过 `DayEnum.day0.createCozeJson` 验证返回字段。

**验收场景**：

1. **Given** `courier_status=是` 且 `if_register` 缺失，**When** 组装 Coze 返回前执行补偿，**Then** `if_register=是`。
2. **Given** `courier_status=是` 且 `if_register=否`，**When** 执行补偿，**Then** `if_register` 覆盖为“是”。
3. **Given** `courier_status=否` 或缺失，**When** 执行补偿，**Then** 不新增或改写 `if_register`。

### 用户故事 2 - 物流消息补偿“已填写”打标受限流保护（优先级：P1）

物流消息发送分支命中后，系统仍应补偿打“已填写”标签，但 FC 调用必须通过 `RateLimitUtil.limitRun`，避免并发修改标签过高。

**独立测试**：构造命中物流链接且 `QwAutoTag` 返回 tagId 的场景，验证会进入限流 helper，且 Redis key 为 `ai:ai:writeOverTagCounter`。

**验收场景**：

1. **Given** 物流消息命中且自动标签存在，**When** 补偿打标，**Then** FC 调用在限流 wrapper 内执行。
2. **Given** 非物流消息或自动标签缺失，**When** 执行补偿方法，**Then** 不进入限流 wrapper。
3. **Given** FC 调用异常，**When** 限流 wrapper 执行任务，**Then** 异常仍由 `invokeFc` 记录，主流程不阻断。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `courier_status`：来源 `AppTask#setTushu` 的物流接口返回；赋值后合并到 `jsonObject`，再合并 `otsInfo`；下游读取位置为 `DayEnum.createCozeJson`。
  - `if_register`：来源 `AppTask#setTagId` 的“已填写”标签识别或本次物流状态补偿；必须在 `DayEnum.createCozeJson` 前完成。
  - `addTagList/removeTagList/externalUserId/userId/unionId/companyId`：来源 `compensateWriteOverTagIfNeeded` 已有上下文和 `QwAutoTag` 查询；下游读取位置为 `invokeFc`。
  - 限流 Redis key：固定 `ai:ai:writeOverTagCounter`；赋值时机为调用 `RateLimitUtil.limitRun` 时。
- 下游读取字段清单：
  - `DayEnum.createCozeJson` 读取 `courier_status`、`if_register` 等返回字段。
  - `invokeFc` 读取标签列表、外部联系人、企微用户、unionId 和主体 source。
- 空对象 / 占位对象风险：无新增空 DTO；已有 `JSONObject` 在当前层现算现用。
- 调用顺序风险：`if_register` 补偿必须在 `DayEnum.createCozeJson` 前；打标限流必须包住 `invokeFc`，不能只包日志或查询。
- 旧逻辑保持：`setTagId`、`setTushu`、`QwAutoTag` 查询条件、FC 函数名选择、异常只记录不阻断发送保持不变。
- 需要用户确认的设计选择：无，用户已指定触发条件和限流工具。

## 边界情况

- `courier_status` 为空、缺失、为“否”或其他值：不补偿 `if_register`。
- `if_register` 已为“是”：重复写“是”保持幂等。
- `QwAutoTag` 未命中、tagId 为空、上下文缺失：不进入限流，不调用 FC。
- `RateLimitUtil.limitRun` 等待超时：沿用工具现有行为，最终执行任务。
- Redis 或 FC 异常：不改变现有异常处理边界。

## 需求

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下创建本 Spec Kit 目录。
- **FR-002**：`AppTask` MUST 在 `DayEnum.createCozeJson` 前，当 `courier_status=是` 时写入 `if_register=是`。
- **FR-003**：`courier_status` 非“是”时 MUST 不新增或改写 `if_register`。
- **FR-004**：`AppTask` MUST 保持原有“已填写”标签识别逻辑不变。
- **FR-005**：`AiServiceImpl.compensateWriteOverTagIfNeeded` 命中补偿打标时 MUST 通过 `RateLimitUtil.limitRun` 包装 `invokeFc`。
- **FR-006**：限流 Redis key MUST 为 `ai:ai:writeOverTagCounter`，不得复用消息发送 key。
- **FR-007**：系统 MUST 不改变 FC taskObj、函数名选择、自动标签查询条件或主流程异常边界。

## 成功标准

- **SC-001**：`courier_status=是` 的 AppTask 返回 100% 包含 `if_register=是`。
- **SC-002**：`courier_status` 非“是”的 AppTask 返回不因本次补偿新增注册态。
- **SC-003**：物流消息补偿打标 100% 经由 `RateLimitUtil.limitRun` 和独立 Redis key 执行。
- **SC-004**：非物流消息或自动标签缺失不会触发打标限流。
- **SC-005**：目标测试和编译命令通过，或记录明确的外部阻塞原因。

## 假设

- `courier_status=是` 是“已发货/已有物流”的唯一补偿触发条件。
- `AppTask` 只补偿 Coze 返回字段，不在该链路写企微标签。
- `userRedisTemplateJuziSend` 可复用于 `RateLimitUtil.limitRun` 的整数计数器操作。
- 工作区已有的 `bootstrap.yml` 和 `dependency-reduced-pom.xml` 修改不是本需求范围。

## 执行记录

### D001 - 文档与实现记录

- 已创建本 Spec Kit 文档。
- 已补充 `AppTask` 的 `courier_status=是 -> if_register=是` 返回字段兼容。
- 已补充 `AiServiceImpl.compensateWriteOverTagIfNeeded` 的打标 FC 限流。
- 已新增和更新目标单元测试，验证命令见 `tasks.md`。
