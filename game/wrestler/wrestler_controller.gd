class_name WrestlerController
extends RefCounted
## Produces one frame of intent for a Wrestler. Subclasses fill these in update().

var move := Vector3.ZERO      ## desired world-space direction, length 0..1
var run_held := false
var block_held := false
var block_pressed := false    ## one-shot (pins a downed opponent)
var punch := false            ## one-shot (this frame)
var kick := false
var grapple := false
var taunt := false
var mash := false             ## any button this frame (getting up, escapes)


func update(_w: Wrestler, _delta: float) -> void:
	pass


func clear_one_shots() -> void:
	punch = false
	kick = false
	grapple = false
	taunt = false
	mash = false
	block_pressed = false
