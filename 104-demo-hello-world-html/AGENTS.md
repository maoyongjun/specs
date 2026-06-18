# 规格执行说明

本目录记录 `Demo Hello World HTML` 需求的规格、任务、检查清单和执行记录。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\104-demo-hello-world-html`
- 目标项目：`C:\workspace\ju-chat`
- 相关模块：工作区根目录静态 HTML demo 文件

## 当前目标

- 新增 `C:\workspace\ju-chat\demo.html`。
- 页面可见区域输出 `helloworld`。
- 不修改既有业务项目、构建配置或依赖。
- 对 `specs` 仓库内本次 spec 文档执行本地 commit，不 push。

## 执行原则

- 实施前确认 `demo.html` 仍不存在，避免覆盖用户已有文件。
- 只新增最小 HTML 文件，不引入框架、脚本依赖或开发服务器。
- 保持输出文本与用户需求完全一致：`helloworld`。
- 如用户改口指定路径或文本，先同步规格文档再实施变更。
- 不处理无关未跟踪文件或其他项目改动。
- `C:\workspace\ju-chat` 不是 git 仓库，`demo.html` 无法纳入 `specs` 仓库 commit；提交时只指定 `104-demo-hello-world-html` 目录内文件。

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：输出文本来自用户需求，目标路径来自本规格假设。
- 赋值时机：输出文本在 HTML 编写时静态写入。
- 占位对象：本需求不涉及 DTO、JSON、Map。
- 下游读取：浏览器读取 HTML body 可见文本。
- 旧逻辑保持：不修改已有业务代码、不新增构建链路。
- 影响范围：只新增一个 HTML 文件。
- 测试映射：文件存在性检查、内容静态检查、无同名覆盖检查。

## 重点代码位置

- 目标文件：`C:\workspace\ju-chat\demo.html`
- 规格文件：`C:\workspace\ju-chat\specs\104-demo-hello-world-html\spec.md`
- 任务文件：`C:\workspace\ju-chat\specs\104-demo-hello-world-html\tasks.md`
- 检查清单：`C:\workspace\ju-chat\specs\104-demo-hello-world-html\checklists\requirements.md`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加执行记录，并同步更新相关文档。
