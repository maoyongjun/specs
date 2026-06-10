# 规格执行说明

本目录用于执行 `066-phone-security-interface-gap-audit` 审计出的手机号安全漏改项，并落实用户确认的整改口径。本规格进入业务代码修复阶段，会修改 `kkhc` 和 `drh` 的实体、Service、Controller、Mapper。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\067-phone-security-gap-remediation`
- 目标项目：
  - `C:\workspace\ju-chat\kkhc`
  - `C:\workspace\drh`
- 相关模块：
  - `kkhc-idc/app`、`kkhc-idc/lms`、`kkhc-idc/ai`、`kkhc-idc/lms-common`、`kkhc-idc/ai-common`、`kkhc-idc/base-common`
  - `kkhc-bizcenter/app`
  - `drh-common`
  - `drh-kk-cms`
  - `drh-media-process`

## 用户确认的整改口径

1. **加解密工具副本**：kkhc `ai-common`、kkhc `base-common`、drh `drh-common` 三套 `DataSecurityInvoke` 暂时保留现状，本规格不做合并，各模块继续调用本地工具。
2. **历史数据回填**：由 `juzi-service` 已编写的方法负责数据更新，不在本规格范围内；本规格只改代码读写口径。
3. **idc-ai 漏改**：`ai` 模块未改全的接口（补发明细查询、无企微任务明细查询等）一并修复。
4. **逻辑 bug**：修正 `OrderBookReissueServiceImpl` 的 `phoneMd5` 计算条件与 MD5 口径。
5. **模糊搜索**：`frontWork`、`front/myClass`、`mall/list` 的手机号模糊搜索改为基于 `phoneMd5` 的精确搜索，不再保留 `LIKE` 模糊。
6. **实体字段**：保留原始明文 `phone` 字段不删除；展示统一用掩码（`phoneMask` 或现算掩码）赋值；缺失安全字段的实体补齐 `phoneMask/phoneMd5/phoneAes`。

## 执行原则

- 精确手机号查询统一口径：进入 Mapper/Wrapper 前调用本模块的 `DataSecurityInvoke.computePhoneMd5(...)`，查询 `*_md5` 字段。
- 集合查询：先把入参手机号集合归一为 MD5 集合，再用 `in` 查询 `*_md5`。
- 默认响应：`phone` 展示掩码，并保留 `phoneMask/phoneMd5/phoneAes`；`065` 已确认的 app `/app/collect/order/pageQuery` 返回 `phoneAes` 例外保持不变。
- 保存链路：`save/update` 前调用 `createAesInfo()` 或等价方法生成安全字段，禁止保存后异步补齐作为唯一保障。
- 外呼、ERP、短信等下游需要明文：库内匹配一律用 `phoneMd5`，仅在向外部发送请求时使用解密后的明文，不得用明文做库内查询或 Redis key。
- 不改接口路径、HTTP 方法、分页参数、权限过滤和导出文件结构。
- 不新增对外 API；不改 MQ/Redis/配置契约（外呼缓存 key 的内部归一化除外，需在 `tasks.md` 单独记录）。

## 强制门禁

进入每个修复点前必须确认并记录到 `tasks.md`：

- 入口 Controller/Feign/回调方法已确认。
- 入参 `phone` 的来源、格式、赋值时机已确认。
- 响应字段 `phone/phoneMask/phoneMd5/phoneAes` 的来源已确认。
- 保存链路是否调用 `createAesInfo()` 或等价方法已确认。
- 所属模块使用的是本地 `DataSecurityInvoke`（不跨模块误引用）。

## 依赖与前置

- DDL：本规格涉及表的 `*_md5`（含索引）、`*_mask`、`*_aes` 字段由 `032/051/063` 提供；进入查询切换前需确认目标库列已存在。
- 历史回填：由 `juzi-service` 负责，本规格上线需与回填进度对齐，避免 `*_md5` 为空导致旧数据查不到。

## 重点代码位置

见 `tasks.md` 每个任务行内标注的 `file:line` 证据。

## 文档维护

- `spec.md` 记录整改背景、修复清单、防漏分析、需求和成功标准。
- `tasks.md` 记录按模块拆分的可执行修复任务和验证任务。
- `checklists/requirements.md` 验证规格质量与实施就绪度。
- 实施中若发现新的漏改或口径变化，追加 `Dxxx` 纠正记录并同步三个文件。
