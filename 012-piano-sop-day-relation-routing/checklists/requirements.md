# 规格质量检查清单：钢琴视频 Prompt 与 SOP 天数关系路由

**用途**：验证钢琴视频 prompt 与钢琴 SOP 天数关系路由需求完整性和实现可测性  
**创建日期**：2026-05-11  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标代码文件。
- [x] 明确 `D%s` 替换目标为 `D + logicalDay`。
- [x] 明确钢琴特殊逻辑仅适用于 `sku=4`。
- [x] 明确过去作业使用 `recognizedDay` 获取 SOP 配置。
- [x] 明确过去作业使用 `homeworkDayRelation=CURRENT`，不使用 `PAST`。
- [x] 明确未来作业固定话术内容。
- [x] 所有必填章节已完成。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 标记残留。
- [x] 需求可测试且无歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖 prompt 替换、钢琴过去作业、钢琴未来作业。
- [x] 边界情况已识别。

## 实施就绪度

- [x] 实现范围限定在 `fc/sop-reply` 模块。
- [x] 不涉及数据库表结构、OTS 表结构、Redis key 结构或配置中心接口调整。
- [x] 明确需要编译检查。
- [x] `SopReply.java` 已按规格实现，且编译验证通过。

## 备注

- `PianoVideoHomeWorkHandleServiceImpl#resolvePianoVideoPrompt` 的 `D%s` 替换改动已完成并在本规格中记录。
- `SopReply.java` 的钢琴 SOP 过去/未来作业逻辑已实现。
