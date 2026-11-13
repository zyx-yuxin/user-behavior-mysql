desc user_behavior;
#改名ts为timestamps
#alter table user_behavior change ts timestamps int(14);
desc user_behavior;
#检查空值
select * from user_behavior where user_id is null;
select * from user_behavior where item_id is null;
select * from user_behavior where category_id is null;
select * from user_behavior where behavior_type is null;
select * from user_behavior where timestamps is null;
#检查重复值
SELECT user_id, item_id, timestamps, behavior_type, COUNT(*) AS cnt
FROM user_behavior
GROUP BY user_id, item_id, timestamps, behavior_type
HAVING COUNT(*) > 1;

show VARIABLES like '%_buffer%';
-- ① 加 datetime 列（用 datetime 不用 timestamp）
ALTER TABLE user_behavior ADD datetimes DATETIME;
-- ② 从 timestamps 转换填充（500万行大约 30~60 秒）
UPDATE user_behavior SET datetimes = FROM_UNIXTIME(timestamps);
-- 验证
SELECT timestamps, datetimes FROM user_behavior LIMIT 10;
-- ③ 加日期、时间、小时列（用精确类型）
ALTER TABLE user_behavior ADD dates DATE;
ALTER TABLE user_behavior ADD times TIME;
ALTER TABLE user_behavior ADD hours TINYINT UNSIGNED;
-- ④ 用内置函数填充（比 substring 更规范，类型更精确）
UPDATE user_behavior SET
  dates = DATE(datetimes),
  times = TIME(datetimes),
  hours = HOUR(datetimes);

-- 验证
SELECT datetimes, dates, times, hours FROM user_behavior LIMIT 10;

-- 看实际日期范围
SELECT MIN(dates), MAX(dates) FROM user_behavior;

-- 看有没有超出这个范围的
SELECT COUNT(*) FROM user_behavior
WHERE dates < '2017-11-25' OR dates > '2017-12-03';

delete from user_behavior
where dates < '2017-11-25' or dates > '2017-12-03';

#数据概览验证
-- 1. 查看总数据量（预期接近 500 万）
select count(*) from user_behavior;

-- 2. 查看行为类型分布（PV/点击、加购、收藏、购买各多少）
select user_behavior.behavior_type,count(*) as cnt
from user_behavior
group by behavior_type
order by behavior_type;

-- 3. 抽样看几条完整数据
select * from user_behavior limit 5;