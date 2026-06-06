# 需求检查清单：图书订单 UnionId 兜底查询

## 文档完整性

- [x] 已创建规格目录 `056-book-order-unionid-fallback`。
- [x] 已包含 `AGENTS.md`、`spec.md`、`tasks.md`。
- [x] 已包含 `checklists/requirements.md`。

## 调用端

- [x] `AppTask` 通过 `external_userid` 查询 `unionId`。
- [x] `unionId` 优先来自 `drh_emp_external_user.union_id`。
- [x] OTS 未命中时兜底 `drh_external_user_info.unionid/union_id`。
- [x] `unionId` 非空才追加到 `getBookOrderByPhone` URL。
- [x] `unionId` 为空时不调用 `OtsUtil.searchRow`。

## OTS

- [x] 查询表固定为 `drh_emp_external_user`。
- [x] 查询索引固定为 `drh_emp_external_user_index`。
- [x] 查询字段固定为 `external_userid`。
- [x] 返回字段固定为 `union_id`。
- [x] 空参、未命中和异常不阻断主流程。

## AI 接口

- [x] `unionId` 是可选请求参数。
- [x] 旧 `phone` 调用兼容。
- [x] 查询顺序为手机号优先、unionId 兜底。
- [x] 查询顺序为手机号、`drh_h5_order.union_id`、`drh_applet_user.union_id` 关联订单。
- [x] 三段查询都限制近 7 天。
- [x] 响应 DTO 结构不变。
- [x] 图书商品 `goodsId` 回填规则不变。

## 验证

- [x] `coze_plugin` 调用链编译通过。
- [x] `kkhc-idc/ai` 编译通过。
