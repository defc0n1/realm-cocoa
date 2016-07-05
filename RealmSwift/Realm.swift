////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Foundation
import Realm
import Realm.Private

#if swift(>=3.0)

/**
A Realm instance (also referred to as "a realm") represents a Realm
database.

Realms can either be stored on disk (see `init(path:)`) or in
memory (see `Configuration`).

Realm instances are cached internally, and constructing equivalent Realm
objects (with the same path or identifier) produces limited overhead.

If you specifically want to ensure a Realm object is
destroyed (for example, if you wish to open a realm, check some property, and
then possibly delete the realm file and re-open it), place the code which uses
the realm within an `autoreleasepool {}` and ensure you have no other
strong references to it.

- warning: Realm instances are not thread safe and can not be shared across
           threads or dispatch queues. You must construct a new instance on each thread you want
           to interact with the realm on. For dispatch queues, this means that you must
           call it in each block which is dispatched, as a queue is not guaranteed to run
           on a consistent thread.
*/
public final class Realm {

    // MARK: Properties

    /// The Schema used by this realm.
    public var schema: Schema { return Schema(rlmRealm.schema) }

    /// Returns the `Configuration` that was used to create this `Realm` instance.
    public var configuration: Configuration { return Configuration.fromRLMRealmConfiguration(rlmConfiguration: rlmRealm.configuration) }

    /// Indicates if this Realm contains any objects.
    public var isEmpty: Bool { return rlmRealm.isEmpty }

    // MARK: Initializers

    /**
    Obtains a Realm instance with the default Realm configuration, which can be
    changed by setting `Realm.Configuration.defaultConfiguration`.

    - throws: An NSError if the Realm could not be initialized.
    */
    public convenience init() throws {
        let rlmRealm = try RLMRealm(configuration: RLMRealmConfiguration.default())
        self.init(rlmRealm)
    }

    /**
    Obtains a Realm instance with the given configuration.

    - parameter configuration: The configuration to use when creating the Realm instance.

    - throws: An NSError if the Realm could not be initialized.
    */
    public convenience init(configuration: Configuration) throws {
        let rlmRealm = try RLMRealm(configuration: configuration.rlmConfiguration)
        self.init(rlmRealm)
    }

    /**
    Obtains a Realm instance persisted at the specified file URL.

    - parameter fileURL: Local URL to the realm file.

    - throws: An NSError if the Realm could not be initialized.
    */
    public convenience init(fileURL: URL) throws {
        var configuration = Configuration.defaultConfiguration
        configuration.fileURL = fileURL
        try self.init(configuration: configuration)
    }

    // MARK: Transactions

    /**
    Performs actions contained within the given block inside a write transaction.

    Write transactions cannot be nested, and trying to execute a write transaction
    on a `Realm` which is already in a write transaction will throw an exception.
    Calls to `write` from `Realm` instances in other threads will block
    until the current write transaction completes.

    Before executing the write transaction, `write` updates the `Realm` to the
    latest Realm version, as if `refresh()` was called, and generates notifications
    if applicable. This has no effect if the `Realm` was already up to date.

    - parameter block: The block to be executed inside a write transaction.

    - throws: An NSError if the transaction could not be written.
    */
    public func write(block: @noescape () -> Void) throws {
        try rlmRealm.transaction(block)
    }

    /**
    Begins a write transaction in a `Realm`.

    Only one write transaction can be open at a time. Write transactions cannot be
    nested, and trying to begin a write transaction on a `Realm` which is
    already in a write transaction will throw an exception. Calls to
    `beginWrite` from `Realm` instances in other threads will block
    until the current write transaction completes.

    Before beginning the write transaction, `beginWrite` updates the
    `Realm` to the latest Realm version, as if `refresh()` was called, and
    generates notifications if applicable. This has no effect if the `Realm`
    was already up to date.

    It is rarely a good idea to have write transactions span multiple cycles of
    the run loop, but if you do wish to do so you will need to ensure that the
    `Realm` in the write transaction is kept alive until the write transaction
    is committed.
    */
    public func beginWrite() {
        rlmRealm.beginWriteTransaction()
    }

    /**
    Commits all writes operations in the current write transaction, and ends
    the transaction.

    Calling this when not in a write transaction will throw an exception.

    - throws: An NSError if the transaction could not be written.
    */
    public func commitWrite() throws {
        try rlmRealm.commitWriteTransaction()
    }

    /**
    Reverts all writes made in the current write transaction and end the transaction.

    This rolls back all objects in the Realm to the state they were in at the
    beginning of the write transaction, and then ends the transaction.

    This restores the data for deleted objects, but does not revive invalidated
    object instances. Any `Object`s which were added to the Realm will be
    invalidated rather than switching back to standalone objects.
    Given the following code:

    ```swift
    let oldObject = objects(ObjectType).first!
    let newObject = ObjectType()

    realm.beginWrite()
    realm.add(newObject)
    realm.delete(oldObject)
    realm.cancelWrite()
    ```

    Both `oldObject` and `newObject` will return `true` for `invalidated`,
    but re-running the query which provided `oldObject` will once again return
    the valid object.

    Calling this when not in a write transaction will throw an exception.
    */
    public func cancelWrite() {
        rlmRealm.cancelWriteTransaction()
    }

    /**
    Indicates if this Realm is currently in a write transaction.

    - warning: Wrapping mutating operations in a write transaction if this property returns `false`
               may cause a large number of write transactions to be created, which could negatively
               impact Realm's performance. Always prefer performing multiple mutations in a single
               transaction when possible.
    */
    public var isInWriteTransaction: Bool {
        return rlmRealm.inWriteTransaction
    }

