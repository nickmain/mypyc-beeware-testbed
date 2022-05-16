//
//  PythonHelpers.h
//  PyTest
//
//  Created by Nick Main on 2/17/22.
//

#ifndef PythonHelpers_h
#define PythonHelpers_h

#include <stdio.h>

#define PY_SSIZE_T_CLEAN
#include "Python.h"

extern PyMODINIT_FUNC PyInit_hello(void);

PyObject* newNone(void);
PyObject* newNotImplemented(void);

int is_NotImplemented(PyObject* ptr);

int isPyTuple(PyObject* ptr);

void addBuiltins(void);

#endif /* PythonHelpers_h */
