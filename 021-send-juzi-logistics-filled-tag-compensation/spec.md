# 功能规格：发送物流时补偿“已填写”标签

**功能目录**: `021-send-juzi-logistics-filled-tag-compensation`  
**创建日期**: 2026-05-19  
**状态**: Implemented  
**输入**: 用户要求在 `AiController.sendJuziMsg` 发送物流信息时，补偿增加标签“已填写”，以防止漏打标签；`QwAutoTag` 的 `tagId` 通过 `qwAutoTagService.getOne(new LambdaQueryWrapper<QwAutoTag>().eq(QwAutoTag::getSource, appInfo.getSource()).eq(QwAutoTag::getType, qwTagEnum.getCode()))` 动态获取；调用的方法固定为 `invokeFc(addTagList, removeTagList, externalUserId, userId, unionId, companyId)`，其中 `companyId = empDto.getCompany()`，`userId = empDto.getQyvxUserId()`；同时增加中文日志，方便线上查看是否起作用。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 发送物流消息时补偿“已填写”标签（优先级：P1）

当 `sendJuziMsg` 进入物流消息分支时，系统需要在继续发送链路内补偿写入“已填写”标签，避免物流消息发送后漏打标签，影响后续营期或跟进逻辑。

**独立测试**：构造一条命中物流消息分支的发送请求，模拟 `QwAutoTag` 可查询到 `Write_Over` 标签，验证会调用 `invokeFc(addTagList, removeTagList, externalUserId, userId, unionId, companyId)`，并且 `addTagList` 包含该标签 ID。

**验收场景**：

1. **Given** 发送内容命中现有物流消息处理分支，**When** 执行 `sendJuziMsg`，**Then** 系统应先完成“已填写”标签补偿，再继续原有物流消息发送流程。
2. **Given** `QwAutoTag` 能查到 `MqQwTagEnum.Write_Over` 对应的 `tagId`，**When** 触发物流消息补偿，**Then** `addTagList` 只包含该 `tagId`，`removeTagList` 保持为空。
3. **Given** `EmpExternalUserDO`、`KkEmpDo` 和 `MsgSendInput` 都已解析成功，**When** 触发补偿，**Then** `externalUserId` 取 `empUser.getExternalUserid()`，`userId` 取 `empDto.getQyvxUserId()`，`unionId` 复用当前会话，`companyId` 取 `empDto.getCompany()`。

### 用户故事 2 - 非物流消息不触发补偿（优先级：P1）

普通消息、非物流文案或未命中物流链接识别逻辑的发送请求，不应触发“已填写”标签补偿，避免对非物流业务产生额外副作用。

**独立测试**：构造一条不包含物流链接的发送请求，验证不会查询 `Write_Over` 标签，也不会调用 `invokeFc` 做补偿。

**验收场景**：

1. **Given** 发送内容不属于物流消息，**When** 执行 `sendJuziMsg`，**Then** 不应进入标签补偿逻辑。
2. **Given** 发送内容已经是普通文本消息，**When** 执行 `sendJuziMsg`，**Then** 现有消息发送行为保持不变。
3. **Given** 发送内容中没有命中物流消息识别条件，**When** 查看日志，**Then** 不应出现“已填写”补偿相关的开始或成功日志。

### 用户故事 3 - 标签配置缺失或补偿失败时只记录日志，不阻断发送（优先级：P1）

补偿打标是附加能力，不应因为 `QwAutoTag` 缺失、`tagId` 为空或 `invokeFc` 调用异常而影响物流消息发送主流程。

**独立测试**：分别模拟 `QwAutoTag` 未命中、`tagId` 为空和 `invokeFc` 抛异常三种情况，验证消息发送结果不受影响，同时日志可明确看到失败原因。

**验收场景**：

1. **Given** `QwAutoTag` 中找不到 `Write_Over` 记录，**When** 执行物流消息发送，**Then** 系统记录中文告警并跳过补偿，不阻断发送。
2. **Given** `invokeFc` 调用抛异常，**When** 执行物流消息发送，**Then** 系统记录中文错误日志并继续原发送流程。
3. **Given** 补偿逻辑执行成功，**When** 查看线上日志，**Then** 能看到中文的开始、命中、查询结果和成功结果日志，足以判断补偿是否生效。

## 边界情况

- 发送内容不属于物流消息，必须不触发补偿。
- `QwAutoTag` 未命中 `Write_Over`，或查到的 `tagId` 为空、空字符串。
- `empUser`、`empDto` 或 `appInfo` 为空时，不能因为新增补偿逻辑引入新的异常类型或新的失败路径。
- `invokeFc` 抛出异常、返回空值或调用被限流时，必须只记录日志，不影响消息发送主流程。
- 物流链接中已存在 `type` 参数时，现有消息处理逻辑保持原样，标签补偿只关注“是否进入物流分支”。
- 同一条物流消息重复发送时，是否会重复触发补偿由后续实现的幂等策略和下游 FC 行为决定，本规格不新增重复判断。