    // MARK: Adding and Creating objects

    /**
    Adds or updates an object to be persisted it in this Realm.

    When 'update' is 'true', the object must have a primary key. If no objects exist in
    the Realm instance with the same primary key value, the object is inserted. Otherwise,
    the existing object is updated with any changed values.

    When added, all (child) relationships referenced by this object will also be
    added to the Realm if they are not already in it. If the object or any related
    objects already belong to a different Realm an exception will be thrown. Use one
    of the `create` functions to insert a copy of a persisted object into a different
    Realm.

    The object to be added must be valid and cannot have been previously deleted
    from a Realm (i.e. `invalidated` must be false).

    - parameter object: Object to be added to this Realm.
    - parameter update: If true will try to update existing objects with the same primary key.
    */
    public func add(_ object: Object, update: Bool = false) {
        if update && object.objectSchema.primaryKeyProperty == nil {
            throwRealmException("'\(object.objectSchema.className)' does not have a primary key and can not be updated")
        }
        RLMAddObjectToRealm(object, rlmRealm, update)
    }

    /**
    Adds or updates objects in the given sequence to be persisted it in this Realm.

    - see: add(_:update:)

    - warning: This method can only be called during a write transaction.

    - parameter objects: A sequence which contains objects to be added to this Realm.
    - parameter update: If true will try to update existing objects with the same primary key.
    */
    public func add<S: Sequence where S.Iterator.Element: Object>(_ objects: S, update: Bool = false) {
        for obj in objects {
            add(obj, update: update)
        }
    }

    /**
    Create an `Object` with the given value.

    Creates or updates an instance of this object and adds it to the `Realm` populating
    the object with the given value.

    When 'update' is 'true', the object must have a primary key. If no objects exist in
    the Realm instance with the same primary key value, the object is inserted. Otherwise,
    the existing object is updated with any changed values.

    - warning: This method can only be called during a write transaction.

    - parameter type:   The object type to create.
    - parameter value:  The value used to populate the object. This can be any key/value coding compliant
                        object, or a JSON dictionary such as those returned from the methods in `NSJSONSerialization`,
                        or an `Array` with one object for each persisted property. An exception will be
                        thrown if any required properties are not present and no default is set.
                        When passing in an `Array`, all properties must be present,
                        valid and in the same order as the properties defined in the model.
    - parameter update: If true will try to update existing objects with the same primary key.

    - returns: The created object.
    */
    @discardableResult
    public func createObject<T: Object>(ofType type: T.Type, populatedWith value: AnyObject = [:], update: Bool = false) -> T {
        let typeName = (type as Object.Type).className()
        if update && schema[typeName]?.primaryKeyProperty == nil {
            throwRealmException("'\(typeName)' does not have a primary key and can not be updated")
        }
        return unsafeBitCast(RLMCreateObjectInRealmWithValue(rlmRealm, typeName, value, update), to: T.self)
    }

    /**
    This method is useful only in specialized circumstances, for example, when building
    components that integrate with Realm. If you are simply building an app on Realm, it is
    recommended to use the typed method `create(_:value:update:)`.

    Creates or updates an object with the given class name and adds it to the `Realm`, populating
    the object with the given value.

    When 'update' is 'true', the object must have a primary key. If no objects exist in
    the Realm instance with the same primary key value, the object is inserted. Otherwise,
    the existing object is updated with any changed values.

    - warning: This method can only be called during a write transaction.

    - parameter className:  The class name of the object to create.
    - parameter value:      The value used to populate the object. This can be any key/value coding compliant
    object, or a JSON dictionary such as those returned from the methods in `NSJSONSerialization`,
    or an `Array` with one object for each persisted property. An exception will be
    thrown if any required properties are not present and no default is set.

    When passing in an `Array`, all properties must be present,
    valid and in the same order as the properties defined in the model.
    - parameter update:     If true will try to update existing objects with the same primary key.

    - returns: The created object.

    :nodoc:
    */
    @discardableResult
    public func createDynamicObject(ofType typeName: String, populatedWith value: AnyObject = [:], update: Bool = false) -> DynamicObject {
        if update && schema[typeName]?.primaryKeyProperty == nil {
            throwRealmException("'\(typeName)' does not have a primary key and can not be updated")
        }
        return unsafeBitCast(RLMCreateObjectInRealmWithValue(rlmRealm, typeName, value, update), to: DynamicObject.self)
    }

    // MARK: Deleting objects

    /**
    Deletes the given object from this Realm.

    - warning: This method can only be called during a write transaction.

    - parameter object: The object to be deleted.
    */
    public func delete(_ object: Object) {
        RLMDeleteObjectFromRealm(object, rlmRealm)
    }

    /**
    Deletes the given objects from this Realm.

    - warning: This method can only be called during a write transaction.

    - parameter objects: The objects to be deleted. This can be a `List<Object>`, `Results<Object>`,
                         or any other enumerable SequenceType which generates Object.
    */
    public func delete<S: Sequence where S.Iterator.Element: Object>(_ objects: S) {
        for obj in objects {
            delete(obj)
        }
    }

    /**
    Deletes the given objects from this Realm.

    - warning: This method can only be called during a write transaction.

    - parameter objects: The objects to be deleted. Must be `List<Object>`.

    :nodoc:
    */
    public func delete<T: Object>(_ objects: List<T>) {
        rlmRealm.deleteObjects(objects._rlmArray)
    }

