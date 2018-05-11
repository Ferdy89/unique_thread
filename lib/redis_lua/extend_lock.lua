local name          = KEYS[1]
local held_until    = KEYS[2]
local extended_time = KEYS[3]
local locked_until  = redis.call('get', name)

if locked_until == held_until then
  redis.call('set', name, extended_time)
  return {'1', extended_time}
else
  return {'0', locked_until}
end
