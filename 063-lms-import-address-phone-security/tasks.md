# 任务清单：lms 批量导入地址手机号安全补充

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标为 `kkhc-idc/lms` 导入地址链路。
- [x] T002 确认真实入口、Feign、Service、实体、Mapper 和回填目标。
- [x] T003 确认手机号来源、赋值时机和下游读取字段。
- [x] T004 确认本次只新增 DDL，不改 MQ、Redis key 或 HTTP 路径。
- [x] T005 确认旧导入状态、ERP 上传、Redis 锁、异步阈值和重试逻辑保持不变。

## Phase 2：风险门禁

- [x] T006 检查空对象风险：真实地址为空时停止更新；手机号为空/非法时不生成安全字段。
- [x] T007 检查调用顺序：保存前生成安全字段，查询前计算 MD5，返回前掩码。
- [x] T008 检查查询风险：手机号非空但 MD5 失败时返回空页，不返回全量。
- [x] T009 检查日志风险：导入确认日志不打印整批明细对象。
- [x] T010 检查接口契约：HTTP 路径和入参不变，Output 只新增字段。
- [x] T011 建立测试映射：MD5 直通、converter 掩码、静态搜索、编译。

## Phase 3：实现

- [x] T012 新增 `drh_import_address_record_detail` DDL。
- [x] T013 补齐 `ImportAddressRecordDetail`、`RealGoodsAddressRecordDO`、`LiveUserDO` 安全字段。
- [x] T014 修改导入明细保存、明细查询、失败列表返回。
- [x] T015 修改真实地址保存、学员回填和 ERP 手机号兜底。
- [x] T016 修改历史回填目标。
- [x] T017 同步文档执行记录。

## Phase 4：测试与验证

- [x] T018 新增 `DataSecurityInvokeTest`，覆盖 MD5 直通。
- [x] T019 新增 `ImportAddressRecordConverterTest`，覆盖 `phone` 掩码输出。
- [ ] T020 运行目标测试和编译。
- [ ] T021 搜索确认无明文查询和敏感日志残留。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `063-lms-import-address-phone-security` 规格目录和 DDL。
- 验证方式：代码搜索、历史规格比对、静态确认。
- 自检结论：目标链路、参数来源、旧逻辑边界和测试映射已明确。

### D002 - 实现记录

- 实现内容：已完成代码修改和测试文件新增。
- 测试命令：
  - `mvn -f C:\workspace\ju-chat\kkhc\kkhc-idc\pom.xml -pl base-common,lms-common,lms -am -DskipTests compile`
  - `mvn -f C:\workspace\ju-chat\kkhc\kkhc-idc\pom.xml -pl base-common,lms -am -Dtest=DataSecurityInvokeTest,ImportAddressRecordConverterTest test`
- 测试结果：待执行后补充。
- 自检结论：待执行后补充。

### D003 - 纠正记录模板

- 触发原因：`说明为什么需要纠正`
- 修正内容：`说明具体修正`
- 文档同步：`说明同步了哪些文件`
- 验证结果：`说明测试或静态验证`
