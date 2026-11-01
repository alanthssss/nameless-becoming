extends SceneTree
## Renderer regression: real effect sizes at pond and long-comparison coordinates.
## Draws the production helper; renderer errors are test failures in CI.
class PrecisionView extends "res://world_view.gd":
 var calls:=0
 func _process(_delta: float): pass
 func _draw():
  draw_rect(Rect2(0,0,1280,800),Color("243b35"))
  model=RefCounted.new() # Only enables the production helper's outline.
  calls=0
  for row in 4:
   var world_x: float=[0.0,32000.0,40000.0,64000.0][row]
   _world_offset=Vector2(80.0-world_x,0)
   draw_set_transform(_world_offset)
   for column in 32:
    var size: float=[1.4,2.3,4.5][column%3]
    _ellipse(Vector2(world_x+column*34,140+row*160),Vector2(size*1.5,size*0.6),Color("ffe1a3"),column*TAU/32)
    calls+=1
  _world_offset=Vector2(-39500,0)
  draw_set_transform(_world_offset)
  _ellipse(Vector2(40000,450),Vector2(2.1,0.84),Color("ff7f69"),deg_to_rad(16))
  calls+=1
  draw_set_transform(Vector2.ZERO)
func _initialize(): call_deferred("run")
func run():
 var view=PrecisionView.new()
 root.add_child(view)
 await process_frame
 await process_frame
 await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  var target=OS.get_environment("SWARM_ELLIPSE_CAPTURE")
  if not target.is_empty(): root.get_texture().get_image().save_png(target)
 var ok=view.calls==129
 print("ELLIPSE PRECISION VERIFIED: 129 production draws, ",0 if ok else 1," failures; renderer error log must also be empty")
 quit(0 if ok else 1)
