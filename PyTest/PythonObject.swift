// copyright

import Foundation

class Python {
    typealias PyTypePtr = UnsafeMutablePointer<PyTypeObject>
    typealias PyObjectPtr = UnsafeMutablePointer<PyObject>
    
    /// Ensure that the GIL is acquired and released around the given work
    @discardableResult
    static func GIL<T>(_ work: () -> T) -> T {
        let gil = PyGILState_Ensure()
        let result = work()
        PyGILState_Release(gil)
        return result
    }
    
    /// Ensure that the GIL is acquired and released around the given work that may throw
    @discardableResult
    static func GIL_throws<T>(_ work: () throws -> T) throws -> T {
        let gil = PyGILState_Ensure()
        do {
            let result = try work()
            PyGILState_Release(gil)
            return result
        } catch {
            PyGILState_Release(gil)
            throw error
        }
    }
    
    // A python object pointer and ownership status.
    // If owned then release on deinit.
    fileprivate class ObjectPtr {
        fileprivate let pyObjPtr: PyObjectPtr
        fileprivate var isOwned: Bool
        
        fileprivate init(_ ptr: PyObjectPtr, isOwned: Bool = true, incrementRef: Bool = false) {
            self.pyObjPtr = ptr
            self.isOwned = isOwned
            
            if incrementRef {
                // assume this is already inside GIL state
                Py_IncRef(ptr)
            }
        }
        
        deinit {
            if isOwned {
                Python.GIL{ Py_DecRef(pyObjPtr) }
            }
        }
    }
    
    class GC {
        /// Run GC if enabled and return count of collected+unreachable objects
        static func collect() -> Int { PyGC_Collect() }
        
        /// Whether GC is enabled
        static var isEnabled: Bool {
            get { PyGC_IsEnabled() != 0 }
            set { if newValue { PyGC_Enable() } else { PyGC_Disable() } }
        }
    }
    
    class Object {
        fileprivate let objectPtr: ObjectPtr
        
        fileprivate init(_ ptr: ObjectPtr) {
            self.objectPtr = ptr
        }

        fileprivate init(_ ptr: PyObjectPtr, isOwned: Bool = true, incrementRef: Bool = false) {
            self.objectPtr = ObjectPtr(ptr, isOwned: isOwned, incrementRef: incrementRef)
        }
        
        // make an Object if the ptr is not null
        fileprivate static func own(_ ptr: PyObjectPtr?) -> Object? {
            guard let ptr = ptr else { return nil }
            return Object(ptr)
        }
        
        /// Get the current ref count on this object
        var refCount: Int { objectPtr.pyObjPtr.pointee.ob_refcnt }
        
        /// Get the object type
        var type: PyTypePtr? { objectPtr.pyObjPtr.pointee.ob_type }
        
        /// Same as Python str()
        func getStr() throws -> Str { Str(try Python.check(PyObject_Str(objectPtr.pyObjPtr))) }

        /// Same as Python repr()
        func getRepr() throws -> Str { Str(try Python.check(PyObject_Repr(objectPtr.pyObjPtr))) }

        /// Decode the type
        func getType() -> PyType {
            guard let type = objectPtr.pyObjPtr.pointee.ob_type else { return .unknown }

            if Boolean.isType(type) { return .bool }
            if PyType_IsSubtype(type, &PyBytes_Type) != 0 { return .bytes }
            if PyType_IsSubtype(type, &PyFloat_Type) != 0 { return .float }
            if PyType_IsSubtype(type, &PyLong_Type) != 0 { return .int }
            if Module.isType(type) { return .module }
            if Str.isType(type) { return .string }
            if PyType_IsSubtype(type, &PyList_Type) != 0 { return .list }
            if Dict.isType(type) { return .dict }
            if PyType_IsSubtype(type, &PyFrozenSet_Type) != 0 { return .frozenSet }
            if PyType_IsSubtype(type, &PySet_Type) != 0 { return .set }
            if Tuple.isType(type) { return .tuple }
            
            if PyType_IsSubtype(type, &PyType_Type) != 0 { return .type }
            if PyType_IsSubtype(type, &PyBaseObject_Type) != 0 { return .object }
            
            return .other(type)
        }
        
        enum PyType {
            case bool, float, int, bytes, string
            case list, dict, set, frozenSet, tuple, namedTuple
            case type
            case module
            case object
            case other(PyTypePtr)
            case unknown
        }
        
        func asTuple() -> Tuple? { Tuple.isType(type) ? Tuple(objectPtr) : nil }
        func asString() -> Str? { Str.isType(type) ? Str(objectPtr) : nil }
        // TODO: more types
    }

    /// The None singleton
    class None: Object {
        static func isNone(_ object: Object) -> Bool { Py_IsNone(object.objectPtr.pyObjPtr) != 0 }
       
        init() {
            super.init(newNone())
        }
    }
    
    /// The NotImplemented singleton
    class NotImplemented: Object {
        static func isNotImplemented(_ object: Object) -> Bool { is_NotImplemented(object.objectPtr.pyObjPtr) != 0 }
       
