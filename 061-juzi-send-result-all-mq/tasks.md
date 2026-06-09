# 任务清单：sendResult 新增 juzi_all MQ 分发

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充编译验证和关键配置/调用点静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前目标为 `data-RC\juzi` 的 sendResult 回调链路。
- [x] T002 用代码搜索确认入口为 `CallbackController.msgCallbackMessageResult`，核心发送实现为 `JuziMessageServiceImpl.sendMq`。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
- [x] T004 确认配置来源为 `JuziConfig`、`MqConfig` 和 Nacos `juzi-config`，MQ 发送使用 Aliyun ONS `ProducerBean`。
- [x] T005 确认旧逻辑必须保持：`juzi.flag` 分支、异步线程、MDC 恢复、`extras` 截断、OSS 上传、原 self 分流发送。

**检查点**：T001-T005 已完成，可以进入实现。

## Phase 2：风险门禁

- [x] T006 检查是否存在新增 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参；结论：本次不新增。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段；结论：新增发送在现有字段处理后执行。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源；结论：all 发送只读取 topic/tag/body，self 字段只由旧发送读取。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为；结论：只新增额外 MQ 发送和 producer bean，不改变接口契约和 body。
- [x] T010 对需要用户确认的业务语义变化做记录；结论：用户已明确 all tag、默认关闭和测试/生产 group/tag。
- [x] T011 为关键行为建立测试映射：默认关闭、开关打开 all tag、不区分 self、旧发送保持、编译验证。

**检查点**：T006-T011 已完成。

## Phase 3：实现

- [x] T012 在 `JuziConfig` 新增 `sendResultAllMqEnabled`，默认 `false`。
- [x] T013 在 `MqConfig` 新增 `juzi_all_group` 和 `juzi_all_tag` 默认值。
- [x] T014 在 `ProduceClient` 新增携带 `PropertyKeyConst.GROUP_ID` 的 all producer bean。
- [x] T015 在 `JuziMessageService` 和实现类新增不走 self 分流的 all 发送方法。
- [x] T016 在 `CallbackController.msgCallbackMessageResult` 原发送后按开关调用 all 发送方法。
- [x] T017 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [x] T018 运行目标模块编译命令并记录结果。
- [x] T019 搜索确认新增开关、group/tag 默认值、all 发送调用点和不区分 self 的实现。
- [x] T020 验证默认关闭逻辑使用 `Boolean.TRUE.equals(...)`，避免配置缺失时误发。
- [x] T021 复查 `CallbackController` 旧逻辑没有被移除或改写。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `061-juzi-send-result-all-mq` 规格文档，记录新增 all MQ 的参数来源、开关默认值、旧逻辑保持和测试映射。
- 验证方式：阅读 `CallbackController`、`JuziMessageServiceImpl`、`JuziConfig`、`MqConfig`、`ProduceClient` 和 Spec Kit 模板。
- 自检结论：满足实现前强制门禁。

### D002 - 实现记录

- 实现内容：新增 `sendResultAllMqEnabled` 开关、all group/tag 配置、`juziAllProducerBean`、`sendJuziAllMq` 和 controller 开关调用；新增 `JuziMessageServiceImplTest` 验证 all 发送不解析 self 字段。
- 测试命令：`mvn -pl juzi -am compile`；`mvn -pl juzi "-Dskip=false" "-DskipTests=false" "-Dmaven.test.skip=false" "-Dtest=JuziMessageServiceImplTest" test`；手动 `JUnitCore` 执行 `JuziMessageServiceImplTest`。
- 测试结果：编译 BUILD SUCCESS；Maven test 受 surefire `<skip>true</skip>` 影响仍跳过执行但测试编译成功；手动 `JUnitCore` 输出 `OK (1 test)`。
- 自检结论：参数来源、调用顺序、默认关闭和旧逻辑保持均满足规格；测试环境 group/tag 需由 Nacos 覆盖为用户指定值。
