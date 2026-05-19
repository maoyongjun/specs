# 功能规格：钢琴 SKU4 goodsId 按标签分流

**功能目录**: `023-external-info-save-piano-goodsid-by-tag`  
**创建日期**: 2026-05-19  
**状态**: Implemented  
**输入**: 用户要求在 `coze_plugin/external-info-save` 中修改钢琴 `sku_id=4` 的 goodsId 选择逻辑：先通过用户标签判断，若包含 `李瑶新书` 则使用 `3379`，否则使用 `3403`；标签查询可通过 `OtsUtil.selectExternalUser(externalUserId, userId)` 获取，参考代码位于 `fc/delay-mq/.../AppTask.java` 的 `notNeedReplay`。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 钢琴 SKU4 命中“李瑶新书”标签时使用 3379（优先级：P1）

当 `external-info-save` 处理 `sku_id=4` 的钢琴用户时，如果该用户在 OTS 标签中包含 `李瑶新书`，系统应使用 `3379` 作为 goodsId，确保后续图书/订单登记按钢琴新书分流。

**独立测试**：构造 `sku_id=4`、`external_user_id` 和 `user_id`，使 `OtsUtil.selectExternalUser(...)` 返回包含 `李瑶新书` 的标签列表，验证最终写入 `BookEditAddressDto.goodsId` 为 `3379`。

**验收场景**：

1. **Given** `sku_id=4` 且标签列表包含 `李瑶新书`，**When** 解析 goodsId，**Then** 结果为 `3379`。
2. **Given** `sku_id=4` 且标签列表包含多个标签但也包含 `李瑶新书`，**When** 解析 goodsId，**Then** 仍使用 `3379`。
3. **Given** `sku_id=4` 且标签查询返回空列表之外的其他标签，**When** 解析 goodsId，**Then** 只有精确命中 `李瑶新书` 才会返回 `3379`。

### 用户故事 2 - 钢琴 SKU4 未命中标签时使用 3403（优先级：P1）

当 `sku_id=4` 的钢琴用户未命中 `李瑶新书` 标签时，系统应回退到固定 goodsId `3403`，避免因为标签缺失导致登记失败或商品错配。

**独立测试**：构造 `sku_id=4`，让 `OtsUtil.selectExternalUser(...)` 返回空列表或不包含 `李瑶新书` 的标签列表，验证 goodsId 为 `3403`。

**验收场景**：

1. **Given** `sku_id=4` 且标签列表为空，**When** 解析 goodsId，**Then** 结果为 `3403`。
2. **Given** `sku_id=4` 且标签列表不包含 `李瑶新书`，**When** 解析 goodsId，**Then** 结果为 `3403`。
3. **Given** `sku_id=4` 且标签查询异常，**When** 解析 goodsId，**Then** 系统应记录日志并回退到 `3403`。

### 用户故事 3 - 非钢琴 SKU 保持原有 goodsId 逻辑不变（优先级：P1）

对非 `sku_id=4` 的请求，系统仍应沿用现有 goodsId 解析逻辑，包括原有环境变量回退和 `sku` 相关的既有分支，不引入新的标签判断副作用。

**独立测试**：构造 `sku_id != 4` 的请求，验证 goodsId 仍然来自现有环境变量逻辑，且不会触发 `OtsUtil.selectExternalUser(...)`。

**验收场景**：

1. **Given** `sku_id != 4`，**When** 解析 goodsId，**Then** 仍使用现有环境变量规则。
2. **Given** `sku_id != 4`，**When** 查看日志，**Then** 不应出现 `李瑶新书` 标签分流日志。
3. **Given** `sku_id != 4`，**When** 处理订单登记，**Then** 既有行为保持不变。

### 用户故事 4 - 共享 OTS 查询能力可复用标签列表（优先级：P2）

