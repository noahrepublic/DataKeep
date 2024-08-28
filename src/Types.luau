--!strict

local Signal = require(script.Parent.Parent.Signal)

local PromiseTypes = require(script.Parent.PromiseTypes)

--[=[
	@type StoreInfo { Name: string, Scope: string? }
	@within Store

	Table format for a store's info in [.GetStore()](#GetStore)
]=]

export type storeInfo = {
	Name: string,
	Scope: string?,
}

--[=[
	@type unreleasedHandler (Session) -> string
	@within Store

	Used to determine how to handle an session locked Keep.

	:::info
	Check [LoadMethods] for more info.
	:::info
]=]

export type unreleasedHandler = (session) -> string -- function for any purposes: logging, whitelist only certain places, etc.

export type dataTemplate<T> = T

export type wrapper<T> = any --{ [string]: <R..., U...>(self: keep<T>, R...) -> U... } Waiting for new solver?

--[=[
	@type StoreBase { LoadKeep: (string, unreleasedHandler?) -> Promise<Keep>, ViewKeep: (string) -> Promise<Keep>, PreLoad: (callback: (Data) -> Data) -> (), PreSave: (callback: (Data) -> Data) -> (), PostGlobalUpdate: (string, (GlobalUpdates) -> ()) -> Promise, Wrapper: { [string]: <R..., U...>(self: Keep, R...) -> U... }, validate: (data: Data) -> (boolean, string?) }
	@within Store

	Stores are used to load and save Keeps from a [DataStoreService:GetDataStore()](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetDataStore)
]=]

type storeBase<T> = {
	_storeInfo: storeInfo,
	_dataTemplate: dataTemplate<T>,

	_store: DataStore,
	_isMockEnabled: boolean,

	_preLoad: (any) -> any,
	_preSave: (any) -> any,

	Wrapper: wrapper<T>,

	validate: (data: data<T>) -> (boolean, string?),

	LoadKeep: (self: storeBase<T>, key: string, unreleasedHandler: unreleasedHandler?) -> PromiseTypes.TypedPromise<keep<T>>,
	ViewKeep: (self: storeBase<T>, key: string, version: string?) -> PromiseTypes.TypedPromise<keep<T>>,

	PreLoad: (self: storeBase<T>, callback: <T>(data<T>) -> data<T>) -> (),
	PreSave: (self: storeBase<T>, callback: <T>(data<T>) -> data<T>) -> (),

	PostGlobalUpdate: (self: storeBase<T>, key: string, updateHandler: (globalUpdatesClass) -> ()) -> PromiseTypes.Promise,
}

--[=[
	@type MockStore StoreBase
	@within Store

	MockStores are used to mirror the real store, but doesn't save data
]=]

export type mockStore<T> = storeBase<T>

--[=[
	@type Store StoreBase & { Mock: MockStore }
	@within Store

	Stores are used to load and save Keeps from a [DataStoreService:GetDataStore()](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetDataStore)
]=]

export type store<T> = storeBase<T> & {
	Mock: mockStore<T>,
}

--[=[
	@type Session { PlaceId: number, JobId: string }
	@within Keep
]=]

export type session = {
	PlaceId: number,
	JobId: string,
}

--[=[
	@type MetaData { ActiveSession: Session?, ForceLoad: Session?, LastUpdate: number, Created: number, LoadCount: number }
	@within Keep
]=]

export type metaData = {
	ActiveSession: session?,

	ForceLoad: session?, -- the session stealing the session lock, if any

	IsOverwriting: boolean?, -- true if .ActiveSession is found during :Overwrite()
	ReleaseSessionOnOverwrite: boolean?,

	LastUpdate: number,
	Created: number,
	LoadCount: number,
}

export type userIds = { number }
export type data<T> = dataTemplate<T>

export type keepStruct<T> = {
	Data: data<T>,
	MetaData: metaData,
	GlobalUpdates: globalUpdates,
	UserIds: userIds,
}

