package ast2obj;

class OClassVar {
    public var cls:OClass;
    
    public var type:OType;
    public var name:String;
    public var isStatic:Bool = false;
    public var expression:OExpression;
    
    public function new() {
    }
}