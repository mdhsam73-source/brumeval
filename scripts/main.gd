extends Node
## Relie le monde et l'interface, et gère la vie de l'appli (téléphone en arrière-plan, bouton retour).


func _ready() -> void:
	$UI.bind($World)


func _notification(what: int) -> void:
	match what:
		# Sur Android, l'appli peut être tuée en arrière-plan : on sauvegarde avant.
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			$World.write_save("auto")
		NOTIFICATION_WM_GO_BACK_REQUEST:
			$UI.go_back()
