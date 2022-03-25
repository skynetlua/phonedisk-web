
-->>get
local get = {}

-- /index.html
function get.index_html(req, res)
	return res.html('/index', {})
end

-- /about.html
function get.about_html(req, res)
	return res.html('/about', {})
end

--<<get

-->>post
local post = {}


--<<post

--<<==
return {
 	get = get,
 	post = post,
}