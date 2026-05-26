# 功能规格：手机号安全字段扩展

**功能目录**：`032-phone-security-columns`  
**创建日期**：`2026-05-26`  
**状态**：Draft  
**输入**：安全防护需求先完成数据库加字段：`drh_h5_order` 图书订单；`drh_live_user` 学员的 `app_phone` 和 `phone`；`drh_applet_user` 线索；`drh_book_question_record` 图书登记信息（留资）；`drh_external_book_question_record` 图书登记信息（非留资）；`drh_book_edit_address_compensation` 图书登记补偿信息。每个手机号需要增加带 `*` 的手机号、MD5 手机号、AES 加密字段，并在 `C:\workspace\ju-chat\specs` 增加文档。

## 背景

- 当前问题：多个业务表仍以原始手机号字段作为主要查询和展示来源，后续安全防护需要拆分展示、查询、单条解密能力。
- 当前行为：目标表保留明文手机号字段，列表展示和查询链路仍可能直接依赖原字段。
- 目标行为：每个手机号字段旁路增加掩码、MD5、AES 三个字段，为后续代码改造和历史回填提供结构基础。
- 非目标：本阶段不执行数据库 DDL，不回填历史数据，不改造接口、实体、Mapper、查询逻辑或展示逻辑。

## 用户场景与测试

### 用户故事 1 - 列表页可直接使用掩码手机号（优先级：P1）

运营或后台列表需要展示手机号时，应读取 `*_mask` 字段，避免批量暴露原始手机号。

**独立测试**：执行 DDL 后检查目标表均存在对应 `*_mask` 字段。

**验收场景**：

1. **Given** 目标表中原字段为 `phone`，**When** 完成 DDL，**Then** 表中存在 `phone_mask`。
2. **Given** `drh_live_user` 同时存在 `phone` 和 `app_phone`，**When** 完成 DDL，**Then** 表中同时存在 `phone_mask` 和 `app_phone_mask`。

### 用户故事 2 - 手机号等值查询使用 MD5（优先级：P1）

需要按手机号查记录时，应先按归一化手机号计算 MD5，再使用 `*_md5` 字段等值查询。

**独立测试**：执行 DDL 后检查每个 `*_md5` 字段都有普通索引。

**验收场景**：

1. **Given** 目标表中原字段为 `phone`，**When** 完成 DDL，**Then** 表中存在 `phone_md5` 和对应索引。
2. **Given** `drh_live_user.app_phone` 需要查询，**When** 完成 DDL，**Then** 表中存在 `app_phone_md5` 和对应索引。

### 用户故事 3 - 单条结果可解密还原手机号（优先级：P1）

在权限允许且只处理单条结果时，系统可读取 `*_aes` 字段并通过 AES 解密得到原始手机号。

**独立测试**：执行 DDL 后检查目标表均存在对应 `*_aes` 字段。

**验收场景**：

1. **Given** 单条详情页需要展示完整手机号，**When** 权限校验通过，**Then** 后续代码可读取 `phone_aes` 解密。
2. **Given** `drh_live_user.app_phone` 需要单条解密，**When** 权限校验通过，**Then** 后续代码可读取 `app_phone_aes` 解密。

## 数据模型与字段

### 字段命名

- 原字段 `phone` 增加：`phone_mask`、`phone_md5`、`phone_aes`。
- 原字段 `app_phone` 增加：`app_phone_mask`、`app_phone_md5`、`app_phone_aes`。

### 字段类型

- `*_mask`：`VARCHAR(32)`，保存如 `138****0000` 的展示值。
- `*_md5`：`CHAR(32)`，保存手机号归一化后的 MD5 十六进制摘要，用于等值查询。
- `*_aes`：`VARCHAR(255)`，保存 AES 密文，用于单条结果解密。

### DDL

完整脚本见 [add-phone-security-columns.sql](add-phone-security-columns.sql)。

```sql
ALTER TABLE drh_h5_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_h5_order_phone_md5 (phone_md5);

ALTER TABLE drh_live_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD COLUMN app_phone_mask VARCHAR(32) DEFAULT NULL COMMENT 'APP手机号掩码展示值',
  ADD COLUMN app_phone_md5 CHAR(32) DEFAULT NULL COMMENT 'APP手机号MD5摘要，用于等值查询',
  ADD COLUMN app_phone_aes VARCHAR(255) DEFAULT NULL COMMENT 'APP手机号AES密文，用于单条结果解密',
  ADD INDEX idx_live_user_phone_md5 (phone_md5),
  ADD INDEX idx_live_user_app_phone_md5 (app_phone_md5);
```

