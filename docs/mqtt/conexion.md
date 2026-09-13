# Conexión al broker

Cuando los dispositivos se conectan al broker, envian una request de CONNECT que se ve así:

```bash
cleanStart:              false
sessionExpiryInterval:   300
protocolVersion:         5

Will:
  topic:                 fak/v1/devices/<device-id>/meta/availability
  payload:               { "state": "offline" }
  qos:                   1
  retain:                true
  willDelayInterval:     60
```

**`cleanStart: false` con `sessionExpiryInterval: 300`** hace que la sesión
sobreviva cinco minutos sin conexión.
Si un dispositivo que se reconecta dentro de esa ventana de tiempo, recupera sus suscripciones y los comandos que se le encolaron.

**`willDelayInterval: 60`** evita que el broker piense que se murió el dispositivo cuando en realidad hubo un microcorte. Tiene que ser menor
o igual que el session expiry, o no hace nada.

