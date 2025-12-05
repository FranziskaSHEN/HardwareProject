lui     x1, 0x00010
addi    x1, x1, 5
addi    x2, x0, 20
sw      x2, 0(x1)
lw      x3, 0(x1)
add     x4, x3, x2
sub     x5, x4, x3
beq     x5, x3, branch_target
addi    x6, x0, 99
loop1:
    jal     x0, loop1
branch_target:
    addi    x6, x0, 42
loop2:
    jal     x0, loop2