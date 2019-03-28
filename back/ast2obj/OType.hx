package craxe.ast2obj;

class OType {
    /**
     * Type name
     */
    public var name:String;

    /**
     * Type parameters
     */
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