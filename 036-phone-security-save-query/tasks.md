# 任务清单：手机号安全字段保存与查询改造

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`、`032-phone-security-columns` DDL 已在测试库执行  
**测试**：实现阶段必须补充与关键行为一一对应的单元测试。

## Phase 1：代码事实确认

- [ ] T001 复查用户需求和本目录 `AGENTS.md`，确认范围仅限 `H5Order` / `H5OrderDO` 和 `BookQuestionRecord` / `BookQuestionRecordDO`，涉及两个工程：`C:\workspace\drh` 和 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai`。
- [ ] T002 确认 drh 工程中 `H5Order`（drh-common）和 `BookQuestionRecord`（drh-common）的字段结构，以及各模块（drh-pay / drh-endpoint / drh-kk-cms / drh-callback / drh-media-process）中所有涉及手机号写入的 Service 方法。
- [ ] T003 确认 ju-chat 工程 ai 模块中 `H5OrderDO`（ai-common）和 `BookQuestionRecordDO`（ai-common）的字段结构，以及 Service 中涉及手机号写入和查询的方法。
- [ ] T004 确认 ju-chat 工程 ai 模块是否能访问 drh-common 的 `DataSecurity*` 类（检查 Maven 依赖链）。如不可用，记录并确认替代方案。
- [ ] T005 确认 `DataSecurityUtil.aesDecrypt()` 对明文手机号输入的行为：抛异常、返回 null、还是返回乱码。决定 `createAesInfo()` 的兼容策略。
- [ ] T006 确认 `DataSecurityInvoke.doDsTask()` 远程 FC 调用的超时时间、失败行为和降级策略。
- [ ] T007 确认 MD5 大小写口径：`DataSecurityInvoke.doDsTask().getMd5()` 输出大写还是小写。
- [ ] T008 确认 drh-kk-cms 中批量 `in` 查询（`getPhoneResult()`、`getPhoneChannelSet()`）改造口径；D006 已改为批量计算 MD5 后查询 `phone_md5`。

**检查点**：不得在未完成 T001-T008 前进入实现。

## Phase 2：风险门禁

- [ ] T009 检查 `DataSecurityInput` 是否存在空 `data` 传入 `doDsTask()` 的风险，确认 `createAesInfo()` 内部做空值保护。
- [ ] T010 检查 `DataSecurityOutput` 返回值是否可能为 `null` 或字段缺失（远程 FC 调用可能超时），确认 `createAesInfo()` 做空值保护。
- [ ] T011 检查是否存在先 `save()` 后补安全字段的调用顺序风险。
- [ ] T012 检查 `H5Order.create()` 静态工厂方法的调用链，确认改造后不影响现有调用方。
- [ ] T013 检查前端兼容逻辑：明文手机号经过 `DataSecurityUtil.aesDecrypt()` 后的行为，确认 try-catch + 回退策略可行。
- [ ] T014 检查 drh-kk-cms `editAddressV2()` 中 Redis 锁 key 是否基于 phone，改造后是否受影响。
- [ ] T015 检查本次改造是否影响接口契约（返回 VO/DTO 字段名是否变化，前端是否需要配合修改）。
- [ ] T016 为每个关键行为建立测试映射：
  - 保存：明文输入正常路径、密文输入正常路径、空手机号路径、解密失败路径、FC 调用失败路径。
  - 查询：正常匹配路径、空查询路径、无匹配结果路径。
  - 展示：正常返回 mask 路径、历史 NULL fallback 路径。

**检查点**：T009-T016 必须有明确结论；发现高风险时先更新 `spec.md` 的"历史问题防漏分析"。

## Phase 3：实现

### 3.1 实体类改造

- [ ] T017 在 `H5Order`（drh-common）中增加 `phoneMask`、`phoneMd5`、`phoneAes` 持久化字段和 `createAesInfo()` 方法（含前端兼容逻辑）。
- [ ] T018 在 `BookQuestionRecord`（drh-common）中增加 `phoneMask`、`phoneMd5`、`phoneAes` 持久化字段和 `createAesInfo()` 方法。
- [ ] T019 在 `H5OrderDO`（ai-common）中增加 `phoneMask`、`phoneMd5`、`phoneAes` 持久化字段和 `createAesInfo()` 方法（如 ai 模块可访问 DataSecurity 类）。
- [ ] T020 在 `BookQuestionRecordDO`（ai-common）中增加 `phoneMask`、`phoneMd5`、`phoneAes` 持久化字段和 `createAesInfo()` 方法。

