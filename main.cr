class HaxeStd
  def self.string(v) : String
    v.to_s
  end
end

class HundredDoors
  def self.main
    findOpenLockers(100)
  end

  def self.findOpenLockers(n : Int)
    i = 1
    while i * i <= n
      pp(i * i)
      i += 1
    end
  end
end

HundredDoors.main
