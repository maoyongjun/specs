# 功能规格：Demo Hello World HTML

**功能目录**：`104-demo-hello-world-html`  
**创建日期**：`2026-06-18`  
**状态**：Draft  
**输入**：`编写demo的html ，输出helloworld.`

## 背景

- 当前问题：工作区根目录暂未发现 `demo.html`，用户需要一个最小 HTML demo 输出 `helloworld`。
- 当前行为：`C:\workspace\ju-chat\demo.html` 不存在，无法直接通过本地 HTML 文件查看 demo 输出。
- 目标行为：新增 `C:\workspace\ju-chat\demo.html`，浏览器打开后页面正文显示 `helloworld`，并对可纳入仓库的本次 spec 文档执行本地 commit。
- 非目标：不接入前端框架、不启动开发服务器、不增加样式系统、不修改已有业务项目代码、不 push。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 打开 Demo 查看输出（优先级：P1）

用户希望获得一个可直接打开的 HTML demo 文件，页面输出 `helloworld`。

**独立测试**：检查 `demo.html` 文件存在且 HTML 正文包含可见文本 `helloworld`。

**验收场景**：

1. **Given** 工作区根目录不存在 `demo.html`，**When** 创建 demo 文件，**Then** 文件路径为 `C:\workspace\ju-chat\demo.html`。
2. **Given** 用户用浏览器打开 `demo.html`，**When** 页面渲染完成，**Then** 页面显示 `helloworld`。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - 输出文本：来源为用户原始需求 `helloworld`；赋值时机为 HTML 编写时静态写入；下游读取位置为浏览器 DOM 渲染。
  - 目标路径：来源为本规格假设的工作区根目录 `C:\workspace\ju-chat\demo.html`；赋值时机为实施阶段新增文件；下游读取位置为用户或浏览器打开文件。
- 下游读取字段清单：
  - 浏览器读取 HTML 文档结构和 `body` 内可见文本 `helloworld`。
- 空对象 / 占位对象风险：
  - 否；本需求不涉及 DTO、JSON、Map 或跨层参数传递。
- 调用顺序风险：
  - 否；本需求为静态文件新增，不涉及异步调用、远程调用或调用后赋值。
- 旧逻辑保持：
  - 不修改既有文件、不引入构建流程、不影响已有项目入口、不删除或覆盖无关文件。
- 需要用户确认的设计选择：
  - 无阻塞项。默认在工作区根目录创建 `demo.html`；若用户后续指定其他目录，追加纠正记录并同步文档。

## 边界情况

- 若实施前发现 `demo.html` 已存在：停止覆盖，先确认是否复用或改名。
- 若用户指定其他输出文本：以用户新文本为准，追加纠正记录。
- 若用户要求放入特定项目目录：改用指定路径并同步规格文档。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 新增一个可直接打开的 HTML 文件 `C:\workspace\ju-chat\demo.html`。
- **FR-002**：系统 MUST 在页面可见区域输出完全匹配的文本 `helloworld`。
- **FR-003**：系统 MUST NOT 修改已有业务项目文件、构建配置、依赖或启动脚本。
- **FR-004**：验证 MUST 至少包含文件存在性检查和内容静态检查。
- **FR-005**：提交 MUST 只包含 `specs` 仓库中本次相关 spec 文件；`C:\workspace\ju-chat\demo.html` 因工作区根目录不是 git 仓库，无法纳入本地 commit。

## 成功标准 *(必填)*

- **SC-001**：`demo.html` 文件存在于 `C:\workspace\ju-chat`。
- **SC-002**：`demo.html` 包含标准 HTML 骨架和页面可见文本 `helloworld`。
- **SC-003**：除本 spec 文档和目标 demo 文件外，不产生无关业务代码改动。
- **SC-004**：`specs` 仓库本地 commit 只包含 `104-demo-hello-world-html` 目录内文件。

## 假设

- 用户所说的 `demo的html` 指工作区根目录下的 `demo.html`。
- 输出文本按用户原文使用小写 `helloworld`，不改为 `Hello World`。
- 静态 HTML 可满足需求，不需要本地 dev server。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成历史问题防漏分析和强制门禁检查。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：新增 `C:\workspace\ju-chat\demo.html`，标准 HTML 骨架中在 `body` 可见区域输出 `helloworld`。
- 影响范围：仅新增根目录静态 HTML 文件，并更新本 spec 执行记录；不修改业务项目代码、依赖或构建配置。
- 验证命令：
  - `Test-Path -LiteralPath 'C:\workspace\ju-chat\demo.html'`
  - `Select-String -LiteralPath 'C:\workspace\ju-chat\demo.html' -Pattern 'helloworld'`
  - `rg "<script|http://|https://|npm|vite" 'C:\workspace\ju-chat\demo.html'`
- 验证结果：文件存在；内容包含 `helloworld`；未发现脚本、远程资源、npm 或 vite 引用。
- 自检结论：满足 FR-001 至 FR-004；无外部调用、无数据库/MQ/Redis/FC/Feign 影响。

### D003 - 提交范围记录

- 触发原因：用户补充要求“进行实施验证并提交commit”。
- 修正内容：原非目标中的“不提交 git”调整为“不 push”；本地 commit 仅限 `specs` 仓库内本次 spec 文件。`C:\workspace\ju-chat` 不是 git 仓库，因此 `C:\workspace\ju-chat\demo.html` 无法纳入本地 commit。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md` 和 `checklists/requirements.md`。
- 验证结果：`git -C 'C:\workspace\ju-chat' rev-parse --show-toplevel` 失败并提示不是 git 仓库；`git -C 'C:\workspace\ju-chat\specs' rev-parse --show-toplevel` 返回 `C:/workspace/ju-chat/specs`。