### 3.2 保存链路改造（drh 工程）

- [ ] T021 改造 drh-pay `H5OrderServiceImpl`：`create()` / `insertH5Order()` / `insertOpenH5Order()` 在 `save()` 前调用 `createAesInfo()`。
- [ ] T022 改造 drh-endpoint `H5OrderServiceImpl`：`editAddress()` / `editAddressV2()` 中 `BookQuestionRecord` 保存前调用 `createAesInfo()`。
- [ ] T023 改造 drh-kk-cms `BookQuestionRecordServiceImpl`：`editAddress()` / `editAddressV2()` 中 `BookQuestionRecord` 保存前调用 `createAesInfo()`。
- [ ] T024 改造 drh-callback `H5OrderServiceImpl`：如涉及 H5Order 更新手机号，调用 `createAesInfo()`。
- [ ] T025 改造 drh-media-process：如涉及手机号写入，调用 `createAesInfo()`。
- [ ] T026 改造 `H5Order.create()` 静态工厂方法或调用方。

### 3.3 保存链路改造（ju-chat 工程）

- [ ] T027 改造 ai 模块 `BookQuestionRecordServiceImpl`：如涉及 `BookQuestionRecordDO` 保存，在 `save()` 前调用 `createAesInfo()`。

### 3.4 查询链路改造

- [ ] T028 改造 drh-pay `H5OrderServiceImpl.selectIsPay()` 和 `H5OrderController.queryPhone()`：phone → phoneMd5。
- [ ] T029 改造 drh-endpoint `H5OrderServiceImpl.queryLeads()`、`editAddress()`、`editAddressV2()` 中的 phone 查询：phone → phoneMd5。
- [ ] T030 改造 drh-kk-cms `BookQuestionRecordServiceImpl.editAddressV2()` 和 `selectCanEdit()` 中的 phone 查询：phone → phoneMd5。
- [ ] T031 改造 ju-chat ai `BookQuestionRecordServiceImpl.getBookQuestionRecordByAppletUserId()`：phone → phoneMd5。
- [ ] T032 确认 MD5 计算工具方法统一：查询输入支持明文手机号、前端 AES 加密手机号、手机号 MD5；MD5 输入直通，不二次摘要。
- [ ] T033 对批量 `in` 查询（`getPhoneResult()`、`getPhoneChannelSet()`）执行 `phone_md5` 改造：批量计算 MD5 后查询 `H5Order::getPhoneMd5`。

### 3.5 展示链路改造

- [ ] T034 改造 drh 工程中 `H5Order` 和 `BookQuestionRecord` 相关的列表 / 导出接口，手机号返回 `phoneMask`。
- [ ] T035 改造 ju-chat 工程中 `BookQuestionRecordDO` 相关返回，手机号改为 `phoneMask`。
- [ ] T036 处理历史数据 `phoneMask` 为 NULL 的 fallback 逻辑。

### 3.6 文档同步

- [ ] T037 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

### 3.7 历史数据回填接口（juzi-service）

- [ ] T049 在 `C:\workspace\ju-chat\data-RC\juzi-service` 新增历史回填启动接口，调用后立即返回成功，后台异步执行。
- [ ] T050 回填目标覆盖 7 张目标表的 `phone_mask/phone_md5/phone_aes`，并额外覆盖 `drh_live_user.app_phone_mask/app_phone_md5/app_phone_aes`。
- [ ] T051 后台回填只处理原手机号非空且安全字段任一为空的记录，不修改 `phone` / `app_phone` 原字段。
- [ ] T052 数据安全 FC 调用最多 4 并发，数据库更新按 300 条批量执行一次。
- [ ] T053 日志打印 `runId`、当前表字段、`lastId`、批次选中数、加密成功数、失败数、批量更新数和累计进度。
- [ ] T054 单实例内防重复启动；重复调用返回正在运行提示。

## Phase 4：单元测试

