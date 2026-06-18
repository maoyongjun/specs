# 任务清单：Demo Hello World HTML

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段执行文件存在性和内容静态验证。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于工作区根目录的静态 HTML demo 文件新增任务。
- [x] T002 用代码搜索确认真实入口、调用链、核心实现类和测试落点：未发现既有 `demo.html`；本次无调用链，目标文件为 `C:\workspace\ju-chat\demo.html`。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型：输出文本来自用户需求，实施时静态写入 HTML body，浏览器读取可见文本。
- [x] T004 确认配置来源、环境变量、Redis key、MQ topic/tag、Feign/FC/HTTP 调用或数据库表是否受影响：均不涉及。
- [x] T005 确认已有旧逻辑中必须保持不变的过滤、幂等、异常处理、日志、延迟和 fallback：不修改已有逻辑或已有文件。

**检查点**：T001-T005 已完成；本需求无业务链路和外部依赖。

## Phase 2：风险门禁

- [x] T006 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参：不涉及。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段：不涉及。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用：输出文本在 HTML 文件中静态确定。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为：不改变。
- [x] T010 对需要用户确认的业务语义变化做记录；未确认前不得实现该变化：无业务语义变化；用户已确认进入实施并要求提交 commit。
- [x] T011 为每个关键行为建立测试映射，至少覆盖正常路径、边界路径和不回归路径：正常路径检查文件和文本；边界路径为若文件已存在则不覆盖；不回归路径为确认无既有业务文件修改。

**检查点**：T006-T011 已有明确结论；无高风险业务变更。

## Phase 3：实现

- [x] T012 按规格实现最小范围改动，新增 `C:\workspace\ju-chat\demo.html`。
- [x] T013 保持未声明的旧行为不变。
- [x] T014 本需求无外部调用参数、MQ body、Redis key、数据库写入或 FC/Feign 参数。
- [x] T015 同步更新实现记录。

## Phase 4：测试与验证

- [x] T016 执行文件存在性检查。
- [x] T017 执行内容静态检查，确认页面可见文本 `helloworld` 存在。
- [x] T018 验证没有覆盖既有 `demo.html`。
- [x] T019 记录验证命令和结果。
- [x] T020 搜索确认没有额外残留或无关业务文件变更。

## 执行记录

### D001 - 文档记录

- 执行内容：新建 `104-demo-hello-world-html` 规格文档。
- 验证方式：`rg --files -g 'demo.html'` 确认无既有同名文件；`Test-Path C:\workspace\ju-chat\demo.html` 返回 `False`；检查无 `.openai/hosting.json`。
- 自检结论：满足强制门禁；用户已确认进入实施，且实现验证已完成。

### D002 - 实现记录

- 实现内容：新增 `C:\workspace\ju-chat\demo.html`，页面 `body` 输出 `helloworld`；同步更新 spec 执行记录。
- 测试命令：
  - `Test-Path -LiteralPath 'C:\workspace\ju-chat\demo.html'`
  - `Select-String -LiteralPath 'C:\workspace\ju-chat\demo.html' -Pattern 'helloworld'`
  - `Get-Content -LiteralPath 'C:\workspace\ju-chat\demo.html'`
  - `rg "<script|http://|https://|npm|vite" 'C:\workspace\ju-chat\demo.html'`
- 测试结果：文件存在；`demo.html:9` 匹配 `helloworld`；HTML 内容为最小静态文档；未发现脚本、远程资源或构建工具引用。
- 自检结论：参数来源明确、无调用顺序风险、旧逻辑未修改；`C:\workspace\ju-chat` 不是 git 仓库，`demo.html` 无法纳入本地 commit，提交范围限定为 `specs` 仓库中的本次 spec 文件。
