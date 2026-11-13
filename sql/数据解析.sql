##获客情况
#创建临时表
create table temp_behavior like user_behavior;
#插入数据
insert into temp_behavior select
* from user_behavior limit 100000;

select * from temp_behavior;

#分段查pv,uv
#pv
select temp_behavior.dates,count(*) 'pv'
from temp_behavior
where behavior_type = 'pv'
group by dates;
#uv--distinct user_id = "把同一个用户的多次访问合并成一个人"，
# count(distinct user_id) = "统计总共有多少个不重复的用户来过"，也就是 UV。
select dates, count(distinct user_id) 'pv'
from temp_behavior
where behavior_type = 'pv'
group by dates ;

#pv,uv
select dates ,count(*) 'pv',count(distinct user_id) 'uv',
round(count(*)/count(distinct user_id),1) 'pv/uv'#round是四舍五入的函数
from temp_behavior
where behavior_type = 'pv'
group by dates ;

#pv/uv 就是人均浏览页数
#建结果表 + 插入真实数据
create table pv_uv_puv (
    dates char(10),
    pv int(9),
    uv int(9),
    puv decimal(10,1)
);

insert into pv_uv_puv
select dates ,count(*) 'pv',count(distinct user_id) 'uv',
round(count(*)/count(distinct user_id),1) 'pv/uv'#round是四舍五入的函数
from user_behavior
where behavior_type = 'pv'
group by dates ;

select * from pv_uv_puv limit 1000;
#这就是9 天的每日流量概况——每天多少人来、看了多少页、
# 人均浏览深度。后面做转化漏斗和留存时，这张表就是基础。

##留存情况
#留存（Retention）= 用户第一次来之后，后续还有没有再来。
#去重
delete from user_behavior where dates is null;
#用户每日活跃去重---一个用户同一天可能有很多行为（多次pv、加购等），
# 留存分析只看"这天来没来"，所以要按用户+日期去重。
select user_id,dates from temp_behavior group by user_id,dates;
#理解步骤.把同一个用户的所有活跃日期自己跟自己配对。比如用户A在25、26、28号活跃，
# 配对后变成 (25,25), (25,26), (25,28), (26,26), (26,28), (28,28)。
select * from
(select user_id,dates from temp_behavior group by user_id,dates) a,
(select user_id,dates from temp_behavior group by user_id,dates) b
where a.user_id=b.user_id;
#筛选
select * from
(select user_id,dates from temp_behavior group by user_id,dates) a,
(select user_id,dates from temp_behavior group by user_id,dates) b
where a.user_id=b.user_id and a.dates<b.dates;
#计算留存数，这里看留存数有多少，顺便计算等一下留存率的分母和分子
select a.dates
,count(if(datediff(b.dates,a.dates)=0,b.user_id,null)) retention_0 #分母
,count(if(datediff(b.dates,a.dates)=1,b.user_id,null)) retention_1 #分子
,count(if(datediff(b.dates,a.dates)=3,b.user_id,null)) retention_3 #分子
from
(select user_id,dates from temp_behavior group by user_id,dates) a,
(select user_id,dates from temp_behavior group by user_id,dates) b
where a.user_id = b.user_id and a.dates <= b.dates
group by a.dates;
#上面代码算出比如：在2017-11-25的retention_0等于2017-11-25 当天，
# 有 696 个独立用户至少产生过一次行为（浏览/加购/收藏/购买中的任意一种）。

#留存率
select a.dates
,count(if(datediff(b.dates,a.dates)=1,b.user_id,null))/
count(if(datediff(b.dates,a.dates)=0,b.user_id,null)) retention_1
from
(select user_id,dates from temp_behavior group by user_id, dates) a,
(select user_id,dates from temp_behavior group by user_id, dates) b
where a.user_id = b.user_id and a.user_id <= b.user_id
group by a.dates ;

