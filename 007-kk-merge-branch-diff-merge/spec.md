# 功能规格：kk-merge 内容手工合并到 kk-merge-2026

**功能目录**: `007-kk-merge-branch-diff-merge`  
**创建日期**: 2026-05-08  
**状态**: Implemented  
**输入**: 用户要求在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档，对比 `C:\workspace\drh` 项目的 `kk-merge-2026` 与 `kk-merge` 分支，并将 `kk-merge` 中新增的内容合并到 `kk-merge-2026`，禁止使用 `git merge`，必须通过文件对比方式合并。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 明确两个分支的差异范围（优先级：P1）

维护者需要知道 `kk-merge` 相对 `kk-merge-2026` 新增、修改、删除了哪些文件，并能基于这份差异清单进行手工合并。

**独立测试**：在 `C:\workspace\drh` 执行 `git diff --name-status kk-merge-2026..kk-merge`，验证输出覆盖新增、修改、删除三类文件。

**验收场景**：

1. **Given** 当前仓库存在 `kk-merge-2026` 与 `kk-merge` 分支，**When** 执行分支差异统计，**Then** 能得到文件级差异清单。
2. **Given** 差异中包含新增文件，**When** 进入合并任务，**Then** 新增文件必须复制或补丁应用到 `kk-merge-2026` 工作区。
3. **Given** 差异中包含删除文件，**When** 用户要求合并“新增内容”，**Then** 默认不删除 `kk-merge-2026` 中已有文件，除非后续明确要求同步删除。

### 用户故事 2 - 通过文件对比执行合并（优先级：P1）

维护者需要在不执行 `git merge` 的前提下，把 `kk-merge` 的新增内容带到当前 `kk-merge-2026` 工作区，并保留目标分支已有改动。

**独立测试**：执行合并后，用 `git diff kk-merge -- <path>` 检查关键文件，确认目标工作区已包含 `kk-merge` 的新增类、配置、mapper、SQL/CSV 及必要代码块。

**验收场景**：

1. **Given** 当前分支为 `kk-merge-2026`，**When** 执行合并，**Then** 不创建 merge commit，不运行 `git merge`。
2. **Given** 目标工作区已有未提交改动，**When** 合并同一文件，**Then** 必须逐文件对比并保留目标分支已有内容。
3. **Given** 源分支包含二进制新增文件，**When** 目标缺失该文件，**Then** 通过源分支文件内容补齐。

### 用户故事 3 - 留下可审计执行记录（优先级：P2）

维护者需要在 Spec Kit 文档中记录比较结果、执行策略、任务状态和验证结果，便于后续复查或继续处理。

**独立测试**：打开 `tasks.md`，验证包含分支版本、差异统计、合并原则、执行记录和验证命令。

**验收场景**：

1. **Given** 合并任务开始，**When** 创建规格目录，**Then** 目录包含 `AGENTS.md`、`spec.md`、`tasks.md` 和 `checklists/requirements.md`。
2. **Given** 合并任务完成或遇到阻塞，**When** 更新任务清单，**Then** 文档能说明已完成项、剩余差异和风险。

## 边界情况

- `C:\workspace\drh` 当前位于 `kk-merge-2026` 分支，但工作区已有大量 staged、unstaged 和 untracked 改动。
- 初始对比提交点为：`kk-merge-2026` = `ef15b4f8c357e1793dc950cfc129e245ba5b8cab`，`kk-merge` = `0fb398f4d5a5e0c0007a02b253eb98a7f00ed629`。
- 合并后 `kk-merge-2026` 当前提交为 `1e6686c62df642c8b10e9aa15d1def5329c18751`，父提交为 `ef15b4f8c357e1793dc950cfc129e245ba5b8cab`，不是 merge commit。
- 提交层面对比 `kk-merge-2026..kk-merge` 共有 207 个差异文件：77 个新增、123 个修改、7 个删除。
- 当前工作区已完成新增内容合并；与 `kk-merge` 对比只剩 7 个目标额外文件，均为源分支删除但本次按规则保留的文件。
- 用户明确禁止使用 `git merge`；同理不使用 `git rebase` 或 `git cherry-pick` 来完成合并。
- “新增内容”默认理解为新增文件和修改文件中的新增业务代码；删除性变更不主动执行。
- 大型 CSV/JSON/JAR/P12/图片等二进制或大文件必须按文件内容补齐，不能手工重写。
- 如果同一文件在目标工作区已有未提交改动，必须先对比再合并，不能直接覆盖。

## 需求 *(必填)*

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下创建本 Spec Kit 目录。
- **FR-002**：系统 MUST 记录源分支 `kk-merge`、目标分支 `kk-merge-2026` 和仓库路径 `C:\workspace\drh`。
- **FR-003**：系统 MUST 使用文件对比结果指导合并，不得执行 `git merge`。
- **FR-004**：系统 MUST 保留 `kk-merge-2026` 工作区中已有未提交改动，不得无差别覆盖。
- **FR-005**：系统 MUST 将 `kk-merge` 中新增但目标缺失的文件补齐到工作区。
- **FR-006**：系统 MUST 对修改文件进行逐文件差异处理，吸收 `kk-merge` 的新增代码块。
- **FR-007**：系统 MUST 默认不删除 `kk-merge-2026` 中已有文件，除非用户明确要求同步删除。
- **FR-008**：系统 MUST 对二进制新增文件采用源分支内容复制，不做文本编辑。
- **FR-009**：系统 MUST 在 `tasks.md` 中记录差异统计、执行命令、验证结果和剩余风险。

## 成功标准 *(必填)*

- **SC-001**：本目录包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：`tasks.md` 记录两个分支的提交点和文件差异统计。
- **SC-003**：没有执行 `git merge`、`git rebase` 或 `git cherry-pick`。
- **SC-004**：`kk-merge` 中新增但当前目标缺失的文件被补齐。
- **SC-005**：合并后通过文件差异命令确认剩余差异只包含刻意保留的目标分支内容、未处理风险或用户未要求的删除性变更。
- **SC-006**：最终状态和验证命令写入 `tasks.md`。

## 假设

- 合并目标是当前 `C:\workspace\drh` 工作区中的 `kk-merge-2026` 分支。
- 允许使用 `git diff`、`git show`、`git ls-tree`、文件复制和补丁编辑来完成文件级对比合并。
- 不要求创建提交；只需要把合并结果留在工作区并记录验证结果。
- 删除性变更不属于“新增内容”的默认范围。
