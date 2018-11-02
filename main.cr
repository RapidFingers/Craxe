
			class HaxeStd
				def self.string(v) : String
					v.to_s
				end
			end
		class Printer
property name : String = ""
def print(v1 : Int, v2 : Int)
d = v1 + v2
@name = HaxeStd.string(d)
end

end
class Main
def self.main
printer = Printer.new()
printer.print(44, 22)
pp(printer.name)
end

end

Main.main()
