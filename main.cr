class HaxeStd
  def self.string(v) : String
    v.to_s
  end
end

class HaxeArray(T) < Array(T)
end

class MyType
  end

  class ArrayTest
    def self.main
      arr = HaxeArray(Int32).new()
      arr.push(33)
      arr.push(22)
      arr.push(11)
      pp(arr)
    end
  end

  ArrayTest.main
