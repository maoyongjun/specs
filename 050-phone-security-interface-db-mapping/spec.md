# 功能规格：手机号安全改造——接口影响与数据库表全量映射

**功能目录**：`050-phone-security-interface-db-mapping`  
**创建日期**：`2026-06-04`  
**状态**：Draft  
**输入**：在 032-phone-security-columns（数据库字段添加）、036-phone-security-save-query（保存/查询/展示链路改造）、041-mybatisplus-xml-phone-md5-query（XML phone_md5 查询兼容）、048-phone-security-query-return-save-mask-validate（查询返回与掩码校验）、048-phone-security-remaining-tables-audit（剩余表排查）的基础上，全量梳理手机号加密改动影响的接口与对应数据库表的完整映射关系。覆盖 drh-pay、drh-endpoint、drh-kk-cms、drh-callback、drh-media-process 五个微服务模块的全部受影响接口，以及每个接口在保存、查询、展示链路中实际读写的数据库表。本文档用于测试团队按模块 × 接口 × 数据库表维度执行全量验证。

## 背景

- 当前问题：手机号安全改造横跨 5 个微服务模块、50+ 个接口、26+ 张数据库表。此前各 spec 分别从代码改造、XML 兼容、返回掩码、剩余表排查等维度分别记录，缺少一份以"接口 × 数据库表"为主轴的完整映射文档，测试团队难以按统一口径执行全量验证。
- 当前行为：各模块接口的影响点散落在 032/036/041/048 四个 spec 中，部分接口的数据库表映射关系不够明确，前端投放页面与接口的对应关系未统一记录。
- 目标行为：以模块为一级分类、接口为二级分类，完整列出每个接口的改动类型（保存/查询/展示/回调）、影响的数据库表（含安全字段读写方向）、前端调用页面，以及测试验证要点。
- 非目标：本阶段只编写映射文档，不修改业务代码、不执行 DDL、不回填数据。

## 数据库表清单

### 已改造目标表（032 + 036 覆盖，7 张）

| # | 数据库表 | 实体类（drh） | 实体类（ju-chat） | 手机号字段 | 改造规格 |
|---|---------|--------------|-----------------|-----------|---------|
| 1 | `drh_h5_order` | `H5Order`（drh-common） | `H5OrderDO`（ai-common） | `phone` | 032/036 |
| 2 | `drh_live_user` | `LiveUser`（drh-common） | `LiveUserDO`（ai-common） | `phone` + `app_phone`（app_phone 仅历史回填） | 032/036 |
| 3 | `drh_applet_user` | `AppletUser`（drh-common） | `AppletUserDo`（ai-common） | `phone` | 032/036 |
| 4 | `drh_book_question_record` | `BookQuestionRecord`（drh-common） | `BookQuestionRecordDO`（ai-common） | `phone` | 032/036 |
| 5 | `drh_external_book_question_record` | `ExternalBookQuestionRecord`（drh-common） | `ExternalBookQuestionRecordDO`（ai-common） | `phone` | 032/036 |
| 6 | `drh_book_edit_address_compensation` | — | `BookEditAddressCompensationDO`（ai-common） | `phone` | 032/036 |
| 7 | `drh_real_address_record` | `RealGoodsAddressRecord`（drh-common） | `RealGoodsAddressRecordDO`（ai-common） | `phone` | 032/036 |

### P1 扩展表（048 覆盖，19 张）

| # | 数据库表 | 实体类 | 手机号字段 | 改造规格 |
|---|---------|--------|-----------|---------|
| 8 | `drh_live_works_user` | `LiveWorksUser`（drh-common）/ `LiveWorksUserDO`（lms/ai/broadcast-common） | `phone` | 048 |
| 9 | `drh_user_form` | `UserForm`（drh-common）/ `UserFormDO`（lms/broadcast-common） | `phone` | 048 |
| 10 | `drh_renew_data` | `RenewData`（drh-common） | `phone` | 048 |
| 11 | `drh_applet_player` | `AppletPlayer`（drh-common） | `phone` | 048 |
| 12 | `app_study_info` | `AppStudyInfo`（drh-common） | `phone` | 048 |
| 13 | `order_book_reissue_detail` | `OrderGoodReissueDetailDO`（lms/ai-common） | `phone` | 048 |
| 14 | `drh_user` | `User`（drh-common） | `phone` | 048 |
| 15 | `drh_applet_black_phone` | `AppletBlackPhone`（drh-common） | `phone` | 048 |
| 16 | `drh_voice_robot_task_user` | `VoiceRobotTaskUser`（drh-common）/ `VoiceRobotTaskUserDO`（lms/ai-common） | `phone` | 048 |
| 17 | `drh_voice_robot_callback_details` | `VoiceRobotCallbackDetails`（drh-common）/ `VoiceRobotCallbackDetailsDO`（lms/ai-common） | `phone` | 048 |
| 18 | `drh_user_assistant` | `UserAssistant`（drh-common） | `phone` | 048 |
| 19 | `drh_app_white` | `AppWhite`（drh-common） | `phone` | 048 |
| 20 | `drh_gx_channel` | `GXChannel`（drh-common） | `phone` | 048 |
| 21 | `drh_sms_trigger_user` | `SmsTriggerUser`（drh-common）/ `SmsTriggerUserDO`（lms/ai-common） | `phone` | 048 |
| 22 | `drh_import_address_record_detail` | `ImportAddressRecordDetail`（drh-common） | `phone` | 048 |
| 23 | `drh_sph_supplier_info` | `SphSupplierInfo`（drh-common）/ `InfluencerDO`（lms/ai-common） | `phone` | 048 |
| 24 | `drh_user_service_record` | — / `UserServiceRecordDO`（lms/ai-common） | `phone` | 048 |
| 25 | `drh_leads_noqw_send_msg_task_detail` | — / `LeadsNoqwSendMsgTaskDetailDO`（lms/ai-common） | `phone` | 048 |
| 26 | `drh_wechat_complaint_order` | — / `WechatComplaintOrderDO`（lms-common） | `phone` | 048 |

