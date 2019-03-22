package ast2obj;

class OType {
    public var name:String;
    public var typeParameters:Array<OType> = [];
    
    public function new() {
    }
    
    public var safeName(get, null):String;
    private function get_safeName():String {
        return StringTools.replace(name, ".", "SAFE");
    }
}