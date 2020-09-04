module SIMJI

  OPCODE={
    :add   => 0b00001, #1
    :sub   => 0b00010, #2
    :mul   => 0b00011,
    :div   => 0b00100,
    :and   => 0b00101,
    :or    => 0b00110,
    :xor   => 0b00111,
    :shl   => 0b01000,
    :shr   => 0b01001,
    :slt   => 0b01010,
    :sle   => 0b01011,
    :seq   => 0b01100,
    :load  => 0b01101,
    :store => 0b01110,
    :jmp   => 0b01111,
    :braz  => 0b10000,
    :branz => 0b10001,
    :scall => 0b10010,
    :stop  => 0b00000
  }

end
