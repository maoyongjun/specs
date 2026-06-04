# 任务清单：手机号安全改造——剩余表排查与影响分析

**输入**：来自 `spec.md` 的排查规格  
**前置条件**：`spec.md`  
**当前阶段**：排查文档阶段；不涉及代码改动。

## Phase 1：全量搜索与识别

- [x] T001 复查 032/036/041 规格文档，确认已覆盖的 7 张目标表清单。
- [x] T002 全量搜索 drh 工程中所有 Java 实体类包含 `private String phone` 的文件。
- [x] T003 全量搜索 ju-chat 工程中所有 Java 实体类包含 `private String phone` 的文件。
- [x] T004 全量搜索两个工程中所有 Mapper XML 引用 `phone` 列的文件，分类为等值、IN、LIKE、JOIN、NULL、SELECT、INSERT。
- [x] T005 排除已覆盖的 7 张表和 `@TableField(exist = false)` 的非持久化字段。
- [x] T006 识别非 MySQL 存储（MongoDB / OTS / ODPS）中含 phone 字段的集合。

**检查点**：T001-T006 必须覆盖 drh 和 ju-chat 两个工程的所有模块。

## Phase 2：优先级分类与影响分析

- [x] T007 对每张未覆盖表搜索 Java 代码中的 `.eq(::getPhone, ...)` / `.in(::getPhone, ...)` 查询，标记为 P1。
- [x] T008 对每张未覆盖表搜索 Java 代码中的 `setPhone(...)` 写入，标记为 P2。
- [x] T009 对 Mapper XML 中有 LIKE / NULL 判断 / SELECT 展示但无等值查询的表，标记为 P3。
- [x] T010 对 Java 代码中完全未使用 phone 字段的表，标记为 P4。
- [x] T011 对每张 P1/P2 表追踪完整调用链：Mapper → Service → Controller → HTTP 接口 → 模块。
- [x] T012 识别 ju-chat 工程中跨模块（ai-common / lms-common / broadcast-common）副本的实体类。
- [x] T013 按模块汇总影响矩阵。

**检查点**：T007-T013 必须为每张表提供实体路径、Mapper 路径、Service 方法、Controller 路径和模块归属。

## Phase 3：文档输出

- [x] T014 创建 `spec.md`，包含完整排查结果、优先级分类、影响面分析和模块矩阵。
- [x] T015 记录需要用户确认的设计选择（LIKE 查询、临时表、日志表、非 phone 命名的手机号字段等）。
- [x] T016 创建 `tasks.md`，记录排查任务和执行状态。

## Phase 4：待用户确认（后续执行）

- [ ] T017 用户确认 P3 表中 LIKE 查询的处理方案（精确查询 / 脱敏搜索 / 排除）。
- [ ] T018 用户确认 drh_temp_phone（非活跃）和 drh_sms_deal（日志型）是否纳入改造。
- [ ] T019 用户确认 drh_mall_order.reciver_phone 是否按 phone 同口径改造。
- [ ] T020 用户确认 P4 表是否需要数据库层面移除 phone 列。
- [ ] T021 根据用户确认结果，创建后续改造规格文档（可按优先级分批）。

## 执行记录

### D001 - 排查文档记录

- 执行内容：全量静态搜索 drh 和 ju-chat 两个工程，识别 43+ 张未覆盖的含 phone 字段 MySQL 表。
- 分类结果：P1（20 个实体，有等值/批量查询）、P2（12 个实体，有写入）、P3（4 个表，LIKE/NULL/展示）、P4（12 个表，未使用）。
- 影响面分析：覆盖 drh 的 7 个模块和 ju-chat 的 5 个模块。
- 识别 ju-chat 中 10 组跨模块副本实体。
- 本阶段未修改任何业务代码。
