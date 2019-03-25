class HaxeStd
  def self.string(v) : String
    v.to_s
  end
end

class MyType
  end

  class ArrayTest
    def self.main
      arr = Array.new()
      arr.push(MyType.new())
      arr.push(MyType.new())
      arr.push(MyType.new())
      pp(arr)
    end
  end

  ArrayTest.main
