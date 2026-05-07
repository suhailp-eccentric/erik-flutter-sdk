package com.eccentric.erik_flutter

interface ErikCommandCallback {
    fun onSuccess()

    fun onError(message: String)

    companion object {
        val NONE: ErikCommandCallback =
            object : ErikCommandCallback {
                override fun onSuccess() = Unit

                override fun onError(message: String) = Unit
            }
    }
}
