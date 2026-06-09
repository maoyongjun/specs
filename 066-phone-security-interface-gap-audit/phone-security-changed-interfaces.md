# 手机号安全改造接口清单

**来源**：用户已整理接口清单  
**整理日期**：2026-06-09  
**说明**：本文档仅记录已整理的改动接口，原文中的 `[图片]` 保留为截图占位；空白表示原清单未填写。

## drh-pay

| 接口 / 入口 | 业务场景 | 类型 | 前端 / 调用位置 | 改动点 | 数据库 / 表 | 测试备注 |
|---|---|---|---|---|---|---|
| `POST /h5/order/pay` | H5 图书订单支付 | 保存 | `/h5/order/pay`：投放页面 H5 支付接口，非微信浏览器支付。页面：`landing.html`、`land2.html`、`lab.html`、`landCd.html`、`landingFb.html`、`landMsg.html`、`landingPage.html`、`landV.html`、`landingXM2.html`、`landDesk.html`（中转页面-收银台）、`landTrans.html`（中转页面-收银台）、`landTransXM2.html`（中转页面-收银台） | H5 图书订单创建时同步写 `phone_mask` / `phone_md5` / `phone_aes` | `drh_h5_order`（写 phone 安全字段） | `[图片]`、`[图片]` |
| `POST /h5/order/open/pay` | H5 图书订单支付 | 保存 | `/h5/order/open/pay`：投放页面公众号支付接口，微信浏览器内支付。页面：`landing.html`、`land2.html`、`lab.html`、`landingFb.html`、`landMsg.html`、`landingPage.html`、`landV.html`、`landingXM2.html` | H5 图书订单创建时同步写 `phone_mask` / `phone_md5` / `phone_aes` | `drh_h5_order`（写 phone 安全字段） |  |
| `GET /h5/order/query/phone?phone=xxxxxxxxx` | 支付状态查询 | 查询 | 支付前查询是否支付；同 `/h5/order/pay` 涉及页面 | 按手机号查询支付状态改为 `phone_md5` 匹配 | `drh_h5_order`（读 `phone_md5`） | `[图片]` |
| `POST/GET /h5/order/wx/notify` | 微信支付回调 | 回调 |  | 微信支付回调读取 `phone_aes` 解密手机号后推送线索回调 | `drh_h5_order`（读 `phone_aes` 后解密）；`drh_applet_user`（写 phone 安全字段，线索回调） | `[图片]` |
| `POST /applet/order/page/pay` | 小程序支付 | 保存 |  | 小程序页面支付生成 H5Order 安全字段，回调不再依赖 DB `phone` 明文 | `drh_h5_order`（写 phone 安全字段） |  |
| `POST/GET /applet/order/wx/notify` | 小程序支付 | 回调 | 小程序页面支付回调 | 回调读取 `phone_aes` 解密手机号 | `drh_h5_order`（读 `phone_aes` 后解密） |  |
| `POST /ali/pay/order` | 支付宝 H5 | 保存 | 支付宝小程序，无需关注 | 支付宝 H5 订单创建、回调、查询：线索更新按 `phone_md5`，展示返回掩码 | `drh_h5_order`（写 phone 安全字段） |  |
| `POST /ali/pay/notify` | 支付宝 H5 | 回调 | 支付宝小程序，无需关注 | 支付宝回调线索更新按 `phone_md5` | `drh_h5_order`（读 `phone_aes` 后解密）；`drh_applet_user`（写/查 `phone_md5`） |  |
| `GET /ali/pay/orderNo/select` | 支付宝 H5 | 查询 | 支付宝小程序，无需关注 | 按订单号查询返回掩码 | `drh_h5_order`（读 `phone_mask`） |  |
| `GET /ali/pay/phone/select` | 支付宝 H5 | 查询 | 支付宝小程序，无需关注 | 按手机号查询返回掩码 | `drh_h5_order`（读 `phone_md5` 查询，返回 `phone_mask`） |  |
| `POST /activity/groupbuying/order/create` | 学员手机号保存/更新（LiveUserService 链路） | 保存 | 小程序拼团活动，现在不使用 | 拼团订单创建涉及学员手机号保存，同步写安全字段 | `drh_live_user`（写 phone 安全字段）；`drh_h5_order`（写 phone 安全字段） |  |
| `POST /common/order/pay` | 学员手机号保存/更新（LiveUserService 链路） | 保存 | 录直播打赏调用；不用处理 | 通用订单支付涉及学员手机号保存 | `drh_live_user`（写 phone 安全字段） |  |
| `POST /salePay/createPay*` | 学员手机号保存/更新（LiveUserService 链路） | 保存 | `createPayV2`：支付链接创建订单，在订单列表生成支付链接 | 促销支付涉及学员手机号保存 | `drh_live_user`（写 phone 安全字段） |  |
| `POST /live/order/pay` | 学员手机号保存/更新（LiveUserService 链路） | 保存 | 录直播、直播、回放支付功能；不用处理 | 直播订单支付涉及学员手机号保存 | `drh_live_user`（写 phone 安全字段）；`drh_h5_order`（写 phone 安全字段） |  |
| `POST /live/order/applet/pay` | 学员手机号保存/更新（LiveUserService 链路） | 保存 | 不用处理 | 小程序直播订单支付 | `drh_live_user`（写 phone 安全字段） |  |

