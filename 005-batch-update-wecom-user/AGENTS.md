# 规格执行说明

本目录记录 `005-batch-update-wecom-user` 功能规格，作用范围仅限当前规格目录及其子目录。

## 当前阶段

- Spec Kit 文档阶段已完成。
- 本轮实现范围涉及 `kkhc-bizcenter/schedule` 与 `kkhc-bizcenter/scrm`。
- 当前目录应包含 `AGENTS.md`、`spec.md`、`tasks.md` 和 `checklists/requirements.md`。

## 实现约束

- 新增 schedule job 时，写法参考 `C:\workspace\ju-chat\kkhc\kkhc-bizcenter\schedule\src\main\java\com\kkhc\bizcenter\schedule\task\increase\IncreaseAbPlanStatusChangeJob.java`。
- 新增 SCRM 入口时，落点为 `C:\workspace\ju-chat\kkhc\kkhc-bizcenter\scrm\src\main\java\com\drh\kkhc\bizcenter\scrm\controller\complaint\ComplaintController.java`。
- job 必须异步调用 SCRM 的 `batchUpdateWecomUser` 接口，异步任务提交成功后即可返回成功。
- `batchUpdateWecomUser` 必须分页调用 `complaintFeign::configPage`，`pageSize=100`，从第 1 页开始处理全部分页。
- 批处理每个有效 `company` 时必须调用 `updateWecomUser`，相邻 company 调用间隔 2 分钟。
- 必须输出指定日志：`更新伪投诉连接地址,company={}` 与 `更新进度{}/{}`。
- 不新增数据库表、配置项或公共 DTO；复用现有 `ComplaintConfigSearchInput`、`ComplaintConfigOutput`、`WecomUserUpdateInput`。

## 文档维护

- `spec.md` 描述用户场景、功能需求、边界情况、成功标准和假设。
- `tasks.md` 记录实现任务拆分、验收任务和执行记录模板。
- `checklists/requirements.md` 用于进入实现前验证规格质量。
- 如果需求变化，先更新 `spec.md`，再同步 `tasks.md` 与检查清单。
