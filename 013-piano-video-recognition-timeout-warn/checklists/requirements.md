# 规格质量检查清单：钢琴视频识别超时告警

**用途**：验证钢琴视频识别超时告警需求完整性和实现可测性  
**创建日期**：2026-05-11  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标代码文件。
- [x] 明确目标方法为 `PianoVideoHomeWorkHandleServiceImpl#handle`。
- [x] 明确首次等待窗口为 10 分钟。
- [x] 明确首次超时后不再进行 7 分钟延迟。
- [x] 明确首次超时后不再调用 `triggerAsyncRecognitionIfNeeded` 重试。
- [x] 明确首次超时后发送告警。
- [x] 明确告警编号为 `WX003`。
- [x] 明确告警变量 `campName` 和 `userName` 由 `common_warn_sender` 内部补齐。
- [x] 明确参考实现为 `AppTask#notifyBookRegisterWarn`。
- [x] 所有必填章节已完成。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 标记残留。
- [x] 需求可测试且无歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖首次超时、告警发送、告警入参和不重试。
- [x] 边界情况已识别。

## 实施就绪度

- [x] 实现范围限定在 `fc/sop-reply` 模块。
- [x] 不涉及数据库表结构、OTS 表结构、Redis key 结构或配置中心接口调整。
- [x] 明确 `common_warn_sender` 告警调用格式。
- [x] 明确需要编译检查。
- [x] `PianoVideoHomeWorkHandleServiceImpl.java` 已按新规格移除延迟重试。
- [x] `PianoVideoHomeWorkHandleServiceImpl.java` 已按新规格发送 `WX003` 告警。
- [x] `fc/sop-reply` 模块已编译验证通过。

## 备注

- 已完成业务代码实现。
- 当前业务代码已从“10 分钟超时后 7 分钟延迟并单次重试”调整为“10 分钟超时后告警且不重试”。
