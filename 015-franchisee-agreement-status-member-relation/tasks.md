# 任务清单：联营商列表签约状态来源改造

**输入**：来自 `specs/015-franchisee-agreement-status-member-relation/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：当前阶段仅创建文档；后续实现后需编译 `idc/base` 模块并验证 Mapper 查询场景。  

## Phase 1：规格与范围

- [x] T001 创建 Spec Kit 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确当前阶段只编写文档，不修改业务代码
- [x] T003 明确目标接口为 `SchoolController#getFranchiseeList`
- [x] T004 明确后续查询核心为 `OrganizationMapper#getFranchiseeList`
- [x] T005 明确接口路径、请求体和返回体保持不变
- [x] T006 明确联营商范围保持 `type=2`、`department_type=2`
- [x] T007 明确状态来源优先级：自己的商户号优先，关联商户号兜底
- [x] T008 明确 `organization_ids` 必须使用分隔符安全匹配
- [x] T009 明确每个联营商只返回一条，避免 OR JOIN 重复分页记录
- [x] T010 明确同优先级多条命中时按 `update_time DESC, id DESC` 取一条
- [x] T011 明确 `agreementStatusStr` 沿用现有文案规则
- [x] T012 明确 `schoolQueryCondition.agreementStatus` 基于最终选中的状态过滤

## Phase 2：后续实现

- [x] T013 调整 `OrganizationMapper#getFranchiseeList`，先为每个联营商选出最终会员记录，再输出列表字段
- [x] T014 将会员匹配优先级设置为：`organization_id = a.id` 优先级 1，`organization_ids` 包含 `a.id` 优先级 2
- [x] T015 对同一优先级的多条会员记录使用 `update_time DESC, id DESC` 选取一条
- [x] T016 使用 `LOCATE(CONCAT(',', a.id, ','), CONCAT(',', b.organization_ids, ',')) > 0` 或等价写法匹配 `organization_ids`
- [x] T017 避免直接 `SELECT *`，明确选择 `proj_organization` 字段和会员状态字段别名
- [x] T018 确保分页主体为联营商组织记录，每个联营商最多返回一条
- [x] T019 调整 `schoolQueryCondition.agreementStatus` 的 SQL 条件，使其基于最终选中的会员记录判断
- [x] T020 保持 `SchoolController#getFranchiseeList` 设置 `type=2`、`departmentType=2` 的行为不变
- [x] T021 保持 `OrganizationServiceImpl#getFranchiseeList` 的 `agreementStatusStr` 文案规则不变
- [x] T022 如 Mapper 已保证唯一记录，保留 Service 层现有校区名称填充逻辑；如仍可能重复，增加防御性去重
- [x] T023 不新增 DTO 字段，不修改数据库结构，不修改接口路径

## Phase 3：后续验证

- [ ] T024 验证无会员记录时返回 `agreementStatus=null`、`agreementStatusStr=未开启`
- [ ] T025 验证只有自己的商户号时取自己的 `registrationStatus`、`bindPhone`、`agreementStatus`
- [ ] T026 验证只有关联商户号时取关联商户号状态
- [ ] T027 验证自己和关联同时存在时取自己的状态
- [ ] T028 验证多条同类会员命中时按 `update_time DESC, id DESC` 取一条
- [ ] T029 验证 `agreementStatus=0` 只返回最终状态为 `未开启` 的联营商
- [ ] T030 验证 `agreementStatus=1` 只返回最终状态为 `步骤1` 的联营商
- [ ] T031 验证 `agreementStatus=2` 只返回最终状态为 `步骤2` 的联营商
- [ ] T032 验证 `agreementStatus=3` 只返回最终状态为 `步骤3` 的联营商
- [ ] T033 验证 `agreementStatus=4` 只返回最终状态为 `签约完成` 的联营商
- [ ] T034 验证自己的商户号和关联商户号状态不同时，筛选只按自己的状态生效
- [ ] T035 验证 `organization_ids='12'` 不匹配联营商 id `2`
- [ ] T036 验证分页结果中同一个联营商不重复出现
- [x] T037 编译 `C:\workspace\proj\proj-two\idc\base` 模块
- [x] T038 记录 Mapper 查询验证结果和剩余风险

## 执行记录

### D001 - 文档记录

- 已按用户要求创建 Spec Kit 文档。
- 当前阶段未修改 `SchoolController.java`、`OrganizationMapper.java`、`OrganizationServiceImpl.java` 或其他业务代码。
- 已记录自己的商户号和关联商户号的状态来源优先级。
- 已记录 `organization_ids` 的分隔符安全匹配要求。
- 已记录每个联营商只返回一条和多条命中时的稳定取值规则。
- 已记录后续实现任务和验证任务。

### D002 - 实现记录

- 已将 `OrganizationMapper#getFranchiseeList` 从注解 SQL 迁移到 `OrganizationMapper.xml`。
- `getFranchiseeList` 现在以 `proj_organization` 联营商记录为分页主体。
- 使用相关子查询为每个联营商选择一条最终 `proj_member` 记录。
- 最终会员记录选择规则为：`organization_id = a.id` 优先；没有自己的商户号时，再使用 `organization_ids` 关联商户号。
- 多条同优先级会员记录按 `update_time DESC, id DESC` 取一条。
- `organization_ids` 使用 `LOCATE(CONCAT(',', a.id, ','), CONCAT(',', m2.organization_ids, ',')) > 0` 做分隔符安全匹配。
- 查询不再使用 `SELECT *`，改为明确输出组织字段和会员状态字段别名。
- `schoolQueryCondition.agreementStatus` 的 0 到 4 筛选基于最终选中的会员记录判断。
- 未修改 `SchoolController.java`、`OrganizationServiceImpl.java`、DTO 或数据库结构。

### D003 - 验证记录

- 执行 XML 格式解析：`OrganizationMapper.xml OK`。
- 执行命令：`mvn -q -DskipTests -pl proj-two/idc/base -am compile`
- 执行目录：`C:\workspace\proj`
- 执行结果：编译通过。
- 直接在 `C:\workspace\proj\proj-two\idc\base` 执行 `mvn -q -DskipTests compile` 会因未纳入同仓库 `common` 和父级依赖而失败；已改用聚合根编译验证。
- 剩余风险：未连接真实数据库执行 Mapper 查询，T024 到 T036 的数据场景需在具备测试数据源后验证。
