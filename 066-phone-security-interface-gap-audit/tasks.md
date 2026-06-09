# 任务清单：手机号安全接口补遗与漏改审计

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：本规格阶段只做文档和静态验证；后续代码修复必须补充编译、单测或接口验证记录。

## Phase 1：代码事实确认

- [x] T001 复查 `050/051/060/063/065`，确认已有 DDL、已覆盖接口和特殊返回口径。
- [x] T002 搜索 `kkhc-idc app/lms/ai` Controller、Facade、Service，确认补充接口入口。
- [x] T003 搜索 `kkhc-bizcenter/app`，确认 `/leads/select` 通过 Feign 触发 idc 线索查询。
- [x] T004 搜索 `drh-kk-cms` Controller、Service、Mapper，确认 `frontWork`、`front/myClass`、`collect/order`、`mall`、`messageTrigger/log` 入口。
- [x] T005 搜索 `drh-media-process` 外呼和短信服务，确认其作为非 HTTP 风险记录。

## Phase 2：风险门禁

- [x] T006 确认本规格不新增 DDL、不改业务代码、不覆盖历史规格目录。
- [x] T007 将 HTTP/Feign/回调入口和纯 service/任务风险分开记录。
- [x] T008 将已覆盖接口和确认漏改接口分开记录。
- [x] T009 对模糊手机号搜索标记为需产品确认，不直接规划 MD5 等价替换。
- [x] T010 对每个确认漏改点记录代码证据、影响表和修复建议。

## Phase 3：文档创建

- [x] T011 创建 `066-phone-security-interface-gap-audit/AGENTS.md`。
- [x] T012 创建 `066-phone-security-interface-gap-audit/spec.md`。
- [x] T013 创建 `066-phone-security-interface-gap-audit/tasks.md`。
- [x] T014 创建 `066-phone-security-interface-gap-audit/checklists/requirements.md`。
- [x] T015 在 `spec.md` 记录 D001 文档执行记录。

## Phase 4：后续修复建议

- [ ] T016 修复 `kkhc-idc app/lms /order/getOrderPage`，对齐 ai 版本的 `phoneMaskForDisplay` 展示口径。
- [ ] T017 修复 `kkhc-idc app/lms/ai /order/reissue/pageDetailQuery`，将明文 `phone` 查询改为 `phoneMd5` 查询。
- [ ] T018 修复 `kkhc-idc app/lms /applet/user/listByEntity|get/one/by/condition` 和 `kkhc-bizcenter/app /leads/select`，避免 `setEntity` 带明文 `phone` 查询。
- [ ] T019 修复 `kkhc-idc app/lms /wechat/*` 保存和统计链路，保存生成安全字段，查询统计走 `phoneMd5`。
- [ ] T020 修复 `kkhc-idc app/lms/ai /leads-noqw-send-msg-task-detail/*`，列表和导出走 `phoneMd5` 并返回掩码。
- [ ] T021 修复 `kkhc-idc app/lms/ai /userServiceRecord/getRecords`，创建链路确认安全字段生成。
- [ ] T022 修复 `kkhc-idc lms mcn/influencer/add|edit`，重复校验和保存使用安全字段。
- [ ] T023 确认 drh `frontWork`、`front/myClass`、`mall/list` 模糊手机号搜索口径，再按确认结果实施。
- [ ] T024 修复 `drh-kk-cms collect/order/import/address/detail`，对齐 `063` 的 `phoneMd5` 查询。
- [ ] T025 修复 `drh-kk-cms messageTrigger/log/query`，手机号集合归一为 `phoneMd5` 集合并使用 `in` 查询。
- [ ] T026 评估 `drh-media-process` 外呼、短信、回调任务的明文手机号关联风险。

## Phase 5：后续测试与验证

- [ ] T027 静态搜索确认确认漏改项不再出现旧的 `::getPhone`、`phone LIKE`、`reciver_phone LIKE` 查询。
- [ ] T028 对每个精确手机号查询接口用明文手机号请求，验证 SQL 条件落到 `phone_md5`。
- [ ] T029 验证响应中 `phone` 不返回明文，且 `phoneMask/phoneMd5/phoneAes` 按接口契约返回。
- [ ] T030 验证 `065` 特例：app `/app/collect/order/pageQuery` 的 `phone` 继续返回 `phoneAes`。
- [ ] T031 分别运行 kkhc app/lms/ai 相关模块编译或单测。
- [ ] T032 分别运行 drh-kk-cms、drh-media-process 相关模块编译或单测。
- [ ] T033 保留 `C:\workspace\drh` 现有未提交测试改动，不回滚用户改动。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `066-phone-security-interface-gap-audit` 规格目录，补充接口矩阵、漏改清单、非 HTTP 风险和后续修复任务。
- 验证方式：读取模板和相邻手机号安全规格；用 `rg` 静态确认 Controller/Feign/Service/Mapper 入口和代码证据。
- 自检结论：文档满足本轮“只创建 spec-kit 文档”的范围；业务代码和已有 DDL 未修改。

### D002 - 后续实现记录模板

- 实现内容：`逐项记录修复的接口、类和行为变化。`
- 测试命令：`记录 Maven/JUnit/静态搜索命令。`
- 测试结果：`记录通过、失败和环境阻塞。`
- 自检结论：`确认 phoneMd5 查询、掩码返回、旧逻辑保持和剩余风险。`

### D003 - 纠正记录模板

- 触发原因：`说明为什么需要纠正。`
- 修正内容：`说明具体修正。`
- 文档同步：`说明同步了哪些文件。`
- 验证结果：`说明测试或静态验证。`
