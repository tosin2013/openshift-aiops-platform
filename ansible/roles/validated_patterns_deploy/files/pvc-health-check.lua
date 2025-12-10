-- PVC Health Check for ArgoCD
-- Handles WaitForFirstConsumer storage class where PVCs stay Pending until used
hs = {}
if obj.status == nil or obj.status.phase == nil then
  hs.status = "Progressing"
  hs.message = "PVC status unknown"
elseif obj.status.phase == "Pending" then
  -- WaitForFirstConsumer PVCs are Pending until a pod uses them
  -- This is normal and should not block sync
  hs.status = "Healthy"
  hs.message = "PVC is pending (likely WaitForFirstConsumer)"
elseif obj.status.phase == "Bound" then
  hs.status = "Healthy"
  hs.message = "PVC is bound"
elseif obj.status.phase == "Lost" then
  hs.status = "Degraded"
  hs.message = "PVC is lost"
else
  hs.status = "Progressing"
  hs.message = "PVC status: " .. obj.status.phase
end
return hs
