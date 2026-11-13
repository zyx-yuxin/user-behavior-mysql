-- ============================================================
-- 淘宝用户行为分析 - 数据库初始化脚本
-- 数据集：UserBehavior（100万用户行为记录）
-- ============================================================

-- 1. 创建数据库（如已存在则跳过）
CREATE DATABASE IF NOT EXISTS user_behavior_analysis
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

-- 切换到目标库
USE user_behavior_analysis;


-- 2. 创建原始行为表
CREATE TABLE user_behavior (
  user_id       BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
  item_id       BIGINT UNSIGNED NOT NULL COMMENT '商品ID',
  category_id   BIGINT UNSIGNED NOT NULL COMMENT '商品类目ID',
  behavior_type VARCHAR(6) NOT NULL COMMENT '行为类型：pv/fav/cart/buy',
  ts            BIGINT NOT NULL COMMENT '行为发生时间（Unix时间戳，秒级）',
  KEY idx_user (user_id),
  KEY idx_item (item_id),
  KEY idx_behavior_ts (behavior_type, ts),
  KEY idx_category (category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='淘宝用户原始行为表';


-- 3. 导入数据（CSV路径需按本机实际位置修改）
-- 数据来源：https://tianchi.aliyun.com/dataset/649
-- 注意：需开启 local_infile 支持（SET GLOBAL local_infile = 1;）
LOAD DATA LOCAL INFILE 'D:/alibaba/UserBehavior/UserBehavior_sample_1m.csv'
INTO TABLE user_behavior
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(user_id, item_id, category_id, behavior_type, ts);


-- 4. 数据验证
-- 4.1 查看总行数
SELECT COUNT(*) AS total_rows FROM user_behavior;

-- 4.2 抽查前10行
SELECT * FROM user_behavior LIMIT 10;

-- 4.3 各行为类型分布
SELECT
    behavior_type AS '行为类型',
    COUNT(*) AS '行为次数',
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM user_behavior) * 100, 2) AS '占比(%)'
FROM user_behavior
GROUP BY behavior_type
ORDER BY cnt DESC;