# 任务清单：学习之星奖状 OOM 修复

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 确认异常发生点：`LearningStarCertificateServiceImpl.processLearningStarCertificateSend` 第 157 行候选营期异常日志。
- [x] T002 确认当前 `selectCandidateCamps` 调用 `selectLearningStarAiCampCandidates`，SQL 只按 `ai_status=1` 和 `category=4` 过滤。
- [x] T003 确认当前 `selectStudents` 一次性按 `chatId/createTime` 查询整营期学员列表。
- [x] T004 确认当前 `processCampStudents` 一次性保留 `preChecked`、`futures` 和 `renderResults`。
- [x] T005 确认并发路径在渲染前构造 `LearningStarDelaySendInput`，存在 `certificateUrl=null` 下传风险。
- [x] T006 确认渲染器每次读取模板、生成 Base64 背景 SVG，并在生产路径再次 `ImageIO.read` 校验 PNG。

## Phase 2：风险门禁

- [x] T007 检查空对象 / 占位对象风险：原并发路径存在空图片 URL 入参风险，本次必须修复。
- [x] T008 检查调用后赋值风险：`certificateUrl` 不得只写到 `StudentRenderResult`，必须写入下游发送入参。
- [x] T009 检查外部契约风险：不修改对外 API、MQ tag/message type、Redis key 前缀和消费者契约。
- [x] T010 检查业务语义风险：候选 SQL 只做 D3/D4 日期窗口预筛，Java 层仍保留精确天数判断。
- [x] T011 建立测试映射：分批处理、URL 回填、渲染异常隔离、MQ 成功通知口径、连续渲染。

## Phase 3：实现

- [x] T012 在 `LearningStarCertificateConfig` 增加 `studentBatchSize` 和 `renderBatchSize` 默认值。
- [x] T013 调整候选营期 SQL，增加 `class_time` 日期窗口过滤。
- [x] T014 将 `processCampCandidate` 改为按批查询学员，逐批处理并释放批次锁。
- [x] T015 将渲染阶段改为按 `renderBatchSize` 小批次提交 future。
- [x] T016 渲染成功后再构造 `LearningStarDelaySendInput` 和消息列表。
- [x] T017 投递 MQ 前校验图片 URL 完整性。
- [x] T018 WX_004 通知改为按成功投递结果统计。
- [x] T019 渲染器缓存模板 data URI 和尺寸，去除生产路径重复 PNG 解码校验。

## Phase 4：测试与验证

- [x] T020 新增大营期分批处理测试。
- [x] T021 新增并发路径 URL 回填测试。
- [x] T022 新增渲染失败隔离测试。
- [x] T023 新增 MQ 投递失败时 WX_004 统计口径测试。
- [x] T024 新增渲染器连续渲染测试。
- [ ] T025 运行目标 Maven 测试并记录结果。
- [ ] T026 静态搜索确认不存在 `certificateUrl=null` 下传到 MQ。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `077-learning-star-certificate-oom-fix` Spec Kit 文档。
- 验证方式：对照 `_template` 补齐 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 自检结论：需求、边界、风险门禁和测试映射已覆盖。

### D002 - 实现记录

- 实现内容：候选营期窗口预筛、学员 keyset 分批、渲染小批次、图片 URL 回填、WX_004 成功投递口径、渲染器模板缓存。
- 测试命令：`mvn -pl ai -am "-Dtest=LearningStarCertificateServiceImplTest,LearningStarCertificateRendererTest" test`。
- 测试结果：待回填。
- 自检结论：待回填。
