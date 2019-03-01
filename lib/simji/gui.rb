require 'gtk3'

require_relative 'iss'

BLACK   =  [0.0,0.0,0.0]
GREY    = Gdk::RGBA::new(0.2, 0.2, 0.2, 1)
RED     = Cairo::Color.parse("red")
CYAN    = Cairo::Color.parse("cyan")
YELLOW  = Cairo::Color.parse("yellow")
GREEN   = Cairo::Color.parse("green")
ORANGE  = Cairo::Color.parse("orange")

module SIMJI

  class GUI

    attr_accessor :label_r1 #needed by ISS
    attr_accessor :log #needed by ISS
    attr_accessor :iss #needed by runner

    def initialize glade_path
      @builder = Gtk::Builder.new
      @builder.add_from_file(glade_path)
      @builder.connect_signals {|handler| method (handler) }

      @main_window = @builder['window1']
      @main_window.signal_connect("destroy"){Gtk.main_quit}

      @drawing =@builder['drawingarea1']
      @drawing.signal_connect("draw"){redraw}

      @log = @builder['textview1']
      @label_cycles = @builder['label3']
      @label_r1     = @builder['label6']
      @label_pc     = @builder['label_pc']
      @entry2= @builder['entry2']

      @timer=GLib::Timeout.add(100){on_timeout}
      @pause=true
      @nb_cycles=0

      @iss=ISS.new(:gui=> self)
      @iss.init
      @disassembler=Disassembler.new
    end

    def run
      @main_window.show
      Gtk.main
    end

    # signal handler for main window destory event
    def quit
      Gtk.main_quit
    end

    def on_ISS_clicked
      about = Gtk::AboutDialog.new
      about.set_program_name "Educational program for Computer Architecture"
      about.set_version "0.1"
      about.set_copyright "(c) Jean-Christophe Le Lann"
      about.set_comments "Simplified MIPS-like processor"
      about.set_website "http://www.jcll.fr"
      begin
        dir = File.expand_path(__dir__)
        logo = GdkPixbuf::Pixbuf.new :file => "#{dir}/logo.png"
        about.set_logo logo
      rescue IOError => e
          puts e
          puts "cannot load image"
          exit
      end
      about.run
      about.destroy
    end

    def on_filechooserbutton1_file_set chooser
      @iss.load_prog_in_memory chooser.filename
    end

    def on_filechooserbutton2_file_set chooser
      @iss.load_data_in_memory chooser.filename
      redraw
    end

    def on_button_step_clicked
      puts "on_button_step_clicked"
      @nb_cycles+=1
      if !@iss.stopped
        @iss.step
      else
        @log.insert_at_cursor "ISS is stopped !\n"
      end
      rewrite_info
      redraw
    end

    def on_button_run_clicked
      puts "on_button_run_clicked"
      @pause=false
      @nb_cycles_to_run=@entry_value
      @nb_cycles_reached=false
    end

    def on_entry1_changed entry
      puts "on_entry1_changed #{entry.text}"
      @entry_value=entry.text.to_i
      @entry_value=nil if @entry_value==0
      @nb_cycles_to_run=@entry_value
      @nb_cycles_reached=false
      @pause=true
    end

    def on_button_stop_clicked
      puts "on_button_stop_clicked"
      @pause=true
      @nb_cycles_to_run=nil
      @nb_cycles_reached=true
    end

    def on_button_boot_clicked
      @iss.pc=@boot_address
    end

    def on_entry_boot_changed entry
      @boot_address=(entry.text.to_i)||0
    end

    def on_button_syscall_0_clicked
      puts "on_button_sycall_0_clicked"
      @iss.reg[1]=@r1_value
      @just_entered=true
      @log.insert_at_cursor "done\n"
      redraw
      @just_entered=false
    end

    def on_entry2_changed entry
      puts "on_entry2_changed #{entry.text}"
      @r1_value=entry.text.to_i
      @log.insert_at_cursor "please valid !\n"
    end

    def on_button_reset_clicked
      puts "on_button_reset_clicked"
      @pause=true
      @y=0
      @nb_cycles=0
      @nb_cycles_to_run=nil
      @nb_cycles_reached=false
      @label_cycles.text="0"
      @label_r1.text=""
      @iss.init
      @log.buffer=Gtk::TextBuffer.new
      @entry2.text=""
      redraw
    end

    def on_button_reset_log_clicked
      puts "on_button_reset_log_clicked"
      @log.buffer=Gtk::TextBuffer.new
    end

    def on_timeout
      unless @pause or @nb_cycles_reached
        puts "nb_cycles       : #{@nb_cycles}"
        puts "# cycles to run : #{@nb_cycles_to_run}"
        if !@iss.stopped
          @iss.step
          @nb_cycles+=1
          @nb_cycles_to_run-=1 if @nb_cycles_to_run
          @nb_cycles_reached=@nb_cycles_to_run==0
          @nb_cycles_to_run=nil if @nb_cycles_reached
        else
          @nb_cycles_to_run=0
          @nb_cycles_reached=true
        end
        rewrite_info
        redraw
      end
      true # <---- dont forget this one !!:
    end

    def rewrite_info
      text="#{@nb_cycles}"
      #@log.insert_at_cursor text+"\n"
      @label_cycles.text=text
      @label_pc.text="#{@iss.pc}"
    end

    def redraw
      cr = @drawing.window.create_cairo_context
      cr.set_source_rgba GREY
      cr.paint
      draw_instr_mem(cr)
      draw_registers(cr)
      draw_data_mem(cr,20)
    end

    def draw_instr_mem cr
      if @iss.mem_instr
        #cr.set_font "Monospace"
        cr.select_font_face "Monospace"
        cr.set_font_size 13
        @iss.mem_instr.each_with_index do |instr,addr|
          if @iss.old_pc==addr
            cr.set_source_rgba GREEN.red,GREEN.green,GREEN.blue
          else
            cr.set_source_rgba YELLOW.red,YELLOW.green,YELLOW.blue
          end
          cr.move_to 10, 20+addr*15
          a_hex=addr.to_s(16).rjust(4,'0')
          i_hex=instr.to_s(16).rjust(8,'0')
          asm = @disassembler.disassemble(instr)
          cr.show_text "#{a_hex} #{i_hex}  #{asm}"
        end
      end
    end

    def draw_data_mem cr,limit=100
      if @iss.data
        cr.set_font_size 13
        @iss.data[0..limit].each_with_index do |instr,addr|
          if @iss.addr==addr
            if @iss.is_load
              cr.set_source_rgba GREEN.red,GREEN.green,GREEN.blue
            else
              cr.set_source_rgba RED.red,RED.green,RED.blue
            end
          else
            cr.set_source_rgba YELLOW.red,YELLOW.green,YELLOW.blue
          end
          cr.move_to 500, 20+addr*15
          a_hex=addr.to_s(16).rjust(4,'0')
          i_hex=instr.to_s(16).rjust(8,'0')
          cr.show_text "#{a_hex} #{i_hex}"
        end
      end
    end

    def draw_registers cr
      cr.set_font_size 14
      @iss.reg.each_with_index do |reg,i|
        cr.set_source_rgba YELLOW.red,YELLOW.green,YELLOW.blue
        cr.move_to 300, 20+i*15
        reg_s="r#{i}".ljust(4)
        val_hex=reg.to_s(16).rjust(8)
        if (i==@iss.r1) or ((i==@iss.final_o) and (@iss.flag==0))
          puts "GREEN : r#{i} #{@iss.flag}"
          cr.set_source_rgba GREEN.red,GREEN.green,GREEN.blue
        end
        if i==@iss.r2
          cr.set_source_rgba RED.red,RED.green,RED.blue
        end
        if i==1 and @just_entered
          cr.set_source_rgba ORANGE.red,ORANGE.green,ORANGE.blue
        end
        cr.show_text "#{reg_s}=#{val_hex}"
      end
    end

  end
end #module

if $PROGRAM_NAME == __FILE__
  SIMJI::GUI.new('gui_v1.glade').run
end
