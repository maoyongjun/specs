# 调研记录与实现方案：学习之星奖状图片生成

**调研日期**：`2026-05-26`

## 本地代码事实

- 旧“实践之星”页面源码未在当前 workspace 中定位到。已搜索 `实践之星`、`奖状模板`、`html2canvas`、`复制截图`、`下载截图`、`toDataURL` 等关键词，未找到可直接复用的前端页面实现。
- 当前仓库已有服务端图片合成参考：`NotePicsServiceImpl` 会下载模板图，使用 `ImageIO/Graphics2D` 绘制合成图，写入临时 PNG，再上传 OSS 并返回 CDN URL。
- 当前仓库已有微信图片发送参考：`SopConfigSender` 的 `IMAGE` action 会把 `materialUrl` 放入 `SendJuziParamDto.picUrl`，`JuziUtil.sendJuzi` 最终把图片 URL 写入消息 payload 的 `url`。
- 当前仓库已有素材上传参考：`HomeworkMaterialService` 提供 OSS 上传和素材中心创建逻辑，可作为后续“生成图是否入素材中心”的实现参考。
- 姓名来源仍需后续圈选逻辑确认。现有代码能看到 `WebChatVoiceDto.contactName`、OTS 表 `drh_external_user_info.name`、配置 JSON 中的 `name_tushu`，但未定位到 `tuhsu_name` 同名字段。

## 推荐方案

采用 Java 生成 SVG，再由 Apache Batik `PNGTranscoder` 渲染成 PNG。该方案不依赖 Chrome、Chromium、Puppeteer 或服务器桌面环境，适合 Java jar / Linux 容器部署。

1. 增加纯渲染服务，例如 `LearningStarCertificateRenderer`。
2. 输入规范化 DTO，例如：

```java
class LearningStarCertificateRequest {
    private String realName;
    private String tuhsuName;
    private String wecomNickName;
    private LocalDate issueDate;
    private SignatureMode signatureMode;
    private String signatureText;
}
```

3. 渲染前统一生成字段：
   - `studentDisplayName`：真实姓名 > `tuhsuName` > 企微昵称；企微昵称超过 5 个字符时截断为前 5 个字符加 `...`。
   - `currentYearText`：`LocalDate.now(Asia/Shanghai)` 得到 `YYYY年`。
   - `courseName`：`开开华彩弹琴6日体验课`。
   - `honorTitle`：`学习之星`。
   - `standardDesc`：`完课情况`。
   - `issueDateText`：按 `YYYY年MM月DD日` 生成。
4. 使用 Java 构建完整 SVG：
   - 底图通过 SVG `<image>` 引用，优先内嵌 base64，避免运行时路径或跨环境访问问题。
   - 动态字段通过 SVG `<text>` / `<tspan>` 绘制，使用精确 `x/y`、字体、字号、颜色、对齐方式。
   - 如果需要标题或签名文本层，统一在 SVG 中按布局配置生成。
5. 使用 Apache Batik `PNGTranscoder` 将 SVG 转成 PNG，并用 `ImageIO.read` 做可读性校验。
6. 生成成功后上传 OSS/CDN，返回 `imageUrl`；后续发送逻辑只消费这个 URL。
7. 签名层按模板是否已包含签名分两种模式：
   - 模板已有签名时，SVG 不额外覆盖；
   - 模板无签名时，通过配置化字段在指定位置渲染签名文本。
8. 发送接入时，先发送固定话术，再发送 `imageUrl` 图片消息，沿用现有 `JuziUtil` payload 结构。

## 方案理由

- 纯 Java：Batik 依赖可以随应用 jar 一起发布，不要求服务器安装浏览器。
- 容器友好：可在 `java.awt.headless=true` 的 Linux 容器中运行。
- 坐标可控：SVG 天然适合奖状这类固定尺寸、固定坐标的图文排版。
- 批量稳定：避免浏览器启动、字体加载、DOM 截图和运行时 Chrome 版本差异带来的不确定性。
- 可测试性好：SVG 字符串、字段解析、PNG 尺寸和图片可读性都可以用单元测试或集成测试覆盖。

