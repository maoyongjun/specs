# 功能规格：sendResult 新增 juzi_all MQ 分发

**功能目录**：`061-juzi-send-result-all-mq`  
**创建日期**：`2026-06-09`  
**状态**：Implemented  
**输入**：用户要求修改 `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\controller\CallbackController.java` 的 `msgCallbackMessageResult` 接口，新增发送消息到新的 tag；topic 仍使用 `juzi`；生产 groupId/tag 为 `GID_juzi_all` / `juzi_all`；测试环境 groupId/tag 为 `GID_juzi_all_tet` / `juzi_all_tet`；新增发送不区分 self 消息，统一发送到 `juzi_all`；新增发送 MQ 增加 Nacos 开关，默认 `false`。

## 背景

- 当前问题：`msgCallbackMessageResult` 只发送到原有 MQ tag，且 `JuziMessageServiceImpl.sendMq` 会按 self 消息分流到 `juzi_self_tag`。
- 当前行为：接口异步处理回调；当 `juzi.flag == false` 时补充 `requestId`，对过长 `payload.extras` 做 OSS 上传和截断，然后调用 `juziMessageService.sendMq(msg.toJSONString())`。
- 目标行为：在原有发送保持不变的前提下，当新增 Nacos 开关打开时，额外发送一份相同 body 到 topic `juzi` 的 all tag；新增发送使用 all groupId，并且不做 self 分流。
- 非目标：不新增回调接口；不修改 MQ body 字段；不修改消费端；不改变原有 `juzi_tag` / `juzi_self_tag` 分流。

## 用户场景与测试

### 用户故事 1 - 开关打开后额外分发 sendResult（优先级：P1）

运营或下游系统需要接收所有 sendResult 回调消息，不希望被 self 分流影响，因此需要在原 MQ 之外额外接收统一 tag 的消息。

**独立测试**：构造 sendResult 回调 JSON，设置 `juzi.flag=false` 且 `juzi.send-result-all-mq-enabled=true`，验证原发送仍执行，新增发送的 topic/tag/group 分别为 `juzi`、`juzi_all`、`GID_juzi_all`。

**验收场景**：

1. **Given** 新增开关为 `true` 且当前为生产配置，**When** `msgCallbackMessageResult` 处理一条非 self 回调，**Then** 系统除原 MQ 外，还发送到 topic `juzi`、groupId `GID_juzi_all`、tag `juzi_all`。
2. **Given** 新增开关为 `true` 且当前为测试配置，**When** `msgCallbackMessageResult` 处理一条回调，**Then** 新增发送使用 groupId `GID_juzi_all_tet`、tag `juzi_all_tet`。

### 用户故事 2 - all 分发不区分 self 消息（优先级：P1）

新增 all MQ 是全量分发通道，self 消息不应再被拆到 self tag。

**独立测试**：构造 `isSelf=true` 或 `contactId == botWxid` 的 sendResult 回调，设置新增开关为 `true`，验证新增发送仍使用 all tag。

**验收场景**：

1. **Given** 回调消息为 self 消息，**When** 新增开关打开，**Then** 原 MQ 仍按旧逻辑发送到 self tag，新增 MQ 发送到 `juzi_all`。
2. **Given** 回调消息未携带 `isSelf`，**When** 新增开关打开，**Then** 新增 MQ 不解析 self 字段，仍发送到 `juzi_all`。

### 用户故事 3 - 默认关闭保持旧行为（优先级：P1）

为了避免配置缺失或发布后立即扩大 MQ 流量，新增分发必须默认关闭。

**独立测试**：不配置 `juzi.send-result-all-mq-enabled` 或配置为 `false`，调用 sendResult 回调，验证只执行原 MQ 发送。

**验收场景**：

