class HaxeStd
  def self.string(v) : String
    v.to_s
  end
end

class HaxeArray(T) < Array(T)
end
