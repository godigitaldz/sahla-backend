# Socket.IO Backend Implementation

This document describes the Socket.IO server implementation for the Sahla Delivery backend.

## Overview

The Socket.IO server provides real-time communication between the Flutter app and the backend, enabling:
- Real-time notifications
- Live order status updates
- Delivery location tracking
- Real-time data synchronization (categories, restaurants, menu items, etc.)
- Chat and messaging features
- User presence tracking

## Files Structure

```
backend/
├── src/
│   ├── socket/
│   │   └── socketServer.js          # Main Socket.IO server implementation
│   ├── services/
│   │   └── socketDataService.js      # Data fetching service for Socket.IO
│   └── index.js                      # Express server with Socket.IO integration
└── api/
    └── socket.js                     # Vercel serverless function placeholder
```

## Implementation Details

### 1. Socket Server (`src/socket/socketServer.js`)

The main Socket.IO server implementation that handles:
- Authentication via Supabase JWT tokens
- Room management (user rooms, order rooms, conversation rooms)
- Event handlers for all client → server events
- Broadcast functions for server → client events

#### Key Features:

**Authentication:**
- Uses Supabase JWT tokens from `Authorization: Bearer <token>` header
- Verifies tokens using `supabaseAdmin.auth.getUser()`
- Allows anonymous connections but marks them appropriately

**Room Management:**
- `user:${userId}` - User-specific room for notifications
- `order:${orderId}` - Order-specific room for order updates
- `conversation:${conversationId}` - Chat conversation room

**Event Handlers:**
- `join:user`, `join:order`, `leave:order`, `join:conversation`
- `notification:send`
- `order:status:change`, `delivery:location:update`
- `categories:request`, `specialPacks:request`, `lto:request`
- `restaurants:request`, `menuItems:request`, `orders:request`, `tasks:request`
- `message:send`, `typing`, `presence`

**Broadcast Functions:**
- `broadcastCategoriesUpdate()`
- `broadcastSpecialPacksUpdate()`
- `broadcastLTOUpdate()`
- `broadcastRestaurantsUpdate()`
- `broadcastRestaurantUpdate(restaurant)`
- `broadcastMenuItemsUpdate({ restaurantId, category })`
- `broadcastMenuItemUpdate(menuItem)`
- `broadcastTasksUpdate({ deliveryPersonId, status })`
- `broadcastTaskUpdate(task)`
- `sendNotificationToUser(userId, notification)`
- `broadcastOrderUpdate(orderId)`
- `broadcastOrdersUpdate({ userId, status })`

### 2. Socket Data Service (`src/services/socketDataService.js`)

Service for fetching data from Supabase for Socket.IO real-time updates.

#### Methods:

- `getCategories()` - Fetch all active categories
- `getSpecialPacks({ limit, offset })` - Fetch special pack menu items
- `getLTOItems({ restaurantId, limit, offset })` - Fetch Limited Time Offer items
- `getRestaurants({ limit, offset, isOpen })` - Fetch restaurants
- `getMenuItems({ restaurantId, category, limit, offset })` - Fetch menu items
- `getTasks({ deliveryPersonId, status, limit, offset })` - Fetch delivery tasks
- `getOrderById(orderId)` - Fetch single order
- `createNotification({ userId, title, message, type, data })` - Create notification
- `updateOrderStatus(orderId, status, previousStatus)` - Update order status
- `updateDeliveryLocation(orderId, latitude, longitude)` - Update delivery location

### 3. Server Integration (`src/index.js`)

The Express server is wrapped with an HTTP server to support Socket.IO:

```javascript
import { createServer } from 'http';
const app = express();
const server = createServer(app);

// Initialize Socket.IO
if (process.env.VERCEL !== '1') {
  io = initializeSocketIO(server);
  broadcastFunctions = createBroadcastFunctions(io);
  global.socketBroadcast = broadcastFunctions;
}

server.listen(config.port, ...);
```

## Event Flow

### Client → Server Events

1. **Connection & Authentication:**
   - Client connects with `Authorization: Bearer <token>` header
   - Server verifies token and attaches `userId` to socket

2. **Room Joining:**
   - Client emits `join:user` with `{ userId }`
   - Client emits `join:order` with `{ orderId }`
   - Server joins socket to appropriate rooms

