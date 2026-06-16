# 功能规格：sendJuziAllMq 保留完整 extras

**功能目录**：`095-juzi-all-mq-full-extras`  
**创建日期**：`2026-06-16`  
**状态**：Implemented  
**输入**：用户要求修改 `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\controller\CallbackController.java`：如果要发送 `sendJuziAllMq`，不用清空/截断 `extras`；其他保持 `payloadObj.put("extras", extrasValue.substring(0, 50)+"...");`。

## 背景

- 当前问题：`msgCallbackMessageResult` 在生成 MQ body 前会直接修改 `msg.payload.extras`，导致原 `sendMq` 和新增 `sendJuziAllMq` 都拿到截断后的 `extras`。
- 当前行为：`payload.extras` 超过 200 字符时，先按 `Dong` 上传 OSS，再执行 `payloadObj.put("extras", extrasValue.substring(0, 50)+"...")`；随后 `sendMq(sendResultMessage)` 与 `sendJuziAllMq(sendResultMessage)` 共用同一个截断后的字符串。
- 目标行为：当 all MQ 开关开启且过滤通过时，`sendJuziAllMq` 使用截断前的消息体，保留完整 `payload.extras`；原 MQ、日志和截断逻辑仍使用截断后的消息体。
- 非目标：不修改 `sendJuziAllMq` 的 topic/tag/group；不修改 all MQ 过滤条件；不修改 `extras` 超 200 的判断阈值、截断长度或 OSS 上传条件；不修改接口响应。

## 用户场景与测试 *(必填)*

### 用户故事 1 - all MQ 接收完整 extras（优先级：P1）

下游订阅 `juzi_all` 需要完整 `payload.extras` 进行处理，因此不能再复用原 MQ 的截断后 body。

**独立测试**：构造 `payload.extras` 长度大于 200 的 sendResult 回调，设置 `juzi.flag=false` 且 `sendResultAllMqEnabled=true`，用同步线程池执行 controller，断言 `sendMq` 收到截断后的 `extras`，`sendJuziAllMq` 收到完整 `extras`。

**验收场景**：

1. **Given** `payload.extras` 长度大于 200 且 all MQ 开关打开，**When** `msgCallbackMessageResult` 处理回调，**Then** `sendJuziAllMq` body 中的 `payload.extras` 等于请求原值。
2. **Given** `payload.extras` 长度大于 200 且 all MQ 开关打开，**When** 原 MQ 发送执行，**Then** `sendMq` body 中的 `payload.extras` 仍为前 50 字符加 `...`。

### 用户故事 2 - 旧过滤和旧截断不回归（优先级：P1）

这次只修正 all MQ body 的 `extras`，不能改变 sendResult 的既有过滤、日志、OSS 上传和原 MQ 发送行为。

**独立测试**：复用已有 `shouldSendJuziAllMq` 测试覆盖 `roomTopic` 和 `externalUserId` 过滤；新增测试只在过滤通过时断言 all MQ body。

**验收场景**：

1. **Given** all MQ 过滤不通过，**When** 回调处理，**Then** 不调用 `sendJuziAllMq`。
2. **Given** `payload.extras` 不超过 200 或为空，**When** 回调处理，**Then** 原 MQ 与 all MQ 均保持原始 `extras`。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `msg`：来源 `CallbackController.msgCallbackMessageResult(@RequestBody JSONObject msg)`；异步线程内复用；下游为 `sendMq` 和 `sendJuziAllMq`。
  - `requestId`：来源 `MDC.get("requestId")`；在异步线程内、生成任一 MQ body 前写入 `msg`。
  - `payload.extras`：来源请求体 `payload.extras`；如果长度大于 200，原 MQ body 生成前被截断；all MQ body 必须在截断前生成。
  - `sendResultAllMqEnabled`：来源 `JuziConfig.sendResultAllMqEnabled`；为 `true` 且 `shouldSendJuziAllMq(msg)` 通过时才生成并发送 all MQ body。
- 下游读取字段清单：
  - `JuziMessageService.sendMq` 接收 JSON 字符串，后续 `JuziMessageServiceImpl.sendMq` 读取 self 相关字段决定 tag。
  - `JuziMessageService.sendJuziAllMq` 接收 JSON 字符串，后续 `JuziMessageServiceImpl.sendJuziAllMq` 只设置 all tag，不解析 self 字段。
  - `shouldSendJuziAllMq` 读取顶层或 `payload` 内 `roomTopic`、`room_topic`、`externalUserId`、`external_user_id`。
- 空对象 / 占位对象风险：
  - 本次不新增 DTO、空 JSON 或空 Map；`payload` 为空时保持现有空值判断，不做截断。
- 调用顺序风险：
  - 风险点是 `JSONObject msg` 可变，先截断会影响 all MQ body；处理策略是在截断前为 all MQ 生成独立字符串，截断后再生成原 MQ 字符串。