为了让 `external-info-save` 直接复用参考实现，`coze_plugin/common` 需要提供 `OtsUtil.selectExternalUser(externalUserId, userId)`，返回 `List<FollowUser.Tag>`，并从 `drh_external_user_info.follow_user` 中解析标签。

**独立测试**：准备一个包含 `follow_user` 数组的 OTS 记录，验证该方法能按 `external_user_id` 取到对应用户，并返回其标签列表。

**验收场景**：

1. **Given** OTS 中存在目标 `external_user_id` 且对应 `user_id`，**When** 调用查询方法，**Then** 返回对应标签列表。
2. **Given** OTS 中不存在目标 `external_user_id`，**When** 调用查询方法，**Then** 返回空列表。
3. **Given** `follow_user` 数据为空或解析失败，**When** 调用查询方法，**Then** 返回空列表并记录日志。

## 边界情况

- `sku_id=4` 但 `external_user_id` 或 `user_id` 为空。
- `follow_user` 字段不存在、为空字符串或 JSON 解析失败。
- 用户存在但没有任何标签。
- 用户存在多个标签，且只有其中一个标签名精确等于 `李瑶新书`。
- `sku_id != 4` 时仍需保持既有 goodsId 逻辑。
- `BookOrderDto.getGoodsId()` 有值时，仍沿用原来的订单商品结果覆盖逻辑。

## 需求 *(必填)*

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下创建本 Spec Kit 目录。
- **FR-002**：`external-info-save` MUST 在 `sku_id=4` 时根据用户标签选择 goodsId。
- **FR-003**：当标签列表中存在 `李瑶新书` 时，goodsId MUST 使用 `3379`。
- **FR-004**：当 `sku_id=4` 且未命中 `李瑶新书` 时，goodsId MUST 使用 `3403`。
- **FR-005**：标签查询 MUST 通过 `OtsUtil.selectExternalUser(externalUserId, userId)` 获取 `List<FollowUser.Tag>`。
- **FR-006**：`selectExternalUser` MUST 从 `drh_external_user_info.follow_user` 中解析对应 `user_id` 的标签列表。
- **FR-007**：`selectExternalUser` MUST 在未命中、空结果或异常时返回空列表，并记录日志。
- **FR-008**：`sku_id != 4` 的 goodsId 解析 MUST 保持现有逻辑不变。
- **FR-009**：订单登记流程中现有 `BookOrderDto.getGoodsId()` 覆盖行为 MUST 保持不变。

## 成功标准 *(必填)*

- **SC-001**：`sku_id=4` 且存在 `李瑶新书` 标签时，goodsId 结果稳定为 `3379`。
- **SC-002**：`sku_id=4` 且未命中标签或查询失败时，goodsId 结果稳定为 `3403`。
- **SC-003**：`sku_id != 4` 时，现有 goodsId 逻辑不发生回归。
- **SC-004**：`OtsUtil.selectExternalUser(...)` 可在共享模块中编译并返回标签列表。
- **SC-005**：`coze_plugin/common` 与 `external-info-save` 一起编译通过。

## 假设

- 标签命中采用 `FollowUser.Tag.tag_name` 精确匹配 `李瑶新书`。
- `sku_id=4` 的固定 goodsId 仅在钢琴分支生效，不影响其他商品。
- 标签查询失败、空结果或未命中时统一回退到 `3403`。
- 共享方法复用 `drh_external_user_info` 中 `follow_user` 的既有 JSON 结构。

## 执行记录

### D001 - 实现记录

- `coze_plugin/common` 已新增 `FollowUser` DTO。
- `coze_plugin/common` 已新增 `OtsUtil.selectExternalUser(externalUserId, userId)`，按 `follow_user` 解析标签列表。
- `external-info-save` 已在 `sku_id=4` 时按 `李瑶新书` 标签分流 goodsId，命中时使用 `3379`，未命中时使用 `3403`。
- 非 `sku_id=4` 的 goodsId 解析保持原有逻辑不变。
