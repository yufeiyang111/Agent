-- ===================== 评价中心 DDL =====================
-- 分片: 4库 x 32表 | 分片键: spu_id
-- 算法: db_idx = spu_id%4, tb_idx = (spu_id>>4)%32
-- 使用: mysql -u root -p review_db_0 < 05_review_center.sql

USE review_db_0;

CREATE TABLE IF NOT EXISTS review_0 (
    review_id    BIGINT         NOT NULL AUTO_INCREMENT COMMENT '评价ID',
    order_no     VARCHAR(32)    NOT NULL COMMENT '关联订单号',
    user_id      BIGINT         NOT NULL COMMENT '用户ID',
    spu_id       BIGINT         NOT NULL COMMENT 'SPU ID',
    sku_id       BIGINT         NOT NULL COMMENT 'SKU ID',
    rating       TINYINT        NOT NULL COMMENT '评分(1~5星)',
    content      VARCHAR(2000)  DEFAULT NULL COMMENT '评价内容',
    tags         JSON           DEFAULT NULL COMMENT '评价标签',
    review_type  TINYINT        DEFAULT 0 COMMENT '评价类型: 0好评(4-5星)/1中评(3星)/2差评(1-2星)',
    is_anonymous TINYINT        DEFAULT 0 COMMENT '是否匿名: 0否/1是',
    is_top       TINYINT        DEFAULT 0 COMMENT '是否置顶: 0否/1是',
    helpful_count INT           DEFAULT 0 COMMENT '有帮助数(点赞)',
    is_archived  TINYINT        DEFAULT 0 COMMENT '是否归档(冷数据): 0否/1是',
    is_deleted   TINYINT        DEFAULT 0 COMMENT '逻辑删除: 0未删/1已删',
    create_time  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (review_id),
    INDEX idx_spu_id (spu_id),
    INDEX idx_user_id (user_id),
    INDEX idx_order_no (order_no),
    INDEX idx_rating (spu_id, rating),
    INDEX idx_create_time (create_time),
    INDEX idx_spu_type (spu_id, review_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='评价表';

CREATE TABLE IF NOT EXISTS review_image_0 (
    image_id    BIGINT       NOT NULL AUTO_INCREMENT COMMENT '图片ID',
    review_id   BIGINT       NOT NULL COMMENT '关联评价ID',
    image_url   VARCHAR(256) NOT NULL COMMENT '图片URL',
    image_order INT          DEFAULT 0 COMMENT '图片排序(越小越前)',
    create_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (image_id),
    INDEX idx_review_id (review_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='评价图片表';

CREATE TABLE IF NOT EXISTS review_reply_0 (
    reply_id    BIGINT         NOT NULL AUTO_INCREMENT COMMENT '回复ID',
    review_id   BIGINT         NOT NULL COMMENT '关联评价ID',
    reply_type  TINYINT        DEFAULT 1 COMMENT '回复类型: 1商家回复/2用户追评',
    content     VARCHAR(2000)  NOT NULL COMMENT '回复内容',
    user_id     BIGINT         DEFAULT NULL COMMENT '回复人ID',
    is_deleted  TINYINT        DEFAULT 0 COMMENT '逻辑删除: 0未删/1已删',
    create_time DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (reply_id),
    INDEX idx_review_id (review_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='评价回复表';

SELECT '评价中心表创建完成 (review_db_0)' AS result;
