package craxe.nim.type;

import haxe.ds.StringMap;
import craxe.common.ast.*;

/**
 * Context with all types
 */
class TypeContext {
    /**
	 * Information about interfaces
	 */
	final interfaces = new StringMap<ClassInfo>();

	/**
	 * Information about classes
	 */
	final classes = new StringMap<ClassInfo>();

    /**
	 * Information about enums
	 */
	final enums = new StringMap<EnumInfo>();

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
	}

	/**
	 * Return iterator for all classes
	 */
	public function classIterator():Iterator<ClassInfo> {
		return classes.iterator();
	}

	/**
	 * Return interface by name
	 */
	public function getInterfaceByName(name:String):ClassInfo {
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
