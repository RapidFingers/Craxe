package craxe.nim;

import craxe.common.ast.ClassInfo;
import craxe.common.IndentStringBuilder;
import craxe.nim.type.TypeResolver;

/**
 * Code generator for interface
 */
class InterfaceGenerator {
	/**
	 * Constructor
	 */
	public function new() {}

	/**
	 * Generate tuple object with interface fields
	 */
	public function generateInterfaceObject(sb:IndentStringBuilder, interfaceInfo:ClassInfo, typeResolver:TypeResolver) {
		var iname = interfaceInfo.classType.name;
		sb.add('${iname} = tuple[');
		sb.addNewLine(Inc);
		sb.add("obj : ref RootObj");
		for (field in interfaceInfo.instanceFields) {
			sb.add(", ");
			sb.addNewLine(Same);
			sb.add(field.name);
			sb.add(" : ptr ");
			sb.add(typeResolver.resolve(field.type));
		}

		for (meth in interfaceInfo.instanceMethods) {
			sb.add(", ");
			sb.addNewLine(Same);
			sb.add(meth.name);
			sb.add(" : ");
			sb.add("proc (");
			switch (meth.type) {
				case TFun(args, ret):
					var resolved = typeResolver.resolveArguments(args);
					if (resolved.length > 0) {
						var sargs = resolved.map(x -> {
							return '${x.name}:${x.t}';
						}).join(", ");
						sb.add(sargs);
					}
					sb.add(") : ");
					sb.add(typeResolver.resolve(ret));
				case v:
					throw 'Unsupported ${v}';
			}
		}

		sb.addNewLine(Dec);
		sb.add("]");
	}

	/**
	 * Generate converter to interface for class
	 */
	public function generateInterfaceConverter(sb:IndentStringBuilder, classInfo:ClassInfo, interfaceInfo:ClassInfo, typeResolver:TypeResolver) {
		var iname = interfaceInfo.classType.name;
		var cname = classInfo.classType.name;
		sb.add('converter to${iname}(this:${cname}) : ${iname} = ');
		sb.addNewLine(Inc);
		sb.add("return (");
		sb.addNewLine(Inc);

		sb.add("obj: this");

		for (field in interfaceInfo.instanceFields) {
			sb.add(", ");
			sb.addNewLine(Same);
			sb.add(field.name);
			sb.add(" : addr this.");
			sb.add(field.name);
		}

		for (meth in interfaceInfo.instanceMethods) {
			sb.add(", ");
			sb.addNewLine(Same);
			sb.add(meth.name);
			sb.add(" : ");
			sb.add("proc (");
			switch (meth.type) {
				case TFun(args, ret):
					var resolved = typeResolver.resolveArguments(args);
					if (resolved.length > 0) {
						var sargs = resolved.map(x -> {
							return '${x.name}:${x.t}';
						}).join(", ");
						sb.add(sargs);
					}

					sb.add(") : ");
					sb.add(typeResolver.resolve(ret));
					sb.add(' = this.${meth.name}(');
					if (resolved.length > 0) {
						var sargs = resolved.map(x -> x.name).join(", ");
						sb.add(sargs);
					}
					sb.add(")");
				case v:
					throw 'Unsupported ${v}';
			}
		}

		sb.addNewLine(Dec);
		sb.add(")");
		sb.addBreak();
	}

	/**
	 * Generate type checking for interface
	 */
	public function generateTypeCheck(sb:IndentStringBuilder, interfaceInfo:ClassInfo) {}
}