        init() {
            super.init(newNotImplemented())
        }
    }
    
    class Boolean: Object {
        static func isType(_ type: PyTypePtr?) -> Bool {
            guard let type = type else { return false }
            return PyType_IsSubtype(type, &PyBool_Type) != 0
        }

        static func True() -> Boolean { Boolean(PyBool_FromLong(1)) }
        static func False() -> Boolean { Boolean(PyBool_FromLong(0)) }

        var isTrue: Bool { Py_IsTrue(objectPtr.pyObjPtr) != 0 }
        var isFalse: Bool { Py_IsFalse(objectPtr.pyObjPtr) != 0 }
    }
    
    class Str: Object {
        static func isType(_ type: PyTypePtr?) -> Bool {
            guard let type = type else { return false }
            return PyType_IsSubtype(type, &PyUnicode_Type) != 0
        }
        
        convenience init(_ str: String) {
            self.init(PyUnicode_FromString(str))
        }
        
        func toString() -> String {
            // TODO: error handling
            guard let bytes = PyUnicode_AsUTF8(objectPtr.pyObjPtr) else { return "" }
            return String(cString: bytes)
        }
    }

    class Dict: Object {
        static func isType(_ type: PyTypePtr?) -> Bool {
            guard let type = type else { return false }
            return PyType_IsSubtype(type, &PyDict_Type) != 0
        }
    }

    class Module: Object {
        static func isType(_ type: PyTypePtr?) -> Bool {
            guard let type = type else { return false }
            return PyType_IsSubtype(type, &PyModule_Type) != 0
        }
        
        /// Return the dictionary object that implements the module’s namespace
        func getDict() -> Dict {
            Dict(PyModule_GetDict(objectPtr.pyObjPtr), isOwned: false)
        }
    }

    /// Tuples do not hold a reference count on the objects they store
    class Tuple: Object {
        static func isType(_ type: PyTypePtr?) -> Bool {
            guard let type = type else { return false }
            return PyType_IsSubtype(type, &PyTuple_Type) != 0
        }
        
        convenience init(size: Int) throws {
            self.init(try Python.check(PyTuple_New(size)))
        }
        
        var size: Int { PyTuple_Size(objectPtr.pyObjPtr) }
        
        /// Get the item at the given index but do not increment the ref count.
        func peekItem(at index: Int) throws -> Object {
            Object(try Python.check(PyTuple_GetItem(objectPtr.pyObjPtr, index)), isOwned: false)
        }
        
        /// Get the item at the given index and also increment the ref count.
        func getItem(at index: Int) throws -> Object {
            Object(try Python.check(PyTuple_GetItem(objectPtr.pyObjPtr, index)), incrementRef: true)
        }

        func setItem(at index: Int, to value: Object) throws {
            let res = PyTuple_SetItem(objectPtr.pyObjPtr, index, value.objectPtr.pyObjPtr)
            if res != 0 { try Python.throwException() }
        }
    }
    
    // MARK: - Python Interpreter
    
    init() {
        addBuiltins()
        Py_Initialize()
        
        // print out the built-in module names
        // PyRun_SimpleString("import sys\nprint(sys.builtin_module_names)")
    }
    
    func importModule(named: String) throws -> Module {
        Module(try Python.check(PyImport_ImportModule(named)))
    }
    
    /// Get a module from its initialization function
    func getModule(from initFunc: (() -> UnsafeMutablePointer<PyObject>?)) -> Module? {
        if let module = initFunc() {
            return Module(module)
        }
        return nil
    }
    
    /// Evaluate an expression
    func eval(expression: String, globals: Dict, locals: Dict? = nil) throws -> Object {
        Object(try Python.check(PyRun_String(expression, Py_eval_input, globals.objectPtr.pyObjPtr, locals?.objectPtr.pyObjPtr ?? globals.objectPtr.pyObjPtr)))
    }
    
    deinit {
        Py_Finalize()
    }
    
    /// Errors that may be thrown by the check() method
    enum Error: Swift.Error {
        case msg(String)
        case nullPointer
        case value(Object)
        case unknown
    }
    
    /// Return the result of the expression unless it is null, in which case throw
    /// the appropriate error
    static func check<T>(_ obj: UnsafeMutablePointer<T>? ) throws -> UnsafeMutablePointer<T> {
        if let result = obj {
            return result
        }
        
        try throwException()
        throw Error.nullPointer
    }
    
    /// Throw current Python exception if any
    static func throwException() throws {
        guard PyErr_Occurred() != nil else { return }
        
        var ptype, pvalue, ptrace : PyObjectPtr?
        PyErr_Fetch(&ptype, &pvalue, &ptrace) // get the active exception
        
        if let type = Object.own(ptype) {
            if let value = Object.own(pvalue) {
                throw Error.value(value)
            } else {
                throw Error.value(type)
            }
        }
        
        throw Error.unknown
    }
}