    /**
    Deletes the given objects from this Realm.

    - warning: This method can only be called during a write transaction.

    - parameter objects: The objects to be deleted. Must be `Results<Object>`.

    :nodoc:
    */
    public func delete<T: Object>(_ objects: Results<T>) {
        rlmRealm.deleteObjects(objects.rlmResults)
    }

    /**
    Deletes all objects from this Realm.

    - warning: This method can only be called during a write transaction.
    */
    public func deleteAllObjects() {
        RLMDeleteAllObjectsFromRealm(rlmRealm)
    }

    // MARK: Object Retrieval

    /**
    Returns all objects of the given type in the Realm.

    - parameter type: The type of the objects to be returned.

    - returns: All objects of the given type in Realm.
    */
    public func allObjects<T: Object>(ofType type: T.Type) -> Results<T> {
        return Results<T>(RLMGetObjects(rlmRealm, (type as Object.Type).className(), nil))
    }

    /**
    This method is useful only in specialized circumstances, for example, when building
    components that integrate with Realm. If you are simply building an app on Realm, it is
    recommended to use the typed method `objects(type:)`.

    Returns all objects for a given class name in the Realm.

    - warning: This method is useful only in specialized circumstances.

    - parameter className: The class name of the objects to be returned.

    - returns: All objects for the given class name as dynamic objects

    :nodoc:
    */
    public func allDynamicObjects(ofType typeName: String) -> Results<DynamicObject> {
        return Results<DynamicObject>(RLMGetObjects(rlmRealm, typeName, nil))
    }

    /**
    Get an object with the given primary key.

    Returns `nil` if no object exists with the given primary key.

    This method requires that `primaryKey()` be overridden on the given subclass.

    - see: Object.primaryKey()

    - parameter type: The type of the objects to be returned.
    - parameter key:  The primary key of the desired object.

    - returns: An object of type `type` or `nil` if an object with the given primary key does not exist.
    */
    public func object<T: Object>(ofType type: T.Type, forPrimaryKey key: AnyObject) -> T? {
        return unsafeBitCast(RLMGetObject(rlmRealm, (type as Object.Type).className(), key), to: Optional<T>.self)
    }

    /**
    This method is useful only in specialized circumstances, for example, when building
    components that integrate with Realm. If you are simply building an app on Realm, it is
    recommended to use the typed method `objectForPrimaryKey(_:key:)`.

    Get a dynamic object with the given class name and primary key.

    Returns `nil` if no object exists with the given class name and primary key.

    This method requires that `primaryKey()` be overridden on the given subclass.

    - see: Object.primaryKey()

    - warning: This method is useful only in specialized circumstances.

    - parameter className:  The class name of the object to be returned.
    - parameter key:        The primary key of the desired object.

    - returns: An object of type `DynamicObject` or `nil` if an object with the given primary key does not exist.

    :nodoc:
    */
    public func dynamicObject(ofType typeName: String, forPrimaryKey key: AnyObject) -> DynamicObject? {
        return unsafeBitCast(RLMGetObject(rlmRealm, typeName, key), to: Optional<DynamicObject>.self)
    }

    // MARK: Notifications

    /**
    Add a notification handler for changes in this Realm.

    Notification handlers are called after each write transaction is committed,
    independent from the thread or process.

    The block is called on the same thread as it was added on, and can only
    be added on threads which are currently within a run loop. Unless you are
    specifically creating and running a run loop on a background thread, this
    normally will only be the main thread.

    Notifications can't be delivered as long as the runloop is blocked by
    other activity. When notifications can't be delivered instantly, multiple
    notifications may be coalesced.

    You must retain the returned token for as long as you want updates to continue
    to be sent to the block. To stop receiving updates, call stop() on the token.

    - parameter block: A block which is called to process Realm notifications.
                       It receives the following parameters:

                       - `Notification`: The incoming notification.
                       - `Realm`:        The realm for which this notification occurred.

    - returns: A token which must be held for as long as you want notifications to be delivered.
    */
    public func addNotificationBlock(block: NotificationBlock) -> NotificationToken {
        return rlmRealm.addNotificationBlock { rlmNotification, _ in
            switch rlmNotification {
            case RLMNotification.DidChange:
                block(notification: .DidChange, realm: self)
            case RLMNotification.RefreshRequired:
                block(notification: .RefreshRequired, realm: self)
            default:
                fatalError("Unhandled notification type: \(rlmNotification)")
            }
        }
    }

    // MARK: Autorefresh and Refresh

    /**
    Whether this Realm automatically updates when changes happen in other threads.

    If set to `true` (the default), changes made on other threads will be reflected
    in this Realm on the next cycle of the run loop after the changes are
    committed.  If set to `false`, you must manually call `refresh()` on the Realm to
    update it to get the latest version.

    Note that by default, background threads do not have an active run loop and you
    will need to manually call `refresh()` in order to update to the latest version,
    even if `autorefresh` is set to `true`.

    Even with this enabled, you can still call `refresh()` at any time to update the
    Realm before the automatic refresh would occur.

    Notifications are sent when a write transaction is committed whether or not
    this is enabled.

    Disabling this on a `Realm` without any strong references to it will not
    have any effect, and it will switch back to YES the next time the `Realm`
    object is created. This is normally irrelevant as it means that there is
    nothing to refresh (as persisted `Object`s, `List`s, and `Results` have strong
    references to the containing `Realm`), but it means that setting
    `Realm().autorefresh = false` in
    `application(_:didFinishLaunchingWithOptions:)` and only later storing Realm
    objects will not work.

    Defaults to true.
    */
    public var shouldAutorefresh: Bool {
        get {
            return rlmRealm.autorefresh
        }
        set {
            rlmRealm.autorefresh = newValue
        }
    }