## drh-endpoint

| 接口 / 入口 | 业务场景 | 类型 | 前端 / 调用位置 | 改动点 | 数据库 / 表 | 测试备注 |
|---|---|---|---|---|---|---|
| `POST /bookPath/editAddress` | 图书登记地址编辑 | 保存 | `/bookPath/editAddress`：我的订单收货地址 `orderAddress.html`；退款/投诉提交 `refundSubmit2.html`（从 `refundOrder.html` 页面进入可跳转）；老系统/服务系统订单列表和线索列表填写收货地址 | 图书登记保存 BookQuestionRecord，并在正价课地址链路保存 RealGoodsAddressRecord 安全字段 | `drh_book_question_record`（写 phone 安全字段）；`drh_real_address_record`（写 phone 安全字段）；`drh_external_book_question_record`；`pic/user/` | `[图片]` |
| `POST /bookPath/editAddressV2` | 图书登记地址编辑 | 保存 | 退款/投诉提交 `refundSubmit2.html`（从 `refundOrder.html` 页面进入可跳转）；老系统/服务系统订单列表和线索列表填写收货地址 | 图书登记保存 BookQuestionRecord；正价课地址链路保存 RealGoodsAddressRecord 安全字段 | `drh_book_question_record`（写 phone 安全字段）；`drh_real_address_record`（写 phone 安全字段）；`drh_external_book_question_record` |  |
| `GET /bookPath/queryTrackNumOrder` | 物流/地址查询 | 查询 | @葛金超；`refundOrder.html`；正价课查询物流信息，查到之后跳转 `logisticsDetail.html`；接口出参有手机号，入参没有 | 真实地址/物流查询返回掩码手机号 | `drh_real_address_record`（读 `phone_mask`）；`drh_h5_order`（读 `phone_mask`） | `[图片]` |
| `GET /liveAuth/ad/applet/query` | 线索/订单查询 | 查询 | @葛金超；投放页 `landing.html`；弹窗填手机和有保护期按钮；查询线索是否存在或用户是否支付过当前落地页配置商品 | `queryLeads` 按手机号查询订单/线索改为 `phone_md5` 匹配 | `drh_h5_order`（读 `phone_md5`）；`drh_applet_user`（读 `phone_md5`） |  |
| `GET /ad/pic` | 加 V / 二维码链路 | 查询 | `/ad/base/pic`；`bdsy1.html`；`transtion.html`（跳转小程序中间页，多个投放页跳转小程序时经过）；投放页跳转弹窗 | 加 V / 二维码链路按手机号找线索改为 `phone_md5` | `drh_applet_user`（读 `phone_md5`） |  |
| `POST /ad/v2/pic` | 加 V / 二维码链路 | 查询 | @葛金超 | 按手机号找线索改为 `phone_md5` | `drh_applet_user`（读 `phone_md5`） |  |
| `POST /ad/base/pic` | 加 V / 二维码链路 | 查询 | @葛金超 | 按手机号找线索改为 `phone_md5` | `drh_applet_user`（读 `phone_md5`） |  |
| `POST /liveAuth/auth/phone/v3` | 手机号授权 / 留资 / 获客助手 | 保存+查询 | `/liveAuth/auth/phone/v3`：`landing3_1.html` 私域投放页；`app/appHome.html` app 领课组件；录直播中间过程留资弹窗 | 手机号授权、留资、获客助手查询链路写入或读取线索/学员安全字段 | `drh_applet_user`（写/读 phone 安全字段）；`drh_live_user`（写/读 phone 安全字段） | `[图片]` |
| `POST /liveAuth/auth/phone/v6` | 手机号授权 / 留资 / 获客助手 | 保存+查询 |  | 手机号授权链路写入或读取线索/学员安全字段 | `drh_applet_user`（写/读 phone 安全字段）；`drh_live_user`（写/读 phone 安全字段） |  |
| `POST /liveAuth/works/auth/phone*` | 手机号授权 / 留资 / 获客助手 | 保存+查询 | 作品授权手机号 | 作品授权手机号链路写入安全字段 | `drh_live_works_user`（写 phone 安全字段）；`drh_applet_user`（写/读 phone 安全字段） |  |
| `POST /liveAuth/*/pic` | 手机号授权 / 留资 / 获客助手 | 查询 |  | 获客助手查询链路读取线索安全字段 | `drh_applet_user`（读 `phone_md5` 查询，返回 `phone_mask`） |  |

