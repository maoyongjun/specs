# 规格执行说明

本目录记录 `061-juzi-send-result-all-mq` 功能规格，作用范围仅限当前规格目录及 `C:\workspace\ju-chat\data-RC\juzi` 模块。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\061-juzi-send-result-all-mq`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi`
- 相关模块：句子回调服务、RocketMQ 生产者配置、Nacos 配置绑定

## 当前目标

- 修改 `CallbackController.msgCallbackMessageResult`，在原有 sendResult MQ 发送之外，按开关额外发送一份消息到 `juzi_all` tag。
- 新增 MQ 使用 topic `juzi`，生产环境 groupId/tag 为 `GID_juzi_all` / `juzi_all`。
- 测试环境 groupId/tag 通过 Nacos 配置为 `GID_juzi_all_tet` / `juzi_all_tet`。
- 新增发送不区分 self 消息，统一发送到 `juzi_all` 对应 tag。
- 新增发送由 Nacos 开关控制，默认关闭。

## 执行原则

- 原有 `msgCallbackMessageResult` 异步处理、`juzi.flag` 判断、长 `extras` 截断、`Dong` 原始消息上传 OSS、日志和原 MQ 发送必须保持。
- 新增发送必须复用当前回调已处理后的 JSON body，不新增接口入参，不改变回调返回体。
- 新增 all MQ 发送不得调用 `isSelf` 分流逻辑。
- 新增 producer 必须显式携带 all groupId，不能只改 message tag 后继续复用旧 group。
- Nacos 缺少新增开关时必须保持不发送。

## 强制门禁

- 参数来源：`msg` 来自回调请求体；`requestId` 来自 MDC；topic/tag/group/switch 来自配置对象或代码默认值。
- 赋值时机：`requestId` 和 `extras` 截断在两个 MQ 发送前完成。
- 占位对象：本次不创建空 DTO、空 JSON 或空 Map 继续下传。
- 下游读取：旧发送读取 self 相关字段用于分流；新增发送只读取 topic/tag 和 body，不读取 self。
- 旧逻辑保持：不改变原发送条件、原 tag 分流、OSS 上传、异常捕获和异步返回。
- 影响范围：只新增一个 producer bean、配置字段、service 方法和 controller 调用点。
- 测试映射：至少执行目标模块编译，并用代码搜索确认新开关、group/tag 和调用点一致。

## 重点代码位置

- `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\controller\CallbackController.java`
- `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\service\JuziMessageService.java`
- `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\service\impl\JuziMessageServiceImpl.java`
- `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\config\JuziConfig.java`
- `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\config\MqConfig.java`
- `C:\workspace\ju-chat\data-RC\juzi\src\main\java\com\drh\data\juzi\mq\ProduceClient.java`

## 文档维护

- `spec.md` 描述业务目标、参数来源、边界和验收标准。
- `tasks.md` 记录事实确认、风险门禁、实现任务和验证结果。
- `checklists/requirements.md` 用于确认规格质量和实施就绪度。
- 用户后续调整 group/tag、开关名或发送条件时，必须追加 Dxxx 记录并同步更新文档。
