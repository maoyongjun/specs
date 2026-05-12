# 功能规格：联营商列表签约状态来源改造

**功能目录**: `015-franchisee-agreement-status-member-relation`  
**创建日期**: 2026-05-11  
**状态**: Implemented - Base Compile Passed; Runtime Verification Pending  
**输入**: 用户要求先在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档，不编码；后续修改 `C:\workspace\proj\proj-two\idc\base\src\main\java\com\proj\base\controller\SchoolController.java` 的 `getFranchiseeList` 接口，使 `agreementStatus` 和 `agreementStatusStr` 取自己的状态或者关联的商户号状态，并参考 `organizationMapper.getFranchiseeList` 的 SQL 关联逻辑；本次增量要求把订单预下单前的商户状态校验也纳入联营商关联商户号兼容范围，解决 `商户号状态异常,schoolId=30475,message=通联账号未申请成功，请先确认。` 场景。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 联营商列表优先展示自己的商户号状态（优先级：P1）

运营在查看联营商列表时，需要看到该联营商自己的通联/签约进度。系统应优先取 `proj_member.organization_id = proj_organization.id` 的会员记录，基于该记录填充 `agreementStatus`、`registrationStatus`、`bindPhone`，并生成 `agreementStatusStr`。

**独立测试**：准备一个联营商组织和一条 `organization_id` 等于该联营商 id 的 `proj_member` 记录，调用 `POST /school/getFranchiseeList`，验证返回记录中的 `agreementStatus` 和 `agreementStatusStr` 均来自该会员记录。

**验收场景**：

1. **Given** 联营商存在自己的商户号且没有关联商户号，**When** 查询联营商列表，**Then** 返回自己的 `agreementStatus` 和对应 `agreementStatusStr`。
2. **Given** 联营商存在自己的商户号且同时被其他商户号关联，**When** 查询联营商列表，**Then** 仍优先返回自己的商户号状态。
3. **Given** 自己的商户号状态未完成但关联商户号状态已完成，**When** 查询联营商列表，**Then** 返回自己的未完成状态，不被关联商户号覆盖。

### 用户故事 2 - 没有自己的商户号时使用关联商户号状态兜底（优先级：P1）

部分联营商没有 `organization_id` 直接等于自身 id 的商户号，但会出现在其他会员记录的 `organization_ids` 中。系统应在没有自己的商户号时，使用关联商户号状态填充列表状态。

**独立测试**：准备一个没有直接会员记录的联营商，并准备一条 `organization_ids` 包含该联营商 id 的 `proj_member` 记录，调用列表接口，验证状态来自关联会员记录。

**验收场景**：

1. **Given** 联营商没有自己的商户号但存在关联商户号，**When** 查询联营商列表，**Then** 返回关联商户号的 `agreementStatus` 和对应 `agreementStatusStr`。
2. **Given** 联营商既没有自己的商户号也没有关联商户号，**When** 查询联营商列表，**Then** `agreementStatus` 为空且 `agreementStatusStr` 为 `未开启`。
3. **Given** `organization_ids='12'` 且联营商 id 为 `2`，**When** 查询联营商列表，**Then** 不应误匹配该关联商户号。

### 用户故事 3 - 状态筛选基于最终选中的商户号状态（优先级：P1）

运营通过 `schoolQueryCondition.agreementStatus` 过滤联营商列表时，筛选结果必须与列表最终展示的状态一致。系统不应先用关联商户号命中过滤条件，再展示自己的不同状态。

**独立测试**：准备一个联营商，自己的商户号处于 `步骤1`，关联商户号处于 `签约完成`。分别用列表状态筛选值 `1` 和 `4` 查询，验证该联营商只出现在 `步骤1` 的结果中。

**验收场景**：

1. **Given** 最终选中状态为 `未开启`，**When** `agreementStatus=0` 查询，**Then** 该联营商出现在结果中。
2. **Given** 最终选中状态为 `步骤1`，**When** `agreementStatus=1` 查询，**Then** 该联营商出现在结果中。
3. **Given** 最终选中状态为 `步骤2`，**When** `agreementStatus=2` 查询，**Then** 该联营商出现在结果中。
4. **Given** 最终选中状态为 `步骤3`，**When** `agreementStatus=3` 查询，**Then** 该联营商出现在结果中。
5. **Given** 最终选中状态为 `签约完成`，**When** `agreementStatus=4` 查询，**Then** 该联营商出现在结果中。
6. **Given** 自己的商户号和关联商户号状态不同，**When** 按关联商户号状态查询，**Then** 该联营商不应被筛出。