select a.dates
,count(if(datediff(b.dates,a.dates)=1,b.user_id,null))/
count(if(datediff(b.dates,a.dates)=0,b.user_id,null)) retention_1
from
(select user_id,dates from temp_behavior group by user_id, dates) a,
(select user_id,dates from temp_behavior group by user_id, dates) b
where a.user_id = b.user_id and a.dates <= b.dates#"把同一个用户的所有活跃日期，按'前面的日期配后面的日期'的方式两两配对，包括同一天自己配自己。"
group by a.dates ;
#and a.dates <= b.dates意思是保证时间方向正确：基准日 → 回访日，不会倒着算

##跳失率
#跳失率高 + 留存率低 → 产品根本留不住人，需要全面排查
#跳失率低 + 留存率低 → 首次体验还行，但长期价值不够，需要增加用户粘性功能
#跳失率高 + 留存率高 → 来的大部分是路人，但留下来的都是铁粉（小众产品特征）
#跳失率低 + 留存率高 → 🚀 理想状态
#这里严格来讲叫一次性用户占比而不是跳失率
#一次性用户数（近似跳失用户）
select count(*) as bounce_users from (
    select user_id from user_behavior
    group by user_id
    having count(behavior_type) = 1
                                     )
a;#1

#总活跃用户数（uv）
select count(distinct user_id) from user_behavior; #9740
#跳失率
select
    (select count(*) as bounce_users from (
    select user_id from user_behavior
    group by user_id
    having count(behavior_type) = 1
                                     )
a)
/
    (select count(distinct user_id) from user_behavior)
as bounce_rate;

#时间序列分析
#按"日期 + 小时"统计四种行为
select dates,hours
,count(if(behavior_type='pv',behavior_type,null)) 'pv'
,count(if(behavior_type='pv',behavior_type,null)) 'cart'
,count(if(behavior_type='pv',behavior_type,null)) 'fav'
,count(if(behavior_type='pv',behavior_type,null)) 'buy'
from temp_behavior
group by dates,hours
order by dates,hours;

#存储
CREATE TABLE date_hour_behavior(
  dates CHAR(10),
  hours CHAR(2),
  pv   INT,
  cart INT,
  fav  INT,
  buy  INT
);

insert into date_hour_behavior
SELECT dates
,LPAD(hours,2,'0')          -- '8' → '08', '0' → '00'
,COUNT(IF(behavior_type='pv'  ,behavior_type,NULL))
,COUNT(IF(behavior_type='cart',behavior_type,NULL))
,COUNT(IF(behavior_type='fav' ,behavior_type,NULL))
,COUNT(IF(behavior_type='buy' ,behavior_type,NULL))
FROM user_behavior
GROUP BY dates, LPAD(hours,2,'0')
ORDER BY dates, LPAD(hours,2,'0');

SELECT * FROM date_hour_behavior;

#怎么看
#-- 各时段平均行为分布（9天平均）
SELECT hours
,AVG(pv)   AS avg_pv
,AVG(cart) AS avg_cart
,AVG(fav)  AS avg_fav
,AVG(buy)  AS avg_buy
-- 点击→加购转化率
,ROUND(AVG(cart) / NULLIF(AVG(pv),0), 4) AS cart_rate
-- 加购→购买转化率
,ROUND(AVG(buy) / NULLIF(AVG(cart),0), 4) AS buy_from_cart_rate
FROM date_hour_behavior
GROUP BY hours
ORDER BY hours;

#用户转化率分析
#按行为类型统计「独立用户数」
SELECT behavior_type, COUNT(DISTINCT user_id) user_num
FROM temp_behavior
GROUP BY behavior_type;
# 按行为类型统计「行为次数」
SELECT behavior_type, COUNT(*) behavior_count_num
FROM temp_behavior
GROUP BY behavior_type;

#存储
create table behavior_user_num(
    behavior_type varchar(5),
    user_num int
);

insert into behavior_user_num
SELECT behavior_type, COUNT(DISTINCT user_id) user_num
FROM temp_behavior
GROUP BY behavior_type
order by behavior_type desc ;

select * from behavior_user_num;

