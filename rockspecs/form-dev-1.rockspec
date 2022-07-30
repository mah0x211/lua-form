package = "form"
version = "dev-1"
source = {
    url = "git+https://github.com/mah0x211/lua-form.git",
}
description = {
    summary = "HTML form data processing module.",
    homepage = "https://github.com/mah0x211/lua-form",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "isa >= 0.3.0",
    "form-urlencoded >= 0.1.0",
    "form-multipart >= 0.1.0",
    "metamodule >= 0.4.0",
}
build = {
    type = "builtin",
    modules = {
        form = "form.lua",
    },
}