    /**
    Update a `Realm` and outstanding objects to point to the most recent
    data for this `Realm`.

    - returns: Whether the realm had any updates.
               Note that this may return true even if no data has actually changed.
    */
    @discardableResult
    public func refresh() -> Bool {
        return rlmRealm.refresh()
    }

    // MARK: Invalidation

    /**
    Invalidate all `Object`s and `Results` read from this Realm.

    A Realm holds a read lock on the version of the data accessed by it, so
    that changes made to the Realm on different threads do not modify or delete the
    data seen by this Realm. Calling this method releases the read lock,
    allowing the space used on disk to be reused by later write transactions rather
    than growing the file. This method should be called before performing long
    blocking operations on a background thread on which you previously read data
    from the Realm which you no longer need.

    All `Object`, `Results` and `List` instances obtained from this
    `Realm` on the current thread are invalidated, and can not longer be used.
    The `Realm` itself remains valid, and a new read transaction is implicitly
    begun the next time data is read from the Realm.

    Calling this method multiple times in a row without reading any data from the
    Realm, or before ever reading any data from the Realm is a no-op. This method
    cannot be called on a read-only Realm.
    */
    public func invalidate() {
        rlmRealm.invalidate()
    }

    // MARK: Writing a Copy

    /**
    Write an encrypted and compacted copy of the Realm to the given local URL.

    The destination file cannot already exist.

    Note that if this is called from within a write transaction it writes the
    *current* data, and not data when the last write transaction was committed.

    - parameter fileURL:       Local URL to save the Realm to.
    - parameter encryptionKey: Optional 64-byte encryption key to encrypt the new file with.

    - throws: An NSError if the copy could not be written.
    */
    public func writeCopy(toFileURL url: URL, encryptionKey: Data? = nil) throws {
        try rlmRealm.writeCopy(to: url, encryptionKey: encryptionKey)
    }

    // MARK: Internal

    internal var rlmRealm: RLMRealm

    internal init(_ rlmRealm: RLMRealm) {
        self.rlmRealm = rlmRealm
    }
}

// MARK: Equatable

extension Realm: Equatable { }

/// Returns whether the two realms are equal.
public func == (lhs: Realm, rhs: Realm) -> Bool { // swiftlint:disable:this valid_docs
    return lhs.rlmRealm == rhs.rlmRealm
}

// MARK: Notifications

/// A notification due to changes to a realm.
public enum Notification: String {
    /**
    Posted when the data in a realm has changed.

    DidChange is posted after a realm has been refreshed to reflect a write transaction, i.e. when
    an autorefresh occurs, `refresh()` is called, after an implicit refresh from
    `write(_:)`/`beginWrite()`, and after a local write transaction is committed.
    */
    case DidChange = "RLMRealmDidChangeNotification"

    /**
    Posted when a write transaction has been committed to a Realm on a different thread for the same
    file. This is not posted if `autorefresh` is enabled or if the Realm is refreshed before the
    notification has a chance to run.

    Realms with autorefresh disabled should normally have a handler for this notification which
    calls `refresh()` after doing some work.
    While not refreshing is allowed, it may lead to large Realm files as Realm has to keep an extra
    copy of the data for the un-refreshed Realm.
    */
    case RefreshRequired = "RLMRealmRefreshRequiredNotification"
}

/// Closure to run when the data in a Realm was modified.
public typealias NotificationBlock = (notification: Notification, realm: Realm) -> Void


// MARK: Unavailable

extension Realm {

    @available(*, unavailable, renamed:"isInWriteTransaction")
    public var inWriteTransaction : Bool { fatalError() }

    @available(*, unavailable, renamed:"createObject(ofType:populatedWith:update:)")
    public func create<T: Object>(_ type: T.Type, value: AnyObject = [:], update: Bool = false) -> T { fatalError() }

    @available(*, unavailable, renamed:"createDynamicObject(ofType:populatedWith:update:)")
    public func dynamicCreate(_ className: String, value: AnyObject = [:], update: Bool = false) -> DynamicObject {
        fatalError()
    }

    @available(*, unavailable, renamed:"delete(_:)")
    public func delete<T: Object>(objects: List<T>) { }

    @available(*, unavailable, renamed:"delete(_:)")
    public func delete<T: Object>(objects: Results<T>) { }

    @available(*, unavailable, renamed:"deleteAllObjects()")
    public func deleteAll() { }

    @available(*, unavailable, renamed:"allObjects(ofType:)")
    public func objects<T: Object>(_ type: T.Type) -> Results<T> { fatalError() }

    @available(*, unavailable, renamed:"allDynamicObjects(ofType:)")
    public func dynamicObjects(_ className: String) -> Results<DynamicObject> { fatalError() }

    @available(*, unavailable, renamed:"object(ofType:forPrimaryKey:)")
    public func objectForPrimaryKey<T: Object>(_ type: T.Type, key: AnyObject) -> T? { fatalError() }

    @available(*, unavailable, renamed:"dynamicObject(ofType:forPrimaryKey:)")
    public func dynamicObjectForPrimaryKey(_ className: String, key: AnyObject) -> DynamicObject? { fatalError() }

