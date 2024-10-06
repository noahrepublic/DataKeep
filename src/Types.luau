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

export type wrapper<T> = T

--[=[
	@type StoreBase { LoadKeep: (string, unreleasedHandler?) -> Promise<Keep>, ViewKeep: (string) -> Promise<Keep>, PreLoad: (callback: (Data) -> Data) -> (), PreSave: (callback: (Data) -> Data) -> (), PostGlobalUpdate: (string, (GlobalUpdates) -> ()) -> Promise, validate: (data: Data) -> (boolean, string?) }
	@within Store

	Stores are used to load and save Keeps from a [DataStoreService:GetDataStore()](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetDataStore)
]=]

type storeBase<T, R> = {
	_storeInfo: storeInfo,
	_dataTemplate: dataTemplate<T>,

	_store: DataStore,
	_isMockEnabled: boolean,

	_preLoad: (any) -> any,
	_preSave: (any) -> any,

	_wrapper: wrapper<R>,

	validate: (data: data<T>) -> (boolean, string?),

	LoadKeep: (self: storeBase<T, R>, key: string, unreleasedHandler: unreleasedHandler?) -> PromiseTypes.TypedPromise<keep<T, R>>,
	ViewKeep: (self: storeBase<T, R>, key: string, version: string?) -> PromiseTypes.TypedPromise<keep<T, R>>,

	PreLoad: (self: storeBase<T, R>, callback: <T>(data<T>) -> data<T>) -> (),
	PreSave: (self: storeBase<T, R>, callback: <T>(data<T>) -> data<T>) -> (),

	PostGlobalUpdate: (self: storeBase<T, R>, key: string, updateHandler: (globalUpdatesClass) -> ()) -> PromiseTypes.Promise,
}

--[=[
	@type MockStore StoreBase
	@within Store

	MockStores are used to mirror the real store, but doesn't save data
]=]

export type mockStore<T, R> = storeBase<T, R>

--[=[
	@type Store StoreBase & { Mock: MockStore }
	@within Store

	Stores are used to load and save Keeps from a [DataStoreService:GetDataStore()](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetDataStore)
]=]

export type store<T, R> = storeBase<T, R> & {
	Mock: mockStore<T, R>,
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

export type keep<T, R> = keepStruct<T> & {
	_key: string,
	_storeInfo: { Name: string, Scope: string },

	_keep_store: store<T, R>,
	_store: DataStore,

	_dataTemplate: dataTemplate<T>,

	_keyInfo: DataStoreKeyInfo,
	_lastSaveAttempt: number,

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

	IsActive: (self: keep<T, R>) -> boolean,
	Identify: (self: keep<T, R>) -> string,
	GetKeyInfo: (self: keep<T, R>) -> DataStoreKeyInfo,

	Save: (self: keep<T, R>) -> PromiseTypes.Promise,
	Release: (self: keep<T, R>) -> PromiseTypes.Promise,
	Overwrite: (self: keep<T, R>, shouldKeepExistingSession: boolean?) -> PromiseTypes.Promise,
	Destroy: (self: keep<T, R>) -> (),

	Reconcile: (self: keep<T, R>) -> (),
	AddUserId: (self: keep<T, R>, userId: number) -> (),
	RemoveUserId: (self: keep<T, R>, userId: number) -> (),

	GetVersions: (self: keep<T, R>, minDate: number?, maxDate: number?) -> PromiseTypes.TypedPromise<iterator<T>>,
	SetVersion: (self: keep<T, R>, version: string, migrateProcessor: ((versionKeep: keep<T, R>) -> keep<T, R>)?) -> PromiseTypes.TypedPromise<keep<T, R>>,

	GetActiveGlobalUpdates: (self: keep<T, R>) -> { globalUpdate },
	GetLockedGlobalUpdates: (self: keep<T, R>) -> { globalUpdate },
	ClearLockedUpdate: (self: keep<T, R>, id: number) -> PromiseTypes.Promise,
} & R

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
	@type GlobalUpdate { Id: number, Locked: boolean, Data: GlobalUpdateData }
	@within GlobalUpdates
]=]

export type globalUpdate = {
	Id: number,
	Locked: boolean,
	Data: globalUpdateData,
}

--[=[
	@type GlobalUpdates { Id: number, Updates: { GlobalUpdate } }
	@within GlobalUpdates

	```Id``` is the most recent update index
]=]

export type globalUpdates = {
	Id: number,
	Updates: { globalUpdate },
}

export type globalUpdatesClass = typeof(setmetatable({}, {})) & {
	AddGlobalUpdate: (self: globalUpdatesClass, globalData: {}) -> PromiseTypes.TypedPromise<number>,
	ChangeActiveUpdate: (self: globalUpdatesClass, updateId: number, globalData: {}) -> PromiseTypes.Promise,
	RemoveActiveUpdate: (self: globalUpdatesClass, updateId: number) -> PromiseTypes.Promise,
	GetActiveUpdates: (self: globalUpdatesClass) -> { globalUpdate },
}

return nil
