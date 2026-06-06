# 任务清单：图书订单 UnionId 兜底查询

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`AGENTS.md`、`spec.md`、`checklists/requirements.md`

## Phase 1：文档

- [x] T001 创建 `specs/056-book-order-unionid-fallback` 目录。
- [x] T002 创建 `AGENTS.md`、`spec.md`、`tasks.md` 和 `checklists/requirements.md`。
- [x] T003 固定接口兼容、OTS 查询、AI 查询顺序和验证命令。

## Phase 2：调用端与 OTS

- [x] T004 在 `coze_plugin/common/OtsUtil.java` 新增 `getUnionIdByExternalUserId`。
- [x] T005 在 `AppTask.java` 新增 `resolveBookUnionId`，优先查 `drh_emp_external_user`，再兜底 `drh_external_user_info`。
- [x] T006 `AppTask.java` 调用 `getBookOrderByPhone` 时追加非空 `unionId`。
- [x] T007 `AppTask.java` 仅在 `unionId` 非空时调用 `OtsUtil.searchRow`。

## Phase 3：AI 服务

- [x] T008 `AiController#getBookOrderByPhone` 增加可选 `unionId` 参数。
- [x] T009 `AiService#getBookOrderByPhone` 签名改为 `phone, unionId`。
- [x] T010 `AiServiceImpl#getBookOrderByPhone` 实现手机号优先、unionId 兜底。
- [x] T011 抽取订单 DTO 映射 helper，保持 `goodsId` 回填规则不变。

## Phase 4：验证

- [x] T012 文档结构检查。
- [x] T013 运行 `mvn -f C:\workspace\ju-chat\coze_plugin\pom.xml -pl common,external-info-save -am -DskipTests package`。
- [x] T014 运行 `mvn -f C:\workspace\ju-chat\kkhc\kkhc-idc\pom.xml -pl ai -am -DskipTests compile`。

## 执行记录

### D001 - 初始实现

- 执行内容：创建 Spec Kit 文档，完成调用端 OTS unionId 解析、AI 接口可选参数和 unionId 兜底查询。
- 验证方式：编译 `coze_plugin` 的 `common,external-info-save` 链路和 `kkhc-idc/ai` 模块。
- 自检结论：实现保持旧 `phone` 调用兼容，不新增数据库表、DTO 字段或配置项。
