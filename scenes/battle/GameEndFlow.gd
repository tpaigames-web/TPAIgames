## 胜利/失败/复活/无限模式 子系统
## 从 BattleScene.gd 提取
extends Node

signal game_ended_signal
signal endless_entered
signal request_reconnect_signals  ## 进入无限模式时需要 BattleScene 重连信号

var _game_ended: bool = false
var _revive_used: bool = false
var _revive_pending: bool = false
var _revive_dlg: Node = null

var _battle_scene: Node = null
var _wave_manager: Node = null
var _speed_btn: Button = null
var _wave_label: Label = null
var _disconnect_signals_fn: Callable


func init(battle_scene: Node, wave_mgr: Node, speed_btn: Button,
		wave_label: Label, disconnect_fn: Callable) -> void:
	_battle_scene = battle_scene
	_wave_manager = wave_mgr
	_speed_btn = speed_btn
	_wave_label = wave_label
	_disconnect_signals_fn = disconnect_fn


func is_ended() -> bool:
	return _game_ended

func set_ended(v: bool) -> void:
	_game_ended = v

func is_revive_pending() -> bool:
	return _revive_pending


## ── 复活广告流程 ─────────────────────────────────────────────────────

func offer_revive() -> void:
	_revive_pending = true
	Engine.time_scale = 0.0
	var dlg := ConfirmationDialog.new()
	_revive_dlg = dlg
	dlg.title = "💔 农场快撑不住了！"
	dlg.dialog_text = "农场 HP 归零！\n观看广告可获得一次免费复活机会\n复活后恢复 50% 生命值"
	dlg.ok_button_text = "📺 观看广告复活"
	dlg.cancel_button_text = "放弃"
	dlg.confirmed.connect(func():
		_revive_dlg = null
		dlg.queue_free()
		AdManager.show_rewarded_ad(
			func(): _do_revive(),
			func(): on_game_over()
		)
	)
	dlg.canceled.connect(func():
		_revive_dlg = null
		dlg.queue_free()
		on_game_over()
	)
	_battle_scene.add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.get_cancel_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()


func _do_revive() -> void:
	_revive_pending = false
	_revive_used = true
	GameManager.player_life = 50
	GameManager.hp_changed.emit(50)
	Engine.time_scale = 1.0
	if _speed_btn:
		_speed_btn.text = "1×"


func can_offer_revive() -> bool:
	return not _revive_used and not _revive_pending


## ── 游戏结束（HP 归零）────────────────────────────────────────────────

func on_game_over() -> void:
	if _game_ended:
		return
	_game_ended = true
	Engine.time_scale = 1.0
	GameManager.challenge_mode = false
	_disconnect_signals_fn.call()
	UserManager.games_played += 1
	UserManager.tutorial_completed = true

	var endless_line := ""
	if _wave_manager.is_endless:
		var day_key := "day%d" % GameManager.current_day
		var best: int = UserManager.best_endless_wave.get(day_key, 0)
		var reached: int = _wave_manager.current_wave
		if reached > best:
			UserManager.best_endless_wave[day_key] = reached
		endless_line = "\n🏆 无限模式到达: 第 %d 波（最高: %d）" % [reached, max(reached, best)]

	SaveManager.clear_battle_save()
	SaveManager.save()
	var carry_gold := GameManager.get_carry_out_gold()
	var dlg := AcceptDialog.new()
	dlg.title = "💀 游戏结束"
	dlg.dialog_text = "农场被攻破了！\n带出金币: %d 🪙\n下次再接再厉～" % carry_gold + endless_line
	dlg.confirmed.connect(func():
		GameManager.challenge_mode = false
		_battle_scene.get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")
	)
	dlg.canceled.connect(func():
		GameManager.challenge_mode = false
		_battle_scene.get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")
	)
	_battle_scene.add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()
	game_ended_signal.emit()


## ── 胜利（所有波次清场）──────────────────────────────────────────────

func on_victory() -> void:
	if _game_ended:
		return
	_game_ended = true
	Engine.time_scale = 1.0
	_disconnect_signals_fn.call()
	UserManager.games_played += 1
	UserManager.games_won   += 1
	if not UserManager.tutorial_completed:
		UserManager.newly_unlocked_day = 1
	UserManager.tutorial_completed = true
	SaveManager.clear_battle_save()
	_offer_double_reward()


func _offer_double_reward() -> void:
	var carry_gold := GameManager.get_carry_out_gold()
	var dlg := ConfirmationDialog.new()
	dlg.title = "🎉 教学完成！"
	dlg.dialog_text = (
		"恭喜守护农场成功！\n\n"
		+ "普通奖励: %d 🪙 + 200 XP\n" % carry_gold
		+ "双倍奖励: %d 🪙 + 400 XP（看广告获得）" % min(carry_gold * 2, GameManager.MAX_CARRY_OUT_GOLD * 2)
	)
	dlg.ok_button_text = "📺 双倍奖励"
	dlg.cancel_button_text = "领取普通奖励"
	dlg.confirmed.connect(func():
		dlg.queue_free()
		AdManager.show_rewarded_ad(
			func(): _finish_victory(true),
			func(): _finish_victory(false)
		)
	)
	dlg.canceled.connect(func():
		dlg.queue_free()
		_finish_victory(false)
	)
	_battle_scene.add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.get_cancel_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()


