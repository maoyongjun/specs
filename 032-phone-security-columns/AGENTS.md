# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\032-phone-security-columns`
- 目标项目：`C:\workspace\ju-chat\kkhc\kkhc-idc`
- 相关模块：`ai-common`、`lms-common`、`ai`、`app`、`lms`

## 当前目标

- 为用户指定的手机号落库表补充安全冗余字段。
- 每个手机号原字段增加三类字段：掩码展示值、MD5 查询值、AES 密文值。
- 在规格目录中沉淀 DDL、字段口径、验证清单和后续实现约束。

## 表与字段口径

- `drh_h5_order`：原手机号字段为 `phone`。
- `drh_live_user`：原手机号字段为 `phone`、`app_phone`。
- `drh_applet_user`：原手机号字段为 `phone`。
- `drh_book_question_record`：原手机号字段为 `phone`。
- `drh_external_book_question_record`：原手机号字段为 `phone`。
- `drh_book_edit_address_compensation`：原手机号字段为 `phone`。

## 执行原则

- 本阶段只交付数据库字段 DDL 和规格文档，不执行线上数据库变更。
- 不删除或改名原始手机号字段，避免影响旧代码读写。
- `*_mask` 只用于列表和日志展示，不参与查询匹配。
- `*_md5` 只用于手机号等值查询，并建立普通索引。
- `*_aes` 只用于单条结果场景解密还原，不作为批量查询条件。
- 后续业务代码写入时，必须在同一事务内同步写入原字段和三个安全字段。

## 强制门禁

- 执行 DDL 前必须确认目标环境不存在同名字段和同名索引。
- 执行 DDL 前必须确认表量级和 MySQL 版本，必要时采用在线 DDL 或低峰执行。
- 回填历史数据时必须先明确 AES 密钥来源、MD5 归一化口径和手机号清洗规则。
- 后续查询改造不得直接用明文手机号做批量检索。
- 后续展示改造不得在列表页返回明文手机号。

## 重点代码位置

- `kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\order\H5OrderDO.java`
- `kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\base\LiveUserDO.java`
- `kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\leads\AppletUserDo.java`
- `kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\book\BookQuestionRecordDO.java`
- `kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\book\ExternalBookQuestionRecordDO.java`
- `kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\book\BookEditAddressCompensationDO.java`

## 文档维护

- `spec.md` 描述字段口径、DDL、验收和边界。
- `tasks.md` 记录事实确认、风险门禁和静态验证。
- `checklists/requirements.md` 用于实施前检查。
- `add-phone-security-columns.sql` 是本阶段可审核 DDL，不代表已执行。