- [ ] T038 编写 `H5Order.createAesInfo()` 单元测试（drh-common）：
  - 明文手机号输入 → `phoneMask`、`phoneMd5`、`phoneAes` 均正确。
  - 前端加密密文输入 → 解密后安全字段与明文输入结果一致。
  - 空手机号输入 → 三个安全字段均为 `NULL`，不抛异常。
  - 非法密文输入（解密失败）→ 不抛异常，安全字段为 `NULL` 或回退处理。
- [ ] T039 编写 `BookQuestionRecord.createAesInfo()` 单元测试（drh-common，同 T038 四种场景）。
- [ ] T040 编写前端兼容判断逻辑单元测试：验证同一手机号在明文和密文两种输入下，`phoneMd5` 结果一致。
- [ ] T041 编写 MD5 查询工具方法单元测试：覆盖明文 / 前端密文归一化，以及 32 位 MD5 输入直通、不二次摘要。
- [ ] T042 测试中断言 `DataSecurityInput.setData()` 参数内容（下游参数断言），不只断言最终结果。

## Phase 5：测试与验证

- [ ] T043A 验证前显式设置 DRH 工程 JDK8：`JAVA_HOME=C:\Program Files\Java\jdk1.8.0_481`（`java version "1.8.0_481"`），避免 Maven 默认使用 JDK17。
- [ ] T043 运行全部单元测试，确认通过。
- [ ] T044 验证保存后数据库中 `phone_mask`、`phone_md5`、`phone_aes` 均有值（集成测试或手动验证）。
- [ ] T045 验证查询改造后 SQL 使用 `phone_md5` 条件（SQL 日志或 mock 验证）。
- [ ] T046 搜索确认 drh 工程没有残留的 `.eq(H5Order::getPhone, ...)` 和 `.eq(BookQuestionRecord::getPhone, ...)` 旧查询（排除批量 in 查询和排除表）。
- [ ] T047 搜索确认 ju-chat 工程没有残留的 `.eq(H5OrderDO::getPhone, ...)` 和 `.eq(BookQuestionRecordDO::getPhone, ...)` 旧查询。
- [ ] T048 运行两个工程的编译命令，确认无编译错误。

## 执行记录

### D001 - 文档记录

- 执行内容：创建手机号安全字段保存与查询改造规格文档。
- 验证方式：代码搜索确认目标实体、Service、Mapper 和现有加密工具位置。
- 自检结论：保存、查询、展示三条链路改造范围明确。

### D002 - 需求补充纠正

- 触发原因：用户补充——`app_phone` 不由本次处理；前端整改前会传明文手机号，需兼容；需编写单元测试。
- 修正内容：范围缩小为 2 张表；新增前端兼容要求和单测要求。
- 文档同步：已同步更新四个文件。

### D003 - 项目路径补充纠正

- 触发原因：用户补充——修改代码涉及 `C:\workspace\drh` 和 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai` 两个工程。
- 修正内容：
  - 确认 `DataSecurity*` 存在于 drh-common 的 `com.drh.common.fc.datasec` 包中。
  - 确认 `DataSecurityInvoke` 调用远程 FC 函数 `DataSecurity-test`。
  - drh 工程涉及 6 个模块：drh-common / drh-pay / drh-endpoint / drh-kk-cms / drh-callback / drh-media-process。
  - 实体名在 drh 中为 `H5Order` / `BookQuestionRecord`，在 ju-chat 中为 `H5OrderDO` / `BookQuestionRecordDO`。
  - 补全所有保存和查询落点（10+ 处 Service 方法）。
  - 新增 ju-chat ai 模块 DataSecurity 依赖可用性为待确认项。
  - 批量 `in` 查询早期列为后续项，后续 D006 已覆盖改为 `phone_md5`。
- 文档同步：`spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 已同步更新。
- 验证结果：文档静态检查通过。

### D004 - 实现记录

- 已被 D006 替代：本轮范围由 2 张表扩展为 7 张表，并按 `phone` 后续可清空的口径补全。

### D006 - 手机号安全字段补全与真实地址记录追加