## 需求 *(必填)*

### 功能需求

- **FR-001**：当前阶段 MUST 只编写 Spec Kit 文档，不修改业务代码。
- **FR-002**：`AiController.sendJuziMsg` / `AiServiceImpl.sendJuzi` MUST 保持现有对外入参和返回结构不变。
- **FR-003**：系统 MUST 仅在物流消息分支命中时触发“已填写”标签补偿。
- **FR-004**：物流消息补偿 MUST 通过 `MqQwTagEnum.Write_Over` 的 code 动态查询 `QwAutoTag`，不得硬编码 `tagId`。
- **FR-005**：`QwAutoTag` 查询 MUST 使用 `source = appInfo.getSource()` 与 `type = qwTagEnum.getCode()` 两个条件。
- **FR-006**：补偿时 `addTagList` MUST 仅包含查询到的 `Write_Over` 标签 ID，`removeTagList` MUST 保持为空。
- **FR-007**：补偿调用 MUST 使用 `invokeFc(addTagList, removeTagList, externalUserId, userId, unionId, companyId)`，其中 `userId = empDto.getQyvxUserId()`，`companyId = empDto.getCompany()`。
- **FR-008**：补偿逻辑 MUST 复用当前 `EmpExternalUserDO` / `KkEmpDo` / `MsgSendInput` 解析结果，不新增额外公共 DTO。
- **FR-009**：补偿逻辑 MUST 为 best-effort，`QwAutoTag` 未命中、`tagId` 为空、`invokeFc` 异常或限流时都不得阻断物流消息发送。
- **FR-010**：补偿逻辑 MUST 增加中文日志，至少覆盖开始、命中物流分支、tag 查询结果、补偿成功、补偿失败和跳过原因。
- **FR-011**：非物流消息 MUST 不触发 `Write_Over` 补偿，也不得查询 `QwAutoTag`。
- **FR-012**：补偿 FC 的函数名 MUST 通过 Nacos 中的 `mq.delay.topic` 判定，`test_delay` 使用 `cpv-qw-tag-util-test`，其他值使用 `sync-external-tag`。
- **FR-013**：本需求 MUST 不新增接口、数据库表、配置项或消息协议字段。

## 成功标准 *(必填)*

### 可衡量结果

- **SC-001**：物流消息分支命中时，100% 会尝试查询 `Write_Over` 对应的自动标签配置。
- **SC-002**：物流消息分支命中且标签配置存在时，100% 会把 `Write_Over` 标签 ID 放入 `addTagList` 并调用补偿 FC。
- **SC-003**：非物流消息 100% 不触发 `Write_Over` 补偿逻辑。
- **SC-004**：`QwAutoTag` 未命中或 `invokeFc` 异常时，100% 只记录日志，不阻断物流消息发送。
- **SC-005**：日志中 100% 能看到中文的补偿开始、查询结果、成功或失败、跳过原因，足以在线上判断功能是否生效。
- **SC-006**：`userId`、`companyId`、`externalUserId`、`unionId` 的来源在规格中完全固定，不再需要实现者二次猜测。

## 假设

- 物流消息判定沿用现有 `sendJuzi` 中的物流链接处理分支，不新增另一套判定规则。
- `MqQwTagEnum.Write_Over` 对应的自动标签配置应由现有 `QwAutoTag` 数据提供；如果配置缺失，补偿允许跳过。
- `invokeFc` 的现有签名保持不变，最后一个参数继续承载当前实现所需的公司/主体标识。
- `invokeFc` 的函数名通过 `mq.delay.topic` 区分，`test_delay` 使用 `cpv-qw-tag-util-test`，默认 `delay` 使用 `sync-external-tag`。
- 补偿属于附加副作用，优先级低于消息发送主流程。
- 本阶段已完成 Spec Kit 文档与业务代码实现。

## 执行记录

### D001 - 实现记录

- `AiServiceImpl.sendJuzi` 在物流消息分支中补偿 `MqQwTagEnum.Write_Over` 标签。
- `QwAutoTag` 按 `source = appInfo.getSource()` 与 `type = MqQwTagEnum.Write_Over.getCode()` 动态查询 `tagId`。
- `invokeFc(addTagList, removeTagList, externalUserId, userId, unionId, companyId)` 已落地，`userId` 取 `empDto.getQyvxUserId()`，`companyId` 取 `empDto.getCompany()`。
- `invokeFc` 的函数名已改为读取 `mq.delay.topic`，其中 `test_delay` 走 `cpv-qw-tag-util-test`，`delay` 走 `sync-external-tag`。
- 补偿失败、配置缺失或限流时只记录中文日志，不阻断物流消息发送。
- 物流链接 `type` 参数补充日志已改为中文输出。
