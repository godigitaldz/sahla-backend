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

const STORAGE_SAVED_USERNAME_KEY = 'sahla_staff_saved_username';
const STORAGE_REMEMBER_ME_KEY = 'sahla_staff_remember_me';

export default function StaffPortalPage() {
  // Authentication & session state
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  const [currentUser, setCurrentUser] = useState<StaffUser | null>(null);
  const [username, setUsername] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [deviceType] = useState<'personal'>('personal');
  const [rememberMe, setRememberMe] = useState<boolean>(true);
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

  // Load saved identity on client mount
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const savedUser = localStorage.getItem(STORAGE_SAVED_USERNAME_KEY);
      const savedRemember = localStorage.getItem(STORAGE_REMEMBER_ME_KEY);

      if (savedUser) {
        setUsername(savedUser);
      } else {
        setUsername('AminKha');
      }

      if (savedRemember !== null) {
        setRememberMe(savedRemember === 'true');
      }

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
      const query =
        selectedRestaurantId && selectedRestaurantId !== 'all'
          ? `?restaurant_id=${selectedRestaurantId}`
          : '';
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
        // Save or clear remembered username
        if (typeof window !== 'undefined') {
          if (rememberMe) {
            localStorage.setItem(STORAGE_SAVED_USERNAME_KEY, username.trim());
            localStorage.setItem(STORAGE_REMEMBER_ME_KEY, 'true');
          } else {
            localStorage.removeItem(STORAGE_SAVED_USERNAME_KEY);
            localStorage.setItem(STORAGE_REMEMBER_ME_KEY, 'false');
          }
        }

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

  const handleOrderStatusChange = async (
    orderId: string,
    newStatus: Order['status'],
    reason?: string,
  ) => {
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
        fetchOrders();
      } else {
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
        setPushStatusMessage(
          'تم رفض إذن الإشعارات من المتصفح. يرجى السماح بالإشعارات من إعدادات المتصفح.',
        );
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

      // Audio test chime
      try {
        const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.frequency.setValueAtTime(587.33, audioCtx.currentTime);
        osc.frequency.setValueAtTime(880, audioCtx.currentTime + 0.1);
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
    <div
      className="flex flex-col min-h-screen max-w-4xl mx-auto w-full px-4 pb-16 pt-[max(env(safe-area-inset-top),20px)] transition-colors duration-200"
      dir="rtl"
    >
      {/* Top Header: Clean minimal toolbar with dropdown and signout only */}
      {isAuthenticated && (
        <header className="bg-white border border-slate-200/90 rounded-2xl p-2.5 mb-4 shadow-sm mt-1 flex items-center justify-between gap-2.5">
          {restaurants.length > 0 && (
            <div className="flex items-center gap-2 flex-1">
              <span
                className={`inline-block w-2.5 h-2.5 rounded-full shrink-0 ${
                  pollStatus === 'polling'
                    ? 'bg-amber-400 animate-ping'
                    : pollStatus === 'error'
                    ? 'bg-rose-500'
                    : 'bg-emerald-500'
                }`}
                title={pollStatus === 'polling' ? 'جاري التحديث...' : 'متصل بالخادم'}
              />
              <select
                value={selectedRestaurantId}
                onChange={(e) => setSelectedRestaurantId(e.target.value)}
                className="w-full bg-slate-50 hover:bg-slate-100 border border-slate-300 text-slate-900 font-bold text-xs md:text-sm rounded-xl px-3 py-2.5 focus:outline-none focus:border-orange-500 focus:ring-2 focus:ring-orange-100 transition shadow-inner"
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

          <button
            onClick={handleLogout}
            className="text-xs bg-slate-100 hover:bg-rose-50 text-slate-700 hover:text-rose-700 font-bold border border-slate-200 hover:border-rose-200 px-4 py-2.5 rounded-xl transition min-h-[40px] shrink-0"
          >
            خروج
          </button>
        </header>
      )}

      {/* Login Screen (Polished White SaaS Aesthetic) */}
      {!isAuthenticated ? (
        <div className="flex flex-col items-center justify-center flex-1 py-6">
          <div className="w-full max-w-md bg-white border border-slate-200/90 rounded-2xl p-6 md:p-8 shadow-xl shadow-slate-200/50">
            <div className="flex justify-center mb-6">
              <div className="w-14 h-14 rounded-2xl bg-orange-50 border border-orange-200/60 flex items-center justify-center text-orange-600 font-black text-3xl shadow-inner">
                س
              </div>
            </div>

            {loginError && (
              <div className="mb-4 p-3.5 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-xs font-medium flex items-center gap-2">
                <span>⚠️</span>
                <span>{loginError}</span>
              </div>
            )}

            <form onSubmit={handleLogin} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1.5">
                  اسم المستخدم (Username)
                </label>
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="مثال: AminKha"
                  className="w-full bg-slate-50 hover:bg-white focus:bg-white border border-slate-300 rounded-xl px-4 py-2.5 text-sm text-slate-900 focus:outline-none focus:border-orange-500 focus:ring-2 focus:ring-orange-100 transition shadow-inner"
                  dir="ltr"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1.5">
                  كلمة المرور (Password)
                </label>
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full bg-slate-50 hover:bg-white focus:bg-white border border-slate-300 rounded-xl px-4 py-2.5 text-sm text-slate-900 focus:outline-none focus:border-orange-500 focus:ring-2 focus:ring-orange-100 transition shadow-inner"
                  dir="ltr"
                />
              </div>

              {/* Save My Identity Option */}
              <div className="flex items-center justify-between pt-1 pb-1">
                <label className="flex items-center gap-2.5 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={rememberMe}
                    onChange={(e) => setRememberMe(e.target.checked)}
                    className="w-4 h-4 text-orange-600 border-slate-300 rounded focus:ring-orange-500 accent-orange-600 transition"
                  />
                  <span className="text-xs font-medium text-slate-700">
                    حفظ بيانات الدخول على هذا الجهاز
                  </span>
                </label>
              </div>

              <button
                type="submit"
                disabled={isSubmitting}
                className="w-full py-3 bg-gradient-to-r from-orange-600 to-amber-600 hover:from-orange-500 hover:to-amber-500 text-white font-bold rounded-xl text-sm shadow-md shadow-orange-600/20 transition disabled:opacity-50 min-h-[48px] mt-2"
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
          <div className="bg-slate-200/80 p-1.5 rounded-2xl flex border border-slate-300/60 shadow-inner">
            <button
              onClick={() => setActiveTab('orders')}
              className={`flex-1 py-2.5 text-xs md:text-sm font-bold rounded-xl transition ${
                activeTab === 'orders'
                  ? 'bg-white text-orange-700 shadow-sm'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              الطلبات المباشرة ({orders.filter((o) => o.status !== 'cancelled' && o.status !== 'delivered').length})
            </button>
            <button
              onClick={() => setActiveTab('menu')}
              className={`flex-1 py-2.5 text-xs md:text-sm font-bold rounded-xl transition ${
                activeTab === 'menu'
                  ? 'bg-white text-orange-700 shadow-sm'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              قائمة الطعام والأسعار
            </button>
            <button
              onClick={() => setActiveTab('notifications')}
              className={`flex-1 py-2.5 text-xs md:text-sm font-bold rounded-xl transition ${
                activeTab === 'notifications'
                  ? 'bg-white text-orange-700 shadow-sm'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              التنبيهات الفورية (Push)
            </button>
          </div>

          {/* Orders View */}
          {activeTab === 'orders' && (
            <div className="flex flex-col gap-4">
              {/* Status Filter Chips */}
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
                      className={`px-3.5 py-2 rounded-xl border transition whitespace-nowrap min-h-[38px] flex items-center gap-1.5 shadow-sm ${
                        orderFilter === filter
                          ? 'bg-orange-600 border-orange-600 text-white font-bold'
                          : 'bg-white border-slate-200 text-slate-700 hover:bg-slate-50'
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
                          className={`text-[10px] px-2 py-0.5 rounded-full font-bold ${
                            orderFilter === filter
                              ? 'bg-orange-800 text-white'
                              : 'bg-slate-100 text-slate-700 border border-slate-200'
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
                      className="bg-white border border-slate-200/90 rounded-2xl p-4 md:p-5 flex flex-col gap-3.5 shadow-sm hover:shadow transition"
                    >
                      <div className="flex items-center justify-between border-b border-slate-100 pb-3 flex-wrap gap-2">
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-base font-extrabold text-slate-900 tracking-wide">
                              {order.order_number}
                            </span>
                            <span className="text-xs bg-orange-50 text-orange-700 font-semibold px-2.5 py-0.5 rounded-lg border border-orange-200/60">
                              {order.restaurant_name}
                            </span>
                          </div>
                          <span className="text-xs text-slate-500 block mt-1">
                            {order.customer_name} {order.customer_phone ? `• ${order.customer_phone}` : ''}
                          </span>
                        </div>
                        <span
                          className={`text-xs px-3 py-1 rounded-full font-bold shadow-xs ${
                            order.status === 'pending'
                              ? 'bg-rose-50 text-rose-700 border border-rose-200 animate-pulse'
                              : order.status === 'preparing'
                              ? 'bg-amber-50 text-amber-800 border border-amber-200'
                              : order.status === 'ready_for_pickup'
                              ? 'bg-emerald-50 text-emerald-800 border border-emerald-200'
                              : order.status === 'delivered'
                              ? 'bg-blue-50 text-blue-700 border border-blue-200'
                              : 'bg-slate-100 text-slate-600 border border-slate-200'
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
                      <div className="space-y-1.5 py-1">
                        {order.items.map((item) => (
                          <div key={item.id} className="flex justify-between text-xs text-slate-800">
                            <span className="font-medium">
                              {item.quantity}x {item.name}
                            </span>
                            <span className="text-slate-500 font-semibold">
                              {item.price * item.quantity} دج
                            </span>
                          </div>
                        ))}
                      </div>

                      {order.cancel_reason && (
                        <div className="p-2.5 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-xs">
                          <strong className="font-bold">سبب الإلغاء:</strong> {order.cancel_reason}
                        </div>
                      )}

                      {/* Total & Action Buttons */}
                      <div className="flex items-center justify-between pt-3 border-t border-slate-100 flex-wrap gap-2">
                        <div>
                          <span className="text-xs text-slate-500">المجموع: </span>
                          <span className="text-base font-extrabold text-orange-600">
                            {order.total_price} دج
                          </span>
                        </div>

                        <div className="flex gap-2">
                          {order.status === 'pending' && (
                            <>
                              <button
                                onClick={() => handleOrderStatusChange(order.id, 'preparing')}
                                className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold transition min-h-[42px] shadow-sm"
                              >
                                قبول الطلب
                              </button>
                              <button
                                onClick={() => setSelectedOrderForCancel(order)}
                                className="px-3.5 py-2 bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-200 rounded-xl text-xs font-semibold transition min-h-[42px]"
                              >
                                رفض
                              </button>
                            </>
                          )}

                          {order.status === 'preparing' && (
                            <button
                              onClick={() => handleOrderStatusChange(order.id, 'ready_for_pickup')}
                              className="px-4 py-2 bg-amber-500 hover:bg-amber-600 text-white rounded-xl text-xs font-bold transition min-h-[42px] shadow-sm"
                            >
                              جاهز للتوصيل
                            </button>
                          )}
                        </div>
                      </div>
                    </div>
                  ))}

                {orders.filter((o) => (orderFilter === 'all' ? true : o.status === orderFilter)).length ===
                  0 && (
                  <div className="py-16 text-center text-slate-400 text-xs bg-white border border-slate-200 rounded-2xl">
                    لا توجد طلبات في هذه الحالة حالياً
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Menu Management View */}
          {activeTab === 'menu' && (
            <div className="flex flex-col gap-4">
              <div className="bg-amber-50/70 border border-amber-200/80 rounded-2xl p-4 text-xs text-amber-900 leading-relaxed shadow-sm">
                ℹ️ <strong className="font-bold">إدارة قائمة الطعام المباشرة:</strong> يمكنك تفعيل/تعطيل توفر الأطباق
                وتحديث السعر الأساسي للأطباق البسيطة مباشرة. الأطباق التي تحتوي على مقاسات متعددة أو إضافات (Variants)
                محمية بحارس البيانات لمنع أي تضارب في الأسعار.
              </div>

              {isLoadingMenu ? (
                <div className="py-16 text-center text-slate-400 text-xs bg-white border border-slate-200 rounded-2xl">
                  جاري تحميل قائمة الطعام...
                </div>
              ) : (
                <div className="flex flex-col gap-3">
                  {menuItems.map((item) => (
                    <div
                      key={item.id}
                      className="bg-white border border-slate-200 rounded-2xl p-4 flex flex-col md:flex-row md:items-center justify-between gap-4 shadow-sm"
                    >
                      <div className="flex items-center gap-3">
                        <button
                          onClick={() => handleMenuAvailabilityToggle(item.id)}
                          className={`w-12 h-6 rounded-full transition relative flex items-center p-0.5 ${
                            item.is_available ? 'bg-emerald-600' : 'bg-slate-300'
                          }`}
                          title={item.is_available ? 'متوفر' : 'غير متوفر'}
                        >
                          <div
                            className={`w-5 h-5 rounded-full bg-white shadow-md transition transform ${
                              item.is_available ? '-translate-x-6' : 'translate-x-0'
                            }`}
                          />
                        </button>
                        <div>
                          <h4 className="text-sm font-bold text-slate-900 flex items-center gap-2">
                            {item.name}
                            {item.has_complex_variants && (
                              <span className="text-[10px] bg-slate-100 text-slate-600 px-2 py-0.5 rounded-md border border-slate-200 font-medium">
                                أحجام / إضافات متعددة
                              </span>
                            )}
                          </h4>
                          <span className="text-xs text-slate-500">
                            التصنيف: {item.category || 'عام'} • وقت التحضير: {item.preparation_time} دقيقة
                          </span>
                        </div>
                      </div>

                      <div className="flex items-center gap-3">
                        <div className="flex items-center gap-1.5">
                          <span className="text-xs text-slate-500 font-medium">السعر:</span>
                          <input
                            type="number"
                            defaultValue={item.price}
                            disabled={item.has_complex_variants}
                            onBlur={(e) => handlePriceUpdate(item.id, e.target.value)}
                            className={`w-24 bg-slate-50 border rounded-xl px-2 py-1.5 text-sm text-center font-bold text-slate-900 focus:outline-none focus:bg-white ${
                              item.has_complex_variants
                                ? 'border-slate-200 text-slate-400 cursor-not-allowed opacity-60'
                                : 'border-slate-300 focus:border-orange-500 focus:ring-2 focus:ring-orange-100'
                            }`}
                            dir="ltr"
                          />
                          <span className="text-xs text-slate-500 font-medium">دج</span>
                        </div>
                      </div>
                    </div>
                  ))}

                  {menuItems.length === 0 && (
                    <div className="py-16 text-center text-slate-400 text-xs bg-white border border-slate-200 rounded-2xl">
                      لا توجد أطباق مسجلة لهذا المطعم
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Web Push Alerts View */}
          {activeTab === 'notifications' && (
            <div className="bg-white border border-slate-200 rounded-2xl p-6 flex flex-col gap-4 shadow-sm">
              <h3 className="text-base font-bold text-slate-900">إعداد التنبيهات الفورية (Web Push)</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                قم بتفعيل الإشعارات الفورية على هذا الجهاز لتلقي رنين صوتي مميز فور وصول طلب جديد لمطعمك، حتى وإن كان
                المتصفح في الخلفية أو الجهاز مقفلاً.
              </p>

              {isIOSInBrowser && (
                <div className="p-4 bg-orange-50 border border-orange-200 rounded-xl text-xs text-orange-950 flex flex-col gap-2">
                  <span className="font-bold text-sm text-orange-900">📱 خطوة تفعيل لمستخدمي iPhone (iOS):</span>
                  <p className="text-slate-700">تشترط أبل إضافة الموقع للشاشة الرئيسية لتشغيل الإشعارات في الخلفية:</p>
                  <ol className="list-decimal list-inside space-y-1 text-slate-700">
                    <li>
                      اضغط على زر المشاركة أسفل Safari <strong className="text-slate-900">(أيقونة ⎋ المربع بسهم)</strong>.
                    </li>
                    <li>
                      مرر للأسفل واختر <strong className="text-slate-900">«إضافة إلى الصفحة الرئيسية» (Add to Home Screen)</strong>.
                    </li>
                    <li>افتح التطبيق من الأيقونة على شاشتك واضغط تفعيل ليعمل الرنين والتنبيه فوراً.</li>
                  </ol>
                </div>
              )}

              {pushStatusMessage && (
                <div className="p-3 bg-slate-50 border border-slate-200 rounded-xl text-xs text-slate-700 whitespace-pre-line">
                  {pushStatusMessage}
                </div>
              )}

              <button
                onClick={subscribePush}
                disabled={pushSubscribed}
                className="py-3 px-6 bg-orange-600 hover:bg-orange-700 text-white font-bold rounded-xl text-xs shadow-md shadow-orange-600/20 transition disabled:opacity-50 min-h-[44px] self-start"
              >
                {pushSubscribed ? 'التنبيهات مفعلة على هذا الجهاز ✓' : 'تفعيل إشعارات الطلبات الفورية'}
              </button>
            </div>
          )}
        </div>
      )}

      {/* Cancellation Reason Modal */}
      {selectedOrderForCancel && (
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-white border border-slate-200 rounded-2xl p-6 max-w-md w-full shadow-2xl flex flex-col gap-4">
            <h3 className="text-base font-bold text-slate-900">
              إلغاء الطلب {selectedOrderForCancel.order_number}
            </h3>
            <p className="text-xs text-slate-600">
              يرجى تحديد سبب الإلغاء ليتم إرساله للزبون وتوثيق العملية في سجل النظام:
            </p>

            <textarea
              value={cancelReason}
              onChange={(e) => setCancelReason(e.target.value)}
              placeholder="مثال: نفاد المكونات الأساسية، المطعم مغلق للصيانة..."
              rows={3}
              className="w-full bg-slate-50 border border-slate-300 rounded-xl p-3 text-xs text-slate-900 focus:outline-none focus:border-orange-500 focus:bg-white"
            />

            <div className="flex gap-2 justify-end">
              <button
                onClick={() => setSelectedOrderForCancel(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-semibold"
              >
                تراجع
              </button>
              <button
                onClick={() =>
                  handleOrderStatusChange(selectedOrderForCancel.id, 'cancelled', cancelReason)
                }
                disabled={!cancelReason.trim() || cancelReason.trim().length < 3}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-700 text-white rounded-xl text-xs font-bold transition disabled:opacity-40"
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
