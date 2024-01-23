local socket = require("socket")

local _M = {
    _VERSION = '0.17.1',
}

local mt = { __index = _M }

function _M:new(userAgent, remote_addr)
	local user_agent = string.lower(userAgent)

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
	elseif user_agent:match(".*python-requests.*") then
		bot_domains = {".python-requests"}
		bot_name = "python-requests"
	else
		bot_domains = {}
		bot_name = ""
	end

	return setmetatable({bot_domains = bot_domains, bot_name = bot_name, remote_addr = remote_addr,
						 hosts = socket.dns.getnameinfo(remote_addr)}, mt)
end

function _M:ends_with(str, ending)
	str = str:lower()
	ending = ending:lower()
	return ending == "" or str:sub(-#ending) == ending
end

function _M:check()
	for k1, host in pairs(self.hosts) do
		for k2, domain in pairs(self.bot_domains) do
			if self.ends_with(nil, host, domain) then
				addrinfo = socket.dns.getaddrinfo(host)
				if addrinfo ~= nil then
					for k3, ips in pairs(addrinfo) do
						for k4, ip in pairs(ips) do
							if self.remote_addr == ip then
								return {bot = false}
							end
						end
					end
				end
			end
		end
	end

	if next(self.bot_domains) == nil then
		return {bot = false}
	end

	return {bot = true}
end

local m = _M.new(nil, "Mozilla/5.0 (platform; rv:geckoversion) Gecko/geckotrail Firefox/firefoxversion", "31.0.0.1")
print(m:check()["bot"])