- 触发原因：用户补充目标表为 `drh_h5_order`、`drh_live_user`、`drh_applet_user`、`drh_book_question_record`、`drh_external_book_question_record`、`drh_book_edit_address_compensation`，并追加 `drh_real_address_record`；`app_phone` 明确不处理。
- 实现内容：
  - **统一工具**：DRH 与 IDC AI 侧 `DataSecurityInvoke` 增加 `buildPhoneSecurity`、`computePhoneMd5`、`decryptPhoneAes`、`phoneMaskForDisplay`。
  - **实体补齐**：DRH 补齐 `H5Order`、`BookQuestionRecord`、`AppletUser`、`LiveUser`、`ExternalBookQuestionRecord`、`RealGoodsAddressRecord`；IDC AI 补齐 `H5OrderDO`、`BookQuestionRecordDO`、`AppletUserDo`、`LiveUserDO`、`ExternalBookQuestionRecordDO`、`BookEditAddressCompensationDO`、`RealGoodsAddressRecordDO`。
  - **保存/更新链路**：H5Order 创建、支付回调线索更新、图书登记、非留资、真实地址记录、补偿记录、学员/线索手机号更新均同步写 `phone_mask/phone_md5/phone_aes`。
  - **查询/读取链路**：目标表手机号等值/批量匹配改用 `phone_md5`；需要明文时从方法入参或 `phone_aes` 解密；展示/列表/订单查询返回 `phone_mask` 或本地掩码。
  - **真实地址记录**：`RealGoodsAddressRecord` 保存前调用 `createAesInfo()`，ERP 下发手机号通过 `phone_aes` 解密兜底，AI 订单地址展示返回掩码手机号。
- 接口影响（DRH 项目，按模块）：

| 模块 | 接口 / 入口 | 影响点 |
|------|-------------|--------|
| `drh-pay` | `POST /h5/order/pay`、`POST /h5/order/open/pay` | H5 图书订单创建时同步写 `phone_mask/phone_md5/phone_aes` |
| `drh-pay` | `GET /h5/order/query/phone` | 按手机号查询支付状态改为 `phone_md5` 匹配 |
| `drh-pay` | `POST/GET /h5/order/wx/notify` | 微信支付回调读取 `phone_aes` 解密手机号后推送线索回调 |
| `drh-pay` | `POST /applet/order/page/pay`、`POST/GET /applet/order/wx/notify` | 小程序页面支付生成 H5Order 安全字段，回调不再依赖 DB `phone` 明文 |
| `drh-pay` | `POST /ali/pay/order`、`POST /ali/pay/notify`、`GET /ali/pay/orderNo/select`、`GET /ali/pay/phone/select` | 支付宝 H5 订单创建/回调/查询：线索更新按 `phone_md5`，展示返回掩码 |
| `drh-pay` | `POST /activity/groupbuying/order/create`、`POST /common/order/pay`、`POST /salePay/createPay*`、`POST /live/order/pay`、`POST /live/order/applet/pay` | 涉及 `LiveUserService` 的学员手机号保存/更新链路同步写安全字段 |
| `drh-endpoint` | `POST /bookPath/editAddress`、`POST /bookPath/editAddressV2` | 图书登记保存 `BookQuestionRecord`，并在正价课地址链路保存 `RealGoodsAddressRecord` 安全字段 |
| `drh-endpoint` | `GET /bookPath/queryTrackNumOrder` | 真实地址/物流查询返回掩码手机号 |
| `drh-endpoint` | `GET /liveAuth/ad/applet/query` | `queryLeads` 按手机号查询订单/线索改为 `phone_md5` 匹配 |
| `drh-endpoint` | `GET /ad/pic`、`POST /ad/v2/pic`、`POST /ad/base/pic` | 加 V / 二维码链路按手机号找线索改为 `phone_md5` |
| `drh-endpoint` | `POST /liveAuth/auth/phone/v3`、`POST /liveAuth/auth/phone/v6`、`POST /liveAuth/works/auth/phone*`、`POST /liveAuth/*/pic` | 手机号授权、留资、获客助手查询链路写入或读取线索/学员安全字段 |
| `drh-kk-cms` | `GET /user/phone/user`、`POST /user/checkCounts`、`POST /user/selectPhone` | CMS 按手机号查线索/统计改为 `phone_md5`；展示避免明文 |
| `drh-kk-cms` | `GET /bookPath/queryAdDetail`、`GET /bookPath/queryOrderDetail`、`GET /bookPath/queryCollectDetail` | 图书登记/订单收货详情手机号展示返回掩码 |
| `drh-kk-cms` | `POST /bookPath/editAddress`、`POST /bookPath/editAddressV2`、`POST /bookPath/selectCanEditV1` | CMS 图书登记保存/可填写用户查询改用安全字段 |
| `drh-kk-cms` | `POST /external/bookQuestionRecord/create`、`POST /external/bookQuestionRecord/count`、`POST /external/bookQuestionRecord/queryHistoryPage`、`POST /external/bookQuestionRecord/queryHistoryExpressNo` | 非留资登记保存、次数判断、历史查询按 `phone_md5` / 掩码字段处理 |
| `drh-kk-cms` | `POST /collect/order/editAddress`、`GET /collect/order/import/address/sure`、`GET /collect/order/import/address` | 统一填地址、批量导入地址链路保存 `RealGoodsAddressRecord` 安全字段 |
| `drh-kk-cms` | `GET /collect/order/detail`、`POST /collect/order/list`、`GET /liveCampGroup/stu/logistics` | 订单详情、订单列表、学员物流展示涉及真实地址手机号掩码展示 |
| `drh-kk-cms` | `GET /liveCampGroup/stu/search` | 学员手机号搜索改为 `phone_md5`，返回手机号为掩码 |
| `drh-callback` | `POST /ad/order`、`POST /appletUser/addAppletUserPhone` | 支付服务间回调/内部线索新增入口同步写线索安全字段 |
| `drh-callback` | `POST /baiduCallback/receive` | 百度小店订单回调创建 `AppletUser` / `H5Order` 时写安全字段 |
| `drh-callback` | `POST /dd/callback`、`POST /dd/sendOrder`、`POST /dd/goose/callback`、`POST /dd/order/changeStatus` | 抖店/小鹅通回调创建订单与线索安全字段，取消消息按 `phone_md5` 查线索 |
| `drh-callback` | `POST /third/external/importLeads`、`POST /third/external/importLeadsV2` | 第三方导入线索去重和保存改为 `phone_md5` / 安全字段 |
| `drh-callback` | `POST /sph/addOrder`、`GET/POST /sph/msgCallback` | 视频号订单回调保存 H5Order/线索时写安全字段 |
| `drh-media-process` | `POST /erp/callback`、`POST /fBook/callback`、`POST /xe/callback` | ERP / 飞书审批 / 小鹅通回传后续处理图书登记、非留资、真实地址安全字段 |
| `drh-media-process` | `GET /Test/execAdOrder`、`GET /Test/getPhone`、`GET /Test/queryOrder` | 测试/运维入口涉及非留资订单处理和手机号读取，按安全字段口径验证 |
| `drh-media-process` | `GET /smsDeal/*`、相关 XXL-JOB：`fillAiAddressOrderTask` | 批处理/短信/AI 地址填充任务从 `phone_aes` 解密或写安全字段 |

