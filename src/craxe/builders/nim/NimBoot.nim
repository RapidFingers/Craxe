proc incRet[T](val:var T):T {.discardable, inline.} =
    inc(val)
    val