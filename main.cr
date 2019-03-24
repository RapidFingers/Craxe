class HaxeStd
  def self.string(v) : String
    v.to_s
  end
end

class Fibonacci
  def self.fib(n : Int)
    if n <= 2
      return 1
    end

    return fib(n - 1) + fib(n - 2)
  end

  def self.main
    pp(fib(50))
  end
end

Fibonacci.main
