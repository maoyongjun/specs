# 规格质量检查清单：联营商列表签约状态来源改造

**用途**：验证联营商列表签约状态来源需求完整性和后续实现可测性  
**创建日期**：2026-05-11  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确当前阶段只编写文档，不编码。
- [x] 明确目标接口为 `SchoolController#getFranchiseeList`。
- [x] 明确核心查询为 `OrganizationMapper#getFranchiseeList`。
- [x] 明确接口路径、请求体和返回体保持不变。
- [x] 明确联营商范围保持 `type=2`、`department_type=2`。
- [x] 明确自己的商户号状态优先。
- [x] 明确没有自己的商户号时使用关联商户号状态兜底。
- [x] 明确 `organization_ids` 必须使用分隔符安全匹配。
- [x] 明确每个联营商只返回一条。
- [x] 明确多条命中记录的稳定排序规则。
- [x] 明确所有必填章节已完成。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 标记残留。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖自己的商户号、关联商户号、无商户号、两者同时存在、多条命中、筛选和分页唯一性。
- [x] 边界情况已识别。
- [x] 已记录 `schoolQueryCondition.agreementStatus` 沿用现有 0 到 4 列表进度筛选语义。

## 实施就绪度

- [x] 实现范围优先限定在 `OrganizationMapper#getFranchiseeList`。
- [x] 已说明必要时可调整 `OrganizationServiceImpl#getFranchiseeList` 的文案派生或去重保护。
- [x] 不涉及数据库表结构调整。
- [x] 不涉及 DTO 字段调整。
- [x] 不涉及接口路径调整。
- [x] 明确需要编译 `idc/base` 模块。
- [x] 明确需要验证 Mapper 查询结果。
- [x] 已修改业务代码。
- [x] 已执行聚合模块编译。

## 备注

- 已完成 Mapper 查询实现，避免 OR JOIN 直接展开后分页，防止同一联营商重复出现。
- 尚未连接真实数据库执行 T024 到 T036 的数据场景验证。
