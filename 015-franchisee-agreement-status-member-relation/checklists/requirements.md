# 规格质量检查清单：联营商列表签约状态来源改造

**用途**：验证联营商列表签约状态来源、商户状态校验关联兼容需求完整性和后续实现可测性  
**创建日期**：2026-05-11  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确文档阶段和实现阶段的状态边界。
- [x] 明确目标接口为 `SchoolController#getFranchiseeList`。
- [x] 明确核心查询为 `OrganizationMapper#getFranchiseeList`。
- [x] 明确接口路径、请求体和返回体保持不变。
- [x] 明确联营商范围保持 `type=2`、`department_type=2`。
- [x] 明确自己的商户号状态优先。
- [x] 明确没有自己的商户号时使用关联商户号状态兜底。
- [x] 明确 `organization_ids` 必须使用分隔符安全匹配。
- [x] 明确每个联营商只返回一条。
- [x] 明确多条命中记录的稳定排序规则。
- [x] 明确订单预下单前商户状态校验也需要兼容联营商关联商户号。
- [x] 明确当前失败链路包含 `ProjOrderServiceImpl#createQrCode`、订单侧 `checkMemberState`、`BaseClient#checkMemberState`、`MemberController#checkMemberState` 和 `MemberServiceImpl#checkMemberState`。
- [x] 本次商户状态校验兼容增量已从文档阶段推进到代码实现阶段。
- [x] 明确所有必填章节已完成。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 标记残留。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖自己的商户号、关联商户号、无商户号、两者同时存在、多条命中、筛选和分页唯一性。
- [x] 验收场景覆盖 `checkMemberState` 的自己的商户号可用、关联商户号可用、自己的商户号不可用、无可用商户号和分隔符误匹配风险。
- [x] 边界情况已识别。
- [x] 已记录 `schoolQueryCondition.agreementStatus` 沿用现有 0 到 4 列表进度筛选语义。
- [x] 已记录商户状态校验失败提示保持 `通联账号未申请成功，请先确认`。
- [x] 已记录自己的商户号存在但不可用时，不使用关联商户号绕过失败。

## 实施就绪度

- [x] 实现范围优先限定在 `OrganizationMapper#getFranchiseeList`。
- [x] 已说明必要时可调整 `OrganizationServiceImpl#getFranchiseeList` 的文案派生或去重保护。
- [x] 商户状态校验增量的实现范围优先限定在 `MemberServiceImpl#checkMemberState`。
- [x] 已说明需要排查其他商户状态、通联账号状态、`checkMemberState`、`organization_id` 单点校验位置。
- [x] 不涉及数据库表结构调整。
- [x] 不涉及 DTO 字段调整。
- [x] 不涉及接口路径调整。
- [x] 明确需要编译 `idc/base` 模块。
- [x] 明确商户状态校验增量后续需要编译 `idc/base` 与 `idc/order` 相关模块。
- [x] 明确需要验证 Mapper 查询结果。
- [x] 明确需要验证 `checkMemberState` 和订单预下单路径。
- [x] 已修改业务代码。
- [x] 已实现 `MemberServiceImpl#checkMemberState` 的联营商关联商户号兼容。
- [x] 已执行聚合模块编译。

## 备注

- 已完成 Mapper 查询实现，避免 OR JOIN 直接展开后分页，防止同一联营商重复出现。
- 尚未连接真实数据库执行 T024 到 T036 的数据场景验证。
- 本次商户状态校验兼容增量已修改 `proj-two` 业务代码。
- 后续实现需重点验证 `schoolId=30475` 类似场景：联营商没有自己的可用商户号，但存在关联可用商户号时，预下单不再因商户状态校验失败。
- `idc/base` 模块编译已通过；`idc/order` 聚合编译被既有 `ProjOrderServiceImpl` 编译错误阻塞，需单独处理后再完成订单模块编译状态。
