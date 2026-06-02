# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\036-phone-security-save-query`
- 目标工程 1：`C:\workspace\drh`（主业务微服务，多模块 Spring Cloud 项目）
  - 相关模块：`drh-common`（实体 + DataSecurity 工具）、`drh-pay`（订单创建）、`drh-endpoint`（用户端 API）、`drh-kk-cms`（CMS 后台）、`drh-callback`（支付回调）、`drh-media-process`（批处理）
- 目标工程 2：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`（AI 模块）
  - 相关模块：`ai-common`（实体）、`ai`（Service / Mapper / Controller）
- 前置需求：`032-phone-security-columns`（DDL 已完成，测试库已执行）

## 当前目标

- 目标表扩展为 7 张：`drh_h5_order`、`drh_live_user`、`drh_applet_user`、`drh_book_question_record`、`drh_external_book_question_record`、`drh_book_edit_address_compensation`、`drh_real_address_record`。
- 在目标表对应实体中增加/补齐 `phoneMask`、`phoneMd5`、`phoneAes` 持久化字段和 `createAesInfo()` / 安全字段生成能力。
- 改造保存链路：所有新增 / 修改手机号的场景，在入库前调用 `createAesInfo()` 同步计算安全字段。
- 改造查询链路：所有按手机号等值查询的场景，改为使用 `phone_md5` 字段匹配；查询输入支持明文手机号、前端 AES 加密手机号、手机号 MD5 三种格式。
- 改造展示链路：列表和导出接口返回 `phone_mask` 而非明文 `phone`。
- 保存 / 更新兼容：`createAesInfo()` 必须兼容前端传入的明文手机号和 AES 加密密文；手机号 MD5 不作为保存 / 更新支持格式。
- 单元测试：为 `createAesInfo()` 和前端兼容逻辑编写单元测试。
- 历史补数：在 `C:\workspace\ju-chat\data-RC\juzi-service` 增加补数接口，后台补齐目标表安全字段；补数范围包含 `drh_live_user.app_phone` 的 `app_phone_*` 三字段。

## 表与实体口径

| 数据库表 | drh 工程实体 | ju-chat 工程实体 |
|---------|-------------|-----------------|
| `drh_h5_order` | `H5Order`（drh-common） | `H5OrderDO`（ai-common） |
| `drh_live_user` | `LiveUser`（drh-common） | `LiveUserDO`（ai-common） |
| `drh_applet_user` | `AppletUser`（drh-common） | `AppletUserDo`（ai-common） |
| `drh_book_question_record` | `BookQuestionRecord`（drh-common） | `BookQuestionRecordDO`（ai-common） |
| `drh_external_book_question_record` | `ExternalBookQuestionRecord`（drh-common） | `ExternalBookQuestionRecordDO`（ai-common） |
| `drh_book_edit_address_compensation` | - | `BookEditAddressCompensationDO`（ai-common） |
| `drh_real_address_record` | `RealGoodsAddressRecord`（drh-common） | `RealGoodsAddressRecordDO`（ai-common） |

## 不涉及（在线代码改造排除）

- `app_phone` 在线保存 / 查询 / 展示链路不改造；但历史补数接口需要读取 `drh_live_user.app_phone` 并写入已有 `app_phone_mask/app_phone_md5/app_phone_aes`。
- 非上述目标表的 `phone` 使用点只整理提示，暂不改业务逻辑。

## DataSecurity 工具类

已确认位于 `C:\workspace\drh\drh-common\src\main\java\com\drh\common\fc\datasec\`：

- `DataSecurityInput`：`businessType`（1=加密）、`dataType`（1=手机号）、`data`。
- `DataSecurityOutput`：`mask`、`md5`、`aesEncrypt`、`aesDecrypt`。
- `DataSecurityInvoke`：通过 `FcInvokeUtils.doSyncTaskReturnJSONObj()` 调用远程 FC 函数 `DataSecurity-test`。
- `DataSecurityUtil`：AES/CBC/PKCS5Padding，key `drh_aes_key_77b!`，IV `drh_aes_iv_77bit`；前端加密手机号需与该解密口径一致。

## 本地构建 / JDK

- DRH 工程验证优先使用 JDK8：`C:\Program Files\Java\jdk1.8.0_481`，版本 `java version "1.8.0_481"`。
- 验证前显式设置：

```powershell
$env:JAVA_HOME='C:\Program Files\Java\jdk1.8.0_481'
$env:Path="$env:JAVA_HOME\bin;$env:Path"
mvn -pl drh-common "-Dtest=DataSecurityUtilTest" test
```

- 不要用本机 Maven 默认的 JDK17 路径 `C:\workspace\tools\jdk17\jdk-17.0.18+8`（版本 `17.0.18`）验证 DRH 工程；老 Lombok 会和 JDK17 的 `jdk.compiler` 模块访问限制冲突。

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
- 下游读取：列表读 `phoneMask`，查询读 `phoneMd5`；查询参数先经 `DataSecurityInvoke.computePhoneMd5()` 归一，支持明文 / 前端密文 / MD5；单条解密读 `phoneAes`。
- 旧逻辑保持：原 `phone` 字段保留，旧查询可并存（渐进式改造）。
- 影响范围：drh 工程 6 个模块 + ju-chat 工程 ai 模块。
- 测试映射：每个关键行为至少对应一条单元测试。
- ju-chat 工程依赖确认：ai 模块是否能访问 drh-common 的 `DataSecurity*` 类。
- 输入兼容确认：保存 / 更新支持明文和前端密文；查询额外支持 32 位手机号 MD5 直通，不二次摘要。
- 远程 FC 调用超时策略：`DataSecurityInvoke.doDsTask()` 失败时的降级处理。
- 历史补数接口：必须单实例防重入，最多 4 个并发调用 FC，按 300 条批量更新，日志打印批次进度。

## 重点代码位置

- drh 工程实体：
  - `drh-common\src\main\java\com\drh\common\entity\H5Order.java`
  - `drh-common\src\main\java\com\drh\common\entity\BookQuestionRecord.java`
  - `drh-common\src\main\java\com\drh\common\entity\AppletUser.java`
  - `drh-common\src\main\java\com\drh\common\entity\LiveUser.java`
  - `drh-common\src\main\java\com\drh\common\entity\ExternalBookQuestionRecord.java`
  - `drh-common\src\main\java\com\drh\common\entity\RealGoodsAddressRecord.java`
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
  - `ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\base\LiveUserDO.java`
  - `ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\leads\AppletUserDo.java`
  - `ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\book\ExternalBookQuestionRecordDO.java`
  - `ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\book\BookEditAddressCompensationDO.java`
  - `ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\order\fulfillment\address\RealGoodsAddressRecordDO.java`
- ju-chat 工程 Service：
  - `ai\src\main\java\com\kkhc\idc\ad\service\order\H5OrderServiceImpl.java`
  - `ai\src\main\java\com\kkhc\idc\lms\service\book\impl\BookQuestionRecordServiceImpl.java`

## 文档维护

- `spec.md` 描述保存、查询、展示链路改造、前端兼容、单元测试要求和验收场景。
- `tasks.md` 记录事实确认、风险门禁、实现任务和测试任务。
- `checklists/requirements.md` 用于验证规格质量和实施就绪度。
- 每次用户纠正或补充需求，都必须追加 Dxxx 执行记录，并同步更新相关文档。