#存储
create table behavior_num(
    behavior_type varchar(5),
    behavior_count_num int
);

insert into behavior_num
SELECT behavior_type, COUNT(*) behavior_count_num
FROM temp_behavior
GROUP BY behavior_type
order by behavior_type desc;

select * from behavior_num;

#算购买用户占比（渗透率）买过东西的独立用户数 ÷ 总独立用户数
select
count(distinct case when behavior_type = 'buy' then user_id end)
/count(distinct user_id) as buy_user_ratio
from user_behavior;
#输出得0.6868

#购买率（次数视角，对应课件 2015807/89660670）算buy_rate购买率和fav_cart_rate加购物车，收藏率
select
    sum(behavior_type = 'buy') / count(*) as buy_rate,
    (sum(behavior_type = 'fav') + sum(behavior_type = 'cart')) /
    count(*) as fav_cart_rate
from user_behavior;
#输出得到buy_rate0.0204,fav_cart_rate0.0836

##行为路径分析
#每个用户对每个商品，统计他在这 9 天里分别浏览/收藏/加购/购买过几次
CREATE VIEW user_behavior_view AS
SELECT user_id, item_id
,COUNT(IF(behavior_type='pv'  ,behavior_type,NULL)) 'pv'
,COUNT(IF(behavior_type='fav' ,behavior_type,NULL)) 'fav'
,COUNT(IF(behavior_type='cart',behavior_type,NULL)) 'cart'
,COUNT(IF(behavior_type='buy' ,behavior_type,NULL)) 'buy'
FROM temp_behavior
GROUP BY user_id, item_id;

#用户行为标准化
#why?路径分析关心的是"这个用户对这件商品，走到哪一步了"，
#而不是"浏览了 5 次还是 6 次"。次数在这里是噪声，二值化才是信号。
CREATE VIEW user_behavior_standard AS
SELECT user_id, item_id,
       (CASE WHEN pv>0 THEN 1 ELSE 0 END)  浏览了,
       (CASE WHEN fav>0 THEN 1 ELSE 0 END) 收藏了,
       (CASE WHEN cart>0 THEN 1 ELSE 0 END) 加购了,
       (CASE WHEN buy>0 THEN 1 ELSE 0 END) 购买了
FROM user_behavior_view;

select * from user_behavior_standard;

#路径类型
CREATE VIEW user_behavior_path AS
SELECT *,
       CONCAT(浏览了, 收藏了, 加购了, 购买了) 购买路径类型
FROM user_behavior_standard AS a
WHERE a.购买了 > 0;

select * from user_behavior_path;

#统计各类购买行为数量--计算购买行为数量
CREATE VIEW path_count AS
SELECT 购买路径类型,
       COUNT(*) 数量
FROM user_behavior_path
GROUP BY 购买路径类型
ORDER BY 数量 DESC;

select * from path_count;

#人话表--就是翻译
CREATE TABLE renhua(
  path_type CHAR(4),
  description VARCHAR(40)
);

INSERT INTO renhua VALUES
('0001','直接购买了'),
('1001','浏览后购买了'),
('0011','加购后购买了'),
('1011','浏览加购后购买了'),
('0101','收藏后购买了'),
('1101','浏览收藏后购买了'),
('0111','收藏加购后购买了'),
('1111','浏览收藏加购后购买了');

select * from renhua;

#合体
select * from path_count p
join renhua r on p.购买路径类型 = r.path_type
order by p.数量 desc;

#-- 加购了但没买的人-货对（流失口径，不在当前 path_count 里）
SELECT COUNT(*) AS cart_no_buy
FROM user_behavior_view
WHERE cart > 0 AND buy = 0;

#存储结果
create table path_result(
path_type char(4),
description varchar(40),
num int);

insert into path_result
select path_type,description,数量 from path_count p
join renhua r on p.购买路径类型 = r.path_type
order by p.数量 desc;

select * from path_result;