### 关联辅助表（无安全字段，但接口链路中间接使用手机号）

| # | 数据库表 | 说明 |
|---|---------|------|
| A | `drh_specail_user` | 特殊用户标记；Mapper 已通过 `lu.phone_md5` 间接查询 |
| B | `drh_handover_plus` | 交接/转交记录；关联查询从 `drh_live_user` 取安全字段 |
| C | `drh_collect_order` | 统一订单；关联查询从 `drh_real_address_record` 或 `drh_live_user` 取安全字段 |
| D | `drh_order_hand_record` | **[补充]** 订单转交记录（未处理）；关联 `drh_live_user` 取安全字段 |
| E | `drh_order_hand_record_del` | **[补充]** 订单转交记录（已处理）；关联 `drh_live_user` 取安全字段 |
| F | `drh_sea_phone` | **[补充]** 号码可见性权限表；控制 `OrderUser.getPhone()` 是否返回掩码 |
| G | `drh_ad_user_pic` | **[补充]** 广告用户关联表；`/ad/pic/user/list` 主查询表 |

---

## 接口影响与数据库表映射（按模块）

### 一、drh-pay 模块

#### 1.1 H5 图书订单支付

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/h5/order/pay` | POST | 保存 | H5 图书订单创建时同步写 `phone_mask`/`phone_md5`/`phone_aes` | `drh_h5_order`（写 phone 安全字段） | landing.html、land2.html、lab.html、landCd.html、landingFb.html、landMsg.html、landingPage.html、landV.html、landingXM2.html | H5 支付接口（非微信浏览器支付）；全部为投放页面 |
| `/h5/order/open/pay` | POST | 保存 | 同上 | `drh_h5_order`（写 phone 安全字段） | landing.html、land2.html、lab.html、landingFb.html、landMsg.html、landingPage.html、landV.html、landingXM2.html | 公众号支付接口（微信浏览器内支付）；全部为投放页面 |

**中转页面（收银台跳转）**：landDesk.html、landTrans.html、landTransXM2.html — 这三个页面为中转页面，跳转到收银台，不直接调用支付接口。

#### 1.2 支付状态查询

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/h5/order/query/phone` | GET | 查询 | 按手机号查询支付状态改为 `phone_md5` 匹配 | `drh_h5_order`（读 phone_md5） | 同 1.1 涉及的全部页面 | 查询入参支持明文/前端密文/MD5 三种格式 |

#### 1.3 微信支付回调

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/h5/order/wx/notify` | POST/GET | 回调 | 微信支付回调读取 `phone_aes` 解密手机号后推送线索回调 | `drh_h5_order`（读 phone_aes → 解密）；`drh_applet_user`（写 phone 安全字段，线索回调） | 无前端页面，微信服务器回调 | 验证解密后手机号与原始手机号一致；验证线索回调推送正确 |

#### 1.4 小程序支付

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/applet/order/page/pay` | POST | 保存 | 小程序页面支付生成 H5Order 安全字段 | `drh_h5_order`（写 phone 安全字段） | 小程序内支付页面 | 回调不再依赖 DB phone 明文 |
| `/applet/order/wx/notify` | POST/GET | 回调 | 小程序微信支付回调 | `drh_h5_order`（读 phone_aes → 解密） | 无前端页面，微信服务器回调 | 同 1.3 |

#### 1.5 支付宝 H5

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/ali/pay/order` | POST | 保存 | 支付宝 H5 订单创建写安全字段 | `drh_h5_order`（写 phone 安全字段） | 投放页面（H5 跳转支付宝） | — |
| `/ali/pay/notify` | POST | 回调 | 支付宝回调线索更新按 `phone_md5` | `drh_h5_order`（读 phone_aes → 解密）；`drh_applet_user`（写/查 phone_md5） | 无前端页面，支付宝服务器回调 | — |
| `/ali/pay/orderNo/select` | GET | 查询 | 按订单号查询返回掩码 | `drh_h5_order`（读 phone_mask） | 前端支付结果页 | — |
| `/ali/pay/phone/select` | GET | 查询 | 按手机号查询返回掩码 | `drh_h5_order`（读 phone_md5 → 查，返回 phone_mask） | 前端支付状态查询 | 展示返回掩码 |

#### 1.6 学员手机号保存/更新（LiveUserService 链路）

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/activity/groupbuying/order/create` | POST | 保存 | 拼团订单创建涉及学员手机号保存，同步写安全字段 | `drh_live_user`（写 phone 安全字段）；`drh_h5_order`（写 phone 安全字段） | 拼团活动页面 | — |
| `/common/order/pay` | POST | 保存 | 通用订单支付涉及学员手机号保存 | `drh_live_user`（写 phone 安全字段） | 通用支付页面 | — |
| `/salePay/createPay*` | POST | 保存 | 促销支付涉及学员手机号保存 | `drh_live_user`（写 phone 安全字段） | 促销支付页面 | 通配符接口 |
| `/live/order/pay` | POST | 保存 | 直播订单支付涉及学员手机号保存 | `drh_live_user`（写 phone 安全字段）；`drh_h5_order`（写 phone 安全字段） | 直播购买页面 | — |
| `/live/order/applet/pay` | POST | 保存 | 小程序直播订单支付 | `drh_live_user`（写 phone 安全字段） | 小程序直播购买页面 | — |