    @available(*, unavailable, renamed:"shouldAutorefresh")
    public var autorefresh : Bool { get { fatalError() } set { fatalError() } }

    @available(*, unavailable, renamed:"writeCopy(toFileURL:encryptionKey:)")
    public func writeCopyToURL(_ fileURL: NSURL, encryptionKey: NSData? = nil) throws { fatalError() }
}

#else

/**
 A `Realm` instance (also referred to as "a Realm") represents a Realm database.

 Realms can either be stored on disk (see `init(path:)`) or in memory (see `Configuration`).

 `Realm` instances are cached internally, and constructing equivalent `Realm` objects (for example, by using the same
 path or identifier) produces limited overhead.

 If you specifically want to ensure a `Realm` instance is destroyed (for example, if you wish to open a Realm, check
 some property, and then possibly delete the Realm file and re-open it), place the code which uses the Realm within an
 `autoreleasepool {}` and ensure you have no other strong references to it.

 - warning: `Realm` instances are not thread safe and cannot be shared across threads or dispatch queues. You must
            construct a new instance for each thread in which a Realm will be accessed. For dispatch queues, this means
            that you must construct a new instance in each block which is dispatched, as a queue is not guaranteed to
            run all of its blocks on the same thread.
*/
public final class Realm {

    // MARK: Properties

    /// The `Schema` used by the Realm.
    public var schema: Schema { return Schema(rlmRealm.schema) }

    /// The `Configuration` value that was used to create this `Realm` instance.
    public var configuration: Configuration { return Configuration.fromRLMRealmConfiguration(rlmRealm.configuration) }

    /// Indicates if this Realm contains any objects.
    public var isEmpty: Bool { return rlmRealm.isEmpty }

    // MARK: Initializers

    /**
     Obtains an instance of the default Realm.

     The default Realm is persisted as *default.realm* under the *Documents* directory of your Application on iOS, and
     in your application's *Application Support* directory on OS X.

     The default Realm is created using the default `Configuration`, which can be changed by setting the
     `Realm.Configuration.defaultConfiguration` property to a new value.

     - throws: An `NSError` if the Realm could not be initialized.
     */
    public convenience init() throws {
        let rlmRealm = try RLMRealm(configuration: RLMRealmConfiguration.defaultConfiguration())
        self.init(rlmRealm)
    }

    /**
     Obtains a `Realm` instance with the given configuration.

     - parameter configuration: A configuration value to use when creating the Realm.

     - throws: An `NSError` if the Realm could not be initialized.
     */
    public convenience init(configuration: Configuration) throws {
        let rlmRealm = try RLMRealm(configuration: configuration.rlmConfiguration)
        self.init(rlmRealm)
    }

    /**
     Obtains a `Realm` instance persisted at a specified file URL.

     - parameter fileURL: The local URL of the file the Realm should be saved at.

     - throws: An `NSError` if the Realm could not be initialized.
     */
    public convenience init(fileURL: NSURL) throws {
        var configuration = Configuration.defaultConfiguration
        configuration.fileURL = fileURL
        try self.init(configuration: configuration)
    }

    // MARK: Transactions

    /**
     Performs actions contained within the given block inside a write transaction.

     If the block throws an error, the transaction will be canceled, reverting any writes made in the block before
     the error was thrown.

     Write transactions cannot be nested, and trying to execute a write transaction on a Realm which is already
     participating in a write transaction will throw an error. Calls to `write` from `Realm` instances in other threads
     will block until the current write transaction completes.

     Before executing the write transaction, `write` updates the `Realm` instance to the
     latest Realm version, as if `refresh()` had been called, and generates notifications
     if applicable. This has no effect if the Realm was already up to date.

     - parameter block: The block containing actions to perform.

     - throws: An `NSError` if the transaction could not be completed successfully.
               If `block` throws, the propagated `ErrorType`.
     */
    public func write(@noescape block: (() throws -> Void)) throws {
        beginWrite()
        do {
            try block()
        } catch let error {
            if inWriteTransaction { cancelWrite() }
            throw error
        }
        if inWriteTransaction { try commitWrite() }
    }

    /**
     Begins a write transaction on the Realm.

     Only one write transaction can be open at a time. Write transactions cannot be
     nested, and trying to begin a write transaction on a Realm which is
     already in a write transaction will throw an error. Calls to
     `beginWrite` from `Realm` instances in other threads will block
     until the current write transaction completes.

     Before beginning the write transaction, `beginWrite` updates the
     `Realm` instance to the latest Realm version, as if `refresh()` had been called, and
     generates notifications if applicable. This has no effect if the Realm
     was already up to date.

     It is rarely a good idea to have write transactions span multiple cycles of
     the run loop, but if you do wish to do so you will need to ensure that the
     Realm in the write transaction is kept alive until the write transaction
     is committed.
     */
    public func beginWrite() {
        rlmRealm.beginWriteTransaction()
    }

    /**
     Commits all write operations in the current write transaction, and ends the transaction.

     - warning: This method may only be called during a write transaction.

     - throws: An `NSError` if the transaction could not be written.
     */
    public func commitWrite() throws {
        try rlmRealm.commitWriteTransaction()
    }