## drh-kk-cms

| 接口 / 入口 | 业务场景 | 类型 | 前端 / 调用位置 | 改动点 | 数据库 / 表 | 测试备注 |
|---|---|---|---|---|---|---|
| `GET /user/phone/user` | CMS 线索/统计查询 | 查询 | 营期消耗、当期成交、往期成交 | CMS 按手机号查线索/统计改为 `phone_md5`；展示避免明文；支持明文手机号、前端加密手机号、手机号 MD5 三种格式 | `drh_applet_user`（读 `phone_md5` 查询，返回 `phone_mask`） |  |
| `POST /user/checkCounts` | CMS 线索/统计查询 | 查询 | 前端已经注掉 | CMS 统计改为 `phone_md5` | `drh_applet_user`（读 `phone_md5`） |  |
| `POST /user/selectPhone` | CMS 线索/统计查询 | 查询 | 前端已经注掉 | CMS 手机号查询 | `drh_applet_user`（读 `phone_md5` 查询，返回 `phone_mask`） |  |
| `GET /bookPath/queryAdDetail` | 图书登记/订单收货详情 | 查询 | 线索列表-查看物流信息 | 图书登记/订单收货详情手机号展示返回掩码 | `drh_book_question_record`（读 `phone_mask`） | `[图片]` |
| `GET /bookPath/queryOrderDetail` | 图书登记/订单收货详情 | 查询 |  | 订单收货详情手机号展示返回掩码 | `drh_h5_order`（读 `phone_mask`）；`drh_real_address_record`（读 `phone_mask`） |  |
| `GET /bookPath/queryCollectDetail` | 图书登记/订单收货详情 | 查询 | 订单管理-订单详情（KC 订单详情）收货地址 | 订单收货详情手机号展示返回掩码 | `drh_real_address_record`（读 `phone_mask`）；`drh_collect_order`（关联查询） | `[图片]` |
| `POST /bookPath/editAddress` | CMS 图书登记保存 | 保存 |  | CMS 图书登记保存/可填写用户查询改用安全字段 | `drh_book_question_record`（写 phone 安全字段） |  |
| `POST /bookPath/editAddressV2` | CMS 图书登记保存 | 保存 | 老系统/服务系统：运营小工具-快递信息 | CMS 图书登记保存 V2 | `drh_book_question_record`（写 phone 安全字段） |  |
| `POST /bookPath/selectCanEditV1` | CMS 图书登记保存 | 查询 | 老系统/服务系统：运营小工具-快递信息 | 可填写用户查询改用安全字段 | `drh_applet_user`（读 `phone_md5`）；`drh_h5_order`（读 `phone_md5`） |  |
| `POST /external/bookQuestionRecord/create` | 非留资图书登记 | 保存 | 老系统/服务系统：运营小工具-快递信息 | 非留资登记保存按 `phone_md5` / 安全字段处理 | `drh_external_book_question_record`（写 phone 安全字段） |  |
| `POST /external/bookQuestionRecord/count` | 非留资图书登记 | 查询 | 老系统/服务系统：运营小工具-快递信息 | 次数判断按 `phone_md5` | `drh_external_book_question_record`（读 `phone_md5`） |  |
| `POST /external/bookQuestionRecord/queryHistoryPage` | 非留资图书登记 | 查询 | 老系统/服务系统：运营小工具-快递信息 | 历史查询按 `phone_md5` / 掩码字段处理 | `drh_external_book_question_record`（读 `phone_md5` 查询，返回 `phone_mask`） | `[图片]` |
| `POST /external/bookQuestionRecord/queryHistoryExpressNo` | 非留资图书登记 | 查询 | 老系统/服务系统：运营小工具-快递信息 | 历史快递单号查询按 `phone_md5` | `drh_external_book_question_record`（读 `phone_md5`） |  |
| `POST /collect/order/editAddress` | 统一订单地址管理 | 保存 | @葛金超 | 统一填地址、批量导入地址链路保存 RealGoodsAddressRecord 安全字段 | `drh_real_address_record`（写 phone 安全字段） |  |
| `GET /collect/order/import/address/sure` | 统一订单地址管理 | 保存 | @葛金超 | 批量导入地址确认 | `drh_real_address_record`（写 phone 安全字段）；`drh_import_address_record_detail`（关联写入） | `[图片]` |
| `GET /collect/order/import/address` | 统一订单地址管理 | 保存 | @葛金超 | 批量导入地址 | `drh_real_address_record`（写 phone 安全字段） | `[图片]` |
| `GET /collect/order/detail` | 订单展示与学员管理 | 查询 | KC 单号订单详情 | 订单详情、订单列表、学员物流展示涉及真实地址手机号掩码展示 | `drh_real_address_record`（读 `phone_mask`）；`drh_collect_order`（关联查询） | `[图片]` |
| `POST /collect/order/list` | 订单展示与学员管理 | 查询 | KC 单号列表查询（已隐藏的订单管理） | 订单详情真实地址手机号掩码展示 | `drh_real_address_record`（读 `phone_mask`） | `[图片]`；原备注：这个自动没有在页面显示 |
| `GET /liveCampGroup/stu/logistics` | 订单展示与学员管理 | 查询 | @葛金超 | 学员物流展示涉及真实地址手机号掩码 | `bookPath/editAddressOrder`（读 `phone_mask`）；`drh_live_user`（读 `phone_mask`） |  |
| `GET /liveCampGroup/stu/search` | 订单展示与学员管理 | 查询 | @葛金超 | 学员手机号搜索改为 `phone_md5`，返回手机号为掩码 | `drh_live_user`（读 `phone_md5` 查询，返回 `phone_mask`） |  |
| `POST /orderUser/user/list` | CMS 后台-学员管理列表 | 查询 | 用户通表-全部用户-用户通表 | 学员管理列表从 `drh_live_user` 关联查询手机号。XML 已 SELECT `phone_mask` / `phone_md5` / `phone_aes`，但搜索条件仍使用 `luser.phone LIKE concat('%',#{input.phone},'%')` 明文模糊匹配，已改为 `phone_md5`；`OrderUser.getPhone()` 有 DTO 层掩码逻辑（`seaPhone=false` 时返回掩码），但 `phone` 字段来源仍为明文 `luser.phone`，应改为返回 `phoneMask` | `drh_live_user`（读 `phone` / `phone_mask` / `phone_md5` / `phone_aes`）；`drh_handover_plus`（主查询表）；`drh_user_form`（注册判断）；`drh_sea_phone`（号码可见性权限） |  |
| `POST /order/hand/list` | CMS 后台-订单异常交接列表 | 查询 | 用户通表-全部用户-带入营期，异常交接班 | 订单转交记录列表从 `drh_live_user` 关联查询手机号。XML 已 SELECT `phone_mask` / `phone_md5` / `phone_aes`，搜索已改为 `lu.phone_md5 = #{phoneMd5}`；但 `OrderHandVo` DTO 可能缺少 `phoneMask` / `phoneMd5` / `phoneAes` 字段定义，导致安全字段无法映射到响应 | `drh_live_user`（读 `phone` / `phone_mask` / `phone_md5` / `phone_aes`）；`drh_order_hand_record`（未处理记录表）；`drh_order_hand_record_del`（已处理记录表） |  |
| `POST /ad/pic/user/list` | CMS 后台-广告线索用户列表 | 查询 |  | 广告线索用户列表从 `drh_applet_user` 查询手机号。XML 已 SELECT `phone_mask` / `phone_md5` / `phone_aes`，搜索已改为 `phone_md5` 匹配；但 `AdUserPicDto.phone` 字段返回仍为数据库明文值，未改为 `phoneMask` | `drh_applet_user`（读 `phone` / `phone_mask` / `phone_md5` / `phone_aes`）；`drh_ad_user_pic`（广告用户关联）；`drh_gx_channel`（国学渠道，`getGxPage`）；`drh_book_question_record`（地址判断） |  |
| `POST /ad/pic/user/importFile` | CMS 后台-广告线索导入 | 导入 |  | 线索导入手机号，入库添加加密信息 | `drh_applet_user` | `[图片]` |
| `POST /ad/pic/user/list/pool` | CMS TMK 线索列表 | 查询 |  | 客户线索查询加密信息 | 关联 `drh_applet_user` 手机号 | `[图片]` |
| `POST /ad/black/phone/list` | CMS 后台投放黑名单列表 | 查询 |  | 投放黑名单列表查询手机号加密信息 | `drh_applet_black_phone` | `[图片]` |
| `POST /ad/black/phone/save` | CMS 后台投放黑名单添加 | 保存 |  | 投放黑名单保存手机加密信息 | `drh_applet_black_phone` | `[图片]` |
| `POST /supplier/list` | CMS 后台供应商列表查询 | 查询 |  | 供应商列表查询 | `drh_sph_supplier_info` | `[图片]` |
| `POST /supplier/add` | CMS 后台供应商添加 | 保存 |  | 供应商列表添加 | `drh_sph_supplier_info` | `[图片]`、`[图片]` |
| `POST /supplier/edit` | CMS 后台供应商编辑 | 修改 |  | 供应商列表修改 | `drh_sph_supplier_info` | `[图片]` |
| `POST /emp/save` | CMS 后台新建账号 | 添加账号 |  | 密码 MD5 存储 | `drh_kk_one_emp`；`drh_kk_emp` | `[图片]`、`[图片]` |
| `POST /emp/change/password` | CMS 后台修改密码 | 修改密码 |  | 密码修改后 MD5 存储 | `drh_kk_one_emp`；`drh_kk_emp` | `[图片]`、`[图片]` |
| `POST /emp/login` | CMS 后台登录 | 登录 |  | 登录验证数据库 MD5 密码 | `drh_kk_one_emp`；`drh_kk_emp` | `[图片]` |
| `POST liveCampGroup/live/base/v3` | 班级详情-学生维度-基础信息 | 查询 |  | 班级详情学生维度基础信息读取学员手机号相关字段 | `drh_live_user` |  |