---

### 二、drh-endpoint 模块

#### 2.1 图书登记地址编辑

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/bookPath/editAddress` | POST | 保存 | 图书登记保存 `BookQuestionRecord`；正价课地址链路保存 `RealGoodsAddressRecord` 安全字段 | `drh_book_question_record`（写 phone 安全字段）；`drh_real_address_record`（写 phone 安全字段） | orderAddress.html（我的订单-收货地址）；refundSubmit2.html（退款/投诉提交，从 refundOrder.html 进入可跳转） | — |
| `/bookPath/editAddressV2` | POST | 保存 | 同上（V2 版本） | `drh_book_question_record`（写 phone 安全字段）；`drh_real_address_record`（写 phone 安全字段） | refundSubmit2.html | — |

#### 2.2 物流/地址查询

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/bookPath/queryTrackNumOrder` | GET | 查询 | 真实地址/物流查询返回掩码手机号 | `drh_real_address_record`（读 phone_mask）；`drh_h5_order`（读 phone_mask） | 物流查询页面 | 验证返回值为掩码格式 |

#### 2.3 线索/订单查询

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/liveAuth/ad/applet/query` | GET | 查询 | `queryLeads` 按手机号查询订单/线索改为 `phone_md5` 匹配 | `drh_h5_order`（读 phone_md5）；`drh_applet_user`（读 phone_md5） | 投放页面 | 查询入参支持三种格式 |

#### 2.4 加V / 二维码链路

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/ad/pic` | GET | 查询 | 按手机号找线索改为 `phone_md5` | `drh_applet_user`（读 phone_md5） | bdsy1.html；transtion.html（跳转小程序中间页）；投放页跳转弹窗 | — |
| `/ad/v2/pic` | POST | 查询 | 同上（V2 版本） | `drh_applet_user`（读 phone_md5） | 同上 | — |
| `/ad/base/pic` | POST | 查询 | 同上（基础版本） | `drh_applet_user`（读 phone_md5） | 同上 | — |

