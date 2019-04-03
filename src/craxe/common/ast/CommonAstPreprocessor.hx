package craxe.common.ast;

import craxe.common.ast.EntryPointInfo;
import craxe.common.ast.ClassInfo;
import haxe.ds.StringMap;
import haxe.macro.Type;

/**
 * Build class result
 */
typedef BuildClassResult = {
	/**
	 * Class info
	 */
	var classInfo(default, null):ClassInfo;

	/**
	 * Entry point if exists
	 */
	var entryPoint:EntryPointInfo;
}

/**
 * Common preprocessor for AST tree
 */
class CommonAstPreprocessor {
	/**
	 * Name of entry point
	 */
	public static inline final MAIN_METHOD = "main";

	/**
	 * Excluded types
	 */
	static final excludedTypes:StringMap<Bool> = [
		"Std" => true, "Array" => true, "Math" => true, "Reflect" => true, "Sys" => true, "EReg" => true, "ArrayAccess" => true, "String" => true,
		"IntIterator" => true, "StringBuf" => true, "StringTools" => true, "Type" => true, "_EnumValue.EnumValue_Impl_" => true, "ValueType" => true,
		"Encoding" => true, "Error" => true, "EnumValue_Impl_" => true
	];

	/**
	 * Filter not needed type. Return true if filtered
	 */
	function filterType(name:String, module:String):Bool {
		if (excludedTypes.exists(name))
			return true;

		if (StringTools.startsWith(module, "haxe."))
			return true;

		return false;
	}

	/**
	 * Build class info
	 */
	function buildClass(c:ClassType, params:Array<Type>):BuildClassResult {
		if (filterType(c.name, c.module)) {
			return null;
		}

		var classFields = c.fields.get();
		var classStaticFields = c.statics.get();

		var instFields = [];
		var instMethods = [];
		var staticFields = [];
		var staticMethods = [];

		var entryMethod:ClassField = null;

		for (ifield in classFields) {
			switch (ifield.kind) {
				case FVar(_, _):
					instFields.push(ifield);
				case FMethod(_):
					instMethods.push(ifield);
			}
		}

		for (ifield in classStaticFields) {
			switch (ifield.kind) {
				case FVar(_, _):
					staticFields.push(ifield);
				case FMethod(_):
					staticMethods.push(ifield);
					if (ifield.name == MAIN_METHOD) {
						entryMethod = ifield;
					}
			}
		}

		var classInfo:ClassInfo = {
			classType: c,
			params: params,
			instanceFields: instFields,
			instanceMethods: instMethods,
			staticFields: staticFields,
			staticMethods: staticMethods
		};

		var entryPoint:EntryPointInfo = if (entryMethod != null) {
			{
				classInfo: classInfo,
				method: entryMethod
			}
		} else null;

		return {
			classInfo: classInfo,
			entryPoint: entryPoint
		}
	}

	/**
	 * Build enum info
	 */
	function buildEnum(c:EnumType, params:Array<Type>):EnumInfo {
		if (filterType(c.name, c.module))
			return null;

		return {
			enumType: c,
			params: params
		}
	}

	/**
	 * Constructor
	 */
	public function new() {}

	/**
	 * Process AST and get types
	 */
	public function process(types:Array<Type>):PreprocessedTypes {
		var classes = new Array<ClassInfo>();
		var interfaces = new Array<ClassInfo>();
		var enums = new Array<EnumInfo>();
		var entryPoint:EntryPointInfo = null;

		for (t in types) {
			switch (t) {
				case TInst(c, params):
					var res = buildClass(c.get(), params);
					if (res != null) {
						if (res.classInfo.classType.isInterface) {
							interfaces.push(res.classInfo);
						} else {
							classes.push(res.classInfo);
						}
						if (res.entryPoint != null)
							entryPoint = res.entryPoint;
					}
				case TEnum(t, params):
					var enu = buildEnum(t.get(), params);
					if (enu != null)
						enums.push(enu);
				case _:
			}
		}

		var types:PreprocessedTypes = {
			interfaces: interfaces,
			classes: classes,
			enums: enums,
			entryPoint: entryPoint
		}

		return types;
	}
}