--[=[
	@type Keep { Data: { [string]: any }, MetaData: MetaData, GlobalUpdates: GlobalUpdates, UserIds: { number }, OnGlobalUpdate: Signal<GlobalUpdateData, number>, GlobalStateProcessor: (update: GlobalUpdateData, lock: () -> (), remove: () -> ()) -> (), Releasing: Signal<Promise>, Saving: Signal<Promise>, Overwritten: Signal<boolean> }
	@within Keep
]=]

export type keep<T> = keepStruct<T> & {
	_key: string,
	_storeInfo: { Name: string, Scope: string },

	_keep_store: store<T>,
	_store: DataStore,

	_dataTemplate: dataTemplate<T>,

	_keyInfo: DataStoreKeyInfo,
	_lastSave: number,

	_viewOnly: boolean,

	_releasing: boolean,
	_released: boolean,
	_destroyed: boolean,

	_pending_global_locks: { number },
	_pending_global_lock_removes: { number },

	Releasing: Signal.ScriptSignal<PromiseTypes.Promise>,
	Overwritten: Signal.ScriptSignal<boolean>,
	OnGlobalUpdate: Signal.ScriptSignal<globalUpdateData, number>,
	Saving: Signal.ScriptSignal<PromiseTypes.Promise>,

	GlobalStateProcessor: (updateData: globalUpdateData, lock: () -> (), remove: () -> ()) -> (),

	IsActive: (self: keep<T>) -> boolean,
	Identify: (self: keep<T>) -> string,
	GetKeyInfo: (self: keep<T>) -> DataStoreKeyInfo,

	Save: (self: keep<T>) -> PromiseTypes.Promise,
	Release: (self: keep<T>) -> PromiseTypes.Promise,
	Overwrite: (self: keep<T>, shouldKeepExistingSession: boolean?) -> PromiseTypes.Promise,
	Destroy: (self: keep<T>) -> (),

	Reconcile: (self: keep<T>) -> (),
	AddUserId: (self: keep<T>, userId: number) -> (),
	RemoveUserId: (self: keep<T>, userId: number) -> (),

	GetVersions: (self: keep<T>, minDate: number?, maxDate: number?) -> PromiseTypes.TypedPromise<iterator<T>>,
	SetVersion: (self: keep<T>, version: string, migrateProcessor: ((versionKeep: keep<T>) -> keep<T>)?) -> PromiseTypes.TypedPromise<keep<T>>,

	GetActiveGlobalUpdates: (self: keep<T>) -> { globalUpdate },
	GetLockedGlobalUpdates: (self: keep<T>) -> { globalUpdate },
	ClearLockedUpdate: (self: keep<T>, id: number) -> PromiseTypes.Promise,
}

export type iterator<T> = {
	Current: () -> DataStoreObjectVersionInfo?,
	Next: () -> DataStoreObjectVersionInfo?,
	Previous: () -> DataStoreObjectVersionInfo?,
	PageUp: () -> (),
	PageDown: () -> (),
	SkipEnd: () -> (),
	SkipStart: () -> (),
}

--[=[
	@type GlobalUpdateData { [any]: any }
	@within GlobalUpdates
]=]

type globalUpdateData = { [any]: any }

--[=[
	@type GlobalUpdate { ID: number, Locked: boolean, Data: GlobalUpdateData }
	@within GlobalUpdates
]=]

export type globalUpdate = {
	ID: number,
	Locked: boolean,
	Data: globalUpdateData,
}

--[=[
	@type GlobalUpdates { ID: number, Updates: { GlobalUpdate } }
	@within GlobalUpdates

	```ID``` is the most recent update index
]=]

export type globalUpdates = {
	ID: number,
	Updates: { globalUpdate },
}

export type globalUpdatesClass = typeof(setmetatable({}, {})) & {
	AddGlobalUpdate: (self: globalUpdatesClass, globalData: {}) -> PromiseTypes.TypedPromise<number>,
	ChangeActiveUpdate: (self: globalUpdatesClass, updateId: number, globalData: {}) -> PromiseTypes.Promise,
	RemoveActiveUpdate: (self: globalUpdatesClass, updateId: number) -> PromiseTypes.Promise,
	GetActiveUpdates: (self: globalUpdatesClass) -> { globalUpdate },
}

return nil
