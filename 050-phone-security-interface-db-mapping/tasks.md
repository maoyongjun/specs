# 任务清单：手机号安全改造——接口影响与数据库表全量映射

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`；032/036/041/048 四个前置规格已完成代码改造  
**测试**：验证阶段按模块 × 接口 × 数据库表维度执行全量验证

## Phase 1：文档事实确认

- [x] T001 复查用户需求，确认本文档覆盖 drh-pay、drh-endpoint、drh-kk-cms、drh-callback、drh-media-process 五个模块。
- [x] T002 复查前置规格（032/036/041/048）已覆盖的数据库表和接口范围。
- [x] T003 确认 26 张已改造数据库表（7 张核心 + 19 张 P1 扩展）的完整清单。
- [x] T004 确认每个接口的改动类型（保存/查询/展示/回调）、数据库表读写方向和前端调用页面。
- [x] T005 确认前端投放页面、CMS 后台页面、小程序/APP 页面和中转页面的完整清单。

**检查点**：文档事实确认已完成，可进入验证阶段。

## Phase 2：验证准备

- [ ] T006 测试团队按 spec.md 中"接口影响与数据库表映射"章节，为每个接口建立测试用例。
- [ ] T007 按"数据库表 × 接口读写矩阵"确认每张表在各模块的读写方向无遗漏。
- [ ] T008 按"前端页面与接口映射"确认每个前端页面的调用接口路径正确。
- [ ] T009 准备测试数据：为每张目标表准备含 phone_mask/phone_md5/phone_aes 的测试记录，以及 phone 字段为空的测试记录。
- [ ] T010 准备测试环境：确认测试库已执行 032 和 048 的 DDL，26 张表均具备安全字段和索引。

## Phase 3：分模块验证

### drh-pay 模块验证

- [ ] T011 验证 H5 图书订单支付（`/h5/order/pay`、`/h5/order/open/pay`）：下单后 `drh_h5_order` 的 phone_mask/phone_md5/phone_aes 均有值。
- [ ] T012 验证支付状态查询（`/h5/order/query/phone`）：传入三种格式手机号均能命中同一记录。
- [ ] T013 验证微信支付回调（`/h5/order/wx/notify`）：回调后正确解密 phone_aes 并推送线索。
- [ ] T014 验证小程序支付（`/applet/order/page/pay`、`/applet/order/wx/notify`）：安全字段生成和回调解密正确。
- [ ] T015 验证支付宝 H5（`/ali/pay/order`、`/ali/pay/notify`、`/ali/pay/orderNo/select`、`/ali/pay/phone/select`）：创建/回调/查询链路安全字段正确。
- [ ] T016 验证学员手机号保存（`/activity/groupbuying/order/create`、`/common/order/pay`、`/salePay/createPay*`、`/live/order/pay`、`/live/order/applet/pay`）：`drh_live_user` 安全字段写入正确。

### drh-endpoint 模块验证

- [ ] T017 验证图书登记地址编辑（`/bookPath/editAddress`、`/bookPath/editAddressV2`）：`drh_book_question_record` 和 `drh_real_address_record` 安全字段写入正确。
- [ ] T018 验证物流查询（`/bookPath/queryTrackNumOrder`）：返回值为掩码格式。
- [ ] T019 验证线索查询（`/liveAuth/ad/applet/query`）：phone_md5 匹配正确。
- [ ] T020 验证加V/二维码（`/ad/pic`、`/ad/v2/pic`、`/ad/base/pic`）：phone_md5 匹配正确。
- [ ] T021 验证手机号授权/留资（`/liveAuth/auth/phone/v3`、`/liveAuth/auth/phone/v6`、`/liveAuth/works/auth/phone*`）：线索/学员安全字段写入和读取正确。

### drh-kk-cms 模块验证

- [ ] T022 验证 CMS 线索查询（`/user/phone/user`、`/user/checkCounts`、`/user/selectPhone`）：phone_md5 匹配，返回掩码。
- [ ] T023 验证图书/订单详情（`/bookPath/queryAdDetail`、`/bookPath/queryOrderDetail`、`/bookPath/queryCollectDetail`）：手机号展示为掩码。
- [ ] T024 验证 CMS 图书登记保存（`/bookPath/editAddress`、`/bookPath/editAddressV2`、`/bookPath/selectCanEditV1`）：安全字段写入正确。
- [ ] T025 验证非留资登记（`/external/bookQuestionRecord/create`、`/count`、`/queryHistoryPage`、`/queryHistoryExpressNo`）：安全字段读写正确。
- [ ] T026 验证统一订单地址管理（`/collect/order/editAddress`、`/import/address/sure`、`/import/address`）：`drh_real_address_record` 安全字段写入正确。
- [ ] T027 验证订单展示与学员管理（`/collect/order/detail`、`/list`、`/liveCampGroup/stu/logistics`、`/liveCampGroup/stu/search`）：掩码展示正确。
- [ ] T027.1 **[补充·已整改]** 验证学员管理列表（`/orderUser/user/list`）：① 搜索条件已改为 `phone_md5` 精确匹配（HandoverMapper.xml 3 处 LIKE 已替换）；② 返回的 `phone` 字段优先使用 `phoneMask`（OrderUser.getPhone() 已修改）；③ phoneMask/phoneMd5/phoneAes 三个安全字段已在 HandoverServiceImpl.fillOrderUserList() 中同步填充。
- [ ] T027.2 **[补充·已整改]** 验证订单转交列表（`/order/hand/list`）：① 搜索条件已改为 `phone_md5` 匹配（HandoverMapper.xml 同上）；② `OrderHandVo` 已新增 phoneMask/phoneMd5/phoneAes 字段，`BeanUtils.copyProperties` 自动复制；③ `getPhone()` 自定义方法优先返回 `phoneMask`。
- [ ] T027.3 **[补充·已整改]** 验证广告线索用户列表（`/ad/pic/user/list`）：① 搜索条件已改为 `phone_md5` 匹配；② `AdUserPicServiceImpl.getPageList` 的 forEach 末尾已将 phone 替换为 phoneMask；③ phoneMask/phoneMd5/phoneAes 三个安全字段已在响应中正确返回。

### drh-callback 模块验证

- [ ] T028 验证支付回调/线索新增（`/ad/order`、`/appletUser/addAppletUserPhone`）：安全字段写入正确。
- [ ] T029 验证百度小店回调（`/baiduCallback/receive`）：AppletUser / H5Order 安全字段写入正确。
- [ ] T030 验证抖店/小鹅通回调（`/dd/callback`、`/dd/sendOrder`、`/dd/goose/callback`、`/dd/order/changeStatus`）：安全字段读写正确。
- [ ] T031 验证第三方导入线索（`/third/external/importLeads`、`/importLeadsV2`）：phone_md5 去重和安全字段写入正确。
- [ ] T032 验证视频号回调（`/sph/addOrder`、`/sph/msgCallback`）：安全字段写入正确。

### drh-media-process 模块验证

- [ ] T033 验证 ERP/飞书/小鹅通回传（`/erp/callback`、`/fBook/callback`、`/xe/callback`）：图书登记/非留资/真实地址安全字段写入正确。
- [ ] T034 验证测试/运维入口（`/Test/execAdOrder`、`/Test/getPhone`、`/Test/queryOrder`）：安全字段口径正确。
- [ ] T035 验证批处理（`/smsDeal/*`、XXL-JOB `fillAiAddressOrderTask`）：phone_aes 解密和安全字段写入正确。

## Phase 4：全量回归

- [ ] T036 执行 26 张表的 phone 字段为空测试，确认所有查询链路不依赖明文 phone。
- [ ] T037 执行前端投放页面全流程测试（从投放页 → 支付 → 回调 → CMS 查看），确认全链路安全字段正确。
- [ ] T038 执行回调接口幂等性测试（重复回调不重复写入或产生异常数据）。
- [ ] T039 确认生产环境 `/Test/*` 接口不可访问。
- [ ] T040 确认中转页面（landDesk.html、landTrans.html、landTransXM2.html）跳转链路中手机号参数传递正确。

## 执行记录

### D001 - 文档记录

- 执行内容：创建接口影响与数据库表全量映射规格文档。
- 验证方式：文档审查，与前置规格交叉比对。
- 自检结论：覆盖 5 个模块、50+ 接口、26 张表；包含读写矩阵和前端页面映射。

### D002 - 人工核查补充接口与整改

- 触发原因：人工核查发现 3 个 drh-kk-cms 接口未纳入原始文档——`/orderUser/user/list`、`/order/hand/list`、`/ad/pic/user/list`。
- 执行内容：
  - **Phase 1（调查）**：新增 T027.1、T027.2、T027.3 三条补充验证任务；代码静态分析确认 Controller → Service → Mapper → 数据库表的完整调用链；在 spec.md 3.7 章节补充 3 个接口分析。
  - **Phase 2（整改实现）**：用户确认改为精确查询、phone 统一使用 phoneMask 后，完成以下代码改造：
    - `HandoverMapper.xml`：3 处 `luser.phone LIKE` 改为 `phone_md5` 精确匹配（`computePhoneMd5` bind）。
    - `OrderUser.java`：`getPhone()` 优先返回 `phoneMask`。
    - `HandoverServiceImpl.java`：`fillOrderUserList()` 同步填充 phoneMask/phoneMd5/phoneAes。
    - `OrderHandVo.java`：新增 phoneMask/phoneMd5/phoneAes 字段及 `getPhone()` 自定义方法。
    - `AdUserPicServiceImpl.java`：forEach 末尾将 phone 替换为 phoneMask。
- 影响范围：drh-kk-cms 模块 5 个文件。
- 文档同步：已同步更新 `spec.md`（D002 记录 + 3.7 章节）、`tasks.md`（T027.x + 本记录）。
- 自检结论：3 个接口已全部整改完成，T027.1/T027.2/T027.3 标记为"已整改"；代码已修改，待编译和接口验证。

### D003 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
