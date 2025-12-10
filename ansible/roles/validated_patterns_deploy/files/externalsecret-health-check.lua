-- ExternalSecret Health Check for ArgoCD
-- Source secrets may not exist immediately on first deployment
hs = {}
if obj.status == nil then
  hs.status = "Progressing"
  hs.message = "ExternalSecret status unknown"
elseif obj.status.conditions ~= nil then
  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Ready" then
      if condition.status == "True" then
        hs.status = "Healthy"
        hs.message = "Secret synced successfully"
        return hs
      elseif condition.status == "False" then
        -- Check if it's a temporary error (source secret not yet created)
        if string.find(condition.message or "", "not found") then
          hs.status = "Progressing"
          hs.message = "Waiting for source secret: " .. (condition.message or "")
        else
          hs.status = "Degraded"
          hs.message = "Sync failed: " .. (condition.message or "unknown error")
        end
        return hs
      end
    end
  end
  hs.status = "Progressing"
  hs.message = "ExternalSecret syncing"
else
  hs.status = "Progressing"
  hs.message = "ExternalSecret initializing"
end
return hs
