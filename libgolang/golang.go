package main

import "C"

//export Add
func Add(a C.int, b C.int) C.int {
	return a + b
}

func main() {}
