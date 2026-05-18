# 功能规格：图书 UnionId 补偿与发送

**功能目录**: `019-book-unionid-compensation`  
**创建日期**: 2026-05-18  
**状态**: Implemented  
**输入**: 用户要求在 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\controller\AiController.java` 新增补偿接口，由 `kkhc-bizcenter/schedule` 的定时任务异步触发。补偿范围为当天整天 `create_time` 范围内、`union_id` 为空、`l_ids` 不为空的 `drh_book_question_record`，按 `200` 条一页分页处理。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 定时任务可以异步触发当天图书补偿（优先级：P1）

运营或系统管理员配置 SchedulerX 任务后，任务按计划触发图书补偿接口。job 不等待所有记录补偿完成，只负责异步触发 AI 服务并记录任务提交结果。

**独立测试**：执行新增 job，模拟 AI Feign 调用可用，验证 `process` 提交异步调用后返回 `ProcessResult(true)`，且异步线程会调用图书补偿接口。

**验收场景**：

1. **Given** SchedulerX 触发新增 job，**When** job 开始执行，**Then** job 记录开始日志并提交异步调用。
2. **Given** 异步调用提交成功，**When** job `process` 返回，**Then** 返回 `ProcessResult(true)`，不等待当天所有记录处理完成。
3. **Given** 异步调用提交前发生异常，**When** job 捕获异常，**Then** 返回 `ProcessResult(false)` 并记录失败日志。
4. **Given** 异步线程内部调用 AI 接口失败，**When** job 主流程已返回，**Then** 异步线程记录错误日志，不反向改变本次 job 返回值。

### 用户故事 2 - 图书补偿接口可以补回 unionId 并发送学员消息（优先级：P1）

AI 服务需要按当天数据批量扫描 `drh_book_question_record`，将 `unionId` 补齐后发送给学员。补偿时优先通过 OTS 表 `drh_ai_external_base_info` 的 `phone_number` 找到 `external_user_id`，再通过 `drh_emp_external_user.externalUserid` 找到 `unionId`；如果这条链路缺失，则兜底通过 `drh_applet_user.id`，再按 `phone` 继续补查 `unionId`，随后回写 `drh_book_question_record.union_id` 并发消息。

**独立测试**：构造当天 1 条待补偿记录，验证接口按 `phone_number -> external_user_id -> unionId` 的主链路补回 unionId，主链路未命中时还能通过 `AppletUserDo` 兜底查回 unionId，并成功发送学员消息。

**验收场景**：

1. **Given** 当天存在 `union_id` 为空且 `l_ids` 不为空的图书记录，**When** 调用补偿接口，**Then** 接口会扫描并处理这些记录，按 `200` 条一页分页处理完当天所有记录。
2. **Given** 某条记录的手机号在 OTS 中命中 `external_user_id`，**When** 接口执行到该记录，**Then** 会继续按 `external_user_id` 查询 `drh_emp_external_user` 获取 `unionId`；如果 OTS 未命中，**Then** 会先按 `AppletUserDo.id`，再按 `phone` 兜底查询 `unionId`。
3. **Given** 某条记录拿到了 `unionId`，**When** 补偿成功，**Then** 会回写 `drh_book_question_record.union_id` 并发送学员消息。
4. **Given** 某条记录的 `lIds` 存在多个单号，**When** 发送消息，**Then** 取 `lIds` 数组中最后一个非空单号作为本次发送的 `lId`。

### 用户故事 3 - 补偿发送的消息内容要和参考实现一致（优先级：P1）

发送给学员的消息必须和 `C:\workspace\drh\drh-media-process\src\main\java\drh\media\process\service\impl\ExternalBookQuestionRecordServiceImpl.java` 的 `sendMsgStudent` 保持一致，链接使用 `logisticsDetailV2.html`，`type` 固定为 `1`，热线固定为 `4006689062`。

**独立测试**：对比补偿接口最终发送的正文，验证其结构、链接、`type=1` 和热线号与参考实现一致。

**验收场景**：

1. **Given** 记录的 `aesId` 有值，**When** 发送学员消息，**Then** 文案中必须包含 `https://kk1.likeduoduiyi.cn/logisticsDetailV2.html?aesId={aesId}&type=1`。
2. **Given** 学员消息发送成功，**When** 查看日志，**Then** 能看到记录 id、手机号、`lId`、`external_user_id` 和 `unionId`。
3. **Given** 单条消息发送失败，**When** 接口继续处理下一条，**Then** 不应因为一条失败阻断后续记录。
4. **Given** 数据缺失导致无法发送，**When** 记录被跳过，**Then** 日志应明确说明跳过原因，便于排查。

## 边界情况

