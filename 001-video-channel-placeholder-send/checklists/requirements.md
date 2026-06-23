# 规格质量检查清单：视频号占位消息拆分发送

**用途**：在进入计划或实现前验证规格完整性和质量  
**创建日期**：2026-04-29  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 规格聚焦用户可见行为：文本、图片、视频号按顺序拆分发送
- [x] 明确记录视频号占位符格式 `##{channels:V18}` 和大小写规则
- [x] 明确记录条件文本占位符格式 `##{text:...}` 和紧邻视频号绑定规则
- [x] 明确记录视频号 7 天限发口径：同一外部联系人、同一企微员工、同一视频号编码
- [x] 明确记录配置台 `VIDEO_CHANNEL` 动作只配置 `V15` 这类编码，发送端再转真实视频号 payload
- [x] 明确记录配置台编码规范化规则：trim 后按 `V` 加数字校验并统一大写
- [x] 明确记录函数计算 `SEND_MESSAGE` 请求体边界和 token 处理边界
- [x] 面向产品、测试和开发均可读
- [x] 所有必填章节已完成

## 需求完整性

- [x] 无 [NEEDS CLARIFICATION] 标记残留
- [x] 需求可测试且无歧义
- [x] 成功标准可衡量
- [x] 成功标准与用户可见结果绑定
- [x] 所有验收场景已定义
- [x] 边界情况已识别
- [x] 范围边界清晰：D004 仅更新 spec-kit 文档；业务实现需在后续确认后按 Phase 9-12 执行
- [x] 依赖和假设已识别

## 功能就绪度

- [x] 所有功能需求都有清晰验收条件
- [x] 用户场景覆盖占位符解析、顺序发送、OSS JSON 获取、Redis 缓存、7 天限发、条件文本绑定、双模块复用和配置台 `VIDEO_CHANNEL` 动作
- [x] 功能满足成功标准中定义的可衡量结果
- [x] 规格文档与任务清单职责分离
- [x] 原始实现范围已限定为 `fc/common`、`fc/ai-reply`、`fc/delay-mq`
- [x] D004 后续实现范围已扩展并限定为 `data-RC/juzi-service`、`fc/sop-reply`，继续复用 `fc/common`
- [x] 配置台 JSON 合同明确：`VIDEO_CHANNEL` 输出 `videoChannelCode`，不输出真实视频号 payload
- [x] 存储边界明确：不新增表字段，视频号编码复用 `text_content`
- [x] 发送边界明确：`sop-reply` 和 `HomeWorkCommentService` 复用 common 视频号工具构造 `messageType=14`
- [x] 回归边界明确：`TEXT`、`VOICE`、`IMAGE`、`PDF`、`RANDOM_EMOJI` 的保存、JSON 输出、delay、条件匹配和发送行为保持不变

## 备注

- 本次按参考目录 `C:\workspace\tiangong\codes\tiangong-ai-w3\specs` 的 Spec Kit 文档方式补充 `AGENTS.md`、`spec.md` 和 `checklists/requirements.md`。
- 按用户要求，本目录暂不生成 `tasks.md`；任务清单稍后由计划功能生成。
- 2026-04-29 已生成并执行 `tasks.md`，目标回归 `mvn -pl common,delay-mq,ai-reply -am test` 通过。
- 2026-05-06 增量补充视频号 7 天限发需求，范围仍限定为 `fc/common`、`fc/ai-reply`、`fc/delay-mq`。
- 2026-05-06 二次增量补充 `##{text:...}` 条件文本需求，条件文本只绑定紧邻后一个视频号。
- 2026-06-23 D004 增量补充作业点评配置台 `VIDEO_CHANNEL` 动作、`sop-reply` 配置发送链路和 `HomeWorkCommentService` 旧链路按编码发送视频号能力；实现与回归已完成，验证命令为 `mvn -pl common,sop-reply -am test`、`mvn -pl juzi-service -DskipTests=false test`。
