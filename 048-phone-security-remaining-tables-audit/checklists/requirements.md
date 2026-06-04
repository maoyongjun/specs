# 需求检查清单

## 排查完整性

- [ ] 所有未覆盖的含 phone 字段 MySQL 表已列出
- [ ] 每张表标注了优先级（P1-P4）
- [ ] 每张表列出了实体类路径（含跨模块副本）
- [ ] 每张表列出了 Mapper XML 文件路径和 phone 使用类型
- [ ] P1/P2 表列出了 Service 方法和 Controller 接口路径
- [ ] 每张表标注了所属模块
- [ ] 非 MySQL 存储已单独列出
- [ ] ju-chat 跨模块副本实体已识别

## 设计选择确认

- [ ] P3 LIKE 查询处理方案已确认
- [ ] drh_temp_phone 是否纳入改造已确认
- [ ] drh_sms_deal 是否纳入改造已确认
- [ ] drh_mall_order.reciver_phone 是否同口径改造已确认
- [ ] P4 表是否需要数据库层面移除 phone 列已确认