# 1直购次数（无收藏无加购的购买）得1643
SELECT SUM(buy) AS direct_buy
FROM user_behavior_view
WHERE buy > 0 AND fav = 0 AND cart = 0;
# 2犹豫后购买次数（至少碰过收藏或加购才买）得458
SELECT SUM(buy) AS assisted_buy
FROM user_behavior_view
WHERE buy > 0 AND (fav > 0 OR cart > 0);

# 3收藏+加购总次数（当分母）得total_fav2744，total_cart5446
SELECT SUM(fav) AS total_fav, SUM(cart) AS total_cart
FROM user_behavior_view;

# 4自己套比例（把 ② 除以 ③ 的和）犹豫后购买次数/收藏+加购总次数 得0.0559
SELECT
  (SELECT SUM(buy) FROM user_behavior_view WHERE buy>0 AND (fav>0 OR cart>0))
  /
  (SELECT SUM(fav)+SUM(cart) FROM user_behavior_view) AS fav_cart_to_buy_rate;

#还有一种情况是用户先加购和收藏，过了几天用户直接浏览下单，这种怎么算？
#回答 这条 SQL 存在的意义，是回答四位码路径分析永远回答不了的那个问题——"用户按下购买键之前，
# 最后一个动作到底是什么？"
WITH buy_time AS (
    SELECT user_id, item_id, MIN(hours) AS first_buy_hour   -- 首次购买时刻
    FROM user_behavior
    WHERE behavior_type = 'buy'
    GROUP BY user_id, item_id
),
last_before AS ( -- 算每个 (user_id, item_id) 在「第一次购买」之前，紧邻下单的那 一条 非购买行为
    SELECT b.user_id, b.item_id, b.behavior_type
    FROM user_behavior b
    JOIN buy_time bt
      ON b.user_id = bt.user_id AND b.item_id = bt.item_id
     AND b.hours < bt.first_buy_hour                 -- 只看购买之前
     AND b.behavior_type <> 'buy'                    -- 购买本身不算
    WHERE b.hours = (                                -- 只留「离购买最近」那一行(子查询)
        SELECT MAX(b2.hours)
        FROM user_behavior b2
        WHERE b2.user_id = b.user_id  -- 保证b2和b同一用户id
          AND b2.item_id = b.item_id  -- 保证b2和b同一商品id
          AND b2.hours < bt.first_buy_hour  -- 这段不理解
          AND b2.behavior_type <> 'buy'  -- 保证这段b2不是购买的行为
    )
)
SELECT behavior_type AS last_action_before_buy,
       COUNT(*) AS cnt
FROM last_before
GROUP BY behavior_type;

##RFM模型
-- 统一
select user_id
,count(user_id) '购买次数'
,max(dates) '最近购买时间'
from user_behavior
where behavior_type='buy'
group by user_id
order by 2 desc,3 desc;

-- 存储
drop table if exists rfm_model;
create table rfm_model(
user_id int,
frequency int,
recent char(10)
);

insert into rfm_model
select user_id
,count(user_id) '购买次数'
,max(dates) '最近购买时间'
from user_behavior
where behavior_type='buy'
group by user_id
order by 2 desc,3 desc;

select * from rfm_model;

select max(rfm_model.frequency),min(frequency) from rfm_model;
-- 先清掉旧分
#UPDATE rfm_model SET fscore = NULL;
-- 根据购买次数对用户进行分层
alter table rfm_model add column fscore int;
#-- 按 1~72 的实际分布五等分（大致每档 20%）
UPDATE rfm_model
SET fscore = CASE
  WHEN frequency >= 29 THEN 5   -- Top 20% 左右（重复购）
  WHEN frequency >= 15 THEN 4   -- 15~28
  WHEN frequency >= 8  THEN 3   -- 8~14
  WHEN frequency >= 3  THEN 2   -- 3~7
  ELSE 1                        -- 只买过 1~2 次（占大头）
END;

-- 根据最近购买时间对用户进行分层
alter table rfm_model add column rscore int;

