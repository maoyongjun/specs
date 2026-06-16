# 任务清单：sendJuziAllMq 保留完整 extras

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段补充 controller 单元测试，断言两个 MQ body 的 `payload.extras` 内容。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标为 `data-RC\juzi` 的 sendResult 回调链路。
- [x] T002 用代码搜索确认入口为 `CallbackController.msgCallbackMessageResult`，相关调用点为 `juziMessageService.sendMq` 和 `juziMessageService.sendJuziAllMq`。
- [x] T003 确认关键参数来源：`msg` 来自请求体，`payload.extras` 来自请求体，`requestId` 来自 MDC，all MQ 开关来自 `JuziConfig`。
- [x] T004 确认配置、Redis、数据库、Feign/FC 不受影响；仅涉及 MQ body 内容。
- [x] T005 确认旧逻辑必须保持：异步线程、MDC、`juzi.flag`、OSS 上传、`extras` 截断、sendResult 日志、原 MQ 发送、all MQ 开关和过滤。

**检查点**：T001-T005 已完成，可以进入实现。

## Phase 2：风险门禁

- [x] T006 检查是否存在新增 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参；结论：本次不新增。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段；结论：需要避免先截断再生成 all MQ body。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源；结论：`requestId` 和原始 `payload.extras` 在生成 all MQ body 前均已确定。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ topic/tag、Redis TTL、数据库写入或异步行为；结论：只改变 all MQ body 中 `payload.extras` 的保留方式。
- [x] T010 对需要用户确认的业务语义变化做记录；结论：用户已明确 all MQ 不清空/截断 `extras`。
- [x] T011 为关键行为建立测试映射：原 MQ 截断、all MQ 完整、过滤不回归、编译/单测验证。

**检查点**：T006-T011 已完成。

## Phase 3：实现

- [x] T012 在 `CallbackController.msgCallbackMessageResult` 中，在 `payload.extras` 截断前判断 all MQ 是否需要发送并生成独立 body。
- [x] T013 保持 `payloadObj.put("extras", extrasValue.substring(0, 50)+"...")` 对原 `msg` 的截断逻辑不变。
- [x] T014 保持 `sendMq` 先发送、`sendJuziAllMq` 后发送的顺序不变。
- [x] T015 补充 controller 单元测试，使用同步线程池和 fake service 断言两个 MQ body。
- [x] T016 同步更新 `spec.md`、`tasks.md`、checklist 中的实现记录和验证结果。

## Phase 4：测试与验证

- [x] T017 运行指定 controller 测试，确认新增行为通过。
- [x] T018 运行已有 service/all MQ 相关测试，确认过滤和 all tag 行为不回归。
- [x] T019 运行目标模块编译或可行的 Maven 测试命令，并记录结果。
- [x] T020 搜索确认 `sendJuziAllMq` 不再复用截断后的 `sendResultMessage`。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `095-juzi-all-mq-full-extras` 规格文档，记录新增 all MQ 完整 `extras` 的参数来源、调用顺序、旧逻辑保持和测试映射。
- 验证方式：阅读 `CallbackController`、`JuziConfig`、`JuziMessageService`、现有 `CallbackControllerTest` 和 Spec Kit 模板。
- 自检结论：满足实现前强制门禁。

### D002 - 实现记录

- 实现内容：`CallbackController.msgCallbackMessageResult` 在截断 `payload.extras` 前生成 all MQ 专用 `sendJuziAllMessage`，原 MQ 继续在截断后生成 `sendResultMessage`；新增 `CallbackControllerTest.sendResultAllMqKeepsOriginalExtrasWhenNormalMqTruncates`，用同步线程池和 fake service 捕获两个 MQ body。
- 测试命令：`mvn -pl juzi "-Dskip=false" "-DskipTests=false" "-Dmaven.test.skip=false" "-Dtest=CallbackControllerTest,JuziMessageServiceImplTest" test`；`mvn -pl juzi "-Dmdep.outputFile=juzi\target\test-classpath.txt" "-Dmdep.includeScope=test" dependency:build-classpath`；`java -cp "<juzi\target\test-classes>;<juzi\target\classes>;<test classpath>" org.junit.runner.JUnitCore com.drh.data.juzi.controller.CallbackControllerTest com.drh.data.juzi.service.impl.JuziMessageServiceImplTest`。
- 测试结果：Maven `test` 编译成功但 surefire 因 `<skip>true</skip>` 跳过执行；手动 `JUnitCore` 输出 `OK (6 tests)`。
- 自检结论：all MQ body 保留完整 `payload.extras`；原 MQ body 仍按 `substring(0, 50)+"..."` 截断；all MQ 开关/过滤、发送顺序、OSS 上传、日志和接口响应保持不变。

### D003 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