## drh-callback

| 接口 / 入口 | 业务场景 | 类型 | 前端 / 调用位置 | 改动点 | 数据库 / 表 | 测试备注 |
|---|---|---|---|---|---|---|
| `POST /ad/order` | 支付回调 / 内部线索新增 | 保存 |  | 支付服务间回调/内部线索新增入口同步写线索安全字段 | `drh_applet_user`（写 phone 安全字段）；`drh_h5_order`（写 phone 安全字段） |  |
| `POST /appletUser/addAppletUserPhone` | 支付回调 / 内部线索新增 | 保存 |  | 内部线索新增入口同步写安全字段 | `drh_applet_user`（写 phone 安全字段） |  |
| `POST /baiduCallback/receive` | 百度小店回调 | 保存 |  | 百度小店订单回调创建 AppletUser / H5Order 时写安全字段 | `drh_applet_user`（写 phone 安全字段）；`drh_h5_order`（写 phone 安全字段） |  |
| `POST /dd/callback` | 抖店 / 小鹅通回调 | 保存 |  | 抖店回调创建订单与线索安全字段 | `drh_applet_user`（写 phone 安全字段）；`drh_h5_order`（写 phone 安全字段） |  |
| `POST /dd/sendOrder` | 抖店 / 小鹅通回调 | 保存 |  | 抖店推送订单 | `drh_h5_order`（写 phone 安全字段） |  |
| `POST /dd/goose/callback` | 抖店 / 小鹅通回调 | 保存 |  | 小鹅通回调 | `drh_xe_order`（写 phone）；`drh_applet_user`（写 phone 安全字段） |  |
| `POST /dd/order/changeStatus` | 抖店 / 小鹅通回调 | 保存 |  | 取消消息按 `phone_md5` 查线索 | `drh_applet_user`（读 `phone_md5` 查询）；`drh_h5_order`（写 phone 安全字段） |  |
| `POST /third/external/importLeads` | 第三方导入线索 | 保存 |  | 第三方导入线索去重和保存改为 `phone_md5` / 安全字段 | `drh_applet_user`（查 `phone_md5` 去重，写 phone 安全字段） |  |
| `POST /third/external/importLeadsV2` | 第三方导入线索 | 保存 |  | 第三方导入线索去重和保存改为 `phone_md5` / 安全字段 | `drh_applet_user`（查 `phone_md5` 去重，写 phone 安全字段） |  |
| `POST /sph/addOrder` | 视频号回调 | 保存 |  | 视频号订单回调保存 H5Order/线索时写安全字段 | `drh_h5_order`（写 phone 安全字段）；`drh_applet_user`（写 phone 安全字段） |  |
| `GET/POST /sph/msgCallback` | 视频号回调 | 保存 |  | 视频号消息回调 | `drh_h5_order`（写 phone 安全字段）；`drh_applet_user`（写 phone 安全字段） |  |
| `POST /qw/addPhone` | H5 留资线索 | 保存 |  | H5 落地页保存线索 | `drh_applet_user`（写 phone 安全字段） |  |

