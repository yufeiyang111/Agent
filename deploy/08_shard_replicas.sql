-- ===================== 复制模板表到所有分片 =====================
-- 在 first_db_0 执行完各业务域 DDL 后，运行此脚本复制到其他分片
-- 使用: mysql -u root -p < 08_shard_replicas.sql

-- 用户库: user_db_1 ~ user_db_3 (每库6张)
CREATE TABLE IF NOT EXISTS user_db_1.user_0       LIKE user_db_0.user_0;
CREATE TABLE IF NOT EXISTS user_db_1.user_address_0 LIKE user_db_0.user_address_0;
CREATE TABLE IF NOT EXISTS user_db_1.user_collection_0 LIKE user_db_0.user_collection_0;
CREATE TABLE IF NOT EXISTS user_db_1.user_browsing_history_0 LIKE user_db_0.user_browsing_history_0;
CREATE TABLE IF NOT EXISTS user_db_1.user_points_log_0 LIKE user_db_0.user_points_log_0;
CREATE TABLE IF NOT EXISTS user_db_1.user_login_log_0 LIKE user_db_0.user_login_log_0;

CREATE TABLE IF NOT EXISTS user_db_2.user_0       LIKE user_db_0.user_0;
CREATE TABLE IF NOT EXISTS user_db_2.user_address_0 LIKE user_db_0.user_address_0;
CREATE TABLE IF NOT EXISTS user_db_2.user_collection_0 LIKE user_db_0.user_collection_0;
CREATE TABLE IF NOT EXISTS user_db_2.user_browsing_history_0 LIKE user_db_0.user_browsing_history_0;
CREATE TABLE IF NOT EXISTS user_db_2.user_points_log_0 LIKE user_db_0.user_points_log_0;
CREATE TABLE IF NOT EXISTS user_db_2.user_login_log_0 LIKE user_db_0.user_login_log_0;

CREATE TABLE IF NOT EXISTS user_db_3.user_0       LIKE user_db_0.user_0;
CREATE TABLE IF NOT EXISTS user_db_3.user_address_0 LIKE user_db_0.user_address_0;
CREATE TABLE IF NOT EXISTS user_db_3.user_collection_0 LIKE user_db_0.user_collection_0;
CREATE TABLE IF NOT EXISTS user_db_3.user_browsing_history_0 LIKE user_db_0.user_browsing_history_0;
CREATE TABLE IF NOT EXISTS user_db_3.user_points_log_0 LIKE user_db_0.user_points_log_0;
CREATE TABLE IF NOT EXISTS user_db_3.user_login_log_0 LIKE user_db_0.user_login_log_0;

-- 商品库: product_db_1 ~ product_db_3 (每库8张: 5业务+3广播)
CREATE TABLE IF NOT EXISTS product_db_1.spu_0              LIKE product_db_0.spu_0;
CREATE TABLE IF NOT EXISTS product_db_1.sku_0              LIKE product_db_0.sku_0;
CREATE TABLE IF NOT EXISTS product_db_1.sku_stock_0        LIKE product_db_0.sku_stock_0;
CREATE TABLE IF NOT EXISTS product_db_1.stock_flow_0       LIKE product_db_0.stock_flow_0;
CREATE TABLE IF NOT EXISTS product_db_1.sku_price_history_0 LIKE product_db_0.sku_price_history_0;
CREATE TABLE IF NOT EXISTS product_db_1.category_broadcast  LIKE product_db_0.category_broadcast;
CREATE TABLE IF NOT EXISTS product_db_1.brand_broadcast     LIKE product_db_0.brand_broadcast;
CREATE TABLE IF NOT EXISTS product_db_1.product_attr        LIKE product_db_0.product_attr;

CREATE TABLE IF NOT EXISTS product_db_2.spu_0              LIKE product_db_0.spu_0;
CREATE TABLE IF NOT EXISTS product_db_2.sku_0              LIKE product_db_0.sku_0;
CREATE TABLE IF NOT EXISTS product_db_2.sku_stock_0        LIKE product_db_0.sku_stock_0;
CREATE TABLE IF NOT EXISTS product_db_2.stock_flow_0       LIKE product_db_0.stock_flow_0;
CREATE TABLE IF NOT EXISTS product_db_2.sku_price_history_0 LIKE product_db_0.sku_price_history_0;
CREATE TABLE IF NOT EXISTS product_db_2.category_broadcast  LIKE product_db_0.category_broadcast;
CREATE TABLE IF NOT EXISTS product_db_2.brand_broadcast     LIKE product_db_0.brand_broadcast;
CREATE TABLE IF NOT EXISTS product_db_2.product_attr        LIKE product_db_0.product_attr;

