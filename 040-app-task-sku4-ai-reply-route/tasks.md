# 任务清单：skuId=4 隔天消息分流到 ai-reply

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：通过 `rocket-mq-consumer` 模块单元测试验证，不真实调用 FC。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标为 `fc/rocket-mq-consumer`。
- [x] T002 确认真实入口为 `com.drh.mq.service.AppTask#handleRequest`。
- [x] T003 确认关键参数来源：`body` 来自 MQ 事件；`sku_id` / `skuId` 来自 `body`；函数名在 FC 调用前解析。
- [x] T004 确认配置来源：非 4 分支使用环境变量 `function_name`；serviceName 固定 `ai-service`。
- [x] T005 确认旧逻辑保持：非 4 默认路由、异步 FC 调用、原始 taskObj 下传保持不变。

**检查点**：T001-T005 已完成。

## Phase 2：风险门禁

- [x] T006 不新增空 DTO、空 Map 或空 JSON 作为有效输入。
- [x] T007 `sku_id` 兼容补齐和函数名解析均发生在 FC 调用前。
- [x] T008 下游 `ai-reply` 读取字段由原始 body 提供，样例格式兼容 `EmpExternalDto`。
- [x] T009 本方案只改变 FC functionName 选择，不改 MQ/Redis/OTS/数据库。
- [x] T010 无需额外用户确认的业务语义变化。
- [x] T011 测试映射覆盖 ai-reply 分支、兼容字段分支、默认路由分支和 body 字符串解析。

**检查点**：风险门禁已完成。

## Phase 3：实现

- [x] T012 在 `AppTask` 中实现 `sku_id` / `skuId` 路由判断。
- [x] T013 抽出 `resolveFunctionName`、`resolveSkuId`、`invokeFc` 测试 seam。
- [x] T014 兼容 `body` 为 JSON object 或 JSON string。
- [x] T015 同步更新执行记录。

## Phase 4：测试与验证

- [x] T016 新增 `AppTaskTest` 覆盖 `sku_id:"4"` 路由到 `ai-reply`。
- [x] T017 新增 `AppTaskTest` 覆盖 `skuId:4` 兼容补齐 `sku_id`。
- [x] T018 新增 `AppTaskTest` 覆盖非 4 和缺失 sku 默认路由。
- [x] T019 运行 `mvn -pl rocket-mq-consumer -am "-Dtest=AppTaskTest,UserLevelUpdateTaskTest" "-Dsurefire.failIfNoSpecifiedTests=false" test` 并记录结果。
- [x] T020 搜索确认无残留错误函数名或未覆盖旧路由口径。

## 执行记录

### D001 - 文档记录

- 执行内容：创建规格文档、任务清单和要求检查清单。
- 验证方式：代码搜索和静态确认。
- 自检结论：参数来源、调用顺序、兼容格式和测试映射已记录。

### D002 - 实现记录

- 实现内容：`AppTask` 按 `sku_id` / `skuId` 选择函数名，`4` 分流 `ai-reply`，非 4 保持默认 `function_name`；兼容字符串 body；为 `skuId` 分支补齐 `sku_id`；新增 FC 调用参数断言测试。
- 测试命令：
  - `mvn -pl rocket-mq-consumer -am "-Dtest=AppTaskTest,UserLevelUpdateTaskTest" test` 首次因 `common` 无指定测试匹配失败。
  - `mvn -pl rocket-mq-consumer -am "-Dtest=AppTaskTest,UserLevelUpdateTaskTest" "-Dsurefire.failIfNoSpecifiedTests=false" test` 复跑通过。
- 测试结果：BUILD SUCCESS；`AppTaskTest` 5 条通过，`UserLevelUpdateTaskTest` 4 条通过，总计 9 条通过。
- 自检结论：参数来源和调用顺序符合门禁；未改变 MQ、Redis、OTS、数据库或 `ai-reply` 内部逻辑；`dependency-reduced-pom.xml` 存在既有 dirty diff，未处理。
