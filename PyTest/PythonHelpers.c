//
//  PythonHelpers.c
//  PyTest
//
//  Created by Nick Main on 2/17/22.
//

#include "PythonHelpers.h"

PyObject* newNone() { Py_RETURN_NONE; }
PyObject* newNotImplemented() { Py_RETURN_NOTIMPLEMENTED; }
int is_NotImplemented(PyObject* ptr) { return Py_Is(ptr, Py_NotImplemented); }

void addBuiltins() {
    PyImport_AppendInittab("hello", PyInit_hello);
}

int isPyTuple(PyObject* ptr) { return PyTuple_Check(ptr); }
