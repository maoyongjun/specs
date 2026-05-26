# 任务清单：学习之星奖状图片生成

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的单元测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前阶段只做图片生成调研和方案，不实现圈选/发送。
- [x] T002 用代码搜索确认旧“实践之星”前端页面源码未在当前 workspace 中定位到。
- [x] T003 确认当前仓库已有服务端图片合成参考：`NotePicsServiceImpl` 使用 `ImageIO/Graphics2D` 读取模板、合成图片并上传 OSS。
- [x] T004 确认当前仓库已有微信图片发送参考：`SopConfigSender` 的 `IMAGE` action 通过 `JuziUtil.sendJuzi` 将图片 URL 写入 payload `url`。
- [x] T005 确认当前仓库已有素材/OSS 上传参考：`HomeworkMaterialService` 和 `OssUtil` 可作为后续上传/素材中心接入参考。
- [x] T006 确认姓名来源仍需后续圈选逻辑提供；现有链路能看到 `WebChatVoiceDto.contactName`、`drh_external_user_info.name`、`name_tushu` 等相近字段，但未定位到 `tuhsu_name` 同名字段。

**检查点**：本阶段已完成事实确认，可以进入 Batik 方案实现准备；demo 已使用当前模板、签名字体和坐标输出样图，生产接入前仍需最终素材验收。

## Phase 2：风险门禁

- [x] T007 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或占位传参风险；本阶段无业务代码传参，规格要求实现时禁止空请求下传。
- [x] T008 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段；规格要求所有字段先解析再生成 SVG，生成 URL 后才发送。
- [x] T009 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用。
- [x] T010 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为；调研方案不改变现有发送契约。
- [x] T011 记录需要用户确认的业务语义变化：底图是否干净、签名是否绘制、日期格式、输出格式、字体坐标和字体来源。
- [x] T012 为关键行为建立测试映射：姓名解析、日期、硬编码文案、SVG 生成、Batik 渲染、图片非空、失败不发送。

**检查点**：风险已记录；Batik 方案符合 jar / Linux 容器 / 无浏览器依赖约束。

## Phase 3：实现准备

- [x] T013 获取或确认当前 demo 使用的学习之星底图；模板已包含固定文案，只为姓名、年份、日期和签名保留动态填充位。
- [x] T014 根据当前底图尺寸建立 SVG 布局配置，包括坐标、字体、颜色、最大宽度、层级和对齐方式。
- [x] T015 确认 demo 字体来源；签名使用用户提供的 `Slideqiuhong-Regular.ttf` 并通过 JVM 注册。
- [x] T016 设计 demo 版 `RenderRequest` / `RenderResult`，生成前解析字段，不允许空请求下传到渲染。
- [x] T017 引入 Apache Batik 依赖，例如 `batik-transcoder` 及 PNG 输出所需依赖，并确认版本与现有 Java 版本兼容。
- [x] T018 实现 SVG 生成器：底图作为 `<image>`，动态文本转为 SVG `<text>`，签名使用给定 TTF 转 SVG path，可按配置启用或保留模板原样。
- [x] T019 实现 Batik 渲染器：使用 `PNGTranscoder` 将 SVG 输入转为 PNG 字节或临时文件。
- [ ] T020 实现上传适配：按后续链路需要返回 OSS/CDN URL 或素材中心 URL。
- [x] T021 实现失败策略：底图缺失、签名字体缺失、SVG 生成失败、Batik 转码失败或输出为空时返回错误，不进入发送层。
- [x] T032 将 `learning-star-certificate-demo` 切换为 Maven/Java + Batik demo，移除 HTML/headless 浏览器作为运行入口。
- [x] T033 输出本地样例 SVG 和 PNG，路径固定为 `output/learning-star-sample.svg` 和 `output/learning-star-sample.png`。
- [x] T035 按最新模板微调主体坐标：昵称和年份上移约 `0.1` 倍字体高度，年份轻微右移，日期与 `DATE` 居中对齐，`李瑶院长` 下移到落款线下方并向右居中。
- [x] T040 按视觉反馈继续微调签名：`李瑶院长` 向右移动约 `0.5` 个字体宽度，向下移动约 `0.15` 个字体高度。
- [x] T036 将模板和签名字体迁移为 classpath 默认资源，避免 IDEA / jar / Docker 因工作目录不同读取到错误路径。
- [x] T037 调整输出路径解析：默认输出到应用目录下的 `output`，并支持 `--output-dir`、系统属性和环境变量覆盖。

## Phase 4：测试与验证

