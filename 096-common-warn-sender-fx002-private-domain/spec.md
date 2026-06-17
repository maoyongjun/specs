# 功能规格：common_warn_sender 支持 FX_002 私域变量与“请勿打扰”打标

**功能目录**：`096-common-warn-sender-fx002-private-domain`  
**创建日期**：`2026-06-16`  
**状态**：Implemented  
**输入**：修改 `C:\workspace\ju-chat\coze_plugin\common_warn_sender`。入参示例：`{"appendJumpLink":false,"external_key":"private-domain:7644449532675866662:wmQcc1XAAA6t6wBanYmYTH7lBFlxkb5A:11311073569:default","sendTemplateList":["FX_002"],"templateVariable":{"unionId":"xxx","userName":"xxx"}}`。要求 `unionId` 和 `userName` 可正常填充，缺失时通过接口获取；遇到 `FX_002` 调用 `POST http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai/qwTag/markAsync` 打标签。标签按 `source + name='请勿打扰'` 查询 `drh_qw_tag` 获取 `tagId`。

## 背景

- 当前问题：`common_warn_sender` 现有 legacy `external_key` 按 4 段解析，不支持私域 5 段 key；模板变量里 `unionId/userName` 缺失时也没有完整补齐 `unionId` 的逻辑；`FX_002` 发送后需要自动打“请勿打扰”标签。
- 当前行为：`AppTask.handleRequest` 从 legacy key 解析 `externalUserId/empId/campDateId/qwUserId`，调用 Center 查询销售、营期和外部联系人姓名，渲染模板后发送飞书或企微消息。
- 目标行为：私域 key 能解析出 `externalUserId` 并通过 `/ai/getEmpExternalUserDO` 补齐 `unionId/name/empId/source`；入参 `templateVariable.unionId/userName` 优先；`FX_002` 发送流程额外 best-effort 调用 `markAsync` 打“请勿打扰”标签。
- 非目标：不新增数据库表，不修改 `markAsync` 既有异步任务语义，不改变非 `FX_002` 模板逻辑，不硬编码任何 `tagId`。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 私域 FX_002 可渲染模板变量（优先级：P1）

当调用方传入私域 `external_key` 和 `templateVariable.unionId/userName` 时，`common_warn_sender` 能按入参值渲染 `FX_002` 模板，不被接口查询结果覆盖。

**独立测试**：构造私域 key 和 `templateVariable`，mock 策略模板读取 `{unionId}`、`{userName}`，断言渲染结果使用入参值。

**验收场景**：

1. **Given** `templateVariable.unionId="xxx"` 且 `templateVariable.userName="xxx"`，**When** 处理 `FX_002`，**Then** 模板变量中 `unionId/userName` 均为入参值。
2. **Given** 私域 key 第 3 段为 `externalUserId`，**When** 解析上下文，**Then** 不按 legacy 4 段 key 解析失败。

### 用户故事 2 - 缺失变量时通过接口补齐（优先级：P1）

当 `templateVariable` 缺失 `unionId` 或 `userName` 时，系统通过 `/sae-gateway/kkhc-idc-ai/ai/getEmpExternalUserDO?externalUserid=...` 查询外部联系人关系，补齐 `unionId` 和 `name`。

**独立测试**：构造缺少变量的入参，mock `getEmpExternalUserDO` 返回 `unionId/name/empId/source`，断言模板变量和打标上下文都使用接口返回值。

**验收场景**：

1. **Given** `templateVariable` 没有 `unionId`，**When** 接口返回 `unionId`，**Then** 模板变量包含该 `unionId`。
2. **Given** `templateVariable` 没有 `userName`，**When** 接口返回 `name`，**Then** `userName/stu_name` 使用该 `name`。
3. **Given** 接口异常或返回空，**When** 处理预警，**Then** 保持已有发送链路并记录补齐失败日志。

### 用户故事 3 - FX_002 后打“请勿打扰”标签（优先级：P1）

当 `sendTemplateList` 包含 `FX_002` 时，系统按主体 `source` 和标签名“请勿打扰”查询 `drh_qw_tag.tagId`，再提交 `markAsync` 异步打标任务。

**独立测试**：mock tag 查询接口返回 `tagId`，拦截 `markAsync` HTTP 请求，断言请求体包含 `external_user_id/user_id/union_id/source/add_tag_list` 且不包含空 `remove_tag_list`。

**验收场景**：

