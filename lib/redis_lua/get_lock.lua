local name          = KEYS[1]
local now           = KEYS[2]
local extended_time = KEYS[3]
local raw           = redis.call('get', name)
local locked_until  = '0'

if raw then
  locked_until = raw
end

if locked_until < now then
  redis.call('set', name, extended_time)
  return {'1', extended_time}
else
  return {'0', locked_until}
end
