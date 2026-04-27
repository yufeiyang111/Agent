-- ===================== 创建视图 (在 common_db 中) =====================
-- 使用: mysql -u root -p common_db < 09_views.sql

USE common_db;

-- 8.1 商品销售概况视图 (近30天销量排行)
CREATE OR REPLACE VIEW v_product_sales_30d AS
SELECT
    item.spu_id,
    COUNT(DISTINCT item.order_no) AS order_count,
    SUM(item.quantity)            AS sold_quantity,
    SUM(item.subtotal)            AS total_gmv,
    AVG(item.price)               AS avg_price
FROM order_db_0.order_item_0 item
JOIN order_db_0.order_0 ord ON item.order_no = ord.order_no
WHERE ord.order_status IN (10, 20, 30, 40)
  AND ord.create_time >= DATE_SUB(NOW(), INTERVAL 30 DAY)
  AND ord.is_archived = 0
GROUP BY item.spu_id;

-- 8.2 用户订单汇总视图
CREATE OR REPLACE VIEW v_user_order_summary AS
SELECT
    user_id,
    COUNT(order_no)       AS total_orders,
    SUM(pay_amount)       AS total_amount,
    AVG(pay_amount)       AS avg_order_amount,
    MAX(create_time)      AS last_order_time,
    COUNT(CASE WHEN order_status = 40 THEN 1 END) AS finished_orders,
    COUNT(CASE WHEN order_status IN (50, 60) THEN 1 END) AS cancelled_refund_orders
FROM order_db_0.order_0
WHERE is_archived = 0
GROUP BY user_id;

-- 8.3 分类销售统计视图
CREATE OR REPLACE VIEW v_category_sales AS
SELECT
    cat.category_id,
    cat.category_name,
    cat.parent_id,
    cat.level,
    COUNT(DISTINCT spu.spu_id) AS spu_count,
    SUM(spu.sale_count)        AS total_sales,
    AVG(spu.avg_rating)        AS avg_rating
FROM product_db_0.category_broadcast cat
LEFT JOIN product_db_0.spu_0 spu ON cat.category_id = spu.category_id AND spu.is_deleted = 0
WHERE cat.is_show = 1
GROUP BY cat.category_id, cat.category_name, cat.parent_id, cat.level;

-- 8.4 订单待办视图
CREATE OR REPLACE VIEW v_pending_tasks AS
SELECT '待支付' AS task_type, COUNT(order_no) AS task_count FROM order_db_0.order_0 WHERE order_status = 0
UNION ALL
SELECT '待发货', COUNT(order_no) FROM order_db_0.order_0 WHERE order_status = 10
UNION ALL
SELECT '已发货', COUNT(order_no) FROM order_db_0.order_0 WHERE order_status = 20
UNION ALL
SELECT '待审核退款', COUNT(refund_id) FROM order_db_0.refund_0 WHERE refund_status = 0
UNION ALL
SELECT '待审核商品', COUNT(spu_id) FROM product_db_0.spu_0 WHERE spu_status = 1;

-- 8.5 优惠券使用统计视图
CREATE OR REPLACE VIEW v_coupon_usage_stats AS
SELECT
    c.coupon_id,
    c.coupon_name,
    c.coupon_type,
    c.total_limit,
    c.received_count,
    c.used_count,
    ROUND(c.used_count / NULLIF(c.received_count, 0) * 100, 2) AS usage_rate,
    c.status
FROM marketing_db_0.coupon_0 c;

-- 8.6 每日经营数据视图
CREATE OR REPLACE VIEW v_daily_business_metrics AS
SELECT
    DATE(ord.create_time) AS biz_date,
    COUNT(DISTINCT ord.order_no) AS order_count,
    COUNT(DISTINCT ord.user_id) AS buyer_count,
    SUM(ord.product_amount) AS product_amount,
    SUM(ord.discount_amount) AS discount_amount,
    SUM(ord.pay_amount) AS gmv,
    AVG(ord.pay_amount) AS avg_order_value,
    COUNT(DISTINCT CASE WHEN ord.order_type = 2 THEN ord.order_no END) AS seckill_order_count
FROM order_db_0.order_0 ord
WHERE ord.payment_time IS NOT NULL AND ord.is_archived = 0
GROUP BY DATE(ord.create_time);

SELECT '6个视图创建完成' AS result;
