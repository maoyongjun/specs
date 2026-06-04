# 功能规格：手机号安全改造——剩余表排查与影响分析

**功能目录**：`048-phone-security-remaining-tables-audit`  
**创建日期**：`2026-06-03`  
**状态**：Draft  
**输入**：在 032-phone-security-columns、036-phone-security-save-query、041-mybatisplus-xml-phone-md5-query 三个规格已覆盖 7 张目标表的基础上，全量扫描 `C:\workspace\drh` 和 `C:\workspace\ju-chat` 两个工程，找出所有尚未被覆盖的含 `phone` 字段的表，分析每张表涉及的实体类、Mapper、Service、Controller 和接口，并标注模块归属。本阶段只编写排查文档，不修改代码。

## 背景

- 当前问题：前三轮手机号安全改造（032/036/041）已覆盖 7 张核心表，但两个工程中仍有大量表的 `phone` 字段未被纳入改造范围。这些表如果后续也需要清空明文 `phone`，必须提前识别并评估影响面。
- 已覆盖的 7 张表：`drh_h5_order`、`drh_live_user`（含 `app_phone`）、`drh_applet_user`、`drh_book_question_record`、`drh_external_book_question_record`、`drh_book_edit_address_compensation`、`drh_real_address_record`。
- 目标行为：全量盘点剩余含 `phone` 字段的表，按优先级分类，明确每张表的改造影响面（实体类、Mapper XML、Service、Controller、模块），为后续分批改造提供依据。
- 非目标：本阶段不执行 DDL、不修改 Java / XML / SQL 代码、不回填数据。

## 排查范围与方法

- 工程范围：`C:\workspace\drh`（drh-common, drh-pay, drh-endpoint, drh-kk-cms, drh-callback, drh-media-process, drh-cms, drh-platform, drh-advertisement 等模块）、`C:\workspace\ju-chat`（kkhc-idc 下的 ai / lms / app / broadcast, kkhc-bizcenter 等模块）。
- 搜索维度：Java 实体类 `private String phone` 字段、MyBatis-Plus `@TableName` 映射、Mapper XML 中 `phone` 列引用、Java 代码中 `.eq(::getPhone, ...)` 查询、`setPhone(...)` 写入、`getPhone()` 读取。
- 排除项：已覆盖的 7 张表；`phone` 为非数据库字段（`@TableField(exist = false)`）的实体；非 MySQL 存储（MongoDB / OTS / ODPS）单独列出。

## 排查结果总览

### 统计

| 类别 | 数量 |
|------|------|
| 已改造的目标表 | 7 张 |
| 未改造的 MySQL 表（有 `phone` 字段） | **约 43 张** |
| 非 MySQL 存储（MongoDB / OTS / ODPS） | 5 个 |
| 未改造表中 Mapper XML 直接使用 `phone` 查询的 | 13 处命中 |
| 未改造表中 Java 代码使用 `.eq(getPhone, ...)` 查询的 | 14 个实体 |
| 未改造表中 Java 代码有 `setPhone()` 写入的 | 12 个实体 |
| 未改造表中 Java 代码完全未使用 `phone` 的 | 12 个实体 |

### 优先级定义

- **P1（必须改造）**：Mapper XML 或 Java 代码中有按 `phone` 的等值查询（`.eq`、`phone = #{...}`）或批量查询（`.in`），明文清空后查询直接失效。
- **P2（需要改造）**：Java 代码中有 `setPhone()` 明文写入，虽然不按 `phone` 查询，但写入链路需要同步生成安全字段。
- **P3（需业务确认）**：仅有 `phone` 的 LIKE 模糊查询、NULL 判断或 SELECT 展示，MD5 不支持模糊匹配，需要业务确认改为精确查询、脱敏搜索或排除。
- **P4（低优先 / 可不改造）**：Java 代码中完全未使用 `phone` 字段，或 `phone` 仅作为辅助展示且无写入 / 查询。

---

## P1 必须改造——有 phone 等值 / 批量查询

### 1. drh_live_works_user（作品小程序用户）

| 维度 | 内容 |
|------|------|
| 实体类（drh） | `LiveWorksUser` — `drh-common/.../entity/LiveWorksUser.java` |
| 实体类（ju-chat） | `LiveWorksUserDO` — `lms-common/.../dao/works/LiveWorksUserDO.java`；`ai-common` 和 `broadcast-common` 各有一份副本 |
| Mapper XML 命中 | `WorksShipMapper.xml`（drh-kk-cms）：`lwu.phone = #{input.phone}` 等值 + `lwu1.phone oPhone` SELECT（5 个 SQL ID）；`WorksAwardsRecordMapper.xml`（drh-kk-cms）：`lwu.phone = #{input.phone}` 等值 + SELECT（2 个 SQL ID）；`ShareIntroductionMapper.xml`（drh-kk-cms）：`dlwu.phone` SELECT |
| Service 层 | `LiveUserServiceImpl.validCode()` / `insertAllPhone()`（drh-endpoint）通过 `LambdaUpdateWrapper.set(phone, phone)` 写入；`LiveUserAsyncServiceImpl.insertPhone()`（drh-endpoint）异步写入；`WorksShipServiceImpl`（drh-kk-cms）读取展示；`WorksAwardsRecordServiceImpl`（drh-kk-cms）；`UserLearningReportServiceImpl`（drh-kk-cms） |
| Controller / 接口 | `POST /live/verify/code*`、`GET /live/checkUserPhone`、`GET /live/insertAllPhone`（drh-endpoint）；`POST /applet/banner/page`、`POST /applet/banner/invite/page`、`POST /applet/banner/class/page`、`POST /applet/banner/order/page`、`GET /applet/banner/export`（drh-kk-cms）；`GET /award/list`、`GET /award/export`（drh-kk-cms）；`GET /user/learning/report/likeData`（drh-kk-cms） |
| 影响模块 | **drh-endpoint**、**drh-kk-cms** |

### 2. drh_user_form（用户表单）