    /**
     Reverts all writes made in the current write transaction and ends the transaction.

     This rolls back all objects in the Realm to the state they were in at the
     beginning of the write transaction, and then ends the transaction.

     This restores the data for deleted objects, but does not revive invalidated
     object instances. Any `Object`s which were added to the Realm will be
     invalidated rather than becoming unmanaged.
     Given the following code:

     ```swift
     let oldObject = objects(ObjectType).first!
     let newObject = ObjectType()

     realm.beginWrite()
     realm.add(newObject)
     realm.delete(oldObject)
     realm.cancelWrite()
     ```

     Both `oldObject` and `newObject` will return `true` for `invalidated`,
     but re-running the query which provided `oldObject` will once again return
     the valid object.

     - warning: This method may only be called during a write transaction.
     */
    public func cancelWrite() {
        rlmRealm.cancelWriteTransaction()
    }

    /**
     Indicates whether this Realm is currently in a write transaction.

     - warning: Do not simply check this property and then start a write transaction whenever an object needs to be
                created, updated, or removed. Doing so might cause a large number of write transactions to be created,
                degrading performance. Instead, always prefer performing multiple updates during a single transaction.
     */
    public var inWriteTransaction: Bool {
        return rlmRealm.inWriteTransaction
    }

    // MARK: Adding and Creating objects

    /**
     Adds or updates an existing object into the Realm.

     Only pass `true` to `update` if the object has a primary key. If no objects exist in
     the Realm with the same primary key value, the object is inserted. Otherwise,
     the existing object is updated with any changed values.

     When added, all child relationships referenced by this object will also be added to
     the Realm if they are not already in it. If the object or any related
     objects are already being managed by a different Realm an error will be thrown. Use one
     of the `create` functions to insert a copy of a managed object into a different
     Realm.

     The object to be added must be valid and cannot have been previously deleted
     from a Realm (i.e. `invalidated` must be `false`).

     - parameter object: The object to be added to this Realm.
     - parameter update: If `true`, the Realm will try to find an existing copy of the object (with the same primary
                         key), and update it. Otherwise, the object will be added.
     */
    public func add(object: Object, update: Bool = false) {
        if update && object.objectSchema.primaryKeyProperty == nil {
            throwRealmException("'\(object.objectSchema.className)' does not have a primary key and can not be updated")
        }
        RLMAddObjectToRealm(object, rlmRealm, update)
    }

    /**
     Adds or updates all the objects in a collection into the Realm.

     - see: `add(_:update:)`

     - warning: This method may only be called during a write transaction.

     - parameter objects: A sequence which contains objects to be added to the Realm.
     - parameter update: If `true`, objects that are already in the Realm will be updated instead of added anew.
     */
    public func add<S: SequenceType where S.Generator.Element: Object>(objects: S, update: Bool = false) {
        for obj in objects {
            add(obj, update: update)
        }
    }

    /**
     Creates or updates a Realm object with a given value, adding it to the Realm and returning it.

     Only pass `true` to `update` if the object has a primary key. If no objects exist in
     the Realm with the same primary key value, the object is inserted. Otherwise,
     the existing object is updated with any changed values.

     The `value` argument can be a key-value coding compliant object, an array or dictionary returned from the methods
     in `NSJSONSerialization`, or an `Array` containing one element for each managed property. An exception will be
     thrown if any required properties are not present and those properties were not defined with default values. Do not
     pass in a `LinkingObjects` instance, either by itself or as a member of a collection.

     When passing in an `Array` as the `value` argument, all properties must be present, valid and in the same order as
     the properties defined in the model.

     - warning: This method may only be called during a write transaction.

     - parameter type:   The type of the object to create.
     - parameter value:  The value used to populate the object.
     - parameter update: If `true`, the Realm will try to find an existing copy of the object (with the same primary
                         key), and update it. Otherwise, the object will be added.

     - returns: The newly created object.
     */
    public func create<T: Object>(type: T.Type, value: AnyObject = [:], update: Bool = false) -> T {
        let className = (type as Object.Type).className()
        if update && schema[className]?.primaryKeyProperty == nil {
            throwRealmException("'\(className)' does not have a primary key and can not be updated")
        }
        return unsafeBitCast(RLMCreateObjectInRealmWithValue(rlmRealm, className, value, update), T.self)
    }

    /**
     This method is useful only in specialized circumstances, for example, when building
     components that integrate with Realm. If you are simply building an app on Realm, it is
     recommended to use the typed method `create(_:value:update:)`.

     Creates or updates an object with the given class name and adds it to the `Realm`, populating
     the object with the given value.

     When 'update' is 'true', the object must have a primary key. If no objects exist in
     the Realm instance with the same primary key value, the object is inserted. Otherwise,
     the existing object is updated with any changed values.

     The `value` argument is used to populate the object. It can be a key-value coding compliant object, an array or
     dictionary returned from the methods in `NSJSONSerialization`, or an `Array` containing one element for each
     managed property. An exception will be thrown if any required properties are not present and those properties were
     not defined with default values.

     When passing in an `Array` as the `value` argument, all properties must be present, valid and in the same order as
     the properties defined in the model.

     - warning: This method can only be called during a write transaction.

     - parameter className:  The class name of the object to create.
     - parameter value:      The value used to populate the object.
     - parameter update:     If true will try to update existing objects with the same primary key.

     - returns: The created object.

     :nodoc:
     */
    public func dynamicCreate(className: String, value: AnyObject = [:], update: Bool = false) -> DynamicObject {
        if update && schema[className]?.primaryKeyProperty == nil {
            throwRealmException("'\(className)' does not have a primary key and can not be updated")
        }
        return unsafeBitCast(RLMCreateObjectInRealmWithValue(rlmRealm, className, value, update), DynamicObject.self)
    }

