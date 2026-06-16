# 任务清单：AI 用户画像聚合查询接口

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [ ] T001 复查需求与 `AGENTS.md`，确认涉及两个项目：`kkhc/kkhc-idc/ai`（后端）与 `coze_plugin/external-info-select`（私域调用方）。
- [ ] T002 确认入口与调用链：`AiController`（`@RequestMapping("ai")`，`BaseResponse<T>`）；coze `AppTask.handleRequest` → `isPrivateDomainExternalKey`/`parsePrivateDomainExternalKey`/`buildPrivateDomainUserInfo`。
- [ ] T003 确认实体/服务字段：`CollectOrderDO(union_id/collect_pay_status/price)`、`LiveCampDO(is_class/emp_id/group_id/is_del)`、`LiveCampDateDO(camp_id/class_time)`、`KkEmpDo(name)`、`GroupLiveDO(group_id/speaker_id/is_del)`、`SpeakerDO(name)`、`LiveUserDO(union_id/phone/id)`、`EmpExternalUserDO(external_userid/union_id)`、`BookQuestionRecordDO/ExternalBookQuestionRecordDO(sign_status/l_ids/l_id/aes_id/type/goods_id/phone/create_time)`、`GoodsDO(name)`。
- [ ] T004 确认配置/外部调用：kapi `KapiConfig.domain`、OSS `OssConfig/OssUtil`（ai 模块已接入）、ShowAPI `BookLogisticsConfig` appKey、Redis 访问方式与新 key/TTL、coze `sys_domain`+`token=projoikshhfucgshajgfyfjf`。
- [ ] T005 确认必须保持不变的旧逻辑：`AiServiceImpl` 物流签收定时处理与实时 ShowAPI 行为、coze 非私域分支与 `setTushu`/`buildPrivateDomainUserInfo` 原字段与异常处理。

### Phase 1 待核实项（编码前确认）

- [ ] V1 kapi `endpoint/qr/code/v2` 响应结构：base64 字段名、是否含 `data:image/...;base64,` 前缀（无现存调用方，需实测/确认）。
- [ ] V2 `drh_live_camp_user` 实体类名与字段（`user_id`/`live_camp_id`），确认体验课学员挂此表。
- [ ] V3 `live_user.phone` 是否明文（ShowAPI 需手机号后 4 位）；解析失败兜底（book 记录自带 phone）。
- [ ] V4 `GroupLiveDO` 表名/字段（`group_id/speaker_id/is_del`）与 `SpeakerDO.name`。
- [ ] V5 模块内 Redis 访问方式（RedisTemplate/已有 util）与新 key 命名/TTL。
- [ ] V6 正价课"最近一个营期"排序口径（`live_camp.create_time desc` 还是 `permission.create_time desc`）。
- [ ] V7 coze 私域分支合并 4 个子对象的位置；新接口响应统一为 `BaseResponse{code,message,data}`，coze 取 `data`。

**检查点**：不得在未完成 T001-T005 与 V1-V7 前进入实现。

## Phase 2：风险门禁

- [ ] T006 检查无 `new XxxDto()`/空 JSON/空 Map 占位下传；查不到给默认值。
- [ ] T007 检查无调用后赋值：`unionId` 先于子查询解析；`campId` 先于营期日期/主讲/courseLink；`phone` 先于物流与 ShowAPI。
- [ ] T008 检查每个下游字段有来源或现算（见 spec 下游字段清单）。
- [ ] T009 评估方案是否改契约/调用顺序/Redis/HTTP：新增端点 + 新增 Redis 缓存 key + coze 新增一处后端 HTTP 调用，均已在文档记录。
- [ ] T010 业务语义变化已确认（4 项设计选择 + 私域接入）。
- [ ] T011 建立测试映射：payStatus、体验课最近营期、正价课最近营期+顿号拼接+classTime 来源、物流混合状态、kapi+OSS+缓存、externalUserId→unionId、私域合并与异常降级。

**检查点**：T006-T011 必须有明确结论；高风险先更新 spec 的"历史问题防漏分析"。

## Phase 3：实现

- [ ] T012 后端：`AiUserPortraitInput/Output`（含 4 子 DTO）、`AiUserPortraitService(+Impl)`、`AiController.userPortrait`、`BookLogisticsApiClient` 抽取、`LinkDomainConfig`、mapper（体验课最近营期/正价课最近营期/营期组主讲）。
- [ ] T013 保持 `AiServiceImpl` 实时物流与定时处理、coze 非私域行为不变。
- [ ] T014 为 CollectOrder 条件、kapi 请求体、OSS 上传入参、物流状态映射、缓存命中、externalUserId 解析增加可断言点。
- [ ] T015 coze：`AppTask` 私域分支调用新接口并合并 4 个子对象；同步更新 spec/tasks/AGENTS。

## Phase 4：测试与验证

- [ ] T016 新增 `AiUserPortraitServiceTest`（mock 各 service/kapi/OSS/ShowAPI/Redis）。
- [ ] T017 断言下游参数内容，不只断言最终结果。
- [ ] T018 验证边界（无订单/无营期/无物流/未发货/已签收不调 ShowAPI/缓存命中不重复调用）与旧逻辑不回归。
- [ ] T019 运行 `mvn -pl ai-common -am install`、`mvn -pl ai -am install`、`mvn -pl ai test -Dtest=AiUserPortraitServiceTest`；coze 模块 `mvn -q -DskipTests package`，记录结果。
- [ ] T020 搜索确认无残留旧调用/旧字段；coze 非私域路径未改动。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 090 规格文档（AGENTS/spec/tasks/checklist）。
- 验证方式：核对 086/089 已填写风格；列出 Phase 1 待核实项 V1-V7。
- 自检结论：满足强制门禁；编码前需完成 V1-V7。

### D002 - 实现记录

- 代码改动：见 `spec.md` D002（ai-common DTO、ai mapper/service/controller、coze AppTask 私域分支）。
- 测试命令：`mvn -s settings.xml -o -pl ai -am test -Dtest=AiUserPortraitServiceImplTest`；coze `mvn -o -pl external-info-select -am compile`。
- 测试结果：`AiUserPortraitServiceImplTest` Tests run: 16, Failures: 0, Errors: 0；ai test-compile 通过；coze compile 通过。
- 自检结论：下游断言覆盖物流状态映射（未发货/运输中/已签收，持久化+实时）、顿号拼接、classTime 格式、物流单号解析、物流链接域名、kapi 请求体 `{type:1,id:campId}`、OSS 路径、courseLink 缓存命中不再调 kapi/OSS、externalUserId→unionId 解析。
- V1（kapi 响应字段）见 spec.md D004，待联调确认；`hasDeliveredOrder` 拼写已按用户确认更正。

### D003 - 实时物流复用而非抽取

- 见 `spec.md` D003：`AiUserPortraitServiceImpl` 同包复用 `AiServiceImpl.queryBookLogisticsDetail`，`AiServiceImpl` 零改动。
- 文档同步：spec/tasks/AGENTS 已更新。
- 验证结果：单测通过；`AiServiceImpl` 未改动。
