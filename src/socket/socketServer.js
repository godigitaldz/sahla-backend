import { Server } from 'socket.io';
import { supabase, supabaseAdmin } from '../config/supabase.js';
import socketDataService from '../services/socketDataService.js';

/**
 * Socket.IO Server Implementation
 * Handles all real-time events for Sahla Delivery app
 */
export function initializeSocketIO(server) {
  const io = new Server(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
      credentials: true,
    },
    transports: ['websocket', 'polling'],
    pingTimeout: 60000,
    pingInterval: 25000,
  });

  // Authentication middleware
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.headers.authorization?.replace('Bearer ', '') ||
                    socket.handshake.auth?.token?.replace('Bearer ', '');

      if (!token) {
        console.log('⚠️ Socket: No authentication token provided');
        // Allow connection but mark as unauthenticated
        socket.userId = null;
        return next();
      }

      // Verify token with Supabase
      const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);

      if (error || !user) {
        console.log('⚠️ Socket: Invalid authentication token');
        socket.userId = null;
        return next();
      }

      socket.userId = user.id;
      socket.userEmail = user.email;
      console.log(`✅ Socket: Authenticated user ${user.id}`);
      next();
    } catch (error) {
      console.error('❌ Socket: Authentication error:', error);
      socket.userId = null;
      next();
    }
  });

  io.on('connection', (socket) => {
    console.log(`🔌 Socket: Client connected - ${socket.id} (User: ${socket.userId || 'Anonymous'})`);

    // ========== ROOM MANAGEMENT ==========

    socket.on('join:user', async ({ userId }) => {
      if (!userId) {
        socket.emit('error', { message: 'userId is required' });
        return;
      }

      const room = `user:${userId}`;
      await socket.join(room);
      console.log(`🚪 Socket: ${socket.id} joined user room: ${room}`);
      socket.emit('joined:user', { userId, room });
    });

    socket.on('join:order', async ({ orderId }) => {
      if (!orderId) {
        socket.emit('error', { message: 'orderId is required' });
        return;
      }

      const room = `order:${orderId}`;
      await socket.join(room);
      console.log(`🚪 Socket: ${socket.id} joined order room: ${room}`);
      socket.emit('joined:order', { orderId, room });
    });

    socket.on('leave:order', async ({ orderId }) => {
      if (!orderId) return;

      const room = `order:${orderId}`;
      await socket.leave(room);
      console.log(`🚪 Socket: ${socket.id} left order room: ${room}`);
    });

    socket.on('join:conversation', async ({ conversationId }) => {
      if (!conversationId) {
        socket.emit('error', { message: 'conversationId is required' });
        return;
      }

      const room = `conversation:${conversationId}`;
      await socket.join(room);
      console.log(`🚪 Socket: ${socket.id} joined conversation room: ${room}`);
    });

    // ========== NOTIFICATIONS ==========

    socket.on('notification:send', async ({ userId, title, message, data = {}, timestamp }) => {
      try {
        console.log(`📨 Socket: Sending notification to user ${userId}`);

        // Create notification in database
        const notification = await socketDataService.createNotification({
          userId,
          title,
          message,
          type: data.type || 'info',
          data,
        });

        if (notification) {
          // Emit to user's room
          io.to(`user:${userId}`).emit('notification', {
            id: notification.id,
            userId: notification.user_id,
            title: notification.title,
            message: notification.message,
            type: notification.type,
            data: notification.data || {},
            is_read: notification.is_read,
            created_at: notification.created_at,
          });

          console.log(`✅ Socket: Notification sent to user ${userId}`);
        }
      } catch (error) {
        console.error('❌ Socket: Error sending notification:', error);
        socket.emit('error', { event: 'notification:send', message: error.message });
      }
    });

    // ========== ORDERS ==========

    socket.on('order:status:change', async ({ orderId, status, customerId, timestamp }) => {
      try {
        console.log(`📦 Socket: Order status change - ${orderId} -> ${status}`);

        // Get current order status
        const currentOrder = await socketDataService.getOrderById(orderId);
        const previousStatus = currentOrder?.status;

        // Update order status in database
        const updatedOrder = await socketDataService.updateOrderStatus(
          orderId,
          status,
          previousStatus
        );

        if (updatedOrder) {
          // Emit to order room
          io.to(`order:${orderId}`).emit('order:status', {
            orderId,
            status,
            previousStatus,
            timestamp: timestamp || new Date().toISOString(),
          });

          // Also emit order update
          io.to(`order:${orderId}`).emit('order:update', updatedOrder);

          // Emit to customer if provided
          if (customerId) {
            io.to(`user:${customerId}`).emit('order:update', updatedOrder);
          }

          console.log(`✅ Socket: Order status updated - ${orderId}`);
        }
      } catch (error) {
        console.error('❌ Socket: Error updating order status:', error);
        socket.emit('error', { event: 'order:status:change', message: error.message });
      }
    });

    socket.on('delivery:location:update', async ({ orderId, latitude, longitude, timestamp }) => {
      try {
        console.log(`📍 Socket: Delivery location update - Order ${orderId}`);

        // Update location in database (if table exists)
        await socketDataService.updateDeliveryLocation(orderId, latitude, longitude);

        // Emit to order room
        io.to(`order:${orderId}`).emit('delivery:location', {
          orderId,
          latitude,
          longitude,
          timestamp: timestamp || new Date().toISOString(),
        });

        console.log(`✅ Socket: Delivery location updated - Order ${orderId}`);
      } catch (error) {
        console.error('❌ Socket: Error updating delivery location:', error);
        socket.emit('error', { event: 'delivery:location:update', message: error.message });
      }
    });

    // ========== DATA REQUESTS ==========

    socket.on('categories:request', async ({ timestamp }) => {
      try {
        console.log(`📂 Socket: Categories request from ${socket.id}`);
        const categories = await socketDataService.getCategories();
        socket.emit('categories:update', categories);
        console.log(`✅ Socket: Sent ${categories.length} categories`);
      } catch (error) {
        console.error('❌ Socket: Error fetching categories:', error);
        socket.emit('error', { event: 'categories:request', message: error.message });
      }
    });

    socket.on('specialPacks:request', async ({ timestamp }) => {
      try {
        console.log(`🎁 Socket: Special packs request from ${socket.id}`);
        const specialPacks = await socketDataService.getSpecialPacks();
        socket.emit('specialPacks:update', specialPacks);
        console.log(`✅ Socket: Sent ${specialPacks.length} special packs`);
      } catch (error) {
        console.error('❌ Socket: Error fetching special packs:', error);
        socket.emit('error', { event: 'specialPacks:request', message: error.message });
      }
    });

    socket.on('lto:request', async ({ timestamp, restaurantId }) => {
      try {
        console.log(`⏰ Socket: LTO request from ${socket.id}`);
        const ltoItems = await socketDataService.getLTOItems({ restaurantId });
        socket.emit('lto:update', ltoItems);
        console.log(`✅ Socket: Sent ${ltoItems.length} LTO items`);
      } catch (error) {
        console.error('❌ Socket: Error fetching LTO items:', error);
        socket.emit('error', { event: 'lto:request', message: error.message });
      }
    });

    socket.on('restaurants:request', async ({ timestamp, isOpen }) => {
      try {
        console.log(`🍽️ Socket: Restaurants request from ${socket.id}`);
        const restaurants = await socketDataService.getRestaurants({ isOpen });
        socket.emit('restaurants:update', restaurants);
        console.log(`✅ Socket: Sent ${restaurants.length} restaurants`);
      } catch (error) {
        console.error('❌ Socket: Error fetching restaurants:', error);
        socket.emit('error', { event: 'restaurants:request', message: error.message });
      }
    });

    socket.on('menuItems:request', async ({ restaurantId, category, timestamp }) => {
      try {
        console.log(`🍕 Socket: Menu items request from ${socket.id} (restaurant: ${restaurantId}, category: ${category})`);
        const menuItems = await socketDataService.getMenuItems({ restaurantId, category });
        socket.emit('menuItems:update', menuItems);
        console.log(`✅ Socket: Sent ${menuItems.length} menu items`);
      } catch (error) {
        console.error('❌ Socket: Error fetching menu items:', error);
        socket.emit('error', { event: 'menuItems:request', message: error.message });
      }
    });

    socket.on('orders:request', async ({ userId, status, timestamp }) => {
      try {
        console.log(`📦 Socket: Orders request from ${socket.id} (user: ${userId}, status: ${status})`);

        // Import OrderService dynamically to avoid circular dependencies
        const { default: orderService } = await import('../services/orderService.js');
        const { data: orders } = await orderService.getOrders({ userId, status });

        socket.emit('orders:update', orders || []);
        console.log(`✅ Socket: Sent ${(orders || []).length} orders`);
      } catch (error) {
        console.error('❌ Socket: Error fetching orders:', error);
        socket.emit('error', { event: 'orders:request', message: error.message });
      }
    });

    socket.on('tasks:request', async ({ deliveryPersonId, status, timestamp }) => {
      try {
        console.log(`📋 Socket: Tasks request from ${socket.id} (deliveryPerson: ${deliveryPersonId}, status: ${status})`);
        const tasks = await socketDataService.getTasks({ deliveryPersonId, status });
        socket.emit('tasks:update', tasks);
        console.log(`✅ Socket: Sent ${tasks.length} tasks`);
      } catch (error) {
        console.error('❌ Socket: Error fetching tasks:', error);
        socket.emit('error', { event: 'tasks:request', message: error.message });
      }
    });

    // ========== MESSAGES ==========

    socket.on('message:send', async ({ conversationId, message, messageType = 'text', timestamp }) => {
      try {
        console.log(`💬 Socket: Message send to conversation ${conversationId}`);

        const messageData = {
          id: `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
          conversationId,
          senderId: socket.userId,
          message,
          messageType,
          timestamp: timestamp || new Date().toISOString(),
        };

        // Emit to conversation room
        io.to(`conversation:${conversationId}`).emit('message', messageData);

        console.log(`✅ Socket: Message sent to conversation ${conversationId}`);
      } catch (error) {
        console.error('❌ Socket: Error sending message:', error);
        socket.emit('error', { event: 'message:send', message: error.message });
      }
    });

    socket.on('typing', ({ conversationId, isTyping, timestamp }) => {
      try {
        const typingData = {
          conversationId,
          userId: socket.userId,
          isTyping,
          timestamp: timestamp || new Date().toISOString(),
        };

        // Emit to conversation room (except sender)
        socket.to(`conversation:${conversationId}`).emit('typing', typingData);
      } catch (error) {
        console.error('❌ Socket: Error sending typing indicator:', error);
      }
    });

    socket.on('presence', ({ status, timestamp }) => {
      try {
        const presenceData = {
          userId: socket.userId,
          status,
          lastSeen: timestamp || new Date().toISOString(),
        };

        // Broadcast presence to all connected clients
        io.emit('presence', presenceData);
      } catch (error) {
        console.error('❌ Socket: Error sending presence:', error);
      }
    });

    // ========== DISCONNECTION ==========

    socket.on('disconnect', (reason) => {
      console.log(`🔌 Socket: Client disconnected - ${socket.id} (Reason: ${reason})`);

      // Broadcast user offline presence
      if (socket.userId) {
        io.emit('presence', {
          userId: socket.userId,
          status: 'offline',
          lastSeen: new Date().toISOString(),
        });
      }
    });

    // ========== ERROR HANDLING ==========

    socket.on('error', (error) => {
      console.error(`❌ Socket: Client error from ${socket.id}:`, error);
    });
  });

  console.log('✅ Socket.IO server initialized');
  return io;
}

/**
 * Broadcast functions for server-side updates
 * These can be called from other parts of the backend to trigger real-time updates
 */
export function createBroadcastFunctions(io) {
  return {
    /**
     * Broadcast categories update to all clients
     */
    async broadcastCategoriesUpdate() {
      try {
        const categories = await socketDataService.getCategories();
        io.emit('categories:update', categories);
        console.log(`📡 Broadcast: Categories update (${categories.length} items)`);
      } catch (error) {
        console.error('❌ Error broadcasting categories:', error);
      }
    },

    /**
     * Broadcast special packs update
     */
    async broadcastSpecialPacksUpdate() {
      try {
        const specialPacks = await socketDataService.getSpecialPacks();
        io.emit('specialPacks:update', specialPacks);
        console.log(`📡 Broadcast: Special packs update (${specialPacks.length} items)`);
      } catch (error) {
        console.error('❌ Error broadcasting special packs:', error);
      }
    },

    /**
     * Broadcast LTO update
     */
    async broadcastLTOUpdate() {
      try {
        const ltoItems = await socketDataService.getLTOItems();
        io.emit('lto:update', ltoItems);
        console.log(`📡 Broadcast: LTO update (${ltoItems.length} items)`);
      } catch (error) {
        console.error('❌ Error broadcasting LTO:', error);
      }
    },

    /**
     * Broadcast restaurants update
     */
    async broadcastRestaurantsUpdate() {
      try {
        const restaurants = await socketDataService.getRestaurants();
        io.emit('restaurants:update', restaurants);
        console.log(`📡 Broadcast: Restaurants update (${restaurants.length} items)`);
      } catch (error) {
        console.error('❌ Error broadcasting restaurants:', error);
      }
    },

    /**
     * Broadcast single restaurant update
     */
    broadcastRestaurantUpdate(restaurant) {
      io.emit('restaurant:update', restaurant);
      console.log(`📡 Broadcast: Restaurant update - ${restaurant.id}`);
    },

    /**
     * Broadcast menu items update
     */
    async broadcastMenuItemsUpdate({ restaurantId, category } = {}) {
      try {
        const menuItems = await socketDataService.getMenuItems({ restaurantId, category });
        io.emit('menuItems:update', menuItems);
        console.log(`📡 Broadcast: Menu items update (${menuItems.length} items)`);
      } catch (error) {
        console.error('❌ Error broadcasting menu items:', error);
      }
    },

    /**
     * Broadcast single menu item update
     */
    broadcastMenuItemUpdate(menuItem) {
      io.emit('menuItem:update', menuItem);
      console.log(`📡 Broadcast: Menu item update - ${menuItem.id}`);
    },

    /**
     * Broadcast tasks update
     */
    async broadcastTasksUpdate({ deliveryPersonId, status } = {}) {
      try {
        const tasks = await socketDataService.getTasks({ deliveryPersonId, status });
        io.emit('tasks:update', tasks);
        console.log(`📡 Broadcast: Tasks update (${tasks.length} items)`);
      } catch (error) {
        console.error('❌ Error broadcasting tasks:', error);
      }
    },

    /**
     * Broadcast single task update
     */
    broadcastTaskUpdate(task) {
      io.emit('task:update', task);
      console.log(`📡 Broadcast: Task update - ${task.id}`);
    },

    /**
     * Send notification to specific user
     */
    async sendNotificationToUser(userId, { title, message, type = 'info', data = {} }) {
      try {
        const notification = await socketDataService.createNotification({
          userId,
          title,
          message,
          type,
          data,
        });

        if (notification) {
          io.to(`user:${userId}`).emit('notification', {
            id: notification.id,
            userId: notification.user_id,
            title: notification.title,
            message: notification.message,
            type: notification.type,
            data: notification.data || {},
            is_read: notification.is_read,
            created_at: notification.created_at,
          });
          console.log(`📡 Broadcast: Notification sent to user ${userId}`);
        }
      } catch (error) {
        console.error('❌ Error sending notification:', error);
      }
    },

    /**
     * Broadcast order update
     */
    async broadcastOrderUpdate(orderId) {
      try {
        const order = await socketDataService.getOrderById(orderId);
        if (order) {
          io.to(`order:${orderId}`).emit('order:update', order);
          if (order.user_id) {
            io.to(`user:${order.user_id}`).emit('order:update', order);
          }
          console.log(`📡 Broadcast: Order update - ${orderId}`);
        }
      } catch (error) {
        console.error('❌ Error broadcasting order update:', error);
      }
    },

    /**
     * Broadcast orders list update
     */
    async broadcastOrdersUpdate({ userId, status } = {}) {
      try {
        const { default: orderService } = await import('../services/orderService.js');
        const { data: orders } = await orderService.getOrders({ userId, status });

        if (userId) {
          io.to(`user:${userId}`).emit('orders:update', orders || []);
        } else {
          io.emit('orders:update', orders || []);
        }
        console.log(`📡 Broadcast: Orders update (${(orders || []).length} items)`);
      } catch (error) {
        console.error('❌ Error broadcasting orders:', error);
      }
    },
  };
}
