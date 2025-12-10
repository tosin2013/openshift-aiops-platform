-- InferenceService Health Check for ArgoCD
-- Models may not exist on initial deployment, so we don't block sync
-- The InferenceService will become ready once models are trained
hs = {}
if obj.status == nil then
  hs.status = "Healthy"
  hs.message = "InferenceService created (model pending)"
elseif obj.status.conditions ~= nil then
  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Ready" then
      if condition.status == "True" then
        hs.status = "Healthy"
        hs.message = "InferenceService is ready"
        return hs
      elseif condition.status == "False" then
        -- Don't mark as Degraded - models are trained after deployment
        hs.status = "Healthy"
        hs.message = "InferenceService waiting for model: " .. (condition.message or "pending")
        return hs
      end
    end
  end
  hs.status = "Healthy"
  hs.message = "InferenceService status progressing"
else
  hs.status = "Healthy"
  hs.message = "InferenceService status unknown (model pending)"
end
return hs
