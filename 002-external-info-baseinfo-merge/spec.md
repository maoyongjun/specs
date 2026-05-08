# 功能规格：External Info BaseInfo 合并查询

**功能分支**: `002-external-info-baseinfo-merge`  
**创建日期**: 2026-05-06  
**状态**: Draft  
**输入**: 用户描述："在 `C:\workspace\ju-chat\data-RC\juzi-service` 增加接口，并发调用 `ai-service/external-select` 与 `ai-service/prod-external-profile`，测试环境分别为 `external-select-test` 与 `external-profile`。两个函数使用同一个 `external_key` 入参，返回 JSON 后合并给调用方。本阶段只在 `C:\workspace\ju-chat\specs` 建立 spec-kit 文档与任务清单，不编码。"

## 用户场景与测试 *(必填)*

### 用户故事 1 - 调用方一次获取合并后的用户上下文（优先级：P1）

调用方只传一个 `external_key`，系统通过 `POST /api/external-info/baseInfo` 并发查询用户基础上下文和画像补充信息，并返回一个合并后的 JSON 对象。调用方不需要分别了解 `external-select` 和 `prod-external-profile` 两个函数的调用细节。

**优先级原因**：下游需要同时使用课节、物流、报名、画像和沟通偏好等字段。分两次调用会增加调用方复杂度，也容易出现两个上下文版本不一致。

**独立测试**：构造包含合法 `external_key` 的请求，模拟两个 FC 都返回 JSON，验证接口返回 `BaseResponse.status=200`、`message=OK`，且 `data` 包含两个函数合并后的字段。

**验收场景**：

1. **Given** 请求体为 `{"external_key":"wmfL1ESgAA9nj5TQyD9aKF1m5DF4z50w:4973:3809:MuPengLin001"}`，**When** 调用 `POST /api/external-info/baseInfo`，**Then** 系统使用相同 `external_key` 并发调用两个 FC。
2. **Given** 两个 FC 均返回 JSON 对象，**When** 系统合并结果，**Then** 接口返回一个合并后的 JSON 对象，不再包裹 `select` 或 `profile` 子对象。
3. **Given** `external-select` 与 `profile` 返回同名字段，**When** 合并结果，**Then** 同名字段以 `external-select` 的值为准。

---

### 用户故事 2 - 按环境切换 FC 函数名（优先级：P1）

系统根据现有 `mq.juzi_tag` 判断测试环境和生产环境。测试环境调用测试函数名，非测试环境调用生产函数名，接口入参和返回合并规则保持一致。

**优先级原因**：现有系统已有 `mq.juzi_tag=test` 的环境判断方式，沿用该规则可以减少额外配置和误调用生产函数的风险。

**独立测试**：分别设置 `mq.juzi_tag=test` 和非 `test` 值，验证构造出的 `FcInvokeInput.serviceName`、`functionName` 与预期一致。

**验收场景**：

1. **Given** `mq.juzi_tag` 等于 `test`，**When** 接口执行查询，**Then** 调用 `ai-service/external-select-test` 和 `ai-service/external-profile`。
2. **Given** `mq.juzi_tag` 不等于 `test`，**When** 接口执行查询，**Then** 调用 `ai-service/external-select` 和 `ai-service/prod-external-profile`。
3. **Given** 环境切换只影响函数名，**When** 调用不同环境函数，**Then** 请求体仍统一为 `{"external_key":"..."}`。

---

### 用户故事 3 - 单个 FC 失败时仍返回可用数据（优先级：P1）

当两个并发调用中只有一个失败时，接口应返回成功函数的数据，并在返回体中标记失败函数信息，避免调用方因为一个补充画像函数异常而完全拿不到用户上下文。

**优先级原因**：`external-select` 与 `profile` 的数据价值不同但都可单独使用。单边失败时完全失败会降低接口可用性。

**独立测试**：分别模拟 `external-select` 失败和 `profile` 失败，验证接口返回成功函数字段，并在 `data._fc_errors` 中记录失败来源、函数名和错误信息。

**验收场景**：

1. **Given** `profile` 成功且 `external-select` 失败，**When** 接口返回，**Then** `data` 包含 `profile` 字段，并包含 `_fc_errors`。
2. **Given** `external-select` 成功且 `profile` 失败，**When** 接口返回，**Then** `data` 包含 `external-select` 字段，并包含 `_fc_errors`。
3. **Given** 两个 FC 均失败，**When** 接口返回，**Then** 使用 `BaseResponse.logicError(...)` 返回业务错误。

## 边界情况

