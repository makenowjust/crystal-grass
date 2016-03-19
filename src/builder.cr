module Grass
  class Builder
    def initialize(@io : IO)
      @env = [in, w, succ, out]
      @in_lambda = false
      @prev = nil
      @id = 0
    end

    def in; @in ||= allocate_ref("in") end
    def w; @w ||= allocate_ref("w") end
    def succ; @succ ||= allocate_ref("succ") end
    def out; @out ||= allocate_ref("out") end

    getter io, env

    def lambda(arity : Int32)
      raise "cannot nest lambda" if @in_lambda
      raise "invalid arity" if arity <= 0

      @in_lambda = true
      env = @env
      @env = env.dup

      put_sep :lambda

      io << "w" * arity
      args = (1..arity).map { allocate_ref("arg") }
      @env.concat args

      yield args

      @env = env
      @in_lambda = false

      @prev = :lambda

      allocate_ref("lambda").tap { |ref| @env << ref }
    end

    def allocate_ref(name)
      @id += 1
      return Reference.new(self, "#{name}#{@id}")
    end

    def put_sep(type)
      if prev = @prev
        io << 'v' if type == :lambda || !@in_lambda && type == :call && prev != :call
      end
      @prev = type
    end

    class Reference
      def initialize(@builder : Builder, @name : String); end

      def index
        if index = @builder.env.rindex &.same?(self)
          @builder.env.size - index
        else
          raise "out of scope"
        end
      end

      def call(args : Enumerable(Reference))
        @builder.put_sep :call
        args.reduce(self) do |fn, arg|
          @builder.io << "W" * fn.index
          @builder.io << "w" * arg.index
          @builder.allocate_ref("call").tap { |ref| @builder.env << ref }
        end
      end

      def call(*args : Reference)
        call args
      end
    end
  end

  def self.build
    String.build do |io|
      with Builder.new(io) yield
    end
  end
end

print_w = Grass.build do
  main = lambda(1) { out.call w }
end

loop_w = Grass.build do
  main = lambda(1) { |args| out.call w; args[0].call args[0] }
end

echo = Grass.build do
  loop = lambda(2) { |args| out.call args[0]; args[1].call args[1] }
  exit = lambda(2) { }
  main = lambda(1) { |args|
    result = in.call w
    result.call(w)
      .call(exit, loop)
      .call(result, args[0])
  }
end

