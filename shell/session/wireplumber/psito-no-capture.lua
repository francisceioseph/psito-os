-- Psito OS: um app no sandbox toca som, mas não grava. O socket que o
-- psito-sandbox dá ao app vem do pw-container, com pipewire.access=psito. O
-- access-default do WirePlumber não sabe esse valor, e o cliente fica parado até
-- este script dar as permissões, de uma vez: ver e usar o grafo, menos a fábrica
-- de links, para o app não ligar a captura sozinho. E a captura de um cliente
-- desses não ganha alvo: nem o microfone nem o som dos outros apps.
lutils = require ("linking-utils")
log = Log.open_topic ("s-client")

factories = ObjectManager {
  Interest {
    type = "factory",
    Constraint { "factory.name", "=", "link-factory" },
  },
}

clients = ObjectManager { Interest { type = "client" } }
clients:connect ("object-added", function (_, client)
  if client.properties ["pipewire.access"] ~= "psito" then
    return
  end
  local permissions = { ["any"] = "rx" }
  for factory in factories:iterate () do
    permissions [factory ["bound-id"]] = "-"
  end
  client:update_permissions (permissions)
end)
factories:connect ("installed", function ()
  clients:activate ()
end)
factories:activate ()

SimpleEventHook {
  name = "linking/psito-no-capture",
  before = {
    "linking/find-media-role-target",
    "linking/find-defined-target",
  },
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "select-target" },
    },
  },
  execute = function (event)
    local _, _, si, si_props = lutils:unwrap_select_target_event (event)
    if not (si_props ["media.class"] or ""):find ("^Stream/Input/") then
      return
    end
    local client = clients:lookup {
      Constraint { "bound-id", "=", si_props ["client.id"], type = "gobject" },
    }
    if client and client.properties ["pipewire.access"] == "psito" then
      log:info (si, "capture denied")
      event:stop_processing ()
    end
  end
}:register ()