    // MARK: Deleting objects

    /**
     Deletes an object from the Realm. Once the object is deleted it is considered invalidated.

     - warning: This method may only be called during a write transaction.

     - parameter object: The object to be deleted.
     */
    public func delete(object: Object) {
        RLMDeleteObjectFromRealm(object, rlmRealm)
    }

    /**
     Deletes one or more objects from the Realm.

     - warning: This method may only be called during a write transaction.

     - parameter objects:   The objects to be deleted. This can be a `List<Object>`, `Results<Object>`,
                            or any other enumerable `SequenceType` whose elements are `Object`s.
     */
    public func delete<S: SequenceType where S.Generator.Element: Object>(objects: S) {
        for obj in objects {
            delete(obj)
        }
    }

    /**
     Deletes one or more objects from the Realm.

     - warning: This method may only be called during a write transaction.

     - parameter objects: A list of objects to delete.

     :nodoc:
     */
    public func delete<T: Object>(objects: List<T>) {
        rlmRealm.deleteObjects(objects._rlmArray)
    }

    /**
     Deletes one or more objects from the Realm.

     - warning: This method may only be called during a write transaction.

     - parameter objects: A `Results` containing the objects to be deleted.

     :nodoc:
     */
    public func delete<T: Object>(objects: Results<T>) {
        rlmRealm.deleteObjects(objects.rlmResults)
    }

    /**
     Deletes all objects from the Realm.

     - warning: This method may only be called during a write transaction.
     */
    public func deleteAll() {
        RLMDeleteAllObjectsFromRealm(rlmRealm)
    }

    // MARK: Object Retrieval

    /**
     Returns all objects of the given type stored in the Realm.

     - parameter type: The type of the objects to be returned.

     - returns: A `Results` containing the objects.
    */
    public func objects<T: Object>(type: T.Type) -> Results<T> {
        return Results<T>(RLMGetObjects(rlmRealm, (type as Object.Type).className(), nil))
    }

    /**
     This method is useful only in specialized circumstances, for example, when building
     components that integrate with Realm. If you are simply building an app on Realm, it is
     recommended to use the typed method `objects(type:)`.

     Returns all objects for a given class name in the Realm.

     - warning: This method is useful only in specialized circumstances.

     - parameter className: The class name of the objects to be returned.

     - returns: All objects for the given class name as dynamic objects

     :nodoc:
    */
    public func dynamicObjects(className: String) -> Results<DynamicObject> {
        return Results<DynamicObject>(RLMGetObjects(rlmRealm, className, nil))
    }

    /**
     Retrieves the single instance of a given object type with the given primary key from the Realm.

     This method requires that `primaryKey()` be overridden on the given object class.

     - see: `Object.primaryKey()`

     - parameter type: The type of the object to be returned.
     - parameter key:  The primary key of the desired object.

     - returns: An object of type `type`, or `nil` if no instance with the given primary key exists.
     */
    public func objectForPrimaryKey<T: Object>(type: T.Type, key: AnyObject?) -> T? {
        return unsafeBitCast(RLMGetObject(rlmRealm, (type as Object.Type).className(), key), Optional<T>.self)
    }

    /**
     This method is useful only in specialized circumstances, for example, when building
     components that integrate with Realm. If you are simply building an app on Realm, it is
     recommended to use the typed method `objectForPrimaryKey(_:key:)`.

     Get a dynamic object with the given class name and primary key.

     Returns `nil` if no object exists with the given class name and primary key.

     This method requires that `primaryKey()` be overridden on the given subclass.

     - see: Object.primaryKey()

     - warning: This method is useful only in specialized circumstances.

     - parameter className:  The class name of the object to be returned.
     - parameter key:        The primary key of the desired object.

     - returns: An object of type `DynamicObject` or `nil` if an object with the given primary key does not exist.

     :nodoc:
     */
    public func dynamicObjectForPrimaryKey(className: String, key: AnyObject?) -> DynamicObject? {
        return unsafeBitCast(RLMGetObject(rlmRealm, className, key), Optional<DynamicObject>.self)
    }

    // MARK: Notifications

    /**
     Adds a notification handler for changes made to this Realm, and returns a notification token.

     Notification handlers are called after each write transaction is committed, independent of the thread or process.

     Handler blocks are called on the same thread that they were added on, and may only be added on threads which are
     currently within a run loop. Unless you are specifically creating and running a run loop on a background thread,
     this will normally only be the main thread.

     Notifications can't be delivered as long as the run loop is blocked by other activity. When notifications can't be
     delivered instantly, multiple notifications may be coalesced.

     You must retain the returned token for as long as you want updates to be sent to the block. To stop receiving
     updates, call `stop()` on the token.

     - parameter block: A block which is called to process Realm notifications. It receives the following parameters:
                        `notification`: the incoming notification; `realm`: the Realm for which the notification
                        occurred.

     - returns: A token which must be retained for as long as you wish to continue receiving change notifications.
     */
    @warn_unused_result(message="You must hold on to the NotificationToken returned from addNotificationBlock")
    public func addNotificationBlock(block: NotificationBlock) -> NotificationToken {
        return rlmRealm.addNotificationBlock { rlmNotification, _ in
            switch rlmNotification {
            case RLMRealmDidChangeNotification:
                block(notification: .DidChange, realm: self)
            case RLMRealmRefreshRequiredNotification:
                block(notification: .RefreshRequired, realm: self)
            default:
                fatalError("Unhandled notification type: \(rlmNotification)")
            }
        }
    }

