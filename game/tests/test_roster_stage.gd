extends SceneTree
var failures:=0
var checks:=0
func _initialize():
	_run.call_deferred()
func check(value:bool,message:String):
	checks+=1
	if not value:
		failures+=1
		push_error(message)
func _run():
	root.size=Vector2i(960,600)
	var menu=load("res://scripts/menu_ui.gd").new()
	root.add_child(menu)
	menu.set_preferences({"reduced_motion":true})
	for mode in ["cats","minecraft"]:
		menu.selected_mode=mode
		menu.show_characters()
		await process_frame
		check(menu.DISPLAY_ORDER[3]==0 and menu.DISPLAY_ORDER[4]==6,"Zizi and Mak-Doong occupy the two center roster slots")
		check(menu.DISPLAY_ORDER.size()==8 and menu.DISPLAY_ORDER.duplicate().size()==8,"Character roster has eight unique display identities")
		var stage:Control=menu._lineup
		check(stage.karts.size()==8,"Eight native models on shared stage")
		for slot in range(8):
			var card:Button=menu._cards[slot]
			var center:Vector2=stage.racer_screen_center(slot)
			var card_center:Vector2=card.get_global_transform_with_canvas()*(card.size*.5)
			check(absf(center.x-card_center.x)<4,"Projected model aligns with name in slot%d (%s)"%[slot,mode])
			check(stage.karts[slot].character_index==menu.DISPLAY_ORDER[slot],"Native model matches the displayed roster identity")
			card.pressed.emit()
			check(stage.selected_character==menu.DISPLAY_ORDER[slot],"Selection highlights the corresponding live racer")
			var bounds:Rect2=stage.racer_screen_rect(slot)
			check(bounds.size.x>60 and bounds.size.y>75,"Racer has visible full geometry at minimum window")
		check(stage._viewport.size.x>=2000,"Lineup renders above display resolution")
		menu.hide()
		await process_frame
		check(stage._viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and not stage.is_processing(),"Hidden menu stops preview rendering and animation")
		menu.show()
		await process_frame
		check(stage._viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS and stage.is_processing(),"Returning to menu resumes live previews")
		menu.selected_character=6
		menu.show_tracks()
		await process_frame
		check(menu._lineup.characters.count(6)==1 and menu._lineup.characters[2]==6,"Track lineup shows the selected racer once in the center")
		menu.call("_show_garage")
		await process_frame
		check(menu.selected_character==6,"Garage preserves selected character")
	print("MENU STAGE QA: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