| 维度 | 内容 |
|------|------|
| 实体类（drh） | `UserForm` — `drh-common/.../entity/UserForm.java` |
| 实体类（ju-chat） | `UserFormDO` — `lms-common/.../dao/userform/UserFormDO.java`；`broadcast-common` 有副本 |
| Mapper XML 命中 | `HandoverMapper.xml`（drh-kk-cms）：`form.phone like concat('%',#{input.phone},'%')` LIKE + SELECT；`RenewDataMapper.xml`（drh-kk-cms）：`duf.phone` SELECT；`ClassStudySituationMapper.xml`（drh-kk-cms）：`duf.phone` SELECT + `duf.phone is null/not null` |
| Service 层 | `LiveUserServiceImpl.validCode()` / `insertAllPhone()`（drh-endpoint）写入；`LiveUserAsyncServiceImpl.insertPhone()`（drh-endpoint）异步写入；`RenewDataServiceImpl.getAccountCampUserFormInfo()`（drh-kk-cms）；`ClassStudySituationServiceImpl.dataView()` / `getList()`（drh-kk-cms） |
| Controller / 接口 | 同 drh_live_works_user 的 endpoint 接口；`GET /renewData/getAccountCampUserFormInfo`（drh-kk-cms）；`GET /classStudySituation/dataView`、`POST /classStudySituation/list`（drh-kk-cms） |
| 影响模块 | **drh-endpoint**、**drh-kk-cms** |

### 3. drh_renew_data（续费数据）

| 维度 | 内容 |
|------|------|
| 实体类 | `RenewData` — `drh-common/.../entity/RenewData.java` |
| Mapper XML 命中 | `RenewDataMapper.xml`（drh-kk-cms）：`drd.phone = #{dto.phone}` 等值查询 + `drd.phone` SELECT |
| Service 层 | `RenewDataServiceImpl.getList()`、`RenewDataServiceImpl.save()` / `update()`（drh-kk-cms） |
| Controller / 接口 | `POST /renewData/list`、`POST /renewData/save`、`POST /renewData/update`（drh-kk-cms） |
| 影响模块 | **drh-kk-cms** |

### 4. drh_applet_player（小程序选手）

| 维度 | 内容 |
|------|------|
| 实体类 | `AppletPlayer` — `drh-common/.../entity/applet/AppletPlayer.java` |
| Mapper XML 命中 | `AppletPlayerMapper.xml`（drh-kk-cms）：`ap.phone = #{input.phone}` 等值查询 |
| Service 层 | `AppletPlayerServiceImpl.selectPage()` / `listExport()` / `selectNextOutput()`（drh-kk-cms） |
| Controller / 接口 | `POST /applet/activity/detail/page`、`GET /applet/activity/detail/export`、`POST /applet/activity/preNext`（drh-kk-cms） |
| 影响模块 | **drh-kk-cms** |

### 5. app_study_info（APP 学习信息）

| 维度 | 内容 |
|------|------|
| 实体类 | `AppStudyInfo` — `drh-common/.../entity/app/AppStudyInfo.java` |
| Mapper XML 命中 | `AppStudyInfoMapper.xml`（drh-platform）：`ainfo.phone = #{phone}` 等值查询；另有 `@Select` 注解中 `phone = #{phone}` |
| Service 层 | `AppStudyInfoServiceImpl.getTotalStudySeconds()` / `getTotalStudyCount()`；`MyHomeServiceImpl.detail()`；`SectionServiceImpl.detail()`（drh-platform） |
| Controller / 接口 | `GET /my/home`、`GET /section/detail`（drh-platform） |
| 影响模块 | **drh-platform**（drh-app） |

### 6. order_book_reissue_detail（图书补发详情）

| 维度 | 内容 |
|------|------|
| 实体类（ju-chat） | `OrderGoodReissueDetailDO` — `lms-common/.../dao/order/fulfillment/reissue/OrderGoodReissueDetailDO.java`；`ai-common` 有副本 |
| Mapper XML 命中 | `OrderBookReissueMapper.xml`（ai / app / lms 三份副本）：`obrd.phone = #{dto.phone}` 等值查询 + `obrd.phone` SELECT + resultMap |
| Service 层 | `OrderBookReissueServiceImpl.create()` / `view()` / `del()` / `updateAddress()` / `export()`（ai / lms / app / bizcenter-product 四个模块） |
| Controller / 接口 | `POST /order/reissue/create`、`POST /order/reissue/pageQuery`、`GET /order/reissue/view`、`POST /order/reissue/del`、`POST /order/reissue/updateAddress`、`POST /order/reissue/export`（kkhc-bizcenter/product、kkhc-idc/lms、kkhc-idc/app、drh-kk-cms） |
| 影响模块 | **kkhc-bizcenter/product**、**kkhc-idc/lms**、**kkhc-idc/app**、**kkhc-idc/ai**、**drh-kk-cms** |

### 7. drh_user（用户表）

| 维度 | 内容 |
|------|------|
| 实体类 | `User` — `drh-common/.../entity/User.java`；`drh-advertisement` 中有另一个 `AppletUser` 映射同表 |
| Java 查询 | `eq(User::getPhone, phone)` — `AuthorizationServiceImpl:220`（drh-platform） |
| Service 层 | `AuthorizationServiceImpl`（登录鉴权链路）：写入 + 查询 |
| Controller / 接口 | `MyHomeController`、登录鉴权 Filter 链路（drh-platform） |
| 影响模块 | **drh-platform** |

### 8. drh_applet_black_phone（小程序黑名单手机号）

| 维度 | 内容 |
|------|------|
| 实体类 | `AppletBlackPhone` — `drh-common/.../entity/AppletBlackPhone.java` |
| Java 查询 | `eq(AppletBlackPhone::getPhone, phone)` — `AppletBlackPhoneServiceImpl`（drh-callback + drh-endpoint）；`AdBlackPhoneController`（drh-kk-cms） |
| Service 层 | `AppletBlackPhoneServiceImpl`（callback + endpoint）；`LiveAuthServiceImpl`（endpoint） |
| Controller / 接口 | 黑名单管理接口（drh-kk-cms）；手机号授权链路（drh-endpoint）；回调入口（drh-callback） |
| 影响模块 | **drh-callback**、**drh-endpoint**、**drh-kk-cms** |

