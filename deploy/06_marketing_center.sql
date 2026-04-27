-- ===================== 营销中心 DDL =====================
-- 分片: 2库 x 16表
-- 使用: mysql -u root -p marketing_db_0 < 06_marketing_center.sql

USE marketing_db_0;

CREATE TABLE IF NOT EXISTS coupon_0 (
    coupon_id        BIGINT        NOT NULL AUTO_INCREMENT COMMENT '优惠券ID',
    coupon_name      VARCHAR(128)  NOT NULL COMMENT '优惠券名称',
    coupon_type      TINYINT       NOT NULL COMMENT '类型: 1满减券/2折扣券/3无门槛券/4新人券',
    discount_value   DECIMAL(12,2) NOT NULL COMMENT '优惠值(满减金额/折扣折数)',
    min_order_amount DECIMAL(12,2) DEFAULT 0.00 COMMENT '最低订单金额(满减门槛)',
    total_limit      INT           NOT NULL DEFAULT 0 COMMENT '发放总量(0=不限)',
    received_count   INT           DEFAULT 0 COMMENT '已领取数量',
    used_count       INT           DEFAULT 0 COMMENT '已使用数量',
    per_user_limit   INT           DEFAULT 1 COMMENT '每人限领数量',
    use_scope        TINYINT       DEFAULT 1 COMMENT '使用范围: 1全平台/2指定分类/3指定SPU',
    scope_values     JSON          DEFAULT NULL COMMENT '范围值',
    valid_start_time DATETIME      NOT NULL COMMENT '有效期开始',
    valid_end_time   DATETIME      NOT NULL COMMENT '有效期结束',
    status           TINYINT       DEFAULT 1 COMMENT '状态: 1启用/2停用/3过期',
    create_time      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (coupon_id),
    INDEX idx_coupon_type (coupon_type),
    INDEX idx_valid_time (valid_start_time, valid_end_time),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='优惠券定义表';

CREATE TABLE IF NOT EXISTS user_coupon_0 (
    uc_id        BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键',
    user_id      BIGINT        NOT NULL COMMENT '用户ID',
    coupon_id    BIGINT        NOT NULL COMMENT '优惠券ID',
    use_status   TINYINT       DEFAULT 0 COMMENT '使用状态: 0未使用/1已使用/2已过期',
    order_no     VARCHAR(32)   DEFAULT NULL COMMENT '使用的订单号',
    use_time     DATETIME      DEFAULT NULL COMMENT '使用时间',
    create_time  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (uc_id),
    INDEX idx_user_id (user_id),
    INDEX idx_coupon_id (coupon_id),
    INDEX idx_use_status (user_id, use_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户领券表';

CREATE TABLE IF NOT EXISTS seckill_activity_0 (
    activity_id        BIGINT       NOT NULL AUTO_INCREMENT COMMENT '活动ID',
    activity_name      VARCHAR(128) NOT NULL COMMENT '活动名称',
    start_time         DATETIME     NOT NULL COMMENT '开始时间',
    end_time           DATETIME     NOT NULL COMMENT '结束时间',
    status             TINYINT      DEFAULT 0 COMMENT '状态: 0待开始/1进行中/2已结束/3已取消',
    seckill_strategy   TINYINT      DEFAULT 1 COMMENT '秒杀策略: 1先到先得/2排队抽签',
    per_user_limit     INT          DEFAULT 1 COMMENT '每人限购件数',
    create_time        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (activity_id),
    INDEX idx_status (status),
    INDEX idx_start_time (start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='秒杀活动表';

CREATE TABLE IF NOT EXISTS seckill_product_0 (
    id               BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键',
    activity_id      BIGINT        NOT NULL COMMENT '活动ID',
    sku_id           BIGINT        NOT NULL COMMENT 'SKU ID',
    spu_id           BIGINT        NOT NULL COMMENT 'SPU ID',
    seckill_price    DECIMAL(12,2) NOT NULL COMMENT '秒杀价',
    seckill_stock    INT           NOT NULL COMMENT '秒杀库存(独立于普通库存)',
    seckill_sold     INT           DEFAULT 0 COMMENT '已售数量',
    seckill_limit    INT           DEFAULT 1 COMMENT '每单限购件数',
    qps_limit        INT           DEFAULT 1000 COMMENT '接口限流QPS',
    create_time      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_activity_sku (activity_id, sku_id),
    INDEX idx_activity_id (activity_id),
    INDEX idx_sku_id (sku_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='秒杀商品表';

CREATE TABLE IF NOT EXISTS seckill_order_0 (
    id             BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键',
    activity_id    BIGINT        NOT NULL COMMENT '活动ID',
    user_id        BIGINT        NOT NULL COMMENT '用户ID',
    sku_id         BIGINT        NOT NULL COMMENT 'SKU ID',
    order_no       VARCHAR(32)   DEFAULT NULL COMMENT '关联正式订单号',
    seckill_status TINYINT       DEFAULT 0 COMMENT '状态: 0抢购成功(待支付)/1已支付/2已取消(超时)',
    create_time    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_activity_user (activity_id, user_id),
    INDEX idx_order_no (order_no),
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='秒杀订单记录表';

CREATE TABLE IF NOT EXISTS promotion_activity_0 (
    activity_id   BIGINT        NOT NULL AUTO_INCREMENT COMMENT '活动ID',
    activity_name VARCHAR(128)  NOT NULL COMMENT '活动名称',
    rule_type     TINYINT       NOT NULL COMMENT '规则类型: 1满减/2满折/3满赠',
    threshold     DECIMAL(12,2) NOT NULL COMMENT '满足条件(满X元)',
    discount      DECIMAL(12,2) NOT NULL COMMENT '优惠值(减Y元/打Z折)',
    scope_type    TINYINT       DEFAULT 1 COMMENT '适用范围: 1全平台/2指定分类/3指定SPU',
    scope_values  JSON          DEFAULT NULL COMMENT '范围值',
    start_time    DATETIME      NOT NULL COMMENT '开始时间',
    end_time      DATETIME      NOT NULL COMMENT '结束时间',
    priority      INT           DEFAULT 0 COMMENT '优先级(数值越大越优先)',
    status        TINYINT       DEFAULT 1 COMMENT '状态: 1启用/2停用',
    create_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (activity_id),
    INDEX idx_time (start_time, end_time),
    INDEX idx_status (status),
    INDEX idx_priority (priority)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='满减活动表';

SELECT '营销中心表创建完成 (marketing_db_0)' AS result;
