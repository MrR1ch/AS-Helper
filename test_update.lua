local MonetLoader = require 'monetloader'

script_version ('0.2v Build')

function check_update()
   local path = getWorkingDirectory() .. "/update.json"
   os.remove(path)
   local url = "https://raw.githubusercontent.com/MrR1ch/AS-Helper/main/update.json"
   --if MonetLoader() then
      downloadToFile(url, path, function(type, pos, total_size)
			if type == "finished" then
			   local updates = readJsonFile(path)
			   if updates then
			      local upd = updates.update
			      if thisScript().version ~= upd then
			         print('Update is available!')
			         updates = true 
			      else
			         print('You have a current version!')
			      end
			   end
			end
      end)
   --end
end

function readJsonFile(filePath)
		if not doesFileExist(filePath) then
			print("[Justice Helper] Ошибка: Файл " .. filePath .. " не существует")
			return nil
		end
		local file = io.open(filePath, "r")
		local content = file:read("*a")
		file:close()
		local jsonData = decodeJson(content)
		if not jsonData then
			print("[Justice Helper] Ошибка: Неверный формат JSON в файле " .. filePath)
			return nil
		end
		return jsonData
	end


  function main()
     while not isSampAvailable() do wait(100) end
     wait(500)
     check_update()
     while true do wait(0)
     end
  end
  
			      
      
      
      
      ---Скачивает асинхронно файл из URL в указанный путь
---@param url string @URL
---@param path string @Путь к файлу, в который будет сохранен скачанный файл
---@param callback? fun(type: "downloading"|"finished"|"error", pos: number, total_size?: number) @Функция, которая будет вызвана при изменении прогресса скачивания или завершении
---@param progressInterval? number @Интервал в секундах между вызовами callback, по умолчанию 0.1
function downloadToFile(url, path, callback, progressInterval)
  callback = callback or function() end
  progressInterval = progressInterval or 0.1
  local effil = require("effil")
  local progressChannel = effil.channel(0)

  local runner = effil.thread(function(url, path)
    local http = require("socket.http")
    local ltn = require("ltn12")

    local r, c, h = http.request({
      method = "HEAD",
      url = url,
    })

    if c ~= 200 then
      return false, c
    end
    local total_size = h["content-length"]

    local f = io.open(path, "w+b")
    if not f then
      return false, "failed to open file"
    end
    local success, res, status_code = pcall(http.request, {
      method = "GET",
      url = url,
      sink = function(chunk, err)
        local clock = os.clock()
        if chunk and not lastProgress or (clock - lastProgress) >= progressInterval then
          progressChannel:push("downloading", f:seek("end"), total_size)
          lastProgress = os.clock()
        elseif err then
          progressChannel:push("error", err)
        end

        return ltn.sink.file(f)(chunk, err)
      end,
    })

    if not success then
      return false, res
    end

    if not res then
      return false, status_code
    end

    return true, total_size
  end)
  local thread = runner(url, path)

  local function checkStatus()
    local tstatus = thread:status()
    if tstatus == "failed" or tstatus == "completed" then
      local result, value = thread:get()

      if result then
        callback("finished", value)
      else
        callback("error", value)
      end

      return true
    end
  end

  lua_thread.create(function()
    if checkStatus() then
      return
    end

    while thread:status() == "running" do
      if progressChannel:size() > 0 then
        local type, pos, total_size = progressChannel:pop()
        callback(type, pos, total_size)
      end
      wait(0)
    end

    checkStatus()
  end)
end