- 接口影响（IDC AI 项目）：`/book/getBookQuestionRecordByAppletUserId`、`/external/bookQuestionRecord/create`、`/external/bookQuestionRecord/count`、`/external/bookQuestionRecord/queryHistoryPage`、`/external/bookQuestionRecord/queryHistoryExpressNo`、`/book-edit-address-compensation/saveOne`、`/book-edit-address-compensation/compensationRun`、真实地址/物流相关 AI 查询接口。
- 测试建议：
  - 7 张表新增/更新后校验 `phone_mask`、`phone_md5`、`phone_aes`。
  - 手动清空目标表 `phone` 后验证支付回调、订单手机号查询、图书登记查询、物流/ERP 推送、补偿任务仍可用。
  - SQL 日志确认目标表手机号匹配不再依赖 `phone = ?`。
  - 同一查询接口分别传明文手机号、前端加密手机号、手机号 MD5，应命中同一条记录。
  - 保存/更新接口分别传明文手机号、前端加密手机号，应正确生成 `phone_mask/phone_md5/phone_aes`；手机号 MD5 不作为保存/更新支持格式。
  - 展示/导出返回掩码，不返回明文；`app_phone` 相关接口不纳入本次验证。
- 非目标表静态提示：广告分配、客服记录、外呼/短信任务、订单售后/补发等非目标表仍存在 `phone` 查询或展示，本次未改业务逻辑。

### D007 - SQL 变更文档补充

