# 规格执行说明

本目录记录手机号安全补充接口整改规格。当前阶段只补充 Spec Kit 文档，不修改业务代码、DDL、SQL 回填脚本或历史规格目录。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\073-phone-security-additional-interface-remediation`
- 目标项目：
  - `C:\workspace\ju-chat\kkhc`
  - `C:\workspace\drh`
- 相关模块：
  - `kkhc-idc app/lms/ai`
  - `kkhc-bizcenter lms`
  - `drh-kk-cms`
  - `drh-media-process`

## 当前目标

- 补充 `drh_leads_noqw_send_msg_task_detail` 相关接口的手机号安全整改规格。
- 补充 `drh_applet_player` 相关接口的查询、响应和导出脱敏整改规格。
- 补充 `drh_sms_deal` 日志型短信处理表及 `HandoverPlusMapper.xml` 的安全字段写入规格。

## 执行原则

- 先读代码，再定方案，后实现。
- 本规格不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、XML 字段映射和测试落点。
- 明文 `phone` 入参继续兼容，但库内查询和保存必须优先生成并使用 `phoneMd5` / `phone_md5`。
- 默认响应和导出中的 `phone` 字段保留字段名，但值应为掩码，不得返回明文。
- 外部短信发送仍可在受控内存中使用明文手机号；`drh_sms_deal` 落库必须同步保存 `phone_mask`、`phone_md5`、`phone_aes`。
- 不新增接口路径、HTTP 方法、MQ/Redis 契约或回填流程；不跨项目引用不属于当前模块的安全工具。

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：每个关键手机号从哪里来，安全字段是否在调用前赋值。
- 赋值时机：是否存在调用后才 `set`，但下游 XML / Wrapper 已经读取的字段。
- 占位对象：是否存在 `new XxxDto()`、空 Map、空 JSON 作为占位参数。
- 下游读取：Wrapper、Mapper XML、导出 DTO 和保存接口实际读取哪些字段。
- 旧逻辑保持：接口路径、分页、导出列名、筛选条件、短信发送和任务触发逻辑必须不变。
- 影响范围：是否影响数据库写入列、XML SELECT 列、导出内容或外部短信请求。
- 测试映射：每个关键行为至少对应一条单元测试、编译或静态验证记录。

## 重点代码位置

- `C:\workspace\ju-chat\kkhc\kkhc-idc\*\src\main\java\com\kkhc\idc\lms\service\works\impl\LeadsNoqwSendMsgTaskDetailServiceImpl.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\*\src\main\java\com\kkhc\idc\lms\controller\works\LeadsNoqwSendMsgTaskDetailConroller.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\*-common\src\main\java\com\kkhc\idc\lms\common\module\dao\works\LeadsNoqwSendMsgTaskDetailDO.java`
- `C:\workspace\drh\drh-kk-cms\src\main\resources\mapper\AppletPlayerMapper.xml`
- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\AppletPlayerServiceImpl.java`
- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\dto\output\AppletPlayOutput.java`
- `C:\workspace\drh\drh-media-process\src\main\resources\mapper\HandoverPlusMapper.xml`
- `C:\workspace\drh\drh-media-process\src\main\java\drh\media\process\dto\DealSmsDto.java`
- `C:\workspace\drh\drh-media-process\src\main\java\drh\media\process\service\impl\SendSmsTaskServiceImpl.java`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