### 用户故事 4 - 分页结果不因多条商户号记录重复（优先级：P1）

联营商可能命中多条 `proj_member` 记录。列表应以联营商组织为分页主体，每个联营商只出现一次，避免 OR JOIN 造成重复记录和分页总数偏差。

**独立测试**：准备一个联营商，同时命中自己的商户号和多条关联商户号。调用列表接口，验证该联营商只返回一条，分页总数按联营商数量计算。

**验收场景**：

1. **Given** 同一联营商命中多条会员记录，**When** 查询列表，**Then** 该联营商在结果中只出现一次。
2. **Given** 同一优先级命中多条会员记录，**When** 查询列表，**Then** 取 `update_time` 最新的记录；`update_time` 相同或为空时取 `id` 最大的记录。
3. **Given** 多页查询，**When** 翻页查看联营商列表，**Then** 不应因为会员记录重复导致联营商跨页重复或总数异常。

### 用户故事 5 - 订单预下单商户状态校验兼容关联商户号（优先级：P1）

用户在联营商关联商户号场景下创建预下单二维码时，系统不应只检查学校上级联营商自己的商户号。若该联营商没有自己的可用商户号，但存在 `organization_ids` 关联到该联营商的可用商户号，应允许商户状态校验通过，避免订单侧报错 `商户号状态异常,schoolId=30475,message=通联账号未申请成功，请先确认。`

**独立测试**：准备一个学校 `schoolId`，其学校组织 `superId` 指向联营商；该联营商没有 `organization_id = superId` 的成功商户号，但存在一条 `organization_ids` 分隔符安全包含 `superId` 且法务审核、签约均成功的 `proj_member` 记录。调用 `GET /member/checkMemberState?schoolId=...`，验证返回成功；再通过 `ProjOrderServiceImpl#createQrCode` 预下单路径验证不再因该商户状态校验失败。

**验收场景**：

1. **Given** 学校存在上级联营商且该联营商自己的商户号可用，**When** 校验商户状态，**Then** 校验成功。
2. **Given** 联营商没有自己的可用商户号但存在关联可用商户号，**When** 校验商户状态，**Then** 校验成功。
3. **Given** 联营商自己的商户号存在但不可用，且关联商户号可用，**When** 校验商户状态，**Then** 按自己的商户号优先规则校验失败。
4. **Given** 联营商没有自己的商户号且关联商户号不存在或不可用，**When** 校验商户状态，**Then** 校验失败并保持提示 `通联账号未申请成功，请先确认`。
5. **Given** `organization_ids='12'` 且联营商 id 为 `2`，**When** 校验关联商户号，**Then** 不应误匹配该关联商户号。

## 参考 SQL 与状态规则

用户提供的参考 SQL：

```sql
SELECT b.*, a.*
FROM proj_organization a
LEFT JOIN proj_member b
ON a.id = b.organization_id
OR organization_ids is not null and LOCATE(CONCAT(a.id, ','), CONCAT(b.organization_ids, ',')) > 0
WHERE a.type = 2 and a.department_type = 2
```

后续实现应保留该关联意图，但关联匹配必须使用分隔符安全写法，等价于：

```sql
LOCATE(CONCAT(',', a.id, ','), CONCAT(',', b.organization_ids, ',')) > 0
```

`agreementStatusStr` 继续沿用当前 `OrganizationServiceImpl#getFranchiseeList` 的文案规则：

- `registrationStatus == null`：`未开启`
- `registrationStatus in (0,1,2)`：`步骤1`
- `registrationStatus == 3 && bindPhone 为空`：`步骤2`
- `bindPhone 非空 && agreementStatus in (0,1,2)`：`步骤3`
- `agreementStatus == 3`：`签约完成`

## 商户状态校验兼容规则

当前失败链路为：`ProjOrderServiceImpl#createQrCode` 在预下单前调用订单侧私有 `checkMemberState`，订单侧通过 `BaseClient#checkMemberState` 调用 base 的 `MemberController#checkMemberState`，最终进入 `MemberServiceImpl#checkMemberState`。

后续实现 `MemberServiceImpl#checkMemberState(schoolId)` 时，应保持入参、接口路径和返回结构不变，并按以下口径选择待校验商户号：

