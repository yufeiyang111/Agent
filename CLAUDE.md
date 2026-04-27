# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

海量数据电商购物平台，设计目标：千万级商品、亿级用户、十亿级订单。
技术栈：MySQL 8.0 + ShardingSphere-JDBC + Redis Cluster + Elasticsearch + RocketMQ + ClickHouse。
后端：Spring Cloud 微服务（Spring Boot 3 + Spring Cloud 2023）；前端：Vue 3 + Ant Design Vue。

## 部署数据库

```bash
# 一键部署（需要 MySQL root 密码）
# Windows:
deploy/deploy.bat 你的root密码

# Linux/macOS:
chmod +x deploy/deploy.sh
./deploy/deploy.sh 你的root密码

# 单文件部署:
mysql -u root -p < deploy/all_in_one.sql
```

初始化结果：23 个数据库、160+ 业务表、6 个分析视图。

## 架构要点

### 分库分表
- 垂直分片（按业务域）+ 水平分片（按分片键取模）
- **订单库**按 `user_id` 分片：8 库 × 64 表 = 512 张物理表（保证"我的订单"不跨分片）
- **用户库**按 `user_id` 分片：4 库 × 32 表
- **商品库**按 `spu_id` 分片：4 库 × 32 表
- 各业务域主从配置：1 主 2 从

### 核心设计原则
- **分片键优先**：90%+ 查询带上分片键，避免跨分片查询
- **冗余避免 JOIN**：跨分片不能 JOIN，通过冗余字段（商品快照、地址快照）解决
- **冷热分离**：MySQL（热）→ ClickHouse（冷），订单 6 个月为界，每日 02:00 迁移
- **最终一致性**：不强求强一致的地方使用 MQ + 对账补偿
- **多级缓存**：浏览器 → CDN → Redis → Caffeine 本地缓存

### 高并发防线（秒杀场景）
Nginx 限流 → Sentinel 限流 → RocketMQ 削峰 → Redis LUA 原子扣库存 → 异步下单

## 工作规范

- **改动同步**：修改项目时，必须同步更新 `deploy/` 中的部署脚本和 `docs/` 中相关文档，保持三者一致
- **文档管理**：新增文档按内容分类放入 `docs/` 下对应的子目录（如 `docs/architecture/`、`docs/api/`、`docs/guide/` 等），而非全部平铺在 `docs/` 根目录

## 模块目录

| 路径 | 内容 |
|------|------|
| `deploy/` | 数据库 DDL 脚本、部署脚本 |
| `docs/` | 完整的设计文档（需求、数据库设计、设计原理、Redis 设计） |

## 数据库部署文件清单

- `deploy/01_databases.sql` — 创建 23 个分片数据库
- `deploy/02_user_center.sql` — 用户中心 6 张表
- `deploy/03_product_center.sql` — 商品中心 8 张表（含广播表）
- `deploy/04_order_center.sql` — 订单中心 8 张表
- `deploy/05_review_center.sql` — 评价中心 3 张表
- `deploy/06_marketing_center.sql` — 营销中心 6 张表
- `deploy/07_common_db.sql` — 公共库 10 张表 + 预置数据
- `deploy/08_shard_replicas.sql` — 复制模板表到所有分片
- `deploy/09_views.sql` — 6 个分析视图

## 文档索引

- [需求文档](docs/requirements.md) — 完整功能需求
- [数据库设计](docs/database-design.md) — 表结构、分片策略、缓存设计
- [设计原理](docs/design-philosophy.md) — 每个设计决策背后的"为什么"
- [第一期 DDL](docs/第一期-数据库DDL.sql) — 第一期 SQL 脚本
- [数据库说明](docs/数据库说明文档-第一期.md) — 第一期开发接入指南
- [Redis 设计](docs/Redis设计-第一期.md) — Redis 缓存设计
