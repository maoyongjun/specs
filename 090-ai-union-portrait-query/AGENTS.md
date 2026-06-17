# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\090-ai-union-portrait-query`
- 目标项目（两个）：
  - 后端接口：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`
  - 私域调用方：`C:\workspace\ju-chat\coze_plugin\external-info-select`
- 相关模块：
  - `com.kkhc.idc.crm.controller.AiController`（新增 `userPortrait` 端点）
  - `com.kkhc.idc.crm.service.ai.AiUserPortraitService`（新增聚合服务）
  - `com.kkhc.idc.crm.service.ai.impl.AiServiceImpl`（零改动；新服务同包复用其包级方法 `queryBookLogisticsDetail`/`getEmpExternalUserDO`，见 spec D003）
  - `com.drh.select.service.AppTask`（已有 `private-domain` 分支接入新接口）

## 当前目标

- 新增按 `union_id`/`externalUserId` 聚合的用户画像查询接口，返回 4 个子对象：`userProfile`（payStatus）、`teacherInfo`（体验课主讲+班主任，**走线索表 `drh_applet_user`**）、`courseData`（正价课营期名/主讲/营期开课时间/小程序码链接，**走交接表 `drh_handover_plus`**，classTime 取 `drh_live_camp_group.start_class_time`）、`logisticsData`（图书物流 list）。
- 私域场景（`external_key` 前缀 `private-domain`）在 coze `AppTask` 私域分支取第 3 段 `externalUserId` 调用新接口，把 4 个子对象合并进私域返回。
- 后端用 `drh_emp_external_user` 把 `externalUserId` 转 `unionId` 后复用全部聚合逻辑。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、配置来源和测试落点。
- 不允许把空对象、占位 DTO 或未赋值字段当成有效输入继续传递。
- 正价课 `classTime` 必须取自 `drh_live_camp_group.start_class_time`（营期开课时间），不得用直播课 `drh_live.class_time`。
- 物流状态先读持久化 `sign_status`，非已签收再实时查物流 API；实时查询逻辑复用，不改变原 `AiServiceImpl` 行为。
- `courseLink` 按 `campId` 缓存复用，避免每次调用都请求 kapi + 上传 OSS。
- 私域分支异常不阻断原返回；非私域逻辑完全不动。

## 强制门禁

- 关键参数必须在调用前有来源：`unionId`（入参或 externalUserId 解析）、`phone`（live_user/applet_user/book 记录）、`campId`（最近营期）、`groupId`（营期）、`goodsId`（物流记录）、kapi `type/id`。
- 下游读取字段必须全部有来源：CollectOrder 查询条件、营期/营期组/营期日期查询、物流记录字段、kapi 请求体、OSS 上传参数。
- 不得用 `new XxxDto()`、空 JSON、空 Map 作为占位继续下传。
- 跨服务 HTTP（coze → `sae-gateway/kkhc-idc-ai/ai/userPortrait`）、kapi、OSS、ShowAPI、Redis key/TTL 改动必须记录并测试断言。
- 单元测试必须断言下游参数内容（CollectOrder 条件、kapi 请求体、OSS 上传入参、物流状态映射、externalUserId→unionId 解析），覆盖正常、边界、不回归路径。

## 重点代码位置

- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\controller\AiController.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\AiUserPortraitService.java`（新增）
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\impl\AiServiceImpl.java`
- `C:\workspace\ju-chat\coze_plugin\external-info-select\src\main\java\com\drh\select\service\AppTask.java`
- 测试：`kkhc-idc/ai/src/test/...AiUserPortraitServiceTest`

## 文档维护

- `spec.md` 记录需求、用户场景、历史问题防漏分析、边界、成功标准、假设和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和结果。
- `checklists/requirements.md` 记录规格质量和参数完整性检查。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
