# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\096-common-warn-sender-fx002-private-domain`
- 目标项目：
  - `C:\workspace\ju-chat\coze_plugin\common_warn_sender`
  - `C:\workspace\ju-chat\kkhc\kkhc-idc\ai`
  - `C:\workspace\ju-chat\kkhc\kkhc-idc\ai-common`
- 相关模块：Coze 通用预警插件、企微标签查询与 `qwTag/markAsync` 异步打标链路。

## 当前目标

- `common_warn_sender` 支持私域 `external_key=private-domain:agentId:externalUserId:userId:env`。
- `templateVariable.unionId/userName` 有值时优先用于模板渲染；缺失时通过 `/ai/getEmpExternalUserDO` 补齐。
- `sendTemplateList` 包含 `FX_002` 时，按 `source + name='请勿打扰' + is_del=0` 查询 `drh_qw_tag.tagId`，再调用 `POST /qwTag/markAsync` 给外部联系人打“请勿打扰”标签。
- `FX_002` 发送消息时，飞书接收人固定为 `ed27a7bb`，不使用销售 `fBookId`。
- 追加变更：私域插件聚合的 `/ai/userPortrait` 返回结构中，`teacherInfo` 和 `courseData` 改为 list，并在体验课/正价课条目中返回 `skuName`；`courseData` 按营期返回，重复 `campId + category/skuName` 去重。

## 执行原则

- 不硬编码 `tagId`，不跨主体 fallback。
- `FX_002` 打标是附加副作用，失败只记录日志和 detail，不阻断原预警发送。
- 私域 key 第 4 段不是企微成员 `user_id`；打标 `user_id` 必须来自 `empId -> getEmpInfoByEmpId -> qyvxUserId`。
- debug 模式不产生真实打标副作用。
- `FX_002` 的飞书接收人固定为 `ed27a7bb`；其他策略继续使用销售 `fBookId`。
- 不改变 legacy 4 段 `external_key` 的发送逻辑，不改变 `appendJumpLink=false` 既有行为。

## 强制门禁

- 关键参数必须在调用 `markAsync` 前确定：`external_user_id/user_id/union_id/source/add_tag_list`。
- `unionId` 为空时不得用 `unKnown` 或占位值提交 FX_002 打标。
- `tagId` 为空时不得调用 `markAsync`。
- `remove_tag_list` 为空时不传。
- 测试必须断言下游请求参数，不只断言返回状态。

## 重点代码位置

- `coze_plugin\common_warn_sender\src\main\java\com\drh\commonwarnsender\service\AppTask.java`
- `coze_plugin\common_warn_sender\src\main\java\com\drh\commonwarnsender\util\CenterUtil.java`
- `coze_plugin\external-info-select\src\main\java\com\drh\select\service\AppTask.java`
- `kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\ai\controller\QwTagController.java`
- `kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\ai\service\impl\QwTagQueryServiceImpl.java`
- `kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\impl\AiUserPortraitServiceImpl.java`
- `kkhc\kkhc-idc\ai\src\main\resources\mapper\ai\AiUserPortraitMapper.xml`
- `kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\input\ai\QwTagNameQueryInput.java`
- `kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\output\ai\QwTagOutput.java`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
