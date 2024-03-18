local socket = require("socket")
local lyaml = require("lyaml")

local _M = {
    _VERSION = '0.17.1',
}

local mt = { __index = _M }

function _M:new()
	local user_agent = string.lower(ngx.var.http_user_agent)
	local config = ngx.shared.f_shared:get(ngx.var.server_name .. "_security_config")

	if not config then
		ngx.log(ngx.ERR, "Config not found in shared memory zone. Reading from file.")
		config = updateConfig()
	end

	if user_agent:match(".*googlebot.*") then
		-- https://developers.google.com/search/docs/advanced/crawling/verifying-googlebot
		bot_domains = {".googlebot.com", ".google.com", "googleusercontent.com"}
		bot_name = "Googlebot"
	elseif user_agent:match(".*facebookexternalhit.*") or user_agent:match(".*facebookcatalog.*") or user_agent:match(".*facebookbot.*") then
		-- https://developers.facebook.com/docs/sharing/webmasters/crawler/
		-- https://developers.facebook.com/docs/sharing/bot/
		bot_domains = {".facebook.com", ".fbsv.net"}
		bot_name = "Facebookbot"
	elseif user_agent:match(".*bingbot.*") then
		-- https://blogs.bing.com/webmaster/2012/08/31/how-to-verify-that-bingbot-is-bingbot
		bot_domains = {".search.msn.com"}
		bot_name = "Bingbot"
	elseif user_agent:match(".*twitterbot.*") then
		-- https://developer.twitter.com/en/docs/twitter-for-websites/cards/guides/troubleshooting-cards#validate_twitterbot
		bot_domains = {".twitter.com", ".twttr.com"}
		bot_name = "Twitterbot"
	elseif user_agent:match(".*applebot.*") then
		-- https://support.apple.com/en-us/HT204683
		bot_domains = {".applebot.apple.com"}
		bot_name = "Applebot"
	elseif user_agent:match(".*linkedinbot.*") then
		-- https://udger.com/resources/ua-list/bot-detail?bot=LinkedInBot
		bot_domains = {".fwd.linkedin.com"}
		bot_name = "LinkedInBot"
	elseif user_agent:match(".*amazonbot.*") then
		-- https://developer.amazon.com/support/amazonbot
		bot_domains = {".crawl.amazonbot.amazon"}
		bot_name = "Amazonbot"
	elseif user_agent:match(".*yandexbot.*") then
		bot_domains = {".yandex.com", ".yandex.ru", ".yandex.net"}
		bot_name = "YandexBot"
	elseif user_agent:match(".*duckduckbot.*") then
		bot_domains = {"..duckduckgo.com"}
		bot_name = "DuckDuckBot"
	elseif user_agent:match(".*baiduspider.*") then
		bot_domains = {".baidu.com"}
		bot_name = "BaiduSpider"
	elseif user_agent:match(".*pinterest.*") then
		bot_domains = {".pinterest.com"}
		bot_name = "Pinterestbot"
	elseif user_agent:match(".*sogou.*") then
		bot_domains = {".sogou.com"}
		bot_name = "Sogou Spider"
	elseif user_agent:match(".*exabot.*") then
		bot_domains = {".exabot.com"}
		bot_name = "Exabot"
	elseif user_agent:match(".*slackbot.*") then
		bot_domains = {".slack.com"}
		bot_name = "Slackbot"
	elseif user_agent:match(".*whatsapp.*") then
		bot_domains = {".whatsapp.com"}
		bot_name = "WhatsAppbot"
	elseif user_agent:match(".*telegrambot.*") then
		bot_domains = {".telegram.org"}
		bot_name = "TelegramBot"
	else
		bot_domains = {}
		bot_name = ""
	end

	return setmetatable({bot_domains = bot_domains, bot_name = bot_name,
						 hosts = socket.dns.getnameinfo(ngx.var.remote_addr), config = config, user_agent = user_agent}, mt)
end

function _M:ends_with(str, ending)
	str = str:lower()
	ending = ending:lower()
	return ending == "" or str:sub(-#ending) == ending
end

function _M:checkFakeBot()
	if next(self.bot_domains) == nil then
		return false
	end

	for _, host in pairs(self.hosts) do
		for _, domain in pairs(self.bot_domains) do
			if self.ends_with(nil, host, domain) then
				addrinfo = socket.dns.getaddrinfo(host)
				if addrinfo ~= nil then
					for _, ips in pairs(addrinfo) do
						for _, ip in pairs(ips) do
							if self.remote_addr == ip then
								return false
							end
						end
					end
				end
			end
		end
	end

	ngx.log(ngx.ERR, "Fake bot detected. Bot name: " .. self.bot_name .. ", Origin: " .. ngx.var.remote_addr)
	ngx.exit(ngx.HTTP_FORBIDDEN)
end

function _M:checkRemoteIP()
	local security_config = lyaml.load(self.config)

	if not security_config.banned_ips then
		return false
	end

	for _, banned_ip in ipairs(security_config.banned_ips) do
		if banned_ip == ngx.var.remote_addr then
			ngx.log(ngx.ERR, "Banned IP address detected. IP: " .. ngx.var.remote_addr)
			ngx.exit(ngx.HTTP_FORBIDDEN)
		end
	end

	return false
end

function _M:checkUserAgent()
	local security_config = lyaml.load(self.config)

	if not security_config.banned_user_agents then
		return false
	end

	for _, banned_user_agent in ipairs(security_config.banned_user_agents) do
		if self.user_agent:match(banned_user_agent) then
			ngx.log(ngx.ERR, "Banned user agent detected. User Agent: " .. self.user_agent)
			ngx.exit(ngx.HTTP_FORBIDDEN)
		end
	end

	return false
end

function updateConfig()
	local file, err = io.open("/etc/nginx/conf/wafconf/" .. ngx.var.server_name .. "_security.yaml", "r")
	if not file then
		ngx.log(ngx.ERR, "Error opening file:", err)
		return
	end

	local yamlContent = file:read("*a")
	file:close()

	ngx.shared.f_shared:set(ngx.var.server_name .. "_security_config", yamlContent, 300)
	return yamlContent
end

return _M
