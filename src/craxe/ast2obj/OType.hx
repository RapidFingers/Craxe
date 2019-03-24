package craxe.ast2obj;

class OType {
    public var name:String;
    public var typeParameters:Array<OType> = [];
    
    public function new() {
    }
    
    public var safeName(get, null):String;
    private function get_safeName():String {
        if (name == null)
            return "null";
        return StringTools.replace(name, ".", "SAFE");
    }
}