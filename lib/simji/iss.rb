
require_relative 'opcodes'
require_relative 'eda_utils'

#-------should be removed--------
require_relative 'disassembler'
#---------------------------------

require 'gtk3' # === for timers that can be paused

module SIMJI

  class ISS

    attr_accessor :mem_instr,:data,:reg
    attr_accessor :old_pc,:addr
    attr_accessor :pc
    attr_accessor :r1,:final_o,:r2 # made accessible for GUI
    attr_accessor :flag
    attr_accessor :stopped,:is_load

    attr_accessor :interactive

    def initialize params={}
      puts "ISS/VM for 4.5"
      @params=params
      @dis=Disassembler.new
    end

    def apply filename
      load_in_memory(filename)
      run
    end

    def load_prog_in_memory filename
      @mem_instr=[]
      IO.readlines(filename).each do |line|
        addr,data=line.split(" ").collect{|e| e.to_i(16)}
        @mem_instr[addr]=data
      end
      puts "loaded prog '#{filename}'"
    end

    def load_data_in_memory filename
      @data=[]
      IO.readlines(filename).each do |line|
        addr,data=line.split(" ").collect{|e| e.to_i(16)}
        @data[addr]=data
      end
      puts "loaded data '#{filename}'"
    end

    def show_regs
      @timer.stop
      tab=[]
      @reg.each_with_index{|r,i| tab << "r#{i.to_s.rjust(2)}=0x#{r.to_s(16).rjust(8,'0')} "}
      slices=tab.each_slice(8).to_a
      slices.each do |slice|
        slice.each do |r|
          print r
        end
        puts
      end
      @timer.continue
    end

    def show_mem
      @mem_instr.each_with_index do |code,idx|
        puts "0x#{idx.to_s(16).rjust(8,'0')} 0x#{code.to_s(16).rjust(8,'0')}"
      end
    end

    def init
      @stopped=false
      @pc=0
      @running=true
      @reg  = Array.new(32,0)
      @data = Array.new(1024,0) #1 Ko
      @r1,@r2=nil,nil
      @nb_instr=0
      @timer=GLib::Timer.new #started
    end

    def decode code
      puts @dis.disassemble code

      opcode=code.bit_field(31..27)

      @r1,@flag,o,@r2=extract([26..22,21..21,20..5,4..0],code)
      puts "r1=#{@r1},flag=#{@flag},o=#{o},r2=#{r2}"
      puts r2
      @addr=nil
      @final_o = (flag==1) ? o : @reg[o]

      @is_load =false #for GUI

      case opcode
      when OPCODE[:add]
        @reg[r2]=@reg[r1] + final_o
      when OPCODE[:sub]
        @reg[r2]=@reg[r1] - final_o
      when OPCODE[:mul]
        @reg[r2]=@reg[r1] * final_o
      when OPCODE[:div]
        @reg[r2]=@reg[r1] / final_o
      when OPCODE[:and]
        @reg[r2]=@reg[r1] & final_o
      when OPCODE[:or]
        @reg[r2]=@reg[r1] | final_o
      when OPCODE[:xor]
        @reg[r2]=@reg[r1] ^ final_o
      when OPCODE[:shl]
        @reg[r2]=@reg[r1] << final_o
      when OPCODE[:slt]
        @reg[r2]=(@reg[r1] <  final_o) ? 1 : 0
      when OPCODE[:sle]
        @reg[r2]=(@reg[r1] <= final_o) ? 1 : 0
      when OPCODE[:seq]
        @reg[r2]=(@reg[r1] == final_o) ? 1 : 0
      when OPCODE[:load]
        @is_load =true #for GUI
        @addr = @reg[r1] + (flag==1 ? o : @reg[o])
        @reg[r2]=@data[addr]
        @r1,@flag,@final_o,@r2=nil,nil,nil,nil
      when OPCODE[:store]
        @addr = @reg[r1] + (flag==1 ? o : @reg[o])
        @data[addr]=@reg[@r2]
        @r1,@flag,@final_o=nil,nil,nil
      when OPCODE[:jmp]
        flag_jmp,o_jump,r_jmp = extract([26..26,25..5,4..0],code)
        address = flag_jmp==0 ? @reg[o_jump] : o_jump
        @reg[r_jmp] = @pc+1 if r_jmp!=0
        @r1,@flag,@final_o,@r2=nil,nil,nil,nil
        return address
      when OPCODE[:braz]
        @r1,@flag,@final_o,@r2=nil,nil,nil,nil
        r,a=extract([26..22,21..0],code)
        return a if @reg[r]==0
      when OPCODE[:branz]
        @r1,@flag,@final_o,@r2=nil,nil,nil,nil
        r,a=extract([26..22,21..0],code)
        return a if @reg[r]!=0
      when OPCODE[:scall]
        @timer.stop
        @r1,@flag,@final_o,@r2=nil,nil,nil,nil
        n=extract [26..0],code
        n=n.shift
        case n
        when 0
          @timer.stop
          puts txt="scall 0 : read an integer"
          if gui=@params[:gui]
            gui.log.insert_at_cursor txt+"\n"
          else
            @reg[1]=$stdin.gets.chomp.to_i
          end
        when 1
          puts txt="scall 1 : write"
          if gui=@params[:gui]
            gui.log.insert_at_cursor txt+" r1=#{@reg[1]}\n"
            gui.label_r1.text="#{@reg[1]}"
          end
          puts @reg[1]
        else
          raise "scall #{n} unknown"
        end
        @timer.continue

      when OPCODE[:stop]

        @stopped=true
        @r1,@flag,@final_o,@r2=nil,nil,nil,nil
        if gui=@params[:gui]
          show_stats
          gui.log.insert_at_cursor "ISS : stop\n"
        else
          show_stats
          raise "ISS : STOP"
        end


      else
        raise "ISS : unknown opcode"
      end
      @reg[0]=0
      return nil
    end

    def show_stats
      secs = @timer.elapsed.first
      perf = (@nb_instr / secs).round(3)
      txt ="-"*80+"\n"
      txt+=tx2="#instructions executed : #{@nb_instr}\n"
      txt+="#wall clock            : #{secs}\n"
      txt+="performance            : #{perf} instr/s\n"
      txt+="-"*80+"\n"
      if gui=@params[:gui]
        gui.log.insert_at_cursor tx2
      else
        puts txt
      end
    end

    def extract fields,code
      fields.collect{|field| code.bit_field(field)}
    end

    def run
      begin
        init
        while @running
          @timer.stop
          puts "fetching @ #{@pc}"
          if @interactive
            print "hit a key !"
            key=$stdin.gets.chomp
          end
          @timer.continue
          step
        end
      rescue Exception => e
        puts e
      end
    end

    def step
      code=@mem_instr[@pc]
      next_addr=decode(code)
      @nb_instr+=1
      @old_pc = @pc
      @pc = next_addr || @pc+1
      show_regs
    end
  end

end #module

if __FILE__ == $PROGRAM_NAME
  SIMJI::ISS.new.apply(ARGV.first)
end
