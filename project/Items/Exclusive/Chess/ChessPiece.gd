extends Item
class_name ChessPiece

var destroyParticlesScene = load("res://Items/Animations/DestroyParticles.tscn")
var noBoardMarkScene = load("res://Items/Animations/NotInChainMark.tscn")
const captureSounds = [
	preload("res://Assets/Sound/Chess1.ogg"),
	preload("res://Assets/Sound/Chess2.ogg"),
	preload("res://Assets/Sound/Chess3.ogg")]

enum PieceColor{
	Black = 0,
	White = 1,
}

var pieceColor: int
var moveCells: Array

var captured: bool
var numCaptures: int

var board = null
var noBoardMark = null

func canAffect(item):
	return item.hasType(Type.ChessPiece) and item.pieceColor != pieceColor

func affectsEmpty(color):
	return true

func _ready():
	super._ready()
	if "White" in name:
		pieceColor = PieceColor.White
	else:
		pieceColor = PieceColor.Black

func setBoard(_board):
	board = _board
	if board == null and placed:
		noBoardMark.appear()
	else:
		noBoardMark.disappear()

func prepare():
	setState(occupiedCells[0])

	moveCells.clear()
	for cell in getAffectedCells_tilemap():
		moveCells.push_back(cell.rotated(rotation).round())

	numCaptures = 0

	super.prepare()

func getMoveCells():
	return moveCells

func getCaptureCells():
	return moveCells

func onPieceMoved(targetCell):

	setState(targetCell)

func onPieceCaptured(eliminatedPiece, activateEvent):
	return load("res://Runtime/Behavior/Features/Items/Exclusive/Chess/ChessPieceBehavior.gd").onPieceCaptured(self, eliminatedPiece, activateEvent)

func doCapturingEffect(eliminatedPiece):
	pass

func onEliminatedBy(capturingPiece, activateEvent):
	return load("res://Runtime/Behavior/Features/Items/Exclusive/Chess/ChessPieceBehavior.gd").onEliminatedBy(self, capturingPiece, activateEvent)

func doEliminatedEffect(capturingPiece):
	pass

func repositionPiece(toCell):
	return load("res://Runtime/Behavior/Features/Items/Exclusive/Chess/ChessPieceBehavior.gd").repositionPiece(self, toCell)

func onShopEntered():
	onStateChanged(false)

func onStateChanged(state):
	return load("res://Runtime/Behavior/Features/Items/Exclusive/Chess/ChessPieceBehavior.gd").onStateChanged(self, state)

func onAddToInventory():
	return load("res://Runtime/Behavior/Features/Items/Exclusive/Chess/ChessPieceBehavior.gd").onAddToInventory(self)

func onRemoveFromInventory():
	if noBoardMark != null:
		noBoardMark.disappear()

func getDescription(wrapInColor = true) -> String:
	var descr = super.getDescription(wrapInColor)
	if placed and board == null:
		descr += "\n\n" + Util.wrapInColor(tr("HINT_Chess"), Util.paramColor)
	return descr

func discard(discardGems = true):
	super.discard(discardGems)
	if noBoardMark != null:
		ObjectPool.returnInstance(noBoardMark)
		noBoardMark = null

func canBeBlocked() -> bool:
	return true
