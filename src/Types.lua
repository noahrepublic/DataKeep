local Signal = require(script.Parent.Parent.Signal)

type LoadMethodsEnum = {
	ForceLoad: string,
	Cancel: string,
}

export type UnReleasedHandler = (Keep.Session) -> string

export type Store<T> = {
	LoadMethods: LoadMethodsEnum,

	mockStore: boolean,
	assumeDeadLock: number,

	ServiceDone: boolean,

	CriticalState: boolean,

	CriticalStateSignal: Signal.Class,
	IssueSignal: Signal.Class,

	LoadKeep: (self: Store<T>, key: string, unreleasedHandler: UnReleasedHandler?) -> Promise<Keep>,
	ViewKeep: (self: Store<T>, key: string, version: string?) -> Promise<Keep>,

	PreSave: (self: Store<T>, callback: ({ any }) -> { any: any }) -> nil,
	PreLoad: (self: Store<T>, callback: ({ any }) -> { any: any }) -> nil,

	PostGlobalUpdate: (self: Store<T>, key: string, updateHandler: (GlobalUpdatesClass) -> nil) -> Promise<nil>,
}

export type Keep = {}

export type GlobalUpdate = {
	ID: number,
	Locked: boolean,
	Data: GlobalUpdateData,
}

export type GlobalUpdatesClass<T> = {
	AddGlobalUpdate: (self: GlobalUpdatesClass<T>, globalData: {}) -> Promise<number>,
	GetActiveUpdates: (self: GlobalUpdatesClass<T>) -> { [number]: { GlobalUpdate } },
	RemoveActiveUpdate: (self: GlobalUpdatesClass<T>, updateId: number) -> Promise<nil>,
	ChangeActiveUpdate: (self: GlobalUpdatesClass<T>, updateId: number, globalData: {}) -> Promise<nil>,
}

return {}
