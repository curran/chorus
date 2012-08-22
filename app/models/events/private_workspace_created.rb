module Events
  class PrivateWorkspaceCreated < Base
    has_targets :workspace
    has_activities :actor, :workspace
  end
end