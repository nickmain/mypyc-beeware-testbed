from typing import *

print("module init x")

baseInt : int = 0

class TestClass:
    a: int = 0
    b: str = ""

    def __init__(self, a: int, b: str):
        self.a = a
        self.b = b
        
    def greet(self):
        print(f"a={self.a} b={self.b}")

def hello():
    TestClass(34, "why?").greet()

def test():
    global baseInt
    # print(f"In hello.test() ++> baseInt={baseInt}")
    tuple = (1+baseInt, 2, 3+baseInt, "Hello World, 👋")
    baseInt += 1
    return tuple # repr(tuple)
