local Signal = require(script.Parent.Parent.Signal)

type LoadMethodsEnum = {
	ForceLoad: string,
	Cancel: string,
}

export type UnReleasedHandler = (Session) -> string

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

	Releasing: Signal.Class,
	Overwritten: Signal.Class,
	OnGlobalUpdate: Signal.Class,
	Saving: Signal.Class,

	GlobalStateProcessor: (GlobalUpdate, lock: () -> nil, remove: () -> nil) -> nil, -- why were these functions marked as returning a boolean?

	-- Methods

	Save: (self: Keep<T>) -> Promise<Keep<T>>, -- why does it return itself?
	Overwrite: (self: Keep<T>, releaseExistingSession: boolean?) -> Promise<Keep<T>>,

	IsActive: (self: Keep<T>) -> boolean,
	Identify: (self: Keep<T>) -> string,
	GetKeyInfo: (self: Keep<T>) -> DataStoreKeyInfo,

	Release: (self: Keep<T>) -> Promise<Keep<T>>,

	Reconcile: (self: Keep<T>) -> nil,
	AddUserId: (self: Keep<T>, userId: number) -> nil,
	RemoveUserId: (self: Keep<T>, userId: number) -> nil,

	-- Versioning
	GetVersions: (self: Keep<T>, minDate: number?, maxDate: number?) -> Promise<Iterator<T>>,
	SetVersion: (self: Keep<T>, version: string, migrateProcessor: ((versionKeep: Keep<T>) -> Keep<T>)?) -> Promise<Keep<T>>,

	GetActiveGlobalUpdates: (self: Keep<T>) -> { [number]: GlobalUpdate },
	GetLockedGlobalUpdates: (self: Keep<T>) -> { [number]: GlobalUpdate },
	ClearLockedUpdate: (self: Keep<T>, id: number) -> Promise<nil>,
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
	AddGlobalUpdate: (self: GlobalUpdatesClass<T>, globalData: {}) -> Promise<number>,
	GetActiveUpdates: (self: GlobalUpdatesClass<T>) -> { [number]: { GlobalUpdate } },
	RemoveActiveUpdate: (self: GlobalUpdatesClass<T>, updateId: number) -> Promise<nil>,
	ChangeActiveUpdate: (self: GlobalUpdatesClass<T>, updateId: number, globalData: {}) -> Promise<nil>,
}

return {}
