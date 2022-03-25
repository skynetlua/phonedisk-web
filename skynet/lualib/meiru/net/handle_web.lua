local skynet       = require "skynet"
local socket       = require "skynet.socket"
local sockethelper = require "http.sockethelper"
local httpd        = require "http.httpd"


local SSLCTX_SERVER = nil
local function gen_interface(protocol, fd, certfile, keyfile)
    if protocol == "http" then
        return {
            init = nil,
            close = nil,
            read = sockethelper.readfunc(fd),
            write = sockethelper.writefunc(fd),
        }
    elseif protocol == "https" then
        local tls = require "http.tlshelper"
        if not SSLCTX_SERVER then
            SSLCTX_SERVER = tls.newctx()
            if not certfile then
                certfile = skynet.getenv("certfile") or "./server-cert.pem"
            end
            if not keyfile then
                keyfile  = skynet.getenv("keyfile") or "./server-key.pem"
            end
            assert(certfile and keyfile)
            SSLCTX_SERVER:set_cert(certfile, keyfile)
        end
        local tls_ctx = tls.newtls("server", SSLCTX_SERVER)
        return {
            init = tls.init_responsefunc(fd, tls_ctx),
            close = tls.closefunc(tls_ctx),
            read = tls.readfunc(fd, tls_ctx),
            write = tls.writefunc(fd, tls_ctx),
        }
    else
        error(string.format("Invalid protocol: %s", protocol))
    end
end

local function do_response(fd, write, statuscode, bodyfunc, header)
    local ok, retval = httpd.write_response(write, statuscode, bodyfunc, header)
    if not ok then
        skynet.error(string.format("httpd.response(%d) : %s", fd, retval))
    end
end

return function(fd, addr, protocol, handle, config)
    -- log(fd, addr, protocol, handle, certfile, keyfile)
    -- log("handle_web: fd =", fd, "addr =", addr, "protocol =", protocol)
    socket.start(fd)
    local interface = gen_interface(protocol, fd, config.certfile, config.keyfile)
    if interface.init then
        interface.init()
    end
    local limit
    if config.port ~= 442 then
        limit = 8192
    end
    local code, url, method, header, body = httpd.read_request(interface.read, limit)
    log("handle_web url:[", url, "] addr:", addr, "method:", method, "fd:", fd, "protocol:", protocol, "code:", code, "port =", config.port)
    if code then
        if code ~= 200 then
            log("handle_web ===============>>error code =", code)
            do_response(fd, interface.write, code)
        else
            if header.upgrade == "websocket" and method:lower() ~= "get" then
                log("handle_web ===============>>websocket error method")
                do_response(fd, interface.write, 400, "need GET method")
            else
                local ip = addr:match("([^:]+)")
                local req = {
                    fd       = fd,
                    protocol = protocol,
                    method   = method,
                    url      = url,
                    header   = header,
                    body     = body,
                    ip       = ip,
                    addr     = addr,
                }
                local res = {
                    interface = interface,
                    response = function(code, bodyfunc, header)
                        do_response(fd, interface.write, code, bodyfunc, header)
                    end
                }
                local ret = handle(header.upgrade == "websocket", req, res)
                if ret then
                    log("handle_web ===============>>websocket")
                    return
                end
                -- log("handle_web ===============>> http")
            end
        end
    else
        if url == sockethelper.socket_error then
            log("httpd:socket closed:", code, url, method)
        else
            log("httpd:request failed:", code, url, method)
        end
    end
    socket.close(fd)
    if interface.close then
        interface.close()
    end
    -- log("handle_web ===============>> close")
end