func _finish_victory(double_reward: bool) -> void:
	var carry_gold := GameManager.get_carry_out_gold()
	var xp_reward  := 200
	if double_reward:
		carry_gold = min(carry_gold * 2, GameManager.MAX_CARRY_OUT_GOLD * 2)
		xp_reward  = 400
	UserManager.add_xp(xp_reward)
	UserManager.add_gold(carry_gold)
	SaveManager.save()

	var hp := GameManager.player_life
	var stars: String
	var star_desc: String
	var star_count: int
	if hp >= 99:
		star_count = 3; stars = "★★★"; star_desc = "完美防守！"
	elif hp >= 50:
		star_count = 2; stars = "★★☆"; star_desc = "表现良好！"
	else:
		star_count = 1; stars = "★☆☆"; star_desc = "险险通关！"

	var day_num: int = GameManager.current_day
	var star_key := "day%d_challenge" % day_num if GameManager.challenge_mode else "day%d" % day_num
	var prev_stars: int = UserManager.level_stars.get(star_key, 0)
	UserManager.level_stars[star_key] = max(prev_stars, star_count)

	if not GameManager.challenge_mode and day_num == UserManager.max_unlocked_day and day_num < 15:
		UserManager.max_unlocked_day = day_num + 1
		UserManager.newly_unlocked_day = day_num + 1

	var chest_key := "day%d_challenge" % day_num if GameManager.challenge_mode else "day%d_normal" % day_num
	var chest_line := ""
	if not UserManager.level_chest_claimed.get(chest_key, false):
		UserManager.level_chest_claimed[chest_key] = true
		var rand := randf()
		var chest_type: int = 0
		if rand >= 0.70:
			chest_type = 1 if rand < 0.90 else 2
		var chest_name: String = ["木宝箱", "铁宝箱", "金宝箱"][chest_type]
		var added := UserManager.add_chest_to_slot(chest_type)
		SaveManager.save()
		if added:
			chest_line = "\n🎁 获得 %s！前往宝箱标签解锁" % chest_name
			_show_result_dialog(stars, star_desc, carry_gold, xp_reward, double_reward, chest_line)
		else:
			_offer_full_slots_ad(stars, star_desc, carry_gold, xp_reward, double_reward)
		return
	_show_result_dialog(stars, star_desc, carry_gold, xp_reward, double_reward, chest_line)


func _show_result_dialog(stars: String, star_desc: String,
		carry_gold: int, xp_reward: int,
		double_reward: bool, chest_line: String) -> void:
	var bonus_text := " 🎊×2" if double_reward else ""
	var can_endless: bool = GameManager.current_day > 0 and not _wave_manager.is_endless

	var dlg: AcceptDialog
	if can_endless:
		var cdlg := ConfirmationDialog.new()
		cdlg.ok_button_text = "♾️ 继续无限模式"
		cdlg.cancel_button_text = "返回主界面"
		cdlg.confirmed.connect(func():
			cdlg.queue_free()
			_enter_endless_mode()
		)
		cdlg.canceled.connect(func():
			GameManager.challenge_mode = false
			_battle_scene.get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")
		)
		dlg = cdlg
	else:
		dlg = AcceptDialog.new()
		dlg.confirmed.connect(func():
			GameManager.challenge_mode = false
			_battle_scene.get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")
		)

	dlg.title = "🎉 胜利！"
	var endless_line := ""
	if _wave_manager.is_endless:
		endless_line = "\n🏆 无限模式最高波数: %d" % _wave_manager.current_wave
	dlg.dialog_text = (
		"恭喜守护农场成功！\n"
		+ "评分: %s %s\n" % [stars, star_desc]
		+ "带出金币: %d 🪙%s\n" % [carry_gold, bonus_text]
		+ "获得 %d XP 奖励%s" % [xp_reward, bonus_text]
		+ chest_line
		+ endless_line
	)
	_battle_scene.add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	if dlg is ConfirmationDialog:
		dlg.get_cancel_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()
	game_ended_signal.emit()


func _enter_endless_mode() -> void:
	_game_ended = false
	request_reconnect_signals.emit()
	_wave_manager.enter_endless()
	if _wave_label:
		_wave_label.text = "♾️ 波次 %d" % _wave_manager.current_wave
	endless_entered.emit()


func _offer_full_slots_ad(stars: String, star_desc: String,
		carry_gold: int, xp_reward: int, double_reward: bool) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "🎁 宝箱槽位已满"
	dlg.dialog_text = "4 个槽位都占满了！\n看广告可以保留这个宝箱\n等有空槽位时再领取"
	dlg.ok_button_text = "📺 看广告保留"
	dlg.cancel_button_text = "放弃"
	var on_ad_complete := func():
		var r := randf()
		var ct: int = 0
		if r >= 0.70:
			ct = 1 if r < 0.90 else 2
		UserManager.pending_chest_type = ct
		SaveManager.save()
		_show_result_dialog(stars, star_desc, carry_gold, xp_reward, double_reward, "\n✅ 宝箱已保留！下次有空槽位时前往宝箱标签领取")
	var on_ad_cancel := func():
		_show_result_dialog(stars, star_desc, carry_gold, xp_reward, double_reward, "\n❌ 已丢失一个金宝箱！（清空槽位后可正常获得）")
	dlg.confirmed.connect(func():
		dlg.queue_free()
		AdManager.show_rewarded_ad(on_ad_complete, on_ad_cancel)
	)
	dlg.canceled.connect(func():
		dlg.queue_free()
		_show_result_dialog(stars, star_desc, carry_gold, xp_reward, double_reward, "\n❌ 已丢失一个金宝箱！（清空槽位后可正常获得）")
	)
	_battle_scene.add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.get_cancel_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()
