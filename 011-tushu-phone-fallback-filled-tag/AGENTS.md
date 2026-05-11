# 规格执行说明

本目录记录 `011-tushu-phone-fallback-filled-tag`，作用范围包含：

- 规格文档：`C:\workspace\ju-chat\specs\011-tushu-phone-fallback-filled-tag`
- 目标代码：`C:\workspace\ju-chat\coze_plugin\external-info-select\src\main\java\com\drh\select\service\AppTask.java`
- 目标代码：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\lms\controller\book\BookQuestionRecordController.java`
- 目标代码：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\lms\service\book\BookQuestionRecordService.java`
- 目标代码：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\lms\service\book\impl\BookQuestionRecordServiceImpl.java`
- 目标代码：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\impl\AiServiceImpl.java`

## 当前目标

- `AppTask#setTushu` 在 `applet_user_id` 为空时不直接拦截，使用 OTS 基础信息里的手机号继续查询图书物流。
- 图书物流查询接口同时支持 `appletUserId` 和 `phone` 两个非必填参数，至少一个有值即可查询。
- `AiServiceImpl#selectUserCampDateIdInfo` 在标签营期补偿分支中识别当前企微员工下的“已填写”标签，并写入 `if_tushu=是`。

## 实现约束

- 不修改图书物流响应 JSON 的字段语义。
- 不修改 OTS 表结构、Redis key 结构或外部网关路径。
- `phone` 兜底只使用 `otsInfo.phone_number`，兼容读取 `otsInfo.phone`。
- “已填写”标签必须校验 `follow_user.userid` 等于当前 `qwUserId` 后才生效。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录实现步骤、验证命令和结果。
- `checklists/requirements.md` 用于验证规格质量和实施完整性。
