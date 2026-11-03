extends RefCounted
## Original motion curves. Waggle/alternating loops evoke bee communication;
## side-step is an extensible, project-authored anthropomorphic clip.
const COMMIT := 1.55
const DURATION := 2.05
const SHORT_COMMIT := 0.18
const SHORT_DURATION := 0.40

static func pose(t: float, style: String, follower := 0) -> Dictionary:
	var phase := maxf(0,t-0.18-follower*0.08)
	var envelope := smoothstep(0.0,0.20,phase)* (1.0-smoothstep(1.18,1.48,phase))
	var offset := Vector2.ZERO
	var tilt := 0.0
	if style == "side_step":
		offset = Vector2(sin(phase*TAU*2)*25,-absf(sin(phase*TAU*2))*7)*envelope
		tilt = sin(phase*TAU*4)*0.19*envelope
	else:
		# A short waggle run followed by alternating return arcs, not a biology simulation.
		var cycle := fposmod(phase,0.6)/0.6
		if cycle < 0.4:
			offset = Vector2(sin(phase*65)*4,lerpf(10,-12,cycle/0.4))*envelope
			tilt = sin(phase*65)*0.14*envelope
		else:
			var arc := (cycle-0.4)/0.6*PI
			var side := 1.0 if int(phase/0.6)%2 == 0 else -1.0
			offset = Vector2(sin(arc)*28*side,-cos(arc)*12)*envelope
			tilt = sin(arc)*0.2*side*envelope
	return {"offset":offset,"face":Vector2(1,tilt)}
