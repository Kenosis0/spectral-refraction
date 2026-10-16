class_name BeamData extends RefCounted

var source: Node
var is_powered: bool
var chain: Array[int]

func _init(beam_source: Node, powered: bool = false, passed_chain: Array[int] = []) -> void:
	source = beam_source
	is_powered = powered
	chain = passed_chain.duplicate()

func has_passed(instance_id: int) -> bool:
	return instance_id in chain

func forwarded_by(mirror: Node) -> BeamData:
	var next_chain := chain.duplicate()
	next_chain.append(mirror.get_instance_id())
	return BeamData.new(mirror, is_powered, next_chain)
