# 任务清单：common_warn_sender 支持 FX_002 私域变量与“请勿打扰”打标

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充关键行为对应测试，尤其是下游 HTTP 请求体和 tag 查询条件。

## Phase 1：代码事实确认

- [x] T001 确认 `common_warn_sender` 入口为 `AppTask.handleRequest(CommonWarnSenderInput, Context)`。
- [x] T002 确认 `CommonWarnSenderInput` 字段为 `external_key/sendTemplateList/templateVariable/appendJumpLink`。
- [x] T003 确认私域 key 格式参考 `external-info-select`：`private-domain:agentId:externalUserId:userId:env`。
- [x] T004 确认 `getEmpExternalUserDO` 返回 `EmpExternalUserDO`，包含 `name/unionId/empId/source/externalUserid`。
- [x] T005 确认 `markAsync` 请求 DTO 为 `QwExternalTagMarkInput`，JSON 字段为 `external_user_id/user_id/union_id/source/add_tag_list/remove_tag_list`。
- [x] T006 确认 `drh_qw_tag` 实体 `QwTagDO` 字段包含 `tagId/name/source/isDel`。

## Phase 2：风险门禁

- [x] T007 检查 `unionId` 空值风险：上游必须阻止空 `unionId` 的 FX_002 打标提交。
- [x] T008 检查 `user_id` 来源：不能使用私域 key 第 4 段，必须通过 `empId -> KkEmpDto.qyvxUserId`。
- [x] T009 检查 `tagId` 来源：按 `source + name='请勿打扰' + is_del=0` 查询，不硬编码。
- [x] T010 检查调用顺序：解析 key、补上下文、渲染发送、FX_002 附加打标。
- [x] T011 测试映射覆盖模板变量优先级、私域 key 解析、FX_002 固定飞书 ID、tag 查询条件、`markAsync` 请求体和失败不阻断。

## Phase 3：实现

- [x] T012 在 `ai-common` 新增 `QwTagNameQueryInput` 和 `QwTagOutput`。
- [x] T013 在 `kkhc-idc-ai` 新增 tag 查询 service 和 `QwTagController#getByName`。
- [x] T014 扩展 `common_warn_sender` 的外部联系人 DTO，支持 `unionId/empId/source/externalUserid`。
- [x] T015 在 `common_warn_sender` 支持私域 key 解析并保持 legacy 兼容。
- [x] T016 调整模板变量构建，确保 `templateVariable.unionId/userName` 优先，缺失时用接口返回补齐。
- [x] T017 实现 `FX_002` best-effort 打“请勿打扰”标签逻辑。
- [x] T018 实现 `FX_002` 飞书接收人固定为 `ed27a7bb`。
- [x] T019 更新执行记录，说明影响范围和剩余风险。

## Phase 4：测试与验证

- [x] T020 增加 `common_warn_sender` 单测，覆盖变量优先级和私域解析。
- [x] T021 增加 `common_warn_sender` 单测，覆盖 FX_002 固定飞书 ID、tag 查询和 `markAsync` 请求体。
- [x] T022 增加 `kkhc-idc-ai` 单测或静态验证，确认 tag 查询条件。
- [x] T023 运行 `common_warn_sender` 模块测试或编译。
- [x] T024 运行 `kkhc-idc-ai` 的 `ai` 模块相关测试或编译。
- [x] T025 搜索确认旧标签名未残留在本需求实现中。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- 验证方式：代码阅读确认入口、DTO、私域 key 格式、tag 查询实体和 `markAsync` 参数。
- 自检结论：已满足参数完整性门禁，进入实现。

### D002 - 实现记录

- 实现内容：新增 `QwTagNameQueryInput/QwTagOutput`、`QwTagQueryService` 和 `QwTagController#getByName`；`common_warn_sender` 支持私域 `external_key`、变量补齐、`FX_002` 固定飞书 ID `ed27a7bb`、按 `source + name='请勿打扰'` 查询 tagId 后 best-effort 调用 `markAsync`。
- 测试命令：`mvn -pl common_warn_sender "-DskipTests=false" "-Dmaven.test.skip=false" "-Dtest=AppTaskTest" test`；`mvn -pl ai -am "-Dtest=QwTagQueryServiceImplTest" test`。
- 测试结果：`common_warn_sender` 8 tests passed，`kkhc-idc-ai ai` 2 tests passed，两个命令均 `BUILD SUCCESS`。
- 自检结论：模板变量优先级、私域 key 解析、`FX_002` 固定飞书 ID、tag 查询条件和 `markAsync` 请求体已覆盖；打标缺少必要上下文或异常时仅记录 detail，不阻断发送；非 `FX_002` 不打标。
