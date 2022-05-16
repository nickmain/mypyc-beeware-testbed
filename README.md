# mypyc-beeware-testbed

An experiment to validate Mypyc + Beeware for macOS and iOS app development.

This repo is for visibility only and will be discarded once a proper Swift/Python interop
package has been developed.

This uses the [Beeware](https://github.com/beeware/Python-Apple-support/releases) project 
to integrate Python into an iPad app and adds a Swift wrapper for some parts of the Python API:
[PyTest/PythonObject.swift](PyTest/PythonObject.swift).

The main point of the experiment is to validate that [Mypyc](https://mypyc.readthedocs.io/en/latest/)
can be used to translate type-annotated Python code to C, which can then be easily linked
into a Swift project.

The Xcode project adds a build step to invoke mypyc so that changes to the Python code can be
immediately executed on device.