### 9. drh_voice_robot_task_user（语音机器人任务用户）

| 维度 | 内容 |
|------|------|
| 实体类（drh） | `VoiceRobotTaskUser` — `drh-common/.../entity/voiceRobot/VoiceRobotTaskUser.java` |
| 实体类（ju-chat） | `VoiceRobotTaskUserDO` — `lms-common/.../dao/foreignCall/voiceRobot/VoiceRobotTaskUserDO.java`；`ai-common` 有副本 |
| Java 查询 | `eq(VoiceRobotTaskUser::getPhone, input.getPhones())` — `MessageTriggerLogServiceImpl:412`（drh-kk-cms）；`.in(::getPhone, phones)` — `VoiceRobotTaskUserServiceImpl:80` |
| Service 层 | `VoiceRobotJobServiceImpl`、`VoiceRobotJobMultiThreadServiceImpl`、`VoiceRobotServiceImpl`、`OutboundExecuteFbServiceImpl`、`OutboundExecuteDzServiceImpl`（drh-kk-cms + drh-media-process） |
| Controller / 接口 | `MessageTriggerLogController`（drh-kk-cms）；内部定时任务处理 |
| 影响模块 | **drh-kk-cms**、**drh-media-process** |

### 10. drh_voice_robot_callback_details（语音机器人回调详情）

| 维度 | 内容 |
|------|------|
| 实体类（drh） | `VoiceRobotCallbackDetails` — `drh-common/.../entity/voiceRobot/VoiceRobotCallbackDetails.java` |
| 实体类（ju-chat） | `VoiceRobotCallbackDetailsDO` — `lms-common/.../dao/foreignCall/voiceRobot/VoiceRobotCallbackDetailsDO.java`；`ai-common` 有副本 |
| Java 查询 | `.in(VoiceRobotCallbackDetails::getPhone, phones)` — `VoiceRobotCallbackDetailsServiceImpl:294`、`VoiceRobotServiceImpl:583` |
| Service 层 | `VoiceRobotCallbackDetailsServiceImpl`（drh-media-process + drh-kk-cms） |
| Controller / 接口 | 内部任务处理，无直接 HTTP 接口 |
| 影响模块 | **drh-media-process**、**drh-kk-cms** |

### 11. drh_user_assistant（用户助手）

| 维度 | 内容 |
|------|------|
| 实体类 | `UserAssistant` — `drh-common/.../entity/UserAssistant.java` |
| Java 查询 | `eq(UserAssistant::getPhone, user.getPhone())` — `MyHomeServiceImpl:226`（drh-platform） |
| Service 层 | `MyHomeServiceImpl`（drh-platform） |
| Controller / 接口 | `GET /my/home`（drh-platform） |
| 影响模块 | **drh-platform** |

### 12. drh_app_white（APP 白名单）

| 维度 | 内容 |
|------|------|
| 实体类 | `AppWhite` — `drh-common/.../entity/app/AppWhite.java` |
| Java 查询 | `eq(AppWhite::getPhone, phone)` — `AuthorizationServiceImpl:258`（drh-platform） |
| Service 层 | `AuthorizationServiceImpl`（登录鉴权链路，drh-platform） |
| Controller / 接口 | 登录鉴权 Filter 链路 |
| 影响模块 | **drh-platform** |

### 13. drh_gx_channel（共享渠道）

| 维度 | 内容 |
|------|------|
| 实体类 | `GXChannel` — `drh-common/.../entity/GXChannel.java` |
| Java 查询 | `eq(GXChannel::getPhone, phone)` — `TestController:710`（drh-kk-cms） |
| Service 层 | `LiveAuthServiceImpl:427`（drh-endpoint）写入 |
| Controller / 接口 | 测试入口（drh-kk-cms）；手机号授权链路（drh-endpoint） |
| 影响模块 | **drh-endpoint**、**drh-kk-cms** |

### 14. drh_sms_trigger_user（短信触达用户）

| 维度 | 内容 |
|------|------|
| 实体类（drh） | `SmsTriggerUser` — `drh-common/.../entity/messaging/trigger/SmsTriggerUser.java` |
| 实体类（ju-chat） | `SmsTriggerUserDO` — `lms-common/.../dao/foreignCall/smsTrigger/SmsTriggerUserDO.java`；`ai-common` 有副本 |
| Java 查询 | `eq(SmsTriggerUser::getPhone, input.getPhones())` — `MessageTriggerLogServiceImpl:412`（drh-kk-cms） |
| Service 层 | `SmsTriggerExecuteServiceImpl`（drh-kk-cms）写入；`SmsTriggerBaiWuUserCallBackHandler`（drh-media-process）读取 |
| Controller / 接口 | `MessageTriggerLogController`（drh-kk-cms） |
| 影响模块 | **drh-kk-cms**、**drh-media-process** |

### 15. drh_import_address_record_detail（导入地址详情）

| 维度 | 内容 |
|------|------|
| 实体类 | `ImportAddressRecordDetail` — `drh-common/.../entity/ImportAddressRecordDetail.java` |
| Java 查询 | `eq(ImportAddressRecordDetail::getPhone, search.getPhone())` — `ImportAddressRecordDetailServiceImpl:32`（drh-kk-cms） |
| Controller / 接口 | `CollectOrderController`（drh-kk-cms） |
| 影响模块 | **drh-kk-cms** |

### 16. drh_sph_supplier_info（视频号供应商 / 达人信息）

| 维度 | 内容 |
|------|------|
| 实体类（drh） | `SphSupplierInfo` — `drh-common/.../entity/sph/SphSupplierInfo.java` |
| 实体类（ju-chat） | `InfluencerDO` — `lms-common/.../dao/mcn/InfluencerDO.java`；`ai-common` 有副本 |
| Java 查询 | `eq(InfluencerDO::getPhone, input.getPhone())` — `InfluencerServiceImpl:156`（ju-chat lms） |
| Controller / 接口 | `InfluencerController`（kkhc-idc/lms） |
| 影响模块 | **kkhc-idc/lms** |

### 17. drh_user_service_record（用户服务记录）

