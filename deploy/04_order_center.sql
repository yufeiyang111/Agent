-- ===================== 订单中心 DDL =====================
-- 分片: 8库 x 64表 | 分片键: user_id
-- 算法: db_idx = user_id%8, tb_idx = (user_id>>4)%64
-- 使用: mysql -u root -p order_db_0 < 04_order_center.sql

USE order_db_0;

CREATE TABLE IF NOT EXISTS order_0 (
    order_no          VARCHAR(32)   NOT NULL COMMENT '订单号(雪花算法+业务编码)',
    user_id           BIGINT        NOT NULL COMMENT '买家用户ID',
    seller_id         BIGINT        DEFAULT NULL COMMENT '卖家ID',
    order_status      TINYINT       NOT NULL DEFAULT 0 COMMENT '状态: 0待支付/10已支付/20已发货/30已收货/40已完成/50已取消/60已退款',
    payment_status    TINYINT       DEFAULT 0 COMMENT '支付状态: 0未支付/1已支付/2已退款/3部分退款',
    delivery_status   TINYINT       DEFAULT 0 COMMENT '物流状态: 0未发货/1已发货/2已揽收/3运输中/4派件中/5已签收',
    order_type        TINYINT       DEFAULT 1 COMMENT '订单类型: 1普通/2秒杀/3拼团/4砍价/5预售',
    source            VARCHAR(32)   DEFAULT 'APP' COMMENT '来源: APP/H5/PC/MINI_PROGRAM',
    product_amount    DECIMAL(12,2) NOT NULL COMMENT '商品总金额',
    discount_amount   DECIMAL(12,2) DEFAULT 0.00 COMMENT '优惠金额',
    freight_amount    DECIMAL(12,2) DEFAULT 0.00 COMMENT '运费金额',
    pay_amount        DECIMAL(12,2) NOT NULL COMMENT '实付金额',
    coupon_id         BIGINT        DEFAULT NULL COMMENT '使用的优惠券ID',
    coupon_amount     DECIMAL(12,2) DEFAULT 0.00 COMMENT '优惠券减免金额',
    points_deduction  INT           DEFAULT 0 COMMENT '积分抵扣数量',
    invoice_type      TINYINT       DEFAULT 0 COMMENT '发票类型: 0不开发票/1电子发票/2纸质发票',
    buyer_remark      VARCHAR(512)  DEFAULT NULL COMMENT '买家备注',
    seller_remark     VARCHAR(512)  DEFAULT NULL COMMENT '卖家备注',
    payment_time      DATETIME      DEFAULT NULL COMMENT '支付时间',
    delivery_time     DATETIME      DEFAULT NULL COMMENT '发货时间',
    receive_time      DATETIME      DEFAULT NULL COMMENT '收货时间',
    finish_time       DATETIME      DEFAULT NULL COMMENT '完成时间',
    cancel_time       DATETIME      DEFAULT NULL COMMENT '取消时间',
    cancel_reason     VARCHAR(256)  DEFAULT NULL COMMENT '取消原因',
    auto_confirm_days INT           DEFAULT 15 COMMENT '自动确认收货天数',
    is_archived       TINYINT       DEFAULT 0 COMMENT '是否已归档(冷数据)',
    consignee_name    VARCHAR(64)   NOT NULL COMMENT '收货人姓名(地址快照)',
    consignee_phone   VARCHAR(20)   NOT NULL COMMENT '收货人手机号(地址快照)',
    province          VARCHAR(32)   NOT NULL COMMENT '省份(地址快照)',
    city              VARCHAR(32)   NOT NULL COMMENT '城市(地址快照)',
    district          VARCHAR(32)   NOT NULL COMMENT '区县(地址快照)',
    street_address    VARCHAR(256)  NOT NULL COMMENT '详细地址(地址快照)',
    create_time       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (order_no),
    INDEX idx_user_id (user_id),
    INDEX idx_order_status (order_status),
    INDEX idx_create_time (create_time),
    INDEX idx_payment_time (payment_time),
    INDEX idx_user_status (user_id, order_status),
    INDEX idx_user_time (user_id, create_time DESC),
    INDEX idx_archived_status (is_archived, order_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单主表';

CREATE TABLE IF NOT EXISTS order_item_0 (
    item_id        BIGINT        NOT NULL AUTO_INCREMENT COMMENT '明细ID',
    order_no       VARCHAR(32)   NOT NULL COMMENT '订单号',
    user_id        BIGINT        NOT NULL COMMENT '买家ID',
    spu_id         BIGINT        NOT NULL COMMENT 'SPU ID',
    sku_id         BIGINT        NOT NULL COMMENT 'SKU ID',
    sku_name       VARCHAR(256)  NOT NULL COMMENT 'SKU名称(商品快照)',
    sku_image      VARCHAR(256)  DEFAULT NULL COMMENT 'SKU图片(商品快照)',
    attrs_snapshot JSON          DEFAULT NULL COMMENT '销售属性快照(JSON)',
    price          DECIMAL(12,2) NOT NULL COMMENT '成交单价',
    quantity       INT           NOT NULL COMMENT '购买数量',
    subtotal       DECIMAL(12,2) NOT NULL COMMENT '小计金额',
    is_evaluated   TINYINT       DEFAULT 0 COMMENT '是否已评价: 0未评/1已评',
    is_refunded    TINYINT       DEFAULT 0 COMMENT '是否已退款: 0否/1退款中/2已退款',
    create_time    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (item_id),
    INDEX idx_order_no (order_no),
    INDEX idx_sku_id (sku_id),
    INDEX idx_user_id (user_id),
    INDEX idx_spu_id (spu_id),
    INDEX idx_evaluated (is_evaluated)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单明细表';

CREATE TABLE IF NOT EXISTS order_log_0 (
    log_id        BIGINT        NOT NULL AUTO_INCREMENT COMMENT '日志ID',
    order_no      VARCHAR(32)   NOT NULL COMMENT '订单号',
    user_id       BIGINT        NOT NULL COMMENT '操作人ID',
    operator_type TINYINT       DEFAULT 1 COMMENT '操作人类型: 1用户/2商家/3系统/4客服',
    action        VARCHAR(64)   NOT NULL COMMENT '操作动作: CREATE/PAY/CANCEL/DELIVER/RECEIVE/FINISH/REFUND',
    from_status   TINYINT       DEFAULT NULL COMMENT '变更前状态',
    to_status     TINYINT       DEFAULT NULL COMMENT '变更后状态',
    remark        VARCHAR(256)  DEFAULT NULL COMMENT '备注',
    create_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (log_id),
    INDEX idx_order_no (order_no),
    INDEX idx_create_time (create_time),
    INDEX idx_action (action)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单操作日志表';

CREATE TABLE IF NOT EXISTS cart_0 (
    cart_id      BIGINT    NOT NULL AUTO_INCREMENT COMMENT '购物车ID',
    user_id      BIGINT    NOT NULL COMMENT '用户ID',
    sku_id       BIGINT    NOT NULL COMMENT 'SKU ID',
    quantity     INT       NOT NULL DEFAULT 1 COMMENT '数量',
    checked      TINYINT   DEFAULT 1 COMMENT '是否选中: 0否/1是',
    is_deleted   TINYINT   DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    create_time  DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time  DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (cart_id),
    UNIQUE KEY uk_user_sku (user_id, sku_id),
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='购物车表';

CREATE TABLE IF NOT EXISTS order_payment_0 (
    payment_id      BIGINT        NOT NULL AUTO_INCREMENT COMMENT '支付记录ID',
    order_no        VARCHAR(32)   NOT NULL COMMENT '订单号',
    user_id         BIGINT        NOT NULL COMMENT '用户ID',
    pay_amount      DECIMAL(12,2) NOT NULL COMMENT '支付金额',
    pay_type        TINYINT       NOT NULL COMMENT '支付方式: 1微信支付/2支付宝/3平台余额/4组合支付',
    pay_status      TINYINT       DEFAULT 0 COMMENT '状态: 0待支付/1支付成功/2支付失败/3已退款',
    trade_no        VARCHAR(128)  DEFAULT NULL COMMENT '第三方支付流水号',
    notify_url      VARCHAR(256)  DEFAULT NULL COMMENT '回调通知URL',
    notify_status   TINYINT       DEFAULT 0 COMMENT '回调处理状态: 0待处理/1处理成功/2处理失败',
    notify_count    TINYINT       DEFAULT 0 COMMENT '回调通知次数(重试上限10次)',
    notify_time     DATETIME      DEFAULT NULL COMMENT '最后通知时间',
    bank_type       VARCHAR(32)   DEFAULT NULL COMMENT '银行类型(微信返回)',
    pay_time        DATETIME      DEFAULT NULL COMMENT '支付时间',
    create_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (payment_id),
    UNIQUE KEY uk_trade_no (trade_no),
    INDEX idx_order_no (order_no),
    INDEX idx_user_id (user_id),
    INDEX idx_pay_status (pay_status),
    INDEX idx_pay_time (pay_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='支付记录表';

CREATE TABLE IF NOT EXISTS refund_0 (
    refund_id       BIGINT        NOT NULL AUTO_INCREMENT COMMENT '退款ID',
    order_no        VARCHAR(32)   NOT NULL COMMENT '原订单号',
    order_item_id   BIGINT        DEFAULT NULL COMMENT '退款的明细ID(部分退款时指定)',
    user_id         BIGINT        NOT NULL COMMENT '用户ID',
    refund_amount   DECIMAL(12,2) NOT NULL COMMENT '退款金额',
    refund_type     TINYINT       NOT NULL COMMENT '退款类型: 1仅退款(未发货)/2退货退款(已发货)',
    refund_reason   VARCHAR(256)  NOT NULL COMMENT '退款原因',
    refund_status   TINYINT       DEFAULT 0 COMMENT '状态: 0待审核/1同意/2驳回/3退款中/4已完成/5退款失败',
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
    INDEX idx_refund_status (refund_status),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='退款表';

CREATE TABLE IF NOT EXISTS order_delivery_0 (
    delivery_id       BIGINT       NOT NULL AUTO_INCREMENT COMMENT '物流记录ID',
    order_no          VARCHAR(32)  NOT NULL COMMENT '订单号',
    express_company   VARCHAR(64)  NOT NULL COMMENT '快递公司名称',
    express_no        VARCHAR(64)  NOT NULL COMMENT '快递单号',
    delivery_status   TINYINT      DEFAULT 0 COMMENT '状态: 0待揽收/1运输中/2派件中/3已签收/4退回',
    estimated_arrival DATETIME     DEFAULT NULL COMMENT '预计送达时间',
    sign_time         DATETIME     DEFAULT NULL COMMENT '签收时间',
    create_time       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (delivery_id),
    INDEX idx_order_no (order_no),
    INDEX idx_express_no (express_no),
    INDEX idx_delivery_status (delivery_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='发货物流表';

CREATE TABLE IF NOT EXISTS delivery_track_0 (
    track_id       BIGINT       NOT NULL AUTO_INCREMENT COMMENT '轨迹ID',
    delivery_id    BIGINT       NOT NULL COMMENT '关联物流记录ID',
    order_no       VARCHAR(32)  NOT NULL COMMENT '订单号',
    track_status   VARCHAR(64)  NOT NULL COMMENT '物流节点描述(如"快件已揽收")',
    track_desc     VARCHAR(256) DEFAULT NULL COMMENT '详细描述',
    track_location VARCHAR(128) DEFAULT NULL COMMENT '发生地点',
    track_time     DATETIME     NOT NULL COMMENT '物流节点时间',
    create_time    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (track_id),
    INDEX idx_delivery_id (delivery_id),
    INDEX idx_order_no (order_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='物流轨迹表';

SELECT '订单中心表创建完成 (order_db_0)' AS result;