3. **Data Requests:**
   - Client emits `categories:request`, `restaurants:request`, etc.
   - Server fetches data from Supabase
   - Server emits corresponding `*:update` event to requesting client

4. **Notifications:**
   - Client emits `notification:send` with notification data
   - Server creates notification in database
   - Server emits `notification` to user's room

5. **Order Updates:**
   - Client emits `order:status:change` with new status
   - Server updates order in database
   - Server emits `order:status` and `order:update` to order room

### Server → Client Events

1. **Data Updates:**
   - `categories:update` - List of categories
   - `specialPacks:update` - List of special packs
   - `lto:update` - List of LTO items
   - `restaurants:update` - List of restaurants
   - `restaurant:update` - Single restaurant update
   - `menuItems:update` - List of menu items
   - `menuItem:update` - Single menu item update
   - `orders:update` - List of orders
   - `order:update` - Single order update
   - `order:status` - Order status change
   - `tasks:update` - List of tasks
   - `task:update` - Single task update

2. **Notifications:**
   - `notification` - Real-time notification to user

3. **Delivery Tracking:**
   - `delivery:location` - Delivery location update

4. **Messages:**
   - `message` - Chat message
   - `typing` - Typing indicator
   - `presence` - User presence update

5. **Errors:**
   - `error` - Error event with `{ event, message }`

## Usage Examples

### Broadcasting from Other Services

```javascript
// In any service file
if (global.socketBroadcast) {
  // Broadcast categories update to all clients
  await global.socketBroadcast.broadcastCategoriesUpdate();

  // Send notification to specific user
  await global.socketBroadcast.sendNotificationToUser(userId, {
    title: 'Order Confirmed',
    message: 'Your order has been confirmed',
    type: 'success',
  });

  // Broadcast order update
  await global.socketBroadcast.broadcastOrderUpdate(orderId);
}
```

### Handling Events in Flutter

The Flutter app's `SocketService` listens to these events and provides streams:

```dart
// Listen to categories updates
_socketService.categoriesStream.listen((categories) {
  // Update UI with new categories
});

// Listen to order updates
_socketService.orderUpdatesStream.listen((orderUpdate) {
  // Update order status in UI
});
```

## Vercel Deployment Notes

⚠️ **Important:** Socket.IO requires persistent connections, which don't work perfectly with Vercel's serverless functions. For production:

1. **Option 1:** Use a separate Socket.IO server (recommended)
   - Deploy Socket.IO server separately (e.g., Railway, Render, DigitalOcean)
   - Update Flutter app to connect to this server

2. **Option 2:** Use Vercel's Edge Functions
   - Convert Socket.IO to use Edge Functions (may require modifications)

3. **Option 3:** Use a managed service
   - Pusher, Ably, or Socket.IO Cloud
   - Modify Flutter app to use these services

For local development, Socket.IO works perfectly with the Express server.

## Testing

1. **Start the server:**
   ```bash
   cd backend
   npm start
   ```

2. **Test with Flutter app:**
   - Use the admin dashboard's "Test Push Notification" button
   - Check Socket.IO connection status
   - Verify events are received

3. **Monitor logs:**
   - Server logs show all Socket.IO events
   - Look for connection, disconnection, and event logs

## Environment Variables

Ensure these are set in `.env`:

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
PORT=3001
NODE_ENV=development
```

## Error Handling

All event handlers include try-catch blocks and emit error events:

```javascript
socket.emit('error', {
  event: 'event-name',
  message: 'error message'
});
```

The client should listen to `error` events and handle them appropriately.

## Security Considerations

1. **Authentication:** All connections require valid Supabase JWT tokens
2. **Room Access:** Users can only join their own user rooms
3. **Data Validation:** Validate all incoming data before processing
4. **Rate Limiting:** Consider adding rate limiting for Socket.IO events
5. **CORS:** Configured to allow connections from Flutter app

## Future Enhancements

- [ ] Add rate limiting for Socket.IO events
- [ ] Implement reconnection logic with exponential backoff
- [ ] Add metrics and monitoring
- [ ] Implement message persistence for chat
- [ ] Add support for file uploads via Socket.IO
- [ ] Implement admin dashboard for monitoring connections
