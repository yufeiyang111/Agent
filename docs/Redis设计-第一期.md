# 海量数据电商购物平台 — Redis 缓存数据库设计 (第一期)

> 文档版本：v1.0  
> 技术栈：Redis 7.x Cluster + Sentinel  
> 部署规模：6 节点 Cluster (3 主 + 3 从) × 2 机房

---

## 目录

1. [集群架构设计](#1-集群架构设计)
2. [Key 命名规范](#2-key-命名规范)
3. [数据结构设计清单](#3-数据结构设计清单)
4. [缓存策略：Cache Aside Pattern](#4-缓存策略cache-aside-pattern)
5. [高并发场景设计](#5-高并发场景设计)
6. [缓存三大问题及解决方案](#6-缓存三大问题及解决方案)
7. [Redis LUA 脚本](#7-redis-lua-脚本)
8. [运维与监控](#8-运维与监控)

---

## 1. 集群架构设计

### 1.1 物理拓扑

```
┌─────────────────────────────────────────────────────────┐
│                     Redis Cluster (机房A)                  │
├───────────────┬───────────────┬───────────────────────────┤
│   Master-0    │   Master-1    │      Master-2            │
│  slot 0-5460  │ slot 5461-10922│  slot 10923-16383       │
│               │               │                           │
│   Slave-0     │   Slave-1     │      Slave-2             │
└───────────────┴───────────────┴───────────────────────────┘
                            │ (主从同步)
┌───────────────────────────┴───────────────────────────────┐
│                     Redis 哨兵 (机房间)                      │
│            Sentinel × 3 (监控 + 自动故障转移)                │
└───────────────────────────────────────────────────────────┘
```

### 1.2 节点规格

| 项目 | 规格 |
|------|------|
| 实例规格 | 16 核 / 64GB 内存 |
| 每节点内存分配 | maxmemory 48GB (预留 25% 系统开销) |
| 淘汰策略 | `allkeys-lru` (LRU 淘汰最少使用的 Key) |
| 持久化 | RDB(每小时1次) + AOF(everysec) |
| 集群总内存 | 3主 × 48GB = 144GB |
| Slot 分布 | 每主节点 5461 个 slot |

### 1.3 各机房部署

| 机房 | 主节点 | 从节点 | 用途 |
|------|--------|--------|------|
| 机房A | 3 主节点 | 3 从节点 | 主集群(承载 100% 流量) |
| 机房B | 3 从节点 | — | 异地灾备(异步复制, 延迟 < 1s) |

---

## 2. Key 命名规范

### 2.1 命名格式

```
{业务域}:{实体}:{标识符}:{子属性}
```

### 2.2 命名示例

```
product:spu:1734567890123456789           → SPU 详情
product:sku:1734567890123456790           → SKU 详情
product:stock:1734567890123456790         → SKU 库存
product:hot:123                           → 分类热销榜
cart:user:1001                            → 用户购物车
session:token:eyJhbGciOi...               → 用户会话
order:lock:OD2024010110010001             → 订单分布式锁
rate:limit:192.168.1.1:login              → 限流计数器
seckill:stock:1734567890123456790:act123  → 秒杀库存
seckill:user:act123:1001                  → 秒杀用户限购
counter:sku:sold:1734567890123456790      → SKU 已售计数
```

### 2.3 Key 设计原则

| 原则 | 说明 |
|------|------|
| **前缀分组** | 相同业务使用相同前缀，方便监控统计 |
| **避免大 Key** | String 类型 ≤ 10KB，Hash/ZSet 元素数 ≤ 5000 |
| **热 Key 处理** | 高频访问的 Key 加本地缓存(Caffeine)兜底 |
| **过期随机** | TTL = 基础值 + random(0, 10%)，避免集中过期 |
| **Hash Tag** | 需要同 slot 的 Key 用 `{}` 包裹相同部分 |

---

## 3. 数据结构设计清单

### 3.1 用户 Session

| 字段 | 说明 |
|------|------|
| Key | `session:token:{access_token}` |
| 类型 | String (JSON) |
| TTL | 2 小时 (与 JWT access_token 一致) |
| 示例值 | `{"user_id":1001,"username":"user1","level":2,"login_ip":"1.2.3.4","login_time":"2024-01-01 10:00:00"}` |
| 操作 | GET (验证), SET (登录), DEL (登出) |
| QPS | ~50,000 /s |

```json
{
  "user_id": 1001,
  "username": "zhangsan",
  "nickname": "张三",
  "phone": "138****1234",
  "email": "zh***@example.com",
  "level": 2,
  "login_ip": "192.168.1.1",
  "device": "APP_iOS_17.1",
  "login_time": "2024-12-01T10:30:00",
  "expire_at": "2024-12-01T12:30:00"
}
```

### 3.2 Refresh Token

| 字段 | 说明 |
|------|------|
| Key | `refresh:token:{user_id}:{device_id}` |
| 类型 | String (token值) |
| TTL | 7 天 |
| 操作 | GET (刷新), SET (登录), DEL (强制下线) |
| 说明 | 一个用户一个设备只保留一个 refresh_token |

### 3.3 商品 SPU 缓存

| 字段 | 说明 |
|------|------|
| Key | `product:spu:{spu_id}` |
| 类型 | String (JSON) |
| TTL | 1 小时 + random(0, 600)s |
| QPS | ~100,000 /s (首页/列表页/详情页都命中) |

```json
{
  "spu_id": 1734567890123456789,
  "spu_name": "iPhone 15 Pro Max",
  "category_id": 1003,
  "brand_id": 2001,
  "main_image": "https://cdn.example.com/img/001.jpg",
  "min_price": 8999.00,
  "max_price": 11999.00,
  "sale_count": 123456,
  "review_count": 8888,
  "avg_rating": 4.8,
  "is_new": 1,
  "is_hot": 1,
  "spu_status": 3,
  "service_guarantee": ["正品保障", "7天退换", "全国联保"]
}
```

### 3.4 商品 SKU 缓存

| 字段 | 说明 |
|------|------|
| Key | `product:sku:{sku_id}` |
| 类型 | String (JSON) |
| TTL | 1 小时 + random(0, 600)s |
| 说明 | 包含价格、库存、属性等详情页必需信息 |

```json
{
  "sku_id": 1734567890123456790,
  "spu_id": 1734567890123456789,
  "sku_name": "iPhone 15 Pro Max 钛金属原色 256GB",
  "sku_image": "https://cdn.example.com/img/001_sku1.jpg",
  "sale_price": 8999.00,
  "market_price": 9999.00,
  "attrs": {"颜色": "钛金属原色", "容量": "256GB"},
  "available_stock": 500,
  "is_on_sale": true
}
```

### 3.5 SKU 库存缓存 (热 Key)

| 字段 | 说明 |
|------|------|
| Key | `product:stock:{sku_id}` |
| 类型 | String (Integer) |
| TTL | 5 分钟 (短 TTL 保证库存一致性) |
| QPS | ~100,000 /s (高并发扣减场景) |

```
SET product:stock:1734567890123456790 500 EX 300
GET product:stock:1734567890123456790  → "500"
DECR product:stock:1734567890123456790  → 499
```

### 3.6 购物车数据

| 字段 | 说明 |
|------|------|
| Key | `cart:user:{user_id}` |
| 类型 | Hash |
| TTL | 7 天 (无操作自动过期) |
| 说明 | Field = `sku_id:{sku_id}`, Value = JSON |

```
HSET cart:user:1001 sku_id:1734567890123456790 '{"quantity":2,"checked":1,"add_time":"2024-01-01 10:00:00"}'
HGETALL cart:user:1001
HDEL cart:user:1001 sku_id:1734567890123456790
```

### 3.7 分类树缓存

| 字段 | 说明 |
|------|------|
| Key | `category:tree` |
| 类型 | String (JSON, 全量分类树) |
| TTL | 1 小时 |
| 说明 | 所有页面都需要, 本地 Caffeine 缓存兜底 |

### 3.8 品牌列表缓存

| 字段 | 说明 |
|------|------|
| Key | `brand:list` |
| 类型 | String (JSON, 全量品牌列表) |
| TTL | 1 小时 |

### 3.9 热销商品排行

| 字段 | 说明 |
|------|------|
| Key | `product:hot:{category_id}` |
| 类型 | Sorted Set |
| TTL | 5 分钟 (实时更新) |
| Member | spu_id |
| Score | sale_count (销量) / 综合热度分 |

```
ZADD product:hot:1003 123456 1734567890123456789 88888 1734567890123456800
ZREVRANGE product:hot:1003 0 9 WITHSCORES  → Top 10
```

### 3.10 SKU 已售计数

| 字段 | 说明 |
|------|------|
| Key | `counter:sku:sold:{sku_id}` |
| 类型 | String (Integer) |
| TTL | 永久 (定期同步到 MySQL) |
| 说明 | 高并发计数器, 每 5 分钟批量同步 MySQL |

```
INCRBY counter:sku:sold:1734567890123456790 1
```

### 3.11 商品搜索热词

| 字段 | 说明 |
|------|------|
| Key | `search:hot` |
| 类型 | Sorted Set |
| TTL | 1 小时 |
| Member | 搜索关键词 |
| Score | 搜索次数 (可加时间衰减) |

```
ZADD search:hot 5000 "iPhone 15" 3000 "羽绒服" 2500 "茅台"
ZREVRANGE search:hot 0 9 WITHSCORES  → 热词 Top 10
```

### 3.12 用户搜索历史

| 字段 | 说明 |
|------|------|
| Key | `search:history:{user_id}` |
| 类型 | List (左进, 去重, 最多 20 条) |
| TTL | 30 天 |

```
LPUSH search:history:1001 "iPhone 15"
LREM search:history:1001 0 "iPhone 15"  → 去重
LPUSH search:history:1001 "iPhone 15"
LTRIM search:history:1001 0 19         → 只保留最近 20 条
LRANGE search:history:1001 0 -1         → 获取全部
```

### 3.13 浏览历史 (Redis)

| 字段 | 说明 |
|------|------|
| Key | `browse:history:{user_id}` |
| 类型 | Sorted Set |
| TTL | 7 天 |
| Member | spu_id |
| Score | 浏览时间戳 |
| 说明 | 快速去重 + 时间排序, 异步持久化到 MongoDB |

### 3.14 秒杀库存

| 字段 | 说明 |
|------|------|
| Key | `seckill:stock:{activity_id}:{sku_id}` |
| 类型 | String (Integer) |
| TTL | 活动结束时间 - now + 1h (自动清理) |
| 说明 | 秒杀核心 Key, 原子扣减用 LUA 脚本 |

### 3.15 秒杀用户限购记录

| 字段 | 说明 |
|------|------|
| Key | `seckill:user:{activity_id}:{user_id}` |
| 类型 | String (Integer: 已购买数量) |
| TTL | 活动结束时间 - now + 1h |

### 3.16 已秒杀成功的用户集合 (防黄牛)

| 字段 | 说明 |
|------|------|
| Key | `seckill:winner:{activity_id}` |
| 类型 | Set |
| TTL | 活动结束后 24h |
| 说明 | 布隆过滤器辅助, 快速判断用户是否已参与秒杀 |

### 3.17 接口限流计数器

| 字段 | 说明 |
|------|------|
| Key | `rate:limit:{ip}:{api}` |
| 类型 | String (Integer, 原子自增) |
| TTL | 1 秒 (滑动窗口) |
| 实现 | `INCR` + `EXPIRE` → 超过阈值拒绝 |

```
-- 令牌桶算法: 每秒每 IP 最多 5 次请求
local count = redis.call('INCR', KEYS[1])
if count == 1 then
    redis.call('EXPIRE', KEYS[1], ARGV[1])
end
if count > tonumber(ARGV[2]) then
    return 0   -- 限流
end
return 1       -- 通过
```

### 3.18 短信验证码

| 字段 | 说明 |
|------|------|
| Key | `sms:code:{biz_type}:{phone}` |
| 类型 | String (6位数字) |
| TTL | 5 分钟 |

```
SET sms:code:register:13800138000 123456 EX 300
```

### 3.19 短信发送频率限制

| 字段 | 说明 |
|------|------|
| Key | `sms:limit:{phone}` |
| 类型 | String (Integer) |
| TTL | 60 秒 (两次发送间隔 ≥ 60s) |

### 3.20 图形验证码

| 字段 | 说明 |
|------|------|
| Key | `captcha:{captcha_id}` |
| 类型 | String (4位字母数字) |
| TTL | 2 分钟 |
| 说明 | 注册/密码错误超过3次时触发校验 |

### 3.21 分布式锁 (通用)

| 字段 | 说明 |
|------|------|
| Key | `lock:{domain}:{resource_id}` |
| 类型 | String (UUID 作为持有者标识) |
| TTL | 30 秒 (防止死锁) |

```
-- 加锁
SET lock:order:OD2024010110010001 {uuid} NX EX 30

-- 解锁 (LUA: 原子判断 + 删除)
if redis.call('GET', KEYS[1]) == ARGV[1] then
    return redis.call('DEL', KEYS[1])
else
    return 0
end
```

### 3.22 已上架商品 Bitmap (布隆过滤器辅助)

| 字段 | 说明 |
|------|------|
| Key | `product:online` |
| 类型 | Bitmap |
| 说明 | 快速判断商品是否存在, 防止缓存穿透 |
| offset | spu_id 取模后映射 |
| 实现 | 布隆过滤器 (Redisson / Guava BloomFilter) |

### 3.23 在线用户统计

| 字段 | 说明 |
|------|------|
| Key | `online:users:{timestamp_5min}` |
| 类型 | HyperLogLog |
| TTL | 10 分钟 |
| 说明 | UV 去重统计, 误差率 0.81% |

```
PFADD online:users:1701403200 1001 1002 1003 ...
PFCOUNT online:users:1701403200  → 在线用户数
```

### 3.24 每日活跃用户统计

| 字段 | 说明 |
|------|------|
| Key | `dau:{date}` |
| 类型 | Bitmap (按 user_id offset) |
| TTL | 30 天 |

```
SETBIT dau:20241201 {user_id} 1
BITCOUNT dau:20241201  → 日活用户数
```

### 3.25 消息队列 (Redis Streams / 备用方案)

| 字段 | 说明 |
|------|------|
| Key | `mq:order_create` |
| 类型 | Stream (Redis 5.0+) |
| 说明 | RocketMQ 的轻量备选, 用于非关键异步任务 |

```
XADD mq:order_create * order_no OD2024010110010001 user_id 1001
XREADGROUP GROUP consumer_group consumer_1 COUNT 10 STREAMS mq:order_create >
```

### 3.26 分库分表路由缓存

| 字段 | 说明 |
|------|------|
| Key | `shard:user:{user_id}` |
| 类型 | String |
| TTL | 永久 (插入时设置) |
| 说明 | 缓存 user_id 对应的 db_idx + tb_idx, 避免每次计算 |

---

## 4. 缓存策略：Cache Aside Pattern

### 4.1 写入流程

```
业务层
  │
  ├─ 1. 更新 MySQL (主库)
  │
  └─ 2. 删除 Redis 缓存
        (不是更新! 避免并发问题)
```

### 4.2 读取流程

```
业务层
  │
  ├─ 1. 查询 Redis
  │     ├─ 命中 → 直接返回
  │     └─ 未命中 ↓
  │
  ├─ 2. 查询 MySQL
  │     └─ 获取锁(setnx) → 查 DB → 写 Redis → 释放锁
  │
  └─ 3. 返回数据
```

### 4.3 缓存更新时机

| 操作 | 更新策略 |
|------|----------|
| 商品信息修改 | 删除 `product:spu:{id}` + `product:sku:{id}` |
| 商品价格修改 | 删除 `product:sku:{id}` (下次读取重建) |
| 库存扣减 | 不删缓存, 直接 `DECR` `product:stock:{id}` |
| 商品上下架 | 删除相关 SPU + SKU 缓存 |
| 用户信息变更 | 删除 `session:token:*` (强制重新登录获取) |
| 分类变更 | 删除 `category:tree` |

---

## 5. 高并发场景设计

### 5.1 秒杀库存扣减 (LUA 原子脚本)

```
┌─────────────────────────────────────────────────┐
│              用户发起秒杀请求                       │
└────────────────────┬────────────────────────────┘
                     │
          ┌──────────▼──────────┐
          │  Nginx 限流 (IP级别)  │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │ Sentinel 限流 (接口)  │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │   RocketMQ 削峰      │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │  Redis LUA 原子扣库存 │  ← 核心!
          │  ① 校验库存 > 0      │
          │  ② 校验限购数量       │
          │  ③ DECR 库存         │
          │  ④ INCR 用户已购数    │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │  返回秒杀结果         │
          └─────────────────────┘
```

### 5.2 热 Key 处理方案

| 场景 | 热 Key 示例 | 方案 |
|------|-------------|------|
| 商品详情 | `product:spu:{热门商品}` | 本地 Caffeine 缓存(1min) + Redis 多副本 |
| 秒杀库存 | `seckill:stock:{活动}` | Redis 集群分散 + LUA 原子操作 |
| 分类树 | `category:tree` | Caffeine 本地缓存(5min) + Redis |
| 系统配置 | `system:config:*` | Caffeine 本地缓存(10min), 变更时发 MQ 通知刷新 |

### 5.3 大 Key 处理

| 检查项 | 阈值 | 处理方案 |
|--------|------|----------|
| String > 10KB | 拆分 | 拆为多个小 Key, 如 `product:spu:{id}:basic` + `product:spu:{id}:desc` |
| Hash > 5000 字段 | 拆分 | 按业务拆多个 Hash |
| ZSet > 5000 成员 | 限制 | 只保留 Top N, 其余离线计算 |
| 集合类型 > 10000 | 分桶 | 按 `user_id % 100` 分 100 个桶 |

---

## 6. 缓存三大问题及解决方案

### 6.1 缓存穿透

```
问题: 查询一个一定不存在的 Key, 每次都打到 MySQL
攻击: 恶意查询 `GET product:spu:-1` → 不存在 → 穿透 DB

解决:
  方案一: 布隆过滤器 (Bloom Filter)
    - 启动时加载所有已上架 spu_id 到布隆过滤器
    - 查缓存前先查布隆过滤器 → 不存在直接返回
    - 误判率 < 1%, 误判允许 (走 DB 查到确实为空则缓存 null)

  方案二: 缓存空值
    - SET product:spu:-1 "" EX 30
    - 30 秒内对同一个不存在的查询不穿透 DB
```

### 6.2 缓存击穿

```
问题: 热点 Key 过期瞬间, 大量请求同时打 DB
场景: 热门商品缓存到期, 10000 人同时刷新

解决:
  方案一: 互斥锁 (SETNX)

    data = GET product:spu:hot123
    if data is None:
        if SETNX lock:product:spu:hot123 uuid EX 10:
            data = DB.query(...)
            SET product:spu:hot123 data EX 3600
            DEL lock:product:spu:hot123
        else:
            sleep(50ms)
            data = GET product:spu:hot123   -- 拿重建后的数据

  方案二: 热点 Key 永不过期
    - 逻辑过期: 值中包含 expire_time 字段
    - 读取时判断过期 → 返回旧值 + 异步刷新
```

### 6.3 缓存雪崩

```
问题: 大量 Key 同一时刻过期, DB 被打垮

解决:
  方案一: TTL 加随机值
    EX = 3600 + random(0, 600)  → 分散过期时间

  方案二: 多级缓存
    本地 Caffeine (一级) → Redis Cluster (二级) → MySQL (三级)
    即使 Redis 全挂了, 本地缓存还能扛

  方案三: Redis 高可用
    主从 + 哨兵自动切换, 单节点故障不影响整体
```

---

## 7. Redis LUA 脚本

### 7.1 秒杀扣库存脚本

```lua
-- KEYS[1] = seckill:stock:{activity_id}:{sku_id}    秒杀库存
-- KEYS[2] = seckill:user:{activity_id}:{user_id}     用户已购数
-- ARGV[1] = 限购数量
-- ARGV[2] = 活动结束时间戳(用于设置过期)
-- 返回值: 1=成功, -1=库存不足, -2=已达限购

local stock = tonumber(redis.call('GET', KEYS[1]))
if not stock or stock <= 0 then
    return -1
end

local bought = tonumber(redis.call('GET', KEYS[2]))
if bought and bought >= tonumber(ARGV[1]) then
    return -2
end

redis.call('DECR', KEYS[1])
redis.call('INCR', KEYS[2])
-- 设置过期时间为活动结束后 1 小时
redis.call('EXPIREAT', KEYS[2], tonumber(ARGV[2]))
return 1
```

### 7.2 购物车合并脚本 (登录时调用)

```lua
-- 本地购物车 + 服务端购物车 = 合并 (相同 SKU 取最大数量, 过期时间重置)
-- KEYS[1] = cart:user:{user_id} (服务端购物车 Hash)
-- ARGV[1..N] = "sku_id:xxx" "json_value" "sku_id:yyy" "json_value" ...
-- 返回值: 合并后的购物车条目数

for i = 1, #ARGV, 2 do
    local field = ARGV[i]
    local value = ARGV[i + 1]
    local existing = redis.call('HGET', KEYS[1], field)
    if existing then
        -- 取最大数量
        local exist_qty = tonumber(string.match(existing, '"quantity":(%d+)'))
        local new_qty = tonumber(string.match(value, '"quantity":(%d+)'))
        if new_qty > exist_qty then
            redis.call('HSET', KEYS[1], field, value)
        end
    else
        redis.call('HSET', KEYS[1], field, value)
    end
end
redis.call('EXPIRE', KEYS[1], 604800)  -- 重置 7 天过期
return redis.call('HLEN', KEYS[1])
```

### 7.3 分布式锁解锁脚本

```lua
-- KEYS[1] = lock key
-- ARGV[1] = lock holder uuid
-- 返回: 1=解锁成功, 0=非持有者(锁已被他人获取)

if redis.call('GET', KEYS[1]) == ARGV[1] then
    return redis.call('DEL', KEYS[1])
else
    return 0
end
```

### 7.4 限流令牌桶脚本

```lua
-- KEYS[1] = rate:limit:{ip}:{api}
-- ARGV[1] = 窗口秒数
-- ARGV[2] = 最大请求数
-- 返回: 1=通过, 0=限流

local count = redis.call('INCR', KEYS[1])
if count == 1 then
    redis.call('EXPIRE', KEYS[1], ARGV[1])
end
if count > tonumber(ARGV[2]) then
    return 0
end
return 1
```

### 7.5 积分扣减+用户升级脚本

```lua
-- KEYS[1] = user:points:{user_id}
-- ARGV[1] = 需要扣除的积分(负数)
-- ARGV[2] = 升级阈值(如 10000 分升级)
-- 返回: 扣减后积分值

local current = tonumber(redis.call('GET', KEYS[1])) or 0
local deduct = tonumber(ARGV[1])
local new_points = current + deduct
if new_points < 0 then
    return -1  -- 积分不足
end
redis.call('SET', KEYS[1], new_points)
return new_points
```

---

## 8. 运维与监控

### 8.1 核心监控指标

| 指标 | 目标/阈值 | 报警 |
|------|-----------|------|
| 内存使用率 | < 80% | > 80% 告警, > 90% 紧急 |
| 连接数 | < 10000/节点 | > 8000 告警 |
| 命中率 | > 95% | < 90% 告警(需分析未命中原因) |
| QPS | 设计 < 100,000/节点 | > 80,000 告警 |
| 慢查询 | < 1ms (P99) | > 5ms 告警 |
| 主从延迟 | < 100ms | > 500ms 告警 |
| 热 Key 数量 | < 10 个 | > 20 个告警 |
| 大 Key 数量 | < 5 个 | > 0 告警 |
| 淘汰 Key 速率 | < 100/s | > 1000/s 告警 |

### 8.2 内存容量预估

```
按 1 亿用户、1000 万 SKU 规模估算:

┌──────────────────────┬─────────┬──────────┬──────────┐
│ 数据类型               │ 单条大小  │ 条数       │ 总大小    │
├──────────────────────┼─────────┼──────────┼──────────┤
│ Session Token         │ ~500B   │ 50万(在线) │ 250MB   │
│ SPU 缓存              │ ~1KB    │ 10万(热)   │ 100MB   │
│ SKU 缓存              │ ~500B   │ 50万(热)   │ 250MB   │
│ 库存缓存               │ ~50B    │ 100万(热)  │ 50MB    │
│ 购物车                 │ ~2KB/人  │ 10万(在线) │ 200MB   │
│ 分类/品牌              │ ~100KB  │ 1份        │ 0.1MB   │
│ 热销榜                 │ ~10KB   │ 1000个分类 │ 10MB    │
│ 搜索/浏览历史          │ ~5KB/人  │ 10万(在线) │ 500MB   │
│ 秒杀相关               │ ~100B   │ 1000场     │ 0.1MB   │
│ 限流/验证码            │ ~100B   │ 10万       │ 10MB    │
│ Bitmap/HLL            │ ~10MB   │ 5个        │ 50MB    │
│ 分布式锁               │ ~100B   │ 1万        │ 1MB     │
├──────────────────────┼─────────┼──────────┼──────────┤
│ 合计                   │         │           │ ~1.5GB  │
├──────────────────────┼─────────┼──────────┼──────────┤
│ 碎片/预留 (×3)         │         │           │ ~4.5GB  │
│ 主从复制开销 (×2)       │         │           │ ~9GB    │
│ 集群节点(×3主)          │         │           │ 每主 ~1.5GB │
└──────────────────────┴─────────┴──────────┴──────────┘

结论: 48GB/节点 的内存规格绰绰有余, 主存储瓶颈不在此
```

### 8.3 持久化策略

| 策略 | 配置 | 说明 |
|------|------|------|
| RDB | `save 3600 1` (每小时至少 1 个 key 变更时触发) | 全量快照, 用于灾备恢复 |
| AOF | `appendonly yes`, `appendfsync everysec` | 增量日志, 保证最多丢 1 秒数据 |
| 混合持久化 | Redis 5.0+ `aof-use-rdb-preamble yes` | RDB 文件 + AOF 增量, 恢复快且完整 |

### 8.4 日常运维命令

```bash
# 查看集群状态
redis-cli -c CLUSTER INFO
redis-cli -c CLUSTER NODES

# 查看内存使用
redis-cli -c INFO memory

# 查看慢日志
redis-cli -c SLOWLOG GET 10

# 热 Key 分析
redis-cli -c --hotkeys

# 大 Key 扫描
redis-cli -c --bigkeys

# 查询 Key 数量
redis-cli -c DBSIZE

# 查看 Key 过期情况
redis-cli -c INFO stats | grep expired_keys

# 实时监控
redis-cli -c MONITOR  # 生产慎用(影响性能)
```

---

> **文档结束**  
> Redis 设计需与 MySQL 设计、应用层缓存(本地 Caffeine)配合使用，形成完整的三层缓存架构。  
> 秒杀等高并发场景的核心逻辑由 LUA 脚本保证原子性，RocketMQ 负责削峰填谷。  
> 详细 MySQL 表设计请参考 [第一期-数据库DDL.sql](./第一期-数据库DDL.sql)