tic_tac_toe = Grass.build do
  builder = itself

  n_0 = lambda(2) { }
  n_1 = lambda(2) { |args| args[0].call args[1] }
  n_2 = lambda(2) { |args| args[0].call args[0].call args[1] }
  n_succ = lambda(3) { |args| args[1].call args[0].call args[1], args[2] }
  n_plus = lambda(2) { |args| args[0].call n_succ, args[1] }
  n_mul = lambda(2) { |args| args[0].call n_plus.call(args[1]), n_0 }
  n_pow = lambda(2) { |args| args[1].call n_mul.call(args[0]), n_1 }
  n_3 = n_succ.call n_2
  n_5 = n_plus.call n_2, n_3
  n_7 = n_plus.call n_5, n_2
  n_8 = n_succ.call n_7
  n_12 = n_plus.call n_5, n_7
  n_24 = n_mul.call n_12, n_2
  n_32 = n_pow.call n_2, n_5
  n_128 = n_pow.call n_2, n_7
  n_147 = n_plus.call n_128, n_plus.call n_12, n_7
  n_169 = n_plus.call n_147, n_plus.call n_12, n_plus.call n_5, n_5
  n_185 = n_plus.call n_169, n_mul.call n_2, n_8
  n_224 = n_mul.call n_7, n_32
  n_248 = n_plus.call n_224, n_24
 
  l_lf = n_147.call succ, w
  l_bar = n_5.call succ, w
  l_sp = n_169.call succ, w
  l_plus = n_plus.call(n_8, n_3).call(succ, l_sp)
  l_min = n_2.call(succ, l_plus)
  l_0 = n_185.call succ, w
  l_8 = n_8.call succ, l_0
  l_9 = succ.call l_8
  l_gt = n_5.call succ, l_9
  l_a = n_plus.call(n_32, n_8).call succ, l_9
  l_c = n_2.call succ, l_a
  l_d = succ.call l_c
  l_i = n_5.call succ, l_d
  l_nn = n_5.call succ, l_i

  out1 = lambda(1) { |args| out.call args[0] }
  board_show = lambda(9) { |args|
    lf = l_lf
    sp = l_sp
    bar = l_bar
    plus = l_plus
    min = l_min
    3.times do |i|
      3.times do |j|
        sp = out.call sp
        out1.call args[i * 3 + j]
        sp = out.call sp
        bar = out.call bar if j < 2
      end
      lf = out1.call lf
      if i < 2
        11.times do |i|
          if (i + 1) % 4 == 0
            plus = out1.call plus
          else
            min = out1.call min
          end
        end
        lf = out1.call lf
      end
    end
  }

  ret = lambda(1) { }
  yes = lambda(2) { |args| ret.call args[0] }
  no = lambda(2) { }

  check_three = lambda(3) { |args|
    args[0].call(args[1]).call(args[0].call(args[2]), no).call(args[0], l_sp)
  }
  board_check = lambda(9) { |args|
    pats = [] of Grass::Builder::Reference

    # diagonal
    pats << check_three.call args[0], args[4], args[8]
    pats << check_three.call args[2], args[4], args[6]

    # vertical
    pats.concat (0...3).map { |i| check_three.call (0...3).map { |j| args[i + j * 3] } }

    # horizontal
    pats.concat (0...3).map { |i| check_three.call (0...3).map { |j| args[i * 3 + j] } }

    pats.reduce(l_sp) { |ret, pat| pat.call(l_sp).call(ret, pat) }
  }

  check_two = lambda(3) { |args|
    args[0].call(args[1]).call(args[2].call(l_sp).call(args[0], l_sp),
      args[0].call(args[2]).call(args[1].call(l_sp).call(args[0], l_sp),
        args[1].call(args[2]).call(args[0].call(l_sp).call(args[1], l_sp), l_sp)))
  }
  board_check_two = lambda(9) { |args|
    pats = [] of Grass::Builder::Reference

    # diagonal
    pats << check_two.call args[0], args[4], args[8]
    pats << check_two.call args[2], args[4], args[6]

    # vertical
    pats.concat (0...3).map { |i| check_two.call (0...3).map { |j| args[i + j * 3] } }

    # horizontal
    pats.concat (0...3).map { |i| check_two.call (0...3).map { |j| args[i * 3 + j] } }

    pats.reduce(l_sp) { |ret, pat| pat.call(l_sp).call(ret, pat) }
  }

  cons = lambda(3) { |args| args[2].call args[0], args[1] }

  g = (0...9).map do |i|
    builder.lambda(9) { |args| ret.call args[i] }
  end
  gs = g.reverse.reduce(yes){ |t, v| cons.call v, t }
  u_gen =builder.lambda(4) { |args|
    args[1].call(args[0].call args[2]).call(args[3])
  }
  u = (0...9).map do |i|
    update = builder.lambda(11) { |args|
      new_board = (0...9).map do |j|
        i == j ? args[0] : args[j + 1]
      end
      args[10].call new_board
    }
    u_gen.call update
  end
  us = u.reverse.reduce(yes){ |t, v| cons.call v, t }

  l_x = succ.call w
  l_y = succ.call l_x
  l_o = n_248.call succ, w
  l_p = succ.call l_o
  l_r = n_2.call succ, l_p
  l_u = n_3.call succ, l_r

  out2 = lambda(1) { |args| out1.call args[0] }
  draw = lambda(1) { |args|
    out2.call l_d
    out2.call l_r
    out2.call l_a
    out2.call w
    out2.call l_lf
  }

  win = lambda(1) { |args|
    out2.call l_sp
    out2.call w
    out2.call l_i
    out2.call l_nn
    out2.call l_lf
  }

  you_win = lambda(1) { |args|
    out2.call l_y
    out2.call l_o
    out2.call l_u
    win.call(args[0])
  }

  cpu_win = lambda(1) { |args|
    out2.call l_c
    out2.call l_p
    out2.call l_u
    win.call(args[0])
  }

  finish = lambda(9) { |args|
    check = args[5]
    check.call(l_sp)
      .call(draw, check.call(l_o).call(you_win, cpu_win))
      .call(check)
  }

  succ1 = lambda(1) { |args| succ.call args[0] }
  loop7 = lambda(9) { |args|
    l0 = args[0]; update = args[2].call(no); board = args[3]; n = args[4]

    board = update.call board, l_x
    n = succ1.call n

    out2.call l_c
    out2.call l_p
    out2.call l_u
    gt = out2.call l_gt
    gt = out2.call gt
    gt = out2.call gt
    out2.call l_lf

    l0.call l0, board, n
  }

  loop6 = lambda(9) { |args|
    l0 = args[0]; l5 = args[1]; uflag = args[2].call(yes); update_ = args[2].call(no); board = args[3]; n = args[4]; l_n = args[5]; uss = args[6]; gss = args[7]; update = args[8]

    board1 = update.call board, l_x
    check = board1.call board_check
    check21 = board.call board_check_two
    check22 = board1.call board_check_two

    check.call(l_x)
      .call(loop7, l_n.call(l_9).call(loop7, l5))
      .call(l0, l5,
        cons.call(
          succ1.call(uflag),
          check.call(l_x).call(
            update,
            uflag.call(l_0).call(
              update,
              check21.call(l_o).call(
                check22.call(l_sp).call(update, update_),
                check22.call(l_x).call(update, update_))))), board, n, l_n, uss, gss, yes)
  }

  loop5 = lambda(9) { |args|
    l0 = args[0]; l5 = args[1]; update = args[2]; board = args[3]; n = args[4]; l_n = args[5]; uss = args[6]; gss = args[7]

    board.call(gss.call(yes)).call(l_sp)
      .call(loop6, l_n.call(l_8).call(loop7, l5))
      .call(l0, l5, update, board, n, succ1.call(l_n), uss.call(no), gss.call(no), uss.call(yes))
  }

  loop4 = lambda(9) { |args|
    l0 = args[0]; board = args[3]; n = args[4]; update = args[5]

    board = update.call(board, l_o)
    board.call board_show
    out.call l_lf

    n = succ1.call n

    check = board.call board_check
    check.call(l_sp)
      .call(n.call(l_9).call(finish, loop5), finish)
      .call(l0, loop5, cons.call(l_0, yes), board, n, check.call(l_sp).call(n.call(l_9).call(check, l_0), check), us, gs, yes)
  }

  loop3 = lambda(11) { |args|
    update = args[0]; get = args[1]; l0 = args[2]; l1 = args[3]; l2 = args[4]; board = args[5]; n = args[6]

    # skip new line
    in.call args[9]

    board.call(get).call(l_sp)
      .call(loop4, l1)
      .call(l0, l1, l2, board, n, update, yes, yes, yes)
  }

  loop2 = lambda(9) { |args|
    l0 = args[0]; l1 = args[1]; l2 = args[2]; board = args[3]; n = args[4]; input = args[5]; l_n = args[6]; uss = args[7]; gss = args[8]

    l_n.call(input)
      .call(loop3.call(uss.call(yes), gss.call(yes)), l_n.call(l_8).call(l1, l2))
      .call(l0, l1, l2, board, n, input, succ1.call(l_n), uss.call(no), gss.call(no))
  }

  loop1 = lambda(9) { |args|
    l0 = args[0]; l1 = args[1]; l2 = args[2]; board = args[3]; n = args[4]

    out2.call l_lf
    out2.call l_y
    out2.call l_o
    out2.call l_u
    gt = out2.call l_gt
    gt = out2.call gt
    gt = out2.call gt
    out2.call l_sp
    input = in.call w
    input.call(w).call(finish, loop2).call(l0, l1, loop2, board, n, input, l_0, us, gs)
  }

  loop0 = lambda(3) { |args|
    l0 = args[0]; board = args[1]; n = args[2]

    board.call board_show
    check = board.call board_check
    check.call(l_sp).call(loop1, finish).call(l0, loop1, loop2, board, n, check, yes, yes, yes)
  }

  initial_board = lambda(1) { |args| args[0].call l_sp, l_sp, l_sp, l_sp, l_sp, l_sp, l_sp, l_sp, l_sp }

  main = lambda(1) { |args|
    board = initial_board
    l_n = l_0
    9.times do |i|
      board = u[i].call(board, l_n)
      l_n = succ1.call l_n
    end
    board.call board_show
    out.call l_lf

    loop0.call loop0, initial_board, l_0
  }
