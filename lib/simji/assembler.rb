require 'pp'
require_relative 'opcodes'

module SIMJI

  class Assembler

    def initialize
      @labels={} #name => address
    end

    def assemble filename
      prg=parse(filename)
      addr_code=encoding(prg)
      dir = File.dirname(filename)
      outfile= dir +"/"+ File.basename(filename,'.asm')+".bin"
      dump_in(addr_code,outfile)
    end

    def dump_in addr_code,outfile
      puts "writing hexa in #{outfile}"
      txt=addr_code.collect{|addr,code| "0x#{addr.to_s(16).rjust(8,'0')} 0x#{code.to_s(16).rjust(8,'0')}"}
      File.open(outfile,'w'){|f| f.puts txt}
    end

    # returns an array of s-expressions
    # like [....,["add",["r1","9","r2"]],....]
    # in the meantime, this method builds a hash for labels
    def parse filename
      puts "parsing #{filename}"
      asm_lines=IO.readlines(filename)

      @max_digits=asm_lines.size.to_s.size
      address=-1
      prog={} #returned

      asm_lines.each_with_index do |line,idx|
        line.chomp!
        @idx=idx+1

        next if line=~/\A\s*;/  # skip comment lines
        line.slice!(/;(.*)/)    # suppress comments at end of line!
        next if line.empty?     # suppress empty lines

        address+=1

        if mdata=has_label(line)
          line.slice!(/\A\s*(\w+)\s*:/)
          label=parse_label(mdata)
          @labels[label]=address
        end

        if !line.empty?
          instr=parse_instr(line)
          prog[address]=instr
          #puts "#{address.to_s.ljust(@max_digits)}: #{line}"
        else
          address-=1
        end

      end
      puts "number of instructions parsed : #{prog.size}"
      puts "number of labels found        : #{@labels.size}"

      return prog
    end

    # prog is an array of s-expressions
    # like [....,["add",["r1","9","r2"]],....]
    #   or [....,["jmp",["my_label",r0]],....]
    # References to labels are resolved (subtitution)
    def encoding prog_h
      puts "encoding..."
      hash={}
      prog_h.each{|addr,instr| hash[addr]=encode(instr)}
      return hash
    end

    def has_label line
      /\A\s*(\w+)\s*:/.match(line)
    end

    def parse_label mdata
      mdata.captures.first
    end

    def parse_instr line
      line.slice!(/\A\s*/) # suppress leading space
      #puts line
      instr,args=/(\w+)\s*((\w+)\s*(,\s*\w+)*)?/.match(line).captures
      instr=instr.to_sym
      args=args.split(",").collect{|arg| arg.gsub(" ",'')} if args
      return [instr,args]
    end

    def encode instr
      codeop=instr.first
      case codeop
      when :jmp
        return encode_jmp(instr)
      when :braz,:branz
        return encode_braz(instr)
      when :scall
        return encode_scall(instr)
      when :stop
        return encode_stop(instr)
      else
        return encode_ternary(instr)
      end
    end

    def regnum str
      if m=/r(\d+)/.match(str)
        return m.captures.first.to_i
      end
      nil
    end

    def encode_ternary instr
      codeop,args=instr
      raise "unknown instruction #{codeop}" if OPCODE[codeop].nil?
      binary=OPCODE[codeop] << 27
      r1,o,r2=args
      r1=regnum(r1)
      binary+=(0b11111 & r1) << 22
      oo =regnum(o)
      if oo
        binary+= (0xFFFF & oo) << 5
      else
        binary+= 1<<21
        o=o.to_i
        binary+=(0xFFFF & o) << 5
      end
      r2=regnum(r2)
      binary+=(0b11111 & r2)
      return binary
    end

    def encode_jmp instr
      codeop,args=instr
      binary=OPCODE[codeop] << 27
      o,r=args
      oo =regnum(o)
      if oo
        binary+= (0b11111111111111111111 & oo) << 5
      else
        binary+= 1<<26
        if o=~/\w+/
          oo=@labels[o]
          raise "ERROR : label #{o} not found " if oo.nil?
          #puts "JMP    LABEL #{o} : #{oo}"
          o=oo
        else
          o=o.to_i
        end
        binary+=(0b111111111111111111111 & o) << 5
      end
      r=regnum(r)
      binary+= 0b11111 & r
      return binary
    end

    def encode_braz instr
      codeop,args=instr
      binary=OPCODE[codeop] << 27
      r,a=args
      r=regnum(r)
      if a=~/\w+/
        aa=@labels[a]
        raise "ERROR : label >#{a}< not found " if aa.nil?
        #puts "BRANCH LABEL #{a} : #{aa}"
        a=aa
      else
        a=a.to_i
      end
      binary+= (0b11111 & r) << 22
      binary+= 0b111111111111111111111 & a
      return binary
    end

    def encode_scall instr
      codeop,args=instr
      binary=OPCODE[codeop] << 27
      n=args.first.to_i
      binary+=n
      return binary
    end

    def encode_stop instr
      codeop,args=instr
      binary=OPCODE[codeop] << 27
      return binary
    end
  end
end

if $PROGRAM_NAME==__FILE__
  SIMJI::Assembler.new.assemble ARGV.first
end
