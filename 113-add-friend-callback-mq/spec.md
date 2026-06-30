# 功能规格：添加好友与 RPA 新增客户回调发送 MQ 新 Tag

**功能目录**：`113-add-friend-callback-mq`  
**创建日期**：`2026-06-30`  
**状态**：Draft  
**输入**：修改 `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\controller\CallbackController.java`，增加添加好友的回调，发送到 MQ 新 tag；对这个消息增加开关，默认 `false`；消费者不用写，由其他人消费。回调信息格式：

```json
{
  "botId": "66a77970c*****6b879ef868",
  "imBotId": "168885****578438",
  "imContactId": "78813*****110143",
  "imContactName": "f",
  "hello": "我是f"
}
```

追加需求：再增加一个“新增客户回调-RPA”接口回调，同样使用 MQ 接收，并使用新的 tag。回调信息格式：

```json
{
  "imContactId": "78813****6927825",
  "name": "test_name",
  "avatar": "http://qlogo.cn/mmhead/Ksm9rvSibEfZKrGiaia9VE3tB7DAKdDIicu4mz0OBibUPYfg/0",
  "gender": 1,
  "createTimestamp": 1705580628000,
  "imInfo": {
    "externalUserId": "wmrRhyBgAA8J*****p3iR6rjFQ3nQxg",
    "followUser": {
      "wecomUserId": "huakaifugui"
    }
  },
  "botInfo": {
    "botId": "657fb386****ecdf5a5567",
    "imBotId": "168885****513525",
    "name": "花开富贵花开富贵花开富贵花开富贵花开富贵花开富贵花开",
    "avatar": "https://qpic.cn/wwpic3az/958155_hMku-PsNRrqSBPG_1702350306/0"
  }
}
```

## 背景

- 当前问题：`CallbackController` 已有消息回调和发送结果回调；已补充添加好友事件独立回调，但还没有“新增客户回调-RPA”的独立入口和独立 MQ tag 发布能力。
- 当前行为：
  - `POST /callback/msg/callback/message` 在 `juzi.flag=true` 时读取 `data` 后调用 `juziMessageService.sendMq(data)`。
  - `POST /callback/msg/callback/sendResult` 在 `juzi.flag=false` 时异步调用 `juziMessageService.sendMq(...)`，并可在 `juzi.sendResultAllMqEnabled=true` 时调用 `sendJuziAllMq(...)`。
  - `JuziMessageServiceImpl.sendMq(...)` 会解析消息并按 `isSelf` 选择 `mq.juzi_tag` 或 `mq.juzi_self_tag`，不适合作为添加好友原始事件的新 tag 发布入口。
  - `JuziMessageServiceImpl.sendJuziAllMq(...)` 和 `sendJuziAddFriendMq(...)` 已提供“不解析 body、按指定 tag 发送原始 JSON”的实现模式。
- 目标行为：新增添加好友和 RPA 新增客户回调入口，收到示例格式 JSON 后，在对应开关开启时将原始 JSON 发布到 `mq.juzi_topic` 下的独立新 tag；开关默认关闭。
- 非目标：不实现 MQ 消费者；不修改现有消息回调、发送结果回调过滤规则；不新增数据库表或 Redis/FC/Feign 逻辑。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 开关开启后发布添加好友事件（优先级：P1）

业务方需要把添加好友事件独立投递到 MQ 新 tag，供其他服务或团队消费。

**独立测试**：构造添加好友回调 JSON，设置 `juzi.addFriendMqEnabled=true`，调用新增 controller 方法，断言 `JuziMessageService` 的添加好友 MQ 方法收到原始 JSON body。

**验收场景**：

1. **Given** `juzi.addFriendMqEnabled=true` 且请求体包含 `botId`、`imBotId`、`imContactId`、`imContactName`、`hello`，**When** 调用新增添加好友回调，**Then** 系统返回成功 JSON，并向 MQ 新 tag 发布同一份业务字段 JSON。
2. **Given** 请求体中 `hello` 为空或未传，**When** 调用新增添加好友回调，**Then** 系统仍按原始 JSON 发布，不补齐、不报错、不阻塞回调返回。

### 用户故事 2 - 默认关闭避免误投递（优先级：P1）

上线前默认不向新 tag 发送消息，避免其他环境未准备好时产生意外 MQ 流量。

**独立测试**：构造添加好友回调 JSON，使用 `new JuziConfig()` 默认值或显式设置 `false`，调用新增 controller 方法，断言不会调用添加好友 MQ 方法。

**验收场景**：

1. **Given** 未配置 `juzi.addFriendMqEnabled` 或配置为 `false`，**When** 调用新增添加好友回调，**Then** 系统只记录日志并返回成功 JSON，不发送 MQ。

