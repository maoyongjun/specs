# 功能规格：图书物流手机号兜底与已填写标签识别

**功能目录**: `011-tushu-phone-fallback-filled-tag`  
**创建日期**: 2026-05-11  
**状态**: Ready for Implementation  
**输入**: 用户要求 `AppTask#setTushu` 在 `applet_user_id` 为空时通过手机号查询图书物流；图书记录接口支持非必填 `phone`；`AiServiceImpl#selectUserCampDateIdInfo` 在标签营期补偿分支识别同一 `userid` 下的“已填写”标签并设置 `if_tushu=是`；当 OTS 手机号为空时通过 `external_user_id` 调用补偿接口查询手机号。

## 用户场景与测试 *(必填)*

### 用户故事 1 - AppTask 使用手机号兜底查询物流（优先级：P1）

当 OTS 基础信息中存在 `phone_number`，但 AI 用户信息里的 `applet_user_id` 为空时，系统不能直接跳过图书物流查询，应使用手机号继续查询物流记录。

**独立测试**：构造 `if_tushu=是`、`applet_user_id=null`、`otsInfo.phone_number=15833215982` 的请求，验证会请求图书查询接口并携带 `phone=15833215982`。

**验收场景**：

1. **Given** `applet_user_id` 为空且 `phone_number` 有值，**When** 调用 `setTushu`，**Then** 打印 `未查询到用户:applet_user_id={}将通过phone={}查询` 并继续查询。
2. **Given** `applet_user_id` 和 `phone_number` 都为空，**When** 调用 `setTushu`，**Then** 不查询外部接口并保持默认物流状态。
3. **Given** `applet_user_id` 有值，**When** 调用 `setTushu`，**Then** 原有按 `appletUserId` 查询行为保持可用。

### 用户故事 2 - 图书查询接口支持 phone 参数（优先级：P1）

调用方可能只有手机号，没有小程序用户 ID。接口需要允许 `appletUserId` 和 `phone` 均非必填，但至少一个有值时可以查询物流记录。

**独立测试**：分别请求只传 `appletUserId`、只传 `phone`、两者都传、两者都不传，验证查询结果和空结果处理符合预期。

**验收场景**：

1. **Given** 只传 `appletUserId`，**When** 调用接口，**Then** 系统通过用户 ID 反查手机号后查询物流。
2. **Given** 只传 `phone`，**When** 调用接口，**Then** 系统直接按手机号查询物流。
3. **Given** 两者都传，**When** 调用接口，**Then** 优先使用 `appletUserId` 对应用户手机号，查不到时回退到传入 `phone`。
4. **Given** 两者都不传，**When** 调用接口，**Then** 返回空 JSON，不出现必填参数绑定异常。

### 用户故事 3 - OTS 手机号为空时通过 external_user_id 补偿（优先级：P1）

当 OTS 基础信息没有 `phone_number` 或 `phone`，但存在 `external_user_id` 时，系统需要通过 `kkhc-idc-ai` 的补偿接口查询手机号，再继续查询图书物流。

**独立测试**：构造 `if_tushu=是`、`applet_user_id=null`、`otsInfo.phone_number=null`、`external_user_id` 有值且补偿接口返回手机号，验证会请求图书查询接口并携带补偿手机号。

**验收场景**：

1. **Given** OTS 手机号有值，**When** 调用 `setTushu`，**Then** 不调用 external_user_id 手机号补偿接口。
2. **Given** OTS 手机号为空且补偿接口命中手机号，**When** 调用 `setTushu`，**Then** 使用补偿手机号继续查询图书物流。
3. **Given** OTS 手机号为空且补偿接口未命中或异常，**When** 调用 `setTushu`，**Then** 不抛异常并保持默认物流状态。

### 用户故事 4 - 标签营期补偿识别已填写（优先级：P1）

当用户未查到小程序用户记录，但可通过外部联系人的营期标签获得当前营期时，系统需要检查同一企微员工下是否存在“已填写”标签，存在则将图书标识写为 `if_tushu=是`。

**独立测试**：构造多个 `follow_user`，其中非当前 `userid` 有“已填写”、当前 `userid` 无“已填写”，验证不设置为“是”；当前 `userid` 有“已填写”时才设置。

**验收场景**：

1. **Given** 当前 `qwUserId` 的标签包含“已填写”，**When** 标签营期匹配当前营期，**Then** 缓存 JSON 包含 `if_tushu=是`。
2. **Given** 其他 `userid` 的标签包含“已填写”，**When** 当前 `qwUserId` 不包含该标签，**Then** 不把 `if_tushu` 设置为“是”。
3. **Given** 标签营期不匹配当前营期，**When** 处理补偿分支，**Then** 保持无权限和 `if_tushu=否` 的原有行为。

