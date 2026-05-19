# 任务清单：发送物流时补偿“已填写”标签

**输入**：来自 `specs/021-send-juzi-logistics-filled-tag-compensation/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：后续实现阶段需要验证物流消息分支、`QwAutoTag` 动态查询、`invokeFc` 参数映射、中文日志和失败继续发送行为。当前已完成实现并通过编译验证。  

## Phase 1：规格与范围

- [x] T001 创建 `specs/021-send-juzi-logistics-filled-tag-compensation` 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确当前阶段只写 Spec Kit 文档，不修改业务代码
- [x] T003 明确物流消息分支是唯一补偿触发点
- [x] T004 明确 `Write_Over` 标签必须通过 `QwAutoTag` 动态查询
- [x] T005 明确 `invokeFc` 的参数来源：`externalUserId`、`userId`、`unionId`、`companyId`

## Phase 2：后续实现

- [x] T006 在 `AiServiceImpl.sendJuzi` 中识别物流消息分支并挂接补偿逻辑
- [x] T007 通过 `QwAutoTagService.getOne(...)` 查询 `MqQwTagEnum.Write_Over` 对应 `tagId`
- [x] T008 构造 `addTagList` / `removeTagList` 并调用 `invokeFc(addTagList, removeTagList, externalUserId, userId, unionId, companyId)`
- [x] T009 将 `userId` 固定取自 `empDto.getQyvxUserId()`，`companyId` 固定取自 `empDto.getCompany()`
- [x] T010 增加中文日志，覆盖开始、命中、查询结果、成功、失败、跳过原因
- [x] T011 保证 `QwAutoTag` 未命中、`tagId` 为空或 `invokeFc` 异常时不阻断消息发送
- [x] T012 保证非物流消息不触发补偿逻辑
- [x] T013 依据 Nacos 的 `mq.delay.topic` 选择补偿 FC 函数名，`test_delay` 走测试函数，`delay` 走正式函数

## Phase 3：验证

- [x] T014 走读物流消息、非物流消息、缺配置、调用失败四类路径
- [x] T015 编译 `kkhc/kkhc-idc` 的 `ai` 模块并记录结果
- [x] T016 复核日志文案是否包含中文关键字和足够的上下文信息

## 执行记录

### D001 - 文档记录

- 已按用户要求在 `C:\workspace\ju-chat\specs` 下创建 `021-send-juzi-logistics-filled-tag-compensation` 的 Spec Kit 文档。
- 已记录物流消息分支补偿 `MqQwTagEnum.Write_Over` / “已填写” 标签的需求。
- 已记录 `QwAutoTag` 动态查询条件为 `source + type`，避免硬编码 `tagId`。
- 已记录 `invokeFc` 参数来源与中文日志要求。
- 已记录 `mq.delay.topic` 决定测试/正式 FC 函数名，`test_delay` 走测试函数，`delay` 走正式函数。
- 当前阶段未修改业务代码。

### D002 - 实现记录

- `AiServiceImpl.sendJuzi` 已在物流消息分支内补偿“已填写”标签。
- 已增加 `QwAutoTagService` 动态查询 `Write_Over` 标签的逻辑。
- 已增加中文日志，覆盖补偿开始、命中、查询、调用成功与失败。
- 已增加 `mq.delay.topic` 读取与 FC 函数名分流逻辑，`test_delay` 走测试函数，`delay` 走正式函数。
- 已通过 `mvn -f kkhc/kkhc-idc/pom.xml -pl ai -am -DskipTests compile` 编译验证。