| 维度 | 内容 |
|------|------|
| 实体类（ju-chat） | `UserServiceRecordDO` — `lms-common/.../dao/userrecord/UserServiceRecordDO.java`；`ai-common` 有副本 |
| Java 查询 | `eq(UserServiceRecordDO::getPhone, input.getPhone())` — `UserServiceRecordServiceImpl:99`（ju-chat, 3 个模块副本） |
| Service 层 | `UserServiceRecordServiceImpl`（lms / ai / app）；`UserProfileUserInfoFacade`（读取并 mask 后输出） |
| Controller / 接口 | `UserServiceRecordController`（kkhc-idc/lms、kkhc-idc/ai、kkhc-idc/app） |
| 影响模块 | **kkhc-idc/lms**、**kkhc-idc/ai**、**kkhc-idc/app** |

### 18. drh_leads_noqw_send_msg_task_detail（非企微线索发消息任务详情）

| 维度 | 内容 |
|------|------|
| 实体类（ju-chat） | `LeadsNoqwSendMsgTaskDetailDO` — `lms-common/.../dao/works/LeadsNoqwSendMsgTaskDetailDO.java`；`ai-common` 有副本 |
| Java 查询 | `eq(LeadsNoqwSendMsgTaskDetailDO::getPhone, condition.getPhone())` — `LeadsNoqwSendMsgTaskDetailServiceImpl:121`（3 个模块副本） |
| Service 层 | `LeadsNoqwSendMsgTaskServiceImpl`（写入）；`LeadsNoqwSendMsgTaskDetailServiceImpl`（查询） |
| Controller / 接口 | `LeadsNoqwSendMsgTaskDetailController`（kkhc-idc/lms、kkhc-idc/ai、kkhc-idc/app） |
| 影响模块 | **kkhc-idc/lms**、**kkhc-idc/ai**、**kkhc-idc/app** |

### 19. drh_wechat_complaint_order（微信投诉订单）

| 维度 | 内容 |
|------|------|
| 实体类（ju-chat） | `WechatComplaintOrderDO` — `lms-common/.../dao/order/wechat/WechatComplaintOrderDO.java` |
| Java 查询 | `eq(WechatComplaintOrderDO::getPhone, phone)` — `WxComplaintOrderServiceImpl:52`（ju-chat lms） |
| Service 层 | `WechatServiceImpl`（kkhc-bizcenter/product）写入；`ComplaintConverter`（ju-chat）读取 |
| Controller / 接口 | `WxComplaintOrderController`（kkhc-idc/lms） |
| 影响模块 | **kkhc-idc/lms**、**kkhc-bizcenter/product** |

### 20. drh_specail_user（特殊用户）

| 维度 | 内容 |
|------|------|
| 实体类 | `SpecailUser` — `drh-common/.../entity/SpecailUser.java` |
| Java 查询 | `SpecailUserServiceImpl:757`（drh-kk-cms）通过 `LiveUser` 的 `phone_md5` 间接计算后查询（已部分兼容） |
| Mapper XML | `SpecailUserMapper.xml`（drh-kk-cms）已改为 `lu.phone_md5 = #{phoneMd5}` |
| Service 层 | `SpecailUserServiceImpl`（drh-kk-cms） |
| 影响模块 | **drh-kk-cms** |
| 备注 | 该表 Mapper XML 已改造为 `phone_md5`，但表本身未确认是否已加 `phone_md5` 字段，需确认 |

---

## P2 需要改造——有 setPhone() 写入但无查询

### 21. drh_xe_order（小鹅通订单）

| 维度 | 内容 |
|------|------|
| 实体类 | `XeOrder` — `drh-common/.../entity/XeOrder.java` |
| 写入位置 | `XeOrderServiceImpl:264`（drh-media-process）；`DdApi:151`（drh-media-process） |
| 读取位置 | `XeOrderServiceImpl:697`：`record.setPhone(xeOrder.getPhone())` |
| Mapper XML | `XeOrderMapper.xml`（drh-media-process） |
| 影响模块 | **drh-media-process** |

### 22. drh_ad_form_answer（广告表单答案）

| 维度 | 内容 |
|------|------|
| 实体类 | `AdFormAnswer` — `drh-common/.../entity/AdFormAnswer.java` |
| 写入位置 | `AdController:438`（drh-callback）：`adFormAnswer.setPhone(adFormInput.getPhone())` |
| 影响模块 | **drh-callback** |

### 23. drh_ad_count（广告计数）

| 维度 | 内容 |
|------|------|
| 实体类 | `AdCount` — `drh-common/.../entity/AdCount.java` |
| 写入位置 | `AdCountServiceImpl:23`（drh-endpoint）：`adCount.setPhone(phone)` |
| 影响模块 | **drh-endpoint** |

### 24. drh_submit_time（提交时间）

| 维度 | 内容 |
|------|------|
| 实体类 | `SubmitTime` — `drh-common/.../entity/SubmitTime.java` |
| 写入位置 | `LiveAuthServiceImpl:417`（drh-endpoint）；`PhoneReportServiceImpl:144`（drh-callback） |
| 影响模块 | **drh-endpoint**、**drh-callback** |

### 25. drh_applet_small_user（小程序小用户）

| 维度 | 内容 |
|------|------|
| 实体类 | `AppletSmallUser` — `drh-common/.../entity/AppletSmallUser.java` |
| 写入位置 | `AppletUserServiceImpl:624`（drh-endpoint）：`smallUser.setPhone(appletUser.getPhone())` |
| 影响模块 | **drh-endpoint** |

### 26. drh_applet_order（小程序订单）

| 维度 | 内容 |
|------|------|
| 实体类 | `AppletOrder` — `drh-common/.../entity/AppletOrder.java` |
| 写入位置 | `AppletOrderServiceImpl:153,183`（drh-pay）：`appletOrder.setPhone(input.getPhone())` |
| 影响模块 | **drh-pay** |

### 27. drh_short_message_operation（短信操作）

