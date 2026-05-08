# 生产路由配置数据修复任务

## 背景

- 2026-05-07 生产环境路由配置控制台显示路由规则数据异常。
- 已核对发布脚本 `data-RC/juzi-service/src/main/resources/sql/drh_ai_config_release_20260323.sql`，其中版本 `1774232604782` 是 2026-03-23 的完整生产路由版本。
- 生产库当前异常活跃版本为 `1778121507165`，该版本只有 AI 规则 1 条、Agent 规则 1 条。
- 恢复目标为将 `prod` 活跃版本回滚到 `1774232604782`。

## 范围

只允许触碰路由配置控制台对应的 4 张表：

- `drh_ai_config_route_active_version`
- `drh_ai_config_route_version`
- `drh_ai_config_agent_route_rule`
- `drh_ai_config_ai_reply_route_rule`

不得修改以下非本页面配置表：

- homework 路由、策略、动作等表
- 课程规则表
- 预警策略表
- 外部任务配置表
- 其他 `drh_ai_config_*` 配置表

## 已核对现状

- `drh_ai_config_route_active_version` 中 `prod` 活跃版本为 `1778121507165`。
- `1778121507165` 在路由规则表中：
  - `drh_ai_config_ai_reply_route_rule`：1 条
  - `drh_ai_config_agent_route_rule`：1 条
- `1774232604782` 在路由规则表中：
  - `drh_ai_config_ai_reply_route_rule`：5 条
  - `drh_ai_config_agent_route_rule`：7 条
- `1774232604782` 在 `drh_ai_config_route_version` 中状态为 `PUBLISHED`，快照中也包含 AI 5 条、Agent 7 条。

## 执行前确认 SQL

```sql
SELECT env_code, active_version_no, updated_by, updated_at
FROM drh_ai_config_route_active_version
WHERE env_code = 'prod';

SELECT rv.version_no,
       rv.status,
       JSON_LENGTH(JSON_EXTRACT(rv.snapshot_json, '$.agentRules')) AS snapshot_agent_rules,
       JSON_LENGTH(JSON_EXTRACT(rv.snapshot_json, '$.aiReplyRules')) AS snapshot_ai_reply_rules
FROM drh_ai_config_route_version rv
WHERE rv.version_no IN (1774232604782, 1778121507165);

SELECT version_no, COUNT(*) AS cnt
FROM drh_ai_config_agent_route_rule
WHERE version_no IN (1774232604782, 1778121507165)
GROUP BY version_no;

SELECT version_no, COUNT(*) AS cnt
FROM drh_ai_config_ai_reply_route_rule
WHERE version_no IN (1774232604782, 1778121507165)
GROUP BY version_no;
```

## 修复 SQL

只更新活跃版本指针，不删除、不插入、不改写历史版本。

```sql
START TRANSACTION;

UPDATE drh_ai_config_route_active_version
SET active_version_no = 1774232604782,
    updated_by = 'data_fix_20260507',
    updated_at = NOW(3)
WHERE env_code = 'prod'
  AND active_version_no = 1778121507165;

SELECT ROW_COUNT() AS affected_rows;

COMMIT;
```

如果 `affected_rows != 1`，立即停止，不继续执行其他修复。

## 执行后验证 SQL

```sql
SELECT env_code, active_version_no, updated_by, updated_at
FROM drh_ai_config_route_active_version
WHERE env_code = 'prod';

SELECT version_no, COUNT(*) AS cnt
FROM drh_ai_config_agent_route_rule
WHERE version_no = 1774232604782
GROUP BY version_no;

SELECT version_no, COUNT(*) AS cnt
FROM drh_ai_config_ai_reply_route_rule
WHERE version_no = 1774232604782
GROUP BY version_no;
```

期望结果：

- `active_version_no = 1774232604782`
- Agent 规则数量为 7
- AI 规则数量为 5

## 页面与缓存验证

- 刷新路由配置控制台，生效版本应显示 `1774232604782`。
- 规则数应显示 `AI 5 | Agent 7`。
- 路由缓存默认刷新间隔为 `route.feature.cacheRefreshMs=30000ms`；执行后等待 30 秒以上，再通过页面或路由验证接口确认实际生效。

## 回退方式

若业务确认需要恢复执行前状态，可只回退活跃版本指针：

```sql
START TRANSACTION;

UPDATE drh_ai_config_route_active_version
SET active_version_no = 1778121507165,
    updated_by = 'rollback_data_fix_20260507',
    updated_at = NOW(3)
WHERE env_code = 'prod'
  AND active_version_no = 1774232604782;

SELECT ROW_COUNT() AS affected_rows;

COMMIT;
```

回退后同样需要等待缓存刷新或触发页面发布接口刷新缓存。
