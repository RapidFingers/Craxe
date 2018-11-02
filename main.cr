
			class HaxeStd
				def self.string(v) : String
					v.to_s
				end
			end
		class Main
setter name : String = ""
def test
d = 33
@name = HaxeStd.string(d)
return @name
end
def self.main
m = Main.new()
m.name = "GOOD"
pp(m.test())
end

end

Main.main()
