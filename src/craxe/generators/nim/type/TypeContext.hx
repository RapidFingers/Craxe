package craxe.generators.nim.type;

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
}
