class_name ViewModel
extends RefCounted
## 表现模型层基类。M0 仅定义契约，不接入生产场景。
## 1. VM 是视图侧唯一允许调用领域服务的入口，命令由 VM 转发。
## 2. 从领域服务快照投影该屏需要的字段，不持有权威数据。
## 3. UI 只订阅 changed 和调用命令方法，禁止直接读写 Game/Expedition。

signal changed

func snapshot() -> Dictionary:
	push_error("ViewModel.snapshot() 必须由子类实现")
	return {}