    // MARK: Autorefresh and Refresh

    /**
     Set this property to `true` to automatically update this Realm when changes happen in other threads.

     If set to `true` (the default), changes made on other threads will be reflected
     in this Realm on the next cycle of the run loop after the changes are
     committed.  If set to `false`, you must manually call `refresh()` on the Realm to
     update it to get the latest data.

     Note that by default, background threads do not have an active run loop and you
     will need to manually call `refresh()` in order to update to the latest version,
     even if `autorefresh` is set to `true`.

     Even with this property enabled, you can still call `refresh()` at any time to update the
     Realm before the automatic refresh would occur.

     Notifications are sent when a write transaction is committed whether or not
     automatic refreshing is enabled.

     Disabling `autorefresh` on a `Realm` without any strong references to it will not
     have any effect, and `autorefresh` will revert back to `true` the next time the Realm is created. This is normally
     irrelevant as it means that there is nothing to refresh (as managed `Object`s, `List`s, and `Results` have strong
     references to the `Realm` that manages them), but it means that setting
     `Realm().autorefresh = false` in
     `application(_:didFinishLaunchingWithOptions:)` and only later storing Realm
     objects will not work.

     Defaults to `true`.
     */
    public var autorefresh: Bool {
        get {
            return rlmRealm.autorefresh
        }
        set {
            rlmRealm.autorefresh = newValue
        }
    }

    /**
     Updates the Realm and outstanding objects managed by the Realm to point to the most recent data.

     - returns: Whether there were any updates for the Realm. Note that `true` may be returned even if no data actually
                changed.
     */
    public func refresh() -> Bool {
        return rlmRealm.refresh()
    }

    // MARK: Invalidation

    /**
     Invalidates all `Object`s, `Results`, `LinkingObjects`, and `List`s managed by the Realm.

     A Realm holds a read lock on the version of the data accessed by it, so
     that changes made to the Realm on different threads do not modify or delete the
     data seen by this Realm. Calling this method releases the read lock,
     allowing the space used on disk to be reused by later write transactions rather
     than growing the file. This method should be called before performing long
     blocking operations on a background thread on which you previously read data
     from the Realm which you no longer need.

     All `Object`, `Results` and `List` instances obtained from this `Realm` instance on the current thread are
     invalidated. `Object`s and `Array`s cannot be used. `Results` will become empty. The Realm itself remains valid,
     and a new read transaction is implicitly begun the next time data is read from the Realm.

     Calling this method multiple times in a row without reading any data from the
     Realm, or before ever reading any data from the Realm, is a no-op. This method
     may not be called on a read-only Realm.
     */
    public func invalidate() {
        rlmRealm.invalidate()
    }

    // MARK: Writing a Copy

    /**
     Writes a compacted and optionally encrypted copy of the Realm to the given local URL.

     The destination file cannot already exist.

     Note that if this method is called from within a write transaction, the *current* data is written, not the data
     from the point when the previous write transaction was committed.

     - parameter fileURL:       Local URL to save the Realm to.
     - parameter encryptionKey: Optional 64-byte encryption key to encrypt the new file with.

     - throws: An `NSError` if the copy could not be written.
     */
    public func writeCopyToURL(fileURL: NSURL, encryptionKey: NSData? = nil) throws {
        try rlmRealm.writeCopyToURL(fileURL, encryptionKey: encryptionKey)
    }

    // MARK: Handover

    public func async(onQueue queue: dispatch_queue_t = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                      handingOver objects: [Object], execute block: (Realm, [Object]) -> ()) {
        rlmRealm.dispatchAsync(queue, handingOver: unsafeBitCast(objects, [RLMObject].self)) { realm, objects in
            block(Realm(realm), unsafeBitCast(objects, [Object].self))
        }
    }

    // MARK: Internal

    internal var rlmRealm: RLMRealm

    internal init(_ rlmRealm: RLMRealm) {
        self.rlmRealm = rlmRealm
    }
}

// MARK: Equatable

extension Realm: Equatable { }

/// Returns a Boolean indicating whether two `Realm` instances are equal.
public func == (lhs: Realm, rhs: Realm) -> Bool { // swiftlint:disable:this valid_docs
    return lhs.rlmRealm == rhs.rlmRealm
}

// MARK: Notifications

/// A notification indicating that changes were made to a Realm.
public enum Notification: String {
    /**
     This notification is posted when the data in a Realm has changed.

     `DidChange` is posted after a Realm has been refreshed to reflect a write transaction, This can happen when
     an autorefresh occurs, `refresh()` is called, after an implicit refresh from
     `write(_:)`/`beginWrite()`, or after a local write transaction is committed.
    */
    case DidChange = "RLMRealmDidChangeNotification"

    /**
     This notification is posted when a write transaction has been committed to a Realm on a different thread for the
     same file.

     It is not posted if `autorefresh` is enabled, or if the Realm is refreshed before the
     notification has a chance to run.

     Realms with autorefresh disabled should normally install a handler for this notification which calls `refresh()`
     after doing some work. Refreshing the Realm is optional, but not refreshing the Realm may lead to large Realm
     files. This is because Realm must keep an extra copy of the data for the stale Realm.
    */
    case RefreshRequired = "RLMRealmRefreshRequiredNotification"
}

/// The type of a block to run for notification purposes when the data in a Realm is modified.
public typealias NotificationBlock = (notification: Notification, realm: Realm) -> Void

#endif
