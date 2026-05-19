# 规格质量检查清单：钢琴 SKU4 goodsId 按标签分流

**用途**：验证钢琴 goodsId 分流需求完整性和后续实现可测性  
**创建日期**：2026-05-19  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标模块为 `coze_plugin/external-info-save`。
- [x] 明确共享查询能力补充到 `coze_plugin/common`。
- [x] 明确 `sku_id=4` 的分流规则。
- [x] 明确命中标签使用 `3379`。
- [x] 明确未命中标签、空结果或查询失败使用 `3403`。
- [x] 明确标签名为 `李瑶新书`。
- [x] 明确标签查询方法为 `OtsUtil.selectExternalUser(externalUserId, userId)`。
- [x] 明确返回类型为 `List<FollowUser.Tag>`。
- [x] 明确非 `sku_id=4` 行为不变。
- [x] 明确现有 `BookOrderDto.getGoodsId()` 覆盖行为不变。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 标记残留。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖命中标签、未命中标签、查询失败和非 `sku_id=4`。
- [x] 边界情况已识别。

## 实施就绪度

- [x] 实现范围限定为 `coze_plugin/common` 与 `coze_plugin/external-info-save`。
- [x] 本次不新增接口、数据库表或消息协议字段。
- [x] 明确后续实现需支持标签查询失败兜底。
- [x] 明确后续实现需保持非钢琴 SKU 不回归。

## 备注

- 标签匹配采用 `FollowUser.Tag.tag_name` 精确等于 `李瑶新书`。
- 查询结果为空、用户未命中或异常时统一回退到 `3403`。
