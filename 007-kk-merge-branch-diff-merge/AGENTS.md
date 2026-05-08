# 规格执行说明

本目录记录 `007-kk-merge-branch-diff-merge` 合并任务，作用范围包含：

- 规格文档：`C:\workspace\ju-chat\specs\007-kk-merge-branch-diff-merge`
- 合并目标仓库：`C:\workspace\drh`

## 当前阶段

- Spec Kit 文档阶段已完成。
- 文件级合并阶段已完成。
- 合并目标为 `C:\workspace\drh` 当前 `kk-merge-2026` 工作区。
- 源分支为 `kk-merge`。

## 实现约束

- 禁止使用 `git merge` 完成合并。
- 禁止使用 `git rebase` 或 `git cherry-pick` 代替合并。
- 允许使用 `git diff`、`git show`、`git ls-tree` 读取分支文件差异。
- 允许通过文件复制、逐文件补丁和人工差异处理合并内容。
- 当前工作区已有未提交改动，不能直接重置、回滚或覆盖。
- 默认只吸收 `kk-merge` 的新增内容；`kk-merge` 中的删除性变更不主动应用。
- 如果需要处理同一文件的双边改动，必须先对比 `kk-merge-2026`、当前工作区和 `kk-merge` 三者内容。
- 当前最终差异只保留 `kk-merge` 删除但目标侧保留的 7 个文件。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准和假设。
- `tasks.md` 记录差异统计、执行拆分、验证命令和执行记录。
- `checklists/requirements.md` 用于验证规格质量和合并边界。
- 如果后续决定同步删除性变更，必须先更新 `spec.md` 和 `tasks.md`。
