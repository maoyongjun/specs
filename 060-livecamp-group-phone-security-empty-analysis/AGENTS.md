# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\060-livecamp-group-phone-security-empty-analysis`
- 目标项目：`C:\workspace\drh\drh-kk-cms`
- 相关模块：`drh-kk-cms` 营期组接口、学员基础信息返回 DTO、手机号安全字段返回链路

## 当前目标

- 分析 `LiveCampGroupController` 相关返回值中 `phoneAes`、`phoneMask`、`phoneMd5` 为空的原因。
- 明确截图所对应的接口、DTO、service 分支和字段来源。
- 输出后续修复建议、风险门禁和验证口径，本阶段不直接修改业务代码。

## 执行原则

- 先读代码，再定结论；不能只根据截图推断。
- 关键字段必须追踪到来源、赋值时机和返回 DTO。
- 对手动 DTO 组装、空对象 fallback、调用后补字段等风险必须记录。
- 本分析不改变接口契约、数据库结构、Redis/MQ/FC/Feign/HTTP 调用。
- 若后续进入实现，优先做最小范围修复，并补充普通用户 V3 分支的单元测试或静态验证。

## 强制门禁

- 参数来源：确认 `GroupLiveBaseOutput.phone*` 字段来自 `drh_live_user` / `LiveUser`。
- 赋值时机：确认 `transRecordsToOutPuts` 在返回前只设置了 `phone`，未设置 `phoneMask`、`phoneMd5`、`phoneAes`。
- 占位对象：确认 `userMap.getOrDefault(..., new LiveUser())` 存在空对象 fallback，缺失用户记录时所有手机号字段都会为空。
- 下游读取：前端或调用方读取 `phone`、`phoneMask`、`phoneMd5`、`phoneAes`、`qyvxUserId`、`qyvxUserName`。
- 旧逻辑保持：保持 V3 现有分页、学员状态、特殊用户、长期班、多企微账号、群发记录、App 注册状态处理逻辑。
- 影响范围：后续修复不应新增数据库表、不改变查询入口、不改变分页条件、不引入额外远程调用。

## 重点代码位置

- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\controller\LiveCampGroupController.java`
  - `POST liveCampGroup/live/base/v3`
- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\LiveCampGroupServiceImpl.java`
  - `liveStudentBaseV3`
  - `transRecordsToOutPuts`
- `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\dto\output\livecamp\GroupLiveBaseOutput.java`
- `C:\workspace\drh\drh-common\src\main\java\com\drh\common\entity\LiveUser.java`
- `C:\workspace\drh\drh-kk-cms\src\main\resources\mapper\HandoverPlusDelMapper.xml`
- `C:\workspace\drh\drh-kk-cms\src\main\resources\mapper\SpecialUserCampMapper.xml`

## 文档维护

- `spec.md` 描述用户场景、原因分析、修复建议、成功标准和执行记录。
- `tasks.md` 记录代码事实确认、风险门禁和后续实现任务。
- `checklists/requirements.md` 用于验证规格质量和参数完整性。
- 如果后续用户要求直接修复代码，需要追加 D002 实现记录，并同步更新本目录所有相关文档。
