# 功能规格：图书订单 UnionId 兜底查询

**功能目录**：`056-book-order-unionid-fallback`  
**创建日期**：2026-06-06  
**状态**：Implemented  
**输入**：修改图书物流登记链路。`external-info-save` 调用 `getBookOrderByPhone` 时增加 `unionId` 参数；`unionId` 通过 OTS 表 `drh_emp_external_user` 按 `external_userid` 获取。AI 接口先通过手机号查询订单，查不到时再按 `drh_h5_order.union_id` 查询近 7 天订单；仍查不到时，通过 `drh_h5_order.applet_user_id = drh_applet_user.id` 且 `drh_applet_user.union_id = unionId` 关联查询近 7 天订单并返回。

## 用户场景与测试

### 用户故事 1 - 图书登记调用端能携带 unionId

AI 保存外部信息时，用户填写了图书收货信息。系统需要在调用图书订单查询接口前，通过外部用户 id 找到 `unionId`，并传给 AI 服务，提升手机号不一致场景下的订单匹配率。

**验收场景**：

1. **Given** `external_userid` 在 OTS `drh_emp_external_user` 中存在 `union_id`，**When** `AppTask` 调用 `getBookOrderByPhone`，**Then** 请求 URL 包含 `phone` 和 URL 编码后的 `unionId`。
2. **Given** `drh_emp_external_user` 未命中，**When** `drh_external_user_info` 中存在 `unionid` 或 `union_id`，**Then** 调用端使用该值作为兜底 `unionId`。
3. **Given** 未获取到 `unionId`，**When** 调用端继续查询订单，**Then** 只传 `phone`，并且 `appletUserId` 保持现有补偿逻辑。

### 用户故事 2 - AI 接口按 unionId 兜底查订单

AI 服务收到手机号和可选 `unionId` 后，先保留现有手机号查询行为；只有手机号无近 7 天订单时，才按 `unionId` 查询 `drh_h5_order` 近 7 天订单。

**验收场景**：

1. **Given** 手机号近 7 天有订单，**When** 调用 `/ai/getBookOrderByPhone?phone=xxx&unionId=yyy`，**Then** 返回手机号订单，不执行 unionId 替换逻辑。
2. **Given** 手机号近 7 天无订单且 `unionId` 非空，**When** `drh_h5_order.union_id` 近 7 天有订单，**Then** 返回 unionId 命中的订单。
3. **Given** 手机号近 7 天无订单且 `drh_h5_order.union_id` 无订单，**When** `drh_applet_user.union_id` 关联到的 `applet_user_id` 近 7 天有订单，**Then** 返回关联命中的订单。
4. **Given** 手机号近 7 天无订单且 `unionId` 为空，**When** 调用接口，**Then** 返回空列表。
5. **Given** 旧调用只传 `phone`，**When** 调用接口，**Then** 响应结构和原逻辑兼容。

## 功能需求

- **FR-001**：`external-info-save` MUST 通过 `external_userid` 查询 OTS 表 `drh_emp_external_user` 的 `union_id`。
- **FR-002**：OTS 查询 MUST 使用 `drh_emp_external_user_index`，条件字段为 `external_userid`，返回字段为 `union_id`。
- **FR-003**：`external-info-save` MUST 在 `unionId` 非空时将其追加到 `getBookOrderByPhone` 请求参数。
- **FR-004**：`external-info-save` MUST 在 `unionId` 为空时跳过 `OtsUtil.searchRow`，避免空值查询。
- **FR-005**：AI Controller MUST 将 `unionId` 声明为可选请求参数。
- **FR-006**：AI Service MUST 先按手机号和近 7 天时间窗口查询 `drh_h5_order`。
- **FR-007**：手机号查询结果为空且 `unionId` 非空时，AI Service MUST 再按 `drh_h5_order.union_id` 和近 7 天时间窗口查询 `drh_h5_order`。
- **FR-008**：手机号和 `drh_h5_order.union_id` 均无结果且 `unionId` 非空时，AI Service MUST 通过 `drh_h5_order.applet_user_id = drh_applet_user.id AND drh_applet_user.union_id = unionId` 关联查询近 7 天订单。
- **FR-009**：`BookOrderDto` 响应结构 MUST 保持不变。
- **FR-010**：订单商品的图书类目判定 MUST 保持现有启用组合商品集合逻辑。
- **FR-011**：实现 MUST 不新增数据库表、公共 DTO 字段或配置项。

## 边界情况

- OTS `drh_emp_external_user` 未命中。
- OTS 命中但 `union_id` 为空。
- `drh_external_user_info` 只有 `union_id` 而没有 `unionid`。
- 手机号查询命中非图书商品订单。
- 手机号查询为空，`unionId` 查询命中多个近 7 天订单。
- `drh_h5_order.union_id` 为空但 `applet_user_id` 关联的 `drh_applet_user.union_id` 命中。
- 旧调用方只传 `phone`。

## 成功标准

- **SC-001**：`AppTask` 可以稳定把非空 `unionId` 传入 `getBookOrderByPhone`。
- **SC-002**：手机号有结果时接口结果不因 `unionId` 改变。
- **SC-003**：手机号无结果且 `drh_h5_order.union_id` 有近 7 天订单时接口能返回订单。
- **SC-004**：手机号和 `drh_h5_order.union_id` 均无结果，但 `drh_applet_user.union_id` 关联有近 7 天订单时接口能返回订单。
- **SC-005**：旧 URL `/ai/getBookOrderByPhone?phone=xxx` 继续可用。
- **SC-006**：`mvn -f C:\workspace\ju-chat\coze_plugin\pom.xml -pl common,external-info-save -am -DskipTests package` 编译通过。
- **SC-007**：`mvn -f C:\workspace\ju-chat\kkhc\kkhc-idc\pom.xml -pl ai -am -DskipTests compile` 编译通过。

## 假设

- “手机号查不到”定义为手机号近 7 天订单查询列表为空。
- `drh_h5_order.union_id` 对应 `H5OrderDO.unionId`，使用 MyBatis-Plus 驼峰映射。
- OTS `drh_emp_external_user_index` 已存在，并包含 `external_userid` 查询字段和 `union_id` 返回字段。
