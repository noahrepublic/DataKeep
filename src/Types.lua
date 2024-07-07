--!strict

local PromiseTypes = require(script.Parent.PromiseTypes)

export type Signal<T> = {
	Is: (object: any) -> boolean,

	IsActive: (self: Signal<T>) -> boolean,
	Connect: (self: Signal<T>, handler: (...any) -> ()) -> ScriptConnection<T>,
	Once: (self: Signal<T>, handler: (...any) -> ()) -> ScriptConnection<T>,
	ConnectOnce: (self: Signal<T>, handler: (...any) -> ()) -> ScriptConnection<T>,

	Wait: (self: Signal<T>) -> ...any,
	Fire: (self: Signal<T>, any: any) -> nil,
	DisconnectAll: (self: Signal<T>) -> nil,
	Destroy: (self: Signal<T>) -> nil,
}

export type ScriptConnection<T> = {
	Connected: boolean,

	Disconnect: (self: ScriptConnection<T>) -> nil,
	Destroy: (self: ScriptConnection<T>) -> nil,
}

type LoadMethodsEnum = {
	ForceLoad: string,
	Cancel: string,
}

export type dataTemplate = any

export type UnReleasedHandler = (Session) -> string

export type StoreInfo = {
	Name: string,
	Scope: string?,
}

export type Store<T> = {
	LoadMethods: LoadMethodsEnum,

	mockStore: boolean,
	assumeDeadLock: number,

	ServiceDone: boolean,

	CriticalState: boolean,

	CriticalStateSignal: Signal<T>,
	IssueSignal: Signal<T>,

	GetStore: (self: Store<T>, storeInfo: StoreInfo | string, dataTemplate: any) -> PromiseTypes.TypedPromise<Store<T>>,

	LoadKeep: (self: Store<T>, key: string, unreleasedHandler: UnReleasedHandler?) -> PromiseTypes.TypedPromise<Keep<T>>,
	ViewKeep: (self: Store<T>, key: string, version: string?) -> PromiseTypes.TypedPromise<Keep<T>>,

	PreSave: (self: Store<T>, callback: ({ any }) -> { any: any }) -> nil,
	PreLoad: (self: Store<T>, callback: ({ any }) -> { any: any }) -> nil,

	PostGlobalUpdate: (self: Store<T>, key: string, updateHandler: (GlobalUpdatesClass<T>) -> nil) -> PromiseTypes.TypedPromise<nil>,

	Wrapper: { [string]: (any) -> any },
}

export type Session = {
	PlaceID: number,
	JobID: string,
}

export type MetaData = {
	ActiveSession: Session?,

	ForceLoad: Session?, -- the session stealing the session lock, if any

	IsOverwriting: boolean?, -- true if .ActiveSession is found during :Overwrite()
	ReleaseSessionOnOverwrite: boolean?,

	LastUpdate: number,
	Created: number,
	LoadCount: number,
}

export type UserIds = { [number]: number }
export type Data = any -- can be set to whatever they want, though optimally a table.

export type KeepStruct<T> = {
	Data: Data,

	MetaData: MetaData,
	GlobalUpdates: GlobalUpdates,

	UserIds: UserIds,
}

export type Keep<T> = {
	assumeDeadLock: number,
	ServiceDone: boolean,

	Data: Data,
	MetaData: MetaData,
	GlobalUpdates: GlobalUpdates,
	UserIds: UserIds,
	LatestKeep: KeepStruct<T>,

	Releasing: Signal<T>,
	Overwritten: Signal<T>,
	OnGlobalUpdate: Signal<T>,
	Saving: Signal<T>,

	GlobalStateProcessor: (GlobalUpdate, lock: () -> nil, remove: () -> nil) -> nil, -- why were these functions marked as returning a boolean?

	-- Methods

	Save: (self: Keep<T>) -> PromiseTypes.TypedPromise<Keep<T>>, -- why does it return itself?
	Overwrite: (self: Keep<T>, releaseExistingSession: boolean?) -> PromiseTypes.TypedPromise<Keep<T>>,

	IsActive: (self: Keep<T>) -> boolean,
	Identify: (self: Keep<T>) -> string,
	GetKeyInfo: (self: Keep<T>) -> DataStoreKeyInfo,

	Release: (self: Keep<T>) -> PromiseTypes.TypedPromise<Keep<T>>,

	Reconcile: (self: Keep<T>) -> nil,
	AddUserId: (self: Keep<T>, userId: number) -> nil,
	RemoveUserId: (self: Keep<T>, userId: number) -> nil,

	-- Versioning
	GetVersions: (self: Keep<T>, minDate: number?, maxDate: number?) -> PromiseTypes.TypedPromise<Iterator<T>>,
	SetVersion: (self: Keep<T>, version: string, migrateProcessor: ((versionKeep: Keep<T>) -> Keep<T>)?) -> PromiseTypes.TypedPromise<Keep<T>>,

	GetActiveGlobalUpdates: (self: Keep<T>) -> { [number]: GlobalUpdate },
	GetLockedGlobalUpdates: (self: Keep<T>) -> { [number]: GlobalUpdate },
	ClearLockedUpdate: (self: Keep<T>, id: number) -> PromiseTypes.TypedPromise<nil>,
}

export type Iterator<T> = {
	Current: () -> DataStoreObjectVersionInfo,
	Next: () -> DataStoreObjectVersionInfo,
	Previous: () -> DataStoreObjectVersionInfo,
	PageUp: () -> DataStoreObjectVersionInfo,
	PageDown: () -> DataStoreObjectVersionInfo,
	SkipEnd: () -> DataStoreObjectVersionInfo,
	SkipStart: () -> DataStoreObjectVersionInfo,
}

type GlobalUpdateData = { [any]: any }

export type GlobalUpdate = {
	ID: number,
	Locked: boolean,
	Data: GlobalUpdateData,
}

type GlobalUpdates = {
	ID: number,
	Updates: { GlobalUpdate },
}

export type GlobalUpdatesClass<T> = {
	AddGlobalUpdate: (self: GlobalUpdatesClass<T>, globalData: {}) -> PromiseTypes.TypedPromise<number>,
	GetActiveUpdates: (self: GlobalUpdatesClass<T>) -> { [number]: { GlobalUpdate } },
	RemoveActiveUpdate: (self: GlobalUpdatesClass<T>, updateId: number) -> PromiseTypes.TypedPromise<nil>,
	ChangeActiveUpdate: (self: GlobalUpdatesClass<T>, updateId: number, globalData: {}) -> PromiseTypes.TypedPromise<nil>,
}

return nil
