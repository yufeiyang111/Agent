# 海量数据电商购物平台 — 数据库设计文档

> 文档版本：v1.0  
> 数据规模：千万级商品、亿级用户、十亿级订单  
> 技术栈：MySQL 8.0 + ShardingSphere-JDBC 5.x + Redis + Elasticsearch + ClickHouse

---

## 目录

1. [设计原则与指导思想](#1-设计原则与指导思想)
2. [总体架构设计](#2-总体架构设计)
3. [分库分表策略详解](#3-分库分表策略详解)
4. [分布式 ID 方案](#4-分布式-id-方案)
5. [冷热分离策略](#5-冷热分离策略)
6. [数据库集群架构](#6-数据库集群架构)
7. [用户中心表设计](#7-用户中心表设计)
8. [商品中心表设计](#8-商品中心表设计)
9. [订单中心表设计](#9-订单中心表设计)
10. [库存中心表设计](#10-库存中心表设计)
11. [营销中心表设计](#11-营销中心表设计)
12. [评价中心表设计](#12-评价中心表设计)
13. [物流/支付表设计](#13-物流支付表设计)
14. [索引设计策略](#14-索引设计策略)
15. [缓存设计](#15-缓存设计)
16. [高并发应对方案](#16-高并发应对方案)
17. [数据迁移与归档方案](#17-数据迁移与归档方案)
18. [附录：ER 图说明](#18-附录er-图说明)

---

## 1. 设计原则与指导思想

### 1.1 五大核心原则

```
┌────────────────────────────────────────────────────────────┐
│                    数据库设计原则                            │
├──────────┬──────────┬──────────┬──────────┬────────────────┤
│ 分库分表  │ 冷热分离  │ 读写分离  │ 异构冗余  │ 最终一致性    │
│          │          │          │          │                │
│ 水平拆分  │ 按时间    │ 主库写    │ ES 搜索   │ MQ 最终      │
│ 突破单库  │ 分层存储   │ 从库读    │ 数据异构   │ 一致 + 对账  │
│ 性能上限  │ 降成本    │ 分摊读负载 │ 解耦查询  │ 兜底          │
└──────────┴──────────┴──────────┴──────────┴────────────────┘
```

### 1.2 设计哲学

| 原则 | 说明 |
|------|------|
| **数据分片优先** | 所有大表在创建时就考虑分片，避免后续数据量过大再改造 |
| **查询即分片键** | 设计分片键时考虑90%以上查询场景，避免跨分片查询 |
| **冗余避免 JOIN** | 合理冗余字段减少跨库 JOIN（跨分片 JOIN 性能极差） |
| **数据分层** | 热数据（MySQL）+ 温数据（TiDB）+ 冷数据（ClickHouse）三级分层 |
| **最终一致性** | 不强求强一致的地方使用最终一致性 + 对账补偿机制 |

---

## 2. 总体架构设计

### 2.1 数据库集群拓扑

```
                        ┌──────────────────┐
                        │    DNS / SLB     │
                        └────────┬─────────┘
                                 │
                ┌────────────────┼────────────────┐
                │                │                │
        ┌───────▼───────┐ ┌─────▼───────┐ ┌──────▼──────┐
        │  ShardingSphere │ │  ShardingSphere││  ShardingSphere│
        │   App 实例 1    │ │   App 实例 2  ││   App 实例 3   │
        └───────┬───────┘ └─────┬───────┘ └──────┬───────┘
                │                │                │
    ┌───────────┼───────────┬───┴────┬──────┬────┘
    │           │           │        │      │
    ▼           ▼           ▼        ▼      ▼
┌───────┐ ┌───────┐ ┌───────┐ ┌────────┐ ┌────────┐
│ 用户库  │ │ 商品库 │ │ 订单库 │ │ 评价库  │ │ 营销库  │
│ 4主8从  │ │ 4主8从 │ │ 8主16从│ │ 4主8从  │ │ 2主4从  │
└───┬───┘ └───┬───┘ └───┬───┘ └───┬────┘ └───┬────┘
    │         │         │         │          │
    ▼         ▼         ▼         ▼          ▼
┌──────────────────────────────────────────────────────┐
│                   Redis Cluster                       │
│          (商品缓存 / Session / 秒杀库存)               │
└──────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────┐
│               Elasticsearch Cluster                   │
│              (商品搜索 / 日志检索)                     │
└──────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────┐
│           RocketMQ Cluster (削峰/异步/解耦)            │
└──────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────┐
│          ClickHouse (冷数据 / OLAP 分析)              │
└──────────────────────────────────────────────────────┘
```

### 2.2 数据库物理分片规模

| 业务域 | 库数量 | 每库表数量 | 总物理表数 | 主从配置 |
|--------|--------|-----------|-----------|---------|
| 用户库 | 4 | 32 | 128 | 1主2从 |
| 商品库 | 4 | 32 | 128 | 1主2从 |
| 订单库 | 8 | 64 | 512 | 1主2从 |
| 评价库 | 4 | 32 | 128 | 1主2从 |
| 营销库 | 2 | 16 | 32 | 1主2从 |
| 合计 | 22 | — | 928 | 22主44从共66节点 |

---

## 3. 分库分表策略详解

### 3.1 分片键选择矩阵

| 表 | 分片键 | 分片算法 | 库数量 | 表数量 | 说明 |
|----|--------|---------|--------|--------|------|
| user | user_id | user_id % 4 | 4 | 32 | 用户维度的数据按用户ID哈希 |
| user_address | user_id | 同 user 库 | — | — | 用户关联表沿用相同分片键 |
| spu | spu_id | spu_id % 4 | 4 | 32 | 商品按商品ID哈希 |
| sku | spu_id | 同 spu 库 | — | — | SKU 跟 SPU 保持在同一分片 |
| order | user_id | user_id % 8 | 8 | 64 | **关键设计**：订单按买家ID分片 |
| order_item | order_id 或 user_id | 与 order 一致 | — | — | 保证订单和明细在同一分片 |
| review | product_id | product_id % 4 | 4 | 32 | 评价按商品ID分片（查看评价时以商品维度） |
| coupon | coupon_id | coupon_id % 2 | 2 | 16 | 营销数据量相对小 |

### 3.2 分片算法详解

#### 3.2.1 用户表分片

```
分片键：user_id（BigInt，雪花算法生成）
算法：db_idx = (user_id >> 4) % 4   // 4 个库
      tb_idx = (user_id >> 4) % 32  // 每库 32 张表
      // >> 4 是为了让分片更均匀（跳过末位低位随机性）

例如：user_id = 170141183460469231731687303715884105728
      db_idx = (170141183460469231731687303715884105728 >> 4) % 4 = 0
      tb_idx = (170141183460469231731687303715884105728 >> 4) % 32 = 15
      路由到：user_db_0 → user_15
```

#### 3.2.2 订单表分片（关键设计）

```
分片键：user_id（买家的用户ID）
算法：db_idx = user_id % 8            // 8 个库
      tb_idx = (user_id >> 4) % 64    // 每库 64 张表

注意：
  - 订单按 user_id 分片，保证了"我的订单"查询不跨分片
  - 卖家查订单需要走 ES 或通过映射表查询
  - 需要建立 order_no → user_id 的映射表，方便通过订单号找到分片
```

#### 3.2.3 订单号 → 用户ID 映射表

由于按 `user_id` 分片，当只有订单号时无法直接定位分片，需要映射表：

```sql
-- 全局映射表（不分区，或者仅按 order_no 哈希分成 2 库）
CREATE TABLE order_no_mapping (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    order_no VARCHAR(32) NOT NULL COMMENT '订单号',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_order_no (order_no),
    INDEX idx_user_id (user_id)
);
```

**查询过程：**
```
用户输入订单号查询：
 ① 先查 order_no_mapping 表 → 得到 user_id
 ② 通过 user_id 计算分片 → order_db_${db_idx}.order_${tb_idx}
 ③ 在对应分片查询订单

优化：订单号前 4 位编码 user_id 的低位 → 无需查映射表
方案：order_no = 前缀(2位业务码) + 时间戳(8位) + user_id低位(4位) + 序列(4位)
      共 18 位，通过订单号可直接解析出 user_id 低位，更快定位分片
```

### 3.3 ShardingSphere 配置示例

```yaml
# shardingSphere 分片配置（订单库示例）
rules:
  - !SHARDING
    tables:
      t_order:
        actualDataNodes: order_db_${0..7}.order_${0..63}
        tableStrategy:
          standard:
            shardingColumn: user_id
            shardingAlgorithmName: order_table_sharding
        databaseStrategy:
          standard:
            shardingColumn: user_id
            shardingAlgorithmName: order_db_sharding
    shardingAlgorithms:
      order_db_sharding:
        type: MOD
        props:
          sharding-count: 8
      order_table_sharding:
        type: MOD
        props:
          sharding-count: 64
```

### 3.4 跨分片查询解决方案

| 场景 | 方案 | 说明 |
|------|------|------|
| 订单号查询 | 映射表 + 订单号编码 | 先查映射表获取 user_id，再路由到分片 |
| 卖家查询买家订单 | Elasticsearch | 订单数据同步到 ES，卖家在 ES 中搜索 |
| 全平台订单统计 | ClickHouse | 所有订单数据同步到 ClickHouse 分析计算 |
| 时间段查询 | 广播表 + 时间分区 | 广播表跨分片路由+时间范围裁剪 |

---

## 4. 分布式 ID 方案

### 4.1 雪花算法（Snowflake）结构

```
 0 | 000000000000000000000000000000000000000000 | 000000000000 | 000000000000
 ↑                        ↑                          ↑               ↑
符号位              41bit 时间戳（毫秒）         10bit 机器 ID   12bit 序列号
(始终为0)           ≈ 69 年（从2024年起算）        支持 1024 台机器  每毫秒 4096 个

ID 总长：64 bit（Long 类型），实际使用时转为 18~19 位十进制数字
```

### 4.2 各表 ID 生成

| 表名 | ID 字段 | 生成策略 | 说明 |
|------|---------|---------|------|
| user | user_id | 雪花算法 | 分布式唯一用户ID |
| spu | spu_id | 雪花算法 | 商品ID |
| sku | sku_id | 雪花算法 | SKUID |
| order | order_no | 业务编码型雪花ID | 订单号含业务标识 + 用户低位信息 |
| review | review_id | 雪花算法 | 评价ID |
| coupon | coupon_id | 雪花算法 | 优惠券ID |

### 4.3 为什么不能使用数据库自增 ID？

| 方案 | 问题 |
|------|------|
| MySQL AUTO_INCREMENT | 分库分表后每个分片自增值可能重复，无法保证全局唯一 |
| UUID | 无序，作为主键时 B+树频繁分裂，性能极差；存储空间大（32位字符串） |
| 雪花算法 | ✅ 有序递增、全局唯一、高性能、不依赖数据库 |

---

## 5. 冷热分离策略

### 5.1 为什么需要冷热分离？

```
成本视角：
  NVMe SSD = 约 2 元/GB/月
  HDD = 约 0.2 元/GB/月
  ClickHouse 列式存储压缩后 ≈ MySQL 的 1/5 ~ 1/10 存储成本

查询视角：
  90% 的查询集中在最近 3 个月的数据
  99% 的查询集中在最近 1 年的数据

如果 100TB 数据全部放在 MySQL 热库：
  × 存储成本极高
  × 热数据查询受冷数据拖累
  × 索引膨胀导致性能下降
```

### 5.2 冷热分离架构

```
                    数据写入入口
                         │
                         ▼
                    ┌──────────┐
                    │ MySQL 热库 │ ← 承载 100% 读写流量
                    └─────┬────┘
                          │ 定时迁移任务（每日凌晨 02:00）
                          ▼
                    ┌──────────┐
                    │  ClickHouse │ ← 存储归档冷数据
                    │  列式存储   │ ← 存储成本降至 1/5
                    └──────────┘      查询性能针对OLAP优化
```

### 5.3 各模块冷热分离策略

| 业务域 | 热数据范围 | 冷数据范围 | 冷存储方案 | 迁移条件 |
|--------|-----------|-----------|-----------|---------|
| 订单 | 最近 6 个月 | 6个月前的已完结订单 | ClickHouse | 状态为"已完成/已关闭/已退款"且时间>6月 |
| 订单明细 | 同订单主表 | 同订单主表 | ClickHouse | 同订单主表 |
| 评价 | 最近 1 年 | 1年以上的评价 | ClickHouse | create_time > 1年 |
| 浏览历史 | 最近 1 个月 | 超过1个月保留最近100条 | MongoDB | 每月清理一次 |
| 操作日志 | 最近 3 个月 | 3个月以上 | Elasticsearch | 按时间滚动索引 |
| 购物车 | 无冷热 | 7天未操作自动清理 | Redis/MySQL | 定时清理 |

### 5.4 冷热数据迁移方案

```sql
-- 每次迁移 1000 条，分批处理，避免锁竞争
-- 迁移流程：
-- Step 1: SELECT 需要迁移的数据（使用游标，避免大事务）
-- Step 2: INSERT INTO ClickHouse（通过 DataX / 自研数据同步工具）
-- Step 3: 将 MySQL 中已迁移的数据标记 `is_archived = 1`
-- Step 4: 清理已标记的数据（保留期过后物理删除）

-- 订单迁移示例
SELECT * FROM order_${tb_idx}
WHERE order_status IN ('FINISHED', 'CLOSED', 'REFUNDED')
  AND pay_time < DATE_SUB(NOW(), INTERVAL 6 MONTH)
  AND is_archived = 0
LIMIT 1000;
```

### 5.5 数据查询路由

```
用户查订单列表：
         │
         ▼
   默认查询热库（MySQL）
         │
         ├── 查到结果 → 直接返回（99% 的场景）
         │
         └── 未查到 → 提示"查询历史数据"
                │
                ▼
           用户点击"查询历史数据" → 异步查询 ClickHouse
```

---

## 6. 数据库集群架构

### 6.1 主从架构

```
            ┌─────────────┐
            │   主库 Master │  ← 写入
            └──────┬──────┘
                   │ binlog 同步
         ┌─────────┼─────────┐
         │         │         │
    ┌────▼───┐ ┌──▼────┐ ┌──▼────┐
    │ Slave1 │ │Slave2 │ │Slave3 │  ← 读取（负载均衡）
    └────────┘ └───────┘ └───────┘
```

### 6.2 读写分离策略

| 操作类型 | 路由目标 | 说明 |
|----------|---------|------|
| INSERT / UPDATE / DELETE | 主库 | 所有写操作走主库 |
| SELECT（实时性要求高） | 主库 | 商品库存、订单状态等 |
| SELECT（实时性要求低） | 从库 | 商品列表、历史订单、评价等 |
| 后台报表统计 | 从库 | 离线/定时统计任务 |
| 管理后台查询 | 从库 | 运营后台查询 |

### 6.3 高可用方案

- **主库故障**：MHA / Orchestrator 自动切换从库为主库
- **从库故障**：从库列表剔除，查询路由到其他从库
- **多活**：异地多机房部署，每个机房一套独立集群
- **备份**：每天全量备份（mysqldump）+ 实时 Binlog 备份

---

## 7. 用户中心表设计

### 7.1 用户表 (user)

```sql
-- 分片：4 库 × 32 表，分片键 user_id
CREATE TABLE user_${tb_idx} (
    user_id          BIGINT       NOT NULL COMMENT '用户ID（雪花算法）',
    username         VARCHAR(64)  NOT NULL COMMENT '用户名',
    password_hash    VARCHAR(128) NOT NULL COMMENT '密码哈希（BCrypt）',
    phone            VARCHAR(20)  DEFAULT NULL COMMENT '手机号',
    email            VARCHAR(128) DEFAULT NULL COMMENT '邮箱',
    avatar_url       VARCHAR(256) DEFAULT NULL COMMENT '头像URL',
    nickname         VARCHAR(64)  DEFAULT NULL COMMENT '昵称',
    gender           TINYINT      DEFAULT 0 COMMENT '性别：0未知/1男/2女',
    birthday         DATE         DEFAULT NULL COMMENT '生日',
    user_status      TINYINT      DEFAULT 1 COMMENT '状态：1正常/2禁用/3冻结',
    register_type    TINYINT      DEFAULT 0 COMMENT '注册方式：1手机/2邮箱/3微信/4QQ',
    register_time    DATETIME     NOT NULL COMMENT '注册时间',
    last_login_time  DATETIME     DEFAULT NULL COMMENT '最后登录时间',
    last_login_ip    VARCHAR(45)  DEFAULT NULL COMMENT '最后登录IP',
    user_level       TINYINT      DEFAULT 0 COMMENT '用户等级：0普通/1银卡/2金卡/3钻石',
    total_points     INT          DEFAULT 0 COMMENT '总积分',
    is_deleted       TINYINT      DEFAULT 0 COMMENT '逻辑删除：0未删/1已删',
    create_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_username (username),
    UNIQUE KEY uk_phone (phone),
    UNIQUE KEY uk_email (email),
    INDEX idx_register_time (register_time),
    INDEX idx_user_level (user_level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='用户表';
```

### 7.2 收货地址表 (user_address)

```sql
-- 分片：同 user 库（user_id 分片，避免跨库关联）
CREATE TABLE user_address_${tb_idx} (
    address_id     BIGINT       NOT NULL AUTO_INCREMENT COMMENT '地址ID',
    user_id        BIGINT       NOT NULL COMMENT '用户ID',
    receiver_name  VARCHAR(64)  NOT NULL COMMENT '收货人姓名',
    receiver_phone VARCHAR(20)  NOT NULL COMMENT '收货人手机号',
    province       VARCHAR(32)  NOT NULL COMMENT '省份',
    city           VARCHAR(32)  NOT NULL COMMENT '城市',
    district       VARCHAR(32)  NOT NULL COMMENT '区县',
    street         VARCHAR(128) NOT NULL COMMENT '详细街道地址',
    zip_code       VARCHAR(10)  DEFAULT NULL COMMENT '邮编',
    address_label  VARCHAR(16)  DEFAULT NULL COMMENT '标签：家/公司/学校',
    is_default     TINYINT      DEFAULT 0 COMMENT '是否默认地址：0否/1是',
    create_time    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (address_id),
    INDEX idx_user_id (user_id),
    INDEX idx_is_default (user_id, is_default)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='用户收货地址表';
```

### 7.3 用户收藏表 (user_collection)

```sql
-- 分片：同 user 库
CREATE TABLE user_collection_${tb_idx} (
    collect_id   BIGINT       NOT NULL AUTO_INCREMENT COMMENT '收藏ID',
    user_id      BIGINT       NOT NULL COMMENT '用户ID',
    spu_id       BIGINT       NOT NULL COMMENT '商品SPU ID',
    folder_id    BIGINT       DEFAULT NULL COMMENT '收藏夹ID(可选)',
    create_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (collect_id),
    UNIQUE KEY uk_user_spu (user_id, spu_id),
    INDEX idx_user_id (user_id),
    INDEX idx_spu_id (spu_id),
    INDEX idx_create_time (user_id, create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='用户收藏表';
```

### 7.4 浏览历史表 (user_browsing_history)

```sql
-- 注意：浏览历史建议存入 MongoDB，这里只做 MySQL 辅助存储
-- MySQL 存储最近 30 天记录，历史数据迁移到 MongoDB

CREATE TABLE user_browsing_history_${tb_idx} (
    id          BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    user_id     BIGINT       NOT NULL COMMENT '用户ID',
    spu_id      BIGINT       NOT NULL COMMENT '商品SPU ID',
    sku_id      BIGINT       DEFAULT NULL COMMENT 'SKU ID',
    stay_seconds INT         DEFAULT 0 COMMENT '停留时长（秒）',
    source      VARCHAR(32)  DEFAULT NULL COMMENT '来源：search/推荐/直接访问',
    browse_time DATETIME     NOT NULL COMMENT '浏览时间',
    create_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_user_time (user_id, browse_time),
    INDEX idx_create_time (create_time),
    INDEX idx_spu_id (spu_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='用户浏览历史表';
```

---

## 8. 商品中心表设计

### 8.1 SPU 表 (spu)

```sql
-- 分片：4 库 × 32 表，分片键 spu_id
CREATE TABLE spu_${tb_idx} (
    spu_id           BIGINT        NOT NULL COMMENT 'SPU ID（雪花算法）',
    spu_name         VARCHAR(256)  NOT NULL COMMENT '商品名称',
    subtitle         VARCHAR(512)  DEFAULT NULL COMMENT '副标题',
    category_id      BIGINT        NOT NULL COMMENT '三级类目ID',
    brand_id         BIGINT        DEFAULT NULL COMMENT '品牌ID',
    main_image       VARCHAR(256)  NOT NULL COMMENT '主图URL',
    images           JSON          DEFAULT NULL COMMENT '商品轮播图列表（JSON 数组）',
    video_url        VARCHAR(256)  DEFAULT NULL COMMENT '商品视频URL',
    description      LONGTEXT      COMMENT '商品详细描述（富文本HTML）',
    service_guarantee VARCHAR(512) DEFAULT NULL COMMENT '服务承诺（JSON数组：正品保障/7天退换等）',
    spu_status       TINYINT       DEFAULT 0 COMMENT '状态：0草稿/1待审核/2审核通过/3已上架/4已下架/5审核驳回',
    audit_reason     VARCHAR(512)  DEFAULT NULL COMMENT '审核驳回原因',
    sale_count       INT           DEFAULT 0 COMMENT '累计销量',
    review_count     INT           DEFAULT 0 COMMENT '累计评价数',
    avg_rating       DECIMAL(2,1)  DEFAULT 0.0 COMMENT '平均评分',
    is_new           TINYINT       DEFAULT 0 COMMENT '是否新品',
    is_hot           TINYINT       DEFAULT 0 COMMENT '是否热销',
    is_recommend     TINYINT       DEFAULT 0 COMMENT '是否推荐',
    is_deleted       TINYINT       DEFAULT 0 COMMENT '逻辑删除',
    create_time      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (spu_id),
    INDEX idx_category_id (category_id),
    INDEX idx_brand_id (brand_id),
    INDEX idx_spu_status (spu_status),
    INDEX idx_create_time (create_time),
    INDEX idx_sale_count (sale_count),
    INDEX idx_recommend (is_recommend, spu_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='商品SPU表';
```

### 8.2 SKU 表 (sku)

```sql
-- 分片：同 spu 库（spu_id 分片，保证 SKU 和 SPU 在同一库）
CREATE TABLE sku_${tb_idx} (
    sku_id         BIGINT        NOT NULL COMMENT 'SKU ID（雪花算法）',
    spu_id         BIGINT        NOT NULL COMMENT '关联SPU ID',
    sku_code       VARCHAR(64)   NOT NULL COMMENT 'SKU编码（商家自定义）',
    sku_name       VARCHAR(256)  DEFAULT NULL COMMENT 'SKU名称（如"iPhone 15 Pro Max 钛金属原色 256GB"）',
    sku_image      VARCHAR(256)  DEFAULT NULL COMMENT 'SKU 图',
    sale_price     DECIMAL(12,2) NOT NULL COMMENT '售价',
    market_price   DECIMAL(12,2) DEFAULT NULL COMMENT '划线价（市场价）',
    cost_price     DECIMAL(12,2) DEFAULT NULL COMMENT '成本价',
    attrs          JSON          NOT NULL COMMENT '销售属性组合（JSON：{"颜色":"钛金属原色","容量":"256GB"}）',
    weight         DECIMAL(10,2) DEFAULT 0.00 COMMENT '重量（kg）',
    volume         DECIMAL(10,2) DEFAULT 0.00 COMMENT '体积（m³）',
    is_deleted     TINYINT       DEFAULT 0 COMMENT '逻辑删除',
    create_time    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (sku_id),
    UNIQUE KEY uk_sku_code (sku_code),
    INDEX idx_spu_id (spu_id),
    INDEX idx_sale_price (sale_price)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='商品SKU表';
```

### 8.3 分类表 (category)

```sql
-- 分类数据量小，使用广播表（每个分片都存全量）
CREATE TABLE category_broadcast (
    category_id   BIGINT       NOT NULL AUTO_INCREMENT COMMENT '分类ID',
    category_name VARCHAR(64)  NOT NULL COMMENT '分类名称',
    parent_id     BIGINT       DEFAULT 0 COMMENT '父分类ID（0=顶级）',
    level         TINYINT      NOT NULL COMMENT '层级：1一级/2二级/3三级',
    sort_order    INT          DEFAULT 0 COMMENT '排序值（越小越前）',
    icon_url      VARCHAR(256) DEFAULT NULL COMMENT '分类图标',
    banner_url    VARCHAR(256) DEFAULT NULL COMMENT '分类Banner',
    is_show       TINYINT      DEFAULT 1 COMMENT '是否显示',
    create_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (category_id),
    INDEX idx_parent_id (parent_id),
    INDEX idx_sort_order (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='商品分类表（广播表）';
```

### 8.4 品牌表 (brand)

```sql
-- 品牌数据量小（通常数千个），使用广播表
CREATE TABLE brand_broadcast (
    brand_id     BIGINT       NOT NULL AUTO_INCREMENT COMMENT '品牌ID',
    brand_name   VARCHAR(128) NOT NULL COMMENT '品牌名称',
    brand_logo   VARCHAR(256) DEFAULT NULL COMMENT '品牌Logo',
    brand_desc   TEXT         COMMENT '品牌描述',
    country      VARCHAR(64)  DEFAULT NULL COMMENT '品牌产地',
    sort_order   INT          DEFAULT 0 COMMENT '排序',
    is_show      TINYINT      DEFAULT 1 COMMENT '是否显示',
    create_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (brand_id),
    INDEX idx_sort_order (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='品牌表（广播表）';
```

### 8.5 商品属性模板表 (product_attr)

```sql
-- 属性模板表，按分类绑定
CREATE TABLE product_attr (
    attr_id       BIGINT       NOT NULL AUTO_INCREMENT COMMENT '属性ID',
    category_id   BIGINT       NOT NULL COMMENT '关联分类ID',
    attr_name     VARCHAR(64)  NOT NULL COMMENT '属性名称（如"电池容量"）',
    input_type    TINYINT      DEFAULT 1 COMMENT '录入方式：1手动/2从列表选择',
    attr_values   JSON         DEFAULT NULL COMMENT '可选值列表（JSON数组）',
    sort_order    INT          DEFAULT 0 COMMENT '排序',
    is_required   TINYINT      DEFAULT 0 COMMENT '是否必填',
    attr_type     TINYINT      DEFAULT 1 COMMENT '1销售属性/2非销售属性',
    create_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (attr_id),
    INDEX idx_category_id (category_id),
    INDEX idx_attr_type (attr_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='商品属性模板表';
```

### 8.6 商品SKU价格历史表 (sku_price_history)

```sql
-- 记录 SKU 价格变动历史，用于数据分析
CREATE TABLE sku_price_history_${tb_idx} (
    id            BIGINT        NOT NULL AUTO_INCREMENT,
    sku_id        BIGINT        NOT NULL COMMENT 'SKU ID',
    old_price     DECIMAL(12,2) NOT NULL COMMENT '原价',
    new_price     DECIMAL(12,2) NOT NULL COMMENT '新价',
    change_type   TINYINT       DEFAULT 1 COMMENT '变动类型：1调价/2促销/3秒杀',
    operator      VARCHAR(64)   DEFAULT NULL COMMENT '操作人',
    create_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_sku_id (sku_id),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='SKU价格历史表';
```

---

## 9. 订单中心表设计

### 9.1 订单表 (order)

```sql
-- 分片：8 库 × 64 表，分片键 user_id
-- 这是整个系统数据量最大的表，设计需极为谨慎
CREATE TABLE order_${db_idx}_${tb_idx} (
    order_no          VARCHAR(32)   NOT NULL COMMENT '订单号（雪花算法+业务编码）',
    user_id           BIGINT        NOT NULL COMMENT '买家用户ID',
    seller_id         BIGINT        DEFAULT NULL COMMENT '卖家ID（平台模式）',
    order_status      TINYINT       NOT NULL DEFAULT 0 COMMENT '订单状态：0待支付/10已支付/20已发货/30已收货/40已完成/50已取消/60已退款',
    payment_status    TINYINT       DEFAULT 0 COMMENT '支付状态：0未支付/1已支付/2已退款/3部分退款',
    delivery_status   TINYINT       DEFAULT 0 COMMENT '物流状态：0未发货/1已发货/2已签收',
    order_type        TINYINT       DEFAULT 1 COMMENT '订单类型：1普通/2秒杀/3拼团/4砍价',
    source            VARCHAR(32)   DEFAULT 'APP' COMMENT '来源：APP/H5/PC/MINI_PROGRAM',
    product_amount    DECIMAL(12,2) NOT NULL COMMENT '商品总金额',
    discount_amount   DECIMAL(12,2) DEFAULT 0.00 COMMENT '优惠金额',
    freight_amount    DECIMAL(12,2) DEFAULT 0.00 COMMENT '运费金额',
    pay_amount        DECIMAL(12,2) NOT NULL COMMENT '实付金额',
    coupon_id         BIGINT        DEFAULT NULL COMMENT '使用的优惠券ID',
    coupon_amount     DECIMAL(12,2) DEFAULT 0.00 COMMENT '优惠券减免金额',
    points_deduction  INT           DEFAULT 0 COMMENT '积分抵扣数量',
    invoice_type      TINYINT       DEFAULT 0 COMMENT '发票类型：0不开发票/1电子发票/2纸质发票',
    buyer_remark      VARCHAR(512)  DEFAULT NULL COMMENT '买家备注',
    seller_remark     VARCHAR(512)  DEFAULT NULL COMMENT '卖家备注（仅后台可见）',
    payment_time      DATETIME      DEFAULT NULL COMMENT '支付时间',
    delivery_time     DATETIME      DEFAULT NULL COMMENT '发货时间',
    receive_time      DATETIME      DEFAULT NULL COMMENT '收货时间',
    finish_time       DATETIME      DEFAULT NULL COMMENT '完成时间',
    cancel_time       DATETIME      DEFAULT NULL COMMENT '取消时间',
    cancel_reason     VARCHAR(256)  DEFAULT NULL COMMENT '取消原因',
    auto_confirm_days INT           DEFAULT 15 COMMENT '自动确认收货天数',
    is_archived       TINYINT       DEFAULT 0 COMMENT '是否已归档（冷数据）',
    -- 地址快照（冗余，拒绝JOIN）
    consignee_name    VARCHAR(64)   NOT NULL COMMENT '收货人姓名',
    consignee_phone   VARCHAR(20)   NOT NULL COMMENT '收货人手机号',
    province          VARCHAR(32)   NOT NULL COMMENT '省份',
    city              VARCHAR(32)   NOT NULL COMMENT '城市',
    district          VARCHAR(32)   NOT NULL COMMENT '区县',
    street_address    VARCHAR(256)  NOT NULL COMMENT '详细地址',
    create_time       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (order_no),
    INDEX idx_user_id (user_id),
    INDEX idx_order_status (order_status),
    INDEX idx_create_time (create_time),
    INDEX idx_payment_time (payment_time),
    INDEX idx_user_status (user_id, order_status),
    INDEX idx_user_time (user_id, create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='订单主表';
```

### 9.2 订单明细表 (order_item)

```sql
-- 分片：与 order 同分片策略（保证订单和明细在同一个物理库）
CREATE TABLE order_item_${db_idx}_${tb_idx} (
    item_id       BIGINT        NOT NULL AUTO_INCREMENT COMMENT '明细ID',
    order_no      VARCHAR(32)   NOT NULL COMMENT '订单号',
    user_id       BIGINT        NOT NULL COMMENT '买家ID',
    spu_id        BIGINT        NOT NULL COMMENT 'SPU ID',
    sku_id        BIGINT        NOT NULL COMMENT 'SKU ID',
    -- 商品信息快照（冗余，因为商品信息后续可能变更）
    sku_name      VARCHAR(256)  NOT NULL COMMENT 'SKU名称（快照）',
    sku_image     VARCHAR(256)  DEFAULT NULL COMMENT 'SKU图片（快照）',
    attrs_snapshot JSON         DEFAULT NULL COMMENT '销售属性快照',
    price         DECIMAL(12,2) NOT NULL COMMENT '成交单价',
    quantity      INT           NOT NULL COMMENT '购买数量',
    subtotal      DECIMAL(12,2) NOT NULL COMMENT '小计金额',
    is_evaluated  TINYINT       DEFAULT 0 COMMENT '是否已评价',
    create_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (item_id),
    INDEX idx_order_no (order_no),
    INDEX idx_sku_id (sku_id),
    INDEX idx_user_id (user_id),
    INDEX idx_spu_id (spu_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='订单明细表';
```

### 9.3 订单操作日志表 (order_log)

```sql
-- 记录订单的所有状态变更，用于对账和问题排查
CREATE TABLE order_log_${db_idx}_${tb_idx} (
    log_id       BIGINT        NOT NULL AUTO_INCREMENT,
    order_no     VARCHAR(32)   NOT NULL COMMENT '订单号',
    user_id      BIGINT        NOT NULL COMMENT '操作人ID',
    operator_type TINYINT      DEFAULT 1 COMMENT '操作人类型：1用户/2商家/3系统/4客服',
    action       VARCHAR(64)   NOT NULL COMMENT '操作动作：CREATE/PAY/CANCEL/REFUND等',
    from_status  TINYINT       DEFAULT NULL COMMENT '变更前状态',
    to_status    TINYINT       DEFAULT NULL COMMENT '变更后状态',
    remark       VARCHAR(256)  DEFAULT NULL COMMENT '备注',
    create_time  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (log_id),
    INDEX idx_order_no (order_no),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='订单操作日志表';
```

### 9.4 购物车表 (cart)

```sql
-- 购物车数据量：最多 200 件/用户，总量可控
-- 不分区，但在 Redis 中缓存
CREATE TABLE cart_${tb_idx} (
    cart_id      BIGINT    NOT NULL AUTO_INCREMENT COMMENT '购物车ID',
    user_id      BIGINT    NOT NULL COMMENT '用户ID',
    sku_id       BIGINT    NOT NULL COMMENT 'SKU ID',
    quantity     INT       NOT NULL DEFAULT 1 COMMENT '数量',
    checked      TINYINT   DEFAULT 1 COMMENT '是否选中：0否/1是',
    is_deleted   TINYINT   DEFAULT 0 COMMENT '软删除',
    create_time  DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time  DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (cart_id),
    UNIQUE KEY uk_user_sku (user_id, sku_id),
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='购物车表';
```

---

## 10. 库存中心表设计

### 10.1 SKU 库存表 (sku_stock)

```sql
-- 分片：同商品库（spu_id 分片）
-- 库存是极高并发场景，使用乐观锁控制并发
CREATE TABLE sku_stock_${tb_idx} (
    stock_id         BIGINT        NOT NULL AUTO_INCREMENT COMMENT '库存ID',
    sku_id           BIGINT        NOT NULL COMMENT 'SKU ID',
    spu_id           BIGINT        NOT NULL COMMENT 'SPU ID',
    total_stock      INT           NOT NULL DEFAULT 0 COMMENT '总库存',
    locked_stock     INT           NOT NULL DEFAULT 0 COMMENT '预扣库存（已下单未支付）',
    available_stock  INT           NOT NULL DEFAULT 0 COMMENT '可用库存 = 总库存 - 预扣库存',
    safety_stock     INT           DEFAULT 0 COMMENT '安全库存',
    version          INT           NOT NULL DEFAULT 0 COMMENT '乐观锁版本号',
    warehouse_id     BIGINT        DEFAULT NULL COMMENT '仓库ID',
    create_time      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (stock_id),
    UNIQUE KEY uk_sku_id (sku_id),
    INDEX idx_spu_id (spu_id),
    INDEX idx_available (available_stock)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='SKU库存表';
```

### 10.2 库存流水表 (stock_flow)

```sql
-- 每次库存变动记录流水，用于对账和问题追溯
CREATE TABLE stock_flow_${tb_idx} (
    flow_id         BIGINT        NOT NULL AUTO_INCREMENT COMMENT '流水ID',
    sku_id          BIGINT        NOT NULL COMMENT 'SKU ID',
    change_type     TINYINT       NOT NULL COMMENT '变动类型：1下单预扣/2支付确认/3取消释放/4入库/5出库/6人工调整',
    change_quantity INT           NOT NULL COMMENT '变动数量（负数为减少）',
    before_stock    INT           NOT NULL COMMENT '变动前可用库存',
    after_stock     INT           NOT NULL COMMENT '变动后可用库存',
    order_no        VARCHAR(32)   DEFAULT NULL COMMENT '关联订单号',
    operator        VARCHAR(64)   DEFAULT NULL COMMENT '操作人（系统/管理员）',
    remark          VARCHAR(256)  DEFAULT NULL COMMENT '备注',
    create_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (flow_id),
    INDEX idx_sku_id (sku_id),
    INDEX idx_create_time (create_time),
    INDEX idx_order_no (order_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='库存流水表';
```

---

## 11. 营销中心表设计

### 11.1 优惠券表 (coupon)

```sql
-- 分片：2 库 × 16 表，分片键 coupon_id
CREATE TABLE coupon_${tb_idx} (
    coupon_id        BIGINT        NOT NULL AUTO_INCREMENT COMMENT '优惠券ID',
    coupon_name      VARCHAR(128)  NOT NULL COMMENT '优惠券名称',
    coupon_type      TINYINT       NOT NULL COMMENT '类型：1满减券/2折扣券/3无门槛券/4新人券',
    discount_value   DECIMAL(12,2) NOT NULL COMMENT '优惠值（满减免X元/折扣X折）',
    min_order_amount DECIMAL(12,2) DEFAULT 0.00 COMMENT '最低订单金额（满减门槛）',
    total_limit      INT           NOT NULL DEFAULT 0 COMMENT '发放总量（0=不限）',
    per_user_limit   INT           DEFAULT 1 COMMENT '每人限领',
    use_scope        TINYINT       DEFAULT 1 COMMENT '使用范围：1全平台/2指定分类/3指定SPU',
    scope_values     JSON          DEFAULT NULL COMMENT '范围值（分类ID列表/SPU ID列表）',
    valid_start_time DATETIME      NOT NULL COMMENT '有效期开始',
    valid_end_time   DATETIME      NOT NULL COMMENT '有效期结束',
    status           TINYINT       DEFAULT 1 COMMENT '状态：1启用/2停用/3过期',
    create_time      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (coupon_id),
    INDEX idx_coupon_type (coupon_type),
    INDEX idx_valid_time (valid_start_time, valid_end_time),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='优惠券定义表';
```

### 11.2 用户领券表 (user_coupon)

```sql
CREATE TABLE user_coupon_${tb_idx} (
    uc_id        BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键',
    user_id      BIGINT        NOT NULL COMMENT '用户ID',
    coupon_id    BIGINT        NOT NULL COMMENT '优惠券ID',
    use_status   TINYINT       DEFAULT 0 COMMENT '使用状态：0未使用/1已使用/2已过期',
    order_no     VARCHAR(32)   DEFAULT NULL COMMENT '使用订单号',
    use_time     DATETIME      DEFAULT NULL COMMENT '使用时间',
    create_time  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (uc_id),
    INDEX idx_user_id (user_id),
    INDEX idx_coupon_id (coupon_id),
    INDEX idx_use_status (user_id, use_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='用户领券表';
```

### 11.3 秒杀活动表 (seckill_activity)

```sql
-- 秒杀活动独立设计，因为秒杀是最高并发场景
CREATE TABLE seckill_activity_${tb_idx} (
    activity_id           BIGINT       NOT NULL AUTO_INCREMENT COMMENT '活动ID',
    activity_name         VARCHAR(128) NOT NULL COMMENT '活动名称',
    start_time            DATETIME     NOT NULL COMMENT '开始时间',
    end_time              DATETIME     NOT NULL COMMENT '结束时间',
    status                TINYINT      DEFAULT 0 COMMENT '状态：0待开始/1进行中/2已结束/3已取消',
    seckill_strategy      TINYINT      DEFAULT 1 COMMENT '秒杀策略：1先到先得/2排队抽签',
    per_user_limit        INT          DEFAULT 1 COMMENT '每人限购件数',
    create_time           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (activity_id),
    INDEX idx_status (status),
    INDEX idx_start_time (start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='秒杀活动表';
```

### 11.4 秒杀商品表 (seckill_product)

```sql
CREATE TABLE seckill_product_${tb_idx} (
    id                  BIGINT        NOT NULL AUTO_INCREMENT,
    activity_id         BIGINT        NOT NULL COMMENT '活动ID',
    sku_id              BIGINT        NOT NULL COMMENT 'SKU ID',
    seckill_price       DECIMAL(12,2) NOT NULL COMMENT '秒杀价',
    seckill_stock       INT           NOT NULL COMMENT '秒杀库存（独立库存）',
    seckill_sold        INT           DEFAULT 0 COMMENT '已售数量',
    -- 秒杀限流配置
    qps_limit           INT           DEFAULT 1000 COMMENT '接口限流QPS',
    create_time         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_activity_sku (activity_id, sku_id),
    INDEX idx_activity_id (activity_id),
    INDEX idx_sku_id (sku_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='秒杀商品表';
```

---

## 12. 评价中心表设计

### 12.1 评价表 (review)

```sql
-- 分片：4 库 × 32 表，分片键 product_id（查询评价时按商品维度）
CREATE TABLE review_${tb_idx} (
    review_id    BIGINT        NOT NULL AUTO_INCREMENT COMMENT '评价ID',
    order_no     VARCHAR(32)   NOT NULL COMMENT '关联订单号',
    user_id      BIGINT        NOT NULL COMMENT '用户ID',
    spu_id       BIGINT        NOT NULL COMMENT 'SPU ID',
    sku_id       BIGINT        NOT NULL COMMENT 'SKU ID',
    rating       TINYINT       NOT NULL COMMENT '评分（1~5星）',
    content      VARCHAR(2000) DEFAULT NULL COMMENT '评价内容',
    tags         JSON          DEFAULT NULL COMMENT '评价标签（["质量很好","物流快"]）',
    review_type  TINYINT       DEFAULT 0 COMMENT '评价类型：0好评(4-5星)/1中评(3星)/2差评(1-2星)',
    is_anonymous TINYINT       DEFAULT 0 COMMENT '是否匿名',
    is_top       TINYINT       DEFAULT 0 COMMENT '是否置顶',
    is_archived  TINYINT       DEFAULT 0 COMMENT '是否归档（冷数据）',
    create_time  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (review_id),
    INDEX idx_spu_id (spu_id),
    INDEX idx_user_id (user_id),
    INDEX idx_order_no (order_no),
    INDEX idx_rating (spu_id, rating),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='评价表';
```

### 12.2 评价图片表 (review_image)

```sql
CREATE TABLE review_image_${tb_idx} (
    image_id    BIGINT       NOT NULL AUTO_INCREMENT,
    review_id   BIGINT       NOT NULL COMMENT '评价ID',
    image_url   VARCHAR(256) NOT NULL COMMENT '图片URL',
    image_order INT          DEFAULT 0 COMMENT '图片排序',
    create_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (image_id),
    INDEX idx_review_id (review_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='评价图片表';
```

### 12.3 商家回复表 (review_reply)

```sql
CREATE TABLE review_reply_${tb_idx} (
    reply_id    BIGINT        NOT NULL AUTO_INCREMENT,
    review_id   BIGINT        NOT NULL COMMENT '关联评价ID',
    reply_type  TINYINT       DEFAULT 1 COMMENT '类型：1商家回复/2用户追评',
    content     VARCHAR(2000) NOT NULL COMMENT '回复内容',
    user_id     BIGINT        DEFAULT NULL COMMENT '回复人ID',
    create_time DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (reply_id),
    INDEX idx_review_id (review_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='评价回复表';
```

---

## 13. 物流/支付表设计

### 13.1 支付记录表 (order_payment)

```sql
-- 分片：同订单库（按 user_id 分片）
CREATE TABLE order_payment_${db_idx}_${tb_idx} (
    payment_id      BIGINT        NOT NULL AUTO_INCREMENT,
    order_no        VARCHAR(32)   NOT NULL COMMENT '订单号',
    user_id         BIGINT        NOT NULL COMMENT '用户ID',
    pay_amount      DECIMAL(12,2) NOT NULL COMMENT '支付金额',
    pay_type        TINYINT       NOT NULL COMMENT '支付方式：1微信/2支付宝/3余额',
    pay_status      TINYINT       DEFAULT 0 COMMENT '状态：0待支付/1支付成功/2支付失败/3已退款',
    trade_no        VARCHAR(128)  DEFAULT NULL COMMENT '第三方支付流水号',
    notify_status   TINYINT       DEFAULT 0 COMMENT '回调处理状态：0待处理/1处理成功/2处理失败',
    notify_count    TINYINT       DEFAULT 0 COMMENT '回调通知次数',
    bank_type       VARCHAR(32)   DEFAULT NULL COMMENT '银行类型（微信返回）',
    pay_time        DATETIME      DEFAULT NULL COMMENT '支付时间',
    create_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (payment_id),
    UNIQUE KEY uk_trade_no (trade_no),
    INDEX idx_order_no (order_no),
    INDEX idx_user_id (user_id),
    INDEX idx_pay_status (pay_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='支付记录表';
```

### 13.2 退款表 (refund)

```sql
CREATE TABLE refund_${db_idx}_${tb_idx} (
    refund_id       BIGINT        NOT NULL AUTO_INCREMENT,
    order_no        VARCHAR(32)   NOT NULL COMMENT '原订单号',
    order_item_id   BIGINT        DEFAULT NULL COMMENT '退款的明细ID（部分退款时）',
    user_id         BIGINT        NOT NULL COMMENT '用户ID',
    refund_amount   DECIMAL(12,2) NOT NULL COMMENT '退款金额',
    refund_type     TINYINT       NOT NULL COMMENT '退款类型：1仅退款/2退货退款',
    refund_reason   VARCHAR(256)  NOT NULL COMMENT '退款原因',
    refund_status   TINYINT       DEFAULT 0 COMMENT '状态：0待审核/1同意/2驳回/3退款中/4已完成/5失败',
    audit_remark    VARCHAR(256)  DEFAULT NULL COMMENT '审核意见',
    express_company VARCHAR(64)   DEFAULT NULL COMMENT '退货快递公司',
    express_no      VARCHAR(64)   DEFAULT NULL COMMENT '退货快递单号',
    audit_time      DATETIME      DEFAULT NULL COMMENT '审核时间',
    finish_time     DATETIME      DEFAULT NULL COMMENT '退款完成时间',
    create_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (refund_id),
    INDEX idx_order_no (order_no),
    INDEX idx_user_id (user_id),
    INDEX idx_refund_status (refund_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='退款表';
```

### 13.3 物流信息表 (order_delivery)

```sql
CREATE TABLE order_delivery_${db_idx}_${tb_idx} (
    delivery_id     BIGINT       NOT NULL AUTO_INCREMENT,
    order_no        VARCHAR(32)  NOT NULL COMMENT '订单号',
    express_company VARCHAR(64)  NOT NULL COMMENT '快递公司名称',
    express_no      VARCHAR(64)  NOT NULL COMMENT '快递单号',
    delivery_status TINYINT      DEFAULT 0 COMMENT '状态：0待揽收/1运输中/2派件中/3已签收/4退回',
    estimated_arrival DATETIME   DEFAULT NULL COMMENT '预计到达时间',
    sign_time       DATETIME     DEFAULT NULL COMMENT '签收时间',
    create_time     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (delivery_id),
    INDEX idx_order_no (order_no),
    INDEX idx_express_no (express_no),
    INDEX idx_delivery_status (delivery_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='发货物流表';
```

---

## 14. 索引设计策略

### 14.1 索引设计原则

| 原则 | 说明 |
|------|------|
| **覆盖索引优先** | 尽可能让查询走覆盖索引（Using index），避免回表 |
| **最左前缀** | 联合索引遵守最左前缀匹配原则 |
| **区分度优先** | 选择性高的列在前（如 user_id > order_status） |
| **避免冗余索引** | (a,b) 和 (a) 是一个索引就够了 |
| **索引下推** | MySQL 5.6+ 的 ICP 特性可减少回表次数 |
| **控制索引数量** | 单表索引不超过 8 个，过多影响写入性能 |

### 14.2 核心索引详解

| 表 | 索引 | 类型 | 解决查询场景 |
|----|------|------|-------------|
| order | (user_id, create_time) | 联合索引 | "我的订单"列表按时间排序 |
| order | (order_status, create_time) | 联合索引 | 运营后台按状态筛选 |
| order | (payment_time) | 单列索引 | 支付对账查询 |
| order_item | (order_no) | 单列索引 | 订单详情关联查询 |
| spu | (category_id, spu_status) | 联合索引 | 按分类查看上架商品 |
| spu | (spu_status, sale_count) | 联合索引 | 热销排行 |
| sku_stock | (sku_id) | 唯一索引 | 库存查询（唯一） |

### 14.3 索引优化示例

```sql
-- ❌ 低效写法：SELECT * 导致回表 + filesort
SELECT * FROM order_${tb_idx} WHERE user_id = ? ORDER BY create_time DESC;

-- ✅ 高效写法：覆盖索引查ID，再回表
SELECT order_no FROM order_${tb_idx}
WHERE user_id = ? ORDER BY create_time DESC LIMIT 20;

-- 或者建立覆盖索引
-- INDEX idx_user_time (user_id, create_time, order_no, order_status)
-- 这样查询可以直接走索引，不需要回表
```

---

## 15. 缓存设计

### 15.1 多级缓存架构

```
┌──────────────────────────────────────────────────────┐
│                  客户端缓存（浏览器）                    │
│           强缓存 Cache-Control / 协商缓存 ETag          │
└──────────────────────┬───────────────────────────────┘
                       │
┌──────────────────────▼───────────────────────────────┐
│                CDN 缓存（静态资源）                     │
│          图片/JS/CSS/HTML → TTL 1h ~ 7d              │
└──────────────────────┬───────────────────────────────┘
                       │
┌──────────────────────▼───────────────────────────────┐
│              Redis 集群缓存（应用层）                    │
│  热数据：商品详情、用户会话、分类列表、热门搜索            │
│  读写 QPS ≥ 100万，单 Key 最大 10MB                   │
└──────────────────────┬───────────────────────────────┘
                       │
┌──────────────────────▼───────────────────────────────┐
│                  本地缓存（Caffeine）                   │
│          菜单/配置数据 TTL 5min ~ 60min                │
└──────────────────────┬───────────────────────────────┘
                       │
┌──────────────────────▼───────────────────────────────┐
│                  MySQL（最终数据源）                    │
└──────────────────────────────────────────────────────┘
```

### 15.2 Redis 缓存清单

| 缓存 Key 模式 | 数据类型 | 过期时间 | 说明 |
|---------------|---------|---------|------|
| `product:spu:{spu_id}` | String(JSON) | 1h | SPU 信息 |
| `product:sku:{sku_id}` | String(JSON) | 1h | SKU 信息 |
| `product:stock:{sku_id}` | String(Int) | 5min | SKU 可用库存 |
| `product:hot:{category_id}` | ZSet | 5min | 热销商品排行榜 |
| `category:tree` | String(JSON) | 1h | 分类树（全量） |
| `session:token:{token}` | String(JSON) | 2h | 用户 Session |
| `cart:user:{user_id}` | Hash | 7d | 购物车数据 |
| `seckill:stock:{sku_id}` | String(Int) | 活动期 | 秒杀库存 |
| `rate:limiter:{ip}` | String(Atomic) | 1s | 接口限流 |
| `lock:order:{order_no}` | String(Atomic) | 30s | 分布式锁 |

### 15.3 缓存三大难题解决

| 问题 | 现象 | 解决方案 |
|------|------|----------|
| **缓存穿透** | 查询不存在的数据，每次都穿透到 DB | ① 布隆过滤器（Bloom Filter）拦截不存在 Key；② 缓存空值（null，TTL 30s） |
| **缓存击穿** | 热点 Key 过期瞬间，高并发打到 DB | ① 互斥锁（SETNX），只让一个线程去查 DB 重建缓存；② 热点 Key 永不过期（后台异步刷新） |
| **缓存雪崩** | 大量 Key 同一时间过期，DB 被打垮 | ① 过期时间加随机值（基础 TTL ± 随机分钟）；② 集群部署避免单点；③ 本地缓存兜底 |

### 15.4 缓存更新策略

```
读操作：
  GET Key → 命中 → 直接返回
         → 未命中 → 查 DB → 写入 Redis → 返回

写操作（MySQL → Redis 异步同步）：
  更新 MySQL (主库)
      │
      ├── 方案 A：旁路缓存（Cache Aside）
      │    删除 Redis Key → 下次读取时重建缓存
      │
      ├── 方案 B：Canal 监听 Binlog
      │    MySQL Binlog → Canal → MQ → 消费 → 更新 Redis
      │
      └── 方案 C：双写（不推荐，一致性难保证）
            更新 MySQL → 立即更新 Redis（先删后改）
```

---

## 16. 高并发应对方案

### 16.1 各场景并发应对矩阵

| 场景 | 并发等级 | 主要瓶颈 | 应对措施 |
|------|---------|---------|---------|
| 商品浏览 | 高 | DB 读 + 带宽 | Redis 缓存 + CDN + 读写分离 |
| 商品搜索 | 高 | MySQL LIKE | **Elasticsearch** 替代 LIKE |
| 加入购物车 | 中 | DB 写 | 异步写入 + Redis 缓冲 |
| 提交订单 | 高 | DB 写 + 一致性 | MQ 削峰 + 异步处理 + 最终一致 |
| 支付回调 | 高 | DB 写 + 幂等 | Redis 锁 + 幂等表 + 异步对账 |
| 秒杀 | **极高** | 库存扣减 | **独立架构：Nginx限流 → MQ → Redis LUA** |
| 后台查询 | 低 | 大表 JOIN | ES + ClickHouse 异构查询 |

### 16.2 秒杀架构（最高并发场景）

```
                    ┌──────────────┐
                    │   用户点击抢购  │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  Nginx 限流   │  ← 单 IP 每秒 N 次，超出返回"请求太频繁"
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ Sentinel 限流  │  ← 秒杀接口独立限流池，总 QPS 阈值
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ 请求入 MQ 队列  │  ← RocketMQ 削峰填谷，排队消费
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ Redis LUA 校验  │  ← 原子操作：校验库存 + 校验限购 + 扣库存
                    │ 库存 + 限购     │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ 发送结果通知    │  ← 成功 → 异步创建订单；失败 → 释放
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  前端轮询/      │  ← WebSocket 或 HTTP 轮询获取结果
                    │  WebSocket     │
                    └──────────────┘
```

### 16.3 扣库存的原子性保障

```lua
-- Redis LUA 脚本：保证秒杀扣库存的原子性
-- KEYS[1] = seckill:stock:{sku_id}       秒杀库存
-- KEYS[2] = seckill:user:{activity_id}   用户购买记录
-- ARGV[1] = user_id
-- ARGV[2] = limit_count                 每人限购数量

local stock = tonumber(redis.call('GET', KEYS[1]))
if not stock or stock <= 0 then
    return -1  -- 库存不足
end

local bought = tonumber(redis.call('GET', KEYS[2] .. ':' .. ARGV[1]))
if bought and bought >= tonumber(ARGV[2]) then
    return -2  -- 已超过限购数量
end

redis.call('DECR', KEYS[1])
redis.call('INCR', KEYS[2] .. ':' .. ARGV[1])
return 1  -- 成功
```

### 16.4 消息队列削峰场景

| 场景 | MQ 主题 | 生产者 | 消费者 | 削峰作用 |
|------|---------|--------|--------|---------|
| 创建订单 | `order_create_topic` | 订单服务 | 订单处理服务 | 比直接写入 DB QPS 提升 10~50 倍 |
| 库存扣减 | `stock_deduct_topic` | 订单服务 | 库存服务 | 异步扣减，避免事务过长 |
| 支付回调 | `payment_callback_topic` | 支付网关 | 订单服务 | 异步处理回调，避免重复通知积压 |
| 数据同步 ES | `data_sync_topic` | 数据变更服务 | ES 同步服务 | 异步同步，解耦 |
| 数据迁移冷库 | `data_archive_topic` | 归档服务 | 归档消费者 | 批量处理，避免影响主库 |

---

## 17. 数据迁移与归档方案

### 17.1 冷热数据迁移流程

```
每日 02:00 定时任务触发
        │
        ▼
   查询待迁移数据（批次处理，每次 1000 条）
        │
        ▼
   写入 ClickHouse（批量 INSERT）
        │
        ▼
   标记 MySQL 数据 is_archived = 1
        │
        ▼
   等待 30 天保留期后 DELETE 物理删除
```

### 17.2 数据一致性校验

- **每日对账**：MySQL COUNT(*) vs ClickHouse COUNT(*) 比对
- **抽样校验**：每日随机抽取 1000 条数据逐字段对比
- **异常处理**：对账不一致时触发告警 + 自动补偿迁移

### 17.3 历史数据清理

| 清理内容 | 清理策略 | 保留周期 |
|----------|---------|---------|
| 订单冷数据 | 迁移至 ClickHouse 后标记归档 | MySQL 保留 30 天后删除 |
| 操作日志 | 按月份滚动删除 | 保留 3 个月 |
| 浏览历史 | 只保留最近 100 条/用户 | 每月清理一次 |
| 消息通知 | 已读 30 天后清理 | 保留 30 天 |
| 购物车 | 未操作超 7 天清理 | 保留 7 天 |

---

## 18. 附录：ER 图说明

### 18.1 核心 ER 关系

```
┌──────────┐    1:N    ┌───────────┐
│   User   │───────────│  Address  │
└────┬─────┘           └───────────┘
     │
     │ 1:N
     │
     ▼
┌──────────┐    1:N    ┌──────────────┐     N:1    ┌──────────┐
│  Order   │───────────│  OrderItem   │───────────│   SKU    │
└────┬─────┘           └──────────────┘           └────┬─────┘
     │                                                   │
     │ 1:1                                               │ N:1
     ▼                                                   │
┌──────────┐           ┌──────────────┐                  │
│ Payment  │           │  StockFlow   │──────────────────┘
└──────────┘           └──────────────┘
                              │
┌──────────┐    1:N    ┌──────┴──────┐    1:N    ┌───────────┐
│   SPU    │───────────│   Review    │───────────│ ReviewImg │
└────┬─────┘           └─────────────┘           └───────────┘
     │
     │ N:1
     │
┌────▼─────┐
│ Category │
└──────────┘
```

> 完整 ER 图可以使用 `drawio-skill-main` 技能生成可视化图表。

---

> **文档结束**  
> 本文档涵盖了购物系统的完整数据库设计，包括分库分表策略、冷热分离方案、各模块表结构、索引设计、缓存策略和高并发应对方案。  
> 如需深入理解每个设计决策的原因，请参考 [设计原理解析文档](./design-philosophy.md)。
