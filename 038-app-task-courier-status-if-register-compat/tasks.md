# 任务清单：AppTask 物流注册态兼容与已填写打标限流

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段补充 AppTask 返回字段测试和 AiServiceImpl 限流测试。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标项目为 `coze_plugin/external-info-select` 与 `kkhc-idc/ai`。
- [x] T002 用代码搜索确认入口：`AppTask.handleRequest`、`AppTask#setTushu`、`AiServiceImpl.compensateWriteOverTagIfNeeded`。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
- [x] T004 确认本次不新增配置、Redis TTL、MQ、数据库或远程接口。
- [x] T005 确认旧逻辑中必须保持不变的标签识别、物流查询、FC 入参、异常处理和日志。

## Phase 2：风险门禁

- [x] T006 未新增空 DTO、空 JSON 或空 Map 作为下游参数。
- [x] T007 `if_register` 补偿已安排在 `DayEnum.createCozeJson` 前，避免调用后赋值风险。
- [x] T008 `invokeFc` 所需字段仍来自原有上下文和 `QwAutoTag` 查询。
- [x] T009 本次仅新增限流 wrapper，不改变接口契约、FC taskObj、MQ 或数据库写入。
- [x] T010 用户已确认业务语义：`courier_status=是` 可视为已填写返回态补偿触发条件。
- [x] T011 建立测试映射：AppTask 正常/边界/返回字段，AiServiceImpl 限流/跳过/函数名回归。

## Phase 3：实现

- [x] T012 按规格实现最小范围改动。
- [x] T013 保持未声明的旧行为不变。
- [x] T014 对打标限流 Redis key 和调用路径增加可测试断言点。
- [x] T015 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 和 checklist。

## Phase 4：测试与验证

- [x] T016 新增 `AppTaskCourierStatusRegisterCompatTest`。
- [x] T017 更新 `AiServiceImplLogisticsTagCompensationTest`，覆盖限流 key 和跳过路径。
- [x] T018 验证边界情况和旧函数名选择不回归。
- [x] T019 运行目标模块测试或编译命令，并记录结果。
- [x] T020 搜索确认没有残留旧调用或旧口径。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 Spec Kit 文档并完成门禁分析。
- 验证方式：静态阅读 `AppTask`、`AiServiceImpl`、`RateLimitUtil` 和目标测试类。
- 自检结论：满足实现前门禁。

### D002 - 实现记录

- 实现内容：`AppTask` 增加物流状态补偿注册态；`AiServiceImpl` 增加打标限流 wrapper。
- 测试命令：
  - `mvn -pl external-info-select "-Dmaven.test.skip=false" "-DskipTests=false" "-Dtest=AppTaskCourierStatusRegisterCompatTest,AppTaskPrivateDomainTest" "-Dsurefire.failIfNoSpecifiedTests=false" test`
  - `mvn -pl external-info-select -am -DskipTests compile`
  - `mvn -pl ai -am "-Dtest=AiServiceImplLogisticsTagCompensationTest" "-DfailIfNoTests=false" "-Dsurefire.failIfNoSpecifiedTests=false" test`
  - `mvn -pl ai -am -DskipTests compile`
- 测试结果：
  - `external-info-select` 测试通过，`12` 个用例全部通过。
  - `external-info-select` 编译通过。
  - `kkhc-idc/ai` 限流测试通过，`6` 个用例全部通过。
  - `kkhc-idc/ai` 编译通过。
- 自检结论：`AppTask` 补偿点位于 `DayEnum.createCozeJson` 前；“已填写”补偿打标已使用独立 Redis key 限流；旧标签识别、物流查询、FC taskObj 和异常边界保持不变。
