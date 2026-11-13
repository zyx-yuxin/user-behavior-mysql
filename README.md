# user-behavior-mysql
某电商平台用户行为分析
# 某宝用户行为数据分析（MySQL）

基于天池 UserBehavior 数据集，使用 MySQL 完成从数据清洗、指标计算到用户价值建模的全流程分析。

## 数据集

- **来源**：阿里云天池 [UserBehavior Dataset](https://tianchi.aliyun.com/dataset/649)
- **规模**：约 100 万条用户行为记录
- **字段**：用户 ID、商品 ID、商品类目 ID、行为类型（pv/fav/cart/buy）、时间戳
- **时间跨度**：2017-11-25 ~ 2017-12-03

## 技术栈

- **MySQL 8.0**：数据清洗、聚合查询、窗口函数（NTILE / RANK / ROW_NUMBER）、CTE、自连接
- **WPS / Excel**：数据透视与可视化（组合图、环形图）