1. **Given** Nacos 没有新增开关，**When** 服务启动并处理 sendResult 回调，**Then** 不发送 all MQ。
2. **Given** 新增开关为 `false`，**When** 回调消息是 self 或非 self，**Then** 只保留原有 MQ 行为。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `msg`：来源 `CallbackController.msgCallbackMessageResult(@RequestBody JSONObject msg)`；赋值时机为接口入参；下游读取位置为 `JuziMessageServiceImpl.sendMq` 和新增 all 发送方法。
  - `requestId`：来源 `MDC.get("requestId")`；在异步线程内发送 MQ 前写入 `msg`；下游只作为 body 字段传递。
  - `payload.extras`：来源请求体 `payload.extras`；在发送前按旧逻辑上传 OSS 后截断；两个 MQ 发送都使用截断后的 body。
  - `juzi.flag`：来源 `JuziConfig.flag`，Nacos `juzi.flag` 绑定；在进入原 sendResult 业务逻辑前判断。
  - `sendResultAllMqEnabled`：来源 `JuziConfig.sendResultAllMqEnabled`，Nacos 建议配置 `juzi.send-result-all-mq-enabled`；默认值为 `false`；在新增 all MQ 发送前判断。
  - `juzi_all_group`：来源 `MqConfig.juzi_all_group`，Nacos 建议配置 `mq.juzi_all_group`；生产默认 `GID_juzi_all`，测试环境配置 `GID_juzi_all_tet`；在 all producer 初始化时写入 `PropertyKeyConst.GROUP_ID`。
  - `juzi_all_tag`：来源 `MqConfig.juzi_all_tag`，Nacos 建议配置 `mq.juzi_all_tag`；生产默认 `juzi_all`，测试环境配置 `juzi_all_tet`；在新增 all MQ 发送时写入 message tag。
  - `juzi_topic`：来源 `MqConfig.juzi_topic`，沿用现有 topic 配置，目标值仍为 `juzi`；新增发送复用该 topic。
- 下游读取字段清单：
  - `JuziMessageServiceImpl.sendMq` 读取 `isSelf`、`botWxid`、`imBotId`、`contactId`、`imContactId`，用于原 tag 分流。
  - 新增 all 发送方法读取 `mqConfig.juzi_topic`、`mqConfig.juzi_all_tag` 和 body 字符串，不读取 self 相关字段。
  - all producer 初始化读取 `mqConfig.juzi_all_group`。
- 空对象 / 占位对象风险：
  - 本次不新增 DTO、空 JSON 或空 Map 作为占位参数；回调缺少 `payload` 时保持现有空值判断。
- 调用顺序风险：
  - `requestId` 写入、`extras` 截断和日志输出发生在两个 MQ 发送之前；不存在调用后才补字段的新增风险。
  - 新增发送位于原发送之后，属于额外分发，不改变接口异步返回时机。
- 旧逻辑保持：
  - 保持 `if (!juziConfig.getFlag())` 外层逻辑。
  - 保持 `payload.extras` 超 200 字符时，`botUserId == Dong` 上传 OSS、随后截断到前 50 字符加省略号。
  - 保持原 `sendMq` 的 self 分流和异常捕获。
  - 保持接口立即返回 `{"errcode":0,"errmsg":""}`。
- 需要用户确认的设计选择：
  - 无。用户已明确新增发送为 all tag、默认关闭、测试和生产 group/tag。

## 边界情况

- Nacos 未配置新增开关：按默认 `false`，不发送 all MQ。
- Nacos 未配置 all group/tag：代码使用生产默认 `GID_juzi_all` / `juzi_all`；测试环境必须在 Nacos 覆盖为 `GID_juzi_all_tet` / `juzi_all_tet`。
- 回调缺少 `payload` 或 `extras`：保持现有逻辑，不影响新增 all 发送。
- 回调为 self 消息或字段缺失导致无法判断 self：新增 all 发送不解析这些字段，统一发 all tag。
- MQ 异步发送失败：记录失败日志，不影响接口返回。

## Nacos 配置建议

生产环境保持或显式配置：

```yaml
juzi:
  send-result-all-mq-enabled: false
mq:
  juzi_all_group: GID_juzi_all
  juzi_all_tag: juzi_all
```

测试环境如需打开新增分发：

