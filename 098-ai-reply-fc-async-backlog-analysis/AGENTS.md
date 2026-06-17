# 规格执行说明

本目录为「ai-reply 函数计算异步请求积压」根因分析与优化建议规格。本规格以**分析与方案**为交付物，不在本阶段直接改动业务代码；任何代码改动需先经用户确认后另起实现记录。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\098-ai-reply-fc-async-backlog-analysis`
- 目标项目：`C:\workspace\ju-chat\fc\ai-reply`（Aliyun 函数计算 Java Handler，Java 8）
- 相关模块：
  - 异步入口 `com.drh.delay.consumer.service.AppTask`
  - AI 调用核心 `com.drh.delay.consumer.util.CozeUtil`
  - 限速器 `com.drh.delay.consumer.util.RateLimitUtil`
  - Redis 访问 `com.drh.delay.consumer.util.RedisClient` / `RedisConnectionPool`
- 证据来源：
  - 监控面板：`异步请求积压数`，2026-06-16 15:12:00 积压 426、处理中 31
  - 日志：`C:\workspace\55dd9b1e-2a13-4302-a6c9-0eec893d041c.csv`（13053 行，含 FCRequestMetrics / FCInstanceMetrics 指标行与应用日志行，时间 2026-06-16 14:50:03 ~ 16:04:55）

## 当前目标

- 目标 1：基于日志指标与源码事实，定位 ai-reply 异步请求积压的根因与放大因素。
- 目标 2：量化关键瓶颈指标（单请求时长、实际并发、完成速率、限速口径），给出可衡量的结论。
- 目标 3：给出分层优化建议（架构层 / 配置层 / 代码层），并标注每条建议是否触及强制门禁、是否需用户确认。

## 执行原则

- 先读代码、再看指标、后下结论；所有结论必须能对应到具体日志数字或源码行。
- 不臆测函数计算后台配置（实例并发、最大实例数、异步队列配置）——无法从仓库代码确认的，列为「待向运维/控制台核实」的假设。
- 优化建议中凡涉及调用顺序、远程调用、MQ、Redis key/TTL、函数并发与触发器配置变更，均标记为「需确认」，不在本规格阶段实施。

## 强制门禁（本规格为分析类，门禁聚焦在「建议是否安全」）

- 参数来源：分析不改参数，但优化建议若引入新参数/新调用，必须说明来源与赋值时机。
- 占位对象：建议中不得出现以空 DTO / 空 JSON / 空 Map 作为占位下传的方案。
- 影响范围：每条建议必须标注是否影响调用顺序、接口契约、远程调用、MQ body、Redis key/TTL、数据库写入或异步行为。
- 测试映射：凡进入实现的建议，必须附「下游参数断言」测试方案（断言 Coze 入参、juzi-api FC 入参、Redis key/TTL、限速计数口径），不能只断言最终回复结果。
- 纠正记录：用户每次补充/纠正口径，追加 Dxxx，并同步 `spec.md`/`tasks.md`/`checklist`。

## 重点代码位置

- 入口：`AppTask.handleRequest`（fc/ai-reply/src/main/java/com/drh/delay/consumer/service/AppTask.java:61）
- 阻塞 AI 流：`CozeUtil.generateAndSendRetry` → `coze.chat().stream(req)` + `blockingForEach`（CozeUtil.java:443、CozeUtil.java:461-531）
- 同会话串行等待：`CozeUtil.waitCanRun`（CozeUtil.java:299-328）
- 全局限速：`RateLimitUtil.limitRun`（RateLimitUtil.java:8-59）
- OkHttp/CozeAPI 客户端构造与超时：`CozeUtil` 构造方法（CozeUtil.java:112-148）、static dispatcher（CozeUtil.java:78-100）
- Redis 连接获取与 select：`RedisClient`（RedisClient.java:20-24）

## 文档维护

- `spec.md`：积压现象、根因链、防漏分析、需求（分析结论 + 优化建议）、成功标准、假设、执行记录。
- `tasks.md`：代码事实确认 → 风险门禁 → （建议落地时的）实现/测试任务。
- `checklists/requirements.md`：规格质量与参数完整性门禁。
- 每次用户纠正或补充，追加 Dxxx 并同步全部文档。