update rfm_model
set rscore = case
when recent = '2017-12-03' then 5
when recent in ('2017-12-01','2017-12-02') then 4
when recent in ('2017-11-29','2017-11-30') then 3
when recent in ('2017-11-27','2017-11-28') then 2
else 1
end;

select * from rfm_model;

#分层
set @f_avg=null;
set @r_avg=null;
select avg(fscore) into @f_avg from rfm_model;
select avg(rscore) into @r_avg from rfm_model;

select *
,(case
    when rfm_model.fscore>@f_avg and rfm_model.rscore >@r_avg then '价值用户'
    when rfm_model.fscore>@f_avg and rfm_model.rscore<@r_avg then '保持用户'
    when rfm_model.fscore<@f_avg and rfm_model.rscore>@r_avg then '发展用户'
    when rfm_model.fscore<@f_avg and rfm_model.rscore<@r_avg then '挽留用户'
    end
    ) class1
from rfm_model;

-- 插入
alter table rfm_model add column class1 varchar(40);
update rfm_model
set class1 = case
when fscore>@f_avg and rscore>@r_avg then '价值用户'
when fscore>@f_avg and rscore<@r_avg then '保持用户'
when fscore<@f_avg and rscore>@r_avg then '发展用户'
when fscore<@f_avg and rscore<@r_avg then '挽留用户'
end;

select * from rfm_model;

-- 统计各分区用户数
select class1,count(user_id) from rfm_model
group by class1;

##商品按热度分类
-- 统计商品的热门品类、热门商品、热门品类热门商品
select category_id
,count(if(behavior_type='pv',behavior_type,null)) '品类浏览量'
from temp_behavior
GROUP BY category_id
order by 2 desc
limit 10;

select item_id
,count(if(behavior_type='pv',behavior_type,null)) '商品浏览量'
from temp_behavior
GROUP BY item_id
order by 2 desc
limit 10;

select category_id,item_id,
品类商品浏览量 from
(
select category_id,item_id
,count(if(behavior_type='pv',behavior_type,null)) '品类商品浏览量'
-- ,rank()over(partition by category_id order by '品类商品浏览量' desc) r
-- 纠错，'品类商品浏览量'这里不能指代count(if(behavior_type='pv',behavior_type,null))因为还没返回
,rank()over(partition by category_id order by count(if(behavior_type='pv',behavior_type,null)) desc) r
from temp_behavior
GROUP BY category_id,item_id
order by 3 desc
) a
where a.r = 1
order by a.品类商品浏览量 desc
limit 10;

-- 存储

create table popular_categories(
category_id int,
pv int);
create table popular_items(
item_id int,
pv int);
create table popular_cateitems(
category_id int,
item_id int,
pv int);


insert into popular_categories
select category_id
,count(if(behavior_type='pv',behavior_type,null)) '品类浏览量'
from user_behavior
GROUP BY category_id
order by 2 desc
limit 10;


insert into popular_items
select item_id
,count(if(behavior_type='pv',behavior_type,null)) '商品浏览量'
from user_behavior
GROUP BY item_id
order by 2 desc
limit 10;

insert into popular_cateitems
select category_id,item_id,
品类商品浏览量 from
(
select category_id,item_id
,count(if(behavior_type='pv',behavior_type,null)) '品类商品浏览量'
,rank()over(partition by category_id order by '品类商品浏览量' desc) r
from user_behavior
GROUP BY category_id,item_id
order by 3 desc
) a
where a.r = 1
order by a.品类商品浏览量 desc
limit 10;


select * from popular_categories;
select * from popular_items;
select * from popular_cateitems;
#报告草稿
#基于 9 天窗口内的浏览行为（behavior_type='pv'），从品类、商品、品类-商品交叉三个粒度统计热度分布。品类级 TOP 10 贡献了全站 XX% 的浏览量，商品级呈现显著的长尾特征（头部 10 商品占 XX%），品类内流量高度集中于单一爆款（品类状元商品浏览量占该品类 XX%），印证了电商场景下的"爆款驱动"流量结构。