- 旧逻辑保持：
  - 保持 `if (!juziConfig.getFlag())` 外层逻辑。
  - 保持 `payload.extras` 超 200 字符时，`botUserId == Dong` 上传 OSS、随后执行 `payloadObj.put("extras", extrasValue.substring(0, 50)+"...")`。
  - 保持 `log.info("sendResult:{}", msg)` 输出截断后的 `msg`。
  - 保持原 `sendMq` 先发送，all MQ 在原发送之后按开关和过滤条件发送。
  - 保持接口立即返回 `{"errcode":0,"errmsg":""}`。
- 需要用户确认的设计选择：
  - 无。用户已明确 `sendJuziAllMq` 不清空/截断 `extras`，其他截断逻辑保持。

## 边界情况

- all MQ 开关关闭：不生成 all MQ body，不调用 `sendJuziAllMq`；原 MQ 行为不变。
- all MQ 过滤不通过：不调用 `sendJuziAllMq`；原 MQ 行为不变。
- `payload` 为空：不截断；如 all MQ 开关和过滤通过，all MQ body 与原 MQ body 均无 `payload.extras` 变更。
- `payload.extras` 为空或长度不超过 200：不截断；原 MQ 与 all MQ body 的 `extras` 一致。
- `payload.extras` 长度大于 200：原 MQ body 截断；all MQ body 保留完整原值。
- `botUserId == Dong` 且 `extras` 超长：仍先上传 OSS 原始消息；本次不改变上传参数。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `sendJuziAllMq` 需要发送时，使用截断前的 sendResult JSON body。
- **FR-002**：系统 MUST 保持原 `sendMq` body 中 `payload.extras` 超 200 时截断为 `extrasValue.substring(0, 50)+"..."`。
- **FR-003**：系统 MUST 保持 `Dong` 原始消息上传 OSS、sendResult 日志、all MQ 开关和过滤条件不变。
- **FR-004**：系统 MUST NOT 修改 MQ topic/tag/group、接口入参、接口响应或消费端契约。
- **FR-005**：单元测试 MUST 断言 `sendMq` 与 `sendJuziAllMq` 接收到的 body 中 `payload.extras` 不同：前者截断，后者完整。

## 成功标准 *(必填)*

- **SC-001**：`extras` 超过 200 且 all MQ 发送时，`sendJuziAllMq` body 的 `payload.extras` 等于原始完整字符串。
- **SC-002**：同一请求中，`sendMq` body 的 `payload.extras` 仍等于前 50 字符加 `...`。
- **SC-003**：已有 `shouldSendJuziAllMq` 过滤测试仍通过。
- **SC-004**：目标模块 `juzi` 编译或指定单元测试通过。

## 假设

- 用户所说“清空 extras”指当前代码对 `extras` 做截断/脱敏后发送，不是要求删除字段。
- all MQ 允许接收更大的 JSON body，且这次业务目标就是保留完整 `extras`。
- all MQ 过滤字段不依赖 `payload.extras` 字符串内容；现有过滤只读取独立字段。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成参数来源、下游读取字段、调用顺序、旧逻辑保持和测试映射分析。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：在 `CallbackController.msgCallbackMessageResult` 中，先按 all MQ 开关和 `shouldSendJuziAllMq(msg)` 过滤判断是否需要发送 all MQ；如需要，在 `payload.extras` 截断前生成 `sendJuziAllMessage`。原 `sendMq` 仍在 `payloadObj.put("extras", extrasValue.substring(0, 50)+"...")` 之后生成 `sendResultMessage` 并发送。
- 影响范围：仅 `data-RC\juzi` 模块 sendResult callback 的 MQ body 生成时机；未修改接口入参/响应、MQ topic/tag/group、all MQ 过滤条件、`sendJuziAllMq` 实现、原 MQ self 分流或 OSS 上传逻辑。
- 测试命令：`mvn -pl juzi "-Dskip=false" "-DskipTests=false" "-Dmaven.test.skip=false" "-Dtest=CallbackControllerTest,JuziMessageServiceImplTest" test`；`mvn -pl juzi "-Dmdep.outputFile=juzi\target\test-classpath.txt" "-Dmdep.includeScope=test" dependency:build-classpath`；`java -cp "<juzi\target\test-classes>;<juzi\target\classes>;<test classpath>" org.junit.runner.JUnitCore com.drh.data.juzi.controller.CallbackControllerTest com.drh.data.juzi.service.impl.JuziMessageServiceImplTest`。
- 测试结果：Maven `test` 完成主代码和测试代码编译并 `BUILD SUCCESS`，但因 `juzi/pom.xml` 中 surefire `<skip>true</skip>` 显示 `Tests are skipped`；手动 `JUnitCore` 执行通过，输出 `OK (6 tests)`。
- 自检结论：`sendJuziAllMq` 不再复用截断后的 `sendResultMessage`；新增测试断言原 MQ body 的 `payload.extras` 为前 50 字符加 `...`，all MQ body 的 `payload.extras` 为完整原值；旧过滤测试和 `sendJuziAllMq` all tag 测试均通过。

### D003 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
