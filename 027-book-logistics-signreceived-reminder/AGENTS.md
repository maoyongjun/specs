# 规格执行说明

本目录是图书物流签收标签与暂存提醒的 Spec Kit 文档。后续实现必须先读本说明，再按 `spec.md` 和 `tasks.md` 执行。

## 作用范围

- 规格目录：`C:\workspace\ju-chat\specs\027-book-logistics-signreceived-reminder`
- 定时任务模块：`C:\workspace\ju-chat\kkhc\kkhc-bizcenter\schedule`
- 业务实现模块：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`
- 延迟队列参考：`C:\workspace\ju-chat\data-RC\juzi-service`
- agent workflow 参考：`C:\workspace\ju-chat\fc\homework-review\src\main\java\com\drh\homework`

## 必读参考代码

- schedule Job 参考：`kkhc\kkhc-bizcenter\schedule\src\main\java\com\kkhc\bizcenter\schedule\task\book\BookQuestionRecordCompensationJob.java`
- schedule Feign 参考：`kkhc\kkhc-bizcenter\schedule\src\main\java\com\kkhc\bizcenter\schedule\feign\book\BookQuestionRecordFeign.java`
- AI Controller 参考：`kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\controller\AiController.java`
- AI Service 参考：`kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\AiService.java`
- AI Service 实现参考：`kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\impl\AiServiceImpl.java`
- unionId 获取参考：`AiServiceImpl.compensateBookQuestionRecordUnionIdAndSend`，并补充 `drh_applet_user` / `drh_live_user` / `drh_emp_external_user` 兜底链路
- OTS 手机号映射参考：`kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\lms\utils\OtsUtil.java`
- 延迟队列参考：`data-RC\juzi-service\src\main\java\com\drh\data\juzi\service\impl\DelayMessageServiceImpl.java`
- AI 模块延迟生产者：`kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\lms\mq\producer\DelayProducerBean.java`
- agent workflow 参考：`fc\homework-review\src\main\java\com\drh\homework\service\SopHomeWorkHandleService.java`
- ShowAPI 参考：`kkhc\kkhc-bizcenter\app\src\main\java\com\kkhc\bizcenter\app\service\order\impl\CollectOrderServiceImpl.java`
- ShowAPI DTO 参考：`kkhc\kkhc-bizcenter\app-common\src\main\java\com\kkhc\bizcenter\app\common\dto\output\order`

## 固定实现口径

- 定时任务只放在 `kkhc-bizcenter\schedule`。
- 业务处理只放在 `kkhc-idc\ai`。
- 后续实现需要新增 AI 处理接口，供 schedule Feign 调用。
- 处理数据源只有 `drh_book_question_record` 和 `drh_external_book_question_record`。
- 只处理 `drh_goods.category = 4` 的钢琴物流。
- `sign_status` 字段固定为：
  - `0`：已发货
  - `1`：已暂存待签收
  - `2`：已签收
- `notice_msg` 只保存 agent 改写后的最终提醒文案。
- `notice_send_status` 字段固定为：
  - `0`：未发送
  - `1`：已发送
- `isOver` 不参与本需求物流状态流转。

## ShowAPI 口径

- 快递公司识别接口：`https://route.showapi.com/2650-6`
- 物流详情接口：`https://route.showapi.com/2650-3`
- 请求方式按现有 `CollectOrderServiceImpl` 使用 `postForm`。
- `2650-6` 参数：`appKey`、`nu`。
- `2650-3` 参数：`appKey`、`nu`、`com`、`phone`。
- `appKey` 使用 `book.logistics.showapi.app-key`，当前实现保留现有 appKey 默认兼容值。
- `phone` 使用手机号后四位。
- ShowAPI 最新轨迹 `status = 104` 表示已签收。
- ShowAPI 最新轨迹 `status = 112` 表示暂存待签收。

## unionId 与主体映射

- 通过手机号优先调用 `otsUtil.getExternalUserIdByPhoneNumber(phone)` 获取 `externalUserId`，未命中时按 `drh_applet_user` / `drh_live_user` 兜底。
- OTS 命中时通过现有 `getEmpExternalUserDO(externalUserId)` 获取 `EmpExternalUserDO`；兜底时通过 `drh_emp_external_user` 最新好友关系补齐。
- 从 `EmpExternalUserDO.unionId` 获取 `unionId`。
- 从 `EmpExternalUserDO.empId` 查询 `drh_kk_emp`。
- 从 `drh_kk_emp.qyvxUserId` 获取销售企微用户 id。
- 从 `drh_kk_emp.company` 获取主体 id。
- 查询“已签收”标签时必须使用 `drh_qw_tag.name = '已签收' AND drh_qw_tag.source = company`。
- 不允许只按标签名称查询后跨主体复用 tagId。

## 延迟队列口径

- 使用已有 ONS 延迟队列，不新增 topic。
- 本业务使用独立 tag：`BOOK_LOGISTICS_TEMP_STORAGE_NOTICE`。
- AI 模块自建 delay consumer，不改 `scrm`。
- `DelayProducerBean.sendTagMessage` 已修正为显式发送带自定义 tag 的 `Message`。
- MQ payload 只放 `recordType`、`recordId`，消费时重新查库取最新状态和上下文。
- 延迟时间为当前时间加随机 `0-40` 分钟。
- consumer 发送前必须重新读取记录，`sign_status = 2` 或 `notice_send_status = 1` 时跳过。

## agent workflow 口径

- 参考 `SopHomeWorkHandleService.invokeCozeWorkFlow` 的 `works_flow` 调用结构。
- `serviceName = ai-service`。
- `functionName = works_flow`。
- `worksFlowId` 使用本业务独立配置 `book.logistics.notice.workflow-id`。
- `botId` 使用本业务独立配置 `book.logistics.notice.bot-id`。
- 输入必须包含快递名称、快递单号和最后一条物流轨迹。
- 输出必须是可直接发送给学员的简短提醒文案。
- agent 失败、超时或返回空文案时，不投递延迟消息。

## 实施门禁

- ShowAPI 签收/暂存识别规则固定为 `104/112`，不得改为文案模糊匹配。
- 不得硬编码 tagId、workflow id。
- 不得在未拿到 `unionId` 时发送暂存提醒。
- 不得在 OTS 未命中时直接放弃解析，必须按 `drh_applet_user -> drh_live_user -> drh_emp_external_user` 兜底。
- 不得跨主体查询或复用“已签收”标签。
- 不得绕过 `drh_goods.category = 4` 过滤。
- 不得让 `sign_status = 2` 的记录继续发送暂存提醒。
- 不得让 `notice_send_status = 1` 的记录继续发送暂存提醒。
- 不得在发送成功后不回写 `notice_send_status = 1`。
- 不得只断言最终结果；测试必须断言 ShowAPI 参数、agent 入参、MQ tag、打标签 tagId 和发送前幂等检查。

## 文档维护

- 用户补充接口、字段、状态码或流程时，必须同步更新 `spec.md`、`tasks.md` 和 `checklists\requirements.md`。
- 实现后在 `tasks.md` 的执行记录补充改动摘要、测试命令、测试结果和剩余风险。
