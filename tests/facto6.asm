; program to compute Factorial(6)
        add r0,6,r3 ; 6 in r3
        add r0,1,r5 ; tmp
        add r0,1,r2  ; i=1
LOOP:   sle r2,r3,r4 ; i<=x
        braz r4, END
        mul r5,r2,r5
        add r2,1,r2
        jmp LOOP,r0
END:
        add r5,r0,r1
        scall 1
        stop
