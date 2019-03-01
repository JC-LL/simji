require_relative 'opcodes'
require_relative 'eda_utils'

module SIMJI

  OPCODE_INV=OPCODE.invert
  OPCODE_JUSTIFY=OPCODE.keys.max_by{|e| e.size}.size + 1


  class Disassembler

    def initialize

    end

    # ascii file is formatted : "addr instr" in hexa
    def disassemble_file filename
      lines=IO.readlines(filename).select{|l| !l.start_with?('#')}
      lines.each do |line|
        addr,instr=line.split(' ').collect{|e| e.to_i(16)}
        asm=disassemble(instr)
        puts "0x#{addr.to_s(16).rjust(4,'0')} 0x#{instr.to_s(16).rjust(8,'0')} #{asm}"
      end
    end

    def disassemble instr
      asm=""
      opcode = (instr & 0xF8000000) >> 27
      asm << (opcode_sym=OPCODE_INV[opcode]).to_s.ljust(OPCODE_JUSTIFY,' ')
      case opcode_sym
      when :add,:sub,:mul,:div,:and,:or,:xor,:shl,:slt,:sle,:seq,:load,:store
        ra=instr.bit_field(26..22)
        flag_o=instr[21]
        o_is_reg=flag_o==0
        o=instr.bit_field(20..5)
        imm_o = o #TBC
        o=o_is_reg ? "r#{o}" : imm_o
        rb=instr.bit_field(4..0)
        asm << "r#{ra},#{o},r#{rb}"
      when :jmp
        flag_o=instr[26]
        o_is_reg=flag_o==0
        o=instr.bit_field(25..5)
        imm_o = o #TBC
        o=o_is_reg ? "r#{o}" : imm_o
        r = instr.bit_field(4..0)
        asm << "#{o},#{r}"
      when :braz,:branz
        r = instr.bit_field(26..22)
        a = instr.bit_field(21..0)
        asm << "r#{r},#{a}"
      when :scall
        n=instr & ~0xF8000000
        asm << n.to_s
      when :stop
      else
        raise "NYI : #{opcode}"
      end
      return asm
    end
  end

end #module

if $PROGRAM_NAME==__FILE__
  SIMJI::Disassembler.new.disassemble_file ARGV.first
end
