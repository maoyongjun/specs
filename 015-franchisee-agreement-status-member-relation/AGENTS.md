# 规格执行说明

本目录记录 `015-franchisee-agreement-status-member-relation`。当前阶段只完成 Spec Kit 文档，不修改业务代码。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\015-franchisee-agreement-status-member-relation`
- 入口接口：`C:\workspace\proj\proj-two\idc\base\src\main\java\com\proj\base\controller\SchoolController.java`
- 查询 Mapper：`C:\workspace\proj\proj-two\idc\base\src\main\java\com\proj\base\v2\organization\mapper\OrganizationMapper.java`
- 状态文案派生：`C:\workspace\proj\proj-two\idc\base\src\main\java\com\proj\base\v2\organization\service\impl\OrganizationServiceImpl.java`
- 返回对象：`C:\workspace\proj\common\src\main\java\com\drh\common\dto\vo\SchoolVo.java`

## 当前目标

- 规划 `POST /school/getFranchiseeList` 的联营商签约状态来源改造。
- `agreementStatus` 和 `agreementStatusStr` 应取联营商自己的商户号状态。
- 如果联营商没有自己的商户号状态，再取关联商户号状态。
- 自己的商户号和关联商户号同时存在时，自己的商户号优先。
- 每个联营商在分页结果中只返回一条记录。

## 后续实现约束

- 接口路径、请求体和返回体保持不变。
- 不新增 DTO 字段，不调整数据库结构。
- 联营商范围保持 `proj_organization.type = 2 AND proj_organization.department_type = 2`。
- 自己的商户号匹配条件为 `proj_member.organization_id = proj_organization.id`。
- 关联商户号匹配条件为 `proj_organization.id` 出现在 `proj_member.organization_ids` 逗号分隔列表中。
- 关联匹配必须使用分隔符安全匹配，避免联营商 id `2` 误命中 `12`。
- 状态筛选必须基于最终选中的商户号状态，不能在自己商户号存在时被关联商户号状态影响。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录后续实现和验证任务。
- `checklists/requirements.md` 用于验证规格质量和实施就绪度。