| 维度 | 内容 |
|------|------|
| 实体类（drh） | `ShortMessageOperation` — `drh-common/.../entity/ShortMessageOperation.java` |
| 实体类（ju-chat） | `ShortMessageOperation` — `broadcast-common/.../entity/ShortMessageOperation.java` |
| 写入位置 | `LiveUserServiceImpl:156,669`（drh-endpoint）：`shortMessageOperation.setPhone(phone)` |
| 影响模块 | **drh-endpoint**、**drh-common** |

### 28. drh_qwb_phone_info（企微宝手机信息）

| 维度 | 内容 |
|------|------|
| 实体类 | `QwbPhoneInfo` — `drh-common/.../entity/QwbPhoneInfo.java` |
| 写入位置 | `MobileService:93`（drh-callback）：`qwbPhoneInfo.setPhone(phone)` |
| 读取位置 | `MobileService:99`：`phoneDetail.getPhone()` |
| 影响模块 | **drh-callback** |

### 29. drh_goods_user_coupon（用户优惠券）

| 维度 | 内容 |
|------|------|
| 实体类（drh） | `GoodsUserCoupon` — `drh-common/.../entity/GoodsUserCoupon.java` |
| 实体类（ju-chat） | `GoodsUserCouponDO` — `lms-common/.../dao/order/GoodsUserCouponDO.java`；`broadcast-common` 有副本 |
| 写入位置 | `GoodsCouponServiceImpl:454`（drh-endpoint）：`goodsUserCoupon.setPhone(input.getPhone())` |
| 影响模块 | **drh-endpoint** |

### 30. drh_order_refund_record（退费记录）

| 维度 | 内容 |
|------|------|
| 实体类（drh） | `OrderRefundRecord` — `drh-common/.../entity/OrderRefundRecord.java` |
| 实体类（ju-chat） | `OrderRefundRecordDO` — `lms-common/.../dao/order/OrderRefundRecordDO.java`；`ai-common` 有副本 |
| 写入位置 | `OrderRefundRecordServiceImpl:953`（drh-kk-cms）：`orderRefundRecord.setPhone(input.getReturnInfoDto().getPhone())` |
| 影响模块 | **drh-kk-cms** |

### 31. drh_sms_trigger_user_callback（短信触达回调）

| 维度 | 内容 |
|------|------|
| 实体类 | `SmsTriggerUserCallback` — `drh-common/.../entity/messaging/trigger/SmsTriggerUserCallback.java` |
| 写入位置 | `SmsTriggerBaiWuUserCallBackHandler:136,356`（drh-media-process）；`BaiWuSmsCallbackServiceImpl:84`（drh-callback） |
| 读取位置 | `SmsTriggerBaiWuUserCallBackHandler:120,127,130` |
| 影响模块 | **drh-media-process**、**drh-callback** |

### 32. drh_koc（KOC 达人）

| 维度 | 内容 |
|------|------|
| 实体类（ju-chat） | `KocDO` — `lms-common/.../dao/circle/KocDO.java` |
| 写入位置 | `KocFacade:71,131`（ju-chat）：`kocDo.setPhone(input.getPhone())` |
| 读取位置 | `KocFacade:107`：`output.setPhone(kocDO.getPhone())` |
| Controller / 接口 | `KocController`、`AppCircleContentController`（kkhc-idc/lms、kkhc-idc/app、kkhc-bizcenter/lms） |
| 影响模块 | **kkhc-idc/lms**、**kkhc-idc/app**、**kkhc-bizcenter/lms** |

---

## P3 需业务确认——LIKE / NULL 判断 / 展示类

### 33. drh_register_works（注册作品）

| 维度 | 内容 |
|------|------|
| 实体类 | `RegisterWorks` — `drh-cms/.../entity/RegisterWorks.java` |
| Mapper XML | `RegisterWorksMapper.xml`（drh-cms）：`w.phone like concat('%',#{works.phone},'%')` LIKE + `w.phone` SELECT |
| Service 层 | `RegisterWorksServiceImpl.selectDetail()` / `selectAll()` |
| Controller / 接口 | `GET /works/select`、`GET /works/export`（drh-cms） |
| 影响模块 | **drh-cms** |
| 备注 | MD5 不支持 LIKE 模糊匹配，需业务确认改为精确查询或脱敏搜索方案 |

### 34. drh_sms_deal（短信处理记录）

| 维度 | 内容 |
|------|------|
| 无独立实体 | 通过 `HandoverPlusMapper.xml`（drh-media-process）直接 INSERT |
| Mapper XML | `HandoverPlusMapper.xml`：`INSERT IGNORE into drh_sms_deal (..., phone, ...) VALUES (#{item.phone}...)` + SELECT `lu.phone`（从 drh_live_user） |
| Service 层 | `HandoverPlusServiceImpl.saveSmsDtosBatch()`；`SendSmsTaskServiceImpl.DTask()` / `DTaskV2()` / `MTask()` |
| Controller / 接口 | `GET /smsDeal/DTask`、`GET /smsDeal/MTask`（drh-media-process） |
| 影响模块 | **drh-media-process** |
| 备注 | 直接 INSERT 明文 phone，需评估该表是否需要 phone_md5 或仅保留为日志型记录 |

### 35. drh_temp_phone（临时手机号）

| 维度 | 内容 |
|------|------|
| 实体类 | `TempPhone` — `drh-common/.../entity/TempPhone.java` |
| Mapper XML | `AppletUserMapper.xml`（drh-media-process）：`LEFT JOIN drh_temp_phone tp ON tp.phone = au.phone` JOIN |
| Service 层 | `TempPhoneServiceImpl.insert()`（已注释掉，返回空列表） |
| Controller / 接口 | `GET /Test/insertPhone`（已注释掉，不活跃） |
| 影响模块 | **drh-media-process** |
| 备注 | 当前处于**非活跃状态**，唯一活跃用法是在 AppletUserMapper.xml 中作为 LEFT JOIN 排除临时号码。如该表 phone 不再更新，JOIN 条件需改为 phone_md5 |

### 36. drh_mall_order（商城订单，字段名 reciver_phone）

