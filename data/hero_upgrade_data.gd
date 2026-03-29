class_name HeroUpgradeData extends Resource

## 英雄单层升级的 A / B 选项数据

## 升级层级（1-4 对应 Lv2-Lv5）
@export var tier: int = 1

## 触发波次（5 / 10 / 15 / 20）
@export var wave_trigger: int = 5

## A 选项
@export var option_a_name: String = ""
@export var option_a_desc: String = ""
@export var option_a_icon: String = "🅰️"

## B 选项
@export var option_b_name: String = ""
@export var option_b_desc: String = ""
@export var option_b_icon: String = "🅱️"
