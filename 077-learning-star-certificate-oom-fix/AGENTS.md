# 规格执行说明

本目录记录 `kkhc-idc-ai` 学习之星奖状自动发送链路的 OOM 修复。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\077-learning-star-certificate-oom-fix`
- 目标项目：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`
- 核心实现：
  - `com.kkhc.idc.crm.service.ai.impl.LearningStarCertificateServiceImpl`
  - `com.kkhc.idc.crm.service.ai.learningstar.LearningStarCertificateRenderer`
  - `mapper/camp/LiveCampDateMapper.xml`

## 当前目标

- 修复学习之星奖状处理候选营期时的 `java.lang.OutOfMemoryError: Java heap space`。
- 将营期和学员处理改为有界扫描、分批预检、分批渲染和分批投递。
- 修复并发渲染后图片 URL 没有回填到 MQ 入参的问题。
- 修复 WX_004 通知数量口径，按成功投递 MQ 的学员数统计。

## 执行原则

- 不新增对外 API，不修改 MQ message type、tag、Redis key 前缀和消费者契约。
- 不扩大业务圈选口径；D3/D4、渠道、OTS 标签、幂等、延迟发送和测试发送规则保持不变。
- 学员处理必须有批次边界，不能为整营期一次性保留全部学员、预检结果、future 或渲染结果。
- 图片消息投递前必须确认 `certificateImageUrl` 与图片消息 `url` 非空且一致。
- 渲染器优化只能降低重复分配和校验开销，不能改变奖状尺寸、字体、背景和内容。

## 强制门禁

- 参数来源：`campDateId/chatId/startTime/classTime` 来自候选营期；`studentBatchSize/renderBatchSize` 来自配置并在运行时 clamp。
- 赋值时机：`certificateUrl` 必须在渲染成功后再写入 `LearningStarDelaySendInput` 和消息列表。
- 占位对象：禁止将 `certificateUrl = null` 的图片消息下传到 RocketMQ 或 FC。
- 下游读取：MQ 投递读取的 `externalUserId/unionId/qyvxUserId/corpId/certificateImageUrl/messages` 必须在投递前完整。
- 旧逻辑保持：渠道判断、D3/D4、OTS 标签、Redis 幂等、FC 延迟调度、已发奖状打标和测试发送入口保持。
- 测试映射：必须覆盖分批处理、URL 回填、异常隔离、WX_004 统计口径和渲染器连续渲染。

## 文档维护

- `spec.md` 描述需求、边界、成功标准、假设和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行结果。
- `checklists/requirements.md` 验证规格质量和实施就绪度。
- 后续若调整批次默认值、扩大候选 SQL 过滤口径或改变发送幂等策略，必须追加纠正记录。