其余 `phone` 表按同一口径增加三字段和 `phone_md5` 索引。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `phone`：来源于各目标表已有字段；本阶段只增加旁路字段，不改写原字段赋值。
  - `app_phone`：来源于 `drh_live_user.app_phone`；本阶段只增加旁路字段，不改写原字段赋值。
  - `*_mask`：后续写入或回填时由原始手机号在当前层现算。
  - `*_md5`：后续写入或回填时由归一化手机号在当前层现算。
  - `*_aes`：后续写入或回填时由归一化手机号和统一 AES 密钥在当前层现算。
- 下游读取字段清单：
  - 列表展示后续读取 `*_mask`。
  - 手机号查询后续读取 `*_md5`。
  - 单条详情后续读取 `*_aes`。
- 空对象 / 占位对象风险：
  - 本阶段无 DTO、Map、JSON 传参；后续代码改造不得把空安全字段当作有效加密结果。
- 调用顺序风险：
  - 本阶段无调用链变更；后续写入时必须先拿到原始手机号，再同步计算三个安全字段后入库。
- 旧逻辑保持：
  - 保留所有原始手机号字段，旧查询、旧展示、旧写入在本阶段不变。
  - 不新增外部调用、MQ、Redis、配置项或接口契约。
- 需要用户确认的设计选择：
  - AES 密钥来源、加密模式、是否带 IV、密文编码方式需要在后续代码实现前确认。
  - 历史数据回填批次、回填窗口和是否清空明文字段需要单独确认。

## 边界情况

- 原手机号为空时，三个安全字段保持 `NULL`。
- 原手机号格式异常时，后续回填应记录失败并跳过，不写入错误摘要。
- DDL 重复执行会因字段或索引已存在而失败，执行前必须做元数据检查。
- 大表执行新增索引可能产生锁表或耗时风险，生产环境需评估在线 DDL 能力和执行窗口。

## 需求

### 功能需求

- **FR-001**：系统 MUST 为 `drh_h5_order.phone` 增加 `phone_mask`、`phone_md5`、`phone_aes`。
- **FR-002**：系统 MUST 为 `drh_live_user.phone` 增加 `phone_mask`、`phone_md5`、`phone_aes`。
- **FR-003**：系统 MUST 为 `drh_live_user.app_phone` 增加 `app_phone_mask`、`app_phone_md5`、`app_phone_aes`。
- **FR-004**：系统 MUST 为 `drh_applet_user.phone` 增加 `phone_mask`、`phone_md5`、`phone_aes`。
- **FR-005**：系统 MUST 为 `drh_book_question_record.phone` 增加 `phone_mask`、`phone_md5`、`phone_aes`。
- **FR-006**：系统 MUST 为 `drh_external_book_question_record.phone` 增加 `phone_mask`、`phone_md5`、`phone_aes`。
- **FR-007**：系统 MUST 为 `drh_book_edit_address_compensation.phone` 增加 `phone_mask`、`phone_md5`、`phone_aes`。
- **FR-008**：系统 MUST 为每个 `*_md5` 字段建立普通索引，支撑等值查询。
- **FR-009**：系统 MUST NOT 在本阶段删除、改名或清空原始手机号字段。
- **FR-010**：本阶段 MUST NOT 执行数据库变更，只提供可审核 DDL。

## 成功标准

- **SC-001**：规格目录中存在完整 DDL 文件，覆盖 6 张表和 7 个手机号字段。
- **SC-002**：每个手机号字段均有掩码、MD5、AES 三个安全字段。
- **SC-003**：每个 MD5 字段均有对应索引。
- **SC-004**：规格明确本阶段不执行 DDL、不回填数据、不改业务代码。

## 假设

- 当前数据库使用 MySQL 兼容语法。
- 手机号 MD5 采用归一化后 32 位十六进制摘要，具体大小写在后续实现统一。
- AES 密文长度 `VARCHAR(255)` 足以容纳后续选型的密文编码。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已按当前代码实体确认目标表的原始手机号字段。
- 已完成历史问题防漏分析和强制门禁检查。

### D002 - DDL 脚本记录

- 已新增 `add-phone-security-columns.sql`。
- 脚本覆盖：`drh_h5_order`、`drh_live_user`、`drh_applet_user`、`drh_book_question_record`、`drh_external_book_question_record`、`drh_book_edit_address_compensation`。
- 本次未连接数据库、未执行 DDL、未回填历史数据。

### D003 - 纠正记录模板

- 触发原因：待后续填写，例如用户补充、审核意见或执行反馈。
- 修正内容：待后续填写，需写清楚旧口径和新口径。
- 文档同步：待后续填写，需说明 `spec.md`、`tasks.md`、`AGENTS.md`、checklist 是否已同步。
- 验证结果：待后续填写，需记录脚本复核或执行结果。