end

kiyosi = Grass.build do
  builder = itself

  n_2 = lambda(2) { |args| args[0].call args[0].call args[1] }
  n_succ = lambda(3) { |args| args[1].call args[0].call args[1], args[2] }
  n_3 = n_succ.call n_2
  n_4 = n_succ.call n_3
  n_5 = n_succ.call n_4
  n_6 = n_succ.call n_5
  n_plus = lambda(2) { |args| args[0].call n_succ, args[1] }
  n_10 = n_plus.call n_4, n_6
  n_12 = n_plus.call n_2, n_10
  n_13 = n_succ.call n_12
  n_0 = lambda(2) { }
  n_mul = lambda(2) { |args| args[0].call n_plus.call(args[1]), n_0 }
  n_31 = n_succ.call n_mul.call n_3, n_10
  n_39 = n_mul.call n_3, n_13

  id = lambda(1) { }
  succ1 = id.call succ

  w1 = id.call w
  const = w1.call w1
  i_0 = w1
  i_1 = succ1.call i_0
  yes = w1.call w1
  no = w1.call i_1
  is_even = lambda(2) { |args|
    args[1].call(i_0)
      .call(const.call(yes), args[1].call(i_1).call(const.call(no), args[0].call(args[0])))
      .call(succ1.call succ1.call args[1])
  }
  is_even = is_even.call is_even
  in1 = id.call in
  m15_init = lambda(1) { |args|
    args[0].call (1..15).map{ |i| i % 2 == 0 ? no : is_even.call(in1.call(w1)) }
  }
  m15_next = lambda(16) { |args|
    args[15].call(
      args[0].call(args[14].call(no, yes), args[14].call(yes, no)),
      args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13])
  }
  m15_get = lambda(15) { |args|
    id.call args[0]
  }

  succ1 = id.call succ1

  w1 = id.call w
  c_119 = w1
  c_129 = n_10.call succ1, c_119
  c_130 = succ1.call c_129
  c_131 = succ1.call c_130
  c_137 = n_6.call succ1, c_131
  c_168 = n_31.call succ1, c_137
  c_173 = n_5.call succ1, c_168
  c_179 = n_6.call succ1, c_173
  c_183 = n_4.call succ1, c_179
  c_186 = n_3.call succ1, c_183
  c_187 = succ1.call c_186
  c_188 = succ1.call c_187
  c_227 = n_39.call succ1, c_188
  c_239 = n_12.call succ1, c_227

  zun = [c_227, c_130, c_186, c_227, c_131, c_179]
  doko = [c_227, c_131, c_137, c_227, c_130, c_179]
  kiyosi = [c_227, c_130, c_173, c_227, c_131, c_187, c_227, c_131, c_168, c_227, c_131, c_187, c_227, c_130, c_183, c_239, c_188, c_129]

  out1 = lambda(1) { |args| out.call args[0] }
  out_zun = lambda(1) { zun.each { |c| out1.call c } }
  out_doko = lambda(1) { doko.each { |c| out1.call c } }
  out_kiyosi = lambda(3) { kiyosi.each { |c| out1.call c } }

  i_2 = succ1.call i_1
  i_3 = succ1.call i_2
  i_4 = succ1.call i_3
  
  loop = lambda(3) { |args|
    lp = args[0]; zun_count = args[1]; m = args[2]

    m = m.call m15_next
    cur = m.call m15_get
    cur.call(out_zun, out_doko).call(cur)

    is_zun_4 = zun_count.call(i_4)
    zun_count_next = cur.call(is_zun_4.call(zun_count, succ.call(zun_count)), i_0)

    is_zun_4
      .call(cur.call(lp, out_kiyosi), lp)
      .call(lp, zun_count_next, m)
  }
  loop = loop.call loop

  main = lambda(1) { |args|
    m = m15_init
    loop.call(i_0, m)
  }
end

puts kiyosi
