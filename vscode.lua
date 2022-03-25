
local projects_path = package.path:match("(.*)/([^/]+)$")

local src_paths = {
    package.path,
    projects_path .. "/lualib/?.lua",
    projects_path .. "/skynet/lualib/?.lua",
}
package.path = table.concat(src_paths, ";")

local extension = require "meiru.extension"

-- os.mode = 'dev'
os.mode = 'test'

local web = require "demo.web"

local config = {
    domain = "127.0.0.1",
    footprint = true,
    treeprint = true
}

local app = web(config)

---------------------------------------
--dispatch
---------------------------------------
local req = {
    protocol = 'http',
    method   = "get",
    url      = "/topic/like/2.html?content=点赞文章",
    header   = {},
    body     = "",
}

req.header = {
    ['connection'] = "keep-alive",
    ['cookie'] = "mrsid=s%3Apw93qo6lxjs15.9183d91c73de0476034f0e36bfdfeb3b",
    ['sec-fetch-mode'] = "no-cors",
    ['host'] = "127.0.0.1",
    ['accept-encoding'] = "gzip, deflate, br",
    ['sec-fetch-site'] = "same-origin",
    ['referer'] = "http://127.0.0.1:8080/",
    ['pragma'] = "no-cache",
    ['accept-language'] = "zh-CN,zh;q=0.9",
    ['cache-control'] = "no-cache",
    ['accept'] = "image/webp,image/apng,image/*,*/*;q=0.8",
    ['user-agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.100 Safari/537.36",
}

local res = {
    response = function(code, bodyfunc, header)
        log("response", code, header, bodyfunc)
    end,
}

app.dispatch(req, res)

-- local memory_info = dump_memory()
-- log("memory_info\n", memory_info)

-- local foot = app.footprint()
-- log("footprint\n", foot)

-- local chunk = app.chunkprint()
-- log("chunkprint\n", chunk)