1. **Given** 已补齐 `externalUserId/userId/unionId/source/tagId`，**When** `sendTemplateList` 包含 `FX_002`，**Then** 调用 `POST /qwTag/markAsync`。
2. **Given** 标签查询未命中或 `tagId` 为空，**When** 处理 `FX_002`，**Then** 不调用 `markAsync`，只记录跳过原因。
3. **Given** `markAsync` 返回错误或 HTTP 异常，**When** 处理 `FX_002`，**Then** 原预警发送结果不被阻断。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `external_key`：来源入参；进入 `handleRequest` 后立即校验；legacy 取前 4 段，私域取第 3 段为 `externalUserId`。
  - `externalUserId`：legacy 第 1 段或私域第 3 段；调用 Center 查询和 `markAsync` 前已确定。
  - `unionId`：优先 `templateVariable.unionId`；缺失时取 `getEmpExternalUserDO.unionId`；调用 `markAsync` 前必须非空。
  - `userName`：优先 `templateVariable.userName`；缺失时取 `getEmpExternalUserDO.name`，再兜底旧 `safeGetUserName`；渲染前已确定。
  - `empId`：legacy 第 2 段或 `getEmpExternalUserDO.empId`；调用 `getEmpInfoByEmpId` 前已确定。
  - `source`：优先 `getEmpExternalUserDO.source`，缺失时使用销售 `company`；查询“请勿打扰”标签前已确定。
  - `user_id`：来自销售 `KkEmpDto.qyvxUserId`；调用 `markAsync` 前必须非空。
  - `tagId`：来源新增 tag 查询接口，条件 `source + name='请勿打扰' + is_del=0`；调用 `markAsync` 前必须非空。
- 下游读取字段清单：
  - 模板渲染读取 `unionId/userName/stu_name/campName/camp_name/salerName/externalUserId/empId/campDateId`。
  - `QwTagController#markAsync` 读取 `external_user_id`、`user_id`、`source`、`union_id`、`add_tag_list`、`remove_tag_list`。
  - `QwExternalTagTaskServiceImpl#submitMarkTask` 会把空 `union_id` 降级为 `unKnown`；本需求必须在上游阻止空 `unionId` 的 FX_002 打标提交。
- 空对象 / 占位对象风险：
  - 不允许构造缺少 `external_user_id/user_id/source/union_id/add_tag_list` 的 `markAsync` 请求。
  - 不允许 `tagId` 为空时用空字符串提交。
  - `templateVariable` 可为空，但当前层必须构造可渲染的变量对象。
- 调用顺序风险：
  - 必须先解析 key，再补齐用户关系，再渲染模板并发送预警；`FX_002` 打标在每次处理后作为附加动作执行。
  - tag 查询必须发生在 `markAsync` 前。
- 旧逻辑保持：
  - legacy `external_key` 4 段解析、策略解析、飞书/企微发送、Redis 频控、升级逻辑保持。
  - `appendJumpLink=false` 继续禁止追加聊天跳转链接。
  - 非 `FX_002` 模板不触发“请勿打扰”打标。
- 需要用户确认的设计选择：
  - 已确认：标签名使用“请勿打扰”，不使用旧标签名。
  - 已确认：tagId 按 `source + name` 查询 `drh_qw_tag`，不复用 `listByTypes`。

## 边界情况

- 私域 key 不是 5 段或任一关键段为空：返回参数错误或跳过处理，记录日志。
- `getEmpExternalUserDO` 无记录：模板变量只能使用入参和旧兜底；`FX_002` 打标跳过。
- `unionId` 缺失：不调用 `markAsync`，避免下游写入 `unKnown`。
- `qyvxUserId` 缺失：不调用 `markAsync`。
- `source` 缺失：不查询 tag，不调用 `markAsync`。
- `drh_qw_tag` 查询多条：取 `is_del=0` 且 `limit 1` 的一条，仍按主体隔离。
- `markAsync` 幂等命中：记录返回 `taskId/status`，不视为失败。
- debug 模式：不实际提交“请勿打扰”打标。

## 需求 *(必填)*

### 功能需求

- **FR-001**：`common_warn_sender` MUST 支持私域 `external_key=private-domain:agentId:externalUserId:userId:env`，并取第 3 段为 `externalUserId`。
- **FR-002**：模板变量 `unionId/userName` MUST 优先使用 `templateVariable` 入参值。
- **FR-003**：当 `unionId/userName` 缺失时，系统 MUST 调用 `/ai/getEmpExternalUserDO` 补齐 `unionId/name`。
- **FR-004**：`sendTemplateList` 包含 `FX_002` 时，系统 MUST 按 `source + name='请勿打扰' + is_del=0` 查询 `drh_qw_tag.tagId`。
- **FR-005**：`FX_002` 打标 MUST 调用 `POST /qwTag/markAsync`，请求体包含 `external_user_id/user_id/union_id/source/add_tag_list`。
- **FR-006**：`FX_002` 发送消息时飞书接收人 MUST 固定为 `ed27a7bb`，不得使用销售 `fBookId`；其他策略保持原逻辑。
- **FR-007**：`remove_tag_list` 为空时 MUST 不传。
- **FR-008**：`tagId/unionId/user_id/source` 任一缺失时 MUST 跳过打标并记录原因，不得提交占位请求。
- **FR-009**：`FX_002` 打标失败 MUST 不阻断原预警发送。
- **FR-010**：系统 MUST NOT 硬编码 `tagId` 或跨主体 fallback。
- **FR-011**：单元测试 MUST 断言模板变量优先级、私域 key 解析、FX_002 飞书接收人、tag 查询条件和 `markAsync` 请求体。

