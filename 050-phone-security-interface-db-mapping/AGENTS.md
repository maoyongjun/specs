# 规格执行说明

本目录为手机号安全改造接口影响与数据库表全量映射 Spec Kit。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\050-phone-security-interface-db-mapping`
- 目标项目：`C:\workspace\drh`（drh 主业务微服务）、`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`（AI 模块）
- 相关模块：drh-pay、drh-endpoint、drh-kk-cms、drh-callback、drh-media-process

## 当前目标

- 全量梳理手机号加密改动影响的接口与对应数据库表的完整映射关系。
- 为测试团队提供按模块 × 接口 × 数据库表维度执行全量验证的依据。
- 整合前置规格（032/036/041/048）的接口影响信息为统一视图。

## 前置规格依赖

| 规格编号 | 名称 | 覆盖内容 |
|---------|------|---------|
| 032 | phone-security-columns | 7 张核心表数据库字段添加 |
| 036 | phone-security-save-query | 保存/查询/展示链路代码改造 + 历史回填 |
| 041 | mybatisplus-xml-phone-md5-query | XML Mapper phone_md5 查询兼容 |
| 048 | phone-security-query-return-save-mask-validate | 查询返回安全字段 + 掩码入参校验 |
| 048 | phone-security-remaining-tables-audit | 剩余 19 张 P1 表排查与改造 |

## 执行原则

- 本文档以接口为主轴，数据库表为辅，前端页面为补充，三者交叉验证。
- 每个接口的改动类型、数据库表读写方向、前端调用页面必须完整标注。
- 数据库表 × 接口读写矩阵必须覆盖所有已改造表。
- 前端页面映射必须覆盖所有已知投放页面、CMS 后台页面、小程序/APP 页面和中转页面。
- 本目录不直接执行数据库 DDL 或历史回填；涉及代码整改时必须同步追加 Dxxx 执行记录。

## 强制门禁

验证前必须完成以下检查：

- 数据库环境：测试库已执行 032、048 和 D003 补充 DDL，28 张表均具备对应安全字段和 MD5 索引。
- 历史回填：测试库已执行历史数据回填，目标表记录的安全字段有值。
- 前置规格代码：032/036/041/048 的代码改造已合入测试分支。
- 测试数据：为每张目标表准备含安全字段和 phone 为空的测试记录。

## 重点代码位置

- drh-pay 入口：`H5OrderServiceImpl`、`H5OrderController`
- drh-endpoint 入口：`H5OrderServiceImpl`、`LiveAuthServiceImpl`、`AppletUserServiceImpl`
- drh-kk-cms 入口：`BookQuestionRecordServiceImpl`、`ExternalBookQuestionRecordServiceImpl`、`CollectOrderServiceImp`、`LiveCampGroupServiceImpl`
- drh-callback 入口：`H5OrderServiceImpl`、各回调 Controller
- drh-media-process 入口：`HandoverPlusServiceImpl`、`SmsTriggerBaiWuUserCallBackHandler`
- 安全工具类：`DataSecurityInvoke`（drh-common/src/main/java/com/drh/common/fc/datasec/）

## 文档维护

- `spec.md` 描述接口影响、数据库表映射、前端页面映射和读写矩阵。
- `tasks.md` 记录分模块验证任务清单和执行记录。
- `AGENTS.md` 描述前置依赖、执行原则和强制门禁。
- `checklists/requirements.md` 验证映射文档完整性和测试就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
