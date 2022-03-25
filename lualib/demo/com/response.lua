
local exports = {}

function exports.render(req, res)
	
	res.html404 = function(body)
		res.status(404)
		return res.html('notify/notify', {the_error = body, referer = req.get('referer')})
    end

    res.html403 = function(body)
        log("req =", req)
        res.status(403)
		return res.html('notify/notify', {the_error = body, referer = req.get('referer')})
    end

    res.htmlCode = function(code, body)
        res.status(code)
		return res.html('notify/notify', {the_error = body, referer = req.get('referer')})
    end
end

return exports
