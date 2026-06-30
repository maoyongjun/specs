# 规格执行说明

本目录记录 `data-RC/juzi` 模块添加好友回调与 RPA 新增客户回调发送 MQ 新 tag 的需求。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\113-add-friend-callback-mq`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi`
- 相关模块：juzi 回调 controller、配置绑定、MQ producer、MQ 发送服务、单元测试

## 当前目标

- 在 `CallbackController` 增加添加好友回调入口。
- 增加添加好友 MQ 发布开关，默认关闭。
- 将添加好友回调原始 JSON 发送到 MQ 新 tag；消费者不在本次实现范围内。
- 在 `CallbackController` 增加 RPA 新增客户回调入口。
- 增加 RPA 新增客户 MQ 发布开关，默认关闭。
- 将 RPA 新增客户回调原始 JSON 发送到独立 MQ 新 tag；消费者不在本次实现范围内。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、配置来源和测试落点。
- 不允许把空对象、占位 DTO 或未赋值字段当成有效输入继续传递。
- 对跨层可变 DTO、调用后赋值、字段来源不明、旧逻辑副作用，必须先标记风险。
- 任何会改变调用顺序、接口契约、远程调用、MQ 字段、Redis key、数据库结构或外部行为的方案，实施前必须确认业务意图。
- 单元测试不能只验证最终结果；涉及 MQ 时，必须做下游参数断言，确认 topic、tag 和 body 内容。

## 强制门禁

- 参数来源：添加好友和 RPA 新增客户业务字段来自请求体；开关来自 `JuziConfig`；topic/tag 来自 `MqConfig`。
- 赋值时机：所有字段在 controller 方法执行时已存在，MQ body 在发送前由请求体生成。
- 占位对象：新增实现不创建业务 DTO 占位对象。
- 下游读取：本服务下游只读取 topic、tag、body；消费者字段读取不在本次范围内。
- 旧逻辑保持：不改 `sendMq` 自己/客户 tag 判断，不改 `sendResult` 异步处理和 `juzi_all` 逻辑。
- 影响范围：新增 HTTP 入口、新配置开关、新 MQ producer、新 MQ tag 发送方法；不涉及数据库、Redis、FC、Feign。
- 测试映射：controller 测开关和 body；service 测 topic/tag/body。

## 重点代码位置

- `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\controller\CallbackController.java`
- `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\config\JuziConfig.java`
- `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\config\MqConfig.java`
- `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\mq\ProduceClient.java`
- `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\service\JuziMessageService.java`
- `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\service\impl\JuziMessageServiceImpl.java`
- `C:\workspace\ju-chat\data-RC\juzi\src\test\java\com\drh\data\juzi\controller\CallbackControllerTest.java`
- `C:\workspace\ju-chat\data-RC\juzi\src\test\java\com\drh\data\juzi\service\impl\JuziMessageServiceImplTest.java`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
