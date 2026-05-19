# 规格执行说明

本目录记录 `023-external-info-save-piano-goodsid-by-tag` 的规格与实现约定，后续修改应保持文档与项目代码同步。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\023-external-info-save-piano-goodsid-by-tag`
- 目标项目：`C:\workspace\ju-chat\coze_plugin\external-info-save`
- 共享依赖：`C:\workspace\ju-chat\coze_plugin\common`

## 当前目标

- 在 `external-info-save` 中新增 `sku_id=4` 的 goodsId 标签分流。
- `sku_id=4` 时，若 `external_user_id + user_id` 对应标签包含 `李瑶新书`，则 goodsId 使用 `3379`。
- `sku_id=4` 时，若未命中该标签或标签查询失败，则 goodsId 使用 `3403`。
- 其他 SKU 保持现有 goodsId 解析和回退行为不变。
- 共享层补充 `OtsUtil.selectExternalUser(externalUserId, userId)`，返回 `List<FollowUser.Tag>`，供 `external-info-save` 直接复用。

## 后续实现约束

- 共享查询能力应沿用 `drh_external_user_info.follow_user` 结构，不新增新的数据来源。
- 标签匹配规则采用 `FollowUser.Tag.tag_name` 精确等于 `李瑶新书`。
- 查询失败、空结果、未命中用户都应走 `3403` 保底。
- 本次实现不新增接口、数据库表或消息协议字段。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录实现和验证任务。
- `checklists/requirements.md` 用于验证规格质量和实施就绪度。