- 先通过 `schoolId` 获取学校组织，并取学校组织 `superId` 作为联营商组织 id；若学校不存在或没有 `superId`，仍按现有逻辑失败。
- 优先选择 `proj_member.organization_id = superId` 的商户号；只要自己的商户号存在，就按自己的商户号状态判断，不被关联商户号覆盖。
- 没有自己的商户号时，再选择 `organization_ids` 分隔符安全包含 `superId` 的关联商户号。
- 关联匹配必须使用分隔符安全写法，避免 `organization_ids='12'` 误匹配联营商 id `2`。
- 可用商户号标准保持现有逻辑不变：`legalAuditStatus == MemberLegalAuditStatusEnum.SUCCESS` 且 `agreementStatus == MemberAgreementStatusEnum.SUCCESS`。
- 校验失败提示保持现有文案 `通联账号未申请成功，请先确认`，订单侧日志仍可记录 `商户号状态异常,schoolId={},message={}`。

后续编码前还应排查其他商户状态、通联账号状态、`checkMemberState`、`organization_id` 单点校验位置；若同样服务于联营商关联业务场景，应使用相同的“自己的商户号优先、关联商户号兜底”口径。

## 边界情况

- 本规格最初文档阶段只要求文档；当前已进入实现阶段，业务代码变更应限定在联营商列表状态来源和商户状态校验关联兼容范围内。
- 本次商户状态校验增量已修改 `MemberServiceImpl.java`、`MemberService.java`、`SchoolController.java`；未修改 `MemberController.java`、`BaseClient.java`、`ProjOrderServiceImpl.java`。
- 接口仍为 `POST /school/getFranchiseeList`；请求仍为 `SchoolQueryCondition`；返回仍为 `Page<SchoolVo>`。
- 商户状态校验接口仍为 `GET /member/checkMemberState`；入参仍为 `schoolId`；订单侧 feign 调用和异常透传方式保持不变。
- `SchoolController#getFranchiseeList` 仍设置 `type=2` 和 `departmentType=2`。
- 联营商范围保持 `proj_organization.type = 2 AND proj_organization.department_type = 2`。
- 自己的商户号定义为 `proj_member.organization_id = proj_organization.id`。
- 关联商户号定义为 `proj_organization.id` 出现在 `proj_member.organization_ids` 英文逗号分隔列表中。
- 自己的商户号优先级高于关联商户号；只要自己的商户号存在，就不使用关联商户号状态。
- 同一优先级命中多条会员记录时，按 `update_time DESC, id DESC` 选一条。
- 无任何会员记录时，输出 `agreementStatus=null`、`registrationStatus=null`、`bindPhone=null`，并派生 `agreementStatusStr=未开启`。
- `schoolQueryCondition.agreementStatus` 是列表进度筛选值，沿用现有实际 SQL 行为：`0=未开启`、`1=步骤1`、`2=步骤2`、`3=步骤3`、`4=签约完成`。
- 状态筛选必须在最终选中的会员记录基础上判断，避免关联商户号影响自己的商户号筛选结果。
- 后续实现应避免 `SELECT *` 字段覆盖歧义，明确别名输出到 `SchoolVo` 需要的字段。
- 后续实现应保证分页主体是 `proj_organization` 联营商记录，而不是 `proj_member` 命中记录。
- 商户状态校验场景中，自己的商户号存在但法务审核或签约未成功时，应按失败处理，不应继续用关联商户号绕过失败。