- 请求体为空、缺少 `external_key` 或 `external_key` 为空字符串。
- `external_key` 格式不合法但 FC 可接收时，接口不在 juzi-service 内拆解或改写，仍原样传给 FC。
- `mq.juzi_tag` 为 `test`、空值或其他非 `test` 值。
- 任一 FC 超时、抛异常、返回空字符串、返回非 JSON 或返回 JSON 数组。
- 两个 FC 都失败或都返回空对象。
- 两个 FC 返回同名字段，例如 `base`、`rejection_reason`、`refund`。
- `courierList` 为空、缺失、不是数组，或数组元素缺少 `order`、`url`。
- 部分失败时 `_fc_errors` 与 FC 原始字段发生同名冲突。
- FC 返回字段类型与历史预期不一致，接口仍按 JSON 原值透传，不做业务字段转换。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 新增公开 API `POST /api/external-info/baseInfo`。
- **FR-002**：请求体 MUST 使用字段 `external_key`，值为传给两个 FC 的公共 key。
- **FR-003**：当请求体为空、缺少 `external_key` 或 `external_key` 为空白时，系统 MUST 返回 `BaseResponse.logicError(...)`，不得调用 FC。
- **FR-004**：系统 MUST 使用同一个请求体 `{"external_key":"..."}` 调用两个 FC。
- **FR-005**：系统 MUST 并发发起两个同步 FC 调用，并等待两个调用完成后汇总结果。
- **FR-006**：当 `mq.juzi_tag == "test"` 时，系统 MUST 调用 `ai-service/external-select-test` 与 `ai-service/external-profile`。
- **FR-007**：当 `mq.juzi_tag != "test"` 时，系统 MUST 调用 `ai-service/external-select` 与 `ai-service/prod-external-profile`。
- **FR-008**：FC 调用 SHOULD 沿用现有 `FcInvokeInput` 与 `FcInvokeUtils.doSyncTaskReturnJSONObj` 调用方式。
- **FR-009**：系统 MUST 将 `profile` 结果先放入合并对象，再将 `external-select` 结果放入合并对象。
- **FR-010**：字段冲突时，系统 MUST 以 `external-select` 返回值为准。
- **FR-011**：系统 MUST 保留 `external-select` 返回的 `courierList` 数组原值；数组元素按来源保留 `order`、`url` 等字段。
- **FR-012**：两个 FC 都成功时，接口 MUST 返回 `BaseResponse.status=200`、`message=OK`、`data` 为合并 JSON。
- **FR-013**：只有一个 FC 成功时，接口 MUST 返回成功函数数据，`message` 设置为 `PARTIAL_OK`，并在 `data._fc_errors` 中记录失败信息。
- **FR-014**：`_fc_errors` MUST 至少包含失败来源、`serviceName`、`functionName` 和错误信息。
- **FR-015**：两个 FC 都失败时，系统 MUST 返回 `BaseResponse.logicError(...)`。
- **FR-016**：系统 MUST 在日志中记录每个 FC 的调用目标、成功或失败状态，避免记录完整敏感返回体。
- **FR-017**：系统 MUST 不在 juzi-service 内重新解释、转换、补默认值或过滤 FC 业务字段。
- **FR-018**：本阶段 MUST 只维护规格文档与 `tasks.md` 任务清单，不修改 `data-RC/juzi-service` 业务代码。

### 返回字段

`external-select` 返回 JSON 字段包括但不限于：

`address`, `advanced_course_url`, `age`, `area`, `base`, `buying_intention`, `city`, `class_day`, `class_info`, `class_session_d1`, `class_session_d2`, `class_session_d3`, `class_session_d4`, `class_session_d5`, `class_session_d6`, `courierList`, `courier_link`, `courier_number`, `courier_status`, `current_time`, `d1_homework`, `d1_task_class_session`, `d2_homework`, `d2_task_class_session`, `d3_homework`, `d3_learn_session`, `d3_task_class_session`, `d4_homework`, `d4_task_class_session`, `d5_homework`, `d5_task_class_session`, `d6_homework`, `d6_task_class_session`, `deposit`, `gender`, `if_register`, `if_tushu`, `ignore_collect_tushu_msg`, `join_chatroom`, `name`, `name_tushu`, `original_message`, `payment_amount`, `pc_link_d0`, `pc_link_d1`, `pc_link_d2`, `pc_link_d3`, `pc_link_d4`, `pc_link_d5`, `pc_link_d6`, `pendpay`, `phone_number`, `promise_d1`, `promise_d4`, `province`, `refund`, `rejection_reason`, `replay`, `sensitive_word`, `sign_up`, `song`, `task_class_session`, `today`, `transfer_amount`, `treasure_book_d1`, `treasure_book_d2`, `treasure_book_d3`, `treasure_book_d4`, `treasure_book_d5`, `week_num`, `is_registered_app`, `brand`, `treasure_book_d0`, `day`, `class_session`, `today_homework`, `yesterday_homework`, `sku`。

`courierList` 为数组对象，元素字段包括但不限于 `order`、`url`。

`profile` 返回 JSON 字段包括但不限于：

`base`, `interest_preference`, `singing_painpoint`, `rejection_reason`, `refund`, `vocal_basic_comm_frequency`, `has_piano`。

## 成功标准 *(必填)*

### 可衡量结果

- **SC-001**：合法请求调用一次 `POST /api/external-info/baseInfo`，系统并发发起两个 FC 查询。
- **SC-002**：`mq.juzi_tag=test` 时，函数名 100% 为 `external-select-test` 和 `external-profile`。
- **SC-003**：非测试环境函数名 100% 为 `external-select` 和 `prod-external-profile`。
- **SC-004**：两个 FC 都成功时，接口返回一个合并 JSON，且同名字段保留 `external-select` 值。
- **SC-005**：单个 FC 失败时，接口仍返回成功函数数据，并包含 `_fc_errors`。
- **SC-006**：两个 FC 均失败或 `external_key` 为空时，接口返回业务错误。
- **SC-007**：本规格阶段生成 `tasks.md` 后仍没有修改业务代码。

## 假设

- `C:\workspace\ju-chat\data-RC\juzi-service` 当前无 `/api/external-info/baseInfo` 路径冲突。
- 新接口使用现有 `BaseResponse<T>` 响应结构。
- 新接口为公开 API，不新增 admin 页面。
- 环境选择只依赖 `mq.juzi_tag` 是否等于 `test`。
- FC 返回值按 JSON 对象处理；字段语义由两个 FC 保持，juzi-service 只负责调用、合并和失败标记。
- 本规格与 `tasks.md` 只描述后续实现目标；本次不改业务代码。
