extends SceneTree
const Rain := preload("res://playtest/rain_route/route_model.gd")
const Spring := preload("res://playtest/spring/spring_model.gd")
const Driver := preload("res://tools/spring_driver.gd")

func _init() -> void:
	var m := Spring.new()
	m.configure(0)
	m.day = 15
	m.start_day()
	for i in range(240):
		m.step(1.0 / 60, Vector2.RIGHT, false)
	for i in range(90):
		m.step(1.0 / 60, Vector2.DOWN, false)
	for i in range(240):
		m.step(1.0 / 60, Vector2.ZERO, true)
	for i in range(5):
		assert(m.companions[i].position.distance_to(m.position) > 45, "Followers must leave the player silhouette clear")
		for j in range(i):
			assert(m.companions[i].position.distance_to(m.companions[j].position) > 38, "Formation must not settle into overlapping sprites")
	Driver.fly(m, m.HIVE)
	for i in range(180):
		m.step(1.0 / 60, Vector2.ZERO, true)
	assert(m.home_companions() == 5, "The wider formation must still bring all five home")
	m.configure(0)
	m.day = 4
	m.start_day()
	assert(not m.social.begin_dance(m), "No flower report without a source")
	Driver.fly(m, m.sources()[0])
	assert(m.act() == "load")
	assert(not m.social.begin_dance(m), "No aerial dance at a flower")
	Driver.fly(m, m.NECTAR_DESK)
	assert(m.act() == "deliver" and m.social.dance_kind == "round" and m.social.dance_age == 0)
	m.step(1.0 / 60, Vector2.ZERO, false)
	assert(m.social.dance_age > 0 and m.cargo == 0)
	m.step(1.0 / 60, Vector2.RIGHT, false)
	assert(m.social.dance_age < 0 and m.velocity.x > 0, "Movement interrupts immediately")
	assert(not m.social.offer_report(m), "Same-source deliveries must not repeatedly trigger a dance")
	m.position = m.HIVE
	m.social.remember_forage(m.PLACES["远花"])
	assert(m.social.begin_dance(m) and m.social.dance_kind == "waggle")
	var left := m.social.dance_point(m, 1.05)
	var right := m.social.dance_point(m, 2.45)
	assert(left.distance_to(right) > 45, "The waggle return loops must alternate sides")
	for i in range(420):
		m.step(1.0 / 60, Vector2.ZERO, false)
	assert(m.social.dance_age < 0 and m.position.distance_to(m.HIVE) < 80)
	assert(m.social.begin_dance(m))
	assert(m.act() == "day_end" and m.social.dance_age < 0, "Closing need not wait for the dance")
	var rain := Rain.new()
	rain.position = rain.FLOWERS
	assert(rain.act() == "load" and rain.social.source == rain.FLOWERS)
	rain.position = rain.HIVE
	assert(rain.social.begin_dance(rain) and rain.social.dance_kind == "waggle")
	print("BEE SOCIAL TEST PASSED: spaced turns, five arrivals, grounded source reports, two paths, interruption, closing and rain sharing")
	quit()
