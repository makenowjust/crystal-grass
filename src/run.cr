module Grass
  #  __  __            _     _            
  # |  \/  | __ _  ___| |__ (_)_ __   ___ 
  # | |\/| |/ _` |/ __| '_ \| | '_ \ / _ \
  # | |  | | (_| | (__| | | | | | | |  __/
  # |_|  |_|\__,_|\___|_| |_|_|_| |_|\___|

  class Machine
    def initialize(@code : Code, @env : Env, @dump : Dump); end

    property code, env, dump

    def push_dump
      @dump << Frame.new(@code, @env)
    end

    def pop_dump
      @dump.pop
    end

    def fetch_env(index)
      if value = @env[-index]?
        value
      else
        raise "out of bound"
      end
    end
  end

  alias Code = Array(Insn)
  alias Env  = Array(Value)
  alias Frame = Tuple(Code, Env)
  alias Dump = Array(Frame)

  #  ___           _                   _   _             
  # |_ _|_ __  ___| |_ _ __ _   _  ___| |_(_) ___  _ __  
  #  | || '_ \/ __| __| '__| | | |/ __| __| |/ _ \| '_ \ 
  #  | || | | \__ \ |_| |  | |_| | (__| |_| | (_) | | | |
  # |___|_| |_|___/\__|_|   \__,_|\___|\__|_|\___/|_| |_|

  abstract class Insn
    def eval(machine : Machine) : Void
      raise "not implemented"
    end
  end

  class App < Insn
    def initialize(@fn : Int32, @arg : Int32); end

    def eval(machine : Machine)
      fn = machine.fetch_env @fn
      arg = machine.fetch_env @arg
      fn.call machine, arg
    end
  end

  class Abs < Insn
    def initialize(@arity : Int32, @code : Code); end

    def eval(machine : Machine)
      machine.env << Fn.new(@arity, @code.dup, machine.env.dup)
    end
  end

  class Fetch < Insn
    def initialize(@index : Int32); end

    def eval(machine : Machine)
      machine.env << machine.fetch_env(@index)
    end
  end

  # __     __    _            
  # \ \   / /_ _| |_   _  ___ 
  #  \ \ / / _` | | | | |/ _ \
  #   \ V / (_| | | |_| |  __/
  #    \_/ \__,_|_|\__,_|\___|

  abstract class Value
    def byte : UInt8
      raise "not a char"
    end

    def call(machine : Machine, arg : Value) : Void
      raise "not implemented"
    end
  end

  class Fn < Value
    def initialize(@arity : Int32, @code : Code, @env : Env); end

    def call(machine : Machine, arg : Value)
      env = @env.dup
      env << arg

      if @arity == 1
        machine.push_dump unless machine.code.empty? # TCO
        machine.code = @code.dup
        machine.env = env
      else
        machine.env << Fn.new(@arity - 1, @code, env)
      end
    end
  end

  TrueFn  = Fn.new 2, Code{Fetch.new 2}, Env.new
  FalseFn = Fn.new 2, Code{Fetch.new 1}, Env.new

  class ByteFn < Value
    def initialize(@byte : UInt8); end

    getter byte

    def call(machine : Machine, arg : Value)
      machine.env << (byte == arg.byte ? TrueFn : FalseFn)
    end
  end

  class Succ < Value
    def call(machine : Machine, arg : Value)
      machine.env << ByteFn.new(arg.byte + 1)
    end
  end

  class Out < Value
    def call(machine : Machine, arg : Value)
      STDOUT.write_byte arg.byte
      STDOUT.flush
      machine.env << arg
    end
  end

  class In < Value
    def call(machine : Machine, arg : Value)
      byte = STDIN.read_byte
      if byte
        machine.env << ByteFn.new(byte)
      else
        machine.env << arg
      end
    end
  end

  #  ____                     
  # |  _ \ __ _ _ __ ___  ___ 
  # | |_) / _` | '__/ __|/ _ \
  # |  __/ (_| | |  \__ \  __/
  # |_|   \__,_|_|  |___/\___|

  def self.parse(source : String) : Code
    source
      .tr("ｗＷｖ", "wWv")
      .sub(/\A[^w]+/, "")
      .gsub(/[^wWv]+/, "")
      .split("v")
      .flat_map do |src|
        counts = src.scan(/w+|W+/).map &.[0].size
        arity = src =~ /\Aw+/ ? counts.shift? : nil

        raise "parse error at app" unless counts.size.even?

        code = Code.new
        until counts.empty?
          code << App.new(counts.shift, counts.shift)
        end

        arity ? Code{Abs.new(arity, code)} : code
      end
  end

  #  _____            _ 
  # | ____|_   ____ _| |
  # |  _| \ \ / / _` | |
  # | |___ \ V / (_| | |
  # |_____| \_/ \__,_|_|

  def self.eval(machine : Machine)
    loop do
      if insn = machine.code.shift?
        insn.eval machine
      else
        break if machine.dump.empty?

        result = machine.fetch_env 1
        machine.code, machine.env = machine.pop_dump
        machine.env << result
      end
    end
  end

  #  ____              
  # |  _ \ _   _ _ __  
  # | |_) | | | | '_ \ 
  # |  _ <| |_| | | | |
  # |_| \_\\__,_|_| |_|

  def self.run(source : String)
    code = parse source
    env = Env{In.new, ByteFn.new('w'.ord.to_u8), Succ.new, Out.new}
    dump = Dump{Frame.new(Code.new, Env.new), Frame.new(Code{App.new(1, 1)}, Env.new)}
    machine = Machine.new code, env, dump

    eval machine
  end
end
