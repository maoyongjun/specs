# 规格质量检查清单：juzi-service SOP 点评开关门禁

**用途**：验证 SOP 点评开关门禁需求完整性和后续实现可测性  
**创建日期**：2026-05-19  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标模块为 `data-RC/juzi-service`。
- [x] 明确参考实现为 `fc/delay-mq/.../AppTask.java`。
- [x] 明确门禁适用于除 `skuId=5` 外所有命中 SOP 点评的 SKU，不限制为 `skuId=4`。
- [x] 明确 `skuId=5` 是门禁例外，不校验开关状态和群 ID 白名单。
- [x] 明确 `aiStatus == 1` 才视为 AI 开启。
- [x] 明确 `aiAutoReview == 1` 才视为作业点评开启。
- [x] 明确除 `skuId=5` 外，两个开关都开启是调用 `sop-reply` 的共同前置条件。
- [x] 明确除 `skuId=5` 外，关闭、空配置、异常配置均不调用 `sop-reply`。
- [x] 明确异步 SOP 调用和同步 SOP 评估两个入口都要受控。
- [x] 明确群聊 SOP 点评还必须校验 `roomWecomChatId` 命中 `chatList`。
- [x] 明确群 ID 校验逻辑仿照 `AppTask.java#isGroupOpen`。
- [x] 明确单聊 SOP 点评不要求校验群 ID。
- [x] 明确非 SOP 点评链路行为不变。
- [x] 明确门禁拦截后交由现有路由 fallback 规则处理。
- [x] 明确后续实现必须增加单元测试。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 标记残留。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖 `skuId=4`、`skuId=5` 例外和其他 SOP SKU。
- [x] 验收场景覆盖开关全开、AI 关闭、作业点评关闭、配置异常和 `skuId=5` 不校验开关。
- [x] 验收场景覆盖异步 `sop-reply` 调用路径。
- [x] 验收场景覆盖同步 SOP 评估路径。
- [x] 验收场景覆盖群 ID 命中、未命中、空群列表和空群 ID。
- [x] 验收场景覆盖单聊不因缺少群 ID 被拦截。
- [x] 验收场景覆盖非 SOP 点评链路不回归。
- [x] 验收场景覆盖单元测试要求。
- [x] 边界情况已识别。

## 实施就绪度

- [x] 实现范围限定为 `data-RC/juzi-service`。
- [x] 本次不修改 `fc/sop-reply` 内部逻辑。
- [x] 本次不新增数据库表。
- [x] 本次不新增对外接口。
- [x] 明确后续实现需要补齐或复用 AI 自动作业点评配置查询能力。
- [x] 明确后续实现需要补齐或复用群聊 `isGroupOpen` 等价判断。
- [x] 明确后续实现需要记录可检索拦截日志。
- [x] 明确后续实现需要编译验证 `data-RC/juzi-service`。
- [x] 明确后续实现需要增加可执行单元测试。

## 备注

- 当前阶段仅完成文档，未进行代码实现。
- 开启值沿用 `AppTask.java` 现有口径：`1` 表示开启，其他值或空值均视为未开启；`skuId=5` 例外不校验该状态。
- 群 ID 匹配沿用 `AppTask.java#isGroupOpen` 的精确包含口径：`chatList.contains(roomWecomChatId)`；`skuId=5` 例外不因群 ID 未命中被拦截。
