##可视化
#日活趋势
select * from pv_uv_puv;
#24 小时用户活跃分布
select * from date_hour_behavior;
#RFM 四类人数 —— 饼图
SELECT class1, COUNT(*) AS user_cnt
FROM rfm_model
GROUP BY class1;

select *from rfm_model;

SELECT
    class1 AS '用户定位',
    COUNT(*) AS '人数',
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM rfm_model) * 100, 2) AS '占比(%)'
FROM rfm_model
GROUP BY class1
ORDER BY 人数 DESC;

#统计各路径购买用户数及占比 圆环图
-- 1. 先创建路径字典表（可选，方便映射中文名称）
CREATE TABLE path_dict (
    path_code VARCHAR(4),
    path_name VARCHAR(50)
);
INSERT INTO path_dict VALUES
('0001','直接购买了'), ('1001','浏览后购买了'), ('0101','收藏后购买了'),
('0011','加购后购买了'), ('1101','浏览收藏后购买了'), ('1011','浏览加购后购买了'),
('0111','收藏加购后购买了'), ('1111','浏览收藏加购后购买了');

-- 2. 统计各路径购买用户数及占比
WITH user_item_behavior AS (
    -- 第一阶段：按用户+商品聚合，打标志位
    SELECT
        user_id,
        item_id,
        MAX(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS pv_flag,
        MAX(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END) AS fav_flag,
        MAX(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS cart_flag,
        MAX(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS buy_flag
    FROM user_behavior  -- 替换为你的原始表名
    GROUP BY user_id, item_id
),
path_data AS (
    -- 第二阶段：拼接路径码，只保留有购买行为的
    SELECT
        CONCAT(pv_flag, fav_flag, cart_flag, buy_flag) AS path_code,
        COUNT(*) AS user_count
    FROM user_item_behavior
    WHERE buy_flag = 1
    GROUP BY path_code
)
SELECT
    d.path_name AS '行为路径',
    p.user_count AS '人数',
    ROUND(p.user_count / (SELECT SUM(user_count) FROM path_data) * 100, 2) AS '占比(%)'
FROM path_data p
JOIN path_dict d ON p.path_code = d.path_code
ORDER BY p.user_count DESC;