
-->>get
local get = {}

-- /topic/:tid.html
function get.topic__tid_html(req, res)
	local tid = req.params.tid
	local content = req.query.content
	return res.html('/topic', {
		tid = tid, 
		opt = "visit",
		content = content
	})
end

-- /topic/like/:tid.html  auth
function get.topic_like__tid_html__auth(req, res)
	local tid = req.params.tid
	local content = req.query.content
	return res.html('/topic', {
		tid = tid, 
		opt = "like",
		content = content
	})
end

--<<get

-->>post
local post = {}

-- /topic/create.html auth
function get.topic_create_html__auth(req, res)
	return res.html('/topic', {opt = "create"})
end

-- /topic/delete/:tid.html  adminauth
function get.topic_like__tid_html__adminauth(req, res)
	local tid = req.params.tid
	return res.html('/topic', {tid = tid, opt = "like"})
end

--<<post

--<<==
return {
 	get = get,
 	post = post,
}