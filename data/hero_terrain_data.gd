class_name HeroTerrainData extends Resource

## 英雄地形配置（圣地 / 领域 定义）

## 英雄 ID（与 TowerCollectionData.tower_id 对应）
@export var hero_id: String = ""

## 地形名称（如"丰收圣地"、"禁锢领域"）
@export var terrain_name: String = ""

## 地形颜色（金色 / 紫色，用于半透明圆绘制）
@export var terrain_color: Color = Color(1.0, 0.85, 0.2, 0.18)

## 初始半径（像素）
@export var base_radius: float = 180.0

## Lv1 基础效果描述
@export var base_effect_desc: String = ""

## 满级形态 A 描述
@export var max_form_a_desc: String = ""

## 满级形态 B 描述
@export var max_form_b_desc: String = ""

## 4 层升级选项（tier 1-4）
@export var upgrades: Array[HeroUpgradeData] = []
