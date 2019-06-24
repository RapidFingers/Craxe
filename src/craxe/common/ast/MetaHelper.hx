package craxe.common.ast;

import haxe.macro.Type.MetaAccess;

/**
 * Helper for Metadata
 */
class MetaHelper {
	/**
	 * Get value from meta parameters
	 */
	public static function getMetaValue(meta:MetaAccess, name:String):String {
		var nt = meta.extract(name);
		if (nt.length > 0 && nt[0].params.length > 0) {
			var meta = nt[0];
			switch (meta.params[0].expr) {
				case EConst(CString(s)):
					return s;
				case _:
			}
		}

		return null;
	}
}