CREATE TABLE IF NOT EXISTS product_db_3.spu_0              LIKE product_db_0.spu_0;
CREATE TABLE IF NOT EXISTS product_db_3.sku_0              LIKE product_db_0.sku_0;
CREATE TABLE IF NOT EXISTS product_db_3.sku_stock_0        LIKE product_db_0.sku_stock_0;
CREATE TABLE IF NOT EXISTS product_db_3.stock_flow_0       LIKE product_db_0.stock_flow_0;
CREATE TABLE IF NOT EXISTS product_db_3.sku_price_history_0 LIKE product_db_0.sku_price_history_0;
CREATE TABLE IF NOT EXISTS product_db_3.category_broadcast  LIKE product_db_0.category_broadcast;
CREATE TABLE IF NOT EXISTS product_db_3.brand_broadcast     LIKE product_db_0.brand_broadcast;
CREATE TABLE IF NOT EXISTS product_db_3.product_attr        LIKE product_db_0.product_attr;

-- 订单库: order_db_1 ~ order_db_7 (每库8张)
CREATE TABLE IF NOT EXISTS order_db_1.order_0            LIKE order_db_0.order_0;
CREATE TABLE IF NOT EXISTS order_db_1.order_item_0        LIKE order_db_0.order_item_0;
CREATE TABLE IF NOT EXISTS order_db_1.order_log_0         LIKE order_db_0.order_log_0;
CREATE TABLE IF NOT EXISTS order_db_1.cart_0              LIKE order_db_0.cart_0;
CREATE TABLE IF NOT EXISTS order_db_1.order_payment_0     LIKE order_db_0.order_payment_0;
CREATE TABLE IF NOT EXISTS order_db_1.refund_0            LIKE order_db_0.refund_0;
CREATE TABLE IF NOT EXISTS order_db_1.order_delivery_0    LIKE order_db_0.order_delivery_0;
CREATE TABLE IF NOT EXISTS order_db_1.delivery_track_0    LIKE order_db_0.delivery_track_0;

CREATE TABLE IF NOT EXISTS order_db_2.order_0            LIKE order_db_0.order_0;
CREATE TABLE IF NOT EXISTS order_db_2.order_item_0        LIKE order_db_0.order_item_0;
CREATE TABLE IF NOT EXISTS order_db_2.order_log_0         LIKE order_db_0.order_log_0;
CREATE TABLE IF NOT EXISTS order_db_2.cart_0              LIKE order_db_0.cart_0;
CREATE TABLE IF NOT EXISTS order_db_2.order_payment_0     LIKE order_db_0.order_payment_0;
CREATE TABLE IF NOT EXISTS order_db_2.refund_0            LIKE order_db_0.refund_0;
CREATE TABLE IF NOT EXISTS order_db_2.order_delivery_0    LIKE order_db_0.order_delivery_0;
CREATE TABLE IF NOT EXISTS order_db_2.delivery_track_0    LIKE order_db_0.delivery_track_0;

CREATE TABLE IF NOT EXISTS order_db_3.order_0            LIKE order_db_0.order_0;
CREATE TABLE IF NOT EXISTS order_db_3.order_item_0        LIKE order_db_0.order_item_0;
CREATE TABLE IF NOT EXISTS order_db_3.order_log_0         LIKE order_db_0.order_log_0;
CREATE TABLE IF NOT EXISTS order_db_3.cart_0              LIKE order_db_0.cart_0;
CREATE TABLE IF NOT EXISTS order_db_3.order_payment_0     LIKE order_db_0.order_payment_0;
CREATE TABLE IF NOT EXISTS order_db_3.refund_0            LIKE order_db_0.refund_0;
CREATE TABLE IF NOT EXISTS order_db_3.order_delivery_0    LIKE order_db_0.order_delivery_0;
CREATE TABLE IF NOT EXISTS order_db_3.delivery_track_0    LIKE order_db_0.delivery_track_0;

CREATE TABLE IF NOT EXISTS order_db_4.order_0            LIKE order_db_0.order_0;
CREATE TABLE IF NOT EXISTS order_db_4.order_item_0        LIKE order_db_0.order_item_0;
CREATE TABLE IF NOT EXISTS order_db_4.order_log_0         LIKE order_db_0.order_log_0;
CREATE TABLE IF NOT EXISTS order_db_4.cart_0              LIKE order_db_0.cart_0;
CREATE TABLE IF NOT EXISTS order_db_4.order_payment_0     LIKE order_db_0.order_payment_0;
CREATE TABLE IF NOT EXISTS order_db_4.refund_0            LIKE order_db_0.refund_0;
CREATE TABLE IF NOT EXISTS order_db_4.order_delivery_0    LIKE order_db_0.order_delivery_0;
CREATE TABLE IF NOT EXISTS order_db_4.delivery_track_0    LIKE order_db_0.delivery_track_0;