```yaml
juzi:
  send-result-all-mq-enabled: true
mq:
  juzi_all_group: GID_juzi_all_tet
  juzi_all_tag: juzi_all_tet
```

## 需求

### 功能需求

- **FR-001**：系统 MUST 在 `msgCallbackMessageResult` 原有 MQ 发送之外，按开关额外发送一份 sendResult 消息到 all MQ。
- **FR-002**：新增 all MQ 发送 MUST 使用 topic `juzi`，生产 groupId/tag 默认为 `GID_juzi_all` / `juzi_all`。
- **FR-003**：测试环境 MUST 支持通过 Nacos 将 all groupId/tag 配置为 `GID_juzi_all_tet` / `juzi_all_tet`。
- **FR-004**：新增 all MQ 发送 MUST NOT 区分 self 消息，不能复用原 `sendMq` 的 self tag 分流。
- **FR-005**：新增 all MQ 发送 MUST 由 Nacos 开关 `juzi.send-result-all-mq-enabled` 控制，默认值 MUST 为 `false`。
- **FR-006**：系统 MUST NOT 改变原有 sendResult MQ 发送条件、body 处理、日志、异常捕获和接口响应。

## 成功标准

- **SC-001**：开关为 `false` 或缺失时，代码路径不会调用 all MQ 发送方法。
- **SC-002**：开关为 `true` 时，新增发送使用 all tag，不会根据 `isSelf`、`contactId` 或 `botWxid` 切换 tag。
- **SC-003**：目标模块 `juzi` 至少通过编译验证。
- **SC-004**：代码搜索能确认新增开关默认值为 `false`，生产默认 group/tag 和测试配置口径记录完整。

## 假设

- `mq.juzi_topic` 在当前环境值为 `juzi`；新增发送沿用该 topic 配置。
- 测试环境的 `GID_juzi_all_tet` / `juzi_all_tet` 拼写按用户原始描述保留，不自动修正为 `test`。
- 新增 all MQ 只在原 sendResult 业务分支内执行，即 `juzi.flag == false` 时才可能发送。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成参数来源、下游读取字段、旧逻辑保持和边界情况分析。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：在 `JuziConfig` 新增 `sendResultAllMqEnabled=false`；在 `MqConfig` 新增 `juzi_all_group=GID_juzi_all` 和 `juzi_all_tag=juzi_all`；在 `ProduceClient` 新增带 all groupId 的 `juziAllProducerBean`；在 `JuziMessageService` / `JuziMessageServiceImpl` 新增不解析 self 的 `sendJuziAllMq`；在 `CallbackController.msgCallbackMessageResult` 原发送后按开关额外调用 all MQ 发送。
- 影响范围：仅 `data-RC\juzi` 模块的 sendResult callback 生产者链路；未修改消费端、接口入参、接口响应、原 MQ body 和原 self 分流。
- 测试命令：`mvn -pl juzi -am compile`；`mvn -pl juzi "-DskipTests=false" "-Dsurefire.skip=false" "-Dtest=JuziMessageServiceImplTest" test`；`mvn -pl juzi "-Dskip=false" "-DskipTests=false" "-Dmaven.test.skip=false" "-Dtest=JuziMessageServiceImplTest" test`；`java -cp "<target/test-classes>;<target/classes>;<test classpath>" org.junit.runner.JUnitCore com.drh.data.juzi.service.impl.JuziMessageServiceImplTest`。
- 测试结果：`mvn -pl juzi -am compile` BUILD SUCCESS；两次 Maven test 命令完成测试编译但因模块 `pom.xml` 中 surefire `<skip>true</skip>` 显示 `Tests are skipped`；手动 `JUnitCore` 执行 `JuziMessageServiceImplTest` 通过，`OK (1 test)`。
- 自检结论：新增开关默认关闭；新增 all 发送使用 all producer/tag，不调用 `isSelf`；原 sendResult 旧逻辑保持；测试环境 `GID_juzi_all_tet` / `juzi_all_tet` 需在 Nacos 中覆盖。
