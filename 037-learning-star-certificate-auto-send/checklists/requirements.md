# 规格质量检查清单：学习之星奖状自动圈选与发送

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-05-28`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目、模块、入口和核心实现位置。
- [x] 明确用户目标、成功标准和非目标。
- [x] 明确新增、修改和禁止改变的行为。
- [x] 明确日志、时间、幂等、fallback、兼容性和异常处理要求。
- [x] 明确图片必须上传 OSS，并使用 OSS/CDN URL 作为图片消息地址。
- [x] 明确发送分散使用 RocketMQ 延迟消息；MQ 消费后使用累计 `doTaskWithDelay` 调度图片和合并文字。
- [x] 明确 RocketMQ topic 使用共有 `mq.delay.topic`，tag 使用新的学习之星 tag，consumer group 配置方式参考 `delay-consumer-group: GID_delay_book_logistics_test`。
- [x] 明确图片生成使用并发执行（最大并发 4 + MDC 追踪），RocketMQ 投递在并发完成后主线程串行执行。并发安全性已确认：渲染器 effectively immutable，`render()` 无共享可变状态，`OssUtil.upload()` 底层线程安全。
- [x] 明确 WX_004 奖状发送完成通知（`common_warn_sender` FC + 模板变量 `{sendNums}`），发送失败不影响主流程。
- [x] 明确后续实现必须增加测试或静态验证记录。

## 需求完整性

- [x] 无待澄清标记或未替换占位内容残留。
- [x] 需求可测试且主要业务口径已拆解，包括非图书 D3 与图书 D4 的完课/到课标签规则。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖正常路径、边界路径和不回归路径。
- [x] 边界情况已识别，并明确跳过、兜底、失败或记录日志的策略。

## 参数完整性门禁

- [x] 已列出关键参数来源和赋值时机。
- [x] 已列出下游读取字段清单。
- [x] 已说明不得使用未解释的空 DTO、空 JSON、空 Map 或占位参数。
- [x] 已要求下游读取字段在调用前赋值，或在当前层现算现用。
- [x] 已识别调用顺序风险：图片生成和 URL 成功前不得发送文字。
- [x] 已识别延迟乱序风险：每个学员投递一条整组 RocketMQ 延迟消息，消费时按图片、合并文字顺序发送。
- [x] 已给出外部调用、FC、OTS、Redis、OSS、RocketMQ 共有 topic / 新 tag / consumer group 和数据库查询的关键参数断言方案。
- [x] 已记录需要编码前确认的业务语义：`qwUserId` 来源、完课/到课真实标签名、好友状态过滤、渠道缺失策略、SchedulerX 时间。

## 实施就绪度

- [x] 实现范围已限定在 `kkhc-idc-ai` 和 `kkhc-bizcenter\schedule`。
- [x] 默认不新增数据库表、不修改 MQ/Redis/FC 契约，除非后续规格明确变更。
- [x] 已确认旧逻辑中必须保持不变的图书物流、文字发送、AI 权限和 demo 方案。
- [x] 每个关键需求至少有一条测试、编译或静态验证任务。
- [x] 单元测试计划覆盖 OSS URL 下传、RocketMQ 延迟范围、单学员单条整组消息、消费顺序发送和必要日志计数。
- [x] 单元测试计划避免真实访问 Redis、OTS、Center、RocketMQ、FC、OSS 或外部 HTTP，除非规格明确要求联调。
- [x] 文档已同步 `spec.md`、`tasks.md` 和 `AGENTS.md`。

## 编码前未完成项

- [ ] 确认 `drh_live_camp_emp.ai_status` 的真实字段名与 DO/Mapper 可用性。
- [ ] 确认 `follow_user.userid` 对应销售字段，优先验证 `KkEmpDo.qyvxUserId`。
- [ ] 确认 `D1 完课`、`D2 完课`、`D3 到课` 的真实 `tag_name` / `group_name`。
- [ ] 确认好友关系是否增加 `status = 0`。
- [ ] 确认渠道完全缺失时业务是否接受跳过。
- [ ] 确认学习之星 RocketMQ 延迟消息的 `MessageType`、新 tag 和 consumer group 实际命名；topic 已明确复用共有 `mq.delay.topic`。
- [ ] 确认 SchedulerX 运行频率和上线配置。
- [x] 确认 WX_004 通知的 `external_key` 由 `externalUserId:empId:campDateId:qwUserId` 组成，所有字段可获取，通知按营期候选维度发送。
- [ ] 确认 `common_warn_sender` 接收模板变量的字段名。
- [ ] 确认 WX_004 模板已在 `common_warn_sender` 后台配置完毕，变量名为 `sendNums`。

## 备注

- 本清单完成的是规格质量检查，不代表业务代码已经实现。
- 强制门禁未完成前，不进入实现。
