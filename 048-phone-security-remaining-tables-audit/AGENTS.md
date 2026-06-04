# 048-phone-security-remaining-tables-audit

## 规格摘要

排查 drh 和 ju-chat 两个工程中所有含 `phone` 字段但未被 032/036/041 覆盖的 MySQL 表，按优先级分类并分析每张表的影响面（实体类、Mapper XML、Service、Controller、模块）。

## 已覆盖目标表（排除）

drh_h5_order, drh_live_user, drh_applet_user, drh_book_question_record, drh_external_book_question_record, drh_book_edit_address_compensation, drh_real_address_record

## 关键约束

- 本阶段只编写排查文档，不修改代码。
- P1 表有 phone 等值/批量查询，明文清空后查询直接失效。
- P2 表有 phone 写入，需同步生成安全字段。
- P3 表有 LIKE/NULL/展示，需业务确认。
- P4 表 Java 代码未使用 phone，低优先。

## 工程路径

- drh 工程：`C:\workspace\drh`
- ju-chat 工程：`C:\workspace\ju-chat`

## 输出文件

- `spec.md`：完整排查结果
- `tasks.md`：任务清单和执行记录