| 维度 | 内容 |
|------|------|
| 实体类 | `MallOrder` — `drh-common/.../entity/MallOrder.java`（推断） |
| Mapper XML | `MallOrderMapper.xml`（drh-kk-cms）：`mo.reciver_phone like concat('%',#{input.reciverPhone},'%')` LIKE + SELECT |
| Service 层 | `MallOrderServiceImpl.selectPageByInput()` / `doSaveOrder()` |
| Controller / 接口 | `POST /mall/list`、`POST /mall/save`（drh-kk-cms） |
| 影响模块 | **drh-kk-cms** |
| 备注 | 字段名是 `reciver_phone` 而非 `phone`，但属于手机号敏感字段，需评估是否同步纳入 |

---

## P4 低优先——Java 代码未使用 phone 字段

以下表的实体类中虽然定义了 `phone` 字段（或数据库表中有 `phone` 列），但 Java Service 层代码中没有对 `phone` 的查询、写入或读取操作。如果后续确认这些表不会按 `phone` 查询，可不纳入改造。

| # | 表名 | 实体类 | 说明 |
|---|------|--------|------|
| 37 | drh_user_input | `UserInput` | 无 Java 代码使用 phone |
| 38 | drh_user_deal | `UserDeal` | 无 Java 代码使用 phone |
| 39 | drh_add_qw_msg_record | `AddQwMsgRecord` | 无 Java 代码使用 phone |
| 40 | drh_asset_agent | `AssetAgent` / `AssetAgentDO` | 无 Java 代码使用 phone |
| 41 | drh_stu_card | `StuCard` | 无 Java 代码使用 phone |
| 42 | drh_express_detail | `ExpressDetail` | 无 Java 代码使用 phone |
| 43 | drh_goose_live_user | `GooseLiveUser` | 无 Java 代码使用 phone |
| 44 | drh_message_send_record | `MessageSendRecord` | 无 Java 代码使用 phone |
| 45 | drh_question_record_v2 | `QuestionRecordV2` | 无 Java 代码使用 phone |
| 46 | drh_front_emp_class_order | `FrontEmpClassOrder` | 无 Java 代码使用 phone |
| 47 | drh_user_question | `UserQuestion` / `UserQuestionDO` | 无 Java 代码使用 phone |
| 48 | drh_dd_order | `DdOrder` | 仅有 `isNull(DdOrder::getPhone)` 用于数据补偿判断 |

---

## 非 MySQL 存储（单独列出）

| # | 存储类型 | 集合 / 索引名 | 类名 | 模块 | 备注 |
|---|---------|-------------|------|------|------|
| 49 | MongoDB | landing_talk_record | `LandingTalkInput` | drh-common | 落地通话记录 |
| 50 | MongoDB | drh_applet_activity_like | `AppletActivityLike` | drh-common | 小程序活动点赞 |
| 51 | OTS (Tablestore) | drh_huacai_coin_record | `HuacaiCoinRecord` | drh-common / broadcast-common | 花菜币记录 |
| 52 | OTS (Tablestore) | 异常请求数据 | `AbnormalRequestData` | drh-common | 异常请求数据 |
| 53 | ODPS | tock_applet_user | `TockAppletUser` | drh-common | 数据分析表 |

---

## 模块影响矩阵

| 模块 | P1 表数 | P2 表数 | P3 表数 | P4 表数 | 主要影响接口 |
|------|---------|---------|---------|---------|-------------|
| **drh-endpoint** | 4 | 5 | 0 | 0 | 手机号授权、验证、补录、广告、支付查询 |
| **drh-kk-cms** | 8 | 2 | 2 | 0 | CMS 后台查询、续费、活动、订单、学员管理 |
| **drh-platform** | 3 | 0 | 0 | 0 | APP 首页、学习统计、登录鉴权 |
| **drh-media-process** | 2 | 1 | 3 | 0 | 小鹅通订单、短信任务、语音机器人、批处理 |
| **drh-callback** | 1 | 4 | 0 | 0 | 广告回调、投诉、企微宝、短信回调 |
| **drh-pay** | 0 | 1 | 0 | 0 | 小程序订单支付 |
| **drh-cms** | 0 | 0 | 1 | 0 | 作品管理 |
| **ju-chat kkhc-idc/lms** | 4 | 0 | 0 | 0 | 补发订单、达人、服务记录、消息任务 |
| **ju-chat kkhc-idc/ai** | 3 | 0 | 0 | 0 | 服务记录、消息任务（与 lms 副本） |
| **ju-chat kkhc-idc/app** | 3 | 0 | 0 | 0 | 补发订单、服务记录（与 lms 副本） |
| **ju-chat kkhc-bizcenter** | 1 | 1 | 0 | 0 | 补发订单、KOC 达人 |
| **ju-chat broadcast** | 0 | 1 | 0 | 0 | 短信操作（广播模块） |

## 跨工程副本同步风险

ju-chat 工程中大量 DO 类在 `ai-common`、`lms-common`、`broadcast-common` 三个模块中存在副本。改造时必须同步修改所有副本，否则会出现部分模块已改造、部分未改造的不一致状态。需要重点关注的副本实体：

- `LiveWorksUserDO`（lms-common + ai-common + broadcast-common）
- `UserFormDO`（lms-common + broadcast-common）
- `GoodsUserCouponDO`（lms-common + broadcast-common）
- `VoiceRobotTaskUserDO`（lms-common + ai-common）
- `VoiceRobotCallbackDetailsDO`（lms-common + ai-common）
- `SmsTriggerUserDO`（lms-common + ai-common）
- `UserServiceRecordDO`（lms-common + ai-common）
- `LeadsNoqwSendMsgTaskDetailDO`（lms-common + ai-common）
- `OrderGoodReissueDetailDO`（lms-common + ai-common）
- `InfluencerDO`（lms-common + ai-common）

## 需要用户确认的设计选择

