# 任务清单：钢琴 SKU4 goodsId 按标签分流

**输入**：来自 `specs/023-external-info-save-piano-goodsid-by-tag/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：实现阶段需要验证 `sku_id=4` 的标签分流、`OtsUtil.selectExternalUser(...)` 的返回值、`sku_id != 4` 的行为不回归，以及 `common` 和 `external-info-save` 联合编译通过。

## Phase 1：规格与范围

- [x] T001 创建 `specs/023-external-info-save-piano-goodsid-by-tag` 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确目标模块为 `coze_plugin/external-info-save`
- [x] T003 明确共享查询能力补充到 `coze_plugin/common`
- [x] T004 明确 `sku_id=4` 时按 `李瑶新书` 标签分流 goodsId
- [x] T005 明确命中标签时使用 `3379`
- [x] T006 明确未命中标签、空结果或查询失败时使用 `3403`
- [x] T007 明确非 `sku_id=4` 保持现有逻辑不变

## Phase 2：实现

- [x] T008 在 `coze_plugin/common` 新增 `FollowUser` DTO
- [x] T009 在 `coze_plugin/common` 新增 `OtsUtil.selectExternalUser(externalUserId, userId)`
- [x] T010 在 `external-info-save` 新增 goodsId 标签分流 helper
- [x] T011 替换 `sku_id=4` 的 goodsId 兜底值为标签分流结果
- [x] T012 保持非 `sku_id=4` 的 goodsId 行为不变
- [x] T013 增加必要日志，便于线上排查分流结果

## Phase 3：验证

- [x] T014 验证 `sku_id=4 + 李瑶新书` 时 goodsId 为 `3379`
- [x] T015 验证 `sku_id=4 + 无标签/查不到/异常` 时 goodsId 为 `3403`
- [x] T016 验证 `sku_id != 4` 行为不回归
- [x] T017 验证 `coze_plugin/common` 与 `external-info-save` 联合编译通过

## 执行记录

### D001 - 实现记录

- 已在共享模块补齐 `FollowUser` DTO 与 `OtsUtil.selectExternalUser(...)`。
- 已在 `external-info-save` 中将 `sku_id=4` 的 goodsId 改为按 `李瑶新书` 标签分流。
- 已保留非 `sku_id=4` 的原有 goodsId 解析逻辑。