#### 2.5 手机号授权 / 留资 / 获客助手

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/liveAuth/auth/phone/v3` | POST | 保存+查询 | 手机号授权链路写入或读取线索/学员安全字段 | `drh_applet_user`（写/读 phone 安全字段）；`drh_live_user`（写/读 phone 安全字段） | landing3_1.html（私域投放页）；app/appHome.html（APP领课组件）；录直播中间过程留资弹窗 | 核心留资入口，重点验证 |
| `/liveAuth/auth/phone/v6` | POST | 保存+查询 | 同上（V6 版本） | `drh_applet_user`（写/读 phone 安全字段）；`drh_live_user`（写/读 phone 安全字段） | 同上 | — |
| `/liveAuth/works/auth/phone*` | POST | 保存+查询 | 作品授权手机号 | `drh_live_works_user`（写 phone 安全字段）；`drh_applet_user`（写/读 phone 安全字段） | 作品授权页面 | 通配符接口 |
| `/liveAuth/*/pic` | POST | 查询 | 获客助手查询链路读取线索安全字段 | `drh_applet_user`（读 phone_md5 → 查，返回 phone_mask） | 获客助手相关页面 | — |

---

### 三、drh-kk-cms 模块

#### 3.1 CMS 线索/统计查询

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/user/phone/user` | GET | 查询 | CMS 按手机号查线索改为 `phone_md5`；展示避免明文 | `drh_applet_user`（读 phone_md5 → 查，返回 phone_mask） | CMS 后台-线索管理 | 支持明文手机号、前端加密手机号、手机号 MD5 三种格式 |
| `/user/checkCounts` | POST | 查询 | CMS 统计改为 `phone_md5` | `drh_applet_user`（读 phone_md5） | CMS 后台-统计 | — |
| `/user/selectPhone` | POST | 查询 | CMS 手机号查询 | `drh_applet_user`（读 phone_md5 → 查，返回 phone_mask） | CMS 后台 | — |

#### 3.2 图书登记/订单收货详情

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/bookPath/queryAdDetail` | GET | 查询 | 图书登记详情手机号展示返回掩码 | `drh_book_question_record`（读 phone_mask） | CMS 后台-图书登记详情 | — |
| `/bookPath/queryOrderDetail` | GET | 查询 | 订单收货详情手机号展示返回掩码 | `drh_h5_order`（读 phone_mask）；`drh_real_address_record`（读 phone_mask） | CMS 后台-订单详情 | — |
| `/bookPath/queryCollectDetail` | GET | 查询 | 统一订单收货详情手机号展示返回掩码 | `drh_real_address_record`（读 phone_mask）；`drh_collect_order`（关联查询） | CMS 后台-统一订单详情 | — |

#### 3.3 CMS 图书登记保存

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/bookPath/editAddress` | POST | 保存 | CMS 图书登记保存 | `drh_book_question_record`（写 phone 安全字段） | CMS 后台-图书登记编辑 | — |
| `/bookPath/editAddressV2` | POST | 保存 | CMS 图书登记保存 V2 | `drh_book_question_record`（写 phone 安全字段） | CMS 后台-图书登记编辑 | — |
| `/bookPath/selectCanEditV1` | POST | 查询 | 可填写用户查询改用安全字段 | `drh_applet_user`（读 phone_md5）；`drh_h5_order`（读 phone_md5） | CMS 后台-可编辑用户筛选 | — |

#### 3.4 非留资图书登记

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/external/bookQuestionRecord/create` | POST | 保存 | 非留资登记保存按 `phone_md5` / 安全字段处理 | `drh_external_book_question_record`（写 phone 安全字段） | CMS 后台-非留资登记 | — |
| `/external/bookQuestionRecord/count` | POST | 查询 | 次数判断按 `phone_md5` | `drh_external_book_question_record`（读 phone_md5） | CMS 后台 | — |
| `/external/bookQuestionRecord/queryHistoryPage` | POST | 查询 | 历史查询按 `phone_md5` / 掩码字段处理 | `drh_external_book_question_record`（读 phone_md5 → 查，返回 phone_mask） | CMS 后台-历史记录 | — |
| `/external/bookQuestionRecord/queryHistoryExpressNo` | POST | 查询 | 历史快递单号查询按 `phone_md5` | `drh_external_book_question_record`（读 phone_md5） | CMS 后台-快递单号校验 | — |

#### 3.5 统一订单地址管理

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/collect/order/editAddress` | POST | 保存 | 统一填地址链路保存 `RealGoodsAddressRecord` 安全字段 | `drh_real_address_record`（写 phone 安全字段） | CMS 后台-统一订单地址编辑 | — |
| `/collect/order/import/address/sure` | GET | 保存 | 批量导入地址确认 | `drh_real_address_record`（写 phone 安全字段）；`drh_import_address_record_detail`（关联写入） | CMS 后台-批量导入 | — |
| `/collect/order/import/address` | GET | 保存 | 批量导入地址 | `drh_real_address_record`（写 phone 安全字段） | CMS 后台-批量导入 | — |

#### 3.6 订单展示与学员管理

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/collect/order/detail` | GET | 查询 | 订单详情真实地址手机号掩码展示 | `drh_real_address_record`（读 phone_mask）；`drh_collect_order`（关联查询） | CMS 后台-订单详情 | — |
| `/collect/order/list` | POST | 查询 | 订单列表真实地址手机号掩码展示 | `drh_real_address_record`（读 phone_mask） | CMS 后台-订单列表 | — |
| `/liveCampGroup/stu/logistics` | GET | 查询 | 学员物流展示涉及真实地址手机号掩码 | `drh_real_address_record`（读 phone_mask）；`drh_live_user`（读 phone_mask） | CMS 后台-学员物流 | — |
| `/liveCampGroup/stu/search` | GET | 查询 | 学员手机号搜索改为 `phone_md5`，返回手机号为掩码 | `drh_live_user`（读 phone_md5 → 查，返回 phone_mask） | CMS 后台-学员搜索 | — |

#### 3.7 [补充] 人工核查补充接口

> 以下 3 个接口由人工核查发现未纳入原始文档，经代码分析后补充。XML Mapper 已包含 `phone_mask`/`phone_md5`/`phone_aes` 查询列，但部分接口的 **phone 字段返回仍为明文**、**搜索条件仍使用 LIKE 明文匹配**、**DTO 缺少安全字段定义**，需要进一步整改。

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/orderUser/user/list` | POST | 查询 | **[补充]** 学员管理列表，从 `drh_live_user` 关联查询手机号。XML 已 SELECT phone_mask/phone_md5/phone_aes，但存在两个问题：① 搜索条件仍使用 `luser.phone LIKE concat('%',#{input.phone},'%')` 明文模糊匹配，未改为 phone_md5；② `OrderUser.getPhone()` 有 DTO 层掩码逻辑（seaPhone=false 时返回掩码），但 phone 字段来源仍为明文 `luser.phone`，应改为返回 `phoneMask` | `drh_live_user`（读 phone/phone_mask/phone_md5/phone_aes）；`drh_handover_plus`（主查询表）；`drh_user_form`（注册判断）；`drh_sea_phone`（号码可见性权限） | CMS 后台-学员管理列表 | **待整改**：① LIKE 搜索需改为 phone_md5 精确匹配或业务确认脱敏搜索方案；② phone 返回值应统一使用 phoneMask |
| `/order/hand/list` | POST | 查询 | **[补充]** 订单转交记录列表，从 `drh_live_user` 关联查询手机号。XML 已 SELECT phone_mask/phone_md5/phone_aes，搜索已改为 `lu.phone_md5 = #{phoneMd5}`。但 `OrderHandVo` DTO 可能缺少 phoneMask/phoneMd5/phoneAes 字段定义，导致安全字段无法映射到响应 | `drh_live_user`（读 phone/phone_mask/phone_md5/phone_aes）；`drh_order_hand_record`（未处理记录表）；`drh_order_hand_record_del`（已处理记录表） | CMS 后台-订单转交列表 | **待确认**：验证 `OrderHandVo`（或 `OrderHandUserGroupDto`）是否包含 phoneMask/phoneMd5/phoneAes 字段，若缺少需补充 |
| `/ad/pic/user/list` | POST | 查询 | **[补充]** 广告线索用户列表，从 `drh_applet_user` 查询手机号。XML 已 SELECT phone_mask/phone_md5/phone_aes，搜索已改为 phone_md5 匹配。但 `AdUserPicDto.phone` 字段返回仍为数据库明文值，未改为 `phoneMask` | `drh_applet_user`（读 phone/phone_mask/phone_md5/phone_aes）；`drh_ad_user_pic`（广告用户关联）；`drh_gx_channel`（国学渠道，getGxPage）；`drh_book_question_record`（地址判断） | CMS 后台-广告线索用户列表 | **待整改**：`AdUserPicDto.phone` 返回值应改为 phoneMask，避免暴露明文 |

**未纳入原始文档的原因分析**：

- `/orderUser/user/list`：属于学员管理模块的 `OrderUserController`（非原表中的 `UserController`、`LiveCampGroupController`），原始接口清单未覆盖该 Controller。其底层查询委托给 `HandoverServiceImpl`，而 HandoverMapper.xml 中 `selectOrderUserListNewV2` 的 phone 相关逻辑在 048 D004 中已添加安全字段 SELECT，但原始文档只列出了 `selectOrderUsersSQL`、`selectChangeGoodsList` 等其他 SQL ID。
- `/order/hand/list`：属于 `OrderHandController`（订单转交管理），原始接口清单中未列出该 Controller。其底层 `OrderHandRecordMapper.xml` 和 `OrderHandRecordDelMapper.xml` 的 `getOrderPageList` 在 048 D004 中已添加安全字段 SELECT，但原始文档未将这两个 Mapper 对应的上层接口纳入。
- `/ad/pic/user/list`：属于 `AdUserPicController` 下的用户列表接口（`@RequestMapping("/ad/pic/user")`），原始接口清单只列出了同 Controller 下的 `/ad/pic`、`/ad/v2/pic`、`/ad/base/pic`（路径前缀 `/ad`），遗漏了 `/ad/pic/user/list`（路径前缀 `/ad/pic/user`）。

**各接口整改项汇总**：

| 接口 | 问题 | 整改方案 | 优先级 | 状态 |
|------|------|---------|--------|------|
| `/orderUser/user/list` | 搜索条件使用 `phone LIKE` 明文匹配 | HandoverMapper.xml 3 处改为 `<bind>` + `phone_md5` 精确匹配 | P1 | **已整改** |
| `/orderUser/user/list` | `phone` 返回值来源为明文 `luser.phone` | OrderUser.getPhone() 优先返回 phoneMask；fillOrderUserList 同步设置 phoneMask | P1 | **已整改** |
| `/order/hand/list` | `OrderHandVo` 缺少安全字段定义 | OrderHandVo 新增 phoneMask/phoneMd5/phoneAes 字段 + getPhone() 优先返回 phoneMask | P2 | **已整改** |
| `/ad/pic/user/list` | `phone` 字段返回数据库明文值 | AdUserPicServiceImpl forEach 末尾将 phone 替换为 phoneMask | P1 | **已整改** |

---

### 四、drh-callback 模块

#### 4.1 支付回调 / 内部线索新增

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/ad/order` | POST | 保存 | 支付服务间回调同步写线索安全字段 | `drh_applet_user`（写 phone 安全字段）；`drh_h5_order`（写 phone 安全字段） | 无前端页面，服务间调用 | — |
| `/appletUser/addAppletUserPhone` | POST | 保存 | 内部线索新增入口同步写安全字段 | `drh_applet_user`（写 phone 安全字段） | 无前端页面，内部服务调用 | — |

#### 4.2 百度小店回调

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/baiduCallback/receive` | POST | 保存 | 百度小店订单回调创建 AppletUser / H5Order 时写安全字段 | `drh_applet_user`（写 phone 安全字段）；`drh_h5_order`（写 phone 安全字段） | 无前端页面，百度服务器回调 | — |

#### 4.3 抖店 / 小鹅通回调

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/dd/callback` | POST | 保存 | 抖店回调创建订单与线索安全字段 | `drh_applet_user`（写 phone 安全字段）；`drh_h5_order`（写 phone 安全字段） | 无前端页面，抖店服务器回调 | — |
| `/dd/sendOrder` | POST | 保存 | 抖店推送订单 | `drh_h5_order`（写 phone 安全字段） | 无前端页面 | — |
| `/dd/goose/callback` | POST | 保存 | 小鹅通回调 | `drh_xe_order`（写 phone）；`drh_applet_user`（写 phone 安全字段） | 无前端页面 | P2 表 `drh_xe_order` 暂不写安全字段 |
| `/dd/order/changeStatus` | POST | 查询+保存 | 取消消息按 `phone_md5` 查线索 | `drh_applet_user`（读 phone_md5 → 查）；`drh_h5_order`（写 phone 安全字段） | 无前端页面 | — |

#### 4.4 第三方导入线索

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/third/external/importLeads` | POST | 保存 | 第三方导入线索去重和保存改为 `phone_md5` / 安全字段 | `drh_applet_user`（查 phone_md5 去重 + 写 phone 安全字段） | 无前端页面，第三方系统调用 | — |
| `/third/external/importLeadsV2` | POST | 保存 | 同上（V2 版本） | `drh_applet_user`（查 phone_md5 去重 + 写 phone 安全字段） | 无前端页面 | — |

#### 4.5 视频号回调

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/sph/addOrder` | POST | 保存 | 视频号订单回调保存 H5Order/线索时写安全字段 | `drh_h5_order`（写 phone 安全字段）；`drh_applet_user`（写 phone 安全字段） | 无前端页面，视频号服务器回调 | — |
| `/sph/msgCallback` | GET/POST | 保存 | 视频号消息回调 | `drh_h5_order`（写 phone 安全字段）；`drh_applet_user`（写 phone 安全字段） | 无前端页面 | — |

---

### 五、drh-media-process 模块

#### 5.1 ERP / 飞书审批 / 小鹅通回传

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/erp/callback` | POST | 保存 | ERP 回传后续处理图书登记、非留资、真实地址安全字段 | `drh_book_question_record`（写 phone 安全字段）；`drh_external_book_question_record`（写 phone 安全字段）；`drh_real_address_record`（写 phone 安全字段） | 无前端页面，ERP 系统回调 | — |
| `/fBook/callback` | POST | 保存 | 飞书审批回传后续处理 | `drh_book_question_record`（写 phone 安全字段）；`drh_real_address_record`（写 phone 安全字段） | 无前端页面，飞书服务器回调 | — |
| `/xe/callback` | POST | 保存 | 小鹅通回传后续处理 | `drh_xe_order`（写 phone）；`drh_book_question_record`（写 phone 安全字段） | 无前端页面 | P2 表 `drh_xe_order` 暂不写安全字段 |

#### 5.2 测试 / 运维入口

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/Test/execAdOrder` | GET | 保存 | 非留资订单处理按安全字段口径验证 | `drh_external_book_question_record`（写 phone 安全字段） | 无前端页面，运维/测试入口 | 仅测试环境可用 |
| `/Test/getPhone` | GET | 查询 | 手机号读取按安全字段口径验证 | `drh_h5_order`（读 phone_aes → 解密）或 `drh_applet_user`（读 phone_aes → 解密） | 无前端页面 | 仅测试环境可用 |
| `/Test/queryOrder` | GET | 查询 | 订单查询按安全字段口径验证 | `drh_h5_order`（读 phone_md5 / phone_mask） | 无前端页面 | 仅测试环境可用 |

#### 5.3 批处理 / 短信 / AI 地址填充

| 接口 | 方法 | 改动类型 | 影响点 | 涉及数据库表 | 前端调用页面 | 测试备注 |
|------|------|---------|--------|-------------|-------------|---------|
| `/smsDeal/*` | GET | 保存+查询 | 短信批处理从 `phone_aes` 解密或写安全字段 | `drh_live_user`（读 phone_aes → 解密）；`drh_applet_user`（读 phone_aes → 解密） | 无前端页面，定时任务 / 手动触发 | 验证解密正确性 |
| XXL-JOB：`fillAiAddressOrderTask` | 定时任务 | 保存 | AI 地址填充任务写安全字段 | `drh_real_address_record`（写 phone 安全字段） | 无前端页面，XXL-JOB 调度 | 验证批量写入安全字段正确 |

---

## 数据库表 × 接口读写矩阵

以下矩阵标注每张表在各模块接口中的读写方向（W=写入安全字段, R=查询/读取安全字段, D=解密 phone_aes, —=不涉及）。

| 数据库表 | drh-pay | drh-endpoint | drh-kk-cms | drh-callback | drh-media-process |
|---------|---------|-------------|-----------|-------------|-----------------|
| `drh_h5_order` | W / R / D | R | R / W | W / R / D | R / D |
| `drh_live_user` | W | W / R | R | — | R / D |
| `drh_applet_user` | — | R / W | R / W | W / R | R / D |
| `drh_book_question_record` | — | W | R / W | — | W |
| `drh_external_book_question_record` | — | — | R / W | — | W |
| `drh_book_edit_address_compensation` | — | — | — | — | — |
| `drh_real_address_record` | — | W / R | R / W | — | W |
| `drh_live_works_user` | — | W | — | — | — |
| `drh_user_form` | — | — | — | — | — |
| `drh_renew_data` | — | — | R / W | — | — |
| `drh_applet_player` | — | — | R | — | — |
| `drh_import_address_record_detail` | — | — | W | — | — |
| `drh_specail_user` | — | — | R | — | — |

注：`drh_book_edit_address_compensation` 的读写由 ju-chat ai 模块内部处理，不直接通过 drh 微服务接口暴露。

---

## 前端页面与接口映射

### 投放页面（H5 / 公众号 / 私域）

| 前端页面 | 调用接口 | 所属模块 |
|---------|---------|---------|
| landing.html | `/h5/order/pay` 或 `/h5/order/open/pay`、`/h5/order/query/phone` | drh-pay |
| land2.html | 同上 | drh-pay |
| lab.html | 同上 | drh-pay |
| landCd.html | `/h5/order/pay`（仅 H5 支付）、`/h5/order/query/phone` | drh-pay |
| landingFb.html | 同上 | drh-pay |
| landMsg.html | 同上 | drh-pay |
| landingPage.html | 同上 | drh-pay |
| landV.html | 同上 | drh-pay |
| landingXM2.html | 同上 | drh-pay |
| landing3_1.html | `/liveAuth/auth/phone/v3` | drh-endpoint |
| bdsy1.html | `/ad/pic`、`/ad/v2/pic`、`/ad/base/pic` | drh-endpoint |
| transtion.html | `/ad/pic`（跳转小程序中间页） | drh-endpoint |

### 中转页面（收银台跳转）

| 前端页面 | 说明 |
|---------|------|
| landDesk.html | 中转页面-收银台 |
| landTrans.html | 中转页面-收银台 |
| landTransXM2.html | 中转页面-收银台 |

### CMS 后台页面

| 前端页面 | 调用接口 | 所属模块 |
|---------|---------|---------|
| orderAddress.html | `/bookPath/editAddress` | drh-endpoint |
| refundSubmit2.html | `/bookPath/editAddress`、`/bookPath/editAddressV2`（从 refundOrder.html 进入可跳转） | drh-endpoint |
| app/appHome.html | `/liveAuth/auth/phone/v3`（APP领课组件） | drh-endpoint |
| CMS 后台各管理页面 | `/user/*`、`/bookPath/*`、`/collect/order/*`、`/liveCampGroup/*`、`/external/*`、`/ad/*` 系列 | drh-kk-cms |

### 小程序 / APP 页面

| 前端页面 | 调用接口 | 所属模块 |
|---------|---------|---------|
| 小程序内支付页面 | `/applet/order/page/pay`、`/applet/order/wx/notify` | drh-pay |
| 直播购买页面 | `/live/order/pay`、`/live/order/applet/pay` | drh-pay |
| 拼团活动页面 | `/activity/groupbuying/order/create` | drh-pay |
| 录直播留资弹窗 | `/liveAuth/auth/phone/v3` | drh-endpoint |

---

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - 保存链路：`phone` 来源于前端请求（明文或 AES 密文），经 `createAesInfo()` 处理后写入数据库安全字段；赋值时机为 `save()` / `insert()` 前。
  - 查询链路：`phone_md5` 来源于 Java 层 `DataSecurityInvoke.computePhoneMd5()`，在进入 Mapper 前计算完成。
  - 展示链路：`phone_mask` 来源于数据库字段，映射到 Output/DTO 时赋值；`phone_aes` 仅在需要解密时读取。
  - 回调链路：`phone_aes` 来源于数据库，在回调处理中解密后用于外部推送（线索回调、ERP 推送等）。
- 下游读取字段清单：
  - 保存链路下游读取 `phoneMask`、`phoneMd5`、`phoneAes` 三个字段入库。
  - 查询链路下游读取 `phoneMd5` 作为 WHERE 条件。
  - 展示链路下游读取 `phoneMask` 作为返回值。
  - 回调链路下游读取 `phoneAes` 解密为明文后推送。
- 空对象 / 占位对象风险：
  - 回调链路中 `new H5Order()` 后可能只 set 部分字段，必须确保 `createAesInfo()` 在 `save()` 前被调用。
  - 第三方导入线索时 `new AppletUser()` 后可能只 set phone，必须同步生成安全字段。
- 调用顺序风险：
  - 保存链路：必须先兼容处理前端输入 → 再调用 `doDsTask`（远程 FC） → 再 set 安全字段 → 最后 `save()`。
  - 查询链路：必须先计算 `phoneMd5` → 再构建查询条件 → 最后执行查询。
  - 回调链路：必须先查库获取 `phone_aes` → 再解密 → 再推送。
- 旧逻辑保持：
  - 原有事务边界、异常处理、日志输出、幂等性不变。
  - 不新增 MQ、Redis、Feign 或外部 HTTP 调用。
  - 前端页面 URL 和接口路径不变。
- 需要用户确认的设计选择：
  - P2 表（如 `drh_xe_order`）在回调链路中暂不写安全字段，后续何时纳入。
  - 部分中转页面（landDesk.html、landTrans.html、landTransXM2.html）是否有直接 API 调用或仅做跳转。

## 边界情况

- 回调接口（微信/支付宝/抖店/百度/视频号/小鹅通）由外部服务器触发，无法控制重试频率；`createAesInfo()` 中的远程 FC 调用超时不应阻断回调响应。
- 批量导入地址（`/collect/order/import/address`）可能一次导入数百条记录，`createAesInfo()` 的 FC 调用并发需评估。
- XXL-JOB 定时任务（`fillAiAddressOrderTask`）执行窗口内可能处理大量数据，需确认批处理写入安全字段的性能。
- 前端投放页面的 H5 支付和公众号支付走不同接口（`/h5/order/pay` vs `/h5/order/open/pay`），但共享相同的 `createAesInfo()` 逻辑。
- 测试/运维入口（`/Test/*`）仅限测试环境，生产环境应确保这些接口不可访问。
- 中转页面（收银台跳转）不直接调用支付接口，但可能传递手机号参数到下游页面，需确认参数传递链路中手机号格式不变。

## 需求

### 功能需求

- **FR-001**：本文档 MUST 覆盖 drh-pay、drh-endpoint、drh-kk-cms、drh-callback、drh-media-process 五个模块的全部受影响接口。
- **FR-002**：每个接口 MUST 标注改动类型（保存/查询/展示/回调）、影响的数据库表（含读写方向）、前端调用页面。
- **FR-003**：本文档 MUST 包含数据库表 × 接口读写矩阵，标注每张表在各模块的读写方向。
- **FR-004**：本文档 MUST 包含前端页面与接口的映射关系，覆盖投放页面、CMS 后台页面、小程序/APP 页面。
- **FR-005**：本文档 MUST 列出全部 26 张已改造数据库表（7 张核心表 + 19 张 P1 扩展表）。
- **FR-006**：本阶段 MUST NOT 修改业务代码。

## 成功标准

- **SC-001**：测试团队可按本文档的模块 × 接口 × 数据库表维度执行全量验证，无遗漏。
- **SC-002**：每个接口有明确的数据库表读写方向和前端页面映射。
- **SC-003**：数据库表 × 接口读写矩阵覆盖所有 26 张已改造表和 5 个微服务模块。
- **SC-004**：前端页面清单覆盖所有已知投放页面、CMS 后台页面、小程序/APP 页面和中转页面。

## 假设

- 前置规格（032/036/041/048）已完成代码改造和数据库字段添加。
- 本文档列出的前端页面清单基于用户提供，如有新增投放页面需补充。
- P2 表（如 `drh_xe_order`、`drh_ad_form_answer` 等）暂不纳入本次接口影响分析。
- 中转页面（landDesk.html、landTrans.html、landTransXM2.html）仅做跳转，不直接调用后端 API。
- drh 工程和 ju-chat 工程的接口路径和模块归属基于现有代码分析，如有新增模块需补充。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成五个微服务模块的全量接口影响分析。
- 已完成 26 张数据库表与接口的读写矩阵映射。
- 已完成前端页面与接口的映射关系。
- 已整合 032/036/041/048 四个前置规格的影响信息。
- 本阶段未修改业务代码。

### D002 - 人工核查补充接口与整改

- 触发原因：人工核查发现 3 个 drh-kk-cms 接口未纳入原始文档——`/orderUser/user/list`、`/order/hand/list`、`/ad/pic/user/list`。
- 修正内容：
  - 新增 **3.7 [补充] 人工核查补充接口** 章节，包含 3 个接口的完整分析。
  - 更新"关联辅助表"章节，新增 D/E/F/G 四张表。
  - 新增"未纳入原始文档的原因分析"和"各接口待整改项汇总"。
- **整改实现**（用户确认改为精确查询，phone 统一使用 phoneMask）：
  - **`/orderUser/user/list` 整改**（4 个文件）：
    - `HandoverMapper.xml`：3 处 `luser.phone like concat('%',#{input.phone},'%')` 改为 `<bind name="orderUserPhoneMd5" value="@com.drh.common.fc.datasec.DataSecurityInvoke@computePhoneMd5(input.phone)"/> and luser.phone_md5 = #{orderUserPhoneMd5}`（使用 `replace_all` 全局替换）。
    - `OrderUser.java`：`getPhone()` 增加 `phoneMask` 优先返回逻辑——`if (!StringUtils.isEmpty(phoneMask)) return phoneMask;`，seaPhone=true 时仍返回明文。
    - `HandoverServiceImpl.java`：`fillOrderUserList()` 方法中填充 LiveUser 数据时同步设置 `phoneMask`、`phoneMd5`、`phoneAes`。
  - **`/order/hand/list` 整改**（1 个文件）：
    - `OrderHandVo.java`：新增 `phoneMask`、`phoneMd5`、`phoneAes` 三个字段，`BeanUtils.copyProperties` 自动从 `OrderHandUserGroupDto` / `OrderHandRecordDel` 复制。新增 `getPhone()` 自定义方法，优先返回 `phoneMask`。
  - **`/ad/pic/user/list` 整改**（1 个文件）：
    - `AdUserPicServiceImpl.java`：`getPageList` 方法的 `forEach` 循环末尾新增 `if (!StringUtils.isEmpty(e.getPhoneMask())) { e.setPhone(e.getPhoneMask()); }`，在所有基于原始 phone 的中间处理（channelPrice 查询、prePhone 省市查询等）完成后，将 phone 替换为 phoneMask。
- 影响范围：drh-kk-cms 模块 5 个文件（HandoverMapper.xml、OrderUser.java、HandoverServiceImpl.java、OrderHandVo.java、AdUserPicServiceImpl.java）。
- 文档同步：已同步更新 `spec.md`（本记录）、`tasks.md`。
- 验证结果：代码已修改，待编译和接口验证。

### D003 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