## drh-media-process

| 接口 / 入口 | 业务场景 | 类型 | 前端 / 调用位置 | 改动点 | 数据库 / 表 | 测试备注 |
|---|---|---|---|---|---|---|
| `POST /erp/callback` | ERP / 飞书审批 / 小鹅通回传 | 保存 |  | ERP / 飞书审批 / 小鹅通回传后续处理图书登记 | `drh_book_question_record`（写 phone 安全字段）；`drh_external_book_question_record`（写 phone 安全字段）；`drh_real_address_record`（写 phone 安全字段） |  |
| `POST /fBook/callback` | ERP / 飞书审批 / 小鹅通回传 | 保存 |  | 飞书审批回传后续处理 | `drh_book_question_record`（写 phone 安全字段）；`drh_real_address_record`（写 phone 安全字段） |  |
| `POST /xe/callback` | ERP / 飞书审批 / 小鹅通回传 | 保存 |  | 小鹅通回传后续处理 | `drh_xe_order`（写 phone）；`drh_book_question_record`（写 phone 安全字段） |  |
| `GET /Test/execAdOrder` | 测试 / 运维入口 | 保存 | @葛金超 | 测试/运维入口涉及非留资订单处理和手机号读取，按安全字段口径验证 | `drh_external_book_question_record`（写 phone 安全字段） |  |
| `GET /Test/getPhone` | 测试 / 运维入口 | 查询 | @葛金超 | 手机号读取按安全字段口径验证 | `drh_h5_order`（读 `phone_aes` 后解密）或 `drh_applet_user`（读 `phone_aes` 后解密） |  |
| `GET /Test/queryOrder` | 测试 / 运维入口 | 查询 | @葛金超 | 订单查询按安全字段口径验证 | `drh_h5_order`（读 `phone_md5` / `phone_mask`） |  |
| `GET /smsDeal/*` | 批处理 / 短信 / AI 地址填充 | 保存+查询 | @葛金超 | 批处理/短信/AI 地址填充任务从 `phone_aes` 解密或写安全字段 | `drh_live_user`（读 `phone_aes` 后解密）；`drh_applet_user`（读 `phone_aes` 后解密） |  |
| 相关 XXL-JOB：`fillAiAddressOrderTask` | 批处理 / 短信 / AI 地址填充 | 保存 | @葛金超 | AI 地址填充任务写安全字段 | `drh_real_address_record`（写 phone 安全字段） |  |

