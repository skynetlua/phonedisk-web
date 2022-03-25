
local view_path = include_assets_path("view")
local static_path = include_assets_path("static")

local config = {
    name = "phonedisk-web", 
    description = "手机盘-web phonedisk-web frawework demo", 
    keywords = "手机盘-web phonedisk-web skynet skynet-web",
    site_static_host = "127.0.0.1",
    gitee = "https://gitee.com/linyouhappy/phonedisk-web",
    static_path = static_path,
    site_headers = {}
}

return config
