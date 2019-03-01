require "optparse"
require "ostruct"

require_relative "version"
require_relative "assembler"
require_relative "disassembler"
require_relative "iss"
require_relative "gui"

module SIMJI

  class Runner

    def self.run *arguments
      new.run(arguments)
    end

    def run arguments
      options = parse_options(arguments)
      if options.assemble
        assemble(options.file)
      elsif options.disassemble
        disassemble(options.file)
      elsif options.gui_mode
        prog = options.prog_file
        data = options.data_file
        gui prog,data
      elsif options.simulate
        prog = options.prog_file
        data = options.data_file
        interactive = options.interactive
        simulate prog,data,interactive
      end
    end

    private
    def parse_options(arguments)

      size=arguments.size

      parser = OptionParser.new

      options = OpenStruct.new

      parser.on("-h", "--help", "Show help message") do
        puts parser
        exit(true)
      end

      parser.on("-v", "--version", "Show version number") do
        puts VERSION
        exit(true)
      end

      parser.on("-a", "--assemble FILE", "Assemble <file.asm> => (ascii) <file.bin>") do |file|
        options.assemble = true
        options.file     = file
      end

      parser.on("-d", "--disassemble FILE") do |file|
        options.disassemble = true
        options.file     = file
      end

      parser.on("-s", "--simulate FILE") do |file|
        options.simulate = true
        options.prog_file = file
      end

      parser.on("--data FILE") do |file|
        options.data_init = true
        options.data_file = file
      end

      parser.on("-i","--interactive", "(will ask a key stoke for each 'tick')") do
        options.interactive = true
      end

      parser.on("--gui") do |file|
        options.gui_mode = true
      end

      parser.parse!(arguments)

      if size==0
        puts parser
      end

      options
    end

    def assemble asm_file
      Assembler.new.assemble asm_file
    end

    def disassemble asm_file
      Disassembler.new.disassemble_file asm_file
    end

    def simulate prog_file,data_file=nil,interactive
      simulator = ISS.new
      simulator.interactive = interactive
      simulator.load_prog_in_memory(prog_file)
      simulator.load_data_in_memory(data_file) if data_file
      simulator.run
    end

    def gui prog_file,data_file=nil
      glade_file = File.expand_path(__dir__)+"/gui_v1.glade"
      gui = GUI.new(glade_file)
      gui.iss.load_prog_in_memory(prog_file) if prog_file
      gui.iss.load_data_in_memory(data_file) if data_file
      gui.run
    end

  end
end