## APP 相关

| 模块 | 接口 / 入口 | 业务场景 | 类型 | 前端 / 调用位置 | 改动点 | 数据库 / 表 |
|---|---|---|---|---|---|---|
| `endpoint` | `POST /liveAuth/auth/phone/v3` | 手机号授权 / 留资 / 获客助手 | 保存 | @王学明 | 手机号授权、留资、获客助手查询链路写入或读取线索/学员安全字段 | `drh_applet_user`（写/读 phone 安全字段）；`drh_live_user`（写/读 phone 安全字段） |
| `bizcenter-lms` | `POST /pageQueryKoc` | KOC 信息查询 | 查询，废弃手机号字段 |  | 查询 KOC 信息 | `drh_koc` |
| `bizcenter-lms` | `GET /koc/getKocDetail` | KOC 详情查询 | 查询，废弃手机号字段 |  | 查询单个 KOC 信息 | `drh_koc` |
| `bizcenter-app` | `POST /activity/passport/processNewUserRegistration` | 注册护照 | 废弃接口 | 登录后调用，接口现在不再注册护照信息 | 注册护照 | `drh_app_passport` |
| `bizcenter-app` | `POST /auth/bandAppPhoneUnionId` | 绑定手机号 | 保存 |  | 绑定手机号 | `drh_live_user`（写/读 phone 安全字段） |
| `bizcenter-app` | `POST /auth/queryAppPhoneUnionBanding` | 查询手机号绑定 | 查询 |  | 返回手机号时从明文改成 AES 密文 + 电话掩码 | `drh_live_user`（写/读 phone 安全字段） |
| `bizcenter-app` | `POST /live/user/unbindAppPhone` | 解绑手机号 | 保存 |  | 解绑手机号 | `drh_live_user`（写/读 phone 安全字段） |
| `bizcenter-app` | `POST /collectOrder/queryLogisticsDetail` | APP 我的订单物流地址 | 查询 | APP-我的-我的订单-查询物流地址 | 支持明文 + 密文 |  |
| `endpoint` | `POST /endpoint/app/loginAndGetUserInfoV2` | APP 登录并获取用户信息 | 保存，废弃手机号使用 |  | 废弃手机号使用 |  |
| `bizcenter-app` | `POST /collectOrder/pageQueryMyOrders` | APP 我的订单分页查询 | 查询 |  | 查询回来的 `phone` 字段内容改成 `phoneAes` |  |

