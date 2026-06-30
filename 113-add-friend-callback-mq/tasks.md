# 任务清单：添加好友回调发送 MQ 新 Tag

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于 `data-RC/juzi` 模块和 `CallbackController` 回调链路。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和测试落点：`CallbackController`、`JuziConfig`、`MqConfig`、`JuziMessageService`、`JuziMessageServiceImpl`、`CallbackControllerTest`、`JuziMessageServiceImplTest`。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型：添加好友字段来源为请求体 `JSONObject`，开关来源为 `JuziConfig`，tag 来源为 `MqConfig`。
- [x] T004 确认配置来源、环境变量、Redis key、MQ topic/tag、Feign/FC/HTTP 调用或数据库表是否受影响：只影响 `juzi` 和 `mq` 配置绑定及 MQ topic/tag 发布，不涉及 Redis、Feign、FC、数据库。
- [x] T005 确认已有旧逻辑中必须保持不变的过滤、幂等、异常处理、日志、延迟和 fallback：保留现有 message/sendResult 分支和 `sendMq` 自己/客户 tag 判断。

**检查点**：T001-T005 已完成，代码事实支持进入实现设计。

## Phase 2：风险门禁

- [x] T006 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参：新增路径不创建 DTO，占位风险低；空请求体按原始 JSON 处理。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段：新增路径发送前生成 body，不依赖后续补齐。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用：开关、topic、tag、body 均在发送前读取。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为：新增 HTTP 入口和新 MQ tag；不改旧入口和旧 MQ body。
- [x] T010 对需要用户确认的业务语义变化做记录；未确认前不得实现该变化：待确认新增路径 `/callback/msg/callback/addFriend` 和默认 tag `juzi_add_friend`。
- [x] T011 为每个关键行为建立测试映射，至少覆盖正常路径、边界路径和不回归路径：映射到 `CallbackControllerTest` 和 `JuziMessageServiceImplTest`。

**检查点**：T006-T011 已有明确结论；无高风险调用顺序问题。

## Phase 3：实现

- [x] T012 在 `JuziConfig` 增加 `addFriendMqEnabled=false`。
- [x] T013 在 `MqConfig` 增加添加好友 MQ group/tag 默认值。
- [x] T014 在 `ProduceClient` 增加添加好友 producer bean，或按最终实现复用明确的 producer。
- [x] T015 在 `JuziMessageService` / `JuziMessageServiceImpl` 增加添加好友 MQ 发送方法。
- [x] T016 在 `CallbackController` 增加添加好友回调入口，开关开启时发送 MQ。

## Phase 4：测试与验证

- [x] T017 更新 `CallbackControllerTest`，覆盖开关关闭不发送、开关开启发送原始 body。
- [x] T018 更新 `JuziMessageServiceImplTest`，覆盖新方法使用新增 tag 且不解析 self 字段。
- [x] T019 运行目标测试或编译命令，并记录结果。
- [x] T020 搜索确认没有残留旧调用、旧字段、旧口径。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `113-add-friend-callback-mq` 规格文档，并完成 Phase 1 / Phase 2 门禁。
- 验证方式：读取 `CallbackController`、`JuziConfig`、`MqConfig`、`JuziMessageService`、`JuziMessageServiceImpl`、`ProduceClient` 和现有测试。
- 自检结论：参数来源、调用顺序、旧逻辑保持和测试映射已明确；用户已确认并已完成实现。

### D002 - 实现记录

- 实现内容：新增 `addFriendMqEnabled` 开关、添加好友 MQ group/tag、独立 producer、`sendJuziAddFriendMq` 和 `POST /callback/msg/callback/addFriend`；补充 controller/service 测试。
- 测试命令：
  - `mvn -pl juzi "-Dtest=CallbackControllerTest,JuziMessageServiceImplTest" "-DskipTests=false" test`
  - `java -cp <juzi target test/classes + dependencies> org.junit.runner.JUnitCore com.drh.data.juzi.controller.CallbackControllerTest com.drh.data.juzi.service.impl.JuziMessageServiceImplTest`
- 测试结果：Maven 编译成功；Maven surefire 因 `pom.xml` `<skip>true</skip>` 跳过测试；JUnitCore 实际执行结果 `OK (9 tests)`。
- 自检结论：参数来源、调用顺序、新 MQ tag、默认关闭、开启发送和旧逻辑不回归均已覆盖；无剩余实现风险。
