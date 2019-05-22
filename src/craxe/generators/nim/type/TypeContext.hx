package craxe.generators.nim.type;

import haxe.macro.Type;
import haxe.io.Bytes;
import haxe.crypto.Crc32;
import haxe.macro.Type.TypedExpr;
import haxe.ds.StringMap;
import craxe.common.ast.*;
import craxe.common.ast.type.*;

/**
 * Context with all types
 */
class TypeContext {
	/**
	 * Information about interfaces
	 */
	final interfaces = new StringMap<InterfaceInfo>();

	/**
	 * Information about classes
	 */
	final classes = new StringMap<ClassInfo>();

	/**
	 * Information about enums
	 */
	final enums = new StringMap<EnumInfo>();

	/**
	 * All anon objects like typedef anonimous by id
	 */
	final anonById = new StringMap<AnonTypedefInfo>();

	/**
	 * All anon objects like typedef by name
	 */
	final anonByName = new StringMap<AnonTypedefInfo>();

	/**
	 * Types for which need generate converters toDynamic
	 */
	final dynamicAllowed = new StringMap<Bool>();

	/**
	 * Has interfaces
	 */
	public final hasInterfaces:Bool;

	/**
	 * Has classes
	 */
	public final hasClasses:Bool;

	/**
	 * Has enums
	 */
	public final hasEnums:Bool;

	/**
	 * Generate anon ID
	 */
	function generateAnonId(fields:Array<{name:String, type:Type}>):String {
		fields.sort((x1, x2) -> {
			var a = x1.name;
			var b = x2.name;
			return if ( a < b ) -1 else if ( a > b ) 1 else 0;
		});
		var str = fields.map(x -> x.name).join("");
		return Std.string(Math.abs(Crc32.make(Bytes.ofString(str))));
	}

	/**
	 * Constructor
	 */
	public function new(processed:PreprocessedTypes) {
		for (item in processed.classes) {
			classes.set(item.classType.name, item);
		}

		for (item in processed.interfaces) {
			interfaces.set(item.classType.name, item);
		}

		for (item in processed.enums) {
			enums.set(item.enumType.name, item);
		}

		for (obj in processed.typedefs) {
			switch (obj.typedefInfo.type) {
				case TAnonymous(a):
					var an = a.get();
					var fields = an.fields.map(x -> {
						return {name: x.name, type: x.type}
					});
					var ano:AnonTypedefInfo = {
						id: generateAnonId(fields),
						name: obj.typedefInfo.name,
						fields: fields
					}
					anonById.set(ano.id, ano);
					anonByName.set(ano.name, ano);
				case v:
					trace(v);
			}
		}

		hasInterfaces = processed.interfaces.length > 0;
		hasClasses = processed.classes.length > 0;
		hasEnums = processed.enums.length > 0;
	}

	/**
	 * Return iterator for all classes
	 */
	public function classIterator():Iterator<ClassInfo> {
		return classes.iterator();
	}

	/**
	 * Return iterator for all interfaces
	 */
	public function interfaceIterator():Iterator<InterfaceInfo> {
		return interfaces.iterator();
	}

	/**
	 * Return iterator for all interfaces
	 */
	public function allAnonymous():Array<AnonTypedefInfo> {
		var res = new Array<AnonTypedefInfo>();
		for (item in anonById.iterator()) {
			res.push(item);
		}

		return res;
	}	

	/**
	 * Return interface by name
	 */
	public function getInterfaceByName(name:String):InterfaceInfo {
		return interfaces.get(name);
	}

	/**
	 * Return enum by name
	 */
	public function getEnumByName(name:String):EnumInfo {
		return enums.get(name);
	}

	/**
	 * Return class by name
	 */
	public function getClassByName(name:String):ClassInfo {
		return classes.get(name);
	}

	/**
	 * Return object by typefields
	 */
	public function getObjectTypeByFields(fields:Array<{name:String, type:Type}>):AnonTypedefInfo {
		var id = generateAnonId(fields);
		var anon = anonById.get(id);
		if (anon == null) {
			anon = {
				id: id,
				name: 'Anon${id}',
				fields: fields
			}
			anonById.set(id, anon);
			anonByName.set(anon.name, anon);
		}
		return anon;
	}

	/**
	 * Return object by name
	 */
	public function getObjectTypeByName(name:String):AnonTypedefInfo {
		return anonByName.get(name);
	}

	/**
	 * Set dynamic support for type
	 */
	public function addDynamicSupport(name:String) {
		dynamicAllowed.set(name, true);
	}

	/**
	 * Return all types for which need build dynamic converters
	 */
	public function allDynamicConverters():Array<String> {
		return [for (key => _ in dynamicAllowed) key];
	}

	/**
	 * Check if type has dynamic support
	 */
	public function isDynamicSupported(name:String):Bool {
		return dynamicAllowed.exists(name);
	}
}