---

## 066 补充：已修改但原清单未列接口

以下接口已在现有规格或当前代码中完成手机号安全改造，但未出现在上方清单，追加用于测试回归和接口验收。

| 模块 | 接口 / 入口 | 类型 | 改动点 | 数据库 / 表 | 来源 / 备注 |
| --- | --- | --- | --- | --- | --- |
| kkhc-idc app | `POST /app/collect/order/pageQuery` | 查询返回 | 返回 `phoneMask/phoneMd5/phoneAes`；按 065 约定，app 侧 `phone` 字段保留返回 `phoneAes` | `drh_real_address_record` | 065 |
| kkhc-idc lms | `POST /app/collect/order/pageQuery` | 查询返回 | 返回 `phoneMask/phoneMd5/phoneAes`；lms 侧 `phone` 字段返回脱敏手机号 | `drh_real_address_record` | 065 |
| kkhc-idc lms | `GET /collect/order/import/address` | 导入保存 | 导入地址明细保存手机号安全字段，后续真实地址和学员回填同步安全字段 | `drh_import_address_record_detail`、`drh_real_address_record`、`drh_live_user` | 063 |
| kkhc-idc lms | `GET /collect/order/download/address/failList` | 导出 / 查询 | 失败列表手机号返回脱敏值 | `drh_import_address_record_detail` | 063 |
| kkhc-idc lms | `GET /collect/order/import/address/sure` | 导入确认 | 确认导入真实地址时同步手机号安全字段 | `drh_import_address_record_detail`、`drh_real_address_record`、`drh_live_user` | 063 |
| kkhc-idc lms | `POST /collect/order/import/address/detail` | 查询 | 查询手机号计算 `phoneMd5`，查询落到 `phone_md5`，返回脱敏值和安全字段 | `drh_import_address_record_detail` | 063 / 当前代码 |
| kkhc-idc lms | `GET /collect/order/import/address/job` | 任务入口 | 导入确认任务链路纳入手机号安全回归 | `drh_import_address_record_detail`、`drh_real_address_record` | 063 |
| kkhc-idc app/lms | `POST /order/reissue/pageQuery` | 查询 | 查询条件已计算 `phoneMd5`，明细查询落到 `phone_md5`，XML 已映射 `phone_mask/phone_md5/phone_aes` | `order_book_reissue_detail` | 048 / 当前代码 |
| kkhc-idc app/lms | `POST /order/reissue/getExportDataList` | 导出 | 导出查询输入手机号已转换为 `phoneMd5` | `order_book_reissue_detail` | 048 / 当前代码 |
| kkhc-idc ai | `GET /book/getBookQuestionRecordByAppletUserId` | 查询 | 明文手机号入参计算 `phoneMd5`，查询问卷记录和外部问卷记录的 `phone_md5` | `drh_book_question_record`、`drh_external_book_question_record` | 当前代码 |

## 066 补充：待修改接口

以下接口当前代码仍存在明文查询、明文返回或安全字段缺失风险。修复前不要标记为已完成。