### 用户故事 3 - 开关开启后发布 RPA 新增客户事件（优先级：P1）

业务方需要把 RPA 新增客户事件独立投递到 MQ 新 tag，供其他服务或团队消费。

**独立测试**：构造 RPA 新增客户回调 JSON，设置 `juzi.rpaCustomerMqEnabled=true`，调用新增 controller 方法，断言 `JuziMessageService` 的 RPA 新增客户 MQ 方法收到原始 JSON body。

**验收场景**：

1. **Given** `juzi.rpaCustomerMqEnabled=true` 且请求体包含 `imContactId`、`name`、`avatar`、`gender`、`createTimestamp`、`imInfo`、`botInfo`，**When** 调用新增 RPA 客户回调，**Then** 系统返回成功 JSON，并向 MQ 新 tag 发布同一份业务字段 JSON。
2. **Given** 请求体存在嵌套对象 `imInfo.followUser` 和 `botInfo`，**When** 调用新增 RPA 客户回调，**Then** 系统保持嵌套结构原样发送，不拆平、不补齐、不转换字段名。

### 用户故事 4 - RPA 新增客户默认关闭避免误投递（优先级：P1）

上线前默认不向 RPA 新增客户 tag 发送消息，避免其他环境未准备好时产生意外 MQ 流量。

**独立测试**：构造 RPA 新增客户回调 JSON，使用 `new JuziConfig()` 默认值或显式设置 `false`，调用新增 controller 方法，断言不会调用 RPA 新增客户 MQ 方法。

**验收场景**：

1. **Given** 未配置 `juzi.rpaCustomerMqEnabled` 或配置为 `false`，**When** 调用新增 RPA 客户回调，**Then** 系统只记录日志并返回成功 JSON，不发送 MQ。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `botId`：来源请求体 `CallbackController` 新增方法入参；赋值时机为外部回调请求到达时；下游读取位置为 MQ 消费者，本次不实现。
  - `imBotId`：来源请求体；赋值时机为外部回调请求到达时；下游读取位置为 MQ 消费者，本次不实现。
  - `imContactId`：来源请求体；赋值时机为外部回调请求到达时；下游读取位置为 MQ 消费者，本次不实现。
  - `imContactName`：来源请求体；赋值时机为外部回调请求到达时；下游读取位置为 MQ 消费者，本次不实现。
  - `hello`：来源请求体；赋值时机为外部回调请求到达时；下游读取位置为 MQ 消费者，本次不实现。
  - `addFriendMqEnabled`：来源 `JuziConfig` / Nacos `juzi.add-friend-mq-enabled`；赋值时机为 Spring Boot 配置绑定和 RefreshScope 刷新；下游读取位置为新增 controller 分支。
  - `juziAddFriendTag`：来源 `MqConfig` / Nacos `mq.juzi-add-friend-tag`，默认 `juzi_add_friend`；赋值时机为 Spring Boot 配置绑定；下游读取位置为新增 service 方法。
  - `imContactId`、`name`、`avatar`、`gender`、`createTimestamp`：来源 RPA 新增客户回调请求体；赋值时机为外部回调请求到达时；下游读取位置为 MQ 消费者，本次不实现。
  - `imInfo.externalUserId`、`imInfo.followUser.wecomUserId`：来源请求体嵌套对象；赋值时机为外部回调请求到达时；下游读取位置为 MQ 消费者，本次不实现。
  - `botInfo.botId`、`botInfo.imBotId`、`botInfo.name`、`botInfo.avatar`：来源请求体嵌套对象；赋值时机为外部回调请求到达时；下游读取位置为 MQ 消费者，本次不实现。
  - `rpaCustomerMqEnabled`：来源 `JuziConfig` / Nacos `juzi.rpa-customer-mq-enabled`；赋值时机为 Spring Boot 配置绑定和 RefreshScope 刷新；下游读取位置为新增 RPA customer controller 分支。
  - `juziRpaCustomerTag`：来源 `MqConfig` / Nacos `mq.juzi-rpa-customer-tag`，默认 `juzi_rpa_customer`；赋值时机为 Spring Boot 配置绑定；下游读取位置为新增 service 方法。
- 下游读取字段清单：
  - 新增 controller 方法读取 `juziConfig.addFriendMqEnabled` 和请求体原始 JSON。
  - 新增 service 方法读取 `mqConfig.juzi_topic`、`mqConfig.juzi_add_friend_tag` 和原始消息 body。
  - RPA 新增客户 controller 方法读取 `juziConfig.rpaCustomerMqEnabled` 和请求体原始 JSON。
  - RPA 新增客户 service 方法读取 `mqConfig.juzi_topic`、`mqConfig.juzi_rpa_customer_tag` 和原始消息 body。