- **P3 中的 LIKE 查询**（drh_user_form、drh_register_works、drh_mall_order）：MD5 不支持模糊匹配，需要确认改为精确查询、脱敏搜索方案还是排除改造。
- **drh_temp_phone**：当前处于非活跃状态，是否纳入改造取决于后续是否会重新启用。
- **drh_sms_deal**：INSERT 明文 phone 的日志型表，是否需要 phone_md5 或保持原样。
- **P4 表**：12 张表 Java 代码完全未使用 phone，是否需要在数据库层面移除 phone 列以减少维护负担，还是保留但标记为不改造。
- **drh_mall_order.reciver_phone**：字段名非 `phone` 但是手机号敏感字段，是否按同口径纳入改造。
- **drh_live_user.app_phone**：前三轮规格已明确排除在线代码改造，仅历史回填。本轮排查不涉及。

## 假设

- 已改造的 7 张表（032/036/041 覆盖）不在本次排查范围内。
- 搜索结果基于静态代码分析，运行时动态拼接 SQL 或通过反射操作的 phone 字段可能遗漏。
- 部分表的 `phone` 字段可能存储的不是用户手机号（如内部联系电话、供应商电话），需要业务确认是否属于个人隐私数据。
- P4 表中 "Java 代码未使用 phone" 的结论基于当前代码搜索，未来新增功能可能会使用。

## 需求

- **FR-001**：本规格 MUST 列出两个工程中所有含 `phone` 字段且未被 032/036/041 覆盖的 MySQL 表。
- **FR-002**：本规格 MUST 为每张未覆盖的表标注优先级（P1-P4）、影响的实体类、Mapper XML、Service、Controller 和模块。
- **FR-003**：本规格 MUST 识别 ju-chat 工程中跨模块副本的实体类，提示同步修改风险。
- **FR-004**：本规格 MUST 列出非 MySQL 存储（MongoDB / OTS / ODPS）中含 phone 字段的集合。
- **FR-005**：本阶段 MUST NOT 修改任何业务代码。

## 成功标准

- **SC-001**：排查文档覆盖两个工程中所有含 phone 字段的未改造表，无遗漏。
- **SC-002**：每张表有明确的优先级分类和影响面分析（实体、Mapper、Service、Controller、模块）。
- **SC-003**：跨模块副本实体已标注，避免后续改造遗漏。
- **SC-004**：需要业务确认的设计选择已记录。

## 执行记录

### D001 - 文档记录

- 已创建本排查规格文档。
- 已完成 drh 和 ju-chat 两个工程的全量静态搜索。
- 搜索维度：Java 实体类 phone 字段、@TableName 映射、Mapper XML phone 引用、Java 代码 .eq(getPhone) 查询、setPhone 写入、getPhone 读取。
- 已按 P1-P4 优先级分类，并分析每张表的完整调用链（Mapper → Service → Controller → 模块）。
- 识别 ju-chat 工程中 10 组跨模块副本实体。
- 本阶段未修改任何业务代码。

### D002 - P1 表实现记录

- 触发原因：用户确认对 P1 表开始改造，并生成 DDL SQL，同步更新 juzi-service 刷数据接口。
- 改动范围涉及 3 个工程：`C:\workspace\drh`、`C:\workspace\ju-chat`、`C:\workspace\ju-chat\data-RC\juzi-service`。

**DDL SQL**：
- 新增 `phone-security-p1-ddl.sql`，为 19 张 P1 表添加 `phone_mask`、`phone_md5`、`phone_aes` 三字段和 `phone_md5` 索引。
- 包含前置检查（information_schema 查询）和后置验证。

**实体类改动**（35 个文件）：
- drh-common 15 个实体：`LiveWorksUser`、`UserForm`、`RenewData`、`AppletPlayer`、`AppStudyInfo`、`User`、`AppletBlackPhone`、`VoiceRobotTaskUser`、`VoiceRobotCallbackDetails`、`UserAssistant`、`AppWhite`、`GXChannel`、`SmsTriggerUser`、`SphSupplierInfo`、`SpecailUser`。
- ju-chat lms-common 10 个 DO：`LiveWorksUserDO`、`UserFormDO`、`OrderGoodReissueDetailDO`、`UserServiceRecordDO`、`LeadsNoqwSendMsgTaskDetailDO`、`WechatComplaintOrderDO`、`InfluencerDO`、`VoiceRobotTaskUserDO`、`VoiceRobotCallbackDetailsDO`、`SmsTriggerUserDO`。
- ju-chat ai-common 8 个 DO 副本同步修改。
- ju-chat broadcast-common 2 个实体副本同步修改（`LiveWorksUser`、`UserForm`）。
- 每个实体在 `phone` 字段后追加 `phoneMask`、`phoneMd5`、`phoneAes` 三个持久化字段。

**juzi-service 刷数据接口**：
- `PhoneSecurityBackfillService.java` 的 `TARGETS` 列表从 8 个目标扩展到 27 个目标（原 8 + 新增 19）。
- 新增的 19 个 BackfillTarget 与现有回填逻辑完全兼容：同一批次查询、同一 FC 加密入口、同一 JDBC batch update。

**Mapper XML 改动**（8 个文件，含 3 份副本）：
- `WorksShipMapper.xml`（drh-kk-cms）：`lwu.phone = #{input.phone}` → `lwu.phone_md5 = #{input.phoneMd5}`，`lwu1.phone` → `lwu1.phone_md5`，`lwu2.phone` → `lwu2.phone_md5`。
- `WorksAwardsRecordMapper.xml`（drh-kk-cms）：`lwu.phone = #{input.phone}` → `lwu.phone_md5 = #{input.phoneMd5}`。
- `RenewDataMapper.xml`（drh-kk-cms）：`drd.phone=#{dto.phone}` → `drd.phone_md5=#{dto.phoneMd5}`。
- `AppletPlayerMapper.xml`（drh-kk-cms）：`ap.phone = #{input.phone}` → `ap.phone_md5 = #{input.phoneMd5}`。
- `AppStudyInfoMapper.xml`（drh-platform）：`ainfo.phone = #{phone}` → `ainfo.phone_md5 = #{phoneMd5}`。
- `OrderBookReissueMapper.xml`（ai/app/lms 三份 + kkhc workspace 两份）：`obrd.phone = #{dto.phone}` → `obrd.phone_md5 = #{dto.phoneMd5}`。
- 所有 SELECT 列中的 `phone` 保持不动。
- LIKE 查询（如 HandoverMapper.xml 中的 `form.phone like`）未改动，待业务确认。

