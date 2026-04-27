# 电商平台数据库初始化脚本

## 环境要求

- MySQL 8.0+
- mysql 客户端可用
- root 权限（或具有 CREATE DATABASE/TABLE 权限的用户）

## 快速部署

### 方式一：一键脚本（推荐）

**Windows:**
```bash
deploy.bat 你的root密码
```

**Linux/macOS:**
```bash
chmod +x deploy.sh
./deploy.sh 你的root密码
```

### 方式二：单文件部署（最简单）

只需在目标机器上执行一个文件：

```bash
mysql -u root -p < all_in_one.sql
```

直接登录 MySQL 后执行：

```sql
source deploy/all_in_one.sql;
```

### 方式三：分步执行

```bash
# 1. 创建数据库
mysql -u root -p < 01_databases.sql

# 2. 创建各业务域表
mysql -u root -p user_db_0 < 02_user_center.sql
mysql -u root -p product_db_0 < 03_product_center.sql
mysql -u root -p order_db_0 < 04_order_center.sql
mysql -u root -p review_db_0 < 05_review_center.sql
mysql -u root -p marketing_db_0 < 06_marketing_center.sql
mysql -u root -p common_db < 07_common_db.sql

# 3. 复制模板表到所有分片
mysql -u root -p < 08_shard_replicas.sql

# 4. 创建视图
mysql -u root -p common_db < 09_views.sql
```

## 脚本清单

| 文件 | 内容 |
|------|------|
| `all_in_one.sql` | 一键初始化（包含全部DDL+数据+分片复制） |
| `01_databases.sql` | 创建23个分片数据库 |
| `02_user_center.sql` | 用户中心6张表 |
| `03_product_center.sql` | 商品中心8张表（含广播表） |
| `04_order_center.sql` | 订单中心8张表 |
| `05_review_center.sql` | 评价中心3张表 |
| `06_marketing_center.sql` | 营销中心6张表 |
| `07_common_db.sql` | 公共库10张表 + 预置数据 |
| `08_shard_replicas.sql` | 复制模板表到所有分片 |
| `09_views.sql` | 6个分析视图 |
| `deploy.bat` | Windows一键部署 |
| `deploy.sh` | Linux/macOS一键部署 |

## 初始化结果

- 数据库: 23个（user_db x4, product_db x4, order_db x8, review_db x4, marketing_db x2, common_db x1）
- 业务表: 160张（含广播表，所有分片中的 _0 模板表）
- 视图: 6个（v_product_sales_30d, v_user_order_summary, v_category_sales, v_pending_tasks, v_coupon_usage_stats, v_daily_business_metrics）
- 预置配置: 7条系统配置 + 7条ID生成器

## 后续配置

初始化完成后，需配置 ShardingSphere-JDBC 的分片规则。参见 [数据库说明文档](../docs/数据库说明文档-第一期.md) 第11节。
