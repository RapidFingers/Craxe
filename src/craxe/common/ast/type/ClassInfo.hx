package craxe.common.ast.type;

import haxe.macro.Type;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.ClassField;

/**
 * Info about class
 */
class ClassInfo extends ObjectType {
	/**
	 * Static fields
	 */
	public final staticFields:Array<ClassField>;

	/**
	 * Static methods
	 */
	public final staticMethods:Array<ClassField>;

	/**
	 * Constructor
	 */
	public function new(classType:ClassType, 
					params:Array<Type>, 
					instanceFields:Array<ClassField>, 
					instanceMethods:Array<ClassField>,
					staticFields:Array<ClassField>, 
					staticMethods:Array<ClassField>,
					isHashable:Bool) {
		super(classType, params, instanceFields, instanceMethods, isHashable);
		this.staticFields = staticFields;
		this.staticMethods = staticMethods;
	}
}
