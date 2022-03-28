# phonedisk-web
phonedisk web framework

## 运行demo
直接下载项目

### windows环境
1. 鼠标点击运行客户端程序/bin/phonedisk-web-wain32/phonedisk.exe
2. 手机盘-web程序上，选择工程路径phonedisk-web的这个目录
3. 点击启动按钮，即可运行demo

### Android环境
没错，支持运行安卓系统
1. 安装apk安装包/bin/phonedisk-web-android.apk
2. 把phonedisk-web项目拷贝到手机的sd卡内存。
3. 启动APP,选择工程路径phonedisk-web的这个目录
4. 点击启动按钮，即可运行demo

### Linux环境
shell终端
1. cd phonedisk-web/skynet
2. 执行编译命令: make linux
3. 确保shell终端当前路径：cd phonedisk-web/
4. 运行 ./skynet/skynet ./config/demo.config

### Mac环境
shell终端
1. cd phonedisk-web/skynet
2. 执行编译命令: make macosx
3. 确保shell终端当前路径：cd phonedisk-web/
4. 运行 ./skynet/skynet ./config/demo.config

Mac客户端暂时不发布

### iPhone环境
因为开发者账号早过期，暂时不发布


## Demo

```lua
local meiru  = require "meiru.meiru"

local config = include "config"
local render = include("util.renderfunc")

local view_path = include_assets_path("view")
local static_path = include_assets_path("static")

return function(params)
	local app = meiru.create_app()
	--配置参数
	app.data(render)
	app.data("config", config)
	app.set("static_url", "/")
	app.set("views_path", view_path)
	if params.domain then
		app.set("host", params.domain)
	end
	--配置组件
	app.use(app.new("ComInit"))
	app.use(app.new("ComCors"))
	app.use(app.new("ComPath"))
	app.use(app.new("ComHeader"))
	app.use(app.new("ComBody"))
	--配置路由
	local router = include("handle.index")
	router.get('/', function(req, res)
		return res.redirect("/index.html")
	end)
	--router.get('/test1.html'
	router.bind("get", "test1_html", function(req, res)
		return res.send(200, "/test1.html")
	end)
	--router.get('/test2.html'
	local model = {
		get = {
			test2_html = function(req, res)
				log("test bind /test2.html")
				return res.send(200, "/test2.html")
			end
		}
	}
	router.bind_model(model)
	app.use(router.node())
	--静态资源
	app.use(meiru.static('/', static_path))
	--监控平台
	app.system()
	--启动
	app.run()
	--日志控制
	if params.footprint then
		app.open_footprint()
	end
	if params.treeprint then
		log("treeprint:\n", app.treeprint())
	end

	return app
end
```