| 优先级 | 模块 | 接口 / 入口 | 待修改点 | 代码证据 / 备注 |
| --- | --- | --- | --- | --- |
| P1 | kkhc-idc app/lms | `POST /order/getOrderPage` | 订单分页仍把学员明文手机号写回响应，应改为返回 `phoneMask` 或调用统一脱敏方法 | `OrderPageProcessorDataFacade` 仍有 `record.setPhone(liveUser.getPhone())`；ai 版本已使用 `phoneMaskForDisplay` |
| P1 | kkhc-idc app/lms/ai | `POST /order/reissue/pageDetailQuery` | 详情查询仍按明文手机号查询，应改为入参计算 `phoneMd5` 并查询 `phone_md5` | `OrderGoodReissueDetailServiceImpl` 仍按 `OrderGoodReissueDetailDO::getPhone` 查询 |
| P1 | kkhc-idc app/lms、kkhc-bizcenter app | `POST /applet/user/listByEntity`、`POST /applet/user/get/one/by/condition`、`POST /leads/select` | 通过实体条件传入 `phone` 时仍会按 `drh_applet_user.phone` 明文查询；`/leads/select` 会通过 Feign 触发该查询；需补 `phoneMask/phoneMd5/phoneAes` 字段并改为 `phoneMd5` 查询 | `AppletUserController` 调用 `setEntity(appletUserDo)`；`AppletUserServiceImpl.getListByEntity` 使用实体条件；`kkhc-bizcenter app` 的 `AppletUserFacade` 会 `setPhone(phone)` |
| P1 | kkhc-idc app/lms | `/wechat/saveComplaintOrder`、`/wechat/getWxComplaintOrderCount` | 投诉单保存和统计仍使用明文手机号；需保存安全字段并按 `phoneMd5` 统计 | `WxComplaintOrderServiceImpl` 仍使用 `WechatComplaintOrderDO::getPhone` |
| P1 | kkhc-idc app/lms/ai | `/leads-noqw-send-msg-task-detail/exportList`、`/leads-noqw-send-msg-task-detail/listAll`、`/leads-noqw-send-msg-task-detail/pageList` | 任务明细查询仍按明文手机号过滤，应改为 `phoneMd5` | `LeadsNoqwSendMsgTaskDetailServiceImpl` 仍按 `LeadsNoqwSendMsgTaskDetailDO::getPhone` 查询 |
| P1 | kkhc-idc app/lms/ai | `/userServiceRecord/getRecords` | 服务记录查询仍按明文手机号过滤，应改为 `phoneMd5`；创建和批量创建还需确认 converter 是否生成安全字段 | `UserServiceRecordServiceImpl` 仍按 `UserServiceRecordDO::getPhone` 查询 |
| P1 | kkhc-idc lms | `mcn/influencer/add`、`mcn/influencer/edit` | 达人手机号重复校验仍使用明文手机号；需落安全字段并按 `phoneMd5` 校验 | `InfluencerServiceImpl` 明文手机号重复校验 |
| P1 | drh-kk-cms | `frontWork/queryList`、`frontWork/queryListV2`、`frontWork/getAllInfo` | 仍对 `AppletUser.phone` 做 `LIKE` 模糊查询；MD5 不能等价支持模糊搜索，需产品确认改为精确查询、禁用手机号模糊搜索，或新增可搜索索引方案 | `FrontWorkServiceImpl` 仍有 `AppletUser::getPhone LIKE` |
| P1 | drh-kk-cms | `front/myClass/user/list`、`front/myClass/user/pageList`、`live/summary/export` | 仍对 `AppletUser.phone` 做 `LIKE` 模糊查询；需与 `frontWork` 同步确认搜索策略 | `FrontMyClassBaseServiceImpl` 仍有 `AppletUser::getPhone LIKE` |
| P1 | drh-kk-cms | `collect/order/import/address/detail` | 本地导入地址明细查询仍按明文手机号过滤；即使当前 HTTP 入口走 kkhc lms Feign，本地 service 也应同步修复或下线 | `ImportAddressRecordDetailServiceImpl` 仍按 `ImportAddressRecordDetail::getPhone` 查询 |
| P2 | drh-kk-cms | `mall/list`、`mall/save` | 商城订单查询存在 `reciver_phone LIKE`，列表返回也包含原始收件手机号；需确认模糊搜索策略、保存安全字段并默认返回脱敏值 | `MallOrderMapper.xml` 使用 `mo.reciver_phone like` 并 select `mo.reciver_phone` |
| P1 | drh-kk-cms | `messageTrigger/log/query` | 消息触发日志查询仍通过明文手机号关联外呼和短信任务用户；应将输入手机号集合归一化为 `phoneMd5` 后查询 | `MessageTriggerLogServiceImpl` 仍查 `VoiceRobotTaskUser::getPhone`、`SmsTriggerUser::getPhone` |
| P2 | drh-media-process | 外呼 / 短信回调任务链路 | 非单一 HTTP 接口，但回调和任务处理仍存在明文手机号匹配风险；需作为回调风险单独跟踪 | `VoiceRobotTaskUserServiceImpl`、`VoiceRobotCallbackDetailsServiceImpl` 及任务 handler 链路 |