**Service 层改动**：
- drh-kk-cms 4 个 Service：`WorksShipServiceImpl`、`WorksAwardsRecordServiceImpl`、`RenewDataServiceImpl`、`AppletPlayerServiceImpl`。在 Mapper 调用前通过 `DataSecurityInvoke.computePhoneMd5()` 计算 phoneMd5。
- drh-platform 1 个 Service：`AppStudyInfoServiceImpl`。`getTotalStudySeconds` 和 `getTotalStudyCount` 方法内部计算 phoneMd5 后传给 Mapper。
- drh-platform Mapper：`AppStudyInfoMapper.java` 的 `@Select` 注解从 `phone = #{phone}` 改为 `phone_md5 = #{phoneMd5}`。
- ju-chat / kkhc `OrderBookReissueServiceImpl`（5 个文件）：使用 `DigestUtils.md5DigestAsHex()` 计算 phoneMd5（ju-chat 无 drh-common 依赖）。

**DTO / Input 类改动**：
- drh-kk-cms：`AppletShipInput`（+`oPhoneMd5`、`superPhoneMd5`）、`AppletUnionIdShipInput`（+`phoneMd5`）、`WorksAwardInput`（+`phoneMd5`）、`RenewDataListDto`（+`phoneMd5`）、`AppletPlayerInput`（+`phoneMd5`）。
- ju-chat：`LmsPageQueryOrderBookReissueInput`（+`phoneMd5`）、`LmsQueryExportDataDto`（+`phoneMd5`），lms-common 和 ai-common 两份副本同步修改。

**排除项**：
- HandoverMapper.xml 中 drh_user_form 的 LIKE 查询未改动（P3 待确认）。
- ShareIntroductionMapper.xml 中 drh_live_works_user 的 SELECT 展示未改动。
- ClassStudySituationMapper.xml 中 drh_user_form 的 NULL 判断和 SELECT 未改动。
- drh_import_address_record_detail 实体类在 drh 工程中未找到，跳过。

### D003 - P2 表实现记录

- 触发原因：用户确认对 P2 表开始改造，生成 DDL SQL，修改实体类和 Service 层保存链路，同步更新 juzi-service 刷数据接口。

**DDL SQL**：
- 新增 `phone-security-p2-ddl.sql`，为 12 张 P2 表添加 `phone_mask`、`phone_md5`、`phone_aes` 三字段和 `phone_md5` 索引。

**实体类改动**（16 个文件）：
- drh-common 10 个实体：`XeOrder`、`AdFormAnswer`、`AdCount`、`AppletSmallUser`、`AppletOrder`、`ShortMessageOperation`、`QwbPhoneInfo`、`GoodsUserCoupon`、`OrderRefundRecord`、`SmsTriggerUserCallback`。
- `SubmitTime` 已有安全字段，跳过。
- ju-chat lms-common 3 个 DO：`GoodsUserCouponDO`、`OrderRefundRecordDO`、`KocDO`。
- ju-chat ai-common 1 个 DO 副本：`OrderRefundRecordDO`。
- ju-chat broadcast-common 2 个实体副本：`GoodsUserCouponDO`、`ShortMessageOperation`。

**juzi-service 刷数据接口**：
- `PhoneSecurityBackfillService.java` 的 `TARGETS` 列表从 27 个目标扩展到 **39 个目标**（原 27 + 新增 12 P2 表）。

**Service 层保存链路改动**（drh 工程 11 个文件，15 个写入点）：
- `XeOrderServiceImpl.doSaveOrder()`（drh-media-process）：setPhone 后调用 `buildPhoneSecurity()` 生成安全字段。
- `AdController`（drh-callback）：AdFormAnswer setPhone 后生成安全字段再 insert。
- `AdCountServiceImpl.insertCount()`（drh-endpoint）：AdCount setPhone 后生成安全字段再 save。
- `LiveUserServiceImpl`（drh-endpoint）：`validCodeV2()` 和 `insertAllPhone()` 中 UserForm / LiveWorksUser 的 LambdaUpdateWrapper 追加 `.set(phoneMask/phoneMd5/phoneAes)`；`sendMessage()` 和 `insertOperation()` 中 ShortMessageOperation 生成安全字段。
- `AppletUserServiceImpl.saveUsersByEmp()`（drh-endpoint）：AppletSmallUser setPhone 后生成安全字段。
- `AppletOrderServiceImpl.create()`（drh-pay）：AppletOrder setPhone 后生成安全字段。
- `GoodsCouponServiceImpl.receiveCouponHandle()`（drh-endpoint）：GoodsUserCoupon setPhone 后生成安全字段。
- `OrderRefundRecordServiceImpl.saveRefundOrder()`（drh-kk-cms）：OrderRefundRecord setPhone 后生成安全字段再 saveBatch。
- `SmsTriggerBaiWuUserCallBackHandler`（drh-media-process）：两处 SmsTriggerUserCallback setPhone 后生成安全字段。
- `BaiWuSmsCallbackServiceImpl`（drh-callback）：SmsTriggerUserCallback setPhone 后生成安全字段。
- `LiveAuthServiceImpl`（drh-endpoint）：SubmitTime 和 GXChannel setPhone 后生成安全字段。

**Service 层保存链路改动**（ju-chat 工程 2 个文件）：
- `KocFacade.upsertKoc()`（lms + app 两个模块副本）：setPhone 后使用 `DigestUtils.md5DigestAsHex()` 计算 phoneMd5，本地 substring 计算 phoneMask，phoneAes 暂由回填接口补齐。

**排除项**：
- MobileService 中 QwbPhoneInfo 的 setPhone 不涉及 DB 写入（LambdaUpdateWrapper 只更新 avatar/name/isFriend），跳过。
- AppletUserServiceImpl 的 saveUsers/saveUsers6 已使用 createAesInfo()，跳过。
- ju-chat 中 OrderRefundRecordServiceImpl / GoodsUserCouponServiceImpl 无 setPhone + DB 写入链路，跳过。
- ju-chat broadcast-common 的 ShortMessageOperation.createOperation() 为死代码（无调用方），跳过。