- SchedulerX job 重复触发，上一轮异步批处理尚未完成。
- 补偿接口当日无可处理记录。
- 当天待处理记录超过 `200` 条，会继续分页处理后续记录，直到当天数据处理完毕。
- 某条记录的 `phone` 为空。
- 某条记录的 `lIds` 为空、格式非法或无法解析出有效单号。
- OTS 表 `drh_ai_external_base_info` 中找不到对应手机号。
- `drh_emp_external_user` 中找不到对应 `externalUserid` 或 `unionId` 为空。
- `drh_book_question_record.union_id` 回写失败。
- 消息发送失败、返回空结果或抛出异常。
- `aesId` 为空，导致消息链接无法正确拼接。

## 需求 *(必填)*

### 功能需求

- **FR-001**：`kkhc-bizcenter/schedule` MUST 新增 SchedulerX job，继承 `JavaProcessor`，并通过异步线程调用 AI 补偿接口。
- **FR-002**：新增 job MUST 在异步任务提交成功后立即返回 `ProcessResult(true)`，不得等待批量处理结束。
- **FR-003**：新增 job MUST 在提交前异常时返回 `ProcessResult(false)` 并记录失败日志。
- **FR-004**：`kkhc-idc/ai` MUST 新增图书补偿接口，控制器落点为 `AiController`，路径为 `/ai/book/question/compensation/send`。
- **FR-005**：补偿接口 MUST 只处理当天零点之后、`union_id` 为空、`l_ids` 不为空的 `drh_book_question_record`。
- **FR-006**：补偿接口 MUST 按 `200` 条一页分页处理当天记录。
- **FR-007**：补偿接口 MUST 从 `lIds` 中取最后一个有效物流单号作为本次发送的 `lId`。
- **FR-008**：补偿接口 MUST 先通过 OTS 表 `drh_ai_external_base_info` 的 `phone_number` 查询 `external_user_id`，命中后再继续后续链路。
- **FR-009**：补偿接口 MUST 通过 `drh_emp_external_user.externalUserid` 获取 `unionId`，若主链路未命中，MUST 再按 `AppletUserDo.id` 与 `phone` 兜底查 `unionId`。
- **FR-010**：补偿接口 MUST 将获取到的 `unionId` 回写到 `drh_book_question_record.union_id`。
- **FR-011**：补偿接口 MUST 发送学员消息，消息正文 MUST 与参考实现 `sendMsgStudent` 保持一致，链接使用 `logisticsDetailV2.html`，`type=1`，热线为 `4006689062`。
- **FR-012**：单条记录在 OTS 未命中、`AppletUserDo` 兜底未命中、`unionId` 未命中、`lIds` 异常、`aesId` 缺失、更新失败或发送失败时 SHOULD 记录日志并继续处理后续记录。
- **FR-013**：实现阶段 MUST 不新增数据库表、公共 DTO 或配置项。
- **FR-014**：`drh_ai_external_base_info` 的 TableStore 索引命名 SHOULD 遵循项目现有约定；如实际索引名不同，仅调整常量，不改流程。

## 成功标准 *(必填)*

### 可衡量结果

- **SC-001**：SchedulerX job 100% 通过异步线程触发 AI 补偿接口。
- **SC-002**：job 提交成功时不等待完整批处理结束即可返回成功。
- **SC-003**：补偿接口可正确筛出当天待处理的图书记录，并按 `200` 条一页分页处理完毕。
- **SC-004**：命中手机号的记录可 100% 完成 `phone_number -> external_user_id -> unionId` 主链路，未命中时可通过 `AppletUserDo` 兜底补齐。
- **SC-005**：成功命中的记录可 100% 回写 `drh_book_question_record.union_id` 并发送学员消息。
- **SC-006**：消息正文与参考实现一致，`type=1` 与热线号 `4006689062` 不偏离。
- **SC-007**：单条失败不会阻断后续记录处理。
- **SC-008**：实现完成后可通过 `mvn -f kkhc/kkhc-idc/pom.xml -pl ai -am -DskipTests compile` 和 `mvn -f kkhc/kkhc-bizcenter/pom.xml -pl schedule -am -DskipTests compile` 编译验证。

## 假设

- 当天的判定以服务端本地时间的零点为准。
- `lIds` 以 JSON 数组字符串形式存储，最后一个有效元素即本次发送单号。
- `drh_emp_external_user.externalUserid` 与 OTS 查到的 `external_user_id` 一一对应；若 OTS 未命中，则允许通过 `AppletUserDo.id` 与 `phone` 兜底补充 `unionId`。
- 学员消息沿用参考实现，不新增文案分支。
- OTS 表 `drh_ai_external_base_info` 使用项目现有 TableStore 命名约定；若实际索引名不同，只调整常量。
