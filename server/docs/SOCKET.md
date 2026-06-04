# Socket.io — Delivery Real-time

Real-time delivery tracking over Socket.io (single instance; no Redis).

## Connection

- **URL:** `http://<HOST>:<PORT>` (same as API, e.g. `http://localhost:5800`)
- **Namespace:** `/delivery`
- **Full path:** `http://localhost:5800/delivery`

## Authentication

Send JWT access token in one of:

- `auth.token`
- `auth.accessToken`
- `Authorization: Bearer <token>` header

### Example (JS client)

```js
import { io } from "socket.io-client";

const socket = io("http://localhost:5800/delivery", {
  auth: {
    token: "YOUR_ACCESS_TOKEN",
  },
});
```

## Events

### Client → Server

| Event            | Payload                  | Description                     |
|------------------|--------------------------|---------------------------------|
| `location_update`| `{ lat: number, lng: number }` | Broadcast delivery boy location |

### Server → Client

| Event             | Payload                         | Description                              |
|-------------------|----------------------------------|------------------------------------------|
| `location_updated`| `{ userId, phone, lat, lng, timestamp }` | Location update from another client       |
| `delivery_updated`| Delivery object (populated)      | Delivery marked complete via API          |
| `error`           | `{ message: string }`            | Validation / auth error                  |

## Rooms

- **`delivery-today`** — Auto-joined on connect. All location updates and delivery updates are sent to this room.
