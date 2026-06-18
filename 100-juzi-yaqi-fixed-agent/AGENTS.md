# 规格执行说明：juzi-service 钢琴雅琪固定 Agent 独立链路

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\100-juzi-yaqi-fixed-agent`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 相关模块：消息入口、Center 营期查询、route aiReplyRules 策略判定、FC payload 构造

## 当前目标

- 新增独立链路：钢琴雅琪 `speakerId=113` 且消息类型策略为 `GENERAL_CHAT` 时固定使用 agentId `7638948127407636514`。
- 不修改私域 AI 链路，不调用私域 agent 配置接口。
- 不调用通用 agentId 获取或配置化 agent 选择逻辑；只读取消息类型策略是否为 `GENERAL_CHAT`。
- 缓存 `campDateId -> category/speakerId`，减少 Center 查询。

## 执行原则

- 保持旧私域、声乐默认、钢琴 SOP/route、旁路验证、人工回复静默和过滤顺序不变。
- 雅琪链路只在旧权限通过后、声乐默认分支之后、现有钢琴 SOP/route 之前尝试。
- `SOP_REVIEW`、`NOOP`、未命中配置、配置灰度未命中、营期查询失败时必须放行旧链路。
- 下游 FC payload 必须显式包含固定 `agent_id`，不得传空 agent 或依赖后续流程补齐。
- 单元测试必须断言下游 `agent_id`、`functionName` 和“不调用私域 agent 配置”。

## 重点代码位置

- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\MessageServiceImpl.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\route\service\YaqiAgentRouteService.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\util\CenterUtil.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\DelayMessageServiceImpl.java`

## 测试命令

- `mvn -pl juzi-service -DskipTests=false "-Dtest=CenterUtilTest,YaqiAgentRouteServiceTest,MessageServiceImplPrivateDomainDoNotDisturbTest,DelayMessageServiceImplTest" test`
- `mvn -pl juzi-service -DskipTests=false test`
- `git -C C:\workspace\ju-chat\data-RC diff --check`
- `git -C C:\workspace\ju-chat\specs diff --check -- 100-juzi-yaqi-fixed-agent`
