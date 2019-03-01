# simji
Instruction set simulator for a MIPS-like processor, and its GUI in Ruby gtk3

![GitHub Logo](/doc/gui.png)

There is no Ruby gem at the moment. If you want to test Simji, you need :
* a recent Ruby interpreter (>2.5)
* ruby gtk3 gem
* simji himseft (clone it !)

I give some small examples of assembly code for Simji processor in test directory.
Simji, used as a command line tool, allows to compile those assembly codes into binary.
Note that the generated code is not a binary file, but instead an ASCII file containing address/instruction codes.

Simji was used as an educational tool only. It is not targeted to high-performance ISS !  