CREATE TABLE IF NOT EXISTS order_db_5.order_0            LIKE order_db_0.order_0;
CREATE TABLE IF NOT EXISTS order_db_5.order_item_0        LIKE order_db_0.order_item_0;
CREATE TABLE IF NOT EXISTS order_db_5.order_log_0         LIKE order_db_0.order_log_0;
CREATE TABLE IF NOT EXISTS order_db_5.cart_0              LIKE order_db_0.cart_0;
CREATE TABLE IF NOT EXISTS order_db_5.order_payment_0     LIKE order_db_0.order_payment_0;
CREATE TABLE IF NOT EXISTS order_db_5.refund_0            LIKE order_db_0.refund_0;
CREATE TABLE IF NOT EXISTS order_db_5.order_delivery_0    LIKE order_db_0.order_delivery_0;
CREATE TABLE IF NOT EXISTS order_db_5.delivery_track_0    LIKE order_db_0.delivery_track_0;

CREATE TABLE IF NOT EXISTS order_db_6.order_0            LIKE order_db_0.order_0;
CREATE TABLE IF NOT EXISTS order_db_6.order_item_0        LIKE order_db_0.order_item_0;
CREATE TABLE IF NOT EXISTS order_db_6.order_log_0         LIKE order_db_0.order_log_0;
CREATE TABLE IF NOT EXISTS order_db_6.cart_0              LIKE order_db_0.cart_0;
CREATE TABLE IF NOT EXISTS order_db_6.order_payment_0     LIKE order_db_0.order_payment_0;
CREATE TABLE IF NOT EXISTS order_db_6.refund_0            LIKE order_db_0.refund_0;
CREATE TABLE IF NOT EXISTS order_db_6.order_delivery_0    LIKE order_db_0.order_delivery_0;
CREATE TABLE IF NOT EXISTS order_db_6.delivery_track_0    LIKE order_db_0.delivery_track_0;

CREATE TABLE IF NOT EXISTS order_db_7.order_0            LIKE order_db_0.order_0;
CREATE TABLE IF NOT EXISTS order_db_7.order_item_0        LIKE order_db_0.order_item_0;
CREATE TABLE IF NOT EXISTS order_db_7.order_log_0         LIKE order_db_0.order_log_0;
CREATE TABLE IF NOT EXISTS order_db_7.cart_0              LIKE order_db_0.cart_0;
CREATE TABLE IF NOT EXISTS order_db_7.order_payment_0     LIKE order_db_0.order_payment_0;
CREATE TABLE IF NOT EXISTS order_db_7.refund_0            LIKE order_db_0.refund_0;
CREATE TABLE IF NOT EXISTS order_db_7.order_delivery_0    LIKE order_db_0.order_delivery_0;
CREATE TABLE IF NOT EXISTS order_db_7.delivery_track_0    LIKE order_db_0.delivery_track_0;

-- 评价库: review_db_1 ~ review_db_3 (每库3张)
CREATE TABLE IF NOT EXISTS review_db_1.review_0       LIKE review_db_0.review_0;
CREATE TABLE IF NOT EXISTS review_db_1.review_image_0  LIKE review_db_0.review_image_0;
CREATE TABLE IF NOT EXISTS review_db_1.review_reply_0  LIKE review_db_0.review_reply_0;

CREATE TABLE IF NOT EXISTS review_db_2.review_0       LIKE review_db_0.review_0;
CREATE TABLE IF NOT EXISTS review_db_2.review_image_0  LIKE review_db_0.review_image_0;
CREATE TABLE IF NOT EXISTS review_db_2.review_reply_0  LIKE review_db_0.review_reply_0;

CREATE TABLE IF NOT EXISTS review_db_3.review_0       LIKE review_db_0.review_0;
CREATE TABLE IF NOT EXISTS review_db_3.review_image_0  LIKE review_db_0.review_image_0;
CREATE TABLE IF NOT EXISTS review_db_3.review_reply_0  LIKE review_db_0.review_reply_0;

-- 营销库: marketing_db_1 (每库6张)
CREATE TABLE IF NOT EXISTS marketing_db_1.coupon_0             LIKE marketing_db_0.coupon_0;
CREATE TABLE IF NOT EXISTS marketing_db_1.user_coupon_0         LIKE marketing_db_0.user_coupon_0;
CREATE TABLE IF NOT EXISTS marketing_db_1.seckill_activity_0    LIKE marketing_db_0.seckill_activity_0;
CREATE TABLE IF NOT EXISTS marketing_db_1.seckill_product_0     LIKE marketing_db_0.seckill_product_0;
CREATE TABLE IF NOT EXISTS marketing_db_1.seckill_order_0       LIKE marketing_db_0.seckill_order_0;
CREATE TABLE IF NOT EXISTS marketing_db_1.promotion_activity_0  LIKE marketing_db_0.promotion_activity_0;

SELECT '所有分片模板表复制完成 (24库 x _0模板表)' AS result;
