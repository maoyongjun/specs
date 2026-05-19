# 规格执行说明

本目录记录 `024-juzi-piano-sop-reply-switch-gate` 的规格与后续实现约定。目录名保留历史命名，当前需求范围已扩展为所有命中 SOP 点评的 SKU。当前阶段只完成文档，未编码。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\024-juzi-piano-sop-reply-switch-gate`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 参考实现：`C:\workspace\ju-chat\fc\delay-mq\src\main\java\com\drh\delay\consumer\service\AppTask.java`

## 当前目标

- 在 `juzi-service` 的 SOP 点评处理前增加通用开关门禁。
- 门禁适用于所有命中 SOP 点评的 SKU，包括 `skuId=4`、`skuId=5` 以及通过通配规则命中的其他 SKU。
- 门禁逻辑仿照 `AppTask.java`：
  - `aiStatus == 1` 才视为 AI 开启。
  - `aiAutoReview == 1` 才视为作业点评开启。
  - 单聊消息两个开关都开启时，才允许继续调用 `sop-reply`。
  - 群聊消息还必须仿照 `isGroupOpen` 校验 `chatList.contains(roomWecomChatId)`。
- 门禁需要覆盖异步 SOP 调用和同步 SOP 评估两个入口。
- 非 SOP 点评链路保持现有行为不变。

## 后续实现约束

- 后续实现应优先复用或等价实现 `AppTask.java#getAiReviewConfig`、`isAiOpen`、`isHomeworkReviewOpen` 的判断口径。
- 群聊判断是否需要点评时应优先复用或等价实现 `AppTask.java#isGroupOpen` 的判断口径。
- 配置为空、查询失败、字段为空或字段不是 `1` 时，一律按未开启处理。
- 任意 SKU 命中 SOP 点评时必须应用门禁，不允许只校验 `skuId=4`。
- 群聊 SOP 点评必须同时满足 AI 开关开启、作业点评开关开启、当前 `roomWecomChatId` 命中 `chatList` 三项条件才允许调用 `sop-reply`。
- 群聊 `chatList` 为空、不包含当前群 ID、`roomWecomChatId` 为空时，一律不允许调用 `sop-reply`。
- 单聊 SOP 点评不要求校验群 ID，不能因 `roomWecomChatId` 为空被拦截。
- 门禁拦截后不允许调用 `sop-reply` FC；是否进入通用聊天应交由现有路由 fallback 规则决定。
- 后续实现必须增加单元测试，覆盖 `skuId=4`、`skuId=5`、AI 开关、作业点评开关、群 ID 命中 / 未命中、空群列表、空群 ID、单聊和非 SOP 链路。
- 本需求不修改 `fc/sop-reply` 内部点评逻辑，不新增数据库表，不新增对外接口。

## 重点代码位置

- `MessageServiceImpl#tryInvokeSopRouteAsyncWhenNoopFallback`：异步调用 `sop-reply` 前需要检查门禁。
- `DefaultSopRouteEvaluator#evaluate`：同步 SOP 评估调用 `sop-reply` 前需要检查门禁。
- `RouteOrchestratorImpl#buildPlan` / `AiReplyRouterImpl#route`：后续实现时需确认门禁关闭后的返回值能进入既有 fallback。
- `CenterUtil` 或等价工具类：后续实现时可补齐 AI 自动作业点评配置查询能力。
- 单元测试位置由后续实现按 `juzi-service` 现有测试结构确定，但必须能断言 `sop-reply` FC 未被调用。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录实现和验证任务。
- `checklists/requirements.md` 用于验证规格质量和实施就绪度。