## 需求 *(必填)*

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下维护本 Spec Kit 目录。
- **FR-002**：当前实现阶段 MUST 将业务代码修改限定在联营商列表状态来源和商户状态校验关联兼容范围内。
- **FR-003**：后续实现 MUST 保持 `POST /school/getFranchiseeList` 的接口路径、请求体和返回体不变。
- **FR-004**：后续实现 MUST 保持联营商查询范围为 `proj_organization.type = 2 AND proj_organization.department_type = 2`。
- **FR-005**：后续实现 MUST 优先使用 `proj_member.organization_id = proj_organization.id` 的商户号状态。
- **FR-006**：后续实现 MUST 在没有自己的商户号时，使用 `proj_member.organization_ids` 关联到该联营商的商户号状态。
- **FR-007**：后续实现 MUST 对 `organization_ids` 使用分隔符安全匹配，避免部分数字误匹配。
- **FR-008**：后续实现 MUST 保证每个联营商最多返回一条列表记录。
- **FR-009**：后续实现 MUST 在同一优先级命中多条会员记录时，按 `update_time DESC, id DESC` 取一条。
- **FR-010**：后续实现 MUST 基于最终选中的会员记录填充 `agreementStatus`、`registrationStatus` 和 `bindPhone`。
- **FR-011**：后续实现 MUST 基于最终选中的会员记录派生 `agreementStatusStr`。
- **FR-012**：后续实现 MUST 沿用现有 `agreementStatusStr` 文案：`未开启`、`步骤1`、`步骤2`、`步骤3`、`签约完成`。
- **FR-013**：后续实现 MUST 基于最终选中的会员记录执行 `schoolQueryCondition.agreementStatus` 过滤。
- **FR-014**：后续实现 MUST 保持 `schoolQueryCondition.agreementStatus` 的现有列表进度筛选语义：`0=未开启`、`1=步骤1`、`2=步骤2`、`3=步骤3`、`4=签约完成`。
- **FR-015**：后续实现 MUST NOT 新增 DTO 字段或修改数据库结构。
- **FR-016**：后续实现 SHOULD 避免 `SELECT *`，明确查询列和别名，降低 `proj_organization` 与 `proj_member` 同名字段覆盖风险。
- **FR-017**：后续实现 MUST 让 `MemberServiceImpl#checkMemberState(schoolId)` 兼容联营商关联商户号场景。
- **FR-018**：后续实现 MUST 保持 `GET /member/checkMemberState` 的接口路径、入参和返回结构不变。
- **FR-019**：后续实现 MUST 保持订单侧 `BaseClient#checkMemberState` 和 `ProjOrderServiceImpl#createQrCode` 的调用契约不变。
- **FR-020**：后续实现 MUST 通过 `schoolId` 找到学校组织，并以学校组织 `superId` 作为待校验联营商组织 id。
- **FR-021**：后续实现 MUST 在商户状态校验中优先使用 `proj_member.organization_id = superId` 的自己的商户号。
- **FR-022**：后续实现 MUST 在没有自己的商户号时，使用 `proj_member.organization_ids` 关联到 `superId` 的商户号兜底校验。
- **FR-023**：后续实现 MUST 对商户状态校验中的 `organization_ids` 使用分隔符安全匹配。
- **FR-024**：后续实现 MUST 保持可用商户号判断标准为法务审核成功且签约成功。
- **FR-025**：后续实现 MUST 保持商户状态校验失败提示 `通联账号未申请成功，请先确认`。
- **FR-026**：后续实现 SHOULD 排查其他商户状态、通联账号状态、`checkMemberState`、`organization_id` 单点校验位置，并对联营商关联场景采用一致兼容口径。

## 成功标准 *(必填)*

- **SC-001**：本目录包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：当前实现变更只包含相关 Spec Kit 文档变化和 `proj-two` 兼容改造代码变化，不包含无关业务改动。
- **SC-003**：规格明确自己的商户号状态优先于关联商户号状态。
- **SC-004**：规格明确没有自己的商户号时使用关联商户号状态兜底。
- **SC-005**：规格明确每个联营商只返回一条列表记录。
- **SC-006**：规格明确 `organization_ids` 必须使用分隔符安全匹配。
- **SC-007**：规格明确多条命中记录的稳定取值规则为 `update_time DESC, id DESC`。
- **SC-008**：规格明确 `agreementStatusStr` 文案规则保持当前行为。
- **SC-009**：规格明确筛选条件必须基于最终选中的会员记录。
- **SC-010**：后续实现后，`idc/base` 模块编译通过，并通过 Mapper 查询场景验证。
- **SC-011**：规格明确订单预下单前的商户状态校验也需要兼容联营商关联商户号。
- **SC-012**：规格明确 `MemberServiceImpl#checkMemberState` 的当前失败链路和后续实现口径。
- **SC-013**：规格明确自己的商户号存在但不可用时，不使用关联商户号绕过失败。
- **SC-014**：后续实现后，`idc/base` 与 `idc/order` 相关模块编译通过，并通过 `checkMemberState` 与订单预下单路径验证。

## 假设

- `proj_member.organization_ids` 是英文逗号分隔的组织 id 字符串。
- `proj_member.organization_id` 和 `proj_member.organization_ids` 可能同时命中同一个联营商。
- “自己的状态”指 `proj_member.organization_id = proj_organization.id` 的会员记录状态。
- “关联的商户号状态”指 `proj_organization.id` 出现在 `proj_member.organization_ids` 中的会员记录状态。
- 当前列表进度筛选值沿用现有 `OrganizationMapper#getFranchiseeList` 的实际 0 到 4 语义，而不是 `MemberAgreementStatusEnum` 的 0 到 3 枚举语义。
- 后续编码范围优先限定在 `OrganizationMapper#getFranchiseeList`；必要时调整 `OrganizationServiceImpl#getFranchiseeList` 的状态文案派生和去重保护。
- 商户状态校验增量的后续编码范围优先限定在 `MemberServiceImpl#checkMemberState`；只有排查确认其他校验点也影响联营商关联场景时，才同步调整对应位置。
