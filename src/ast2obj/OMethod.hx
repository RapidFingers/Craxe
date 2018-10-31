package ast2obj;

class OMethod {
    public var cls:OClass;
    
    public var type:OType;
    public var name:String;
    public var isStatic:Bool = false;
    public var expression:OExpression;
    public var args:Array<OMethodArg> = [];
    
    public function new() {
    }
    
    public function findMethodArg(id:Int):OMethodArg {
        var m = null;
        for (a in args) {
            if (a.id == id) {
                m = a;
                break;
            }
        }
        return m;
    }
}