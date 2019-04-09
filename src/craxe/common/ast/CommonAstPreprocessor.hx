package craxe.common.ast;

import craxe.common.ast.EntryPointInfo;
import craxe.common.ast.type.*;
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
		"Encoding" => true, "Error" => true, "EnumValue_Impl_" => true, "File" => true, "FileInput" => true, "FileOutput" => true, "FileSeek" => true
	];

	/**
	 * Filter not needed type. Return true if filtered
	 */
	function filterType(name:String, module:String):Bool {
		if (excludedTypes.exists(name))
			return true;

		if (StringTools.startsWith(module, "haxe.") || StringTools.startsWith(module, "craxe.nim."))
			return true;

		return false;
	}

	/**
	 * Get fields and methods of instance
	 */
	function getFieldsAndMethods(c:ClassType):{fields:Array<ClassField>, methods:Array<ClassField>} {
		var classFields = c.fields.get();

		var fields = [];
		var methods = [];

		for (ifield in classFields) {
			switch (ifield.kind) {
				case FVar(_, _):
					fields.push(ifield);
				case FMethod(_):
					methods.push(ifield);
			}
		}

		return {
			fields: fields,
			methods: methods
		}
	}

	/**
	 * Get fields and methods of instance
	 */
	function getStaticFieldsAndMethods(c:ClassType):{
		fields:Array<ClassField>,
		methods:Array<ClassField>,
		entryMethod:ClassField
	} {
		var classFields = c.statics.get();

		var fields = [];
		var methods = [];
		var entryMethod:ClassField = null;

		for (ifield in classFields) {
			switch (ifield.kind) {
				case FVar(_, _):
					fields.push(ifield);
				case FMethod(_):
					methods.push(ifield);
					if (ifield.name == MAIN_METHOD) {
						entryMethod = ifield;
					}
			}
		}

		return {
			fields: fields,
			methods: methods,
			entryMethod: entryMethod
		}
	}

	/**
	 * Build interface info
	 */
	function buildInterface(c:ClassType, params:Array<Type>):InterfaceInfo {
		if (filterType(c.name, c.module)) {
			return null;
		}

		var res = getFieldsAndMethods(c);
		return new InterfaceInfo(c, params, res.fields, res.methods);
	}

	/**
	 * Build class info
	 */
	function buildClass(c:ClassType, params:Array<Type>):BuildClassResult {
		if (filterType(c.name, c.module)) {
			return null;
		}

		var instanceRes = getFieldsAndMethods(c);
		var staticRes = getStaticFieldsAndMethods(c);

		var classInfo = new ClassInfo(c, params, instanceRes.fields, instanceRes.methods, staticRes.fields, staticRes.methods);

		var entryPoint:EntryPointInfo = if (staticRes.entryMethod != null) {
			{
				classInfo: classInfo,
				method: staticRes.entryMethod
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
	 * Process class, interface, struct and return ObjectType info
	 */
	function processTInst(c:ClassType, params:Array<Type>):{
		?objectInfo:ObjectType,
		?entryPoint:EntryPointInfo
	} {
		if (c.isInterface) {
			return {
				objectInfo: buildInterface(c, params)
			}
		} else {
			var res = buildClass(c, params);
			if (res != null)
				return {
					objectInfo: res.classInfo,
					entryPoint: res.entryPoint
				}
		}

		return null;
	}

	/**
	 * Process AST and get types
	 */
	public function process(types:Array<Type>):PreprocessedTypes {
		var classes = new Array<ClassInfo>();
		var structures = new Array<StructInfo>();
		var interfaces = new Array<InterfaceInfo>();
		var enums = new Array<EnumInfo>();
		var entryPoint:EntryPointInfo = null;

		for (t in types) {
			switch (t) {
				case TInst(c, params):
					var res = processTInst(c.get(), params);
					if (res != null) {
						if ((res.objectInfo is ClassInfo)) {
							classes.push(cast(res.objectInfo, ClassInfo));
							if (res.entryPoint != null)
								entryPoint = res.entryPoint;
						} else if ((res.objectInfo is InterfaceInfo)) {
							interfaces.push(cast(res.objectInfo, InterfaceInfo));
						} else if ((res.objectInfo is StructInfo)) {
							structures.push(cast(res.objectInfo, StructInfo));
						}
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
