# Organización de los tópicos MQTT

La idea es hacer lo siguiente:

```
fak/v1/devices/<device-id>/
│
├── meta/
│   ├── availability
│   ├── identity
│   ├── capabilities
│   └── metrics
│
├── readings/<reading-id>
│
├── actionables/<actionable-id>/
│   ├── command
│   ├── result
│   └── state
│
└── config/
    ├── desired
    └── reported
```

## meta

En meta, viviría toda la metadata del dispositivo:

### availability

Comunica si el dispositivo está disponible.

Cuando el dispositivo se conecta, publica lo siguiente:

```json
{ "state": "online", "ts": 1772899200 }
```

**Cuando el dispositivo deja de responder**, el broker publica un Last Will con `state` en `offline`.

Este last will es Retained, con QoS 1, y con `willDelayInterval` en 60.

El setear `willDelayInterval` en 60 hace que el broker espere 60 segundos antes de declarar al dispositivo como offline. Eso es, siempre que `sessionExpiryInterval >= willDelayInterval`

```json
{ "state": "offline" }
```

### identity

Comunica cosas que identifica al dispositivo a nivel de hardware:

(Estos son valores de ejemplo que pueden llegar a cambiar)

```json
{
  "mac": "a0:b7:65:3f:1c:22",
  "model": "esp32-c3",
  "firmware_version": "1.4.2",
  "zone": "invernadero-1/cantero-norte",
  "provisioned_at": "2026-03-14"
}
```

### capabilities

La idea es que con `capabilities` se pueda comunicar facilmente que lecturas tiene el dispositivo y que cosas puede hacer

Por ejemplo, un capabilities (de vuelta, es de ejemplo y los valores son candidatos a cambiar) sería asi:

```json
{
  "readings": {
    "water-level": {
      "unit": "cm",
      "min": 0,
      "max": 200,
      "interval_s": 60,
      "expiry_s": 180
    }
  },
  "actionables": {
    "pump": {
      "type": "switch",
      "values": ["on", "off"],
      "safe_value": "off"
    }
  }
}
```

Entonces eso ya le dice a cualquier consumidor que existen estos topics y cual es su estructura:

- `fak/v1/devices/<device-id>/readings/water-level`
- `fak/v1/devices/<device-id>/actionables/pump`

### metrics

Este endpoint se usaría para obtener metricas del dispositivo, como RSSI, uso de CPU, uso de memoria, etc...

Este endpoint no tendria Retained, asi que se podría usar como heartbeat en un caso raro en el que el microcontrolador entre en un bucle de reinicios, en el cual mantiene viva la sesión de MQTT, pero se reinicia justo despues d eso. Es un edge caso raro igual.

Sería algo así:

```json
{ "uptime_s": 84021, "rssi": -67, "heap_free": 142000, "ts": 1772899200 }
```

## readings

Todo lo que es mediciones, va acá.

La idea es que sean requests como este ejemplo:

```
topic:           fak/v1/devices/suelo-04/readings/moisture
payload:         { "value": 38.2, "ts": 1772899200 }
retain:          true
messageExpiry:   180
```

Y que sean con QoS 1 para que no se pierdan valores en el tiempo

Algo que hay que tener en cuenta es el `messageExpiry`. Estoy en duda si dejarselo o no, pero por ahora, le voy a dejar un Retained con expiración.

`messageExpiry` tiene que coindicir con `expiry_s` de [Capabilities](#capabilities)

## actionables

Esto es todo lo que te permite accionar cosas que controle el dispositivo (como una bomba de agua, luces, etc...)

### command

En este topic le haces el pedido al dispositivo de hacer la acción que quieras.

Nos aprovechamos de que [MQTT 5 introdujo Request/Response](https://www.hivemq.com/blog/mqtt5-essentials-part9-request-response-pattern/), haciendo que la request sea así:

```
Topic:             fak/v1/devices/bomba-01/actionables/pump/command
Payload:           { "value": "on" }
retain:            false
correlationData:   c-8f3a
responseTopic:     fak/v1/devices/bomba-01/actionables/pump/result
messageExpiry:     30
```

El `payload` depende de cada dispositivo, pero lo que importa acá son 3 cosas, el `correlationData`, el `responseTopic`, y el `messageExpiry`.

`correlationData` y `responseTopic` son de Request/Response de MQTT5, lee [la documentación de hivemq para entender](https://www.hivemq.com/blog/mqtt5-essentials-part9-request-response-pattern/)

#### responseTopic

Es el topic que el dispositivo va a usar para contestar cual fue el resultado del comando.

#### correlationData

Es un valor que genera el que hace la petición, que sirve para luego emparejar a qué pedido correspondió cada response.

#### messageExpiry

Esto se setea para un caso particular, en donde hay que usar la imaginación.

Imaginate que justo el microcontrolador que controla una bomba deja de funcionar. cuando lo vas a arreglar y lo reconectas, le va a llegar el mensaje de que tiene que prender la bomba, por más que haya pasado hace 4 horas.

Por eso seteamos `messageExpiry`, para que eso no pase, para que las peticiones expiren luego de un cierto tiempo. Asi el broker, que tiene QoS 1, sabe cuando dejar de intentarlo.

### result

Es el resultado del comando.

```
Topic:             fak/v1/devices/bomba-01/actionables/pump/result
Payload:           { "ok": false, "reason": "dangerous_action",
                     "detail": "tanque por debajo del mínimo" }
retain:            false
correlationData:   c-8f3a
```

Igual que `command/`, se usa Request/Response de MQTT. Uno sabe que tiene que escuchar al `reponseTopic`, y que tiene que saber si te estan respondiendo a vos en base a la `correlationData`

### state

Es el estado actual del actionable. Es el dispositivo el que cambia el state.

Es retained.

Por ejemplo:

```
{ "v": "off", "ts": 1772899200 }
```

## config

Es la configuración del dispositivo que puede ser cambiada en Runtime

### desired

Es como queres que el dispositivo se comporte.

Por ejemplo, podría ser así:

```json
{
  "actionables": {
    "pump": {
      "on_link_loss": "safe",
      "safe_value": "off",
      "grace_s": 120,
      "max_run_s": 600
    }
  },
  "readings": {
    "water-level": { "interval_s": 60 }
  }
}
```

### reported

Que configuración tiene realmente cargada el dispositivo.

Por ejemplo, esto:

```json
{
  "applied": {
    "actionables": {
      "pump": { "max_run_s": 600 }
    }
  },
  "rejected": {},
  "ts": 1772899200
}
```

Ese es un caso de ejemplo, donde `max_run_s` es la cantidad de segundos MAXIMO que puede correr un actuador, como por ejemplo, una bomba de agua.

Si el dispositivo rechaza parte de la config, te dice por qué:

```json
{
  "applied": {
    "readings": {
      "water-level": {
        "interval_s": 60
      }
    }
  },
  "rejected": {
    "actionables": {
      "pump": { "max_run_s": "fuera de rango" }
    }
  },
  "ts": 1772899200
}
```