- 空对象 / 占位对象风险：
  - 不创建业务 DTO 占位对象；直接发送请求体 `JSONObject.toJSONString()`。请求体为空 JSON 时只会发送 `{}`（对应开关开启时），该行为需通过日志可观察。
- 调用顺序风险：
  - 不依赖调用后补字段；开关判断在发送前完成；MQ body 在发送前从当前请求体生成。
- 旧逻辑保持：
  - 保持 `msg/callback/message` 的 `juzi.flag=true` 分支不变。
  - 保持 `msg/callback/sendResult` 的异步线程、`juzi.flag=false`、`sendResultAllMqEnabled`、extras 截断、Dong 原始消息上传 OSS、`shouldSendJuziAllMq` 过滤不变。
  - 保持 `sendMq` 对 `isSelf` 的解析和原 tag 选择逻辑不变。
  - 保持已实现的 `addFriend` 回调开关、tag、producer 和测试口径不变。
- 需要用户确认的设计选择：
  - RPA 新增客户回调路径拟采用 `POST /callback/msg/callback/rpaCustomer`，沿用现有 `msg/callback/...` 路径风格。
  - RPA 新增客户 MQ tag 默认值拟采用 `juzi_rpa_customer`，可通过 Nacos `mq.juzi-rpa-customer-tag` 覆盖。
  - 虽然追加需求未明确要求开关，但为保持与添加好友回调一致并避免误投递，拟新增独立开关 `juzi.rpa-customer-mq-enabled=false`。

## 边界情况

- 开关缺失：默认 `false`，不发送 MQ。
- 请求体字段缺失、为空或嵌套对象缺失：不在 controller 做业务校验，按原始 JSON 交给消费者判断；避免回调方因字段瑕疵被阻塞。
- MQ 发送异常：沿用 `JuziMessageServiceImpl` 捕获并记录错误的模式，不向回调方抛出异常。
- 重复触发：本次不做幂等，交由消费端处理。
- 配置 tag 缺失：使用 `MqConfig` 默认 `juzi_add_friend`。
- RPA 新增客户配置 tag 缺失：使用 `MqConfig` 默认 `juzi_rpa_customer`。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `CallbackController` 增加添加好友回调入口，接收示例格式 JSON。
- **FR-002**：系统 MUST 增加添加好友 MQ 发布开关，配置项默认值为 `false`。
- **FR-003**：系统 MUST 在开关开启时将添加好友回调原始 JSON 发送到 `mq.juzi_topic` 的新 tag。
- **FR-004**：系统 MUST NOT 实现 MQ 消费者或改变现有消息回调、发送结果回调逻辑。
- **FR-005**：测试 MUST 覆盖开关关闭不发送、开关开启发送原始 body、service 使用新 tag 三个关键行为。
- **FR-006**：系统 MUST 在 `CallbackController` 增加 RPA 新增客户回调入口，接收示例格式 JSON。
- **FR-007**：系统 MUST 增加 RPA 新增客户 MQ 发布开关，配置项默认值为 `false`。
- **FR-008**：系统 MUST 在 RPA 新增客户开关开启时将回调原始 JSON 发送到 `mq.juzi_topic` 的独立新 tag。
- **FR-009**：RPA 新增客户实现 MUST 保持嵌套 JSON 结构原样发送，不拆平、不重命名、不改写字段。

## 成功标准 *(必填)*

- **SC-001**：默认配置下调用添加好友回调不会产生 MQ 发送调用。
- **SC-002**：开启 `juzi.addFriendMqEnabled` 后，示例 JSON 的五个业务字段以原始 JSON 形式发送到新增 tag。
- **SC-003**：现有 `CallbackControllerTest` 和 `JuziMessageServiceImplTest` 相关用例通过，证明旧逻辑未回归。
- **SC-004**：默认配置下调用 RPA 新增客户回调不会产生 MQ 发送调用。
- **SC-005**：开启 `juzi.rpaCustomerMqEnabled` 后，示例 JSON 的顶层字段与嵌套字段以原始 JSON 形式发送到 `juzi_rpa_customer` tag。

## 假设

- 添加好友回调请求会由外部系统投递到 juzi 服务新增 HTTP 入口。
- 新 tag 名未在需求中明确，默认采用 `juzi_add_friend`，生产可通过 Nacos 覆盖。
- 添加好友事件消费方由其他人实现，本服务只负责发布。
- RPA 新增客户回调请求会由外部系统投递到 juzi 服务新增 HTTP 入口。
- RPA 新增客户 tag 名未在需求中明确，默认采用 `juzi_rpa_customer`，生产可通过 Nacos 覆盖。
- RPA 新增客户消费方由其他人实现，本服务只负责发布。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成历史问题防漏分析和强制门禁检查。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：
  - `JuziConfig` 新增 `addFriendMqEnabled=false` 开关。
  - `MqConfig` 新增 `juzi_add_friend_group=GID_juzi_add_friend` 和 `juzi_add_friend_tag=juzi_add_friend`。
  - `ProduceClient` 新增 `juziAddFriendProducerBean`。
  - `JuziMessageService` / `JuziMessageServiceImpl` 新增 `sendJuziAddFriendMq`，按新 tag 发送原始 body。
  - `CallbackController` 新增 `POST /callback/msg/callback/addFriend`，开关开启时发送 MQ。
  - 补充 controller/service 单元测试。
