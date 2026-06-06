# 规格执行说明

本目录是图书订单 UnionId 兜底查询的 Spec Kit 文档。实现必须按 `spec.md`、`tasks.md` 和 `checklists/requirements.md` 执行。

## 作用范围

- 规格目录：`C:\workspace\ju-chat\specs\056-book-order-unionid-fallback`
- Coze 插件调用端：`C:\workspace\ju-chat\coze_plugin\external-info-save`
- Coze 公共 OTS 工具：`C:\workspace\ju-chat\coze_plugin\common`
- AI 服务模块：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`

## 必读参考代码

- 调用端入口：`coze_plugin\external-info-save\src\main\java\com\drh\info\service\AppTask.java`
- 公共 OTS 工具：`coze_plugin\common\src\main\java\com\drh\common\util\OtsUtil.java`
- OTS unionId 查询参考：`coze_plugin\payment-send\src\main\java\com\drh\paymentsend\utils\OtsUtil.java`
- AI Controller：`kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\controller\AiController.java`
- AI Service：`kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\AiService.java`
- AI Service 实现：`kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\impl\AiServiceImpl.java`

## 固定实现口径

- `getBookOrderByPhone` 必须兼容旧调用，仅 `phone` 参数仍能正常返回。
- 新增 `unionId` 为可选参数，不新增 DTO 字段和数据库表。
- AI 服务端查询顺序固定为：先查手机号近 7 天订单；无结果且 `unionId` 非空时，再查 `drh_h5_order.union_id` 近 7 天订单；仍无结果时，通过 `drh_h5_order.applet_user_id = drh_applet_user.id AND drh_applet_user.union_id = unionId` 关联查询近 7 天订单。
- 调用端通过 OTS `drh_emp_external_user_index` 查询 `drh_emp_external_user.external_userid -> union_id`。
- OTS 未命中时允许回退 `drh_external_user_info.unionid/union_id`。
- `OtsUtil.searchRow` 不得使用空 `unionId` 查询。

## 验证门禁

- 手机号查询有结果时不得再使用 `unionId` 结果替换。
- 手机号查询为空且 `drh_h5_order.union_id` 命中时，必须返回同样结构的 `BookOrderDto` 列表。
- 手机号和 `drh_h5_order.union_id` 查询均为空，但 `drh_applet_user.union_id` 关联命中时，也必须返回同样结构的 `BookOrderDto` 列表。
- `goodsId` 回填规则保持原样：只有命中启用组合图书商品集合时才回填。
- 编译验证至少覆盖 `coze_plugin` 的 `common,external-info-save` 和 `kkhc-idc` 的 `ai` 模块。