## 成功标准 *(必填)*

- **SC-001**：示例私域入参能正常渲染 `unionId/userName`。
- **SC-002**：缺少 `unionId/userName` 时可通过接口补齐并参与模板渲染。
- **SC-003**：`FX_002` 能提交“请勿打扰”异步打标任务，请求体字段完整。
- **SC-004**：`FX_002` 飞书消息固定发给 `ed27a7bb`。
- **SC-005**：非 `FX_002`、tag 缺失或用户上下文不完整时不产生打标副作用。
- **SC-006**：legacy 预警发送、跳转链接开关、重复发送限制不回归。

## 假设

- `drh_qw_tag` 中存在各主体的“请勿打扰”有效标签。
- `sys_domain` 可访问 `kkhc-idc-ai` 内部接口；用户指定的生产网关为 `http://kapi.likeduoduiyi.cn/sae-gateway/kkhc-idc-ai`。
- `markAsync` 为异步提交任务，最终落地状态以现有任务表和任务日志为准。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成参数来源、下游读取字段、空对象风险、调用顺序和旧逻辑保持分析。
- 已同步用户纠正：标签名为“请勿打扰”。
- 已同步用户补充：`FX_002` 发送消息时飞书 ID 固定为 `ed27a7bb`。

### D002 - 实现记录

- 实现内容：`kkhc-idc-ai` 新增按 `source + name + is_del=0` 查询 `drh_qw_tag` 的内部接口；`common_warn_sender` 新增私域 key 解析、`unionId/userName` 入参优先和接口补齐、`FX_002` 固定飞书 ID `ed27a7bb`、`FX_002` 后 best-effort 提交“请勿打扰”异步打标。
- 影响范围：`common_warn_sender`、`kkhc-idc-ai/ai`、`kkhc-idc-ai/ai-common`；不改变非 `FX_002` 发送逻辑，不硬编码 `tagId`，不新增必填入参。
- 测试命令：`mvn -pl common_warn_sender "-DskipTests=false" "-Dmaven.test.skip=false" "-Dtest=AppTaskTest" test`；`mvn -pl ai -am "-Dtest=QwTagQueryServiceImplTest" test`。
- 测试结果：两个命令均 `BUILD SUCCESS`；`common_warn_sender` 8 tests passed，`kkhc-idc-ai ai` 2 tests passed。
- 自检结论：关键字段在调用前已赋值或缺失时跳过打标；`markAsync` 不传空 `remove_tag_list`；debug 模式不产生真实打标；打标失败不阻断预警发送。

### D003 - 用户画像私域返回结构变更

- 变更内容：`POST /ai/userPortrait` 的 `teacherInfo` 和 `courseData` 从单对象改为 list；`logisticsData` 保持 list；`userProfile.payStatus` 保持对象字段。
- 字段来源：体验课 `teacherInfo` 通过 `drh_applet_user -> drh_kk_emp -> drh_live_camp_date -> drh_speaker -> drh_business_line` 返回 `speakerName/headTeacherName/skuName`；正价课 `courseData` 通过 `drh_handover_plus -> drh_live_camp -> drh_live_camp_group -> drh_business_line` 返回 `campName/classTime/courseLink/skuName`，主讲取该营期 `drh_live -> drh_speaker` 并去重后用顿号拼接。
- 分组口径：`courseData` 按营期返回；同一 `campId + category/skuName` 重复交接记录只返回一条，保持最近优先；`classTime` 使用班级/营期开课时间 `drh_live_camp_group.start_class_time`，不是直播课时间。
- 兼容性决策：不保留旧的 `teacherInfo/courseData` 单对象字段；私域插件 `external-info-select` 透传新数组结构，并补充单测锁定 `skuName` 和 `hasDeliveredOrder` 字段名。
- 测试结果：`mvn -pl ai -am "-Dtest=AiUserPortraitServiceImplTest" test` 通过，22 tests passed；`mvn -pl external-info-select "-Dmaven.test.skip=false" "-DskipTests=false" "-Dtest=AppTaskPrivateDomainTest" test` 通过，8 tests passed。
