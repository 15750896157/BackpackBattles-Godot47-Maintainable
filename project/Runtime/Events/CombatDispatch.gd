extends Node
## Ordered dispatch: logging precedes receivers; combat completion stops delivery.

enum LoggingMode { None = 0, Instant = 1, Delayed = 2 }
var loggingMode = LoggingMode.Instant
var signalQueue: Array = []
var connections: Dictionary = {}
var signalIDs: Dictionary = {}

func setLoggingMode(mode: int):
	loggingMode = mode

func getLoggingMode():
	return loggingMode

func queueSignal(emitter: Node, name: String, event: CombatEvent, arguments = []):
	signalQueue.append([emitter, name, event, arguments])

func flushLoggingQueue():
	loggingMode = LoggingMode.Instant
	var pending = signalQueue.duplicate()
	signalQueue.clear()
	for message in pending:
		emitAndLog.callv(message)

func emitSignal(emitter: Node, name: String, arguments = []):
	emitEvent(emitter, name, null, arguments)

func emitEvent(emitter: Node, name: String, event: CombatEvent, arguments = []):
	var delivery = queueSignal if loggingMode == LoggingMode.Delayed else emitAndLog
	delivery.call(emitter, name, event, arguments)

func logEvent(event: CombatEvent):
	emitEvent(null, "", event)

func emitAndLog(emitter: Node, name: String, event: CombatEvent, arguments: Array):
	if event != null:
		Game.combatLog.logEvent(event)
	if emitter == null or not signalIDs.has(name):
		return
	var key = getEmissionID(emitter, signalIDs[name])
	for receiver in connections.get(key, []):
		if Game.fightEnded:
			break
		receiver.callv(arguments)

func connectEvent(emitter: Node, name: String, receiver: Node, method: String):
	if not signalIDs.has(name):
		signalIDs[name] = signalIDs.size()
	var key = getEmissionID(emitter, signalIDs[name])
	if not connections.has(key):
		connections[key] = []
	connections[key].append(Callable(receiver, method))

func getEmissionID(emitter: Node, signal_id: int) -> int:
	return emitter.get_instance_id() + (signal_id << 32)

func disconnectAll():
	connections.clear()