- 影响范围：仅 `data-RC/juzi` 模块添加好友回调发布链路；未实现消费者；未修改现有 message/sendResult 逻辑。
- 测试命令：
  - `mvn -pl juzi "-Dtest=CallbackControllerTest,JuziMessageServiceImplTest" "-DskipTests=false" test`
  - `mvn -pl juzi dependency:build-classpath "-Dmdep.outputFile=juzi\target\test-classpath.txt" "-Dmdep.includeScope=test"`
  - `java -cp <juzi target test/classes + dependencies> org.junit.runner.JUnitCore com.drh.data.juzi.controller.CallbackControllerTest com.drh.data.juzi.service.impl.JuziMessageServiceImplTest`
- 测试结果：
  - Maven 编译成功；因 `juzi/pom.xml` surefire 配置 `<skip>true</skip>`，测试阶段显示 `Tests are skipped`。
  - 通过 `JUnitCore` 实际执行 `CallbackControllerTest` 和 `JuziMessageServiceImplTest`，结果 `OK (9 tests)`。
- 自检结论：默认关闭不发送、开启后发送添加好友 JSON、新 service 方法使用 `juzi_add_friend` tag 且不解析 body 均已验证；旧 `juzi_all` 测试仍通过。

### D003 - RPA 新增客户回调需求记录

- 触发原因：用户追加“新增客户回调-RPA”，要求同样使用 MQ 接收并使用新的 tag。
- 修正内容：
  - 在同一规格中追加 RPA 新增客户回调入口、独立 MQ tag 和独立发布开关。
  - 拟新增路径 `POST /callback/msg/callback/rpaCustomer`。
  - 拟新增配置 `juzi.rpa-customer-mq-enabled=false`。
  - 拟新增 MQ group/tag 默认值 `GID_juzi_rpa_customer` / `juzi_rpa_customer`。
  - 消费者仍不在本次范围内。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 验证结果：已完成实现前代码事实确认和风险门禁；本阶段未修改业务代码。

### D004 - RPA 新增客户实现记录

- 实现内容：
  - `JuziConfig` 新增 `rpaCustomerMqEnabled=false` 开关。
  - `MqConfig` 新增 `juzi_rpa_customer_group=GID_juzi_rpa_customer` 和 `juzi_rpa_customer_tag=juzi_rpa_customer`。
  - `ProduceClient` 新增 `juziRpaCustomerProducerBean`。
  - `JuziMessageService` / `JuziMessageServiceImpl` 新增 `sendJuziRpaCustomerMq`，按新 tag 发送原始 body。
  - `CallbackController` 新增 `POST /callback/msg/callback/rpaCustomer`，开关开启时发送 MQ。
  - 补充 controller/service 单元测试，并为当前 `shouldSendJuziAllMq` 的 `juziConfig` 依赖补充测试初始化。
- 影响范围：仅 `data-RC/juzi` 模块 RPA 新增客户回调发布链路；未实现消费者；未修改现有 message/sendResult/addFriend 的业务行为。
- 测试命令：
  - `mvn -pl juzi "-Dtest=CallbackControllerTest,JuziMessageServiceImplTest" "-DskipTests=false" test`
  - `mvn -pl juzi dependency:build-classpath "-Dmdep.outputFile=juzi\target\test-classpath.txt" "-Dmdep.includeScope=test"`
  - `java -cp <juzi target test/classes + dependencies> org.junit.runner.JUnitCore com.drh.data.juzi.controller.CallbackControllerTest com.drh.data.juzi.service.impl.JuziMessageServiceImplTest`
- 测试结果：
  - Maven 编译成功；因 `juzi/pom.xml` surefire 配置 `<skip>true</skip>`，测试阶段显示 `Tests are skipped`。
  - 通过 `JUnitCore` 实际执行 `CallbackControllerTest` 和 `JuziMessageServiceImplTest`，结果 `OK (12 tests)`。
- 自检结论：默认关闭不发送、开启后发送 RPA 新增客户 JSON、嵌套字段原样保留、新 service 方法使用 `juzi_rpa_customer` tag 且不解析 body 均已验证；旧 `juzi_all` 与 `addFriend` 测试仍通过。
