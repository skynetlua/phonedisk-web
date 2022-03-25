local skynet = require "skynet"

if skynet.getenv("debug") then
    os.mode = 'dev'
end

require "meiru.extension"

ROOT_PATH = ROOT_PATH or "./"