- [x] T022 新增姓名解析单元测试，覆盖真实姓名、`tuhsu_name`、企微昵称截断和全空兜底。
- [x] T023 新增日期格式测试，使用固定日期验证 `2026年` 和 `2026年05月26日`。
- [x] T024 新增 SVG 生成测试，断言 SVG 包含姓名、年份、日期和签名配置，且不重复绘制模板已有固定文案。
- [x] T025 新增 Batik 渲染测试，断言 PNG 尺寸、文件非空、`ImageIO` 可读。
- [x] T026 新增 headless Java 运行验证，使用 `-Djava.awt.headless=true` 断言不依赖浏览器仍可完成渲染。
- [x] T027 新增字体测试，验证目标签名字体可加载，字体缺失时失败。
- [x] T028 新增签名测试，覆盖“模板含签名不覆盖”和“模板无签名按配置绘制”两种场景。
- [ ] T029 新增上传/发送参数测试，Mock 上传返回 URL，断言发送层读取生成后的 URL。
- [x] T030 搜索确认 demo 新生成链路没有残留旧口径 `实践之星`、`作业情况`、`开开华彩声乐6日体验课`。
- [x] T031 运行目标模块测试或编译命令，并记录结果。
- [x] T034 实现和验证完成后，回写 `spec.md`、`tasks.md` 和检查清单状态。
- [x] T038 新增 classpath 模板与默认字体读取测试，验证不依赖当前工作目录。
- [x] T039 验证 jar 包内包含模板和字体资源。

## 执行记录

### D001 - 文档与调研记录

- 执行内容：已创建 Spec Kit 文档，完成本地代码搜索和实现路径调研。
- 验证方式：搜索 `实践之星/学习之星/奖状/html2canvas/Graphics2D/ImageIO/awardInfo` 等关键词，阅读 `NotePicsServiceImpl`、`SopConfigSender`、`JuziUtil`、`HomeworkMaterialService`。
- 自检结论：仓库已有图片合成、OSS 上传和微信发送参考链路。旧前端参考页源码未定位到；发送和圈选后续再接。

### D002 - 方案纠正：切换为 Apache Batik

- 执行内容：因目标部署为 jar / Linux 容器且服务器不单独安装浏览器，推荐方案从 HTML/headless 截图切换为 Java SVG + Apache Batik 渲染 PNG。
- 验证方式：同步更新 `spec.md`、`research.md`、`tasks.md`、`checklists/requirements.md` 和 `AGENTS.md`。
- 自检结论：文档已明确无浏览器依赖，后续实现以 Batik、字体加载和 Linux headless Java 验证为核心。

### D003 - 实现记录

- 执行内容：已将 `learning-star-certificate-demo` 实现为 Maven/Java + Apache Batik demo。模板以内嵌 base64 放入 SVG `<image>`，动态字段通过 SVG `<text>` 绘制，Batik `PNGTranscoder` 输出 PNG。
- 动态字段：只绘制学员名称、年份数字、发证日期和 `李瑶院长`；模板已有的固定文案不再由代码重复生成。
- 签名：默认 `draw`，字体使用 `classpath:/fonts/Slideqiuhong-Regular.ttf` 转 SVG path，避免 Batik 按系统字体名匹配失败；并支持 `template` 模式保留模板签名。
- 坐标：按当前模板微调完成，昵称和年份上移约 `0.1` 倍字体高度，年份轻微右移，日期与 `DATE` 居中对齐，签名移动到落款线下方并按落款区中轴居中。
- 追加坐标微调：根据用户反馈，签名中心点从 `x=1132,y=832` 调整到 `x=1156,y=839`，约等于右移 `0.5` 个字体宽度、下移 `0.15` 个字体高度。
- 路径：模板和字体默认使用 `classpath:/certificates/template-clean.png`、`classpath:/fonts/Slideqiuhong-Regular.ttf`，同时保留外部路径覆盖能力；输出默认解析到应用目录下的 `output`，避免受工作目录影响。
- 验证方式：执行 `mvn clean test`，结果 `Tests run: 10, Failures: 0, Errors: 0, Skipped: 0`。
- 路径验证：从 `C:\workspace\ju-chat` 执行 `mvn -q -f learning-star-certificate-demo\pom.xml exec:java ...`，输出仍为 `C:\workspace\ju-chat\learning-star-certificate-demo\output\learning-star-sample.png`，没有写入 `C:\workspace\ju-chat\output`。
- jar 验证：执行 `mvn -q package -DskipTests` 后，`jar tf target\learning-star-certificate-demo-1.0.0-SNAPSHOT.jar` 包含 `certificates/template-clean.png` 和 `fonts/Slideqiuhong-Regular.ttf`。
- 样图：已输出 `learning-star-certificate-demo/output/learning-star-sample.svg` 和 `learning-star-certificate-demo/output/learning-star-sample.png`；PNG 尺寸 `1549x1015`，文件非空且可读。
- 剩余风险：T020/T029 上传与发送链路未接入，本阶段保持后续生产接入任务；真实 Linux 镜像内字体和依赖仍需在目标镜像中复验。
