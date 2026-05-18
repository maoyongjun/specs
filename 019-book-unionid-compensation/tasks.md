# 任务清单：图书 UnionId 补偿与发送

**输入**：来自 `specs/019-book-unionid-compensation/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：通过 `mvn -f kkhc/kkhc-idc/pom.xml -pl ai -am -DskipTests compile` 与 `mvn -f kkhc/kkhc-bizcenter/pom.xml -pl schedule -am -DskipTests compile` 验证 AI 补偿链路和 schedule job / Feign 接入。

## Phase 1：规格与范围

- [x] T001 创建 `specs/019-book-unionid-compensation` 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确 AI 控制器补偿接口路径为 `/ai/book/question/compensation/send`
- [x] T003 明确 schedule 侧使用 Feign + SchedulerX job 异步触发
- [x] T004 明确按当天范围分页处理，页面大小为 `200`

## Phase 2：AI 补偿实现

- [x] T005 在 `AiServiceImpl` 中增加当天待补偿图书记录查询、`unionId` 回写和学员消息发送逻辑
- [x] T006 通过 OTS 表 `drh_ai_external_base_info.phone_number` 获取 `external_user_id`
- [x] T007 通过 `drh_emp_external_user.externalUserid` 获取 `unionId`
- [x] T008 解析 `lIds` 并使用最后一个有效 `lId`
- [x] T009 学员消息正文与参考实现 `sendMsgStudent` 保持一致，`type=1`、热线 `4006689062`
- [x] T010 单条异常跳过并继续后续记录处理

## Phase 3：Schedule 接入

- [x] T011 新增 `BookQuestionRecordFeign`
- [x] T012 新增 `BookQuestionRecordCompensationJob`
- [x] T013 job 异步提交成功后立即返回 `ProcessResult(true)`
- [x] T014 job 异步线程内部捕获并记录接口调用异常

## Phase 4：验证

- [x] T015 运行 `mvn -f kkhc/kkhc-idc/pom.xml -pl ai -am -DskipTests compile`
- [x] T016 运行 `mvn -f kkhc/kkhc-bizcenter/pom.xml -pl schedule -am -DskipTests compile`
- [x] T017 复核 `200` 条分页、消息模板、日志和异常继续处理行为
- [x] T018 记录本轮验证结论
