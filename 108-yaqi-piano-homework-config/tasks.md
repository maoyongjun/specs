# 任务清单：雅琪钢琴作业点评配置同步与绑定

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：用户已明确要求实现计划；数据库写入只允许测试库。  
**测试**：以数据库计数、接口返回和 `SopConfigSender` 兼容匹配验证为准。

## Phase 1：代码事实确认

- [x] T001 确认目标项目为 `C:\workspace\ju-chat\data-RC\juzi-service` 和 `C:\workspace\ju-chat\fc\sop-reply`。
- [x] T002 确认 admin 接口为 `/admin/homework-config/**`，素材 action 支持 `TEXT/VOICE/IMAGE/PDF/RANDOM_EMOJI/VIDEO_CHANNEL`。
- [x] T003 确认三表为 `drh_ai_config_homework_strategy`、`drh_ai_config_homework_action`、`drh_ai_config_homework_route`。
- [x] T004 确认测试接口 key 为 `drh20262026`，支持 query `key` 和 header `X-Config-Key`。
- [x] T005 确认 `SopConfigSender` 支持 route/action 的 `&&` 多条件和 `question` 条件。

**检查点**：事实确认完成，可进入执行。

## Phase 2：风险门禁

- [x] T006 `_Vxx.txt` 是视频号占位文件，不能上传为空文本。
- [x] T007 D1 question 分组必须加 `conditionKey=question`，否则会混发。
- [x] T008 原钢琴 route 只改匹配条件，不改 strategy/action。
- [x] T009 数据库写入仅限测试库；生产库只读导出。
- [x] T010 用户已确认采用全量覆盖测试三表和目录原值 question。
- [x] T011 验证映射包含三表计数、route 条件、接口配置和运行时匹配。

**检查点**：写库前仍需对每个 SQL 文件执行 `db_skill.py analyze`。

## Phase 3：实现

- [x] T012 创建执行脚本和 SQL 文件。
- [x] T013 导出正式三表快照和测试三表备份。
- [x] T014 分析并执行测试库三表同步 SQL。
- [x] T015 分析并执行李瑶 route 归属更新 SQL。
- [x] T016 调用测试接口创建雅琪 D1-D4 strategy/action/route。
- [x] T017 记录创建返回和生成新增 SQL/回滚 SQL。

## Phase 4：测试与验证

- [x] T018 验证测试三表同步后计数。
- [x] T019 验证原钢琴 route 全部包含 `speakerId=110`。
- [x] T020 验证雅琪 route 全部包含 `speakerId=113`。
- [x] T021 验证 D1 question 分组和 D2-D4 action 顺序。
- [x] T022 生成 `verification-summary.json`。

## 执行记录

### D001 - 文档记录

- 执行内容：创建并填写本规格文档。
- 验证方式：读取接口实现、实体类、SOP 匹配逻辑和素材目录。
- 自检结论：参数来源、调用顺序和旧逻辑保持口径已明确。

### D002 - 实现记录

- 执行内容：导出正式和测试三表快照；将测试三表全量同步为正式数据；更新测试环境原启用 `skuId=4` route 为 `currentDay&&homeworkDayRelation&&speakerId`，旧配置限定 `speakerId=110`；推送并部署已提交的 `VIDEO_CHANNEL`/speakerId 透传代码；通过测试接口创建雅琪 D1-D4 strategy/action/route。
- 创建结果：strategy id `87/88/89/90`，route id `125/126/127/128`，action id `359-386`。
- 验证结果：`HomeworkConfigServiceVideoChannelTest` 通过 `2` 项；`piano-speaker-summary.json` 显示旧钢琴 route `14` 条、雅琪 route `4` 条，旧 speaker 违规 `0`、雅琪 speaker 违规 `0`；`verification-summary.json` 显示 `speakerId=113` 命中雅琪 D1-D4，`speakerId=110` 命中原李瑶配置，其他 speaker 不命中。
- 输出文件：三表备份和快照在 `out/`，接口创建记录为 `created-records.json`，最终明细为 `out/piano-routes-after-yaqi-create.json`，雅琪回滚 SQL 为 `sql/rollback-yaqi-created-config.sql`。

### D003 - 正式同步准备记录

- 执行内容：响应“数据同步到正式环境”，导出正式当前三表快照，生成正式增量 SQL 和正式回滚 SQL。
- 生成结果：`sql/prod-sync-yaqi-piano-config.sql` 预计更新旧 `skuId=4` route `14` 条、新增雅琪 strategy `4` 条、action `28` 条、route `4` 条；`sql/rollback-prod-yaqi-piano-config.sql` 可删除雅琪配置并恢复旧 route 条件。
- 分析结果：同步 SQL 为 DML `41` 条语句；回滚 SQL 为 DML `18` 条语句，均已执行 `analyze`。
- 暂缓原因：正式 `homework-config.html` 未包含 `VIDEO_CHANNEL`，Jenkins/API/SSH 均无法由当前会话完成正式代码部署。为避免旧正式服务读取新 action 类型失败，未执行生产写库。

### D004 - 正式同步执行记录

- 执行内容：正式服务确认已支持 `VIDEO_CHANNEL` 后，重新导出正式三表快照并执行 `sql/prod-sync-yaqi-piano-config.sql`。
- 写库结果：`prod-sync-yaqi-piano-config-result.json` 显示 affected_rows `50`，雅琪启用 strategy/action/route 为 `4/28/4`。
- 验证结果：`prod-counts-after-final-sync.json` 显示正式最终 enabled/total 为 strategy `79/84`、action `219/344`、route `77/77`；`prod-piano-speaker-summary-after-final-sync.json` 显示旧钢琴 route `14` 条、雅琪 route `4` 条，speaker 违规均为 `0`。
- 接口验证：正式 `GET /admin/homework-config/config?skuId=4` 返回 200；`prod-verification-summary.json` 显示 `speakerId=110` 命中旧李瑶配置，`speakerId=113` 命中雅琪 D1-D4，其他 speaker 不命中。
