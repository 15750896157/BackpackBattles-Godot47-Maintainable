extends RefCounted
class_name ItemPool

var pool: Array
var topIndex: int
var sellPrice = false
var deleteAfterDraw: bool = false

func resetPool():
	pool.clear()

func addItem(item):
	if not item.isReleased():
		print("missing item: ", item.itemIndex)
		return
	pool.push_back(item)

func sortItems():
	pool.sort_custom(Callable(ItemSorter, "sortPrice"))
	topIndex = pool.size() - 1

func resetPrice():
	topIndex = pool.size() - 1

func setPrice(price: int):
	return load("res://Runtime/Callbacks/Utility/CallbacksI.gd").ForItemPool.setPrice(self, price)

func removeItem(index):
	pool.remove_at(index)
	if index <= topIndex:
		topIndex -= 1

func getItem(index):
	return load("res://Runtime/Callbacks/Utility/CallbacksI.gd").ForItemPool.getItem(self, index)

func getRandomItem():
	var index = Util.rng.randi_range(0, topIndex)
	return getItem(index)

func getRandomItemWithinQuantile(quantile: float):
	var lowerBound = int(topIndex * quantile)
	return getItem(Util.rng.randi_range(lowerBound, topIndex))

func getRandomItemTopHeavy(topQuantileChance = 0.9, topQuantile = 0.5):
	if Util.flip(topQuantileChance):
		return getRandomItemWithinQuantile(topQuantile)
	else:
		return getRandomItem()

func printPool():
	print("POOL START")
	for item in pool:
		print(item.getName())
	print("POOL END")

class ItemSorter:
	static func sortPrice(item1, item2):
		return item1.getPrice() < item2.getPrice()
