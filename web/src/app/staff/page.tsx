'use client';

import React, { useState, useEffect, useCallback } from 'react';

export interface OrderItem {
  id: string;
  name: string;
  quantity: number;
  price: number;
}

export interface Order {
  id: string;
  order_number: string;
  restaurant_name: string;
  restaurant_id?: string;
  status: 'pending' | 'preparing' | 'ready_for_pickup' | 'delivering' | 'delivered' | 'cancelled';
  total_price: number;
  created_at: string;
  customer_name: string;
  customer_phone?: string;
  items: OrderItem[];
  cancel_reason?: string;
}

export interface MenuItem {
  id: string;
  name: string;
  category?: string;
  price: number;
  preparation_time: number;
  is_available: boolean;
  has_complex_variants: boolean;
}

export interface Restaurant {
  id: string;
  name: string;
  is_open: boolean;
  public_slug?: string;
}

export interface StaffUser {
  id: string;
  username: string;
  name: string;
  role: string;
  phone?: string;
  device_type?: 'personal' | 'kitchen_tablet';
}

export default function StaffPortalPage() {
  // Authentication & session state
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  const [currentUser, setCurrentUser] = useState<StaffUser | null>(null);
  const [username, setUsername] = useState<string>('AminKha');
  const [password, setPassword] = useState<string>('');
  const [deviceType, setDeviceType] = useState<'personal' | 'kitchen_tablet'>('personal');
  const [loginError, setLoginError] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);

  // Active view tabs
  const [activeTab, setActiveTab] = useState<'orders' | 'menu' | 'notifications'>('orders');
  const [orderFilter, setOrderFilter] = useState<'all' | 'pending' | 'preparing' | 'ready_for_pickup'>('pending');
  const [pollStatus, setPollStatus] = useState<'idle' | 'polling' | 'error'>('idle');

  // Multi-restaurant selector state
  const [restaurants, setRestaurants] = useState<Restaurant[]>([]);
  const [selectedRestaurantId, setSelectedRestaurantId] = useState<string>('all');

  // Real Orders and Menu state
  const [orders, setOrders] = useState<Order[]>([]);
  const [menuItems, setMenuItems] = useState<MenuItem[]>([]);
  const [isLoadingOrders, setIsLoadingOrders] = useState<boolean>(false);
  const [isLoadingMenu, setIsLoadingMenu] = useState<boolean>(false);

  // Cancellation modal state
  const [selectedOrderForCancel, setSelectedOrderForCancel] = useState<Order | null>(null);
  const [cancelReason, setCancelReason] = useState<string>('');

  // Push notifications & iOS standalone state
  const [pushSupported, setPushSupported] = useState<boolean>(false);
  const [pushSubscribed, setPushSubscribed] = useState<boolean>(false);
  const [pushStatusMessage, setPushStatusMessage] = useState<string>('');
  const [isIOSInBrowser, setIsIOSInBrowser] = useState<boolean>(false);

  // Detect iOS browser vs Standalone PWA
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const isIOS =
        /iPad|iPhone|iPod/.test(navigator.userAgent) ||
        (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
      const isStandalone =
        (window.navigator as any).standalone === true ||
        window.matchMedia('(display-mode: standalone)').matches;

      setIsIOSInBrowser(isIOS && !isStandalone);
      setPushSupported('serviceWorker' in navigator && 'Notification' in window);
    }
  }, []);

  // Register staff Service Worker on mount
  useEffect(() => {
    if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
      navigator.serviceWorker
        .register('/staff-sw.js', { scope: '/staff/' })
        .then((reg) => {
          console.log('[Staff SW] Registered at scope:', reg.scope);
        })
        .catch((err) => console.error('[Staff SW] Registration error:', err));
    }
  }, []);

  // Check existing session on mount
  useEffect(() => {
    fetch('/staff/api/auth/session')
      .then((res) => (res.ok ? res.json() : null))
      .then((data) => {
        if (data?.authenticated && data.user) {
          setIsAuthenticated(true);
          setCurrentUser(data.user);
        }
      })
      .catch(() => {});
  }, []);

  // Fetch available restaurants for this user
  const fetchRestaurants = useCallback(async () => {
    try {
      const res = await fetch('/staff/api/restaurants');
      if (res.ok) {
        const data = await res.json();
        if (data.success && Array.isArray(data.restaurants) && data.restaurants.length > 0) {
          setRestaurants(data.restaurants);
        }
      }
    } catch (err) {
      console.error('[staff] Error fetching restaurants:', err);
    }
  }, []);

  // Fetch real orders from database
  const fetchOrders = useCallback(async () => {
    if (!isAuthenticated) return;
    setPollStatus('polling');
    try {
      const query = selectedRestaurantId && selectedRestaurantId !== 'all' ? `?restaurant_id=${selectedRestaurantId}` : '';
      const res = await fetch(`/staff/api/orders${query}`);
      if (res.ok) {
        const data = await res.json();
        if (data.success && Array.isArray(data.orders)) {
          setOrders(data.orders);
        }
        setPollStatus('idle');
      } else {
        setPollStatus('error');
      }
    } catch {
      setPollStatus('error');
    }
  }, [isAuthenticated, selectedRestaurantId]);

  // Fetch real menu items for selected restaurant
  const fetchMenu = useCallback(async () => {
    if (!isAuthenticated) return;
    setIsLoadingMenu(true);
    try {
      // If 'all' is selected, default menu items to first restaurant
      let restId = selectedRestaurantId;
      if (restId === 'all' && restaurants.length > 0) {
        restId = restaurants[0].id;
      }
      const query = restId ? `?restaurant_id=${restId}` : '';
      const res = await fetch(`/staff/api/menu${query}`);
      if (res.ok) {
        const data = await res.json();
        if (data.success && Array.isArray(data.items)) {
          setMenuItems(data.items);
        }
      }
    } catch (err) {
      console.error('[staff] Error fetching menu:', err);
    } finally {
      setIsLoadingMenu(false);
    }
  }, [isAuthenticated, selectedRestaurantId, restaurants]);

  // Run initial data loading on authentication
  useEffect(() => {
    if (isAuthenticated) {
      fetchRestaurants();
      fetchOrders();
    }
  }, [isAuthenticated, fetchRestaurants, fetchOrders]);

  // Refresh menu when activeTab switches to 'menu' or restaurant changes
  useEffect(() => {
    if (isAuthenticated && activeTab === 'menu') {
      fetchMenu();
    }
  }, [isAuthenticated, activeTab, selectedRestaurantId, fetchMenu]);

  // Refresh orders when selected restaurant changes
  useEffect(() => {
    if (isAuthenticated) {
      fetchOrders();
    }
  }, [isAuthenticated, selectedRestaurantId, fetchOrders]);

  // 15-second live poller
  useEffect(() => {
    if (!isAuthenticated) return;
    const interval = setInterval(fetchOrders, 15000);
    const handleFocus = () => fetchOrders();
    window.addEventListener('focus', handleFocus);

    return () => {
      clearInterval(interval);
      window.removeEventListener('focus', handleFocus);
    };
  }, [isAuthenticated, fetchOrders]);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoginError('');
    setIsSubmitting(true);

    if (!username.trim() || !password.trim()) {
      setLoginError('يرجى إدخال اسم المستخدم وكلمة المرور');
      setIsSubmitting(false);
      return;
    }

    try {
      const res = await fetch('/staff/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: username.trim(),
          password: password.trim(),
          device_type: deviceType,
        }),
      });

      const data = await res.json();
      if (res.ok && data.success) {
        setIsAuthenticated(true);
        setCurrentUser(data.user);
      } else {
        setLoginError(data.error || 'فشل تسجيل الدخول. تحقق من البيانات المدخلة.');
      }
    } catch {
      setLoginError('تعذر الاتصال بالخادم. يرجى المحاولة لاحقاً.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleLogout = async () => {
    try {
      await fetch('/staff/api/auth/session', { method: 'DELETE' });
    } catch {
      // ignore
    }
    setIsAuthenticated(false);
    setCurrentUser(null);
    setOrders([]);
    setMenuItems([]);
  };

  const handleOrderStatusChange = async (orderId: string, newStatus: Order['status'], reason?: string) => {
    // Optimistic UI update
    setOrders((prev) =>
      prev.map((ord) => (ord.id === orderId ? { ...ord, status: newStatus } : ord)),
    );

    if (newStatus === 'cancelled') {
      setSelectedOrderForCancel(null);
      setCancelReason('');
    }

    try {
      const res = await fetch(`/staff/api/orders/${orderId}/status`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: newStatus, reason }),
      });
      const data = await res.json();
      if (!res.ok || !data.success) {
        alert(data.error || 'فشل تحديث حالة الطلب');
        fetchOrders(); // Rollback to actual server state
      } else {
        // Refetch to ensure all timestamps and statuses are synced
        fetchOrders();
      }
    } catch {
      alert('حدث خطأ أثناء الاتصال بالخادم لتحديث الطلب');
      fetchOrders();
    }
  };

  const handleMenuAvailabilityToggle = async (id: string) => {
    const item = menuItems.find((m) => m.id === id);
    if (!item) return;

    const newAvailability = !item.is_available;
    // Optimistic update
    setMenuItems((prev) =>
      prev.map((m) => (m.id === id ? { ...m, is_available: newAvailability } : m)),
    );

    try {
      const res = await fetch(`/staff/api/menu/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ is_available: newAvailability }),
      });
      const data = await res.json();
      if (!res.ok || !data.success) {
        alert(data.error || 'فشل تحديث حالة توفر الطبق');
        // Rollback
        setMenuItems((prev) =>
          prev.map((m) => (m.id === id ? { ...m, is_available: !newAvailability } : m)),
        );
      }
    } catch {
      alert('تعذر الاتصال بالخادم لتحديث توفر الطبق');
      fetchMenu();
    }
  };

  const handlePriceUpdate = async (id: string, newPriceStr: string) => {
    const item = menuItems.find((m) => m.id === id);
    if (!item) return;

    if (item.has_complex_variants) {
      alert(
        '⚠️ تنبيه أمان: هذا الطبق يحتوي على أحجام أو إضافات متعددة (Variants). تعديل السعر المباشر محجوب لحماية تناسق القائمة.',
      );
      return;
    }

    const price = Number(newPriceStr);
    if (isNaN(price) || price < 0) return;

    try {
      const res = await fetch(`/staff/api/menu/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ price }),
      });
      const data = await res.json();
      if (!res.ok || !data.success) {
        alert(data.error || 'فشل تعديل السعر');
        fetchMenu();
      } else {
        setMenuItems((prev) =>
          prev.map((m) => (m.id === id ? { ...m, price } : m)),
        );
      }
    } catch {
      alert('تعذر الاتصال بالخادم لتحديث السعر');
    }
  };

  const subscribePush = async () => {
    if (isIOSInBrowser) {
      setPushStatusMessage(
        '⚠️ لتفعيل الإشعارات على أجهزة iPhone:\n1. اضغط على أيقونة المشاركة (⎋ Share) أسفل الشاشة.\n2. اختر «إضافة إلى الصفحة الرئيسية» (Add to Home Screen).\n3. افتح التطبيق من الشاشة الرئيسية واضغط تفعيل.',
      );
      return;
    }

    if (typeof window === 'undefined' || !('Notification' in window)) {
      setPushStatusMessage('المتصفح لا يدعم نظام الإشعارات.');
      return;
    }

    try {
      setPushStatusMessage('جاري طلب إذن الإشعارات من المتصفح...');
      const perm = await Notification.requestPermission();
      if (perm !== 'granted') {
        setPushStatusMessage('تم رفض إذن الإشعارات من المتصفح. يرجى السماح بالإشعارات من إعدادات المتصفح.');
        return;
      }

      if (!('serviceWorker' in navigator)) {
        setPushStatusMessage('المتصفح لا يدعم Service Worker.');
        return;
      }

      let reg = await navigator.serviceWorker.getRegistration('/staff/');
      if (!reg) {
        reg = await navigator.serviceWorker.register('/staff-sw.js', { scope: '/staff/' });
      }

      if ('PushManager' in window && reg.pushManager) {
        let sub = await reg.pushManager.getSubscription();
        if (!sub) {
          sub = await reg.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey:
              'BEl62iUYgUivxIkv69yViEuiBIa-Ib9-SkvMeAtA3LFgDzkrxZJjSgSnfckjBJuBkr3qBUYIHBQFLXYp5Nksh8U',
          });
        }

        await fetch('/staff/api/push/subscribe', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ subscription: sub, device_type: deviceType }),
        });
      }

      // Test chime sound immediately so user gets positive confirmation
      try {
        const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.frequency.setValueAtTime(587.33, audioCtx.currentTime); // D5
        osc.frequency.setValueAtTime(880, audioCtx.currentTime + 0.1); // A5
        gain.gain.setValueAtTime(0.3, audioCtx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.35);
        osc.start();
        osc.stop(audioCtx.currentTime + 0.35);

        if (reg?.showNotification) {
          reg.showNotification('بوابة ساهلة لإدارة المطعم 🔔', {
            body: 'تم تفعيل التنبيهات الفورية بنجاح! ستتلقى رنيناً مع كل طلب جديد.',
            icon: '/icon-192.png',
            tag: 'staff-welcome',
          });
        }
      } catch (soundErr) {
        console.warn('Audio/Notification test warning:', soundErr);
      }

      setPushSubscribed(true);
      setPushStatusMessage('تم تفعيل التنبيهات الفورية بنجاح على هذا الجهاز ✓');
    } catch (err: any) {
      setPushStatusMessage('تعذر تفعيل الإشعارات: ' + (err.message || err));
    }
  };

  return (
    <div className="flex flex-col min-h-screen max-w-4xl mx-auto w-full px-4 py-4 pb-16" dir="rtl">
      {/* Top Header */}
      <header className="flex flex-col sm:flex-row sm:items-center justify-between border-b border-slate-800 pb-4 mb-4 gap-3">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-orange-600 to-amber-500 flex items-center justify-center text-white font-bold text-xl shadow-lg shadow-orange-950">
            س
          </div>
          <div>
            <h1 className="text-xl font-bold text-white flex items-center gap-2">
              بوابة ساهلة لإدارة المطعم
              <span className="text-xs bg-orange-900/60 text-orange-400 px-2 py-0.5 rounded-full border border-orange-700/50">
                Staff PWA
              </span>
            </h1>
            <p className="text-xs text-slate-400">إدارة الطلبات المباشرة، التنبيهات الفورية، وتوفر الأطباق</p>
          </div>
        </div>

        {isAuthenticated && (
          <div className="flex items-center gap-3 self-end sm:self-auto">
            {/* Restaurant Selector for Admin & Multi-restaurant owners */}
            {restaurants.length > 0 && (
              <div className="flex items-center gap-1.5">
                <select
                  value={selectedRestaurantId}
                  onChange={(e) => setSelectedRestaurantId(e.target.value)}
                  className="bg-slate-900 border border-slate-700 text-white text-xs rounded-xl px-2.5 py-1.5 focus:outline-none focus:border-orange-500 max-w-[160px] truncate"
                >
                  {(currentUser?.role === 'admin' || currentUser?.role === 'super_admin') && (
                    <option value="all">🏢 جميع المطاعم ({restaurants.length})</option>
                  )}
                  {restaurants.map((r) => (
                    <option key={r.id} value={r.id}>
                      {r.name} {r.is_open ? '🟢' : '🔴'}
                    </option>
                  ))}
                </select>
              </div>
            )}

            <div className="text-left hidden sm:block">
              <span className="block text-xs font-bold text-white">{currentUser?.name || 'طاقم العمل'}</span>
              <span className="text-[10px] bg-slate-800 text-slate-300 px-1.5 py-0.5 rounded border border-slate-700">
                {currentUser?.role === 'admin' ? 'مدير النظام (Admin)' : currentUser?.role || 'Staff'}
              </span>
            </div>

            <span
              className={`inline-block w-2.5 h-2.5 rounded-full ${
                pollStatus === 'polling'
                  ? 'bg-amber-400 animate-ping'
                  : pollStatus === 'error'
                  ? 'bg-rose-500'
                  : 'bg-emerald-400'
              }`}
              title={pollStatus === 'polling' ? 'جاري التحديث...' : 'متصل بقاعدة البيانات'}
            />

            <button
              onClick={handleLogout}
              className="text-xs bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-700 px-3 py-1.5 rounded-lg transition min-h-[36px]"
            >
              خروج
            </button>
          </div>
        )}
      </header>

      {/* Login Screen */}
      {!isAuthenticated ? (
        <div className="flex flex-col items-center justify-center flex-1 py-8">
          <div className="w-full max-w-md bg-slate-900/80 border border-slate-800 rounded-2xl p-6 shadow-2xl backdrop-blur">
            <h2 className="text-lg font-bold text-white mb-2 text-center">تسجيل دخول طاقم العمل</h2>
            <p className="text-xs text-slate-400 mb-6 text-center">
              سجل دخولك باسم المستخدم الخاص بمطعمك (بدون بريد خارجي)
            </p>

            {loginError && (
              <div className="mb-4 p-3 rounded-xl bg-rose-950/60 border border-rose-800/80 text-rose-300 text-xs">
                {loginError}
              </div>
            )}

            <form onSubmit={handleLogin} className="space-y-4">
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">اسم المستخدم (Username)</label>
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="مثال: AminKha"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-orange-500 transition"
                  dir="ltr"
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">كلمة المرور (Password)</label>
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-orange-500 transition"
                  dir="ltr"
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-300 mb-2">نوع الجهاز (جلسة العمل)</label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setDeviceType('personal')}
                    className={`p-3 rounded-xl border text-xs font-medium flex flex-col items-center gap-1 transition ${
                      deviceType === 'personal'
                        ? 'border-orange-500 bg-orange-950/30 text-orange-300'
                        : 'border-slate-800 bg-slate-950 text-slate-400'
                    }`}
                  >
                    <span>هاتف شخصي</span>
                    <span className="text-[10px] text-slate-500">مهلة خمول: 12 ساعة</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setDeviceType('kitchen_tablet')}
                    className={`p-3 rounded-xl border text-xs font-medium flex flex-col items-center gap-1 transition ${
                      deviceType === 'kitchen_tablet'
                        ? 'border-orange-500 bg-orange-950/30 text-orange-300'
                        : 'border-slate-800 bg-slate-950 text-slate-400'
                    }`}
                  >
                    <span>تابلت المطبخ المشترك</span>
                    <span className="text-[10px] text-slate-500">مهلة خمول: 30 دقيقة</span>
                  </button>
                </div>
              </div>

              <button
                type="submit"
                disabled={isSubmitting}
                className="w-full py-3 bg-gradient-to-r from-orange-600 to-amber-600 hover:from-orange-500 hover:to-amber-500 text-white font-bold rounded-xl text-sm shadow-lg shadow-orange-950 transition disabled:opacity-50 min-h-[48px]"
              >
                {isSubmitting ? 'جاري التحقق...' : 'دخول إلى البوابة'}
              </button>
            </form>
          </div>
        </div>
      ) : (
        /* Authenticated Staff Dashboard */
        <div className="flex flex-col flex-1 gap-4">
          {/* Main Tab Navigation */}
          <div className="flex border-b border-slate-800">
            <button
              onClick={() => setActiveTab('orders')}
              className={`flex-1 py-3 text-sm font-semibold border-b-2 transition ${
                activeTab === 'orders'
                  ? 'border-orange-500 text-orange-400 bg-orange-950/10'
                  : 'border-transparent text-slate-400 hover:text-slate-200'
              }`}
            >
              الطلبات المباشرة ({orders.filter((o) => o.status !== 'cancelled' && o.status !== 'delivered').length})
            </button>
            <button
              onClick={() => setActiveTab('menu')}
              className={`flex-1 py-3 text-sm font-semibold border-b-2 transition ${
                activeTab === 'menu'
                  ? 'border-orange-500 text-orange-400 bg-orange-950/10'
                  : 'border-transparent text-slate-400 hover:text-slate-200'
              }`}
            >
              قائمة الطعام والأسعار
            </button>
            <button
              onClick={() => setActiveTab('notifications')}
              className={`flex-1 py-3 text-sm font-semibold border-b-2 transition ${
                activeTab === 'notifications'
                  ? 'border-orange-500 text-orange-400 bg-orange-950/10'
                  : 'border-transparent text-slate-400 hover:text-slate-200'
              }`}
            >
              التنبيهات الفورية (Push)
            </button>
          </div>

          {/* Orders View */}
          {activeTab === 'orders' && (
            <div className="flex flex-col gap-4">
              {/* Order status filters */}
              <div className="flex gap-2 overflow-x-auto pb-1 text-xs">
                {(['pending', 'preparing', 'ready_for_pickup', 'all'] as const).map((filter) => {
                  const count =
                    filter === 'all'
                      ? orders.length
                      : orders.filter((o) => o.status === filter).length;

                  return (
                    <button
                      key={filter}
                      onClick={() => setOrderFilter(filter)}
                      className={`px-3 py-1.5 rounded-full border transition whitespace-nowrap min-h-[36px] flex items-center gap-1.5 ${
                        orderFilter === filter
                          ? 'bg-orange-500 border-orange-500 text-white font-bold'
                          : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-slate-200'
                      }`}
                    >
                      <span>
                        {filter === 'pending'
                          ? 'قيد الانتظار'
                          : filter === 'preparing'
                          ? 'قيد التحضير'
                          : filter === 'ready_for_pickup'
                          ? 'جاهز للاستلام'
                          : 'الكل'}
                      </span>
                      {count > 0 && (
                        <span
                          className={`text-[10px] px-1.5 py-0.2 rounded-full ${
                            orderFilter === filter ? 'bg-orange-700 text-white' : 'bg-slate-800 text-slate-300'
                          }`}
                        >
                          {count}
                        </span>
                      )}
                    </button>
                  );
                })}
              </div>

              {/* Order Cards List */}
              <div className="flex flex-col gap-3">
                {orders
                  .filter((o) => (orderFilter === 'all' ? true : o.status === orderFilter))
                  .map((order) => (
                    <div
                      key={order.id}
                      className="bg-slate-900 border border-slate-800 rounded-2xl p-4 flex flex-col gap-3 shadow-md"
                    >
                      <div className="flex items-center justify-between border-b border-slate-800/80 pb-2">
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-base font-bold text-white tracking-wide">{order.order_number}</span>
                            <span className="text-xs bg-slate-800 text-orange-300 px-2 py-0.5 rounded-lg border border-slate-700">
                              {order.restaurant_name}
                            </span>
                          </div>
                          <span className="text-xs text-slate-400 block mt-0.5">
                            {order.customer_name} {order.customer_phone ? `• ${order.customer_phone}` : ''}
                          </span>
                        </div>
                        <span
                          className={`text-xs px-2.5 py-1 rounded-full font-bold ${
                            order.status === 'pending'
                              ? 'bg-rose-950/80 text-rose-300 border border-rose-800/50 animate-pulse'
                              : order.status === 'preparing'
                              ? 'bg-amber-950/80 text-amber-300 border border-amber-800/50'
                              : order.status === 'ready_for_pickup'
                              ? 'bg-emerald-950/80 text-emerald-300 border border-emerald-800/50'
                              : order.status === 'delivered'
                              ? 'bg-blue-950/80 text-blue-300 border border-blue-800/50'
                              : 'bg-slate-800 text-slate-400'
                          }`}
                        >
                          {order.status === 'pending'
                            ? 'بانتظار الموافقة'
                            : order.status === 'preparing'
                            ? 'جاري التحضير'
                            : order.status === 'ready_for_pickup'
                            ? 'جاهز للاستلام'
                            : order.status === 'delivered'
                            ? 'تم التوصيل'
                            : order.status === 'cancelled'
                            ? 'ملغي'
                            : order.status}
                        </span>
                      </div>

                      {/* Items */}
                      <div className="space-y-1">
                        {order.items.map((item) => (
                          <div key={item.id} className="flex justify-between text-xs text-slate-300">
                            <span>
                              {item.quantity}x {item.name}
                            </span>
                            <span className="text-slate-400">{item.price * item.quantity} دج</span>
                          </div>
                        ))}
                      </div>

                      {/* Cancellation reason note if exists */}
                      {order.cancel_reason && (
                        <div className="p-2 rounded-lg bg-rose-950/40 border border-rose-900/50 text-rose-300 text-[11px]">
                          سبب الإلغاء: {order.cancel_reason}
                        </div>
                      )}

                      {/* Total & Action Buttons */}
                      <div className="flex items-center justify-between pt-2 border-t border-slate-800/80">
                        <div>
                          <span className="text-xs text-slate-400">المجموع: </span>
                          <span className="text-sm font-bold text-orange-400">{order.total_price} دج</span>
                        </div>

                        <div className="flex gap-2">
                          {order.status === 'pending' && (
                            <>
                              <button
                                onClick={() => handleOrderStatusChange(order.id, 'preparing')}
                                className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-bold transition min-h-[44px]"
                              >
                                قبول الطلب
                              </button>
                              <button
                                onClick={() => setSelectedOrderForCancel(order)}
                                className="px-3 py-2 bg-rose-900/40 hover:bg-rose-900 text-rose-300 border border-rose-800/60 rounded-xl text-xs font-medium transition min-h-[44px]"
                              >
                                رفض
                              </button>
                            </>
                          )}

                          {order.status === 'preparing' && (
                            <button
                              onClick={() => handleOrderStatusChange(order.id, 'ready_for_pickup')}
                              className="px-4 py-2 bg-amber-600 hover:bg-amber-500 text-white rounded-xl text-xs font-bold transition min-h-[44px]"
                            >
                              جاهز للتوصيل
                            </button>
                          )}
                        </div>
                      </div>
                    </div>
                  ))}

                {orders.filter((o) => (orderFilter === 'all' ? true : o.status === orderFilter)).length === 0 && (
                  <div className="py-12 text-center text-slate-500 text-xs">
                    لا توجد طلبات في هذه الحالة حالياً
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Menu Management View */}
          {activeTab === 'menu' && (
            <div className="flex flex-col gap-4">
              <div className="bg-slate-900/60 border border-slate-800 rounded-2xl p-4 text-xs text-slate-400 leading-relaxed">
                ℹ️ <strong className="text-slate-200">إدارة القائمة المباشرة:</strong> يمكنك تفعيل/تعطيل توفر الأطباق،
                وتحديث السعر الأساسي للأطباق البسيطة. الأطباق التي تحتوي على مقاسات متعددة أو إضافات (Variants/Supplements)
                محمية بحارس البيانات لمنع تشوه التسعير.
              </div>

              {isLoadingMenu ? (
                <div className="py-12 text-center text-slate-500 text-xs">جاري تحميل قائمة الطعام...</div>
              ) : (
                <div className="flex flex-col gap-3">
                  {menuItems.map((item) => (
                    <div
                      key={item.id}
                      className="bg-slate-900 border border-slate-800 rounded-2xl p-4 flex flex-col md:flex-row md:items-center justify-between gap-4"
                    >
                      <div className="flex items-center gap-3">
                        <button
                          onClick={() => handleMenuAvailabilityToggle(item.id)}
                          className={`w-12 h-6 rounded-full transition relative flex items-center p-0.5 ${
                            item.is_available ? 'bg-emerald-600' : 'bg-slate-700'
                          }`}
                          title={item.is_available ? 'متوفر' : 'غير متوفر'}
                        >
                          <div
                            className={`w-5 h-5 rounded-full bg-white transition transform ${
                              item.is_available ? '-translate-x-6' : 'translate-x-0'
                            }`}
                          />
                        </button>
                        <div>
                          <h4 className="text-sm font-bold text-white flex items-center gap-2">
                            {item.name}
                            {item.has_complex_variants && (
                              <span className="text-[10px] bg-slate-800 text-slate-400 px-1.5 py-0.5 rounded border border-slate-700">
                                أحجام / إضافات متعددة
                              </span>
                            )}
                          </h4>
                          <span className="text-xs text-slate-400">
                            التصنيف: {item.category || 'عام'} • وقت التحضير: {item.preparation_time} دقيقة
                          </span>
                        </div>
                      </div>

                      <div className="flex items-center gap-3">
                        <div className="flex items-center gap-1.5">
                          <span className="text-xs text-slate-400">السعر:</span>
                          <input
                            type="number"
                            defaultValue={item.price}
                            disabled={item.has_complex_variants}
                            onBlur={(e) => handlePriceUpdate(item.id, e.target.value)}
                            className={`w-24 bg-slate-950 border rounded-lg px-2 py-1 text-sm text-center font-bold text-white focus:outline-none ${
                              item.has_complex_variants
                                ? 'border-slate-800 text-slate-500 cursor-not-allowed opacity-60'
                                : 'border-slate-700 focus:border-orange-500'
                            }`}
                            dir="ltr"
                          />
                          <span className="text-xs text-slate-400">دج</span>
                        </div>
                      </div>
                    </div>
                  ))}

                  {menuItems.length === 0 && (
                    <div className="py-12 text-center text-slate-500 text-xs">
                      لا توجد أطباق مسجلة لهذا المطعم
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Web Push Alerts View */}
          {activeTab === 'notifications' && (
            <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 flex flex-col gap-4">
              <h3 className="text-base font-bold text-white">إعداد التنبيهات الفورية (Web Push)</h3>
              <p className="text-xs text-slate-400 leading-relaxed">
                قم بتفعيل الإشعارات الفورية على هذا الجهاز لتلقي رنين صوتي مميز فور وصول طلب جديد لمطعمك، حتى وإن كان المتصفح
                في الخلفية أو الجهاز مقفلاً.
              </p>

              {/* iOS Safari Instruction Card */}
              {isIOSInBrowser && (
                <div className="p-4 bg-orange-950/40 border border-orange-700/60 rounded-xl text-xs text-orange-200 flex flex-col gap-2">
                  <span className="font-bold text-sm">📱 خطوة تفعيل لمستخدمي iPhone (iOS):</span>
                  <p>أبل تشترط إضافة الموقع للشاشة الرئيسية لتشغيل الإشعارات في الخلفية:</p>
                  <ol className="list-decimal list-inside space-y-1 text-slate-300">
                    <li>
                      اضغط على زر المشاركة أسفل Safari <strong className="text-white">(أيقونة ⎋ المربع بسهم)</strong>.
                    </li>
                    <li>
                      مرر للأسفل واختر <strong className="text-white">«إضافة إلى الصفحة الرئيسية» (Add to Home Screen)</strong>.
                    </li>
                    <li>افتح التطبيق من الأيقونة على شاشتك واضغط تفعيل ليعمل الرنين والتنبيه مثل التطبيقات الأصلية!</li>
                  </ol>
                </div>
              )}

              {pushStatusMessage && (
                <div className="p-3 bg-slate-950 border border-slate-800 rounded-xl text-xs text-slate-300 whitespace-pre-line">
                  {pushStatusMessage}
                </div>
              )}

              <button
                onClick={subscribePush}
                disabled={pushSubscribed}
                className="py-3 px-6 bg-orange-600 hover:bg-orange-500 text-white font-bold rounded-xl text-xs shadow-lg transition disabled:opacity-50 min-h-[44px] self-start"
              >
                {pushSubscribed ? 'التنبيهات مفعلة على هذا الجهاز ✓' : 'تفعيل إشعارات الطلبات الفورية'}
              </button>
            </div>
          )}
        </div>
      )}

      {/* Cancellation Reason Modal */}
      {selectedOrderForCancel && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center p-4 z-50">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 max-w-md w-full shadow-2xl flex flex-col gap-4">
            <h3 className="text-base font-bold text-white">إلغاء الطلب {selectedOrderForCancel.order_number}</h3>
            <p className="text-xs text-slate-400">
              يرجى تحديد سبب الإلغاء ليتم إرساله للزبون وتوثيق العملية في سجل النظام:
            </p>

            <textarea
              value={cancelReason}
              onChange={(e) => setCancelReason(e.target.value)}
              placeholder="مثال: نفاد المكونات الأساسية، المطعم مغلق للصيانة..."
              rows={3}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-white focus:outline-none focus:border-rose-500"
            />

            <div className="flex gap-2 justify-end">
              <button
                onClick={() => setSelectedOrderForCancel(null)}
                className="px-4 py-2 bg-slate-800 text-slate-300 rounded-xl text-xs font-medium"
              >
                تراجع
              </button>
              <button
                onClick={() => handleOrderStatusChange(selectedOrderForCancel.id, 'cancelled', cancelReason)}
                disabled={!cancelReason.trim() || cancelReason.trim().length < 3}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-500 text-white rounded-xl text-xs font-bold transition disabled:opacity-40"
              >
                تأكيد الإلغاء
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
