# 任务清单：external-info-select 返回 speaker_name

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标项目为 `external-info-select` 和 `idc-ai`。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和测试落点。
- [x] T003 确认 `camp_date_id`、`speakerId`、`speaker_name` 来源和赋值时机。
- [x] T004 确认本次新增 HTTP 接口，不影响 Redis key、MQ topic/tag、OTS 表或数据库结构。
- [x] T005 确认旧逻辑中必须保持不变的私域、物流、敏感词、转账金额、设备信息和课程规则逻辑。

**检查点**：已完成 T001-T005，可进入实现。

## Phase 2：风险门禁

- [x] T006 检查空对象和占位传参：本需求新增查询失败均返回 `null`，不向下游传空 DTO。
- [x] T007 检查调用后赋值风险：`speaker_name` 必须在 `DayEnum.createCozeJson` 后追加到最终 JSON。
- [x] T008 检查下游读取字段：`speaker_name` 在返回前现算现用。
- [x] T009 检查影响范围：新增 idc-ai HTTP 接口和插件侧本地缓存；不改 MQ、Redis key、数据库写入。
- [x] T010 业务语义变化：查不到时省略字段，按计划默认执行。
- [x] T011 测试映射：覆盖正常返回、缺失跳过、缓存命中、缓存过期和 idc-ai 编译。

**检查点**：T006-T011 有明确结论，可进入实现。

## Phase 3：实现

- [x] T012 在 `idc-ai` 暴露 `getSpeakerInfoBySpeakerId`。
- [x] T013 在 `external-info-select` 增加 campInfo 查询、speaker 查询和 6 小时本地缓存。
- [x] T014 在 `AppTask` legacy 流程最终返回中追加 `speaker_name`。
- [x] T015 同步更新执行记录。

## Phase 4：测试与验证

- [x] T016 新增或更新 `external-info-select` 单元测试。
- [x] T017 测试断言 speaker 查询参数和缓存调用次数。
- [x] T018 验证缺失数据和私域流程不回归。
- [x] T019 运行 `external-info-select` 测试和 `idc-ai` 编译。
- [x] T020 搜索确认没有字段名或接口路径残留错误。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `062-external-info-select-speaker-name` 规格目录并填写文档。
- 验证方式：模板复制、代码搜索、静态确认。
- 自检结论：满足实现前强制门禁。

### D002 - 实现记录

- 实现内容：idc-ai 新增 speaker 查询接口；external-info-select 新增 campInfo/speaker 查询、speaker name 6 小时本地缓存、legacy 最终返回追加 `speaker_name`。
- 测试命令：
  - `mvn -f C:\workspace\ju-chat\coze_plugin\external-info-select\pom.xml "-Dmaven.test.skip=false" test`
  - `mvn -f C:\workspace\ju-chat\kkhc\kkhc-idc\pom.xml -pl ai -am "-DskipTests" compile`
  - `mvn -f C:\workspace\ju-chat\kkhc\kkhc-idc\pom.xml -pl ai -am "-Dtest=AiServiceImplSpeakerInfoTest" "-DfailIfNoTests=false" test`
- 测试结果：插件 20 个测试通过；idc-ai 父工程定向编译通过；新增 idc-ai 测试 2 个通过。
- 自检结论：参数来源明确，`speaker_name` 在最终返回前现算现用，私域流程和旧字段保持不变；单模块 `ai\pom.xml` 编译会受远端旧版 `ai-common` 影响，父工程本地 reactor 编译已通过。

### D003 - 纠正记录模板

- 触发原因：`说明为什么需要纠正`
- 修正内容：`说明具体修正`
- 文档同步：`说明同步了哪些文件`
- 验证结果：`说明测试或静态验证`