## 坐标与样式建议

以下坐标仅按用户截图的目标图做排版参考，不能替代最终切图标注。假设底图约 `1484 x 1016`。Batik 方案中这些坐标直接转为 SVG 文本坐标，便于后续调整。

| 字段 | 建议位置 | 对齐 | 说明 |
| --- | --- | --- | --- |
| 主标题 `学习之星` | x=742, y=205 | 居中 | 如果底图已含标题则不绘制 |
| 副标题 `~开开华彩音乐学院~` | x=742, y=310 | 居中 | 如果底图已含副标题则不绘制 |
| 学员名称 | x=255, y=392 | 左对齐 | 与 `同学：` 同行 |
| `同学：` | 紧跟姓名后 | 左对齐 | 姓名长度变化时动态测宽或固定区域排版 |
| 描述句 | x=742, y=465 | 居中 | 包含年份、课程名、标准描述 |
| 荣誉称号 | x=742, y=545 | 居中 | `“学习之星”` 较大字号红色 |
| 发证日期 | x=355, y=760 | 居中 | 日期区横线之上，格式 `YYYY年MM月DD日` |
| 落款单位 | x=1110, y=760 | 居中 | 如底图已含单位则不绘制 |
| 落款签名 | x=1110, y=835 | 居中 | 是否绘制待确认 |

字体建议随服务打包中文字体，例如思源宋体/思源黑体或产品指定字体。实现时通过 `GraphicsEnvironment.registerFont` 或容器镜像预装字体，避免 Linux 缺字导致乱码、方块字或布局漂移。

## 不推荐方案

- 不建议把旧页面截图逻辑作为自动化主链路。原因是人工页面截图依赖浏览器、字体加载、DOM 尺寸和跨域图片，批量任务中更容易出现空白图、字体漂移和环境差异。
- 不建议将 HTML/headless Chromium 作为 jar 容器部署默认方案。该方案仍需要 Chrome/Chromium 可执行文件，和“服务器不单独安装浏览器”的约束不匹配。
- 不建议回到手写 `Graphics2D` 绘制所有元素作为首选方案。它可行但调试视觉成本更高；SVG 更接近模板化描述，且 Batik 能完成稳定服务端渲染。

## 测试方案

- 姓名解析测试：真实姓名优先、`tuhsu_name` 兜底、企微昵称截断、全空兜底。
- 日期测试：使用固定 Clock，断言 `2026年` 和 `2026年05月26日`。
- SVG 生成测试：断言 SVG 中包含新课程、新称号、新标准描述和动态姓名。
- Batik 渲染测试：使用测试底图转 PNG，断言输出图片尺寸、文件大小大于 0、`ImageIO.read` 可读。
- Linux headless 测试：设置 `java.awt.headless=true` 执行生成，断言不依赖浏览器仍能导出图片。
- 字体测试：使用目标中文字体生成样图，断言不会缺字或乱码；生产字体缺失时应失败或明确降级。
- 签名测试：分别验证模板含签名和模板不含签名时的处理结果，断言默认策略和配置覆盖逻辑符合预期。
- 上传测试：Mock OSS 上传，断言返回 URL 被写入生成结果。
- 发送接入测试：Mock `JuziUtil`，断言图片消息 payload 使用生成 URL。
- 回归搜索：实现后搜索确认新链路没有使用 `实践之星`、`作业情况`、`开开华彩声乐6日体验课`。

## 待确认问题

- 需要最终生产底图，最好是不含动态文字的 PNG。
- 需要确认落款签名是否已经在底图中；如果需要绘制，默认签名文字是什么，签名是否允许配置化覆盖。
- 日期格式已按用户需求固定为 `YYYY年MM月DD日`；如最终视觉要求空格样式，需要再确认并更新规格。
- 需要确认图片输出格式和是否必须保存到素材中心。
- 需要确认生产字体文件来源：随 jar 资源打包，还是由容器镜像预装。
- 需要后续圈选逻辑提供学员姓名字段的真实来源和字段名。
