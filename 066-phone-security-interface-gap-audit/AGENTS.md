# 规格执行说明

本目录用于记录手机号安全改造的接口补遗审计。当前任务只创建文档，不修改业务代码、不新增 DDL、不回写历史规格。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\066-phone-security-interface-gap-audit`
- 目标项目：
  - `C:\workspace\ju-chat\kkhc`
  - `C:\workspace\drh`
- 相关模块：
  - `kkhc-idc/app`、`kkhc-idc/lms`、`kkhc-idc/ai`
  - `kkhc-bizcenter/app`
  - `drh-kk-cms`
  - `drh-media-process`

## 当前目标

- 汇总 `050/051/060/063/065` 已有手机号安全 DDL 与接口覆盖情况。
- 补充未列入原主清单的 HTTP、Feign、回调入口。
- 明确已确认漏改接口、代码证据、影响表和后续修复建议。

## 执行原则

- 只记录代码事实和可执行修复任务，不在本规格内直接修改业务代码。
- 主接口矩阵只覆盖 HTTP、Feign、回调入口；定时任务、批处理、纯 service 放入风险清单。
- 已由 `050/060/063/065` 覆盖的接口只引用，不重复展开为待修复项。
- 精确手机号查询的默认修复口径为计算 `phoneMd5` 后查 `phone_md5`。
- 返回字段默认口径为 `phone` 展示掩码，并保留 `phoneMask/phoneMd5/phoneAes`；`065` 已明确的 app `/app/collect/order/pageQuery` 例外返回 `phoneAes`。
- 模糊手机号搜索不能直接等价替换为 MD5，必须在规格中标记为产品确认项或新增可搜索索引方案。

## 强制门禁

后续进入代码修复前必须完成以下检查，并记录到 `tasks.md`：

- 每个接口的入口 Controller、Feign 或回调方法已确认。
- 每个查询入参 `phone` 的来源、格式和赋值时机已确认。
- 每个响应字段 `phone/phoneMask/phoneMd5/phoneAes` 的来源已确认。
- 每个保存链路是否调用 `createAesInfo()` 或等价安全字段生成方法已确认。
- 所有明文查询残留均有代码行证据或已标记为非本轮范围。
- 模糊查询、导出、ERP/外呼等需要明文的链路有明确业务口径。

## 重点代码位置

- `C:\workspace\ju-chat\kkhc\kkhc-idc\app\src\main\java\com\kkhc\idc\lms\facade\order\OrderPageProcessorDataFacade.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\lms\src\main\java\com\kkhc\idc\lms\facade\order\OrderPageProcessorDataFacade.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\*\src\main\java\com\kkhc\idc\lms\service\order\fulfillment\reissue\impl\OrderGoodReissueDetailServiceImpl.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\*\src\main\java\com\kkhc\idc\lms\service\works\impl\LeadsNoqwSendMsgTaskDetailServiceImpl.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\*\src\main\java\com\kkhc\idc\lms\service\userrecord\impl\UserServiceRecordServiceImpl.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\*\src\main\java\com\kkhc\idc\lms\service\order\wechat\impl\WxComplaintOrderServiceImpl.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\*\src\main\java\com\kkhc\idc\ad\controller\leads\AppletUserController.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\lms\src\main\java\com\kkhc\idc\ad\controller\mcn\InfluencerController.java`
- `C:\workspace\ju-chat\kkhc\kkhc-bizcenter\app\src\main\java\com\kkhc\bizcenter\app\controller\leads\LeadsController.java`
- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\controller\FrontWorkController.java`
- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\controller\workServe\front\FrontMyClassController.java`
- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\controller\CollectOrderController.java`
- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\controller\MallController.java`
- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\controller\messaging\trigger\MessageTriggerLogController.java`

## 文档维护

- `spec.md` 记录接口补遗、漏改清单、非 HTTP 风险、需求和成功标准。
- `tasks.md` 记录已完成的文档审计，以及后续修复建议和验证任务。
- `checklists/requirements.md` 验证规格质量和实施就绪度。
- 后续若用户确认模糊手机号搜索方案，必须追加新的 Dxxx 纠正记录。