## 边界情况

- `otsInfo` 为空或不包含 `phone_number` 时，不因手机号兜底抛异常。
- OTS 手机号为空、`external_user_id` 为空或补偿接口异常时，不因手机号补偿抛异常。
- `phone` 为空字符串时，接口返回空 JSON。
- 按手机号查询不到 `drh_book_question_record` 和 `drh_external_book_question_record` 时返回空 JSON。
- 仅通过 `phone` 查询时，无法从 `appletUserId` 获取 `channelId`，响应可不包含 `channelId`。
- `follow_user` 为空、当前 `userid` 不存在或标签为空时，“已填写”判断为 false。

## 需求 *(必填)*

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下创建本 Spec Kit 目录。
- **FR-002**：`AppTask#setTushu` MUST 接收来自 `otsInfo.phone_number` 的手机号。
- **FR-003**：`applet_user_id` 为空且手机号有值时，`AppTask#setTushu` MUST 继续请求图书物流查询接口。
- **FR-004**：`applet_user_id` 为空时 MUST 打印 `未查询到用户:applet_user_id={}将通过phone={}查询`。
- **FR-005**：图书查询接口 `appletUserId` 和 `phone` MUST 都为非必填参数。
- **FR-006**：图书查询服务 MUST 支持按 `phone` 查询两张图书物流记录表。
- **FR-007**：当 `appletUserId` 和 `phone` 同时存在时，服务 MUST 优先使用 `appletUserId` 反查到的手机号。
- **FR-008**：图书查询接口 MUST 保持原有响应字段 `lIds`、`aesId`、`type`、`channelId`、`bookList` 的语义。
- **FR-009**：`AiServiceImpl` MUST 在标签营期补偿分支中检查“已填写”标签。
- **FR-010**：“已填写”标签判断 MUST 校验 `follow_user.userid` 与当前 `qwUserId` 相等。
- **FR-011**：当前 `userid` 存在“已填写”标签且营期匹配时，缓存 JSON MUST 写入 `if_tushu=是`。
- **FR-012**：OTS `phone_number` 和 `phone` 为空时，`AppTask#setTushu` MUST 通过 `external_user_id` 调用补偿接口查询手机号。
- **FR-013**：`kkhc-idc-ai` MUST 提供 `GET /user/externalUserPhone?externalUserId=`，返回匹配到的最新非空手机号。
- **FR-014**：手机号补偿 SQL MUST 按 `drh_emp_external_user.external_userid` 查询，并通过 `union_id` 与 `emp_id` 关联 `drh_applet_user`，按 `drh_applet_user.id desc` 取 1 条。
- **FR-015**：手机号补偿失败、返回非 200 或返回空时，`AppTask#setTushu` MUST 记录日志并保持原默认物流状态。

## 成功标准 *(必填)*

- **SC-001**：本目录包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：`AppTask` 在 `applet_user_id=null` 且 `phone_number` 有值时构造包含 `phone` 的图书查询请求。
- **SC-003**：`getBookQuestionRecordByAppletUserId` 不再因为缺少 `appletUserId` 触发请求参数绑定失败。
- **SC-004**：只传 `phone` 时可按手机号查询物流记录。
- **SC-005**：当前 `userid` 下含“已填写”标签时，标签营期匹配分支写入 `if_tushu=是`。
- **SC-006**：编译检查覆盖 `external-info-select` 模块和 `kkhc-idc` 的 `ai` 模块。
- **SC-007**：OTS 手机号为空且补偿接口返回手机号时，`AppTask` 构造包含补偿手机号的图书查询请求。
- **SC-008**：`GET /user/externalUserPhone` 可按 `externalUserId` 返回最新非空手机号，不影响原 `user/externalUserInfo` 响应。

## 假设

- OTS 基础信息中的手机号字段为 `phone_number`，兼容读取 `phone`。
- 手机号查询不需要新增数据库字段或索引，现有 `phone` 字段可直接查询。
- 通过标签营期补偿获得权限时，`payment_amount=0` 可作为缓存中的非负权限标记。
- 补偿接口请求参数使用 `externalUserId`，SQL 字段仍使用 `external_userid`。
- 手机号补偿 SQL 使用 `a.emp_id = b.emp_id` 约束同一企微员工。
