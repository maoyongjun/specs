# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\036-phone-security-save-query`
- 目标工程 1：`C:\workspace\drh`（主业务微服务，多模块 Spring Cloud 项目）
  - 相关模块：`drh-common`（实体 + DataSecurity 工具）、`drh-pay`（订单创建）、`drh-endpoint`（用户端 API）、`drh-kk-cms`（CMS 后台）、`drh-callback`（支付回调）、`drh-media-process`（批处理）
- 目标工程 2：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`（AI 模块）
  - 相关模块：`ai-common`（实体）、`ai`（Service / Mapper / Controller）
- 前置需求：`032-phone-security-columns`（DDL 已完成，测试库已执行）

## 当前目标

- 在 `H5Order`（drh-common）/ `H5OrderDO`（ai-common）和 `BookQuestionRecord`（drh-common）/ `BookQuestionRecordDO`（ai-common）的实体类中增加 `phoneMask`、`phoneMd5`、`phoneAes` 持久化字段。
- 改造保存链路：所有新增 / 修改手机号的场景，在入库前调用 `createAesInfo()` 同步计算安全字段。
- 改造查询链路：所有按手机号等值查询的场景，改为使用 `phone_md5` 字段匹配。
- 改造展示链路：列表和导出接口返回 `phone_mask` 而非明文 `phone`。
- 前端兼容：`createAesInfo()` 必须兼容前端传入的明文手机号和 AES 加密密文。
- 单元测试：为 `createAesInfo()` 和前端兼容逻辑编写单元测试。

## 表与实体口径

| 数据库表 | drh 工程实体 | ju-chat 工程实体 |
|---------|-------------|-----------------|
| `drh_h5_order` | `H5Order`（drh-common） | `H5OrderDO`（ai-common） |
| `drh_book_question_record` | `BookQuestionRecord`（drh-common） | `BookQuestionRecordDO`（ai-common） |

## 不涉及（本次排除）

- `drh_applet_user`：整改已完成。
- `drh_live_user`（含 `app_phone`）：由其他同事后续处理。
- `drh_external_book_question_record`：由其他同事后续处理。
- `drh_book_edit_address_compensation`：本次未提及。

## DataSecurity 工具类

已确认位于 `C:\workspace\drh\drh-common\src\main\java\com\drh\common\fc\datasec\`：

- `DataSecurityInput`：`businessType`（1=加密）、`dataType`（1=手机号）、`data`。
- `DataSecurityOutput`：`mask`、`md5`、`aesEncrypt`、`aesDecrypt`。
- `DataSecurityInvoke`：通过 `FcInvokeUtils.doSyncTaskReturnJSONObj()` 调用远程 FC 函数 `DataSecurity-test`。
- `DataSecurityUtil`：AES/CBC/PKCS5Padding，key `drh_aes_key_77b!`，IV `drh_aes_iv_77bit`。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、配置来源和测试落点。
- 不允许把空对象、占位 DTO 或未赋值字段当成有效输入继续传递。
- 对跨层可变 DTO、调用后赋值、字段来源不明、旧逻辑副作用，必须先标记风险。
- 发现关键参数依赖后续步骤补齐时，优先在当前层现算现用。
- 任何会改变调用顺序、接口契约、远程调用、MQ 字段、Redis key、数据库结构或外部行为的方案，实施前必须确认业务意图。
- 单元测试不能只验证最终结果；涉及外部调用时，必须做下游参数断言。

## 强制门禁

- 参数来源：`phone` 来自前端请求（密文或明文）；`phoneMask/phoneMd5/phoneAes` 来自 `DataSecurityInvoke.doDsTask()`（远程 FC 调用）。
- 赋值时机：`createAesInfo()` 必须在 `save()` / `insert()` 之前调用。
- 占位对象：`DataSecurityInput` 必须 `setData()` 后才可调用 `doDsTask()`。
- 下游读取：列表读 `phoneMask`，查询读 `phoneMd5`，单条解密读 `phoneAes`。
- 旧逻辑保持：原 `phone` 字段保留，旧查询可并存（渐进式改造）。
- 影响范围：drh 工程 6 个模块 + ju-chat 工程 ai 模块。
- 测试映射：每个关键行为至少对应一条单元测试。
- ju-chat 工程依赖确认：ai 模块是否能访问 drh-common 的 `DataSecurity*` 类。
- 前端兼容确认：`DataSecurityUtil.aesDecrypt()` 对明文输入的行为。
- 远程 FC 调用超时策略：`DataSecurityInvoke.doDsTask()` 失败时的降级处理。

## 重点代码位置

- drh 工程实体：
  - `drh-common\src\main\java\com\drh\common\entity\H5Order.java`
  - `drh-common\src\main\java\com\drh\common\entity\BookQuestionRecord.java`
- drh 工程 DataSecurity：
  - `drh-common\src\main\java\com\drh\common\fc\datasec\DataSecurityInput.java`
  - `drh-common\src\main\java\com\drh\common\fc\datasec\DataSecurityOutput.java`
  - `drh-common\src\main\java\com\drh\common\fc\datasec\DataSecurityInvoke.java`
  - `drh-common\src\main\java\com\drh\common\fc\datasec\DataSecurityUtil.java`
- drh 工程 Service（H5Order）：
  - `drh-app\drh-provider\drh-pay\src\main\java\com\drh\pay\service\impl\H5OrderServiceImpl.java`
  - `drh-endpoint\src\main\java\com\drh\endpoint\service\impl\H5OrderServiceImpl.java`
  - `drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\H5OrderServiceImpl.java`
  - `drh-callback\src\main\java\com\drh\callback\service\impl\H5OrderServiceImpl.java`
  - `drh-media-process\src\main\java\drh\media\process\service\impl\H5OrderServiceImpl.java`
- drh 工程 Service（BookQuestionRecord）：
  - `drh-endpoint\src\main\java\com\drh\endpoint\service\impl\BookQuestionRecordServiceImpl.java`
  - `drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\BookQuestionRecordServiceImpl.java`
  - `drh-media-process\src\main\java\drh\media\process\service\impl\BookQuestionRecordServiceImpl.java`
- ju-chat 工程实体：
  - `ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\order\H5OrderDO.java`
  - `ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\book\BookQuestionRecordDO.java`
- ju-chat 工程 Service：
  - `ai\src\main\java\com\kkhc\idc\ad\service\order\H5OrderServiceImpl.java`
  - `ai\src\main\java\com\kkhc\idc\lms\service\book\impl\BookQuestionRecordServiceImpl.java`

## 文档维护

- `spec.md` 描述保存、查询、展示链路改造、前端兼容、单元测试要求和验收场景。
- `tasks.md` 记录事实确认、风险门禁、实现任务和测试任务。
- `checklists/requirements.md` 用于验证规格质量和实施就绪度。
- 每次用户纠正或补充需求，都必须追加 Dxxx 执行记录，并同步更新相关文档。
