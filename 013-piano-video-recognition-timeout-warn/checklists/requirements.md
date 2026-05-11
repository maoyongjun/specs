# 规格质量检查清单：钢琴视频识别超时与异常告警

**用途**：验证钢琴视频识别超时与异常告警需求完整性和实现可测性  
**创建日期**：2026-05-11  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标代码文件。
- [x] 明确目标方法为 `PianoVideoHomeWorkHandleServiceImpl#handle`。
- [x] 明确首次等待窗口为 10 分钟。
- [x] 明确首次超时后不再进行 7 分钟延迟。
- [x] 明确首次超时后不再调用 `triggerAsyncRecognitionIfNeeded` 重试。
- [x] 明确首次超时后发送告警。
- [x] 明确钢琴视频识别处理链路异常也发送告警。
- [x] 明确异常告警范围包含异步提交异常、非法异步提交返回值、等待轮询异常、缓存读写异常、结果解析异常和等待线程中断。
- [x] 明确异常告警与明确业务失败状态的边界。
- [x] 明确告警编号为 `WX003`。
- [x] 明确告警变量 `campName` 和 `userName` 由 `common_warn_sender` 内部补齐。
- [x] 明确同一 `externalKey` 5 分钟内只告警一次。
- [x] 明确去重 key 前缀和 300 秒过期时间。
- [x] 明确 Redis 去重异常时继续告警。
- [x] 明确参考实现为 `AppTask#notifyBookRegisterWarn`。
- [x] 所有必填章节已完成。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 标记残留。
- [x] 需求可测试且无歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖首次超时、告警发送、告警入参和不重试。
- [x] 验收场景覆盖识别处理异常、异常告警发送、异常告警失败捕获和返回空结果。
- [x] 验收场景覆盖 5 分钟去重命中和 Redis 异常降级。
- [x] 边界情况已识别。

## 实施就绪度

- [x] 实现范围限定在 `fc/sop-reply` 模块。
- [x] 不涉及数据库表结构、OTS 表结构、Redis key 结构或配置中心接口调整。
- [x] 明确 `common_warn_sender` 告警调用格式。
- [x] 明确需要编译检查。
- [x] `PianoVideoHomeWorkHandleServiceImpl.java` 已按原超时规格移除延迟重试。
- [x] `PianoVideoHomeWorkHandleServiceImpl.java` 已按原超时规格发送 `WX003` 告警。
- [x] `PianoVideoHomeWorkHandleServiceImpl.java` 已按同一 `externalKey` 5 分钟去重。
- [x] 原超时告警实现已通过 `fc/sop-reply` 模块编译验证。
- [x] `PianoVideoHomeWorkHandleServiceImpl.java` 已按增量规格补充异常告警实现。
- [x] 异常告警实现已通过 `fc/sop-reply` 模块编译验证。
- [x] 异常告警实现已验证同一 `externalKey` 5 分钟去重。

## 备注

- 已完成原超时告警业务代码实现。
- 当前业务代码已从“10 分钟超时后 7 分钟延迟并单次重试”调整为“10 分钟超时后告警且不重试”。
- 当前业务代码已实现同一 `externalKey` 5 分钟内最多尝试发送一次 `WX003`。
- 本次新增“异常也需要告警”为增量规格，已完成文档更新、业务代码实现和编译验证。