- 触发原因：用户要求将本次手机号安全字段相关 SQL 放到 spec-kit 文档中。
- 修正内容：
  - 在 `spec.md` 增加“数据库 SQL 变更”小节，补充 7 张目标表完整 DDL、执行前 `information_schema` 检查 SQL、业务 SQL 改造口径。
  - 新增 `phone-security-d006.sql`，便于 DBA / 测试直接查看当前口径 SQL。
  - 明确 `app_phone` 不在 D006 SQL 范围内；`app_phone_*` 字段来自 032，历史回填接口会读写这些已有安全字段。
- 验证建议：执行前确认字段和索引是否已存在；032 已执行过 6 张表 DDL 的环境，本次重点追加 `drh_real_address_record`。

### D008 - 历史数据回填接口补充

- 触发原因：用户要求在 `juzi-service` 增加补历史数据接口，并明确本次补数据包含 `app_phone`；前面在线代码改造仍不用处理 `app_phone`。
- 实现内容：
  - 新增 `POST /admin/phone-security-backfill/start`，返回 `runId`、批次大小和 FC 并发上限后异步执行。
  - 新增 `GET /admin/phone-security-backfill/status`，便于查看当前单实例补数状态。
  - 回填目标：`drh_h5_order.phone`、`drh_live_user.phone`、`drh_live_user.app_phone`、`drh_applet_user.phone`、`drh_book_question_record.phone`、`drh_external_book_question_record.phone`、`drh_book_edit_address_compensation.phone`、`drh_real_address_record.phone`。
  - 约束：最多 4 个并发调用 `DataSecurity/DataSecurity-test`，每 300 条做一次批量更新，日志输出每批进度。
- 文档同步：同步更新 `spec.md`、`tasks.md`、`AGENTS.md`。
- 验证建议：执行前确认目标环境字段存在，执行后按表抽样校验 `*_mask/*_md5/*_aes` 三字段均已填充。

### D009 - DRH 接口影响模块标注补充

- 触发原因：用户要求 DRH 项目影响接口补充模块标注，例如 `cms`、`endpoint`。
- 修正内容：
  - 将原 D006 中混合描述的接口影响拆成 `drh-pay`、`drh-endpoint`、`drh-kk-cms`、`drh-callback`、`drh-media-process` 五个 DRH 模块。
  - 对每个模块列出接口 / 内部入口 / 任务入口，并补充对应验证点：保存安全字段、按 `phone_md5` 查询、从 `phone_aes` 解密、展示掩码。
  - 保留 IDC AI 项目接口影响清单，作为 DRH 表后的独立项目范围。
- 验证建议：测试按模块执行接口验证，重点观察 SQL 日志是否使用 `phone_md5`，返回值手机号是否为掩码。

### D010 - 查询 / 保存输入格式兼容补充

- 触发原因：用户补充查询接口需支持明文手机号、前端加密手机号、手机号 MD5 三种格式；保存 / 更新需支持明文手机号、前端加密手机号两种格式。
- 当前确认：原 `DataSecurityInvoke.computePhoneMd5()` 已支持明文和前端 AES 密文，但手机号 MD5 输入会被二次摘要，查询直接传 MD5 不满足。
- 本次修正：`computePhoneMd5()` 增加 32 位十六进制 MD5 直通识别，保存 / 更新链路仍通过 `buildPhoneSecurity()` 生成完整三字段，不支持仅传 MD5 保存。
- 文档同步：同步更新 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 的输入兼容口径、测试建议和执行记录。
- 当前结论：改造后查询三种输入已满足；保存 / 更新两种输入已满足；手机号 MD5 仅作为查询输入兼容。

### D011 - 本地 JDK 口径补充

- 触发原因：用户要求补充 JDK 路径和版本，防止下次验证时 Maven 默认走 JDK17。
- 修正内容：记录 DRH 工程验证使用 JDK8：`C:\Program Files\Java\jdk1.8.0_481`，版本 `java version "1.8.0_481"`；记录本机 Maven 曾默认使用 JDK17：`C:\workspace\tools\jdk17\jdk-17.0.18+8`，版本 `17.0.18`，会触发老 Lombok 与 `jdk.compiler` 模块访问冲突。
- 文档同步：同步更新 `spec.md`、`tasks.md`、`AGENTS.md`。
- 验证建议：运行 DRH 编译或单测前先设置 `JAVA_HOME` 和 `Path` 指向 JDK8。

### D005 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
